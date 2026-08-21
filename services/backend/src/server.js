import http from 'node:http';
import { readFileSync } from 'node:fs';
import { URL } from 'node:url';

import { isAdminAuthorized, validateAdminToken } from './admin_auth.js';
import { createAnonymousIdentity } from './identity.js';
import { moderateSuggestion } from './moderation.js';
import {
  createObservability,
  instrumentResponse,
} from './observability.js';
import { createSqliteStateRepository } from './persistence.js';

const problemKeys = new Set([
  'lighting',
  'potholes',
  'waste',
  'cleanliness',
  'green',
  'signage',
  'transport',
  'parking',
  'decor',
  'noise',
  'safety',
  'construction',
  'queues',
]);

const predictionChoices = new Set(['improve', 'stable', 'worsen']);
const confidenceValues = new Set(['gutFeeling', 'considered', 'convinced']);
const voteChoices = new Set(['up', 'down']);
const suggestedProblemStatuses = new Set(['pending', 'approved', 'rejected']);
const moderationDecisions = new Set(['approved', 'rejected']);
const motivationValues = new Set([
  'visibleActions',
  'recentDecline',
  'seasonality',
  'unmetPromises',
  'personalExperience',
]);

const maxJsonBodyBytes = 64 * 1024;
const maxTitleLength = 120;
const maxDescriptionLength = 1000;
const maxModerationReasonLength = 500;
const maxQueryLength = 120;
const submissionWindowMs = 60 * 60 * 1000;
const maxSubmissionsPerWindow = 3;
const developmentIdentitySecret =
  'migliora-paese-development-secret-change-before-deploy';

const municipalityAliases = new Map([
  ['bologna', 'bologna'],
  ['comune:bologna', 'bologna'],
  ['castel-bolognese', 'castel-bolognese'],
  ['castel bolognese', 'castel-bolognese'],
  ['comune:castel bolognese', 'castel-bolognese'],
]);

