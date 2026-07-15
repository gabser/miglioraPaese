export function createBackendService(store) {
  if (!store) {
    throw new TypeError('A store is required.');
  }

  return {
    getMunicipalityActivation(municipalityId) {
      const municipality = store.getMunicipality(municipalityId);
      return {
        municipalityId: municipality.id,
        state: municipality.activationState,
      };
    },

    getCivicLoopSummary(municipalityId) {
      return store.getCivicLoopSummary(municipalityId);
    },

    getCurrentTurn(municipalityId) {
      return store.getCurrentTurn(municipalityId);
    },

    listProblems(municipalityId) {
      return { items: store.listProblems(municipalityId) };
    },

    getLeaderboard(municipalityId) {
      return { items: store.getLeaderboard(municipalityId) };
    },

    listNextProblems(input) {
      return { items: store.listNextProblems(input) };
    },

    submitNextProblem(input) {
      return store.submitNextProblem(input);
    },

    voteNextProblem(input) {
      return store.voteNextProblem(input);
    },

    getPredictions(input) {
      return { items: store.getPredictions(input) };
    },

    upsertPrediction(input) {
      return store.upsertPrediction(input);
    },

    resolvePrediction(input) {
      return store.resolvePrediction(input);
    },
  };
}
