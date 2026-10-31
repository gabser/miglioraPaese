import {runtimeIdentity} from '../operations/diagnostics.js';
import {randomUUID} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {handleCooperation} from './cooperation-handler.js';
import {handleMeasurements} from './measurement-handler.js';
import { handleReview } from './review-handler.js';
import { handleMission } from './mission-handler.js';
import { handleFantasy } from './fantasy-handler.js';
import { sessionIdentity } from '../domain/proposal-session.js';
import { httpError } from '../domain/errors.js';
import { URL } from 'node:url';
import { normalizeProposalLocation, proposalLimits, proposalText } from '../domain/proposal-location.js';

import { createBackendService } from '../application/backend-service.js';
import { normalizeAllowedOrigins } from '../config/environment.js';
import {
  confidenceValues,
  inputLimits,
  motivationValues,
  predictionChoices,
  problemKeys,
  suggestedProblemStatuses,
  voteChoices,
} from '../domain/catalog.js';
import { matchRoute } from './routes.js';
import {
  corsHeadersForRequest,
  getHeader,
  readJson,
  sendJson,
} from './transport.js';
import {
  optionalEnum,
  optionalText,
  requireEnum,
  requireEnumArray,
  requireIdempotencyKey,
  requireText,
  textOrDefault,
} from './validation.js';

