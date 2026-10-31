import pg from 'pg';
import { createReviewRepository } from '../src/persistence/postgres/review-repository.js';
// Explicit local synthetic adapter: no HTTP role provisioning and no user data.
const [command,account,municipality,role]=process.argv.slice(2);
let pool;
try{
 const url=new URL(process.env.DATABASE_URL??'');
 if(!['127.0.0.1','localhost','[::1]'].includes(url.hostname)||!['grant','revoke'].includes(command))throw new Error('Usage: DATABASE_URL=loopback node scripts/review-role.js grant|revoke accountUuid municipality moderator|verifier|outcomesSupervisor');
 if(process.env.EMAIL_DELIVERY!=='simulated')throw new Error('Explicit EMAIL_DELIVERY=simulated required for local synthetic roles.');
 pool=new pg.Pool({connectionString:url.toString()});await createReviewRepository(pool).setRole(account,municipality,role,command==='grant');console.log('Local synthetic role '+command+' completed.');
}catch(error){console.error(error.message);process.exitCode=1;}finally{await pool?.end();}
