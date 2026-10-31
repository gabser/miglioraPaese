import { fieldError } from './errors.js';

export const proposalLimits = Object.freeze({
  title: 120,
  description: 1000,
  label: 120,
  civic: 20,
  reference: 200,
});

export function proposalText(value, field, limit) {
  if (typeof value !== 'string' || !value.isWellFormed() || value.includes('\u0000') || value.trim() === '') {
    throw fieldError(field, 'invalid_text', `${field} must be non-empty Unicode text.`);
  }
  const text = value.trim();
  if (Array.from(text).length > limit) {
    throw fieldError(field, 'too_long', `${field} must be at most ${limit} Unicode code points.`);
  }
  return text;
}

// null is reserved for legacy submissions. New clients require an explicit kind.
export function normalizeProposalLocation(value) {
  if (value == null) return null;
  if (typeof value !== 'object' || Array.isArray(value)) invalidLocation();
  if (value.kind === 'municipality') {
    if (Object.keys(value).some((key) => key !== 'kind')) invalidLocation();
    return { kind: 'municipality' };
  }
  if (value.kind !== 'specific' || Object.keys(value).some(
    (key) => !['kind', 'label', 'civic', 'reference'].includes(key),
  )) invalidLocation();
  const location = {
    kind: 'specific',
    label: proposalText(value.label, 'location.label', proposalLimits.label),
  };
  for (const field of ['civic', 'reference']) {
    if (value[field] === undefined) continue;
    if (typeof value[field] !== 'string') invalidLocation();
    if (value[field].trim() !== '') {
      location[field] = proposalText(value[field], `location.${field}`, proposalLimits[field]);
    }
  }
  return location;
}

export function proposalLocationLabel(location) {
  if (location === null) return 'Luogo non indicato';
  if (location.kind === 'municipality') return 'Intero Comune';
  return [location.label, location.civic].filter(Boolean).join(', ');
}

function invalidLocation() {
  throw fieldError('location', 'invalid_location', 'location must be municipality or a specific place with a label.');
}