export function createApp(options = {}) {
  if (!options.application && !options.store) {
    throw new TypeError('createApp requires an explicit application or store.');
  }
  const identity=options.identity??runtimeIdentity(Object.fromEntries(Object.entries({FANTASY_ENABLED:options.fantasy,ACCOUNT_ENABLED:options.accounts,MISSIONS_ENABLED:options.missions,REVIEW_ENABLED:options.review,MEASUREMENTS_ENABLED:options.measurements,LEAGUE_CONTINUITY_ENABLED:options.leagueContinuityEnabled,COOPERATION_ENABLED:options.cooperation,OPS_LOCAL_ENABLED:options.ops}).map(([name,value])=>[name,value?'true':'false'])),options.store?.pool?'postgres':'memory');
  const backend = options.application ?? createBackendService(options.store);
  const allowedOrigins = normalizeAllowedOrigins(
    options.allowedOrigins ?? process.env.CORS_ALLOWED_ORIGINS,
  );

  return async function app(req, res) {
    const requestId=randomUUID(),startedAt=performance.now();
    let observedRoute='unmatched';
    const finish=()=>options.observer?.record({route:observedRoute,status:res.statusCode??res.status??500,durationMs:performance.now()-startedAt,requestId});
    let responseHeaders = {'x-request-id':requestId};
    try {
      const url = new URL(req.url ?? '/', 'http://localhost');
      const cors = corsHeadersForRequest(req, allowedOrigins);
      responseHeaders = {...cors.headers,'x-request-id':requestId};
      if (!cors.allowed) {
        return sendJson(
          res,
          403,
          {
            error: 'origin_not_allowed',
            message: 'Request origin is not allowed.',
          },
          responseHeaders,
        );
      }

      if ((req.method ?? 'GET') === 'OPTIONS') {
        const requestedMethod = getHeader(req, 'access-control-request-method');
        if (!cors.origin || !requestedMethod) {
          return sendJson(
            res,
            400,
            {
              error: 'invalid_cors_request',
              message: 'Origin and access-control-request-method are required.',
            },
            responseHeaders,
          );
        }
        if (!matchRoute(requestedMethod.toUpperCase(), url.pathname)) {
          return sendJson(res, 404, { error: 'not_found' }, responseHeaders);
        }
        return sendJson(res, 200, { status: 'ok' }, responseHeaders);
      }

      const route = matchRoute(req.method ?? 'GET', url.pathname);

      observedRoute=route?.name??'unmatched';
      if (!route) {
        return sendJson(res, 404, { error: 'not_found' }, responseHeaders);
      }

      if (route.name === 'ready') {
        const dependencies={};
        const checks={restoreVerification:()=>options.exposureReady?.()??true,persistence:()=>options.readiness?.()??options.store?.isReady?.()??true,
          observability:()=>options.observer?.isReady()??true,
          erasureJournal:()=>options.ops?.isReady()??true};
        for(const name of ['cooperation','measurements','review','missions','accounts','fantasy'])if(options[name])checks[name]=async()=>{const service=await options[name];return service.isReady();};
        for(const [name,check] of Object.entries(checks)){try{dependencies[name]=await check()!==false;}catch{dependencies[name]=false;}}
        const ready=Object.values(dependencies).every(Boolean);
        return sendJson(res,ready?200:503,{...(ready?{status:'ready'}:{error:'service_unavailable',message:'Required dependencies are not ready.'}),...identity,dependencies},responseHeaders);
      }

      if (route.name === 'health') {
        return sendJson(res, 200, { status: 'ok',...identity }, responseHeaders);
      }
      if(options.exposureReady&&!await options.exposureReady())throw httpError(503,'service_unavailable','Restored copy requires verification.');
      // An uncertain external erasure must be reconciled before exposing data.
      if(options.ops&&!await options.ops.isReady()&&route.name!=='fantasyEraseSession')throw httpError(503,'service_unavailable','Local operations require reconciliation.');

      if(route.name.startsWith('cooperation'))return sendJson(res,200,await handleCooperation({req,route,url,cooperation:options.cooperation,pilotMunicipalityId:options.pilotMunicipalityId}),{...responseHeaders,'cache-control':'no-store'});
      if(route.name.startsWith('measurements')){responseHeaders={...responseHeaders,'cache-control':'no-store'};return sendJson(res,200,await handleMeasurements({req,route,url,measurements:options.measurements}),responseHeaders);}
      if(route.name.startsWith('review')){responseHeaders={...responseHeaders,'cache-control':'no-store'};return sendJson(res,200,await handleReview({req,route,url,review:options.review}),responseHeaders);}

      if(route.name.startsWith('mission'))return sendJson(res,200,await handleMission({req,route,url,missions:options.missions}),{...responseHeaders,'cache-control':'no-store'});

      if(route.name.startsWith('account')) {
        const accounts=options.accounts;if(!accounts)throw httpError(404,'not_found','Accounts are not enabled.');
        let result;
        if(route.name==='accountCode')result=await accounts.requestCode(await readJson(req));
        else if(route.name==='accountVerify')result=await accounts.verify(await readJson(req));
        else {
          const match=/^Bearer ([A-Za-z0-9_-]{43})$/.exec(getHeader(req,'authorization')??'');
          if(!match)throw httpError(401,'account_required','An account session is required.');
          const token=match[1];
          if(route.name==='accountMe')result=await accounts.me(token);
          if(route.name==='accountDevices')result=await accounts.devices(token);
          if(route.name==='accountLogout')result=await accounts.logout(token);
          if(route.name==='accountRevokeDevice')result=await accounts.revokeDevice(token,route.params.deviceId);
          if(route.name==='accountProfile')result=await accounts.profile(token,await readJson(req));
          if(route.name==='accountGuestLink')result=await accounts.linkGuest(token,await readJson(req));
        }
        return sendJson(res,200,result,{...responseHeaders,'cache-control':'no-store'});
      }

      if (route.name.startsWith('fantasy')) {
        responseHeaders={...responseHeaders,'cache-control':'no-store','referrer-policy':'no-referrer'};
        const result = await handleFantasy({req,route,url,backend,fantasy:options.fantasy,adminToken:options.adminToken,pilotMunicipalityId:options.pilotMunicipalityId,leagueContinuityEnabled:options.leagueContinuityEnabled===true,ops:options.ops});
        return sendJson(res,200,result,{...responseHeaders,'cache-control':'no-store'});
      }

      const authorization = getHeader(req, 'authorization');
      let sessionToken = null;
      const proposalRoutes = new Set(['createProposalSession', 'getProposalSession',
        'revokeProposalSession', 'lookupSubmission', 'ownNextProblem',
        'nextProblems', 'nextProblem', 'submitNextProblem', 'voteNextProblem', 'predictions', 'upsertPrediction', 'resolvePrediction', 'predictionResults', 'reputationScore', 'reputationHistory']);
      if (authorization !== null && proposalRoutes.has(route.name)) {
        const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(authorization);
        if (!match) throw httpError(401, 'proposal_session_required', 'A valid proposal session is required.');
        sessionToken = match[1];
      }
      const privateSession = () => {
        if (!sessionToken) throw httpError(401, 'proposal_session_required', 'A valid proposal session is required.');
        return sessionToken;
      };
      const sessionCapabilities = { proposalLocation: true, publicDetail: true,
        privateSubmissionLookup: true, scopedIdempotency: true, revocation: true,
        sessionRequiredForRecovery: true };
      if (route.name === 'createProposalSession') {
        const session = await backend.createProposalSession();
        return sendJson(res, 201, { ...session, capabilities: sessionCapabilities },
          { ...responseHeaders, 'cache-control': 'no-store' });
      }
      if (route.name === 'getProposalSession') {
        const session = await backend.getProposalSession(privateSession(),url.searchParams.get('submissionScope'));
        return sendJson(res, 200, { ...session, capabilities: sessionCapabilities },
          { ...responseHeaders, 'cache-control': 'no-store' });
      }
      if (route.name === 'revokeProposalSession') {
        return sendJson(res, 200, await backend.revokeProposalSession(privateSession()),
          { ...responseHeaders, 'cache-control': 'no-store' });
      }
      if (route.name === 'lookupSubmission') {
        return sendJson(res, 200, await backend.lookupSubmission({
          municipalityId: route.params.municipalityId,
          idempotencyKey: requireIdempotencyKey(route.params.problemId),
          sessionToken: privateSession(),
          submissionScope:url.searchParams.get('submissionScope'),
        }), { ...responseHeaders, 'cache-control': 'no-store' });
      }
      if (route.name === 'ownNextProblem') {
        return sendJson(res, 200, await backend.getOwnNextProblem({
          ...route.params, sessionToken: privateSession(),
        }), { ...responseHeaders, 'cache-control': 'no-store' });
      }

      if (['predictionResults','reputationScore','reputationHistory','aggregatedInsight','insightHistory','criticalInsights'].includes(route.name)) {
        const remote=options.remoteGame;
        if(!remote) throw httpError(404,'not_found','Remote game is not configured.');
        const p=route.params;
        let result;
        if(route.name==='predictionResults') result=await remote.getPredictionResults({turnId:p.turnId,sessionToken:privateSession()});
        if(route.name==='reputationScore') result=await remote.getReputationScore({turnId:p.turnId,sessionToken:privateSession()});
        if(route.name==='reputationHistory') result=await remote.getReputationHistory({municipalityId:p.municipalityId,sessionToken:privateSession()});
        if(route.name==='aggregatedInsight') result=await remote.getAggregatedInsight(p.problemId);
        if(route.name==='insightHistory') result=await remote.getInsightHistory(p.problemId);
        if(route.name==='criticalInsights') {
          const raw=url.searchParams.get('userReflectionIndex');
          if(raw!==null && !/^\d+$/.test(raw)) throw httpError(400,'invalid_field','Invalid reflection index.');
          result=await remote.getCriticalInsights({problemId:p.problemId,userChoice:optionalEnum(url.searchParams.get('userChoice'),predictionChoices,'userChoice'),userConfidence:optionalEnum(url.searchParams.get('userConfidence'),confidenceValues,'userConfidence'),userReflectionIndex:raw===null?null:Number(raw)});
        }
        return sendJson(res,200,result,sessionToken?{...responseHeaders,'cache-control':'no-store'}:responseHeaders);
      }

      if (route.name === 'municipalityActivation') {
        return sendJson(
          res,
          200,
          await backend.getMunicipalityActivation(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'municipalitySummary') {
        return sendJson(
          res,
          200,
          await backend.getCivicLoopSummary(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'currentTurn') {
        return sendJson(
          res,
          200,
          await backend.getCurrentTurn(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'problems') {
        return sendJson(
          res,
          200,
          await backend.listProblems(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'leaderboard') {
        return sendJson(
          res,
          200,
          await backend.getLeaderboard(route.params.municipalityId),
          responseHeaders,
        );
      }

      const identifiedSession = sessionToken !== null &&
        ['nextProblems','nextProblem','predictions','upsertPrediction'].includes(route.name)
        ? await backend.getProposalSession(sessionToken) : null;
      const proposalUserId = identifiedSession ? sessionIdentity(identifiedSession) : null;

      if (route.name === 'nextProblems') {
        return sendJson(
          res,
          200,
          await backend.listNextProblems({
            sessionToken,
            municipalityId: route.params.municipalityId,
            status: optionalEnum(
              url.searchParams.get('status'),
              suggestedProblemStatuses,
              'status',
            ),
            query: optionalText(
              url.searchParams.get('query'),
              'query',
              inputLimits.queryLength,
            ),
            userId: proposalUserId ?? textOrDefault(
              url.searchParams.get('userId'),
              'demo-user',
              'userId',
              inputLimits.userIdLength,
            ),
          }),
          sessionToken?{...responseHeaders,'cache-control':'no-store'}:responseHeaders,
        );
      }

      if (route.name === 'nextProblem') {
        const item = await backend.getNextProblem({
          sessionToken,
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          userId: proposalUserId ?? textOrDefault(url.searchParams.get('userId'), 'demo-user',
            'userId', inputLimits.userIdLength),
        });
        return sendJson(res, 200, item, sessionToken?{...responseHeaders,'cache-control':'no-store'}:responseHeaders);
      }

      if (route.name === 'submitNextProblem') {
        const body = await readJson(req);
        const created = await backend.submitNextProblem({
          sessionToken,
          idempotencyKey: requireIdempotencyKey(
            getHeader(req, 'idempotency-key'),
          ),
          municipalityId: route.params.municipalityId,
          title: proposalText(body.title, 'title', proposalLimits.title),
          description: proposalText(
            body.description,
            'description',
            proposalLimits.description,
          ),
          category: requireEnum(body.category, problemKeys, 'category'),
          location: normalizeProposalLocation(body.location),
          userId: proposalUserId ?? textOrDefault(
            body.userId,
            'demo-user',
            'userId',
            inputLimits.userIdLength,
          ),
        });
        return sendJson(res, 201, created, responseHeaders);
      }

      if (route.name === 'voteNextProblem') {
        const body = await readJson(req);
        const updated = await backend.voteNextProblem({
          sessionToken,
          idempotencyKey: requireIdempotencyKey(
            getHeader(req, 'idempotency-key'),
          ),
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          vote: requireEnum(body.vote, voteChoices, 'vote'),
          userId: proposalUserId ?? textOrDefault(
            body.userId,
            'demo-user',
            'userId',
            inputLimits.userIdLength,
          ),
        });
        return sendJson(res, 200, updated, responseHeaders);
      }

      if (route.name === 'predictions') {
        return sendJson(
          res,
          200,
          await backend.getPredictions({
            sessionToken,
            turnId: route.params.turnId,
            userId: proposalUserId ?? textOrDefault(
              url.searchParams.get('userId'),
              'demo-user',
              'userId',
              inputLimits.userIdLength,
            ),
          }),
          sessionToken ? { ...responseHeaders, 'cache-control': 'no-store' } : responseHeaders,
        );
      }

      if (route.name === 'upsertPrediction') {
        const body = await readJson(req);
        const prediction = await backend.upsertPrediction({
          sessionToken,
          idempotencyKey: requireIdempotencyKey(
            getHeader(req, 'idempotency-key'),
          ),
          turnId: route.params.turnId,
          problemId: route.params.problemId,
          userId: proposalUserId ?? textOrDefault(
            body.userId,
            'demo-user',
            'userId',
            inputLimits.userIdLength,
          ),
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
          motivations: requireEnumArray(
            body.motivations ?? [],
            motivationValues,
            'motivations',
            2,
          ),
          confidence: optionalEnum(
            body.confidence,
            confidenceValues,
            'confidence',
          ),
        });
        return sendJson(res, 200, prediction, sessionToken ? { ...responseHeaders, 'cache-control': 'no-store' } : responseHeaders);
      }

      if (route.name === 'resolvePrediction') {
        if(sessionToken && !options.remoteGame)throw httpError(404,'not_found','Remote game is not configured.');
        const body = await readJson(req);
        const result = await (sessionToken && options.remoteGame ? options.remoteGame : backend).resolvePrediction({
          ...(sessionToken ? { sessionToken } : {}),
          problemId: route.params.problemId,
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
        });
        return sendJson(res, 200, result, sessionToken?{...responseHeaders,'cache-control':'no-store'}:responseHeaders);
      }

      return sendJson(
        res,
        500,
        { error: 'unhandled_route' },
        responseHeaders,
      );
    } catch (error) {
      const status = error.statusCode ?? 500;
      const retryAfter = status === 429 && Number.isInteger(error.retryAfterSeconds) && error.retryAfterSeconds > 0
        ? error.retryAfterSeconds : null;
      return sendJson(
        res,
        status,
        {
          error: error.code ?? 'internal_error',
          message: status === 500 ? 'Unexpected error.' : error.message,
          ...(retryAfter === null ? {} : { retryAfterSeconds: retryAfter }),
          ...(status === 400 && error.fieldErrors ? { fieldErrors: error.fieldErrors } : {}),
        },
        { ...responseHeaders, ...(retryAfter === null ? {} : { 'retry-after': String(retryAfter) }) },
      );
    } finally { finish(); }
  };
}