export function createApp(options = {}) {
  const store = options.store ?? createMemoryStore();
  const observability = options.observability ?? createObservability();
  const pilotMunicipalityId = optionalPilotMunicipalityId(
    options.pilotMunicipalityId ?? process.env.PILOT_MUNICIPALITY_ID,
    store,
  );
  const moderationAdminToken =
    options.moderationAdminToken == null
      ? null
      : validateAdminToken(options.moderationAdminToken);
  const identity =
    options.identity ??
    createAnonymousIdentity({
      secret:
        options.identitySecret ??
        process.env.ANON_IDENTITY_SECRET ??
        developmentIdentitySecret,
      secure: options.secureCookies ?? process.env.NODE_ENV === 'production',
    });
  const allowedOrigins = normalizeAllowedOrigins(
    options.allowedOrigins ?? process.env.CORS_ALLOWED_ORIGINS,
  );

  return async function app(req, res) {
    let routeName = 'unmatched';
    instrumentResponse({
      req,
      res,
      observability,
      routeName: () => routeName,
    });
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
        routeName = 'corsPreflight';
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
        const requestedRoute = matchRoute(
          requestedMethod.toUpperCase(),
          url.pathname,
        );
        if (!requestedRoute) {
          return sendJson(res, 404, { error: 'not_found' }, responseHeaders);
        }
        return sendJson(res, 200, { status: 'ok' }, responseHeaders);
      }

      const route = matchRoute(req.method ?? 'GET', url.pathname);

      if (!route) {
        return sendJson(res, 404, { error: 'not_found' }, responseHeaders);
      }
      routeName = route.name;

      if (!routeBelongsToPilot(route, store, pilotMunicipalityId)) {
        return sendJson(res, 404, { error: 'not_found' }, responseHeaders);
      }

      if (route.name === 'health') {
        return sendJson(res, 200, { status: 'ok' }, responseHeaders);
      }

      if (route.name === 'ready') {
        try {
          if (store.isReady?.() === false) throw new Error('Store is not ready.');
          return sendJson(res, 200, { status: 'ready' }, responseHeaders);
        } catch {
          return sendJson(
            res,
            503,
            { error: 'service_unavailable', message: 'Store is not ready.' },
            responseHeaders,
          );
        }
      }

      if (route.name === 'metrics') {
        return sendText(res, 200, observability.metrics(), responseHeaders);
      }

      if (route.name === 'moderateNextProblem') {
        if (!isAdminAuthorized(req, moderationAdminToken)) {
          return sendJson(
            res,
            401,
            { error: 'unauthorized', message: 'Admin authorization is required.' },
            responseHeaders,
          );
        }
        const body = await readJson(req);
        const updated = store.moderateNextProblem({
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          status: requireEnum(body.status, moderationDecisions, 'status'),
          reason: optionalText(
            body.reason,
            'reason',
            maxModerationReasonLength,
          ),
        });
        return sendJson(res, 200, updated, responseHeaders);
      }

      const requestIdentity = identity.resolve(req);
      const userId = requestIdentity.userId;
      responseHeaders = { ...responseHeaders, ...requestIdentity.headers };

      if (route.name === 'municipalityActivation') {
        const municipality = store.getMunicipality(route.params.municipalityId);
        return sendJson(
          res,
          200,
          {
            municipalityId: municipality.id,
            state: municipality.activationState,
          },
          responseHeaders,
        );
      }

      if (route.name === 'municipalitySummary') {
        return sendJson(
          res,
          200,
          store.getCivicLoopSummary(
            route.params.municipalityId,
            userId,
          ),
          responseHeaders,
        );
      }

      if (route.name === 'currentTurn') {
        return sendJson(
          res,
          200,
          store.getCurrentTurn(route.params.municipalityId),
          responseHeaders,
        );
      }

      if (route.name === 'problems') {
        return sendJson(
          res,
          200,
          {
            items: store.listProblems(route.params.municipalityId),
          },
          responseHeaders,
        );
      }

      if (route.name === 'leaderboard') {
        return sendJson(
          res,
          200,
          {
            items: store.getLeaderboard(route.params.municipalityId),
          },
          responseHeaders,
        );
      }

      if (route.name === 'nextProblems') {
        return sendJson(
          res,
          200,
          {
            items: store.listNextProblems({
              municipalityId: route.params.municipalityId,
              status: optionalEnum(
                url.searchParams.get('status'),
                suggestedProblemStatuses,
                'status',
              ),
              query: optionalText(
                url.searchParams.get('query'),
                'query',
                maxQueryLength,
              ),
              userId,
            }),
          },
          responseHeaders,
        );
      }

      if (route.name === 'submitNextProblem') {
        const body = await readJson(req);
        const title = requireText(body.title, 'title', maxTitleLength);
        const description = requireText(
          body.description,
          'description',
          maxDescriptionLength,
        );
        const moderation = moderateSuggestion({ title, description });
        if (!moderation.allowed) {
          throw httpError(
            422,
            'content_rejected',
            'The suggestion does not meet the pilot moderation policy.',
          );
        }
        const created = store.submitNextProblem({
          municipalityId: route.params.municipalityId,
          title,
          description,
          category: requireEnum(body.category, problemKeys, 'category'),
          userId,
        });
        return sendJson(res, 201, created, responseHeaders);
      }

      if (route.name === 'voteNextProblem') {
        const body = await readJson(req);
        const updated = store.voteNextProblem({
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          vote: requireEnum(body.vote, voteChoices, 'vote'),
          userId,
        });
        return sendJson(res, 200, updated, responseHeaders);
      }

      if (route.name === 'predictions') {
        return sendJson(
          res,
          200,
          {
            items: store.getPredictions({
              turnId: route.params.turnId,
              userId,
            }),
          },
          responseHeaders,
        );
      }

      if (route.name === 'upsertPrediction') {
        const body = await readJson(req);
        const prediction = store.upsertPrediction({
          turnId: route.params.turnId,
          problemId: route.params.problemId,
          userId,
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
          motivations: requireEnumArray(
            body.motivations ?? [],
            motivationValues,
            'motivations',
            2,
          ),
          confidence: optionalEnum(body.confidence, confidenceValues, 'confidence'),
        });
        return sendJson(res, 200, prediction, responseHeaders);
      }

      if (route.name === 'predictionResults') {
        return sendJson(
          res,
          200,
          {
            items: store.getPredictionResults({
              turnId: route.params.turnId,
              userId,
            }),
          },
          responseHeaders,
        );
      }

      if (route.name === 'reputation') {
        return sendJson(
          res,
          200,
          store.getReputationScore({
            turnId: route.params.turnId,
            userId,
          }),
          responseHeaders,
        );
      }

      if (route.name === 'reputationHistory') {
        return sendJson(
          res,
          200,
          {
            items: store.getReputationHistory({
              municipalityId: route.params.municipalityId,
              userId,
            }),
          },
          responseHeaders,
        );
      }

      if (route.name === 'resolvePrediction') {
        const body = await readJson(req);
        const result = store.resolvePrediction({
          problemId: route.params.problemId,
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
          userId,
        });
        return sendJson(res, 200, result, responseHeaders);
      }

      if (route.name === 'aggregatedInsight') {
        return sendJson(
          res,
          200,
          store.getAggregatedInsight(route.params.problemId),
          responseHeaders,
        );
      }

      if (route.name === 'insightHistory') {
        return sendJson(
          res,
          200,
          store.getInsightHistory(route.params.problemId),
          responseHeaders,
        );
      }

      if (route.name === 'criticalInsights') {
        return sendJson(
          res,
          200,
          {
            items: store.getCriticalInsights({
              problemId: route.params.problemId,
              userChoice: optionalEnum(
                url.searchParams.get('userChoice'),
                predictionChoices,
                'userChoice',
              ),
              userConfidence: optionalEnum(
                url.searchParams.get('userConfidence'),
                confidenceValues,
                'userConfidence',
              ),
              userReflectionIndex: optionalInteger(
                url.searchParams.get('userReflectionIndex'),
                'userReflectionIndex',
                0,
                20,
              ),
            }),
          },
          responseHeaders,
        );
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

export function createMemoryStore(options = {}) {
  const clock = options.now ?? Date.now;
  const onChange = options.onChange ?? (() => {});
  const moderationRequired = options.moderationRequired ?? false;
  const minimumAggregateSampleSize = positiveInteger(
    options.minimumAggregateSampleSize ?? 1,
    'minimumAggregateSampleSize',
  );
  const isoNow = () => new Date(clock()).toISOString();
  const municipalities = new Map([
    [
      'castel-bolognese',
      {
        id: 'castel-bolognese',
        name: 'Castel Bolognese',
        activationState: 'collectingSignals',
        baseActivationState: 'collectingSignals',
      },
    ],
    [
      'bologna',
      {
        id: 'bologna',
        name: 'Bologna',
        activationState: 'active',
        baseActivationState: 'active',
      },
    ],
  ]);

  const now = clock();
  const turnStartAt = new Date(now - 24 * 60 * 60 * 1000).toISOString();
  const turnEndAt = new Date(now + 6 * 24 * 60 * 60 * 1000).toISOString();
  const turnsByMunicipality = new Map([
    [
      'castel-bolognese',
      {
        id: 'turn-castel-bolognese-today',
        municipalityId: 'castel-bolognese',
        state: 'open',
        startAt: turnStartAt,
        endAt: turnEndAt,
      },
    ],
    [
      'bologna',
      {
        id: 'turn-bologna-today',
        municipalityId: 'bologna',
        state: 'open',
        startAt: turnStartAt,
        endAt: turnEndAt,
      },
    ],
  ]);

  const problemsByMunicipality = new Map([
    [
      'bologna',
      [
        createProblem({
          id: 'problem-traffic-indipendenza',
          key: 'transport',
          title: 'Traffico Via Indipendenza',
          zoneName: 'Centro',
          status: 'worsening',
          trendPercent: -14,
          updatedAt: new Date(now - 6 * 60 * 60 * 1000).toISOString(),
        }),
        createProblem({
          id: 'problem-green-margherita',
          key: 'green',
          title: 'Verde ai Giardini Margherita',
          zoneName: 'Santo Stefano',
          status: 'improving',
          trendPercent: 9,
          updatedAt: new Date(now - 2 * 60 * 60 * 1000).toISOString(),
        }),
      ],
    ],
    ['castel-bolognese', []],
  ]);

  const nextProblemsByMunicipality = new Map([
    [
      'castel-bolognese',
      [
        createSuggestedProblem({
          id: 'suggested-potholes-station',
          title: 'Buche vicino alla stazione',
          shortDescription: 'Segnalazioni ricorrenti su marciapiedi e attraversamenti.',
          category: 'potholes',
          votesUp: 0,
          votesDown: 0,
          status: 'pending',
          createdAt: new Date(now - 2 * 60 * 60 * 1000).toISOString(),
        }),
        createSuggestedProblem({
          id: 'suggested-lighting-park',
          title: 'Illuminazione al parco',
          shortDescription: 'Percorsi poco leggibili nelle ore serali.',
          category: 'lighting',
          votesUp: 0,
          votesDown: 0,
          status: 'pending',
          createdAt: new Date(now - 60 * 60 * 1000).toISOString(),
        }),
      ],
    ],
    [
      'bologna',
      [
        createSuggestedProblem({
          id: 'suggested-queues-registry',
          title: "Tempi d'attesa all'anagrafe",
          shortDescription: 'Coda percepita alta negli orari centrali.',
          category: 'queues',
          votesUp: 4,
          votesDown: 1,
          status: 'approved',
          createdAt: new Date(now - 24 * 60 * 60 * 1000).toISOString(),
        }),
      ],
    ],
  ]);

  const votesByProblem = new Map();
  const predictionsByTurn = new Map();
  const predictionResultsByTurn = new Map();
  let nextProblemCounter = 200;

  if (options.initialState !== undefined && options.initialState !== null) {
    restoreState(options.initialState);
  }

  function restoreState(state) {
    if (
      state === null ||
      typeof state !== 'object' ||
      state.schemaVersion !== 1
    ) {
      throw new Error('Unsupported or invalid persistent state.');
    }
    const requiredCollections = [
      'municipalities',
      'turns',
      'problems',
      'suggestedProblems',
      'votes',
      'predictions',
      'predictionResults',
    ];
    for (const key of requiredCollections) {
      if (!Array.isArray(state[key])) {
        throw new Error(`Persistent state field ${key} must be an array.`);
      }
    }

    municipalities.clear();
    for (const municipality of state.municipalities) {
      municipalities.set(municipality.id, { ...municipality });
    }
    turnsByMunicipality.clear();
    for (const turn of state.turns) {
      turnsByMunicipality.set(turn.municipalityId, { ...turn });
    }
    problemsByMunicipality.clear();
    nextProblemsByMunicipality.clear();
    for (const municipalityId of municipalities.keys()) {
      problemsByMunicipality.set(municipalityId, []);
      nextProblemsByMunicipality.set(municipalityId, []);
    }
    for (const item of state.problems) {
      const problems = problemsByMunicipality.get(item.municipalityId) ?? [];
      problems.push({ ...item.problem });
      problemsByMunicipality.set(item.municipalityId, problems);
    }
    for (const item of state.suggestedProblems) {
      const suggestions =
        nextProblemsByMunicipality.get(item.municipalityId) ?? [];
      suggestions.push({ ...item.problem });
      nextProblemsByMunicipality.set(item.municipalityId, suggestions);
    }

    votesByProblem.clear();
    for (const item of state.votes) {
      const votes = votesByProblem.get(item.problemId) ?? new Map();
      votes.set(item.userId, item.vote);
      votesByProblem.set(item.problemId, votes);
    }
    predictionsByTurn.clear();
    for (const prediction of state.predictions) {
      const predictions = predictionsByTurn.get(prediction.turnId) ?? new Map();
      predictions.set(prediction.id, { ...prediction });
      predictionsByTurn.set(prediction.turnId, predictions);
    }
    predictionResultsByTurn.clear();
    for (const resolution of state.predictionResults) {
      const results =
        predictionResultsByTurn.get(resolution.turnId) ?? new Map();
      results.set(
        resolution.turnId + ':' + resolution.problemId + ':' + resolution.userId,
        { ...resolution },
      );
      predictionResultsByTurn.set(resolution.turnId, results);
    }
    if (
      !Number.isSafeInteger(state.nextProblemCounter) ||
      state.nextProblemCounter < 1
    ) {
      throw new Error('Persistent nextProblemCounter is invalid.');
    }
    nextProblemCounter = state.nextProblemCounter;
  }

  function exportState() {
    return {
      schemaVersion: 1,
      municipalities: [...municipalities.values()].map((item) => ({ ...item })),
      turns: [...turnsByMunicipality.values()].map((item) => ({ ...item })),
      problems: [...problemsByMunicipality.entries()].flatMap(
        ([municipalityId, problems]) =>
          problems.map((problem) => ({
            municipalityId,
            problem: { ...problem },
          })),
      ),
      suggestedProblems: [...nextProblemsByMunicipality.entries()].flatMap(
        ([municipalityId, problems]) =>
          problems.map((problem) => ({
            municipalityId,
            problem: { ...problem },
          })),
      ),
      votes: [...votesByProblem.entries()].flatMap(([problemId, votes]) =>
        [...votes.entries()].map(([userId, vote]) => ({
          problemId,
          userId,
          vote,
        })),
      ),
      predictions: [...predictionsByTurn.values()].flatMap((predictions) =>
        [...predictions.values()].map((item) => ({ ...item })),
      ),
      predictionResults: [...predictionResultsByTurn.values()].flatMap(
        (results) => [...results.values()].map((item) => ({ ...item })),
      ),
      nextProblemCounter,
    };
  }

  function persist() {
    onChange(exportState());
  }

  function getMunicipality(municipalityId) {
    const canonicalId = canonicalMunicipalityId(municipalityId);
    const municipality = municipalities.get(canonicalId);
    if (!municipality) {
      throw httpError(404, 'municipality_not_found', 'Municipality not found.');
    }
    return municipality;
  }

  function getCurrentTurn(municipalityId) {
    const municipality = getMunicipality(municipalityId);
    return turnsByMunicipality.get(municipality.id);
  }

  function listProblems(municipalityId) {
    const municipality = getMunicipality(municipalityId);
    return problemsByMunicipality.get(municipality.id) ?? [];
  }

  function listNextProblems({
    municipalityId,
    status = null,
    query = null,
    userId = 'demo-user',
  }) {
    const municipality = getMunicipality(municipalityId);
    let items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    if (status) {
      items = items.filter((item) => item.status === status);
    }
    if (query) {
      const normalized = query.trim().toLowerCase();
      items = items.filter((item) => {
        return (
          item.title.toLowerCase().includes(normalized) ||
          item.shortDescription.toLowerCase().includes(normalized)
        );
      });
    }
    return items.map((item) => withUserVote(item, userId));
  }

  function submitNextProblem({
    municipalityId,
    title,
    description,
    category,
    userId,
  }) {
    const municipality = getMunicipality(municipalityId);
    const items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const duplicate = items.some(
      (item) => normalizeTitle(item.title) === normalizeTitle(title),
    );
    if (duplicate) {
      throw httpError(409, 'duplicate_title', 'A suggestion with this title exists.');
    }
    const windowStart = clock() - submissionWindowMs;
    const recentSubmissions = items.filter(
      (item) =>
        item.submittedByUserId === userId &&
        Date.parse(item.createdAt) >= windowStart,
    );
    if (recentSubmissions.length >= maxSubmissionsPerWindow) {
      throw httpError(
        429,
        'submission_rate_limited',
        'Too many suggestions were submitted recently.',
      );
    }

    const created = createSuggestedProblem({
      id: `suggested-${nextProblemCounter++}`,
      title,
      shortDescription: description,
      category,
      status: 'pending',
      votesUp: 0,
      votesDown: 0,
      submittedByUserId: userId,
      submittedByDisplayName: 'Cittadino',
      createdAt: isoNow(),
    });
    if (moderationRequired) {
      created.promotionRule = {
        ...created.promotionRule,
        reason:
          'Pilot: i voti ordinano le proposte; la promozione richiede moderazione.',
      };
    }
    nextProblemsByMunicipality.set(municipality.id, [created, ...items]);
    persist();
    return withUserVote(created, userId);
  }

  function voteNextProblem({ municipalityId, problemId, vote, userId }) {
    const municipality = getMunicipality(municipalityId);
    const items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const index = items.findIndex((item) => item.id === problemId);
    if (index === -1) {
      throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
    }

    const current = items[index];
    const userVotes = votesByProblem.get(problemId) ?? new Map();
    const previousVote = userVotes.get(userId) ?? 'none';
    let votesUp = current.votesUp;
    let votesDown = current.votesDown;

    if (previousVote === 'up') votesUp = Math.max(0, votesUp - 1);
    if (previousVote === 'down') votesDown = Math.max(0, votesDown - 1);

    const nextVote = previousVote === vote ? 'none' : vote;
    if (nextVote === 'up') votesUp += 1;
    if (nextVote === 'down') votesDown += 1;

    if (nextVote === 'none') {
      userVotes.delete(userId);
    } else {
      userVotes.set(userId, nextVote);
    }
    votesByProblem.set(problemId, userVotes);

    const updated = {
      ...current,
      votesUp,
      votesDown,
      score: votesUp - votesDown,
      myVote: 'none',
      status:
        moderationRequired || current.status === 'rejected'
          ? current.status
          : votesUp - votesDown >= 1
            ? 'approved'
            : 'pending',
    };
    items[index] = updated;
    syncPromotion(municipality, updated);
    persist();
    return withUserVote(updated, userId);
  }

  function moderateNextProblem({
    municipalityId,
    problemId,
    status,
    reason = null,
  }) {
    const municipality = getMunicipality(municipalityId);
    const items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const index = items.findIndex((item) => item.id === problemId);
    if (index === -1) {
      throw httpError(
        404,
        'suggested_problem_not_found',
        'Suggested problem not found.',
      );
    }
    const updated = {
      ...items[index],
      status,
      moderatedAt: isoNow(),
      moderationReason: reason,
    };
    items[index] = updated;
    syncPromotion(municipality, updated);
    persist();
    return updated;
  }

  function withUserVote(problem, userId) {
    const userVotes = votesByProblem.get(problem.id);
    return {
      ...problem,
      myVote: userVotes?.get(userId) ?? 'none',
    };
  }

  function syncPromotion(municipality, suggestion) {
    const problems = problemsByMunicipality.get(municipality.id) ?? [];
    const promotedId = 'proposal_' + suggestion.id;
    const existingIndex = problems.findIndex((item) => item.id === promotedId);

    if (suggestion.status === 'approved' && existingIndex === -1) {
      problems.push(
        createProblem({
          id: promotedId,
          key: suggestion.category,
          title: suggestion.title,
          zoneName: 'Tema scelto dai cittadini',
          status: 'stable',
          trendPercent: 0,
          updatedAt: isoNow(),
        }),
      );
    }
    if (suggestion.status !== 'approved' && existingIndex !== -1) {
      problems.splice(existingIndex, 1);
    }
    problemsByMunicipality.set(municipality.id, problems);

    const suggestions = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const hasApprovedSuggestion = suggestions.some(
      (item) => item.status === 'approved',
    );
    municipality.activationState =
      municipality.baseActivationState === 'active' || hasApprovedSuggestion
        ? 'active'
        : 'collectingSignals';
  }

  function getPredictions({ turnId, userId }) {
    findTurn(turnId);
    const turnPredictions = predictionsByTurn.get(turnId) ?? new Map();
    return [...turnPredictions.values()].filter((item) => item.userId === userId);
  }

  function upsertPrediction({
    turnId,
    problemId,
    userId,
    choice,
    motivations,
    confidence,
  }) {
    const turn = findTurn(turnId);
    const problemRecord = findProblemRecord(problemId);
    if (problemRecord.municipalityId !== turn.municipalityId) {
      throw httpError(
        409,
        'problem_turn_mismatch',
        'Problem does not belong to this turn.',
      );
    }
    if (turn.state !== 'open') {
      throw httpError(409, 'turn_not_open', 'Turn is not open.');
    }

    const turnPredictions = predictionsByTurn.get(turnId) ?? new Map();
    const id = turnId + ':' + problemId + ':' + userId;
    const existing = turnPredictions.get(id);
    if (existing && existing.choice !== choice) {
      throw httpError(
        409,
        'prediction_locked',
        'Prediction choice is already locked for this turn.',
      );
    }
    const timestamp = isoNow();
    const prediction = {
      id,
      turnId,
      problemId,
      userId,
      choice,
      motivations,
      confidence,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
    };
    turnPredictions.set(id, prediction);
    predictionsByTurn.set(turnId, turnPredictions);
    persist();
    return prediction;
  }

  function resolvePrediction({ problemId, choice, userId = 'demo-user' }) {
    const problemRecord = findProblemRecord(problemId);
    const problem = problemRecord.problem;
    const turn = turnsByMunicipality.get(problemRecord.municipalityId);
    const turnPredictions = predictionsByTurn.get(turn.id) ?? new Map();
    const prediction = turnPredictions.get(
      turn.id + ':' + problemId + ':' + userId,
    );
    if (!prediction) {
      throw httpError(
        404,
        'prediction_not_found',
        'Prediction not found for this user and turn.',
      );
    }
    if (prediction.choice !== choice) {
      throw httpError(
        409,
        'prediction_choice_mismatch',
        'Resolution choice does not match the saved prediction.',
      );
    }
    const winningChoice = statusToChoice(problem.status);
    const result = evaluatePrediction(problem.status, choice);
    const resolution = {
      turnId: turn.id,
      problemId,
      userId,
      choice,
      winningChoice,
      result,
      correct: result === 'correct',
      pointsDelta: pointsForResult(result),
      resolvedAt: isoNow(),
    };
    const turnResults = predictionResultsByTurn.get(turn.id) ?? new Map();
    turnResults.set(turn.id + ':' + problemId + ':' + userId, resolution);
    predictionResultsByTurn.set(turn.id, turnResults);
    persist();
    return resolution;
  }

  function getPredictionResults({ turnId, userId }) {
    findTurn(turnId);
    return getResolutionRecords({ turnId, userId }).map((resolution) => ({
      problemId: resolution.problemId,
      result: resolution.result,
    }));
  }

  function getReputationScore({ turnId, userId }) {
    findTurn(turnId);
    const results = getResolutionRecords({ turnId, userId });
    if (results.length === 0) {
      return { totalPoints: 0, accuracy: 0, predictionsCount: 0 };
    }
    const totalPoints = results.reduce(
      (sum, resolution) => sum + resolution.pointsDelta,
      0,
    );
    const accuracyUnits = results.reduce((sum, resolution) => {
      if (resolution.result === 'correct') return sum + 1;
      if (resolution.result === 'partial') return sum + 0.5;
      return sum;
    }, 0);
    return {
      totalPoints,
      accuracy: accuracyUnits / results.length,
      predictionsCount: results.length,
    };
  }

  function getReputationHistory({ municipalityId, userId }) {
    const municipality = getMunicipality(municipalityId);
    return [...turnsByMunicipality.values()]
      .filter((turn) => turn.municipalityId === municipality.id)
      .sort((a, b) => a.startAt.localeCompare(b.startAt))
      .map((turn) => getReputationScore({ turnId: turn.id, userId }));
  }

  function getResolutionRecords({ turnId, userId }) {
    const turnResults = predictionResultsByTurn.get(turnId) ?? new Map();
    return [...turnResults.values()].filter(
      (resolution) => resolution.userId === userId,
    );
  }

  function getAggregatedInsight(problemId) {
    const problemRecord = findProblemRecord(problemId);
    const turn = turnsByMunicipality.get(problemRecord.municipalityId);
    return aggregateInsightForTurn(turn, problemId);
  }

  function aggregateInsightForTurn(turn, problemId) {
    const turnPredictions = predictionsByTurn.get(turn.id) ?? new Map();
    const predictions = [...turnPredictions.values()].filter(
      (prediction) => prediction.problemId === problemId,
    );
    const choiceDistribution = Object.fromEntries(
      [...predictionChoices].map((choice) => [choice, 0]),
    );
    const motivationDistribution = Object.fromEntries(
      [...motivationValues].map((motivation) => [motivation, 0]),
    );
    for (const prediction of predictions) {
      choiceDistribution[prediction.choice] += 1;
      for (const motivation of prediction.motivations) {
        motivationDistribution[motivation] += 1;
      }
    }
    if (predictions.length < minimumAggregateSampleSize) {
      return {
        problemId,
        totalPredictions: 0,
        choiceDistribution: Object.fromEntries(
          [...predictionChoices].map((choice) => [choice, 0]),
        ),
        motivationDistribution: Object.fromEntries(
          [...motivationValues].map((motivation) => [motivation, 0]),
        ),
      };
    }
    return {
      problemId,
      totalPredictions: predictions.length,
      choiceDistribution,
      motivationDistribution,
    };
  }

  function getInsightHistory(problemId) {
    const problemRecord = findProblemRecord(problemId);
    const turns = [...turnsByMunicipality.values()]
      .filter((turn) => turn.municipalityId === problemRecord.municipalityId)
      .sort((a, b) => a.startAt.localeCompare(b.startAt));
    return {
      problemId,
      snapshots: turns.map((turn) => {
        const insight = aggregateInsightForTurn(turn, problemId);
        const turnPredictions = predictionsByTurn.get(turn.id) ?? new Map();
        const latestAt =
          insight.totalPredictions === 0
            ? turn.startAt
            : [...turnPredictions.values()]
                .filter((prediction) => prediction.problemId === problemId)
                .reduce(
                  (latest, prediction) =>
                    prediction.updatedAt > latest
                      ? prediction.updatedAt
                      : latest,
                  turn.startAt,
                );
        const motivationTop = Object.entries(insight.motivationDistribution)
          .filter(([, count]) => count > 0)
          .sort(([aKey, aCount], [bKey, bCount]) => {
            const byCount = bCount - aCount;
            return byCount === 0 ? aKey.localeCompare(bKey) : byCount;
          })
          .slice(0, 2)
          .map(([motivation]) => motivation);
        return {
          turnId: turn.id,
          at: latestAt,
          totalPredictions: insight.totalPredictions,
          choiceDistribution: insight.choiceDistribution,
          motivationTop,
        };
      }),
    };
  }

  function getCriticalInsights({
    problemId,
    userChoice,
    userConfidence,
    userReflectionIndex,
  }) {
    const insight = getAggregatedInsight(problemId);
    if (insight.totalPredictions === 0) {
      return [
        {
          headline: 'Dati in raccolta',
          supporting: 'Non ci sono ancora previsioni aggregate per questo tema.',
          note: null,
        },
      ];
    }

    const orderedChoices = Object.entries(insight.choiceDistribution).sort(
      ([aChoice, aCount], [bChoice, bCount]) => {
        const byCount = bCount - aCount;
        return byCount === 0 ? aChoice.localeCompare(bChoice) : byCount;
      },
    );
    const [leadingChoice, leadingCount] = orderedChoices[0];
    const leadingPercentage = Math.round(
      (leadingCount / insight.totalPredictions) * 100,
    );
    const tied = orderedChoices[1]?.[1] === leadingCount;
    const items = [
      {
        headline: 'Percezione prevalente',
        supporting:
          leadingPercentage +
          '% prevede che il problema ' +
          choiceNarrative(leadingChoice) +
          '.',
        note: tied ? 'Opinioni divise.' : null,
      },
    ];

    if (userChoice !== null) {
      items.push({
        headline:
          userChoice === leadingChoice
            ? 'La tua lettura e\' condivisa'
            : 'La tua lettura e\' minoritaria',
        supporting:
          userChoice === leadingChoice
            ? 'La scelta coincide con la previsione piu\' frequente.'
            : 'La scelta differisce dalla previsione piu\' frequente.',
        note:
          userConfidence === null
            ? null
            : 'Convinzione dichiarata: ' + userConfidence + '.',
      });
    }

    if (userReflectionIndex !== null) {
      items.push({
        headline: 'Riflessione registrata',
        supporting:
          'La risposta ' +
          (userReflectionIndex + 1) +
          ' contestualizza il confronto aggregato.',
        note: null,
      });
    }
    return items;
  }

  function findProblem(problemId) {
    return findProblemRecord(problemId).problem;
  }

  function findProblemRecord(problemId) {
    for (const [municipalityId, problems] of problemsByMunicipality.entries()) {
      const problem = problems.find((item) => item.id === problemId);
      if (problem) return { municipalityId, problem };
    }
    throw httpError(404, 'problem_not_found', 'Problem not found.');
  }

  function findTurn(turnId) {
    for (const turn of turnsByMunicipality.values()) {
      if (turn.id === turnId) return turn;
    }
    throw httpError(404, 'turn_not_found', 'Turn not found.');
  }

  function getCivicLoopSummary(municipalityId, userId = 'demo-user') {
    const municipality = getMunicipality(municipalityId);
    const turn = getCurrentTurn(municipalityId);
    const predictions = getPredictions({
      turnId: turn.id,
      userId,
    });
    const outcomes = getPredictionResults({ turnId: turn.id, userId });
    const reputation = getReputationScore({ turnId: turn.id, userId });
    const proposedThemes = listNextProblems({ municipalityId }).length;
    const confirmedThemes = listNextProblems({
      municipalityId,
      status: 'approved',
    }).length;
    const confirmedItems = listNextProblems({
      municipalityId,
      status: 'approved',
    }).sort((a, b) => b.score - a.score);
    return {
      municipalityName: municipality.name,
      proposedThemes,
      confirmedThemes,
      cardsInTurn: listProblems(municipalityId).length,
      predictions: predictions.length,
      outcomes: outcomes.length,
      reputationPoints: reputation.totalPoints,
      topThemeTitle: confirmedItems[0]?.title ?? null,
    };
  }

  function getLeaderboard(municipalityId) {
    getMunicipality(municipalityId);
    return [
      { userId: 'user-luca', displayName: 'Luca', rank: 1, points: 3480 },
      { userId: 'user-giulia', displayName: 'Giulia', rank: 2, points: 2910 },
      { userId: 'demo-user', displayName: 'Tu', rank: 9, points: 1284 },
    ];
  }

  return {
    getMunicipality,
    getCurrentTurn,
    listProblems,
    listNextProblems,
    submitNextProblem,
    voteNextProblem,
    moderateNextProblem,
    getPredictions,
    upsertPrediction,
    resolvePrediction,
    getPredictionResults,
    getReputationScore,
    getReputationHistory,
    getAggregatedInsight,
    getInsightHistory,
    getCriticalInsights,
    getCivicLoopSummary,
    getLeaderboard,
    exportState,
    isReady: () => true,
  };
}

export function createPersistentStore({
  databasePath,
  now,
  moderationRequired,
  minimumAggregateSampleSize,
} = {}) {
  const stateRepository = createSqliteStateRepository({ databasePath });
  try {
    const initialState = stateRepository.load();
    const store = createMemoryStore({
      initialState,
      now,
      moderationRequired,
      minimumAggregateSampleSize,
      onChange: stateRepository.save,
    });
    if (initialState === null) {
      stateRepository.save(store.exportState());
    }
    return {
      ...store,
      close: stateRepository.close,
      persistence: {
        path: stateRepository.path,
        schemaVersion: stateRepository.schemaVersion,
      },
      isReady: stateRepository.isReady,
    };
  } catch (error) {
    stateRepository.close();
    throw error;
  }
}

export function startServer({
  port = process.env.PORT ?? 8787,
  host = process.env.HOST ?? '127.0.0.1',
  store,
  allowedOrigins,
  databasePath = process.env.DATABASE_PATH,
  identitySecret,
  identitySecretFile = process.env.ANON_IDENTITY_SECRET_FILE,
  moderationAdminToken,
  moderationAdminTokenFile = process.env.MODERATION_ADMIN_TOKEN_FILE,
  pilotMunicipalityId = process.env.PILOT_MUNICIPALITY_ID,
  moderationRequired = optionalBoolean(
    process.env.MODERATION_REQUIRED,
    process.env.NODE_ENV === 'production',
  ),
  minimumAggregateSampleSize = positiveInteger(
    process.env.MIN_AGGREGATE_SAMPLE_SIZE ??
      (process.env.NODE_ENV === 'production' ? 3 : 1),
    'MIN_AGGREGATE_SAMPLE_SIZE',
  ),
  secureCookies = process.env.NODE_ENV === 'production',
  observability,
  logger = null,
} = {}) {
  const resolvedIdentitySecret = resolveSecret({
    direct: identitySecret ?? process.env.ANON_IDENTITY_SECRET,
    file: identitySecretFile,
  });
  const resolvedModerationAdminToken = resolveSecret({
    direct: moderationAdminToken ?? process.env.MODERATION_ADMIN_TOKEN,
    file: moderationAdminTokenFile,
  });
  if (process.env.NODE_ENV === 'production' && !store && !databasePath) {
    throw new Error('DATABASE_PATH is required in production.');
  }
  if (process.env.NODE_ENV === 'production' && !resolvedIdentitySecret) {
    throw new Error('ANON_IDENTITY_SECRET is required in production.');
  }
  if (process.env.NODE_ENV === 'production' && !resolvedModerationAdminToken) {
    throw new Error('MODERATION_ADMIN_TOKEN is required in production.');
  }
  if (process.env.NODE_ENV === 'production' && !pilotMunicipalityId) {
    throw new Error('PILOT_MUNICIPALITY_ID is required in production.');
  }
  if (process.env.NODE_ENV === 'production' && moderationRequired !== true) {
    throw new Error('MODERATION_REQUIRED must be true in production.');
  }
  if (
    process.env.NODE_ENV === 'production' &&
    !(allowedOrigins ?? process.env.CORS_ALLOWED_ORIGINS)
  ) {
    throw new Error('CORS_ALLOWED_ORIGINS is required in production.');
  }
  const managedStore =
    store ??
    (databasePath
      ? createPersistentStore({
          databasePath,
          moderationRequired,
          minimumAggregateSampleSize,
        })
      : createMemoryStore({
          moderationRequired,
          minimumAggregateSampleSize,
        }));
  const managedObservability =
    observability ?? createObservability({ logger, version: '0.5.0' });
  let app;
  try {
    app = createApp({
      store: managedStore,
      allowedOrigins,
      identitySecret: resolvedIdentitySecret ?? developmentIdentitySecret,
      moderationAdminToken: resolvedModerationAdminToken,
      pilotMunicipalityId,
      secureCookies,
      observability: managedObservability,
    });
  } catch (error) {
    if (!store && typeof managedStore.close === 'function') managedStore.close();
    throw error;
  }
  const server = http.createServer(app);
  if (!store && typeof managedStore.close === 'function') {
    server.once('close', managedStore.close);
  }
  server.listen(normalizePort(port), host);
  return server;
}

function matchRoute(method, pathname) {
  if (method === 'GET' && pathname === '/health') {
    return { name: 'health', params: {} };
  }
  if (method === 'GET' && pathname === '/ready') {
    return { name: 'ready', params: {} };
  }
  if (method === 'GET' && pathname === '/metrics') {
    return { name: 'metrics', params: {} };
  }

  const patterns = [
    ['GET', /^\/v1\/municipalities\/([^/]+)\/activation$/, 'municipalityActivation'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/summary$/, 'municipalitySummary'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/turn$/, 'currentTurn'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/problems$/, 'problems'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/leaderboard$/, 'leaderboard'],
    [
      'GET',
      /^\/v1\/municipalities\/([^/]+)\/reputation-history$/,
      'reputationHistory',
    ],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/next-problems$/, 'nextProblems'],
    ['POST', /^\/v1\/municipalities\/([^/]+)\/next-problems$/, 'submitNextProblem'],
    [
      'POST',
      /^\/v1\/municipalities\/([^/]+)\/next-problems\/([^/]+)\/votes$/,
      'voteNextProblem',
    ],
    [
      'POST',
      /^\/v1\/admin\/municipalities\/([^/]+)\/next-problems\/([^/]+)\/moderation$/,
      'moderateNextProblem',
    ],
    ['GET', /^\/v1\/turns\/([^/]+)\/predictions$/, 'predictions'],
    ['PUT', /^\/v1\/turns\/([^/]+)\/predictions\/([^/]+)$/, 'upsertPrediction'],
    ['GET', /^\/v1\/turns\/([^/]+)\/prediction-results$/, 'predictionResults'],
    ['GET', /^\/v1\/turns\/([^/]+)\/reputation$/, 'reputation'],
    ['POST', /^\/v1\/problems\/([^/]+)\/resolve$/, 'resolvePrediction'],
    ['GET', /^\/v1\/problems\/([^/]+)\/insight$/, 'aggregatedInsight'],
    ['GET', /^\/v1\/problems\/([^/]+)\/insight-history$/, 'insightHistory'],
    ['GET', /^\/v1\/problems\/([^/]+)\/critical-insights$/, 'criticalInsights'],
  ];

  for (const [routeMethod, pattern, name] of patterns) {
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
  if (
    name === 'municipalityActivation' ||
    name === 'municipalitySummary' ||
    name === 'currentTurn' ||
    name === 'problems' ||
    name === 'leaderboard' ||
    name === 'reputationHistory' ||
    name === 'nextProblems' ||
    name === 'submitNextProblem'
  ) {
    return { municipalityId: decodeURIComponent(match[1]) };
  }
  if (name === 'voteNextProblem' || name === 'moderateNextProblem') {
    return {
      municipalityId: decodeURIComponent(match[1]),
      problemId: decodeURIComponent(match[2]),
    };
  }
  if (
    name === 'predictions' ||
    name === 'predictionResults' ||
    name === 'reputation'
  ) {
    return { turnId: decodeURIComponent(match[1]) };
  }
  if (name === 'upsertPrediction') {
    return {
      turnId: decodeURIComponent(match[1]),
      problemId: decodeURIComponent(match[2]),
    };
  }
  if (
    name === 'resolvePrediction' ||
    name === 'aggregatedInsight' ||
    name === 'insightHistory' ||
    name === 'criticalInsights'
  ) {
    return { problemId: decodeURIComponent(match[1]) };
  }
  return {};
}

function canonicalMunicipalityId(value) {
  if (typeof value !== 'string') return value;
  const normalized = value.trim().toLowerCase();
  return municipalityAliases.get(normalized) ?? normalized;
}

function optionalPilotMunicipalityId(value, store) {
  if (value == null || value === '') return null;
  if (typeof value !== 'string') {
    throw new TypeError('PILOT_MUNICIPALITY_ID must be a string.');
  }
  const canonicalId = canonicalMunicipalityId(value);
  return store.getMunicipality(canonicalId).id;
}

function routeBelongsToPilot(route, store, pilotMunicipalityId) {
  if (pilotMunicipalityId === null) return true;
  if (
    route.params.municipalityId !== undefined &&
    canonicalMunicipalityId(route.params.municipalityId) !== pilotMunicipalityId
  ) {
    return false;
  }
  if (
    route.params.turnId !== undefined &&
    store.getCurrentTurn(pilotMunicipalityId).id !== route.params.turnId
  ) {
    return false;
  }
  if (
    route.params.problemId !== undefined &&
    route.name !== 'voteNextProblem' &&
    route.name !== 'moderateNextProblem' &&
    !store
      .listProblems(pilotMunicipalityId)
      .some((problem) => problem.id === route.params.problemId)
  ) {
    return false;
  }
  return true;
}

function normalizeTitle(value) {
  return value.trim().toLowerCase().replaceAll(/\s+/g, ' ');
}

function getHeader(req, name) {
  const value = req.headers?.[name];
  return Array.isArray(value) ? value[0] : value ?? null;
}

function normalizeAllowedOrigins(value) {
  if (value == null || value === '') return new Set();
  const entries =
    typeof value === 'string'
      ? value.split(',')
      : value instanceof Set
        ? [...value]
        : value;
  if (!Array.isArray(entries)) {
    throw new TypeError('allowedOrigins must be a comma-separated string or array.');
  }
  return new Set(
    entries
      .map((entry) => normalizeOrigin(entry))
      .filter((entry) => entry !== null),
  );
}

function normalizeOrigin(value) {
  if (typeof value !== 'string' || value.trim() === '' || value.trim() === '*') {
    throw new TypeError('CORS origins must be explicit HTTP(S) origins.');
  }
  const url = new URL(value.trim());
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new TypeError('CORS origins must use HTTP or HTTPS.');
  }
  return url.origin;
}

function corsHeadersForRequest(req, allowedOrigins) {
  const rawOrigin = getHeader(req, 'origin');
  if (!rawOrigin) {
    return { allowed: true, origin: null, headers: {} };
  }

  let origin;
  try {
    origin = normalizeOrigin(rawOrigin);
  } catch {
    return { allowed: false, origin: null, headers: { vary: 'Origin' } };
  }
  const url = new URL(origin);
  const loopbackHosts = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);
  const allowed = loopbackHosts.has(url.hostname) || allowedOrigins.has(origin);
  if (!allowed) {
    return { allowed: false, origin, headers: { vary: 'Origin' } };
  }
  return {
    allowed: true,
    origin,
    headers: {
      'access-control-allow-origin': origin,
      'access-control-allow-methods': 'GET, POST, PUT, OPTIONS',
      'access-control-allow-headers': 'Content-Type',
      'access-control-allow-credentials': 'true',
      'access-control-max-age': '600',
      vary: 'Origin',
    },
  };
}

