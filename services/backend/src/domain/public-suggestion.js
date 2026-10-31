import { normalizeProposalLocation } from './proposal-location.js';

export function isPublicSuggestion(problem) {
  return problem.status === 'pending' || problem.status === 'approved';
}

// Project explicitly: new storage/session columns must never become public
// simply because an adapter or an old idempotency result contains them.
export function publicSuggestion(problem) {
  return {
    id: problem.id,
    title: problem.title,
    shortDescription: problem.shortDescription,
    location: normalizeProposalLocation(problem.location),
    category: problem.category,
    status: problem.status,
    votesUp: problem.votesUp,
    votesDown: problem.votesDown,
    score: problem.score,
    myVote: problem.myVote,
    submittedByDisplayName: problem.submittedByDisplayName,
    createdAt: problem.createdAt,
    promotionRule: {
      threshold: problem.promotionRule.threshold,
      scopeLabel: problem.promotionRule.scopeLabel,
      reason: problem.promotionRule.reason,
    },
  };
}
