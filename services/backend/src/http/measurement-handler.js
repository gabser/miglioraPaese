import {canonicalMunicipalityId} from '../domain/catalog.js';
import {httpError} from '../domain/errors.js';
import {getHeader,readJson} from './transport.js';
export async function handleMeasurements({req,route,url,measurements}){
 const api=await measurements;if(!api)throw httpError(404,'not_found','Measurements are not enabled.');
 const p=route.params,m=canonicalMunicipalityId(p.municipalityId),q={seasonId:url.searchParams.get('seasonId'),matchdayId:url.searchParams.get('matchdayId')};
 for(const [k,v]of Object.entries(q))if(v!==null&&(!v||v.length>128))throw httpError(400,'invalid_field','Invalid '+k+'.');
 if(route.name==='measurementsOverview')return api.overview(m,q);
 if(route.name==='measurementsPublished'||route.name==='measurementsHistory')return api.published(m,p.id,route.name==='measurementsHistory');
 const token=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(getHeader(req,'authorization')??'')?.[1];if(!token)throw httpError(401,'account_required','Active account bearer required.');
 if(route.name==='measurementsWorkspace')return api.workspace(token,m,q);
 if(route.name==='measurementsDetail')return api.detail(token,m,p.id);
 if(route.name==='measurementsProof')return api.proof(token,m,p.id,p.subId);
 if(route.name==='measurementsAppeal')return api.appeal(token,m,p.id,p.subId);
 if(route.name==='measurementsCommand'){
  if(p.resource==='problems'&&p.id&&p.action!=='protocol-versions'||p.resource==='interventions'&&p.id&&p.action!=='updates'||p.resource==='evaluations'&&p.action==='protocol-versions')throw httpError(404,'not_found','Unknown command.');
  return api.command(token,m,p.resolution?'resolutions':p.action??p.resource,p.resolution?{evaluationId:p.id,appealId:p.subId}:p.id,await readJson(req));
 }
 throw httpError(404,'not_found','Measurement resource not found.');
}
