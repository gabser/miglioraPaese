import path from 'node:path';
import {verifyRestoredDependencies} from './verify-restored.js';
import {runtimeIdentity} from './diagnostics.js';
import {verifiedRestoreMarker} from './restore-marker.js';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {createHash} from 'node:crypto';
import {writeFile,chmod,readdir,lstat} from 'node:fs/promises';
import pg from 'pg';
import {privateDirectory,privateRead,privateWrite,testDatabase,disposableDatabase} from './private-files.js';
import {buildMigrationManifest} from '../persistence/postgres/migration-manifest.js';
import {createFantasyStore} from '../application/fantasy/store.js';
import {proofKeyPattern} from '../infrastructure/local-proof-storage.js';
import {operationsLock} from './retention.js';
const run=promisify(execFile),hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const pgBin='/opt/homebrew/opt/postgresql@17/bin';
function disjoint(...roots){for(let i=0;i<roots.length;i++)for(let j=i+1;j<roots.length;j++)if(roots[i]===roots[j]||roots[i].startsWith(roots[j]+'/')||roots[j].startsWith(roots[i]+'/'))throw Error('Operational private roots must be disjoint.');}
function credentials(url){return {PGHOST:url.hostname==='[::1]'?'::1':url.hostname,PGPORT:url.port||'5432',PGUSER:decodeURIComponent(url.username),PGPASSWORD:decodeURIComponent(url.password),PGDATABASE:decodeURIComponent(url.pathname.slice(1))};}
async function command(name,args,url){try{await run(path.join(pgBin,name),args,{env:{...credentials(url),LANG:'C',PGCONNECT_TIMEOUT:'3'},maxBuffer:1024*1024,timeout:120000});}catch{throw Error('PostgreSQL snapshot command failed.');}}
export async function backupPostgres({databaseUrl,proofRoot,output,journal,candidateId,environment={},writersSuspended=false,onCheckpoint=async()=>{}}){
 const url=testDatabase(databaseUrl);if(!writersSuspended)throw Error('Explicit suspended-writers acknowledgement required.');if(!/^[a-f0-9]{64}$/.test(candidateId??''))throw Error('Identified candidate required.');
 disjoint(proofRoot,output,journal.root);
 await privateDirectory(proofRoot);await privateDirectory(output,{create:true});if((await readdir(output)).length)throw Error('Backup output must be new and empty.');
 const proofs=path.join(output,'proofs');await privateDirectory(proofs,{create:true});
 const pool=new pg.Pool({connectionString:databaseUrl,max:1});
 try{return await journal.withSnapshot(async state=>{
  const client=await pool.connect();
  try{
   if(!['127.0.0.1','::1'].includes((await client.query('SELECT host(inet_server_addr()) AS host')).rows[0].host))throw Error('Loopback PostgreSQL server required.');
   await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');await client.query('SELECT pg_advisory_xact_lock($1)',[operationsLock]);
   const snapshot=(await client.query('SELECT pg_export_snapshot() AS id')).rows[0].id;
   const uploads=(await client.query('SELECT file_key,chunks FROM mission_uploads')).rows;
   const keys=[...new Set(uploads.flatMap(r=>r.file_key?[r.file_key]:r.chunks.map(c=>c.key)).filter(Boolean))].sort();
   const files=[];
   for(const key of keys){if(!proofKeyPattern.test(key))throw Error('Unsafe private proof key.');const bytes=await privateRead(path.join(proofRoot,key),8*1024*1024);await writeFile(path.join(proofs,key),bytes,{mode:0o600,flag:'wx'});files.push({key,sha256:hash(bytes),bytes:bytes.length});}
   await onCheckpoint('backup_proofs_copied');
   await writeFile(path.join(output,'database.dump'),Buffer.alloc(0),{mode:0o600,flag:'wx'});
   await command('pg_dump',['--format=custom','--no-owner','--no-acl','--snapshot='+snapshot,'--file='+path.join(output,'database.dump')],url);await chmod(path.join(output,'database.dump'),0o600);
   const dump=await privateRead(path.join(output,'database.dump'),512*1024*1024);
   const schema=(await client.query('SELECT name FROM pgmigrations ORDER BY id')).rows.map(r=>r.name);
   const manifest={version:1,kind:'synthetic-postgres-snapshot',candidateId,createdAt:new Date().toISOString(),writersSuspended:true,configuration:runtimeIdentity({...environment,CANDIDATE_ID:candidateId,OPS_LOCAL_ENABLED:'true'},'postgres'),journalId:state.id,journalKeyFingerprint:journal.keyFingerprint,journalWatermark:state.entries.length,migrations:await buildMigrationManifest(),schema,dump:{sha256:hash(dump),bytes:dump.length},proofs:files};
   await client.query('COMMIT');await privateWrite(path.join(output,'manifest.json'),JSON.stringify({data:manifest,mac:journal.signManifest(manifest)},null,2));return manifest;
  }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
 });}finally{await pool.end();}
}
export async function restorePostgres({databaseUrl,sourceDatabaseUrl,backup,proofRoot,journal,onCheckpoint=async()=>{}}){
 const target=disposableDatabase(databaseUrl),source=testDatabase(sourceDatabaseUrl);if(target.pathname===source.pathname)throw Error('Restore target must differ from source.');
 disjoint(backup,proofRoot,journal.root);
 await privateDirectory(backup);await privateDirectory(proofRoot,{create:true});if((await readdir(proofRoot)).length)throw Error('Restore proofs must be new and empty.');
 return journal.withSnapshot(async state=>{
  const signed=JSON.parse(await privateRead(path.join(backup,'manifest.json')));if(!journal.verifyManifest(signed.data,signed.mac))throw Error('Invalid backup manifest integrity.');const manifest=signed.data;
  if(manifest.version!==1||manifest.kind!=='synthetic-postgres-snapshot'||manifest.journalId!==state.id||manifest.journalKeyFingerprint!==journal.keyFingerprint||!Array.isArray(manifest.proofs)||manifest.proofs.length>100000)throw Error('Invalid restore manifest or journal binding.');
  const dump=await privateRead(path.join(backup,'database.dump'),512*1024*1024);if(hash(dump)!==manifest.dump.sha256||dump.length!==manifest.dump.bytes)throw Error('Incomplete PostgreSQL backup.');
  if(JSON.stringify(await buildMigrationManifest())!==JSON.stringify(manifest.migrations))throw Error('Restore schema manifest differs from candidate.');
  await privateDirectory(path.join(backup,'proofs'));
  const seen=new Set();for(const file of manifest.proofs){if(!proofKeyPattern.test(file.key)||seen.has(file.key))throw Error('Invalid snapshot proof.');seen.add(file.key);const bytes=await privateRead(path.join(backup,'proofs',file.key),8*1024*1024);if(hash(bytes)!==file.sha256||bytes.length!==file.bytes)throw Error('Incomplete proof snapshot.');await writeFile(path.join(proofRoot,file.key),bytes,{flag:'wx',mode:0o600});}
  // CREATE DATABASE has no IF NOT EXISTS: an existing target is always rejected.
  const adminUrl=new URL(target);adminUrl.pathname='/postgres';const admin=new pg.Client({connectionString:adminUrl.href});await admin.connect();
  try{if(!['127.0.0.1','::1'].includes((await admin.query('SELECT host(inet_server_addr()) AS host')).rows[0].host))throw Error('Loopback restore server required.');await admin.query('CREATE DATABASE '+target.pathname.slice(1)+' TEMPLATE template0 ALLOW_CONNECTIONS false');await admin.query("COMMENT ON DATABASE "+target.pathname.slice(1)+" IS 'sentinelle-restore-pending-v1'");await admin.query('ALTER DATABASE '+target.pathname.slice(1)+' ALLOW_CONNECTIONS true');}finally{await admin.end();}
  await onCheckpoint('restore_database_created');
  await command('pg_restore',['--exit-on-error','--single-transaction','--no-owner','--no-acl','--dbname='+decodeURIComponent(target.pathname.slice(1)),path.join(backup,'database.dump')],target);
  const pool=new pg.Pool({connectionString:target.href});
  try{
   await onCheckpoint('restore_dump_loaded');
   const fantasy=await createFantasyStore({pool});
   const replay=await journal.replay({pool,fantasy,expectedId:manifest.journalId,expectedKeyFingerprint:manifest.journalKeyFingerprint,watermark:manifest.journalWatermark,onCheckpoint});
   await verifyRestoredDependencies({pool,fantasy,configuration:manifest.configuration});
   await onCheckpoint('restore_verified');const marker=verifiedRestoreMarker(journal,{candidateId:manifest.candidateId,journalId:state.id,appliedSequence:state.entries.length});await pool.query("COMMENT ON DATABASE "+target.pathname.slice(1)+" IS '"+marker+"'");return {status:'ready',candidateId:manifest.candidateId,replayed:replay.erased,proofs:manifest.proofs.length};
  }finally{await pool.end();}
 });
}
