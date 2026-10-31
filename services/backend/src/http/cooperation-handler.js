import {httpError} from '../domain/errors.js';
import {getHeader,readJson} from './transport.js';
import {exact} from '../domain/missions/rules.js';
export async function handleCooperation({req,route,url,cooperation,pilotMunicipalityId}){
 if(!cooperation)throw httpError(404,'not_found','Cooperation is not enabled.');
 const api=await cooperation,p=route.params;
 const allowed=route.name==='cooperationMunicipal'?['seasonId','matchdayId']:route.name==='cooperationLeague'?['matchdayId']:route.name==='cooperationInbox'?['municipalityId','limit','cursor']:route.name==='cooperationRead'?[]:['municipalityId'];
 const q={};for(const [k,v]of url.searchParams){if(!allowed.includes(k)||Object.hasOwn(q,k))throw httpError(400,'invalid_field','Unsupported or duplicate query.');q[k]=v;}
 const municipalityId=p.municipalityId??q.municipalityId;
 if(pilotMunicipalityId&&municipalityId&&municipalityId!==pilotMunicipalityId)throw httpError(404,'not_found','Municipality outside pilot.');
 if(route.name==='cooperationMunicipal')return api.municipal(p.municipalityId,q);
 const match=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(getHeader(req,'authorization')??'');if(!match)throw httpError(401,'account_required','Verified account required.');
 const t=match[1];
 if(route.name==='cooperationLeague')return api.league(t,p.municipalityId,p.leagueId,q);
 if(route.name==='cooperationInbox')return api.inbox(t,q);
 if(route.name==='cooperationFollows')return api.follows(t,q.municipalityId);
 exact(await readJson(req),[]);
 if(route.name==='cooperationRead')return api.read(t,p.id);
 return api.follow(t,q.municipalityId,p.placeId,req.method==='PUT');
}
