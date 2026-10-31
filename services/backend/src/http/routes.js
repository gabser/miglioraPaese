import { httpError } from '../domain/errors.js';

const routePatterns = [
  ['POST', /^\/v1\/auth\/code$/, 'accountCode'],
  ['POST', /^\/v1\/auth\/verify$/, 'accountVerify'],
  ['GET', /^\/v1\/auth\/me$/, 'accountMe'],
  ['GET', /^\/v1\/auth\/devices$/, 'accountDevices'],
  ['POST', /^\/v1\/auth\/logout$/, 'accountLogout'],
  ['POST', /^\/v1\/auth\/profile$/, 'accountProfile'],
  ['POST', /^\/v1\/auth\/guest-link$/, 'accountGuestLink'],
  ['POST', /^\/v1\/auth\/devices\/([^/]+)\/revoke$/, 'accountRevokeDevice'],
  ['GET', /^\/v1\/turns\/([^/]+)\/prediction-results$/, 'predictionResults'],
  ['GET', /^\/v1\/turns\/([^/]+)\/reputation$/, 'reputationScore'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/reputation-history$/, 'reputationHistory'],
  ['GET', /^\/v1\/problems\/([^/]+)\/insight$/, 'aggregatedInsight'],
  ['GET', /^\/v1\/problems\/([^/]+)\/insight-history$/, 'insightHistory'],
  ['GET', /^\/v1\/problems\/([^/]+)\/critical-insights$/, 'criticalInsights'],
  ['POST', /^\/v1\/proposal-session$/, 'createProposalSession'],
  ['GET', /^\/v1\/proposal-session$/, 'getProposalSession'],
  ['POST', /^\/v1\/proposal-session\/revoke$/, 'revokeProposalSession'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/submissions\/([^/]+)$/, 'lookupSubmission'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/next-problems\/([^/]+)\/own$/, 'ownNextProblem'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/activation$/, 'municipalityActivation'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/summary$/, 'municipalitySummary'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/turn$/, 'currentTurn'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/problems$/, 'problems'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/leaderboard$/, 'leaderboard'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/next-problems$/, 'nextProblems'],
  ['POST', /^\/v1\/municipalities\/([^/]+)\/next-problems$/, 'submitNextProblem'],
  ['GET', /^\/v1\/municipalities\/([^/]+)\/next-problems\/([^/]+)$/, 'nextProblem'],
  [
    'POST',
    /^\/v1\/municipalities\/([^/]+)\/next-problems\/([^/]+)\/votes$/,
    'voteNextProblem',
  ],
  ['GET', /^\/v1\/turns\/([^/]+)\/predictions$/, 'predictions'],
  ['PUT', /^\/v1\/turns\/([^/]+)\/predictions\/([^/]+)$/, 'upsertPrediction'],
  ['POST', /^\/v1\/problems\/([^/]+)\/resolve$/, 'resolvePrediction'],
];

