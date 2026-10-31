import {createErasureJournal} from './erasure-journal.js';
export const restoreMarkerPrefix='sentinelle-restore-v1:';
export async function restoredExposureReady(pool,env){
 const result=await pool.query("SELECT COALESCE(shobj_description(oid,'pg_database'),'') AS marker FROM pg_database WHERE datname=current_database()");
 const marker=result.rows[0]?.marker;if(typeof marker!=='string')return false;
 if(!marker.startsWith('sentinelle-restore-'))return true;
 try{
  if(!marker.startsWith(restoreMarkerPrefix)||marker.length>2048)return false;
  const signed=JSON.parse(Buffer.from(marker.slice(restoreMarkerPrefix.length),'base64url').toString());
  const journal=await createErasureJournal({root:env.OPS_JOURNAL_ROOT}),state=await journal.assertReady(),data=signed.data;
  return journal.verifyMarker(data,signed.mac)&&data.state==='verified'&&data.candidateId===env.CANDIDATE_ID&&data.journalId===state.id&&data.appliedSequence===state.entries.length;
 }catch{return false;}
}
export function verifiedRestoreMarker(journal,{candidateId,journalId,appliedSequence}){const data={state:'verified',candidateId,journalId,appliedSequence};return restoreMarkerPrefix+Buffer.from(JSON.stringify({data,mac:journal.signMarker(data)})).toString('base64url');}