function normalizePort(value) {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new RangeError('PORT must be an integer between 0 and 65535.');
  }
  return port;
}

function optionalBoolean(value, fallback) {
  if (value == null || value === '') return fallback;
  if (value === true || value === 'true' || value === '1') return true;
  if (value === false || value === 'false' || value === '0') return false;
  throw new TypeError('Boolean configuration must be true, false, 1 or 0.');
}

function positiveInteger(value, name) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1) {
    throw new TypeError(`${name} must be a positive integer.`);
  }
  return parsed;
}

function resolveSecret({ direct, file }) {
  const hasDirect = typeof direct === 'string' && direct.length > 0;
  const hasFile = typeof file === 'string' && file.length > 0;
  if (hasDirect && hasFile) {
    throw new Error('Configure a secret directly or by file, not both.');
  }
  if (hasDirect) return direct;
  if (!hasFile) return null;
  const value = readFileSync(file, 'utf8').trim();
  if (value.length === 0) throw new Error('Configured secret file is empty.');
  return value;
}

async function readJson(req) {
  const contentLength = Number(getHeader(req, 'content-length'));
  if (Number.isFinite(contentLength) && contentLength > maxJsonBodyBytes) {
    throw httpError(413, 'payload_too_large', 'Request body exceeds 64 KiB.');
  }

  const chunks = [];
  let totalBytes = 0;
  for await (const chunk of req) {
    totalBytes += chunk.length;
    if (totalBytes > maxJsonBodyBytes) {
      throw httpError(413, 'payload_too_large', 'Request body exceeds 64 KiB.');
    }
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw.trim()) return {};
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw httpError(400, 'invalid_json', 'Request body must be valid JSON.');
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
    throw httpError(400, 'invalid_body', 'Request body must be a JSON object.');
  }
  return parsed;
}

