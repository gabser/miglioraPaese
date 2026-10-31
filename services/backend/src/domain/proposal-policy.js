import { httpError } from './errors.js';

export const proposalSubmissionLimit = 3;
export const proposalSubmissionWindowMs = 60 * 60 * 1000;

// A conservative pilot filter, not a claim of complete personal-data detection.
const emailPattern = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i;
const urlPattern = /\b(?:https?:\/\/|www\.)\S+/i;
const phonePattern = /(?:\+?\d[\s().-]*){8,}/;
const unsafeCharacters = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;
const abusiveTerms = new Set(['cazzo', 'coglione', 'coglioni', 'merda', 'stronzo', 'stronza', 'vaffanculo']);

export function assertPublicProposalContent({ title, description, location }) {
  const text = [title, description, location?.label, location?.reference].filter(value => value != null).join('\n');
  const allText = [text, location?.civic].filter(value => value != null).join('\n');
  const normalized = allText.normalize('NFKD').replaceAll(/[\u0300-\u036f]/g, '').toLowerCase();
  // Civic numbers are allowed, including 12/A; they are not interpreted as contacts.
  if (unsafeCharacters.test(allText) || urlPattern.test(allText) || emailPattern.test(allText) ||
      phonePattern.test(text) || (normalized.match(/[a-z]+/g) ?? []).some(word => abusiveTerms.has(word))) {
    throw httpError(422, 'content_rejected', 'Revise the proposal content before submitting.');
  }
}

export function assertSubmissionQuota(recentCreatedAt, nowMs) {
  if (!Number.isFinite(nowMs)) throw new TypeError('The server clock must return finite milliseconds.');
  const recent = recentCreatedAt.map(value => new Date(value).getTime())
    .filter(value => Number.isFinite(value) && value >= nowMs - proposalSubmissionWindowMs)
    .sort((a, b) => b - a);
  if (recent.length < proposalSubmissionLimit) return;
  // The inclusive lower bound expires one millisecond after the boundary.
  const availableAt = recent[proposalSubmissionLimit - 1] + proposalSubmissionWindowMs + 1;
  const error = httpError(429, 'submission_rate_limited', 'Up to three proposals per hour are allowed for this municipality.');
  error.retryAfterSeconds = Math.max(1, Math.ceil((availableAt - nowMs) / 1000));
  throw error;
}

export function validateProposalReview(input) {
  const { decision, expectedStatus, operatorLabel, reason } = input;
  if (!['reject', 'reopen'].includes(decision) || !['pending', 'rejected'].includes(expectedStatus) ||
      typeof operatorLabel !== 'string' || !operatorLabel.trim() || Array.from(operatorLabel.trim()).length > 160 ||
      typeof reason !== 'string' || !reason.trim() || Array.from(reason.trim()).length > 1000) {
    throw httpError(400, 'invalid_review', 'A review requires a decision, expected status, operator label and reason.');
  }
  const requiredStatus = decision === 'reject' ? 'pending' : 'rejected';
  if (expectedStatus !== requiredStatus) throw httpError(409, 'review_conflict', 'The review does not match the expected proposal state.');
  return { decision, expectedStatus, operatorLabel: operatorLabel.trim(), reason: reason.trim(),
    targetStatus: decision === 'reject' ? 'rejected' : 'pending' };
}
