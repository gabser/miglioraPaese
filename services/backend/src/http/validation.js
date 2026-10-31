import { httpError, fieldError } from '../domain/errors.js';

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
    throw fieldError(field, 'invalid_choice', `${field} is invalid.`);
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

export function requireIdempotencyKey(value) {
  const key = requireText(value, 'Idempotency-Key', 160);
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{7,159}$/.test(key)) {
    throw httpError(
      400,
      'invalid_field',
      'Idempotency-Key must contain 8-160 safe ASCII characters.',
    );
  }
  return key;
}
