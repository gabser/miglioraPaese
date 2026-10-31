import assert from 'node:assert/strict';
import {once} from 'node:events';
import {randomUUID,createHash} from 'node:crypto';
import {readFile,writeFile} from 'node:fs/promises';
import {deflateSync} from 'node:zlib';
import path from 'node:path';
import pg from 'pg';
import {startServer} from '../src/server.js';
import {runPostgresMigrations} from '../src/persistence/postgres/migrator.js';
import {publishSyntheticCalendar} from '../src/application/calendar-publication.js';
import {createReviewRepository} from '../src/persistence/postgres/review-repository.js';
import {createSimulatedEmailAdapter} from '../src/infrastructure/simulated-email.js';
import {privateDirectory,testDatabase} from '../src/operations/private-files.js';
import {createErasureJournal} from '../src/operations/erasure-journal.js';
import {backupPostgres,restorePostgres} from '../src/operations/backup.js';
const quiet={info(){},warn(){},error(){}};
const key=()=>randomUUID(),day=86400000;
function png(){const crc=bytes=>{let c=0xffffffff;for(const b of bytes){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;};const chunk=(type,data)=>{const t=Buffer.from(type),size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(data.length);sum.writeUInt32BE(crc(Buffer.concat([t,data])));return Buffer.concat([size,t,data,sum]);};return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',Buffer.from('00000001000000010806000000','hex')),chunk('IDAT',deflateSync(Buffer.from([0,255,0,0,255]))),chunk('IEND',Buffer.alloc(0))]);}
export async function rehearseOperations({databaseUrl,candidateId,artifactRoot}){
 const source=testDatabase(databaseUrl);if(!/^[a-f0-9]{64}$/.test(candidateId??''))throw Error('Real candidate digest required.');
 // Create a separate synthetic DB, never reset the supplied reference DB.
 const url=new URL(source);url.pathname='/sentinelle_rehearsal_'+key().replaceAll('-','').slice(0,12)+'_test';
 const adminUrl=new URL(source);adminUrl.pathname='/postgres';const admin=new pg.Client({connectionString:adminUrl.href});await admin.connect();try{await admin.query('CREATE DATABASE '+url.pathname.slice(1)+' TEMPLATE template0');}finally{await admin.end();}
 const runRoot=path.join(artifactRoot,'rehearsal-'+key());await privateDirectory(runRoot,{create:true});
 const root=path.join(runRoot,'proofs'),journalRoot=path.join(runRoot,'external-journal');await privateDirectory(root,{create:true});const journal=await createErasureJournal({root:journalRoot,initialize:true});
 await runPostgresMigrations({databaseUrl:url.href,attestationDatabaseUrl:url.href,sourceCommit:'phase8-synthetic-rehearsal',artifactDigest:'sha256:'+candidateId,logger:quiet});
 const pool=new pg.Pool({connectionString:url.href});
 let server,base,time=Date.parse('2027-01-01T00:00:00Z');const now=()=>time,mail=createSimulatedEmailAdapter(),events=[];
 const env={DATA_STORE:'postgres',DATABASE_URL:url.href,CANDIDATE_ID:candidateId,FANTASY_ENABLED:'true',ACCOUNT_ENABLED:'true',EMAIL_DELIVERY:'simulated',MISSIONS_ENABLED:'true',MISSION_STORAGE:'local-synthetic',MISSION_STORAGE_ROOT:root,MISSION_RETENTION_DAYS:'30',REVIEW_ENABLED:'true',MEASUREMENTS_ENABLED:'true',LEAGUE_CONTINUITY_ENABLED:'true',COOPERATION_ENABLED:'true',OPS_LOCAL_ENABLED:'true',OPS_JOURNAL_ROOT:journalRoot};
 const launch=async(database=url.href,storageRoot=root)=>{server=startServer({env:{...env,DATABASE_URL:database,MISSION_STORAGE_ROOT:storageRoot},port:0,host:'127.0.0.1',now,emailAdapter:mail,logger:quiet,requestLogger:{info:e=>events.push(e)}});await once(server,'listening');base='http://127.0.0.1:'+server.address().port;};
 const stop=async()=>{if(server){await new Promise((resolve,reject)=>server.close(e=>e?reject(e):resolve()));await server.closeResources();server=null;}};
 const req=async(route,method='GET',body,token)=>{const response=await fetch(base+route,{method,headers:{...(token?{authorization:'Bearer '+token}:{}),...(body?{'content-type':'application/json'}:{})},body:body?JSON.stringify(body):undefined});const data=await response.json();assert(response.ok,route+': '+JSON.stringify(data));return data;};
 const login=async email=>{const c=await req('/v1/auth/code','POST',{email});return req('/v1/auth/verify','POST',{challengeId:c.challengeId,code:mail.inspect().at(-1).code});};
 const facts={candidateId,clock:'2027-01-01..2027-01-09 UTC controlled synthetic',profile:'synthetic-local',http:true,postgres:true};
 try{
  const calendar=JSON.parse(await readFile(new URL('./examples/calendar-synthetic.json',import.meta.url),'utf8'));await publishSyntheticCalendar({pool,input:calendar,clock:now,loopbackSynthetic:true});
  const seasonId=calendar.season.id,seasonQuery='?seasonId='+seasonId;
  await launch();assert.equal((await req('/health')).candidateId,candidateId);assert.equal((await req('/ready')).status,'ready');
  let author=await login('rehearsal-author@example.invalid'),other=await login('rehearsal-other@example.invalid'),operator=await login('rehearsal-review@example.invalid');const authorId=author.account.id;
  time+=61000;author=await login('rehearsal-author@example.invalid');assert.equal(author.account.id,authorId);facts.accountRecovered=true;
  const roles=createReviewRepository(pool,{clock:now});for(const role of ['moderator','verifier','outcomesSupervisor'])await roles.setRole(operator.account.id,'tuglie',role,true);
  const fp='/v1/fantasy/municipalities/tuglie';
  for(const auth of [author,other])await req(fp+'/enrollment'+seasonQuery,'POST',{},auth.token);
  const league=(await req(fp+'/leagues'+seasonQuery,'POST',{name:'Amici',idempotencyKey:'shared-creator-key'},author.token)).league;
  await req(fp+'/leagues'+seasonQuery,'POST',{name:'Quartiere',idempotencyKey:'shared-creator-key'},other.token);
  const invite=(await req(fp+'/leagues/'+league.id+'/invites'+seasonQuery,'POST',{expiresInHours:72},author.token)).invite;
  await req('/v1/fantasy/league-invites/preview','POST',{token:invite.token});await req(fp+'/leagues/join'+seasonQuery,'POST',{token:invite.token},other.token);
  const ownership=fp+'/leagues/'+league.id+'/ownership';let work=await req(ownership+seasonQuery,'GET',undefined,author.token);
  const offer=await req(ownership+'/offers'+seasonQuery,'POST',{targetMemberId:work.candidates[0].memberId,expectedRevision:work.revision,idempotencyKey:key()},author.token);work=await req(ownership+seasonQuery,'GET',undefined,other.token);
  await req(ownership+'/offers/'+offer.offer.id+'/accept'+seasonQuery,'POST',{expectedRevision:work.revision,idempotencyKey:key()},other.token);assert.equal((await req(ownership+seasonQuery,'GET',undefined,other.token)).isOwner,true);facts.inviteAndTransfer=true;
  // The old unique(owner,key) schema cannot represent this populated state.
  const db=await pool.connect();try{await db.query('BEGIN');let sql;(await import('../migrations/20261015150000000_league_creator_identity.js')).down({sql:s=>sql=s});await assert.rejects(db.query(sql),e=>e.code==='23505');await db.query('ROLLBACK');}finally{db.release();}facts.down15AtomicRefusal=true;
  await req('/v1/me/followed-places/'+calendar.missions[0].placeId+'?municipalityId=tuglie','PUT',{},other.token);
  time=Date.parse(calendar.missions[0].windows[0].startsAt)+1000;
  const observe=async(auth,mission,answer,value)=>{const booking=await req('/v1/municipalities/tuglie/missions/'+mission.id+'/bookings','POST',{windowId:mission.windows[0].id,idempotencyKey:key()},auth.token);const bytes=png(),u=await req('/v1/bookings/'+booking.id+'/uploads','POST',{idempotencyKey:key(),mimeType:'image/png',totalBytes:bytes.length,synthetic:true},auth.token);await req('/v1/uploads/'+u.id+'/chunks','PUT',{offset:0,dataBase64:bytes.toString('base64')},auth.token);await req('/v1/uploads/'+u.id+'/complete','POST',{},auth.token);const body={idempotencyKey:key(),expectedRevision:1,protocolVersion:booking.protocolVersion,answer,notes:'Synthetic rehearsal only',proofIds:[u.id],measurement:{value}};const receipt=await req('/v1/bookings/'+booking.id+'/observations','POST',body,auth.token);assert.deepEqual(await req('/v1/bookings/'+booking.id+'/observations','POST',body,auth.token),receipt);return {booking,receipt,proof:u.id};};
  const reviewBase='/v1/review/municipalities/tuglie/observations/';
  const review=async(o,action,extra={})=>{const live=(await pool.query('SELECT revision FROM observation_reviews WHERE observation_id=$1',[o.id])).rows[0];return req(reviewBase+o.id+'/'+action,'POST',{idempotencyKey:key(),expectedRevision:live.revision,...extra},operator.token);};
  const screen=async o=>{await review(o,'assignment');await review(o,'screening',{decision:'forward',reason:'Synthetic screening'});return review(o,'assignment');};
  const one=await observe(author,calendar.missions[0],'visibleWaste',5);await screen(one.receipt);
  const integration=await review(one.receipt,'integration-requests',{message:'Synthetic extra angle'}),bytes=png();
  const upload=await req('/v1/observations/'+one.receipt.id+'/uploads','POST',{idempotencyKey:key(),integrationRequestId:integration.integrationRequest.id,mimeType:'image/png',totalBytes:bytes.length,synthetic:true},author.token);
  await req('/v1/uploads/'+upload.id+'/chunks','PUT',{offset:0,dataBase64:bytes.toString('base64')},author.token);await req('/v1/uploads/'+upload.id+'/complete','POST',{},author.token);
  await req('/v1/observations/'+one.receipt.id+'/supplements','POST',{idempotencyKey:key(),expectedRevision:integration.revision,integrationRequestId:integration.integrationRequest.id,notes:'Synthetic supplement',proofIds:[upload.id]},author.token);
  const approved=await review(one.receipt,'decisions',{decision:'approve',reason:'Synthetic verified'});assert.equal(approved.xpAwarded,10);
  const two=await observe(other,calendar.missions[0],'noIssue',5);await screen(two.receipt);assert.equal((await review(two.receipt,'decisions',{decision:'approve',reason:'Synthetic no issue'})).xpAwarded,10);facts.observationWithAndWithoutIssue=true;facts.integration=true;
  await stop();await launch();assert.equal((await req('/v1/me/xp','GET',undefined,author.token)).balance,10);facts.restartAndReceiptRetry=true;
  const protocols=(await pool.query('SELECT payload FROM measurement_protocols WHERE season_id=$1 AND matchday_id=$2',[seasonId,calendar.matchdays[0].id])).rows;const protocol=protocols[0].payload;
  const mb='/v1/measurements/municipalities/tuglie/';const cmd=(resource,extra,token=operator.token)=>req(mb+resource,'POST',{idempotencyKey:key(),...extra},token);
  const sourceId='calendar:'+seasonId+':'+calendar.missions[0].id;
  const intervention=await cmd('interventions',{title:'Synthetic temporary barrier',problemIds:[protocol.problemId],status:'started',temporary:true,expectedDurationDays:3,sourceId,sourceDate:calendar.missions[0].baseline.measuredAt});
  const completed=await cmd('interventions/'+intervention.id+'/updates',{title:'Synthetic temporary barrier',problemIds:[protocol.problemId],status:'completed',temporary:true,expectedDurationDays:3,sourceId,sourceDate:calendar.missions[0].baseline.measuredAt,expectedRevision:1});facts.temporaryIntervention=completed.history.length===2;
  time=Date.parse(calendar.matchdays[0].observationEndsAt);
  const evidence={protocolId:protocol.id,protocolVersion:protocol.version,afterValue:5,measuredAt:one.receipt.measurement.recordedAt,sourceIds:[],approvedObservationIds:[one.receipt.id,two.receipt.id],interventionIds:[intervention.id],rationale:'Synthetic independent observations'};
  const draft=await cmd('evaluations',evidence);const publication=await cmd('evaluations/'+draft.id+'/publications',{expectedRevision:draft.revision,disposition:'determinate',observed:'improves',rationale:evidence.rationale,undeterminableReason:null});
  const appeal=await cmd('evaluations/'+publication.id+'/appeals',{expectedRevision:publication.revision,publishedVersion:publication.version,reason:'Synthetic uncertainty appeal'},author.token);
  const correction=await cmd('evaluations/'+publication.id+'/corrections',{expectedRevision:publication.revision,...Object.fromEntries(Object.entries(evidence).filter(([k])=>!['protocolId','protocolVersion'].includes(k))),afterValue:null,measuredAt:null,sourceIds:[],approvedObservationIds:[],disposition:'undeterminable',observed:null,undeterminableReason:'insufficientEvidence',appealId:appeal.id});assert.equal(correction.version,2);facts.appealCorrectionUndeterminable=true;
  const scope='?seasonId='+seasonId+'&matchdayId='+calendar.matchdays[0].id;
  const coverage=await req('/v1/municipalities/tuglie/cooperation'+scope);assert.equal(coverage.coverage.validatedPlaceWindows,1);assert((await req('/v1/me/inbox','GET',undefined,author.token)).items.length>0);facts.coverageInbox=true;
  time=Date.parse(calendar.missions[1].windows[0].startsAt)+1000;const week2=await observe(author,calendar.missions[1],'noIssue',3);await screen(week2.receipt);await review(week2.receipt,'decisions',{decision:'approve',reason:'Synthetic second weekly check'});assert.equal((await req('/v1/me/xp','GET',undefined,author.token)).balance,20);facts.secondWeeklyCheck=true;
  // Snapshot rich receipts/XP/history/membership/inbox on a stopped-writer source.
  await stop();const backup=path.join(runRoot,'backup');await backupPostgres({databaseUrl:url.href,proofRoot:root,output:backup,journal,candidateId,environment:env,writersSuspended:true});
  await launch();const guest=await req('/v1/proposal-session','POST',{});await req(fp+'/enrollment'+seasonQuery,'POST',{},guest.token);await req('/v1/session','DELETE',undefined,author.token);await req('/v1/session','DELETE',undefined,guest.token);await stop();
  const restoreUrl=new URL(url);restoreUrl.pathname='/sentinelle_restore_'+key().replaceAll('-','').slice(0,12)+'_test';const restoredProofs=path.join(runRoot,'restored-proofs');const restored=await restorePostgres({databaseUrl:restoreUrl.href,sourceDatabaseUrl:url.href,backup,proofRoot:restoredProofs,journal});
  const copy=new pg.Pool({connectionString:restoreUrl.href});try{assert.equal((await copy.query('SELECT amount FROM xp_ledger ORDER BY amount')).rowCount,3);assert.equal((await copy.query('SELECT receipt FROM mission_observations WHERE id=$1',[one.receipt.id])).rows[0].receipt.id,one.receipt.id);assert.equal((await copy.query('SELECT user_id FROM fantasy_players WHERE user_id=$1',['account:'+authorId])).rowCount,0);assert.equal((await copy.query('SELECT user_id FROM fantasy_players WHERE user_id=$1',['account:'+other.account.id])).rowCount,1);assert.equal((await copy.query('SELECT * FROM measurement_publications WHERE evaluation_id=$1',[publication.id])).rowCount,2);assert((await copy.query('SELECT * FROM cooperation_inbox')).rowCount>0);assert((await copy.query('SELECT * FROM fantasy_members WHERE user_id=$1',['account:'+other.account.id])).rowCount>0);}finally{await copy.end();}
  await launch(restoreUrl.href,restoredProofs);assert.equal((await req('/ready')).status,'ready');assert.equal((await req('/health')).candidateId,candidateId);assert.equal((await req('/v1/me/xp','GET',undefined,author.token)).balance,20);assert((await req('/v1/proofs/'+one.proof,'GET',undefined,author.token)).dataBase64);assert.equal((await fetch(base+fp+'/team'+seasonQuery,{headers:{authorization:'Bearer '+author.token}})).status,404);await stop();facts.restoredHttpReadiness=true;
  facts.postgresBackupRestore=restored;facts.erasureScope='fantasy only; accounts, sessions, missions and audit retained';
  assert(!JSON.stringify(events).includes(author.token));assert(!JSON.stringify(events).includes('example.invalid'));assert(!JSON.stringify(events).includes('Synthetic supplement'));facts.staticLogEvents=events.length;
  await writeFile(path.join(runRoot,'result.json'),JSON.stringify(facts,null,2),{mode:0o600});return {runRoot,facts};
 }finally{await stop();await pool.end();}
}
if(import.meta.url===`file://${process.argv[1]}`){rehearseOperations({databaseUrl:process.env.TEST_DATABASE_URL,candidateId:process.env.CANDIDATE_ID,artifactRoot:path.resolve('../../.sentinelle-local/phase8/backend')}).then(({runRoot,facts})=>console.log(JSON.stringify({artifact:path.basename(runRoot),...facts}))).catch(error=>{console.error(error.message);process.exitCode=1;});}
