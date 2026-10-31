import { timingSafeEqual } from 'node:crypto';
import { canonicalMunicipalityId } from '../domain/catalog.js';
import { sessionIdentity } from '../domain/proposal-session.js';
import { httpError } from '../domain/errors.js';
import { getHeader, readJson } from './transport.js';

export async function handleFantasy({req,route,url,backend,fantasy,adminToken,pilotMunicipalityId,leagueContinuityEnabled=false,ops}) {
  const originalApi = await fantasy;
  const hint=url.searchParams.get('seasonId');
  if(hint!==null&&(!hint||hint.length>128))throw httpError(400,'invalid_field','Invalid seasonId.');
  const api=originalApi;
  if (!api) throw httpError(404,'not_found','Fantasy is not enabled.');
  const municipalityId = route.params.municipalityId===undefined?undefined:canonicalMunicipalityId(route.params.municipalityId.replace(/^comune:/i,'').trim().toLowerCase().replace(/\s+/g,'-'));
  if (pilotMunicipalityId && municipalityId && municipalityId !== pilotMunicipalityId) throw httpError(404,'not_found','Municipality is outside the pilot.');
  const continuityRoute=route.name==='fantasyLeaguePreview'||route.name.startsWith('fantasyOwnership');
  if(continuityRoute&&!leagueContinuityEnabled)throw httpError(404,'not_found','League continuity is not enabled.');
  if(route.name==='fantasyLeaguePreview'){
    if(url.search)throw httpError(400,'invalid_field','Preview accepts only a JSON body.');
    return api.leagues.preview(await readJson(req),{pilotMunicipalityId,rateBucket:req.socket?.remoteAddress??'local'});
  }
  return api.scoped(hint??route.params.seasonId??null,async()=>{
  if (route.name === 'fantasyPublishOutcome') {
    // Publication is a separately configured local operator capability.
    if (getHeader(req,'origin')) throw httpError(403,'forbidden','Publication is only available to the local operator.');
    const given=getHeader(req,'x-admin-token');
    const expected=typeof adminToken==='string'?Buffer.from(adminToken):null;
    if (!expected?.length || typeof given!=='string' || Buffer.byteLength(given)!==expected.length || !timingSafeEqual(Buffer.from(given),expected)) throw httpError(401,'admin_required','Local publication authorization is required.');
    return api.results.publish(municipalityId,route.params.matchdayId,route.params.cardId,await readJson(req));
  }
  if (route.name==='fantasySeason') return api.season(municipalityId);
  if (route.name==='fantasyCards') return api.cards(municipalityId);
  if (route.name==='fantasyMatchday') return api.matchday(municipalityId,route.params.matchdayId);
  const match=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(getHeader(req,'authorization')??'');
  if (!match) throw httpError(401,'proposal_session_required','A valid proposal session is required.');
  const token=match[1],userId=sessionIdentity(await backend.getProposalSession(token));
  // No IDs controlled by the client participate in identity or data ownership.
  if (url.searchParams.has('userId')) throw httpError(400,'invalid_field','userId is not accepted.');
  return api.authenticated(token, async()=> {
    const p=route.params;
    if(route.name==='fantasyOwnership')return api.leagues.ownership(municipalityId,userId,p.leagueId);
    if(route.name.startsWith('fantasyOwnership'))return api.leagues.ownershipCommand(municipalityId,userId,p.leagueId,route.name==='fantasyOwnershipOffer'?'offer':route.name==='fantasyOwnershipAccept'?'accept':'revoke',p.offerId,await readJson(req));
    if(route.name==='fantasyResultHistory')return api.results.history(municipalityId,userId,p.matchdayId);
    if (route.name==='fantasyEraseSession') return ops?ops.erase(userId,()=>api.eraseUserData(userId)):api.eraseUserData(userId);
    if (route.name==='fantasyTeam') {
      try {return await api.teams.team(municipalityId,userId,url.searchParams.get('matchdayId'));}
      catch(error) {if(error.code==='not_found' && /enrollment/i.test(error.message)) error.code='team_not_found';throw error;}
    }
    if (route.name==='fantasyEnroll') return api.teams.enroll(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyUpdateTeam') return api.teams.update(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyConfirmTeam') return api.teams.confirm(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyTransferQuote') return api.market.quote(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyTransferConfirm') return api.market.confirm(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyReflection') return api.results.reflect(municipalityId,userId,p.matchdayId,p.cardId,await readJson(req));
    if (route.name==='fantasyReveal'||route.name==='fantasySummary') return api.results.read(municipalityId,userId,p.matchdayId);
    if (route.name==='fantasyLeagueList') return api.leagues.list(municipalityId,userId);
    if (route.name==='fantasyLeagueRead') return api.leagues.read(municipalityId,userId,p.leagueId);
    if (route.name==='fantasyLeagueCreate') return api.leagues.create(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyLeagueJoin') return api.leagues.join(municipalityId,userId,await readJson(req));
    if (route.name==='fantasyLeagueInvite') return api.leagues.invite(municipalityId,userId,p.leagueId,await readJson(req));
    if (route.name==='fantasyLeagueRevoke') return api.leagues.revoke(municipalityId,userId,p.leagueId,p.inviteId);
    if (route.name==='fantasyLeagueLeave') return api.leagues.leave(municipalityId,userId,p.leagueId);
    throw httpError(404,'not_found','Fantasy resource not found.');
  }, userId);
  });
}