export function matchRoute(method, pathname) {
  const cp=pathname.match(/^\/v1\/municipalities\/([^/]+)\/cooperation$/);
  if(cp&&method==='GET')return {name:'cooperationMunicipal',params:{municipalityId:decodeRouteParam(cp[1])}};
  const cl=pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/leagues\/([^/]+)\/cooperation$/);
  if(cl&&method==='GET')return {name:'cooperationLeague',params:{municipalityId:decodeRouteParam(cl[1]),leagueId:decodeRouteParam(cl[2])}};
  if(pathname==='/v1/me/inbox'&&method==='GET')return {name:'cooperationInbox',params:{}};
  const cr=pathname.match(/^\/v1\/me\/inbox\/([^/]+)\/read$/);
  if(cr&&method==='PUT')return {name:'cooperationRead',params:{id:decodeRouteParam(cr[1])}};
  const cf=pathname.match(/^\/v1\/me\/followed-places(?:\/([^/]+))?$/);
  if(cf){const name=!cf[1]&&method==='GET'?'cooperationFollows':cf[1]&&['PUT','DELETE'].includes(method)?'cooperationFollow':null;if(name)return {name,params:{placeId:cf[1]&&decodeRouteParam(cf[1])}};}

  const mp=pathname.match(/^\/v1\/municipalities\/([^/]+)\/measurements(?:\/evaluations\/([^/]+)(?:\/(history))?)?$/);
  if(mp&&method==='GET')return {name:mp[2]?(mp[3]?'measurementsHistory':'measurementsPublished'):'measurementsOverview',params:{municipalityId:decodeRouteParam(mp[1]),id:mp[2]&&decodeRouteParam(mp[2])}};
  const mw=pathname.match(/^\/v1\/measurements\/municipalities\/([^/]+)\/(workspace|problems|interventions|evaluations)(?:\/([^/]+))?(?:\/(protocol-versions|updates|draft-updates|publications|corrections|appeals|proofs)(?:\/([^/]+))?(?:\/(resolutions))?)?$/);
  if(mw){const [,m,resource,id,action,subId,resolution]=mw;const name=method==='GET'?resource==='workspace'&&!id?'measurementsWorkspace':resource==='evaluations'&&id?!action?'measurementsDetail':action==='proofs'&&subId?'measurementsProof':action==='appeals'&&subId?'measurementsAppeal':null:null:method==='POST'&&resource!=='workspace'?((!id&&!action)||(id&&action))?'measurementsCommand':null:null;if(name)return {name,params:{municipalityId:decodeRouteParam(m),resource,id:id&&decodeRouteParam(id),action,resolution,subId:subId&&decodeRouteParam(subId)}};}
  const fh=pathname.match(/^\/v1\/municipalities\/([^/]+)\/fantasy\/seasons\/([^/]+)\/matchdays\/([^/]+)\/results\/history$/);
  if(fh&&method==='GET')return {name:'fantasyResultHistory',params:{municipalityId:decodeRouteParam(fh[1]),seasonId:decodeRouteParam(fh[2]),matchdayId:decodeRouteParam(fh[3])}};
  const review=pathname.match(/^\/v1\/review\/municipalities\/([^/]+)\/(capabilities|observations|proofs)(?:\/([^/]+))?(?:\/(assignment|screening|integration-requests|decisions|replication-requests))?$/);
  if(review){const [,municipalityId,resource,id,action]=review;const name=method==='GET'&&!action?(resource==='capabilities'&&!id?'reviewCapabilities':resource==='observations'?(id?'reviewDetail':'reviewQueue'):resource==='proofs'&&id?'reviewProof':null):method==='POST'&&resource==='observations'&&id&&action?'reviewCommand':null;if(name)return {name,params:{municipalityId:decodeRouteParam(municipalityId),id:id&&decodeRouteParam(id),action}};}
  const ownReview=pathname.match(/^\/v1\/observations\/([^/]+)(?:\/(uploads|supplements))?$/);
  if(ownReview){const [,id,action]=ownReview;const name=method==='GET'&&!action?'reviewOwn':method==='POST'&&action==='uploads'?'reviewUpload':method==='POST'&&action==='supplements'?'reviewSupplement':null;if(name)return {name,params:{id:decodeRouteParam(id)}};}
  const replica=pathname.match(/^\/v1\/replication-requests\/([^/]+)(?:\/(bookings))?$/);
  if(replica&&(method==='GET'&&!replica[2]||method==='POST'&&replica[2]))return {name:replica[2]?'reviewReplicaBooking':'reviewReplica',params:{id:decodeRouteParam(replica[1])}};
  if(method==='GET'&&pathname==='/v1/me/xp')return {name:'reviewXp',params:{}};

  const missionRoute=pathname.match(/^\/v1\/municipalities\/([^/]+)\/missions(?:\/([^/]+))?(?:\/(booking|bookings))?$/);
  if(missionRoute){const [,municipalityId,missionId,action]=missionRoute;const name=!missionId&&method==='GET'?'missionCatalog':missionId&&!action&&method==='GET'?'missionDetail':action==='booking'&&method==='GET'?'missionCurrentBooking':action==='bookings'&&method==='POST'?'missionBook':null;if(name)return {name,params:{municipalityId:decodeRouteParam(municipalityId),missionId:missionId&&decodeRouteParam(missionId)}};}
  const bookingRoute=pathname.match(/^\/v1\/bookings\/([^/]+)(?:\/(release|uploads|observations|receipts\/([^/]+)))?$/);
  if(bookingRoute){const [,bookingId,action,commandKey]=bookingRoute;const name=!action&&method==='GET'?'missionBooking':action==='release'&&method==='POST'?'missionRelease':action==='uploads'&&method==='POST'?'missionCreateUpload':action==='observations'&&method==='POST'?'missionObservation':commandKey&&method==='GET'?'missionReceipt':null;if(name)return {name,params:{bookingId:decodeRouteParam(bookingId),commandKey:commandKey&&decodeRouteParam(commandKey)}};}
  const uploadRoute=pathname.match(/^\/v1\/(uploads|proofs)\/([^/]+)(?:\/(chunks|complete))?$/);
  if(uploadRoute){const [,resource,uploadId,action]=uploadRoute;const name=resource==='proofs'&&!action&&method==='GET'?'missionProof':resource==='uploads'&&!action&&method==='GET'?'missionUpload':resource==='uploads'&&action==='chunks'&&method==='PUT'?'missionUploadChunk':resource==='uploads'&&action==='complete'&&method==='POST'?'missionUploadComplete':null;if(name)return {name,params:{uploadId:decodeRouteParam(uploadId)}};}

  if (method === 'GET' && pathname === '/ready') return {name:'ready',params:{}};
  if (method === 'DELETE' && pathname === '/v1/session') return {name:'fantasyEraseSession',params:{}};
  if(method==='POST'&&pathname==='/v1/fantasy/league-invites/preview')return {name:'fantasyLeaguePreview',params:{}};
  const ownership=pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/leagues\/([^/]+)\/ownership(?:\/offers(?:\/([^/]+)\/(accept|revoke))?)?$/);
  if(ownership){
    const [,municipalityId,leagueId,offerId,action]=ownership;
    const name=method==='GET'&&pathname.endsWith('/ownership')?'fantasyOwnership':method==='POST'&&pathname.endsWith('/offers')?'fantasyOwnershipOffer':method==='POST'&&action==='accept'?'fantasyOwnershipAccept':method==='POST'&&action==='revoke'?'fantasyOwnershipRevoke':null;
    if(name)return {name,params:{municipalityId:decodeRouteParam(municipalityId),leagueId:decodeRouteParam(leagueId),offerId:offerId?decodeRouteParam(offerId):undefined}};
  }
  const fantasyLeague = pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/leagues(?:\/([^/]+))?(?:\/(invites|membership)(?:\/([^/]+))?)?$/);
  if (fantasyLeague) {
    const [, municipalityId, leagueId, action, inviteId] = fantasyLeague;
    const name = !leagueId && method === 'GET' ? 'fantasyLeagueList'
      : !leagueId && method === 'POST' ? 'fantasyLeagueCreate'
      : leagueId === 'join' && !action && method === 'POST' ? 'fantasyLeagueJoin'
      : leagueId && !action && method === 'GET' ? 'fantasyLeagueRead'
      : action === 'invites' && !inviteId && method === 'POST' ? 'fantasyLeagueInvite'
      : action === 'invites' && inviteId && method === 'DELETE' ? 'fantasyLeagueRevoke'
      : action === 'membership' && !inviteId && method === 'DELETE' ? 'fantasyLeagueLeave' : null;
    if (name) return { name, params: { municipalityId: decodeRouteParam(municipalityId), leagueId: leagueId && decodeRouteParam(leagueId), inviteId: inviteId && decodeRouteParam(inviteId) } };
  }

  const fantasyOutcome = pathname.match(/^\/v1\/fantasy\/admin\/municipalities\/([^/]+)\/matchdays\/([^/]+)\/outcomes\/([^/]+)$/);
  if (fantasyOutcome && method === 'PUT') return { name: 'fantasyPublishOutcome', params: { municipalityId: decodeRouteParam(fantasyOutcome[1]), matchdayId: decodeRouteParam(fantasyOutcome[2]), cardId: decodeRouteParam(fantasyOutcome[3]) } };
  const fantasyResult = pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/matchdays\/([^/]+)\/(reveal|summary|cards\/([^/]+)\/reflection)$/);
  if (fantasyResult && ((method === 'GET' && ['reveal', 'summary'].includes(fantasyResult[3])) || (method === 'POST' && fantasyResult[4]))) {
    return { name: fantasyResult[4] ? 'fantasyReflection' : fantasyResult[3] === 'reveal' ? 'fantasyReveal' : 'fantasySummary',
      params: { municipalityId: decodeRouteParam(fantasyResult[1]), matchdayId: decodeRouteParam(fantasyResult[2]), cardId: fantasyResult[4] ? decodeRouteParam(fantasyResult[4]) : undefined } };
  }

  const fantasyTransfer = pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/transfers\/(quote|confirmation)$/);
  if (fantasyTransfer && method === 'POST') {
    return { name: fantasyTransfer[2] === 'quote' ? 'fantasyTransferQuote' : 'fantasyTransferConfirm',
      params: { municipalityId: decodeRouteParam(fantasyTransfer[1]) } };
  }

  const fantasyTeam = pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/(enrollment|team|team\/confirmation)$/);
  if (fantasyTeam) {
    const name = fantasyTeam[2] === 'enrollment' && method === 'POST' ? 'fantasyEnroll'
      : fantasyTeam[2] === 'team' && method === 'GET' ? 'fantasyTeam'
      : fantasyTeam[2] === 'team' && method === 'PUT' ? 'fantasyUpdateTeam'
      : fantasyTeam[2] === 'team/confirmation' && method === 'POST' ? 'fantasyConfirmTeam' : null;
    if (name) return { name, params: { municipalityId: decodeRouteParam(fantasyTeam[1]) } };
  }

  const fantasy = pathname.match(/^\/v1\/fantasy\/municipalities\/([^/]+)\/(season|cards|matchday|matchdays\/([^/]+))$/);
  if (method === 'GET' && fantasy) {
    return { name: fantasy[2] === 'season' ? 'fantasySeason' : fantasy[2] === 'cards' ? 'fantasyCards' : 'fantasyMatchday',
      params: { municipalityId: decodeRouteParam(fantasy[1]), matchdayId: fantasy[3] == null ? undefined : decodeRouteParam(fantasy[3]) } };
  }

  if (method === 'GET' && pathname === '/health') {
    return { name: 'health', params: {} };
  }

  for (const [routeMethod, pattern, name] of routePatterns) {
    const match = pathname.match(pattern);
    if (routeMethod === method && match) {
      return {
        name,
        params: routeParams(name, match),
      };
    }
  }
  return null;
}

