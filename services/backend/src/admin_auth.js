import { timingSafeEqual } from 'node:crypto';

export function validateAdminToken(token) {
  if (typeof token !== 'string' || Buffer.byteLength(token) < 32) {
    throw new TypeError('Moderation admin token must be at least 32 bytes.');
  }
  return token;
}

export function isAdminAuthorized(req, expectedToken) {
  if (typeof expectedToken !== 'string') return false;
  const authorization = headerValue(req, 'authorization');
  if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) {
    return false;
  }
  const provided = Buffer.from(authorization.slice('Bearer '.length), 'utf8');
  const expected = Buffer.from(expectedToken, 'utf8');
  return (
    provided.length === expected.length && timingSafeEqual(provided, expected)
  );
}

function headerValue(req, name) {
  const value = req.headers?.[name];
  return Array.isArray(value) ? value[0] : value ?? null;
}
