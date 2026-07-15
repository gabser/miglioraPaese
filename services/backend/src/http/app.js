import { URL } from 'node:url';

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
import { createMemoryStore } from '../infrastructure/memory-store.js';
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
  requireText,
  textOrDefault,
} from './validation.js';

export function createApp(options = {}) {
  const backend =
    options.application ??
    createBackendService(options.store ?? createMemoryStore());
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

      if (route.name === 'municipalityActivation') {
        return sendJson(
          res,
          200,
          backend.getMunicipalityActivation(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'municipalitySummary') {
        return sendJson(
          res,
          200,
          backend.getCivicLoopSummary(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'currentTurn') {
        return sendJson(
          res,
          200,
          backend.getCurrentTurn(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'problems') {
        return sendJson(
          res,
          200,
          backend.listProblems(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'leaderboard') {
        return sendJson(
          res,
          200,
          backend.getLeaderboard(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'nextProblems') {
        return sendJson(
          res,
          200,
          backend.listNextProblems({
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

      if (route.name === 'submitNextProblem') {
        const body = await readJson(req);
        const created = backend.submitNextProblem({
          municipalityId: route.params.municipalityId,
          title: requireText(body.title, 'title', inputLimits.titleLength),
          description: requireText(
            body.description,
            'description',
            inputLimits.descriptionLength,
          ),
          category: requireEnum(body.category, problemKeys, 'category'),
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
        const updated = backend.voteNextProblem({
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
          backend.getPredictions({
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
        const prediction = backend.upsertPrediction({
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
        const result = backend.resolvePrediction({
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
      return sendJson(
        res,
        status,
        {
          error: error.code ?? 'internal_error',
          message: status === 500 ? 'Unexpected error.' : error.message,
        },
        responseHeaders,
      );
    }
  };
}
