import { httpError } from '../domain/errors.js';

export function requireText(value, field, maxLength = null) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw httpError(400, 'invalid_field', field + ' is required.');
  }
  const normalized = value.trim();
  if (maxLength !== null && normalized.length > maxLength) {
    throw httpError(
      400,
      'invalid_field',
      field + ' must be at most ' + maxLength + ' characters.',
    );
  }
  return normalized;
}

export function textOrDefault(value, fallback, field, maxLength) {
  if (value == null) return fallback;
  return requireText(value, field, maxLength);
}

export function optionalText(value, field, maxLength) {
  if (value == null || value.trim() === '') return null;
  return requireText(value, field, maxLength);
}

export function requireEnum(value, values, field) {
  if (typeof value !== 'string' || !values.has(value)) {
    throw httpError(400, 'invalid_field', `${field} is invalid.`);
  }
  return value;
}

export function optionalEnum(value, values, field) {
  if (value == null) return null;
  return requireEnum(value, values, field);
}

export function requireEnumArray(value, values, field, maxItems) {
  if (
    !Array.isArray(value) ||
    value.length > maxItems ||
    value.some((item) => typeof item !== 'string' || !values.has(item)) ||
    new Set(value).size !== value.length
  ) {
    throw httpError(
      400,
      'invalid_field',
      field + ' must contain at most ' + maxItems + ' unique known values.',
    );
  }
  return value;
}
