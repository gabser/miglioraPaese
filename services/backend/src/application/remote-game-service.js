import { confidenceValues, motivationValues, predictionChoices, statusToChoice } from '../domain/catalog.js';
import { httpError } from '../domain/errors.js';

// Legacy game results are synthetic demo data. They never award Sentinelle XP.
export function evaluateRemotePrediction(winningChoice, choice) {
  if (choice === winningChoice) return 'correct';
  if (choice === 'stable' || winningChoice === 'stable') return 'partial';
  return 'wrong';
}

export function createRemoteGameService({ repository, minimumAggregateSampleSize = 3 }) {
  if (!Number.isSafeInteger(minimumAggregateSampleSize) || minimumAggregateSampleSize < 1) {
    throw new TypeError('A positive aggregate sample size is required.');
  }
  const resultDto = row => ({ problemId: row.problem_id,
    result: evaluateRemotePrediction(row.winning_choice, row.choice) });
  function reputation(rows) {
    return { totalPoints: rows.reduce((sum, row) => sum + row.points_delta, 0),
      accuracy: rows.length === 0 ? 0 : rows.reduce((sum, row) => {
        const result = resultDto(row).result;
        return sum + (result === 'correct' ? 1 : result === 'partial' ? 0.5 : 0);
      }, 0) / rows.length,
      predictionsCount: rows.length };
  }
  function aggregate(problemId, rows) {
    const choices = Object.fromEntries([...predictionChoices].map(key => [key, 0]));
    const motivations = Object.fromEntries([...motivationValues].map(key => [key, 0]));
    if (rows.length >= minimumAggregateSampleSize) {
      for (const row of rows) {
        choices[row.choice]++;
        for (const key of row.motivations) motivations[key]++;
      }
    }
    return { problemId, totalPredictions: rows.length >= minimumAggregateSampleSize ? rows.length : 0,
      choiceDistribution: choices, motivationDistribution: motivations };
  }
  return {
    async resolvePrediction(input) {
      if (!predictionChoices.has(input.choice)) throw httpError(400, 'invalid_field', 'Invalid prediction choice.');
      return repository.resolvePrediction(input, (prediction, problem) => {
        if (prediction.choice !== input.choice) {
          throw httpError(409, 'prediction_choice_mismatch', 'Resolution choice differs from the saved prediction.');
        }
        const winningChoice = statusToChoice(problem.status);
        const result = evaluateRemotePrediction(winningChoice, prediction.choice);
        return { winningChoice, result, correct: result === 'correct',
          pointsDelta: result === 'correct' ? 10 : result === 'partial' ? 4 : 0 };
      });
    },
    async getPredictionResults(input) {
      return { items: (await repository.resultsForTurn(input)).map(resultDto) };
    },
    async getReputationScore(input) { return reputation(await repository.resultsForTurn(input)); },
    async getReputationHistory(input) {
      const groups = await repository.resultsForMunicipality(input);
      return { items: groups.map(group => reputation(group.results)) };
    },
    async getAggregatedInsight(problemId) {
      const groups = await repository.predictionsForProblem(problemId);
      return aggregate(problemId, groups.at(-1)?.predictions ?? []);
    },
    async getInsightHistory(problemId) {
      const groups = await repository.predictionsForProblem(problemId);
      return { problemId, snapshots: groups.map(group => {
        const insight = aggregate(problemId, group.predictions);
        const motivationTop = Object.entries(insight.motivationDistribution)
          .filter(([, count]) => count > 0)
          .sort(([a, ac], [b, bc]) => bc - ac || a.localeCompare(b))
          .slice(0, 2).map(([key]) => key);
        const at = insight.totalPredictions === 0 ? group.startAt :
          group.predictions.reduce((latest, row) => row.updated_at > latest ? row.updated_at : latest, group.startAt);
        return { turnId: group.turnId, at, totalPredictions: insight.totalPredictions,
          choiceDistribution: insight.choiceDistribution, motivationTop };
      }) };
    },
    async getCriticalInsights({ problemId, userChoice = null, userConfidence = null, userReflectionIndex = null }) {
      if ((userChoice !== null && !predictionChoices.has(userChoice)) ||
          (userConfidence !== null && !confidenceValues.has(userConfidence)) ||
          (userReflectionIndex !== null && (!Number.isSafeInteger(userReflectionIndex) || userReflectionIndex < 0 || userReflectionIndex > 20))) {
        throw httpError(400, 'invalid_field', 'Invalid insight context.');
      }
      const insight = await this.getAggregatedInsight(problemId);
      if (insight.totalPredictions === 0) return { items: [{ headline: 'Dati in raccolta',
        supporting: 'Non ci sono ancora previsioni aggregate per questo tema.', note: null }] };
      const ordered = Object.entries(insight.choiceDistribution).sort(([a, ac], [b, bc]) => bc - ac || a.localeCompare(b));
      const [choice, count] = ordered[0];
      const narrative = { improve: "migliorera'", worsen: "peggiorera'", stable: "restera' stabile" };
      const items = [{ headline: 'Percezione prevalente',
        supporting: `${Math.round(count / insight.totalPredictions * 100)}% prevede che il problema ${narrative[choice]}.`,
        note: ordered[1][1] === count ? 'Opinioni divise.' : null }];
      if (userChoice !== null) items.push({
        headline: userChoice === choice ? "La tua lettura e' condivisa" : "La tua lettura e' minoritaria",
        supporting: userChoice === choice ? "La scelta coincide con la previsione piu' frequente." : "La scelta differisce dalla previsione piu' frequente.",
        note: userConfidence === null ? null : `Convinzione dichiarata: ${userConfidence}.` });
      if (userReflectionIndex !== null) items.push({ headline: 'Riflessione registrata',
        supporting: `La risposta ${userReflectionIndex + 1} contestualizza il confronto aggregato.`, note: null });
      return { items };
    },
  };
}
