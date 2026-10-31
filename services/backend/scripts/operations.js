import path from 'node:path';
import {createErasureJournal} from '../src/operations/erasure-journal.js';
import {testDatabase} from '../src/operations/private-files.js';
import {backupPostgres,restorePostgres} from '../src/operations/backup.js';
import {cleanupProofs} from '../src/operations/retention.js';
import pg from 'pg';
const env=process.env;
async function main(){
 const [operation]=process.argv.slice(2);if(process.argv.length!==3||!['journal-init','backup','restore','cleanup'].includes(operation))throw Error('Use operations.js journal-init|backup|restore|cleanup with explicit environment.');
 if(env.OPS_LOCAL_ENABLED!=='true'||env.OPS_SYNTHETIC_ACK!=='true')throw Error('Explicit synthetic local operations acknowledgement required.');
 testDatabase(env.DATABASE_URL);
 const journal=await createErasureJournal({root:env.OPS_JOURNAL_ROOT,initialize:operation==='journal-init'});
 if(operation==='journal-init')return {status:'initialized'};
 if(operation==='backup'){const result=await backupPostgres({databaseUrl:env.DATABASE_URL,proofRoot:env.MISSION_STORAGE_ROOT,output:env.OPS_BACKUP_ROOT,journal,candidateId:env.CANDIDATE_ID,environment:env,writersSuspended:env.OPS_WRITERS_SUSPENDED==='true'});return {status:'complete',candidateId:result.candidateId,proofs:result.proofs.length};}
 if(operation==='restore')return restorePostgres({databaseUrl:env.OPS_RESTORE_DATABASE_URL,sourceDatabaseUrl:env.DATABASE_URL,backup:env.OPS_BACKUP_ROOT,proofRoot:env.OPS_RESTORE_PROOF_ROOT,journal});
 if(env.OPS_WRITERS_SUSPENDED!=='true')throw Error('Cleanup requires explicit suspended-writers acknowledgement.');
 await journal.assertReady();const pool=new pg.Pool({connectionString:env.DATABASE_URL});try{return await cleanupProofs({pool,root:env.MISSION_STORAGE_ROOT});}finally{await pool.end();}
}
main().then(result=>console.log(JSON.stringify(result))).catch(()=>{console.error('Local operations failed closed. Inspect private artifacts and reconcile before exposure.');process.exitCode=1;});