function sendJson(res, statusCode, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    ...headers,
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function sendText(res, statusCode, body, headers = {}) {
  res.writeHead(statusCode, {
    ...headers,
    'content-type': 'text/plain; version=0.0.4; charset=utf-8',
    'content-length': Buffer.byteLength(body),
  });
  res.end(body);
}

function requireText(value, field, maxLength = null) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw httpError(400, 'invalid_field', field + ' is required.');
  }
  const normalized = value.trim();
  if (maxLength !== null && normalized.length > maxLength) {
    throw httpError(
      400,
      'invalid_field',
      field + ' must be at most ' + maxLength + ' characters.',
    );
  }
  return normalized;
}

function optionalText(value, field, maxLength) {
  if (value == null || value.trim() === '') return null;
  return requireText(value, field, maxLength);
}

function requireEnum(value, values, field) {
  if (typeof value !== 'string' || !values.has(value)) {
    throw httpError(400, 'invalid_field', `${field} is invalid.`);
  }
  return value;
}

function optionalEnum(value, values, field) {
  if (value == null) return null;
  return requireEnum(value, values, field);
}

function optionalInteger(value, field, min, max) {
  if (value == null) return null;
  if (!/^-?\d+$/.test(value)) {
    throw httpError(400, 'invalid_field', `${field} is invalid.`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) {
    throw httpError(
      400,
      'invalid_field',
      `${field} must be between ${min} and ${max}.`,
    );
  }
  return parsed;
}

function requireEnumArray(value, values, field, maxItems) {
  if (
    !Array.isArray(value) ||
    value.length > maxItems ||
    value.some((item) => typeof item !== 'string' || !values.has(item)) ||
    new Set(value).size !== value.length
  ) {
    throw httpError(
      400,
      'invalid_field',
      field + ' must contain at most ' + maxItems + ' unique known values.',
    );
  }
  return value;
}

function httpError(statusCode, code, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  return error;
}

function createProblem({
  id,
  key,
  title,
  zoneName,
  status,
  trendPercent,
  updatedAt = new Date().toISOString(),
}) {
  return {
    id,
    key,
    title,
    zoneName,
    status,
    trendPercent,
    updatedAt,
  };
}

function createSuggestedProblem({
  id,
  title,
  shortDescription,
  category,
  status,
  votesUp,
  votesDown,
  submittedByUserId = 'seed',
  submittedByDisplayName = 'Comune',
  createdAt = new Date().toISOString(),
}) {
  return {
    id,
    title,
    shortDescription,
    category,
    status,
    votesUp,
    votesDown,
    score: votesUp - votesDown,
    myVote: 'none',
    submittedByUserId,
    submittedByDisplayName,
    createdAt,
    promotionRule: {
      threshold: 1,
      scopeLabel: category,
      reason: 'Regola demo: una approvazione netta promuove il tema.',
    },
  };
}

function statusToChoice(status) {
  if (status === 'improving') return 'improve';
  if (status === 'worsening') return 'worsen';
  return 'stable';
}

function evaluatePrediction(status, choice) {
  const winningChoice = statusToChoice(status);
  if (choice === winningChoice) return 'correct';
  if (choice === 'stable' || winningChoice === 'stable') return 'partial';
  return 'wrong';
}

function pointsForResult(result) {
  if (result === 'correct') return 10;
  if (result === 'partial') return 4;
  return 0;
}

function choiceNarrative(choice) {
  if (choice === 'improve') return 'migliorera\'';
  if (choice === 'worsen') return 'peggiorera\'';
  return 'restera\' stabile';
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const log = (entry) => console.log(entry);
  const server = startServer({ logger: log });
  server.once('listening', () => {
    const address = server.address();
    const location =
      typeof address === 'string'
        ? address
        : 'http://' + address.address + ':' + address.port;
    log(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'info',
        event: 'server_listening',
        location,
        pilotMunicipalityId: process.env.PILOT_MUNICIPALITY_ID ?? null,
      }),
    );
  });
  server.once('error', (error) => {
    console.error(
      JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'error',
        event: 'server_error',
        message: error.message,
      }),
    );
    process.exitCode = 1;
  });
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => {
      log(
        JSON.stringify({
          timestamp: new Date().toISOString(),
          level: 'info',
          event: 'server_shutdown',
          signal,
        }),
      );
      const forceClose = setTimeout(() => {
        server.closeAllConnections();
        process.exitCode = 1;
      }, 10_000);
      forceClose.unref();
      server.close((error) => {
        clearTimeout(forceClose);
        if (error) {
          console.error(
            JSON.stringify({
              timestamp: new Date().toISOString(),
              level: 'error',
              event: 'server_shutdown_error',
              message: error.message,
            }),
          );
          process.exitCode = 1;
        }
      });
    });
  }
}
