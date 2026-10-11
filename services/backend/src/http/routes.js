import { httpError } from '../domain/errors.js';

const routePatterns = [
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
    return { municipalityId: decodeRouteParam(match[1]) };
  }
  if (name === 'voteNextProblem' || name === 'nextProblem' || name === 'ownNextProblem' || name === 'lookupSubmission') {
    return {
      municipalityId: decodeRouteParam(match[1]),
      problemId: decodeRouteParam(match[2]),
    };
  }
  if (name === 'predictions') {
    return { turnId: decodeRouteParam(match[1]) };
  }
  if (name === 'upsertPrediction') {
    return {
      turnId: decodeRouteParam(match[1]),
      problemId: decodeRouteParam(match[2]),
    };
  }
  if (name === 'resolvePrediction') {
    return { problemId: decodeRouteParam(match[1]) };
  }
  return {};
}

function decodeRouteParam(value) {
  try { return decodeURIComponent(value); }
  catch { throw httpError(400, 'invalid_field', 'Path parameters must be valid UTF-8.'); }
}
