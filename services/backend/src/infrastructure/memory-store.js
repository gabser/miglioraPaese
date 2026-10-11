import { assertPublicProposalContent, assertSubmissionQuota, validateProposalReview } from '../domain/proposal-policy.js';
import { newProposalSession, sessionHash, sessionIdentity, sessionRevoked, scopedSubmissionKey } from '../domain/proposal-session.js';
import {
  canonicalMunicipalityId,
  createProblem,
  createSuggestedProblem,
  statusToChoice,
} from '../domain/catalog.js';
import { httpError } from '../domain/errors.js';
import { normalizeProposalLocation, proposalLocationLabel } from '../domain/proposal-location.js';

export function createMemoryStore({ clock = Date.now } = {}) {
  if (typeof clock !== 'function') throw new TypeError('A server clock is required.');
  const reviewHistory = [];
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
  const idempotentWrites = new Map();
  const sessions = new Map();

  function createProposalSession() {
    const session = newProposalSession();
    sessions.set(session.tokenHash, { submissionScope: session.submissionScope, revoked: false });
    return { token: session.token, submissionScope: session.submissionScope };
  }

  function getProposalSession(token) {
    const session = sessions.get(sessionHash(token));
    if (!session || session.revoked) throw sessionRevoked();
    return { submissionScope: session.submissionScope };
  }

  function revokeProposalSession(token) {
    const key = sessionHash(token);
    const session = sessions.get(key);
    if (!session) throw sessionRevoked();
    session.revoked = true;
    return { revoked: true };
  }

  function sessionInput(input) {
    const { sessionToken, ...fields } = input;
    if (!sessionToken) {
      if (fields.userId?.startsWith('session:')) throw httpError(401, 'proposal_session_required', 'A valid proposal session is required.');
      return fields;
    }
    const session = getProposalSession(sessionToken);
    const municipalityId = getMunicipality(fields.municipalityId).id;
    return { ...fields, municipalityId, userId: sessionIdentity(session),
      ...(fields.idempotencyKey ? { idempotencyKey: scopedSubmissionKey(
        session.submissionScope, municipalityId, fields.idempotencyKey) } : {}) };
  }

  function lookupSubmission(input) {
    getProposalSession(input.sessionToken);
    const fields = sessionInput(input);
    const record = idempotentWrites.get('submit_suggestion:' + fields.idempotencyKey);
    if (!record) throw httpError(404, 'submission_not_found', 'Submission not found.');
    return structuredClone(record.value);
  }

  function getOwnNextProblem(input) {
    getProposalSession(input.sessionToken);
    const fields = sessionInput(input);
    const value = getNextProblem(fields);
    if (value.submittedByUserId !== fields.userId) {
      throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
    }
    return value;
  }

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
          item.shortDescription.toLowerCase().includes(normalized) ||
          (item.location !== null && proposalLocationLabel(item.location).toLowerCase().includes(normalized)) ||
          (item.location?.reference ?? '').toLowerCase().includes(normalized)
        );
      });
    }
    return items.map((item) => withUserVote(item, userId));
  }

  function submitNextProblem(input) {
    const { idempotencyKey, location: rawLocation, ...fields } = sessionInput(input);
    const location = normalizeProposalLocation(rawLocation);
    const request = { ...fields, ...(location === null ? {} : { location }) };
    return runIdempotentWrite(
      'submit_suggestion',
      idempotencyKey,
      request,
      () => submitNextProblemCore(request),
    );
  }

  function getNextProblem({ municipalityId, problemId, userId = 'demo-user' }) {
    const municipality = getMunicipality(municipalityId);
    const items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const problem = items.find((item) => item.id === problemId);
    if (!problem) throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
    return withUserVote(problem, userId);
  }

  function submitNextProblemCore({
    municipalityId,
    title,
    description,
    category,
    location = null,
    userId,
  }) {
    const municipality = getMunicipality(municipalityId);
    assertPublicProposalContent({ title, description, location });
    const items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const nowMs = clock();
    assertSubmissionQuota(items.filter(item => item.submittedByUserId === userId).map(item => item.createdAt), nowMs);
    const created = createSuggestedProblem({
      createdAt: new Date(nowMs).toISOString(),
      id: `suggested-${nextProblemCounter++}`,
      title,
      shortDescription: description,
      category,
      location,
      status: 'pending',
      votesUp: 0,
      votesDown: 0,
      submittedByUserId: userId,
      submittedByDisplayName: userId === 'demo-user' ? 'Tu' : 'Cittadino',
    });
    nextProblemsByMunicipality.set(municipality.id, [created, ...items]);
    return withUserVote(created, userId);
  }

  function reviewSuggestion(input) {
    const review = validateProposalReview(input);
    const municipality = getMunicipality(input.municipalityId);
    const items = nextProblemsByMunicipality.get(municipality.id) ?? [];
    const item = items.find(value => value.id === input.problemId);
    if (!item) throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
    if (item.status !== review.expectedStatus) throw httpError(409, 'review_conflict', 'The proposal state changed.');
    const event = { ...review, municipalityId: municipality.id, problemId: item.id, reviewedAt: new Date(clock()).toISOString() };
    item.status = review.targetStatus;
    reviewHistory.push(event);
    return withUserVote(item, input.userId ?? 'operator');
  }

  function voteNextProblem(input) {
    const { idempotencyKey, ...request } = sessionInput(input);
    return runIdempotentWrite(
      'vote_suggestion',
      idempotencyKey,
      request,
      () => voteNextProblemCore(request),
    );
  }

  function voteNextProblemCore({ municipalityId, problemId, vote, userId }) {
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

    const current = items[index];
    if (current.status === 'rejected') {
      throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
    }
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
          zoneName: proposalLocationLabel(suggestion.location),
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

  function upsertPrediction(input) {
    const { idempotencyKey, ...request } = sessionInput(input);
    return runIdempotentWrite(
      'upsert_prediction',
      idempotencyKey,
      request,
      () => upsertPredictionCore(request),
    );
  }

  function upsertPredictionCore({
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

  function runIdempotentWrite(operation, idempotencyKey, request, callback) {
    if (!idempotencyKey) return callback();
    const recordKey = `${operation}:${idempotencyKey}`;
    const fingerprint = JSON.stringify(request);
    const existing = idempotentWrites.get(recordKey);
    if (existing) {
      if (existing.fingerprint !== fingerprint) {
        throw httpError(
          409,
          'idempotency_key_reused',
          'Idempotency-Key was already used for a different request.',
        );
      }
      return structuredClone(existing.value);
    }
    const value = callback();
    idempotentWrites.set(recordKey, {
      fingerprint,
      value: structuredClone(value),
    });
    return value;
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
    const confirmedItems = listNextProblems({
      municipalityId,
      status: 'approved',
    }).sort((a, b) => b.score - a.score);
    return {
      municipalityName: municipality.name,
      proposedThemes,
      confirmedThemes: confirmedItems.length,
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
    createProposalSession, getProposalSession, revokeProposalSession, lookupSubmission, getOwnNextProblem,
    getMunicipality,
    getCurrentTurn,
    listProblems,
    listNextProblems,
    getNextProblem,
    submitNextProblem,
    reviewSuggestion,
    voteNextProblem,
    getPredictions,
    upsertPrediction,
    resolvePrediction,
    getCivicLoopSummary,
    getLeaderboard,
  };
}
