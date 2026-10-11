import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { httpError } from './errors.js';

export function sessionHash(token) {
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) {
    throw httpError(401, 'proposal_session_required', 'A valid proposal session is required.');
  }
  return createHash('sha256').update(token).digest('hex');
}

export function newProposalSession() {
  const token = randomBytes(32).toString('base64url');
  return { token, tokenHash: sessionHash(token), submissionScope: randomUUID() };
}

export function scopedSubmissionKey(scope, municipalityId, key) {
  return 'scope-' + createHash('sha256')
    .update(JSON.stringify([scope, municipalityId, key])).digest('hex');
}

export function sessionIdentity(session) {
  return 'session:' + session.submissionScope;
}

export function sessionRevoked() {
  return httpError(401, 'proposal_session_revoked', 'The proposal session is unavailable or revoked.');
}
