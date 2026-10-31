import { httpError } from '../domain/errors.js';
import { readJson,getHeader } from './transport.js';
import { exact } from '../domain/missions/rules.js';
export async function handleMission({req,route,url,missions}) {
 if(!missions)throw httpError(404,'not_found','Missions are not enabled.');
 const s=await missions,p=route.params;
 if(route.name==='missionCatalog')return s.catalog(p.municipalityId,url.searchParams.get('zoneId'));
 if(route.name==='missionDetail')return s.detail(p.municipalityId,p.missionId);
 const match=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(getHeader(req,'authorization')??'');if(!match)throw httpError(401,'account_required','Verified account required.');const token=match[1];
 switch(route.name){
 case 'missionBook':return s.book(token,p.municipalityId,p.missionId,await readJson(req));
 case 'missionCurrentBooking':return s.current(token,p.municipalityId,p.missionId);
 case 'missionBooking':return s.getBooking(token,p.bookingId);
 case 'missionRelease':return s.release(token,p.bookingId,await readJson(req));
 case 'missionCreateUpload':return s.createUpload(token,p.bookingId,await readJson(req));
 case 'missionUpload':return s.getUpload(token,p.uploadId);
 case 'missionUploadChunk':return s.chunk(token,p.uploadId,await readJson(req));
 case 'missionUploadComplete':exact(await readJson(req),[]);return s.complete(token,p.uploadId);
 case 'missionProof':return s.proof(token,p.uploadId);
 case 'missionObservation':return s.submit(token,p.bookingId,await readJson(req));
 case 'missionReceipt':return s.receipt(token,p.bookingId,p.commandKey);
 default:throw httpError(404,'not_found','Mission route unavailable.');
 }
}
