import assert from 'node:assert/strict';
import { mkdtemp, copyFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { once } from 'node:events';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';
import { createPersistentStore, startServer } from '../src/server.js';
import { createObservability } from '../src/observability.js';
import { evaluatePilotSignals } from '../src/pilot_signals.js';
const exec=promisify(execFile);
const start=Date.parse('2026-10-08T00:00:00Z'),lock=Date.parse('2026-10-10T00:00:00Z'),end=Date.parse('2026-10-15T00:00:00Z');
const tables=['fantasy_players','fantasy_drafts','fantasy_snapshots','fantasy_quotes','fantasy_transfers','fantasy_transfer_commands','fantasy_outcomes','fantasy_reveals','fantasy_finalizations','fantasy_reflections','fantasy_leagues','fantasy_members','fantasy_invites','fantasy_invite_attempts'];
function dump(db) { return Object.fromEntries(tables.map(table=>[table,db.prepare(`SELECT * FROM ${table} ORDER BY rowid`).all()])); }

// There is intentionally no target URL/database input. Every write and fault is
// confined to a newly created temporary database and loopback ephemeral server.
export async function runFantasyRehearsal() {
  const directory=await mkdtemp(join(tmpdir(),'fantasy-rehearsal-'));
  const databasePath=join(directory,'source.sqlite'),backupPath=join(directory,'backup.sqlite'),restoredPath=join(directory,'restored.sqlite');
  const token='synthetic-rehearsal-admin-secret-minimum-32-chars';
  const identitySecret='synthetic-rehearsal-identity-secret-minimum-32-chars';
  const events=[];
  let time=start,store,server,baseUrl,db;
  async function open(path) {
    store=createPersistentStore({databasePath:path,now:()=>time,moderationRequired:true,minimumAggregateSampleSize:3});
    server=startServer({port:0,host:'127.0.0.1',store,identitySecret,moderationAdminToken:token,
      pilotMunicipalityId:'tuglie',moderationRequired:true,secureCookies:false,
      observability:createObservability({logger:event=>events.push(event)})});
    await once(server,'listening'); baseUrl=`http://127.0.0.1:${server.address().port}`;
  }
  async function close() { if(server) { await new Promise(resolve=>server.close(resolve)); server=null; } store?.close(); store=null; }
  function session() {
    let cookie;
    return async(path,method='GET',body,admin=false)=> {
      const response=await fetch(`${baseUrl}${path}`,{method,headers:{...(cookie?{cookie}:{}),...(body?{'content-type':'application/json'}:{}),...(admin?{authorization:`Bearer ${token}`}:{})},
        body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(8000)});
      const issued=response.headers.get('set-cookie'); if(issued) cookie=issued.split(';')[0];
      const value=await response.json(); return {status:response.status,body:value};
    };
  }
  const base='/v1/fantasy/municipalities/tuglie';
  try {
    await open(databasePath);
    const clients=[session(),session(),session()],outsider=session(),admin=session();
    let teams=[];
    for(const request of clients) { const result=await request(`${base}/enrollment`,'POST',{}); assert.equal(result.status,200); teams.push(result.body); }
    const league=(await clients[0](`${base}/leagues`,'POST',{name:'Amici',idempotencyKey:'rehearsal-create-key'})).body.league;
    const invitation=(await clients[0](`${base}/leagues/${league.id}/invites`,'POST',{expiresInHours:168})).body.invite;
    for(const request of clients.slice(1)) assert.equal((await request(`${base}/leagues/join`,'POST',{token:invitation.token})).status,200);
    assert.equal((await outsider(`${base}/leagues/${league.id}`)).status,404);
    for(const [outgoingId,incomingId] of [['parco-nord','fontanelle-ovest'],['fontanelle-ovest','parco-nord'],['parco-nord','fontanelle-ovest'],['fontanelle-ovest','parco-nord']]) {
      const q=(await clients[2](`${base}/transfers/quote`,'POST',{expectedRevision:teams[2].revision,matchdayId:'matchday-1',outgoingId,incomingId})).body.quote;
      const command={quoteId:q.id,expectedRevision:q.expectedRevision,idempotencyKey:`rehearsal-transfer-${q.expectedRevision}`};
      const accepted=await clients[2](`${base}/transfers/confirmation`,'POST',command);
      assert.equal(accepted.status,200); teams[2]=accepted.body;
      assert.deepEqual((await clients[2](`${base}/transfers/confirmation`,'POST',command)).body,accepted.body);
    }
    for(let i=0;i<clients.length;i++) {
      const t=teams[i],body={expectedRevision:t.revision,matchdayId:t.matchdayId,starterIds:t.team.starterIds,captainId:t.team.captainId,
        predictions:Object.fromEntries(t.team.starterIds.map(id=>[id,'stable'])),motivations:{'buche-centro':'Motivazione sintetica riservata'}};
      const update=await clients[i](`${base}/team`,'PUT',body); assert.equal(update.status,200);
      const accepted=await clients[i](`${base}/team/confirmation`,'POST',{expectedRevision:update.body.revision,matchdayId:t.matchdayId});
      assert.equal(accepted.status,200); teams[i]=accepted.body;
    }
    // Smoke reads never create players, snapshots or commands.
    const beforeSmoke=store.fantasy.counts();
    const smoke=await exec(process.execPath,['scripts/smoke.js'],{cwd:new URL('..',import.meta.url),env:{...process.env,STAGING_BASE_URL:baseUrl,PILOT_MUNICIPALITY_ID:'tuglie',STAGING_PROFILE:'fantasy-api'}});
    assert.equal(JSON.parse(smoke.stdout.trim()).profile,'fantasy-api'); assert.deepEqual(store.fantasy.counts(),beforeSmoke);
    time=lock;
    for(let i=0;i<clients.length;i++) {
      assert.equal((await clients[i](`${base}/team/confirmation`,'POST',{expectedRevision:teams[i].revision,matchdayId:'matchday-1'})).status,409);
      assert.equal((await clients[i](`${base}/team`)).body.snapshots.length,1);
    }
    time=end;
    const catalog=(await clients[0](`${base}/cards`)).body;
    for(const card of catalog.items.filter(c=>c.sourceStatus==='verified')) {
      const result=await admin(`/v1/fantasy/admin/municipalities/tuglie/matchdays/matchday-1/outcomes/${card.id}`,'PUT',{
        observed:'stable',sourceLabel:card.sourceLabel,sourceStatus:'verified',sourceDate:new Date(end).toISOString(),explanation:'Esito sintetico riservato',rulesVersion:'fantasy-demo-v1',version:1},true);
      assert.equal(result.status,200);
    }
    const summaries=[];
    for(const request of clients) { const result=await request(`${base}/matchdays/matchday-1/reveal`); assert.equal(result.body.summary.status,'final'); summaries.push(result.body); }
    const reflected=await clients[0](`${base}/matchdays/matchday-1/cards/buche-centro/reflection`,'POST',{expectedRevision:summaries[0].revision,answer:'observedIntervention'});
    assert.equal(reflected.status,200); assert.equal(reflected.body.summary.total,29);
    const ranking=(await clients[0](`${base}/leagues/${league.id}`)).body;
    assert.deepEqual(ranking.entries.map(e=>e.points),[29,28,20]);
    db=new DatabaseSync(databasePath); const expected=dump(db); db.close(); db=null;
    await exec(process.execPath,['scripts/backup.js'],{cwd:new URL('..',import.meta.url),env:{...process.env,DATABASE_PATH:databasePath,BACKUP_PATH:backupPath}});
    const verified=await exec(process.execPath,['scripts/verify_database.js'],{cwd:new URL('..',import.meta.url),env:{...process.env,BACKUP_PATH:backupPath}});
    assert.equal(JSON.parse(verified.stdout.trim()).schemaVersion,6);
    await close(); await copyFile(backupPath,restoredPath); await open(restoredPath);
    db=new DatabaseSync(restoredPath); assert.deepEqual(dump(db),expected);
    assert.deepEqual((await clients[0](`${base}/leagues/${league.id}`)).body.entries,ranking.entries);
    assert.deepEqual((await clients[0](`${base}/matchdays/matchday-1/reveal`)).body,reflected.body);
    // Real fault injection verifies safe errors, transactional privacy rollback,
    // readiness degradation and metric growth. Only the isolated restored copy.
    db.exec("CREATE TRIGGER rehearsal_delete_failure BEFORE DELETE ON fantasy_players BEGIN SELECT RAISE(ABORT,'isolated-fault'); END;");
    assert.equal((await clients[0]('/v1/session','DELETE')).status,500);
    assert.equal((await clients[1](`${base}/leagues/${league.id}`)).body.league.status,'active');
    db.exec('DROP TRIGGER rehearsal_delete_failure; ALTER TABLE fantasy_invites RENAME TO isolated_invites;');
    const failedReady=await fetch(`${baseUrl}/ready`); assert.equal(failedReady.status,503); await failedReady.text();
    db.exec('ALTER TABLE isolated_invites RENAME TO fantasy_invites;');
    const metrics=await (await fetch(`${baseUrl}/metrics`)).text();
    assert.match(metrics,/route="deleteSessionData",status="500"/); assert.match(metrics,/route="ready",status="503"/);
    const signals=evaluatePilotSignals({ready:false,consecutiveReadinessFailures:2,fiveXxIncrease:1,diskAvailableRatio:0.1,backupVerifiedAt:end-86400001,now:end,scrapeHealthy:false});
    assert.equal(signals.length,5);
    assert.equal((await clients[0]('/v1/session','DELETE')).status,200);
    const remaining=(await clients[1](`${base}/leagues/${league.id}`)).body;
    assert.equal(remaining.league.status,'archived'); assert.equal(remaining.league.memberCount,2); assert.equal(remaining.entries.length,0);
    for(let i=1;i<clients.length;i++) assert.equal((await clients[i](`${base}/matchdays/matchday-1/reveal`)).body.summary.total,summaries[i].summary.total);
    const serialized=JSON.stringify(events)+metrics;
    for(const secret of [token,identitySecret,invitation.token,league.id,'Motivazione sintetica riservata','Esito sintetico riservato',...expected.fantasy_players.map(p=>p.user_id)]) assert.ok(!serialized.includes(secret));
    const sourceBackup=new DatabaseSync(backupPath,{readOnly:true}); try {assert.deepEqual(dump(sourceBackup),expected);} finally {sourceBackup.close();}
    return {event:'fantasy_isolated_rehearsal_completed',isDemo:true,sessions:3,ranking:[29,28,20],backupRestore:true,
      privacyRollback:true,ownerDeletion:true,nonMutatingSmoke:true,privateLogs:true,localAlertSignals:signals,operationalGoLive:'not_authorized'};
  } finally {db?.close(); await close(); await rm(directory,{recursive:true,force:true});}
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) {
  try {console.log(JSON.stringify(await runFantasyRehearsal()));}
  catch {console.error(JSON.stringify({event:'fantasy_isolated_rehearsal_failed'})); process.exitCode=1;}
}
