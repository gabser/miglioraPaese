import { httpError } from '../domain/errors.js';
import { readJson,getHeader } from './transport.js';
export async function handleReview({req,route,url,review}){
 if(!review)throw httpError(404,'not_found','Review is not enabled.');
 const match=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(getHeader(req,'authorization')??'');if(!match)throw httpError(401,'account_required','Verified account required.');
 const s=await review,t=match[1],p=route.params;
 switch(route.name){
 case 'reviewCapabilities':return s.capabilities(t,p.municipalityId);
 case 'reviewQueue':return s.queue(t,p.municipalityId,url.searchParams.get('status'));
 case 'reviewDetail':return s.detail(t,p.municipalityId,p.id);
 case 'reviewProof':return s.proof(t,p.municipalityId,p.id);
 case 'reviewCommand':return s.command(t,p.municipalityId,p.id,p.action,await readJson(req));
 case 'reviewOwn':return s.own(t,p.id);
 case 'reviewXp':return s.xp(t);
 case 'reviewUpload':return s.createUpload(t,p.id,await readJson(req));
 case 'reviewSupplement':return s.supplement(t,p.id,await readJson(req));
 case 'reviewReplica':return s.replication(t,p.id);
 case 'reviewReplicaBooking':return s.bookReplica(t,p.id,await readJson(req));
 default:throw httpError(404,'not_found','Review resource unavailable.');
 }
}