function routeParams(name, match) {
  if(name==='accountRevokeDevice')return {deviceId:decodeRouteParam(match[1])};
  if (
    name === 'reputationHistory' ||
    name === 'municipalityActivation' ||
    name === 'municipalitySummary' ||
    name === 'currentTurn' ||
    name === 'problems' ||
    name === 'leaderboard' ||
    name === 'nextProblems' ||
    name === 'submitNextProblem'
  ) {
    return { municipalityId: decodeRouteParam(match[1]) };
  }
  if (name === 'voteNextProblem' || name === 'nextProblem' || name === 'ownNextProblem' || name === 'lookupSubmission') {
    return {
      municipalityId: decodeRouteParam(match[1]),
      problemId: decodeRouteParam(match[2]),
    };
  }
  if (name === 'predictions' || name === 'predictionResults' || name === 'reputationScore') {
    return { turnId: decodeRouteParam(match[1]) };
  }
  if (name === 'upsertPrediction') {
    return {
      turnId: decodeRouteParam(match[1]),
      problemId: decodeRouteParam(match[2]),
    };
  }
  if (name === 'resolvePrediction' || name === 'aggregatedInsight' || name === 'insightHistory' || name === 'criticalInsights') {
    return { problemId: decodeRouteParam(match[1]) };
  }
  return {};
}

function decodeRouteParam(value) {
  try { return decodeURIComponent(value); }
  catch { throw httpError(400, 'invalid_field', 'Path parameters must be valid UTF-8.'); }
}
