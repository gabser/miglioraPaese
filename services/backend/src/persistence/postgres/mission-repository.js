import { missionStatements } from './mission-statements.js';
import { withTransaction } from './transaction.js';
import { sessionHash,sessionRevoked } from '../../domain/proposal-session.js';
import { httpError } from '../../domain/errors.js';
const quiet={warn(){},error(){}};
export function createMissionRepository(pool,{clock=Date.now,onCheckpoint=async()=>{}}={}) {
 return {
  query:(operation,values=[],client=pool)=>{const sql=missionStatements[operation];if(!sql)throw new TypeError('Unknown mission operation.');return client.query(sql,values);},
  transaction:(token,action)=>withTransaction(pool,async client=>{
   await client.query('SELECT pg_advisory_xact_lock(76131801)');
   // Serialize allocation and account revocation/linking in a consistent order.
   await client.query('SELECT pg_advisory_xact_lock(76131001)');
   const row=(await client.query('SELECT account_id,revoked_at,expires_at FROM proposal_sessions WHERE token_hash=$1 FOR UPDATE',[sessionHash(token)])).rows[0];
   if(!row||row.revoked_at)throw sessionRevoked();
   if(row.expires_at&&Date.parse(row.expires_at)<=clock())throw httpError(401,'session_expired','Session has expired.');
   if(!row.account_id)throw httpError(401,'account_required','Verified account required.');
   await onCheckpoint('mission_session_locked');
   return action(client,row.account_id);
  },{logger:quiet}),
  seed:()=>withTransaction(pool,async c=>{
   await c.query('SELECT pg_advisory_xact_lock(76131001)');
   const protocol={id:'synthetic-cleanliness-v1',version:1,instructions:['Fixture locale: osserva soltanto file e luoghi sintetici.','Area pubblica di prova delimitata fra i quattro angoli descritti.','Non entrare in aree pericolose; puoi rinunciare senza penalità.'],photoPoints:[{id:'entrance',label:'Punto A: ingresso sintetico, rivolto verso il centro'}],minPhotos:1,indicator:'Numero di rifiuti visibili lungo il percorso sintetico',threshold:'Almeno un rifiuto visibile; protocollo dimostrativo non ratificato'};
   await c.query('INSERT INTO missions VALUES($1,$2,$3,$4,$5,$6,15,true) ON CONFLICT DO NOTHING',['synthetic-cleanliness-tuglie','tuglie','synthetic-centre','Pulizia area pubblica — prova sintetica',JSON.stringify({label:'Area sintetica di prova',boundary:'Quadrilatero dimostrativo A–B–C–D; nessuna ubicazione reale',public:true}),JSON.stringify(protocol)]);
   for(let i=0;i<4;i++){const start=Date.parse('2026-10-14T00:00:00Z')+i*7*86400000;await c.query('INSERT INTO mission_windows VALUES($1,$2,$3,$4,2) ON CONFLICT DO NOTHING',['synthetic-week-'+(i+1),'synthetic-cleanliness-tuglie',new Date(start).toISOString(),new Date(start+7*86400000).toISOString()]);}
  },{logger:quiet}),
  ready:async()=>{try{for(const op of ['probeMissions','probeWindows','probeBookings','probeUploads','probeObservations'])await pool.query(missionStatements[op]);return true;}catch{return false;}},
 };
}
