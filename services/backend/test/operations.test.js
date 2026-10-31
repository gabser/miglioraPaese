import assert from 'node:assert/strict';
import {it} from 'node:test';
import http from 'node:http';
import {once} from 'node:events';
import {randomUUID} from 'node:crypto';
import {mkdir,readFile,writeFile,symlink,unlink,lstat} from 'node:fs/promises';
import path from 'node:path';
import pg from 'pg';
import {restoredExposureReady} from '../src/operations/restore-marker.js';
import {createTestStore,integrationTest} from './helpers/fantasy.js';
import {createApp,startServer} from '../src/server.js';
import {createMemoryStore} from '../src/infrastructure/memory-store.js';
import {runtimeIdentity,createRequestObserver} from '../src/operations/diagnostics.js';
import {createErasureJournal} from '../src/operations/erasure-journal.js';
import {testDatabase,disposableDatabase,privateDirectory} from '../src/operations/private-files.js';
import {backupPostgres,restorePostgres} from '../src/operations/backup.js';
import {cleanupProofs} from '../src/operations/retention.js';
import {createLocalProofStorage} from '../src/infrastructure/local-proof-storage.js';
import {createAccountService} from '../src/application/account-service.js';
import {createSimulatedEmailAdapter} from '../src/infrastructure/simulated-email.js';
import {createMissionService} from '../src/application/mission-service.js';
import {createMissionRepository} from '../src/persistence/postgres/mission-repository.js';
const artifactRoot=path.resolve('../../.sentinelle-local/phase8/backend/tests');
async function privateRoot(label){const root=path.join(artifactRoot,label+'-'+randomUUID());await privateDirectory(root,{create:true});return root;}
async function serving(app,callback){const server=http.createServer(app);server.listen(0,'127.0.0.1');await once(server,'listening');try{await callback('http://127.0.0.1:'+server.address().port);}finally{await new Promise(r=>server.close(r));}}
it('candidate configuration, server-generated request IDs, bounded static labels and sink fault readiness',async()=>{
 assert.throws(()=>runtimeIdentity({CANDIDATE_ID:'token'},'memory'),/64/);
 const secret='SECRET_TOKEN_EMAIL_OTP',events=[];let broken=false;
 const observer=createRequestObserver({candidateId:'a'.repeat(64),logger:{info(event){if(broken)throw Error(secret);events.push(event);}}});
 const identity=runtimeIdentity({CANDIDATE_ID:'a'.repeat(64)},'memory');
 await serving(createApp({store:createMemoryStore(),observer,identity}),async base=>{
  let r=await fetch(base+'/health?'+secret,{headers:{'x-request-id':secret,authorization:secret}});const h=await r.json();assert.equal(h.candidateId,'a'.repeat(64));assert.notEqual(r.headers.get('x-request-id'),secret);assert.match(r.headers.get('x-request-id'),/^[a-f0-9-]{36}$/);
  await fetch(base+'/v1/municipalities/'+secret+'/activation');await fetch(base+'/'+secret);
  assert(!JSON.stringify(events).includes(secret));assert(events.some(e=>e.route==='municipalityActivation'));assert(events.some(e=>e.route==='unmatched'));
  broken=true;await fetch(base+'/health');r=await fetch(base+'/ready');assert.equal(r.status,503);assert.equal((await r.json()).dependencies.observability,false);assert(observer.snapshot().logFailures>0);
 });
 assert.throws(()=>startServer({env:{DATA_STORE:'memory',OPS_LOCAL_ENABLED:'true'},port:0}),/Local operations/);
 for(const url of ['postgres://localhost/live','postgres://example.com/source_test','postgres://127.0.0.1/source_test?host=remote'])assert.throws(()=>testDatabase(url));
 assert.throws(()=>disposableDatabase('postgres://localhost/source_test'));
});
it('journal survives interruption, refuses missing/corrupt material and keeps only signed HMAC references',async()=>{
 const root=await privateRoot('journal');let fault=true;
 const journal=await createErasureJournal({root,initialize:true,onCheckpoint:async p=>{if(fault&&p==='erasure_db_committed')throw Error('fault');}});
 let deleted=0;await assert.rejects(journal.erase('account:private-id',async()=>{deleted++;}),/fault/);assert.equal(await journal.isReady(),false);assert.equal(deleted,1);
 await serving(createApp({store:createMemoryStore(),ops:journal}),async base=>{assert.equal((await fetch(base+'/ready')).status,503);assert.equal((await fetch(base+'/v1/proposal-session',{method:'POST'})).status,503);});
 fault=false;await journal.erase('account:private-id',async()=>{deleted++;});assert.equal(await journal.isReady(),true);assert.equal((await journal.read()).entries.length,1);
 const bytes=await readFile(path.join(root,'journal.json'));assert(!bytes.toString().includes('private-id'));await writeFile(path.join(root,'journal.json'),'corrupt',{mode:0o600});assert.equal(await journal.isReady(),false);await assert.rejects(createErasureJournal({root}));await writeFile(path.join(root,'journal.json'),bytes);const keyBytes=await readFile(path.join(root,'journal.key'));await writeFile(path.join(root,'journal.key'),Buffer.alloc(32));assert.equal(await journal.isReady(),false);await writeFile(path.join(root,'journal.key'),keyBytes);const {chmod}=await import('node:fs/promises');await chmod(path.join(root,'journal.key'),0o644);assert.equal(await journal.isReady(),false);await chmod(path.join(root,'journal.key'),0o600);await unlink(path.join(root,'journal.key'));assert.equal(await journal.isReady(),false);await assert.rejects(createErasureJournal({root,initialize:true}),/Incomplete/);
});
integrationTest('real PostgreSQL backup before HTTP account/guest fantasy erase, signed watermark replay and re-enrollment preservation',async()=>{
 const time=()=>Date.parse('2026-10-09T00:00:00Z'),store=await createTestStore({now:time});
 await store.pool.query('TRUNCATE missions,accounts,account_email_codes CASCADE');
 const proofs=await privateRoot('proofs'),journalRoot=await privateRoot('external-journal'),backup=await privateRoot('backup');
 const journal=await createErasureJournal({root:journalRoot,initialize:true}),mail=createSimulatedEmailAdapter(),accounts=createAccountService({pool:store.pool,emailAdapter:mail,clock:time});
 const challenge=await accounts.requestCode({email:'ops-erase@example.invalid'}),account=await accounts.verify({challengeId:challenge.challengeId,code:mail.inspect().at(-1).code});
 const guest=await store.createProposalSession(),other=await store.createProposalSession();
 const user='account:'+account.account.id,guestId='session:'+guest.submissionScope,otherId='session:'+other.submissionScope;
 const restored=[];
 try{
  for(const principal of [user,guestId,otherId])await store.fantasy.teams.enroll('tuglie',principal,{});
  const first=await backupPostgres({databaseUrl:process.env.TEST_DATABASE_URL,proofRoot:proofs,output:backup,journal,candidateId:'b'.repeat(64),writersSuspended:true});assert.equal(first.journalWatermark,0);
  await serving(createApp({store,fantasy:store.fantasy,accounts,ops:journal}),async base=>{for(const token of [account.token,guest.token]){const r=await fetch(base+'/v1/session',{method:'DELETE',headers:{authorization:'Bearer '+token}});assert.equal(r.status,200,JSON.stringify(await r.json()));}});
  assert.equal((await accounts.me(account.token)).account.id,account.account.id);assert.equal((await journal.read()).entries.length,2);
  const restore=async(folder)=>{const target=new URL(process.env.TEST_DATABASE_URL);target.pathname='/sentinelle_restore_'+randomUUID().replaceAll('-','').slice(0,12)+'_test';restored.push(target);const result=await restorePostgres({databaseUrl:target.href,sourceDatabaseUrl:process.env.TEST_DATABASE_URL,backup:folder,proofRoot:await privateRoot('restored-proofs'),journal});assert.equal(result.status,'ready');const pool=new pg.Pool({connectionString:target.href});return {pool,result};};
  const one=await restore(backup);try{assert.equal(await restoredExposureReady(one.pool,{CANDIDATE_ID:'b'.repeat(64),OPS_JOURNAL_ROOT:journalRoot}),true);assert.equal(await restoredExposureReady(one.pool,{CANDIDATE_ID:'a'.repeat(64),OPS_JOURNAL_ROOT:journalRoot}),false);assert.equal(await restoredExposureReady(one.pool,{CANDIDATE_ID:'b'.repeat(64)}),false);assert.equal(one.result.replayed,2);const rows=(await one.pool.query('SELECT user_id FROM fantasy_players')).rows.map(r=>r.user_id);assert(!rows.includes(user));assert(!rows.includes(guestId));assert(rows.includes(otherId));assert.equal((await one.pool.query('SELECT id FROM accounts WHERE id=$1',[account.account.id])).rowCount,1);}finally{await one.pool.end();}
  // An erase before backup2 must not erase a legitimate subsequent enrollment.
  await store.fantasy.teams.enroll('tuglie',user,{});const backup2=await privateRoot('backup2');await backupPostgres({databaseUrl:process.env.TEST_DATABASE_URL,proofRoot:proofs,output:backup2,journal,candidateId:'b'.repeat(64),writersSuspended:true});const two=await restore(backup2);try{assert.equal(two.result.replayed,0);assert.equal((await two.pool.query('SELECT user_id FROM fantasy_players WHERE user_id=$1',[user])).rowCount,1);}finally{await two.pool.end();}
  await assert.rejects(restorePostgres({databaseUrl:process.env.TEST_DATABASE_URL,sourceDatabaseUrl:process.env.TEST_DATABASE_URL,backup,proofRoot:await privateRoot('bad'),journal}),/disposable/);
  const quarantined=new URL(process.env.TEST_DATABASE_URL);quarantined.pathname='/sentinelle_restore_'+randomUUID().replaceAll('-','').slice(0,12)+'_test';restored.push(quarantined);
  await assert.rejects(restorePostgres({databaseUrl:quarantined.href,sourceDatabaseUrl:process.env.TEST_DATABASE_URL,backup,proofRoot:await privateRoot('quarantine-proofs'),journal,onCheckpoint:async stage=>{if(stage==='restore_erasure_applied')throw Error('post-dump-fault');}}),/post-dump-fault/);
  const server=startServer({env:{DATA_STORE:'postgres',DATABASE_URL:quarantined.href},port:0,logger:{info(){},error(){}}});await once(server,'listening');try{const base='http://127.0.0.1:'+server.address().port;assert.equal((await fetch(base+'/ready')).status,503);assert.equal((await fetch(base+'/v1/proposal-session',{method:'POST'})).status,503);}finally{await new Promise(r=>server.close(r));await server.closeResources();}
  const {rename}=await import('node:fs/promises');await rename(path.join(backup,'proofs'),path.join(backup,'original-proofs'));await symlink(proofs,path.join(backup,'proofs'));await assert.rejects(restore(backup),/Unsafe/);await unlink(path.join(backup,'proofs'));await rename(path.join(backup,'original-proofs'),path.join(backup,'proofs'));
  const bytes=await readFile(path.join(backup,'database.dump'));await writeFile(path.join(backup,'database.dump'),bytes.subarray(0,100));await assert.rejects(restore(backup),/Incomplete/);
  await accounts.logout(account.token);await assert.rejects(accounts.me(account.token),e=>e.statusCode===401);
 }finally{await store.close();for(const target of restored){const admin=new URL(target);admin.pathname='/postgres';const c=new pg.Client({connectionString:admin.href});await c.connect();try{await c.query('DROP DATABASE IF EXISTS '+target.pathname.slice(1)+' WITH (FORCE)');}finally{await c.end();}}}
});
integrationTest('retention removes complete/incomplete/chunks/orphans with fault retry, expiry access denial and another account intact',async()=>{
 let time=Date.parse('2026-10-14T10:00:00Z');const store=await createTestStore({now:()=>time}),root=await privateRoot('retention'),storage=createLocalProofStorage({root});
 try{
  await store.pool.query('TRUNCATE missions,accounts,account_email_codes CASCADE');const repo=createMissionRepository(store.pool,{clock:()=>time});await repo.seed();const service=createMissionService({repository:repo,storage,clock:()=>time,retentionDays:1});
  const mail=createSimulatedEmailAdapter(),accounts=createAccountService({pool:store.pool,emailAdapter:mail,clock:()=>time});const login=async email=>{const c=await accounts.requestCode({email});return accounts.verify({challengeId:c.challengeId,code:mail.inspect().at(-1).code});};
  const a=await login('retention-a@example.invalid'),b=await login('retention-b@example.invalid');
  const upload=async(account)=>{const booking=await service.book(account.token,'tuglie','synthetic-cleanliness-tuglie',{windowId:'synthetic-week-1',idempotencyKey:randomUUID()});const u=await service.createUpload(account.token,booking.id,{idempotencyKey:randomUUID(),mimeType:'image/png',totalBytes:5,synthetic:true});await service.chunk(account.token,u.id,{offset:0,dataBase64:Buffer.alloc(5).toString('base64')});return u;};
  const expired=await upload(a),live=await upload(b),orphan=await storage.put(Buffer.from('orphan'));
  const incomplete=await service.createUpload(a.token,expired.bookingId,{idempotencyKey:randomUUID(),mimeType:'image/png',totalBytes:5,synthetic:true});await service.chunk(a.token,incomplete.id,{offset:0,dataBase64:Buffer.alloc(3).toString('base64')});await store.pool.query('UPDATE mission_uploads SET expires_at=$2 WHERE id=$1',[incomplete.id,new Date(time-1).toISOString()]);
  const final=await storage.put(Buffer.from('synthetic-final'));await store.pool.query("UPDATE mission_uploads SET status='complete',file_key=$2 WHERE id=$1",[expired.id,final]);await store.pool.query("UPDATE mission_uploads SET expires_at=$2 WHERE id=$1",[expired.id,new Date(time-1).toISOString()]);
  await assert.rejects(service.proof(a.token,expired.id),e=>e.code==='upload_not_found');
  await assert.rejects(cleanupProofs({pool:store.pool,root,now:time,onCheckpoint:async()=>{throw Error('file-db-fault');}}),/file-db-fault/);
  assert.equal((await store.pool.query('SELECT file_key FROM mission_uploads WHERE id=$1',[expired.id])).rows[0].file_key,final);
  const cleaned=await cleanupProofs({pool:store.pool,root,now:time});assert.equal(cleaned.expiredUploads,2);assert.equal(cleaned.orphans,1);await assert.rejects(storage.get(final));await assert.rejects(storage.get(orphan));assert.equal((await service.getUpload(b.token,live.id)).receivedBytes,5);
  const target=path.join(root,randomUUID());await symlink('/etc/hosts',target);await assert.rejects(cleanupProofs({pool:store.pool,root,now:time}),/Unsafe/);await assert.rejects(storage.get(path.basename(target)),/Unsafe/);await unlink(target);
 }finally{await store.close();}
});
