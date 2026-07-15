export const problemKeys = new Set([
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

export const predictionChoices = new Set(['improve', 'stable', 'worsen']);
export const confidenceValues = new Set([
  'gutFeeling',
  'considered',
  'convinced',
]);
export const voteChoices = new Set(['up', 'down']);
export const suggestedProblemStatuses = new Set([
  'pending',
  'approved',
  'rejected',
]);
export const motivationValues = new Set([
  'visibleActions',
  'recentDecline',
  'seasonality',
  'unmetPromises',
  'personalExperience',
]);

export const inputLimits = Object.freeze({
  jsonBodyBytes: 64 * 1024,
  titleLength: 120,
  descriptionLength: 1000,
  queryLength: 120,
  userIdLength: 128,
});

const municipalityAliases = new Map([
  ['bologna', 'bologna'],
  ['comune:bologna', 'bologna'],
  ['castel-bolognese', 'castel-bolognese'],
  ['castel bolognese', 'castel-bolognese'],
  ['comune:castel bolognese', 'castel-bolognese'],
]);

export function canonicalMunicipalityId(value) {
  if (typeof value !== 'string') return value;
  const normalized = value.trim().toLowerCase();
  return municipalityAliases.get(normalized) ?? normalized;
}

export function normalizeTitle(value) {
  return value.trim().toLowerCase().replaceAll(/\s+/g, ' ');
}

export function createProblem({
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

export function createSuggestedProblem({
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

export function statusToChoice(status) {
  if (status === 'improving') return 'improve';
  if (status === 'worsening') return 'worsen';
  return 'stable';
}
