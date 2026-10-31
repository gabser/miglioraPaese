import {
  confidenceValues,
  createProblem,
  createSuggestedProblem,
  motivationValues,
  predictionChoices,
  problemKeys,
  suggestedProblemStatuses,
} from '../../domain/catalog.js';
import { normalizeProposalLocation } from '../../domain/proposal-location.js';

const activationStates = new Set([
  'active',
  'collectingSignals',
  'newMunicipality',
]);
const turnStates = new Set(['open', 'calculating', 'closed']);
const problemStates = new Set(['improving', 'stable', 'worsening']);
const userVotes = new Set(['none', 'up', 'down']);

export function mapMunicipalityRow(row) {
  assertRowKeys(row, [
    'id',
    'name',
    'activation_state',
    'base_activation_state',
  ]);
  return {
    id: requiredText(row.id, 'municipality.id'),
    name: requiredText(row.name, 'municipality.name'),
    activationState: enumValue(
      row.activation_state,
      activationStates,
      'municipality.activation_state',
    ),
    baseActivationState: enumValue(
      row.base_activation_state,
      activationStates,
      'municipality.base_activation_state',
    ),
  };
}

export function mapTurnRow(row) {
  assertRowKeys(row, [
    'id',
    'municipality_id',
    'state',
    'start_at',
    'end_at',
  ]);
  const startAt = timestamp(row.start_at, 'turn.start_at');
  const endAt = timestamp(row.end_at, 'turn.end_at');
  if (Date.parse(endAt) <= Date.parse(startAt)) {
    throw new TypeError('turn.end_at must be after turn.start_at.');
  }
  return {
    id: requiredText(row.id, 'turn.id'),
    municipalityId: requiredText(row.municipality_id, 'turn.municipality_id'),
    state: enumValue(row.state, turnStates, 'turn.state'),
    startAt,
    endAt,
  };
}

export function mapProblemRow(row) {
  assertRowKeys(row, [
    'id',
    'problem_key',
    'title',
    'zone_name',
    'status',
    'trend_percent',
    'updated_at',
  ]);
  return createProblem({
    id: requiredText(row.id, 'problem.id'),
    key: enumValue(row.problem_key, problemKeys, 'problem.problem_key'),
    title: requiredText(row.title, 'problem.title'),
    zoneName: requiredText(row.zone_name, 'problem.zone_name'),
    status: enumValue(row.status, problemStates, 'problem.status'),
    trendPercent: integer(row.trend_percent, 'problem.trend_percent', {
      min: -100,
      max: 100,
    }),
    updatedAt: timestamp(row.updated_at, 'problem.updated_at'),
  });
}

export function mapSuggestedProblemRow(row) {
  assertRowKeys(row, [
    'id',
    'title',
    'description',
    'location',
    'category',
    'status',
    'submitted_by_user_id',
    'submitted_by_display_name',
    'created_at',
    'votes_up',
    'votes_down',
    'my_vote',
  ]);
  const suggestion = createSuggestedProblem({
    id: requiredText(row.id, 'suggestion.id'),
    title: requiredText(row.title, 'suggestion.title'),
    location: mapLocation(row.location),
    shortDescription: requiredText(
      row.description,
      'suggestion.description',
    ),
    category: enumValue(row.category, problemKeys, 'suggestion.category'),
    status: enumValue(
      row.status,
      suggestedProblemStatuses,
      'suggestion.status',
    ),
    submittedByUserId: requiredText(
      row.submitted_by_user_id,
      'suggestion.submitted_by_user_id',
    ),
    submittedByDisplayName: requiredText(
      row.submitted_by_display_name,
      'suggestion.submitted_by_display_name',
    ),
    createdAt: timestamp(row.created_at, 'suggestion.created_at'),
    votesUp: integer(row.votes_up, 'suggestion.votes_up', {
      min: 0,
      max: Number.MAX_SAFE_INTEGER,
    }),
    votesDown: integer(row.votes_down, 'suggestion.votes_down', {
      min: 0,
      max: Number.MAX_SAFE_INTEGER,
    }),
  });
  return {
    ...suggestion,
    myVote: enumValue(row.my_vote, userVotes, 'suggestion.my_vote'),
  };
}

export function mapPredictionRow(row) {
  assertRowKeys(row, [
    'id',
    'turn_id',
    'problem_id',
    'user_id',
    'choice',
    'motivations',
    'confidence',
    'created_at',
    'updated_at',
  ]);
  if (!Array.isArray(row.motivations)) {
    throw new TypeError('prediction.motivations must be an array.');
  }
  const motivations = row.motivations.map((value) =>
    enumValue(value, motivationValues, 'prediction.motivations'),
  );
  if (motivations.length > 2 || new Set(motivations).size !== motivations.length) {
    throw new TypeError('prediction.motivations must contain at most two unique values.');
  }
  const createdAt = timestamp(row.created_at, 'prediction.created_at');
  const updatedAt = timestamp(row.updated_at, 'prediction.updated_at');
  if (Date.parse(updatedAt) < Date.parse(createdAt)) {
    throw new TypeError('prediction.updated_at must not precede created_at.');
  }
  return {
    id: requiredText(row.id, 'prediction.id'),
    turnId: requiredText(row.turn_id, 'prediction.turn_id'),
    problemId: requiredText(row.problem_id, 'prediction.problem_id'),
    userId: requiredText(row.user_id, 'prediction.user_id'),
    choice: enumValue(row.choice, predictionChoices, 'prediction.choice'),
    motivations,
    confidence:
      row.confidence === null
        ? null
        : enumValue(
            row.confidence,
            confidenceValues,
            'prediction.confidence',
          ),
    createdAt,
    updatedAt,
  };
}

function assertRowKeys(row, expectedKeys) {
  if (row === null || typeof row !== 'object' || Array.isArray(row)) {
    throw new TypeError('PostgreSQL mapper expected an object row.');
  }
  const actual = Object.keys(row).sort();
  const expected = [...expectedKeys].sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    throw new TypeError(
      `Unexpected PostgreSQL row shape: expected ${expected.join(', ')}; received ${actual.join(', ')}.`,
    );
  }
}

function mapLocation(value) {
  try {
    return normalizeProposalLocation(value);
  } catch {
    throw new TypeError('suggestion.location contains an invalid place.');
  }
}

function requiredText(value, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${field} must be a non-empty string.`);
  }
  return value;
}

function enumValue(value, allowed, field) {
  if (typeof value !== 'string' || !allowed.has(value)) {
    throw new TypeError(`${field} contains an unknown enum value.`);
  }
  return value;
}

function integer(value, field, { min, max }) {
  const parsed = typeof value === 'string' ? Number(value) : value;
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) {
    throw new TypeError(`${field} must be a safe integer between ${min} and ${max}.`);
  }
  return parsed;
}

function timestamp(value, field) {
  if (value instanceof Date) {
    if (Number.isNaN(value.valueOf())) {
      throw new TypeError(`${field} must be a valid timestamp.`);
    }
    return value.toISOString();
  }
  if (
    typeof value !== 'string' ||
    !/(?:Z|[+-]\d{2}:\d{2})$/.test(value) ||
    Number.isNaN(Date.parse(value))
  ) {
    throw new TypeError(`${field} must include an explicit timezone.`);
  }
  return new Date(value).toISOString();
}
