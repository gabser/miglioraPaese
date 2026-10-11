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
  const backend = options.application ?? createBackendService(options.store);
  const allowedOrigins = normalizeAllowedOrigins(
    options.allowedOrigins ?? process.env.CORS_ALLOWED_ORIGINS,
  );

  return async function app(req, res) {
    let responseHeaders = {};
    try {
      const url = new URL(req.url ?? '/', 'http://localhost');
      const cors = corsHeadersForRequest(req, allowedOrigins);
      responseHeaders = cors.headers;
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

      if (!route) {
        return sendJson(res, 404, { error: 'not_found' }, responseHeaders);
      }

      if (route.name === 'health') {
        return sendJson(res, 200, { status: 'ok' }, responseHeaders);
      }

      const authorization = getHeader(req, 'authorization');
      let sessionToken = null;
      const proposalRoutes = new Set(['createProposalSession', 'getProposalSession',
        'revokeProposalSession', 'lookupSubmission', 'ownNextProblem',
        'nextProblems', 'nextProblem', 'submitNextProblem', 'voteNextProblem']);
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
        const session = await backend.getProposalSession(privateSession());
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
        }), { ...responseHeaders, 'cache-control': 'no-store' });
      }
      if (route.name === 'ownNextProblem') {
        return sendJson(res, 200, await backend.getOwnNextProblem({
          ...route.params, sessionToken: privateSession(),
        }), { ...responseHeaders, 'cache-control': 'no-store' });
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

      const proposalUserId = sessionToken !== null &&
        (route.name === 'nextProblems' || route.name === 'nextProblem')
        ? sessionIdentity(await backend.getProposalSession(sessionToken)) : null;

      if (route.name === 'nextProblems') {
        return sendJson(
          res,
          200,
          await backend.listNextProblems({
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
          responseHeaders,
        );
      }

      if (route.name === 'nextProblem') {
        const item = await backend.getNextProblem({
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          userId: proposalUserId ?? textOrDefault(url.searchParams.get('userId'), 'demo-user',
            'userId', inputLimits.userIdLength),
        });
        return sendJson(res, 200, item, responseHeaders);
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
          userId: textOrDefault(
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
          userId: textOrDefault(
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
            turnId: route.params.turnId,
            userId: textOrDefault(
              url.searchParams.get('userId'),
              'demo-user',
              'userId',
              inputLimits.userIdLength,
            ),
          }),
          responseHeaders,
        );
      }

      if (route.name === 'upsertPrediction') {
        const body = await readJson(req);
        const prediction = await backend.upsertPrediction({
          idempotencyKey: requireIdempotencyKey(
            getHeader(req, 'idempotency-key'),
          ),
          turnId: route.params.turnId,
          problemId: route.params.problemId,
          userId: textOrDefault(
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
        return sendJson(res, 200, prediction, responseHeaders);
      }

      if (route.name === 'resolvePrediction') {
        const body = await readJson(req);
        const result = await backend.resolvePrediction({
          problemId: route.params.problemId,
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
        });
        return sendJson(res, 200, result, responseHeaders);
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
    }
  };
}
