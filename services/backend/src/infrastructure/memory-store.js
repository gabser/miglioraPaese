import {
  canonicalMunicipalityId,
  createProblem,
  createSuggestedProblem,
  normalizeTitle,
  statusToChoice,
} from '../domain/catalog.js';
import { httpError } from '../domain/errors.js';

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
      throw httpError(
        404,
        'suggested_problem_not_found',
        'Suggested problem not found.',
      );
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
