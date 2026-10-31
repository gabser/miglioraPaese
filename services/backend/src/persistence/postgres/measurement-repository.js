import {unitOfWork} from './unit-of-work.js';
import {measurementStatements} from './measurement-statements.js';
import {sessionHash} from '../../domain/proposal-session.js';
import {fail} from '../../domain/measurements/rules.js';
export function createMeasurementRepository(pool,{clock=Date.now,onCheckpoint=async()=>{}}={}){
 const uow=unitOfWork(pool);
 const query=(c,name,args=[])=>{if(!measurementStatements[name])throw new TypeError('Unknown measurement statement.');return c.query(measurementStatements[name],args);};
 return {query,one:async(c,n,args)=>(await query(c,n,args)).rows[0],many:async(c,n,args)=>(await query(c,n,args)).rows,
  transaction:(token,action)=>uow.run(async c=>{
   let account=null;
   if(token){const r=(await query(c,'session',[sessionHash(token)])).rows[0];await onCheckpoint('measurement_session_locked');if(!r||r.revoked_at||!r.account_id)fail('account_required','Active verified account required.',401);if(r.expires_at&&Date.parse(r.expires_at)<=clock())fail('session_expired','Session expired.',401);account=r.account_id;}
   const result=await action(c,account);
   if(token){const r=(await query(c,'session',[sessionHash(token)])).rows[0];if(!r||r.revoked_at||!r.account_id)fail('account_required','Active account required.',401);if(r.expires_at&&Date.parse(r.expires_at)<=clock())fail('session_expired','Session expired before commit.',401);}
   return result;
  }),
  ready:async()=>{try{await pool.query('SELECT id FROM measurement_evaluations LIMIT 0');await pool.query('SELECT result_revision FROM fantasy_result_revisions LIMIT 0');return true;}catch{return false;}},
 };
}
