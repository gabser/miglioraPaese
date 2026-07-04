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

export function createApp(options = {}) {
  const store = options.store ?? createMemoryStore();

  return async function app(req, res) {
    try {
      const url = new URL(req.url ?? '/', 'http://localhost');
      const route = matchRoute(req.method ?? 'GET', url.pathname);

      if (!route) {
        return sendJson(res, 404, { error: 'not_found' });
      }

      if (route.name === 'health') {
        return sendJson(res, 200, { status: 'ok' });
      }

      if (route.name === 'municipalityActivation') {
        const municipality = store.getMunicipality(route.params.municipalityId);
        return sendJson(res, 200, {
          municipalityId: municipality.id,
          state: municipality.activationState,
        });
      }

      if (route.name === 'municipalitySummary') {
        return sendJson(
          res,
          200,
          store.getCivicLoopSummary(route.params.municipalityId),
        );
      }

      if (route.name === 'currentTurn') {
        return sendJson(res, 200, store.getCurrentTurn(route.params.municipalityId));
      }

      if (route.name === 'problems') {
        return sendJson(res, 200, {
          items: store.listProblems(route.params.municipalityId),
        });
      }

      if (route.name === 'leaderboard') {
        return sendJson(res, 200, {
          items: store.getLeaderboard(route.params.municipalityId),
        });
      }

      if (route.name === 'nextProblems') {
        return sendJson(res, 200, {
          items: store.listNextProblems({
            municipalityId: route.params.municipalityId,
            status: url.searchParams.get('status'),
            query: url.searchParams.get('query'),
          }),
        });
      }

      if (route.name === 'submitNextProblem') {
        const body = await readJson(req);
        const created = store.submitNextProblem({
          municipalityId: route.params.municipalityId,
          title: requireText(body.title, 'title'),
          description: requireText(body.description, 'description'),
          category: requireEnum(body.category, problemKeys, 'category'),
          userId: textOrDefault(body.userId, 'demo-user'),
        });
        return sendJson(res, 201, created);
      }

      if (route.name === 'voteNextProblem') {
        const body = await readJson(req);
        const updated = store.voteNextProblem({
          municipalityId: route.params.municipalityId,
          problemId: route.params.problemId,
          vote: requireEnum(body.vote, voteChoices, 'vote'),
          userId: textOrDefault(body.userId, 'demo-user'),
        });
        return sendJson(res, 200, updated);
      }

      if (route.name === 'predictions') {
        return sendJson(res, 200, {
          items: store.getPredictions({
            turnId: route.params.turnId,
            userId: textOrDefault(url.searchParams.get('userId'), 'demo-user'),
          }),
        });
      }

      if (route.name === 'upsertPrediction') {
        const body = await readJson(req);
        const prediction = store.upsertPrediction({
          turnId: route.params.turnId,
          problemId: route.params.problemId,
          userId: textOrDefault(body.userId, 'demo-user'),
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
          motivations: requireStringArray(body.motivations ?? [], 'motivations'),
          confidence: optionalEnum(body.confidence, confidenceValues, 'confidence'),
        });
        return sendJson(res, 200, prediction);
      }

      if (route.name === 'resolvePrediction') {
        const body = await readJson(req);
        const result = store.resolvePrediction({
          problemId: route.params.problemId,
          choice: requireEnum(body.choice, predictionChoices, 'choice'),
        });
        return sendJson(res, 200, result);
      }

      return sendJson(res, 500, { error: 'unhandled_route' });
    } catch (error) {
      const status = error.statusCode ?? 500;
      return sendJson(res, status, {
        error: error.code ?? 'internal_error',
        message: status === 500 ? 'Unexpected error.' : error.message,
      });
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
        activationState: 'activating',
      },
    ],
    [
      'bologna',
      {
        id: 'bologna',
        name: 'Bologna',
        activationState: 'active',
      },
    ],
  ]);

  const turnsByMunicipality = new Map([
    [
      'castel-bolognese',
      {
        id: 'turn-castel-bolognese-today',
        municipalityId: 'castel-bolognese',
        state: 'open',
        startsAt: '2026-07-04T00:00:00.000Z',
        endsAt: '2026-07-04T21:59:59.000Z',
      },
    ],
    [
      'bologna',
      {
        id: 'turn-bologna-today',
        municipalityId: 'bologna',
        state: 'open',
        startsAt: '2026-07-04T00:00:00.000Z',
        endsAt: '2026-07-04T21:59:59.000Z',
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
          votesUp: 1,
          votesDown: 0,
          status: 'approved',
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
    const municipality = municipalities.get(municipalityId);
    if (!municipality) {
      throw httpError(404, 'municipality_not_found', 'Municipality not found.');
    }
    return municipality;
  }

  function getCurrentTurn(municipalityId) {
    getMunicipality(municipalityId);
    return turnsByMunicipality.get(municipalityId);
  }

  function listProblems(municipalityId) {
    getMunicipality(municipalityId);
    return problemsByMunicipality.get(municipalityId) ?? [];
  }

  function listNextProblems({ municipalityId, status, query }) {
    getMunicipality(municipalityId);
    let items = nextProblemsByMunicipality.get(municipalityId) ?? [];
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
    return items;
  }

  function submitNextProblem({
    municipalityId,
    title,
    description,
    category,
    userId,
  }) {
    getMunicipality(municipalityId);
    const items = nextProblemsByMunicipality.get(municipalityId) ?? [];
    const duplicate = items.some(
      (item) => item.title.trim().toLowerCase() === title.trim().toLowerCase(),
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
    nextProblemsByMunicipality.set(municipalityId, [created, ...items]);
    return created;
  }

  function voteNextProblem({ municipalityId, problemId, vote, userId }) {
    getMunicipality(municipalityId);
    const items = nextProblemsByMunicipality.get(municipalityId) ?? [];
    const index = items.findIndex((item) => item.id === problemId);
    if (index === -1) {
      throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
    }

    const current = items[index];
    const userVotes = votesByProblem.get(problemId) ?? new Map();
    const previousVote = userVotes.get(userId) ?? 'none';
    let votesUp = current.votesUp;
    let votesDown = current.votesDown;

    if (previousVote === 'up') votesUp -= 1;
    if (previousVote === 'down') votesDown -= 1;

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
      myVote: nextVote,
      status: votesUp - votesDown >= 1 ? 'approved' : 'pending',
    };
    items[index] = updated;
    return updated;
  }

  function getPredictions({ turnId, userId }) {
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
    const turnPredictions = predictionsByTurn.get(turnId) ?? new Map();
    const id = `${turnId}:${problemId}:${userId}`;
    const prediction = {
      id,
      turnId,
      problemId,
      userId,
      choice,
      motivations,
      confidence,
      updatedAt: new Date().toISOString(),
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
    for (const problems of problemsByMunicipality.values()) {
      const problem = problems.find((item) => item.id === problemId);
      if (problem) return problem;
    }
    throw httpError(404, 'problem_not_found', 'Problem not found.');
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
    return {
      municipalityName: municipality.name,
      proposedThemes,
      confirmedThemes,
      cardsInTurn: listProblems(municipalityId).length,
      predictions: predictions.length,
      outcomes: 0,
      reputationPoints: 0,
      topThemeTitle:
        listNextProblems({ municipalityId, status: 'approved' })[0]?.title ?? null,
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

export function startServer({ port = process.env.PORT ?? 8787 } = {}) {
  const server = http.createServer(createApp());
  server.listen(Number(port), '127.0.0.1');
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

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw.trim()) return {};
  try {
    return JSON.parse(raw);
  } catch {
    throw httpError(400, 'invalid_json', 'Request body must be valid JSON.');
  }
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

function requireText(value, field) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw httpError(400, 'invalid_field', `${field} is required.`);
  }
  return value.trim();
}

function textOrDefault(value, fallback) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return fallback;
  }
  return value.trim();
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

function requireStringArray(value, field) {
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    throw httpError(400, 'invalid_field', `${field} must be a string array.`);
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
}) {
  return {
    id,
    key,
    title,
    zoneName,
    status,
    trendPercent,
    updatedAt: '2026-07-04T08:00:00.000Z',
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
    createdAt: '2026-07-04T08:00:00.000Z',
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
  const address = server.address();
  console.log(`Backend listening on http://${address.address}:${address.port}`);
}
