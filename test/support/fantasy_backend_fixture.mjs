import {publishSyntheticCalendar} from '../../services/backend/src/application/calendar-publication.js';
import {createCooperationService} from '../../services/backend/src/application/cooperation-service.js';
import {createCooperationEvents} from '../../services/backend/src/application/cooperation-events.js';
import { createMeasurementService } from '../../services/backend/src/application/measurement-service.js';
import { createMeasurementRepository } from '../../services/backend/src/persistence/postgres/measurement-repository.js';
import { seedSyntheticMeasurementSeason } from '../../services/backend/src/persistence/postgres/measurement-synthetic-fixture.js';
// Disposable loopback PostgreSQL only. Time/publishing controls are stdin-only.
import { createInterface } from 'node:readline';
import { once } from 'node:events';
import http from 'node:http';
import { randomUUID } from 'node:crypto';
import { mkdtemp,rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createReviewService } from '../../services/backend/src/application/review-service.js';
import { createReviewRepository } from '../../services/backend/src/persistence/postgres/review-repository.js';
import { createMissionService } from '../../services/backend/src/application/mission-service.js';
import { createMissionRepository } from '../../services/backend/src/persistence/postgres/mission-repository.js';
import { createLocalProofStorage } from '../../services/backend/src/infrastructure/local-proof-storage.js';
import pg from '../../services/backend/node_modules/pg/lib/index.js';
import { runPostgresMigrations } from '../../services/backend/src/persistence/postgres/migrator.js';
import { createApp, createPostgresStore } from '../../services/backend/src/server.js';
import { createAccountService } from '../../services/backend/src/application/account-service.js';
import { createSimulatedEmailAdapter } from '../../services/backend/src/infrastructure/simulated-email.js';
import { createFantasyStore } from '../../services/backend/src/application/fantasy/store.js';
const originalUrl=process.env.TEST_DATABASE_URL;
if(!originalUrl)throw new Error('Fantasy Flutter integration requires a disposable TEST_DATABASE_URL.');
const parsed=new URL(originalUrl);
if(!['127.0.0.1','localhost','[::1]'].includes(parsed.hostname)||!parsed.pathname.endsWith('_test'))throw new Error('Disposable loopback test database required.');
const database='fantasy_flutter_'+randomUUID().replaceAll('-','')+'_test';
const admin=new pg.Client({connectionString:originalUrl}); await admin.connect();
await admin.query(`CREATE DATABASE "${database}"`);
parsed.pathname='/'+database; process.env.TEST_DATABASE_URL=parsed.toString();
const proofRoot=await mkdtemp(path.join(tmpdir(),'sentinelle-flutter-proof-'));
const emailAdapter = createSimulatedEmailAdapter();
let time = Date.parse('2026-10-08T00:00:00Z'), store, server, runtimePool;
const quiet={debug(){},info(){},warn(){},error(){}};
async function start(initial=false) {
  const databaseUrl=parsed.toString();
  const pool=new pg.Pool({connectionString:databaseUrl,max:8});
  runtimePool=pool;
  if(initial)await runPostgresMigrations({databaseUrl,attestationDatabaseUrl:databaseUrl,
    sourceCommit:'fantasy-flutter-integration',artifactDigest:'sha256:'+'a'.repeat(64),logger:quiet});
  const cooperationEvents=createCooperationEvents({clock:()=>time});
  const fantasy=await createFantasyStore({pool,now:()=>time,seedDemo:initial,cooperationEvents});
  store=createPostgresStore(pool,{logger:quiet});
  Object.assign(store,{fantasy,close:()=>pool.end()});
  const missionRepository=createMissionRepository(pool,{clock:()=>time});
  if(initial)await missionRepository.seed();
  const missions=createMissionService({cooperationEvents,repository:missionRepository,storage:createLocalProofStorage({root:proofRoot}),clock:()=>time,retentionDays:1});
  const review=createReviewService({cooperationEvents,repository:createReviewRepository(pool,{clock:()=>time}),storage:createLocalProofStorage({root:proofRoot}),clock:()=>time,retentionDays:1});
  const measurements=createMeasurementService({cooperationEvents,repository:createMeasurementRepository(pool,{clock:()=>time}),fantasy,storage:createLocalProofStorage({root:proofRoot}),clock:()=>time});
  server=http.createServer(createApp({cooperation:createCooperationService({pool,fantasy,clock:()=>time}),measurements,review,store,fantasy:store.fantasy,accounts:createAccountService({pool,emailAdapter,clock:()=>time}),missions,leagueContinuityEnabled:true}));
  server.listen(0,'127.0.0.1'); await once(server,'listening');
  return {url:`http://127.0.0.1:${server.address().port}`};
}
async function close(){
  if(server){const closing=server;server=null;await new Promise(resolve=>closing.close(resolve));}
  if(runtimePool){const closing=runtimePool;runtimePool=null;await closing.end();}
}
let cleanupPromise;
function cleanup(){return cleanupPromise??=(async()=>{
  await close();
  await admin.query(`DROP DATABASE "${database}"`);
  await admin.end();
  await rm(proofRoot,{recursive:true,force:true});
})();}
process.once('SIGTERM',()=>{void cleanup().then(()=>process.exit(0));});
try {
console.log(JSON.stringify(await start(true)));
for await(const line of createInterface({input:process.stdin})) {
 try {
  const command=JSON.parse(line);
  if(command.action==='accountCode'){const message=emailAdapter.inspect().filter(m=>m.email===command.value).at(-1);if(!message)throw new Error('Missing synthetic delivery');console.log(JSON.stringify({code:message.code}));continue;}
  if(command.action==='reviewRole'){await createReviewRepository(runtimePool,{clock:()=>time}).setRole(command.value.accountId,command.value.municipalityId,command.value.role,command.value.enabled??true);console.log(JSON.stringify({ok:true}));continue;}
  if(command.action==='missionCapacity'){await runtimePool.query('UPDATE mission_windows SET capacity=$1 WHERE id=$2',[Number(command.value),'synthetic-week-1']);}
  if(command.action==='missionCounts'){const counts=(await runtimePool.query("SELECT (SELECT count(*)::int FROM mission_observations) AS observations,(SELECT count(*)::int FROM mission_bookings WHERE status='active') AS active")).rows[0];console.log(JSON.stringify(counts));continue;}
  if(command.action==='cooperationCalendar'){console.log(JSON.stringify(await publishSyntheticCalendar({pool:runtimePool,input:command.value,loopbackSynthetic:true,clock:()=>time})));continue;}
  if(command.action==='measurementSeed'){const result=await seedSyntheticMeasurementSeason({pool:runtimePool,...command.value,loopbackSynthetic:true});console.log(JSON.stringify(result));continue;}
  if(command.action==='clock')time=Date.parse(command.value);
  if(command.action==='publish') {
    for(const card of (await store.fantasy.cards('tuglie')).items.filter(c=>c.sourceStatus==='verified'))
      await store.fantasy.results.publish('tuglie','matchday-1',card.id,{observed:'stable',sourceLabel:card.sourceLabel,
        sourceDate:'2026-10-15T00:00:00Z',sourceStatus:'verified',explanation:'Fixture sintetica',rulesVersion:'fantasy-demo-v1',version:1});
  }
  if(command.action==='restart'){await close();console.log(JSON.stringify(await start()));continue;}
  if(command.action==='stop')break;
  console.log(JSON.stringify({ok:true}));
 }catch(error){console.log(JSON.stringify({error:error.message}));}
}

} finally {await cleanup();}
