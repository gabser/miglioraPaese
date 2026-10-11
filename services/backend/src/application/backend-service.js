import { httpError } from '../domain/errors.js';
import { isPublicSuggestion, publicSuggestion } from '../domain/public-suggestion.js';

export function createBackendService(store) {
  if (!store) {
    throw new TypeError('A store is required.');
  }

  async function getPublicNextProblem(input) {
    try {
      const problem = await store.getNextProblem(input);
      if (!isPublicSuggestion(problem)) {
        throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
      }
      return publicSuggestion(problem);
    } catch (error) {
      if (error.statusCode === 404) {
        throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
      }
      throw error;
    }
  }

  return {
    createProposalSession: () => store.createProposalSession(),
    getProposalSession: token => store.getProposalSession(token),
    revokeProposalSession: token => store.revokeProposalSession(token),
    async lookupSubmission(input) {
      return publicSuggestion(await store.lookupSubmission(input));
    },
    async getOwnNextProblem(input) {
      return publicSuggestion(await store.getOwnNextProblem(input));
    },
    async getMunicipalityActivation(municipalityId) {
      const municipality = await store.getMunicipality(municipalityId);
      return {
        municipalityId: municipality.id,
        state: municipality.activationState,
      };
    },

    async getCivicLoopSummary(municipalityId) {
      return await store.getCivicLoopSummary(municipalityId);
    },

    async getCurrentTurn(municipalityId) {
      return await store.getCurrentTurn(municipalityId);
    },

    async listProblems(municipalityId) {
      return { items: await store.listProblems(municipalityId) };
    },

    async getLeaderboard(municipalityId) {
      return { items: await store.getLeaderboard(municipalityId) };
    },

    async listNextProblems(input) {
      const items = await store.listNextProblems(input);
      return { items: items.filter(isPublicSuggestion).map(publicSuggestion) };
    },

    getNextProblem: getPublicNextProblem,

    async submitNextProblem(input) {
      return publicSuggestion(await store.submitNextProblem(input));
    },

    async voteNextProblem(input) {
      // This also prevents replay of a cached public vote after rejection.
      await getPublicNextProblem(input);
      return publicSuggestion(await store.voteNextProblem(input));
    },

    async getPredictions(input) {
      return { items: await store.getPredictions(input) };
    },

    async upsertPrediction(input) {
      return await store.upsertPrediction(input);
    },

    async resolvePrediction(input) {
      return await store.resolvePrediction(input);
    },
  };
}
