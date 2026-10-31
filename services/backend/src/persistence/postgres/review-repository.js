import { withTransaction } from './transaction.js';
import { sessionHash } from '../../domain/proposal-session.js';
import { fail,uuid } from '../../domain/missions/rules.js';
const quiet={warn(){},error(){}};
export function createReviewRepository(pool,{clock=Date.now,onCheckpoint=async()=>{}}={}){
 const transaction=action=>withTransaction(pool,async c=>{
  // Same order as account linking, session revocation and mission writes.
  await c.query('SELECT pg_advisory_xact_lock(76131001)');return action(c);
 },{logger:quiet});
 return {
  transaction:(token,action)=>transaction(async c=>{
   const row=(await c.query('SELECT account_id,revoked_at,expires_at FROM proposal_sessions WHERE token_hash=$1 FOR UPDATE',[sessionHash(token)])).rows[0];
   await onCheckpoint('review_session_locked');
   if(!row||row.revoked_at||!row.account_id)fail('account_required','Active verified account required.',401);
   if(row.expires_at&&Date.parse(row.expires_at)<=clock())fail('session_expired','Session expired.',401);
   const result=await action(c,row.account_id);
   if(row.expires_at&&Date.parse(row.expires_at)<=clock())fail('session_expired','Session expired before completion.',401);
   return result;
  }),
  // Local synthetic administration only; no HTTP endpoint can call this adapter.
  setRole:(account,municipality,role,enabled)=>transaction(async c=>{
   uuid(account);if(!['moderator','verifier','outcomesSupervisor'].includes(role)||typeof municipality!=='string'||!municipality||typeof enabled!=='boolean')fail('invalid_field','Invalid local role grant.');
   await c.query('SELECT id FROM accounts WHERE id=$1 FOR UPDATE',[account]);
   if(enabled)await c.query('INSERT INTO review_roles VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[account,municipality,role]);
   else await c.query('DELETE FROM review_roles WHERE account_id=$1 AND municipality_id=$2 AND role=$3',[account,municipality,role]);
  }),
  ready:async()=>{try{
   for(const sql of [
    'SELECT account_id,municipality_id,role FROM review_roles LIMIT 0',
    'SELECT observation_id,place_id,status,revision,assigned_to FROM observation_reviews LIMIT 0',
    'SELECT account_id,command_key,request_hash,response FROM review_commands LIMIT 0',
    'SELECT id,observation_id,action,actor_id,reason,at,revision FROM review_audit LIMIT 0',
    'SELECT id,observation_id,message,requested_at,due_at,status,revision FROM integration_requests LIMIT 0',
    'SELECT id,observation_id,integration_request_id,notes,proofs,submitted_at FROM observation_supplements LIMIT 0',
    'SELECT id,observation_id,account_id,mission_id,municipality_id,place_id,window_id,protocol_version,reason,requested_at,due_at,status FROM replication_requests LIMIT 0',
    'SELECT id,observation_id,account_id,place_id,window_id,window_scope,amount,awarded_at,rule_version,replication_request_id FROM xp_ledger LIMIT 0',
    'SELECT mission_id,place_id FROM mission_places LIMIT 0',
    'SELECT mission_id,season_id,matchday_id,card_id FROM mission_card_links LIMIT 0',
    'SELECT replication_request_id FROM mission_bookings LIMIT 0',
    'SELECT integration_request_id FROM mission_uploads LIMIT 0',
   ])await pool.query(sql);return true;
  }catch{return false;}},
 };
}
