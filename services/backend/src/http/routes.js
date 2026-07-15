const routePatterns = [
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

export function matchRoute(method, pathname) {
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
