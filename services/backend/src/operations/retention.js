import {readdir,lstat} from 'node:fs/promises';
import path from 'node:path';
import {privateDirectory} from './private-files.js';
import {createLocalProofStorage,proofKeyPattern} from '../infrastructure/local-proof-storage.js';
export const operationsLock=76131801;
export async function cleanupProofs({pool,root,now=Date.now(),onCheckpoint=async()=>{}}){
 await privateDirectory(root);const storage=createLocalProofStorage({root}),client=await pool.connect();
 try{
  await client.query('BEGIN');await client.query('SELECT pg_advisory_xact_lock($1)',[operationsLock]);
  const expired=(await client.query('SELECT id,chunks,file_key FROM mission_uploads WHERE expires_at<=$1 FOR UPDATE',[new Date(now).toISOString()])).rows;
  // Delete bytes before clearing metadata: any interruption keeps retryable pointers.
  for(const row of expired){for(const chunk of row.chunks)await storage.delete(chunk.key);if(row.file_key)await storage.delete(row.file_key);await onCheckpoint('retention_files_deleted');await client.query("UPDATE mission_uploads SET chunks='[]',file_key=NULL WHERE id=$1",[row.id]);}
  const live=(await client.query('SELECT chunks,file_key FROM mission_uploads')).rows;
  const retained=new Set(live.flatMap(r=>[r.file_key,...r.chunks.map(c=>c.key)]).filter(Boolean));
  let orphans=0;
  // The same advisory lock is taken by upload writes and snapshot operations.
  for(const key of await readdir(root)){const stat=await lstat(path.join(root,key));if(stat.isSymbolicLink()||!stat.isFile()||!proofKeyPattern.test(key))throw Error('Unsafe entry in private proof storage.');if(!retained.has(key)){await storage.delete(key);orphans++;}}
  await client.query('COMMIT');return {expiredUploads:expired.length,orphans};
 }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
}
