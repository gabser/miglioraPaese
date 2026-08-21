import http from 'node:http';
import { URL } from 'node:url';

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
const maxQueryLength = 120;
const maxUserIdLength = 128;

const municipalityAliases = new Map([
  ['bologna', 'bologna'],
  ['comune:bologna', 'bologna'],
  ['castel-bolognese', 'castel-bolognese'],
  ['castel bolognese', 'castel-bolognese'],
  ['comune:castel bolognese', 'castel-bolognese'],
]);

export function createApp(options = {}) {
  const store = options.store ?? createMemoryStore();
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
          store.getCivicLoopSummary(route.params.municipalityId),
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
              userId: textOrDefault(
                url.searchParams.get('userId'),
                'demo-user',
                'userId',
                maxUserIdLength,
              ),
            }),
          },
          responseHeaders,
        );
      }

      if (route.name === 'submitNextProblem') {
        const body = await readJson(req);
        const created = store.submitNextProblem({
          municipalityId: route.params.municipalityId,
          title: requireText(body.title, 'title', maxTitleLength),
          description: requireText(
            body.description,
            'description',
            maxDescriptionLength,
          ),
          category: requireEnum(body.category, problemKeys, 'category'),
          userId: textOrDefault(
            body.userId,
            'demo-user',
            'userId',
            maxUserIdLength,
          ),
        });
        return sendJson(res, 201, created, responseHeaders);
      }

      if (route.name === 'voteNextProblem') {
        const body = await readJson(req);
        const updated = store.voteNextProblem({
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          vote: requireEnum(body.vote, voteChoices, 'vote'),
          userId: textOrDefault(
            body.userId,
            'demo-user',
            'userId',
            maxUserIdLength,
          ),
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
              userId: textOrDefault(
                url.searchParams.get('userId'),
                'demo-user',
                'userId',
                maxUserIdLength,
              ),
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
          userId: textOrDefault(
            body.userId,
            'demo-user',
            'userId',
            maxUserIdLength,
          ),
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

      if (route.name === 'resolvePrediction') {
        const body = await readJson(req);
        const result = store.resolvePrediction({
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

export function createMemoryStore() {
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

  const now = Date.now();
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
        }),
        createProblem({
          id: 'problem-green-margherita',
          key: 'green',
          title: 'Verde ai Giardini Margherita',
          zoneName: 'Santo Stefano',
          status: 'improving',
          trendPercent: 9,
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
        }),
        createSuggestedProblem({
          id: 'suggested-lighting-park',
          title: 'Illuminazione al parco',
          shortDescription: 'Percorsi poco leggibili nelle ore serali.',
          category: 'lighting',
          votesUp: 0,
          votesDown: 0,
          status: 'pending',
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
        }),
      ],
    ],
  ]);

  const votesByProblem = new Map();
  const predictionsByTurn = new Map();
  let nextProblemCounter = 200;

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

    const created = createSuggestedProblem({
      id: `suggested-${nextProblemCounter++}`,
      title,
      shortDescription: description,
      category,
      status: 'pending',
      votesUp: 0,
      votesDown: 0,
      submittedByUserId: userId,
      submittedByDisplayName: userId === 'demo-user' ? 'Tu' : 'Cittadino',
    });
    nextProblemsByMunicipality.set(municipality.id, [created, ...items]);
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
        current.status === 'rejected'
          ? 'rejected'
          : votesUp - votesDown >= 1
            ? 'approved'
            : 'pending',
    };
    items[index] = updated;
    syncPromotion(municipality, updated);
    return withUserVote(updated, userId);
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
          updatedAt: new Date().toISOString(),
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
    const timestamp = new Date().toISOString();
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
    return prediction;
  }

  function resolvePrediction({ problemId, choice }) {
    const problem = findProblem(problemId);
    const winningChoice = statusToChoice(problem.status);
    const correct = choice === winningChoice;
    return {
      problemId,
      choice,
      winningChoice,
      correct,
      pointsDelta: correct ? 12 : -3,
      resolvedAt: new Date().toISOString(),
    };
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

  function getCivicLoopSummary(municipalityId) {
    const municipality = getMunicipality(municipalityId);
    const turn = getCurrentTurn(municipalityId);
    const predictions = getPredictions({
      turnId: turn.id,
      userId: 'demo-user',
    });
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
      outcomes: 0,
      reputationPoints: 0,
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
    getPredictions,
    upsertPrediction,
    resolvePrediction,
    getCivicLoopSummary,
    getLeaderboard,
  };
}

export function startServer({
  port = process.env.PORT ?? 8787,
  host = process.env.HOST ?? '127.0.0.1',
  store,
  allowedOrigins,
} = {}) {
  const server = http.createServer(createApp({ store, allowedOrigins }));
  server.listen(normalizePort(port), host);
  return server;
}

function matchRoute(method, pathname) {
  if (method === 'GET' && pathname === '/health') {
    return { name: 'health', params: {} };
  }

  const patterns = [
    ['GET', /^\/v1\/municipalities\/([^/]+)\/activation$/, 'municipalityActivation'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/summary$/, 'municipalitySummary'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/turn$/, 'currentTurn'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/problems$/, 'problems'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/leaderboard$/, 'leaderboard'],
    ['GET', /^\/v1\/municipalities\/([^/]+)\/next-problems$/, 'nextProblems'],
    ['POST', /^\/v1\/municipalities\/([^/]+)\/next-problems$/, 'submitNextProblem'],
    [
      'POST',
      /^\/v1\/municipalities\/([^/]+)\/next-problems\/([^/]+)\/votes$/,
      'voteNextProblem',
    ],
    ['GET', /^\/v1\/turns\/([^/]+)\/predictions$/, 'predictions'],
    ['PUT', /^\/v1\/turns\/([^/]+)\/predictions\/([^/]+)$/, 'upsertPrediction'],
    ['POST', /^\/v1\/problems\/([^/]+)\/resolve$/, 'resolvePrediction'],
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
    name === 'nextProblems' ||
    name === 'submitNextProblem'
  ) {
    return { municipalityId: decodeURIComponent(match[1]) };
  }
  if (name === 'voteNextProblem') {
    return {
      municipalityId: decodeURIComponent(match[1]),
      problemId: decodeURIComponent(match[2]),
    };
  }
  if (name === 'predictions') {
    return { turnId: decodeURIComponent(match[1]) };
  }
  if (name === 'upsertPrediction') {
    return {
      turnId: decodeURIComponent(match[1]),
      problemId: decodeURIComponent(match[2]),
    };
  }
  if (name === 'resolvePrediction') {
    return { problemId: decodeURIComponent(match[1]) };
  }
  return {};
}

function canonicalMunicipalityId(value) {
  if (typeof value !== 'string') return value;
  const normalized = value.trim().toLowerCase();
  return municipalityAliases.get(normalized) ?? normalized;
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

function textOrDefault(value, fallback, field, maxLength) {
  if (value == null) return fallback;
  return requireText(value, field, maxLength);
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

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = startServer();
  server.once('listening', () => {
    const address = server.address();
    const location =
      typeof address === 'string'
        ? address
        : 'http://' + address.address + ':' + address.port;
    console.log('Backend listening on ' + location);
  });
  server.once('error', (error) => {
    console.error('Backend failed to start:', error.message);
    process.exitCode = 1;
  });
}
