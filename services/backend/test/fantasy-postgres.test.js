import assert from 'node:assert/strict';
import { integrationTest as it } from './helpers/fantasy.js';
import { Readable } from 'node:stream';
import { createTestStore, client, appFor } from './helpers/fantasy.js';
import { createFantasyStore } from '../src/application/fantasy/store.js';
import { createApp, startServer } from '../src/server.js';
import { sessionIdentity } from '../src/domain/proposal-session.js';

const start=Date.parse('2026-10-08T00:00:00Z'),lock=Date.parse('2026-10-10T00:00:00Z'),end=Date.parse('2026-10-15T00:00:00Z');
const town='tuglie', user='test-player';
const base='/v1/fantasy/municipalities/'+town;
function draft(t,changes={}) {return {expectedRevision:t.revision,matchdayId:t.matchdayId,starterIds:t.team.starterIds,captainId:t.team.captainId,predictions:t.team.predictions,motivations:t.team.motivations,...changes};}
async function failWrites(pool,table,event) {
  await pool.query(`CREATE FUNCTION fantasy_fail_test() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected failure'; END $$;
    CREATE TRIGGER fantasy_failure BEFORE ${event} ON ${table} FOR EACH ROW EXECUTE FUNCTION fantasy_fail_test()`);
  return ()=>pool.query(`DROP TRIGGER fantasy_failure ON ${table}; DROP FUNCTION fantasy_fail_test()`);
}
async function request(app,path,method='GET',body,headers={}) {
  const req=Readable.from(body===undefined?[]:[Buffer.from(JSON.stringify(body))]);Object.assign(req,{url:path,method,headers});
  const res={writeHead(status,headers){this.status=status;this.headers=headers;},end(payload){this.body=JSON.parse(payload);}};await app(req,res);return res;
}
async function confirm(fantasy,userId=user) {
  let t=await fantasy.teams.enroll(town,userId,{});
  t=await fantasy.teams.update(town,userId,draft(t,{predictions:Object.fromEntries(t.team.starterIds.map(id=>[id,'stable']))}));
  return fantasy.teams.confirm(town,userId,{expectedRevision:t.revision,matchdayId:t.matchdayId});
}
async function publish(fantasy,cardId='buche-centro') {
  const card=(await fantasy.cards(town)).items.find(c=>c.id===cardId);
  return fantasy.results.publish(town,'matchday-1',cardId,{observed:'stable',sourceLabel:card.sourceLabel,sourceStatus:'verified',sourceDate:new Date(end).toISOString(),explanation:'Synthetic test fixture',version:1,rulesVersion:'fantasy-demo-v1'});
}
it('fantasy is disabled by default and rejects incompatible configuration',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    assert.equal((await request(createApp({store}),base+'/season')).status,404);
    assert.throws(()=>startServer({env:{DATA_STORE:'memory',FANTASY_ENABLED:'true'}}),/PostgreSQL/);
  }finally {await store.close();}
});
it('recovers a deadline missed at restart without renewing the persisted fixture calendar',async()=> {
  let time=start;const store=await createTestStore({now:()=>time});
  try {
    await confirm(store.fantasy);await store.fantasy.teams.enroll(town,'other',{});
    const season=(await store.fantasy.season(town)).season;
    time=lock;
    const restarted=await createFantasyStore({pool:store.pool,now:()=>time,seedDemo:true,seedStartsAt:'2027-10-08T00:00:00Z'});
    const team=await restarted.teams.team(town,user);assert.equal(team.snapshots[0].eligible,true);
    assert.equal((await restarted.season(town)).season.startsAt,season.startsAt);
    await restarted.eraseUserData(user);
    await assert.rejects(restarted.teams.team(town,user),/enrollment/);
    assert.equal((await restarted.teams.team(town,'other')).snapshots[0].eligible,false);
    assert.equal((await restarted.counts()).players,1);
  }finally {await store.close();}
});
it('draft and revision roll back together when PostgreSQL rejects a write',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    const first=await store.fantasy.teams.enroll(town,user,{}),cleanup=await failWrites(store.pool,'fantasy_drafts','UPDATE');
    try {await assert.rejects(store.fantasy.teams.update(town,user,draft(first,{captainId:'bus-stazione'})),/injected failure/);assert.deepEqual(await store.fantasy.teams.team(town,user),first);}finally {await cleanup();}
    assert.equal((await store.fantasy.teams.update(town,user,draft(first))).revision,2);
  }finally {await store.close();}
});
it('personal erasure rolls back league archival and invite revocation on PostgreSQL failure',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    await store.fantasy.teams.enroll(town,user,{});await store.fantasy.teams.enroll(town,'other',{});
    const league=(await store.fantasy.leagues.create(town,user,{name:'Amici',idempotencyKey:'erase-league-key'})).league;
    const invite=(await store.fantasy.leagues.invite(town,user,league.id,{expiresInHours:24})).invite;
    const cleanup=await failWrites(store.pool,'fantasy_players','DELETE');
    try {await assert.rejects(store.fantasy.eraseUserData(user),/injected failure/);assert.equal((await store.fantasy.leagues.read(town,user,league.id)).league.status,'active');assert.equal((await store.pool.query('SELECT revoked FROM fantasy_invites WHERE id=$1',[invite.id])).rows[0].revoked,0);}finally {await cleanup();}
    await store.fantasy.eraseUserData(user);assert.equal((await store.fantasy.counts()).players,1);
  }finally {await store.close();}
});
it('lost transfer reply replays the original persisted response after restart and lock, including concurrent duplicates',async()=> {
  let time=start;const store=await createTestStore({now:()=>time});
  try {
    const t=await store.fantasy.teams.enroll(town,user,{});
    const quote=(await store.fantasy.market.quote(town,user,{expectedRevision:t.revision,matchdayId:t.matchdayId,outgoingId:'parco-nord',incomingId:'fontanelle-ovest'})).quote;
    const command={quoteId:quote.id,expectedRevision:quote.expectedRevision,idempotencyKey:'lost-market-reply'};
    const responses=await Promise.all([store.fantasy.market.confirm(town,user,command),store.fantasy.market.confirm(town,user,command)]);
    assert.deepEqual(responses[0],responses[1]);assert.equal((await store.fantasy.counts()).transfers,1);
    time=lock;const restarted=await createFantasyStore({pool:store.pool,now:()=>time});
    assert.deepEqual(await restarted.market.confirm(town,user,command),responses[0]);
    assert.equal((await restarted.teams.team(town,user)).snapshots[0].transferPenalty,0);
  }finally {await store.close();}
});
it('catalog version, prices, availability and role changes invalidate transfer quotes without spending allowance',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    const t=await store.fantasy.teams.enroll(town,user,{}),seasonId=t.seasonId;
    const make=()=>store.fantasy.market.quote(town,user,{expectedRevision:t.revision,matchdayId:t.matchdayId,outgoingId:'parco-nord',incomingId:'fontanelle-ovest'});
    const quote=(await make()).quote,command={quoteId:quote.id,expectedRevision:1,idempotencyKey:'catalog-change-key'};
    await store.pool.query('UPDATE fantasy_seasons SET catalog_version=2 WHERE id=$1',[seasonId]);
    await assert.rejects(store.fantasy.market.confirm(town,user,command),e=>e.code==='stale_quote');
    await store.pool.query('UPDATE fantasy_seasons SET catalog_version=1 WHERE id=$1',[seasonId]);
    for(const [field,value,error] of [['price',10,'stale_quote'],['availability','unavailable','card_unavailable'],['role','mobility','stale_quote']]) {
      const before=(await store.pool.query(`SELECT ${field} AS value FROM fantasy_cards WHERE season_id=$1 AND id='fontanelle-ovest'`,[seasonId])).rows[0].value;
      await store.pool.query(`UPDATE fantasy_cards SET ${field}=$2 WHERE season_id=$1 AND id='fontanelle-ovest'`,[seasonId,value]);
      await assert.rejects(store.fantasy.market.confirm(town,user,command),e=>e.code===error||e.code==='invalid_squad');
      await store.pool.query(`UPDATE fantasy_cards SET ${field}=$2 WHERE season_id=$1 AND id='fontanelle-ovest'`,[seasonId,before]);
    }
    assert.equal((await store.fantasy.teams.team(town,user)).transfersRemaining,2);
    const cleanup=await failWrites(store.pool,'fantasy_transfer_commands','INSERT');
    try {await assert.rejects(store.fantasy.market.confirm(town,user,command),/injected failure/);assert.equal((await store.fantasy.counts()).transfers,0);assert.equal((await store.fantasy.teams.team(town,user)).revision,1);}finally {await cleanup();}
  }finally {await store.close();}
});
it('results, reflections and finalization persist across restart; erasure preserves publications',async()=> {
  let time=start;const store=await createTestStore({now:()=>time});
  try {
    await confirm(store.fantasy);time=end;
    const team=await store.fantasy.teams.team(town,user);
    for(const cardId of team.snapshots[0].starterIds)await publish(store.fantasy,cardId);
    const result=await store.fantasy.results.read(town,user,'matchday-1');
    const reflection={expectedRevision:result.revision,answer:'insufficientInformation'};
    const cleanup=await failWrites(store.pool,'fantasy_reflections','INSERT');
    try {await assert.rejects(store.fantasy.results.reflect(town,user,'matchday-1','buche-centro',reflection),/injected failure/);assert.deepEqual(await store.fantasy.results.read(town,user,'matchday-1'),result);}finally {await cleanup();}
    const reflected=await store.fantasy.results.reflect(town,user,'matchday-1','buche-centro',reflection);
    const restarted=await createFantasyStore({pool:store.pool,now:()=>time});assert.deepEqual(await restarted.results.read(town,user,'matchday-1'),reflected);
    await restarted.eraseUserData(user);const counts=await restarted.counts();
    assert.equal(counts.reveals,0);assert.equal(counts.reflections,0);assert.equal(counts.finalizations,0);assert.equal(counts.outcomes,5);
  }finally {await store.close();}
});
it('invite hashes and failed-guess quota survive restart; five failed attempts consume the minute window',async()=> {
  let time=start;const store=await createTestStore({now:()=>time});
  try {
    await store.fantasy.teams.enroll(town,user,{});await store.fantasy.teams.enroll(town,'other',{});
    const league=(await store.fantasy.leagues.create(town,user,{name:'Amici',idempotencyKey:'rate-limit-key'})).league;
    const invite=(await store.fantasy.leagues.invite(town,user,league.id,{expiresInHours:24})).invite;
    const stored=(await store.pool.query('SELECT token_hash FROM fantasy_invites WHERE id=$1',[invite.id])).rows[0];assert.match(stored.token_hash,/^[a-f0-9]{64}$/);assert.notEqual(stored.token_hash,invite.token);
    for(let n=0;n<5;n++)await assert.rejects(store.fantasy.leagues.join(town,'other',{token:'bad-token'}),e=>e.code==='invalid_invite');
    const restarted=await createFantasyStore({pool:store.pool,now:()=>time});await assert.rejects(restarted.leagues.join(town,'other',{token:invite.token}),e=>e.code==='invite_rate_limited');
    time+=60000;assert.equal((await restarted.leagues.join(town,'other',{token:invite.token})).league.memberCount,2);
  }finally {await store.close();}
});
it('concurrent enrollment and owned league limits are serialized across PostgreSQL connections',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    const enrolled=await Promise.all([store.fantasy.teams.enroll(town,user,{}),store.fantasy.teams.enroll(town,user,{})]);assert.deepEqual(enrolled[0],enrolled[1]);
    const attempts=await Promise.allSettled(Array.from({length:4},(_,i)=>store.fantasy.leagues.create(town,user,{name:'Amici',idempotencyKey:'owned-limit-key-'+i})));
    assert.equal(attempts.filter(v=>v.status==='fulfilled').length,3);assert.equal(attempts.filter(v=>v.status==='rejected')[0].reason.code,'league_limit');
  }finally {await store.close();}
});
it('HTTP publication uses separate local admin authorization and refuses cross-origin publication',async()=> {
  let time=start;const store=await createTestStore({now:()=>time}),secret='local-fantasy-publication-test-secret';
  try {
    const app=appFor(store,{adminToken:secret,pilotMunicipalityId:town}),api=client(app);
    const enrolled=(await api(base+'/enrollment','POST',{})).body;await api(base+'/team/confirmation','POST',{expectedRevision:enrolled.revision,matchdayId:'matchday-1'});time=end;
    const card=(await store.fantasy.cards(town)).items.find(c=>c.id==='buche-centro'),body={observed:'stable',sourceLabel:card.sourceLabel,sourceStatus:'verified',sourceDate:new Date(end).toISOString(),explanation:'Synthetic fixture',version:1,rulesVersion:'fantasy-demo-v1'};
    const path='/v1/fantasy/admin/municipalities/tuglie/matchdays/matchday-1/outcomes/buche-centro';
    assert.equal((await request(app,path,'PUT',body)).status,401);assert.equal((await request(app,path,'PUT',body,{'x-admin-token':secret,origin:'http://localhost:3000'})).status,403);
    assert.equal((await request(app,path,'PUT',body,{'x-admin-token':secret})).status,200);
    const revealed=await api(base+'/matchdays/matchday-1/reveal');assert.equal(revealed.body.results.length,1);
    const reflected=await api(base+'/matchdays/matchday-1/cards/buche-centro/reflection','POST',{expectedRevision:revealed.body.revision,answer:'observedIntervention'});assert.equal(reflected.body.summary.reflectionBonus,1);
    const preflight=await request(app,'/v1/session','OPTIONS',undefined,{origin:'http://localhost:3000','access-control-request-method':'DELETE'});assert.equal(preflight.status,200);assert.match(preflight.headers['access-control-allow-methods'],/DELETE/);
  }finally {await store.close();}
});
it('bearer session erasure isolates managers, spans municipalities and preserves legacy proposals and token until revoke',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    const app=appFor(store),a=client(app),b=client(app);await a(base+'/enrollment','POST',{});await a('/v1/fantasy/municipalities/bologna/enrollment','POST',{});await b(base+'/enrollment','POST',{});
    assert.equal((await request(app,base+'/team')).status,401);assert.equal((await a(base+'/team?userId=spoof')).status,400);
    assert.equal((await a('/v1/session','DELETE')).status,200);assert.equal((await a(base+'/team')).body.error,'team_not_found');assert.equal((await b(base+'/team')).status,200);
    assert.equal((await a('/v1/proposal-session')).status,200);assert.equal((await store.fantasy.counts()).players,1);
    await a('/v1/proposal-session/revoke','POST',{});assert.equal((await a(base+'/enrollment','POST',{})).status,401);assert.equal((await store.fantasy.counts()).players,1);
  }finally {await store.close();}
});
function deferred(){let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};}
for(const phase of ['before_session_lock','session_locked'])it('revocation is a barrier for fantasy transactions at '+phase,async()=> {
  const store=await createTestStore({now:()=>start});
  let release;
  try {
    const session=await store.createProposalSession(),identity=sessionIdentity(session),entered=deferred(),gate=deferred();let armed=true;
    release=gate.resolve;
    const fantasy=await createFantasyStore({pool:store.pool,now:()=>start,onTransactionCheckpoint:async where=>{if(armed&&where===phase){armed=false;entered.resolve();await gate.promise;}}});
    const operation=fantasy.authenticated(session.token,()=>fantasy.teams.enroll(town,identity,{}));
    const settled=operation.then(value=>({value}),error=>({error}));await entered.promise;
    const revocation=store.revokeProposalSession(session.token);
    if(phase==='before_session_lock'){await revocation;gate.resolve();assert.equal((await settled).error.code,'proposal_session_revoked');assert.equal((await fantasy.counts()).players,0);}
    else {gate.resolve();await revocation;const result=await settled;assert.ok(result.value||result.error?.code==='proposal_session_revoked');const count=(await fantasy.counts()).players;await assert.rejects(fantasy.authenticated(session.token,()=>fantasy.teams.enroll(town,identity,{})),e=>e.code==='proposal_session_revoked');assert.equal((await fantasy.counts()).players,count);}
  }finally {release?.();await store.close();}
});
it('readiness detects missing tables, renamed columns and removed foreign keys and recovers after repair',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    assert.equal(await store.fantasy.isReady(),true);
    const app=appFor(store);assert.equal((await request(app,'/ready')).status,200);
    await store.pool.query('ALTER TABLE fantasy_cards RENAME COLUMN availability TO availability_probe');
    try {assert.equal(await store.fantasy.isReady(),false);assert.equal((await request(app,'/ready')).status,503);}finally {await store.pool.query('ALTER TABLE fantasy_cards RENAME COLUMN availability_probe TO availability');}
    await store.pool.query('ALTER TABLE fantasy_quotes RENAME TO fantasy_quotes_probe');
    try {assert.equal(await store.fantasy.isReady(),false);}finally {await store.pool.query('ALTER TABLE fantasy_quotes_probe RENAME TO fantasy_quotes');}
    const fk=(await store.pool.query(`SELECT conname,pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE conrelid='fantasy_cards'::regclass AND contype='f'`)).rows[0];
    await store.pool.query(`ALTER TABLE fantasy_cards DROP CONSTRAINT ${fk.conname}`);
    try {assert.equal(await store.fantasy.isReady(),false);}finally {await store.pool.query(`ALTER TABLE fantasy_cards ADD CONSTRAINT ${fk.conname} ${fk.definition}`);}
    assert.equal(await store.fantasy.isReady(),true);
  }finally {await store.close();}
});
it('PostgreSQL fantasy schema enforces JSON shape, role, revision and composite season ownership',async()=> {
  const store=await createTestStore({now:()=>start});
  try {
    const player=await store.fantasy.teams.enroll(town,user,{});
    for(const value of ['{}','null','"text"'])await assert.rejects(store.pool.query('UPDATE fantasy_players SET squad_ids=$1 WHERE season_id=$2 AND user_id=$3',[value,player.seasonId,user]),e=>e.code==='23514');
    await assert.rejects(store.pool.query('UPDATE fantasy_players SET revision=0 WHERE season_id=$1 AND user_id=$2',[player.seasonId,user]),e=>e.code==='23514');
    await assert.rejects(store.pool.query("UPDATE fantasy_cards SET role='unknown' WHERE season_id=$1 AND id='buche-centro'",[player.seasonId]),e=>e.code==='23514');
    await assert.rejects(store.pool.query("UPDATE fantasy_cards SET payload='[]' WHERE season_id=$1 AND id='buche-centro'",[player.seasonId]),e=>e.code==='23514');
    await assert.rejects(store.pool.query('INSERT INTO fantasy_drafts VALUES($1,$2,$3,$4)',['fantasy-demo-bologna-2026-autumn',user,'matchday-1','{}']),e=>e.code==='23503');
    assert.equal((await store.fantasy.teams.team(town,user)).revision,1);
  }finally {await store.close();}
});
