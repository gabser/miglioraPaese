import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

const cookieName = 'mp_anon';
const cookieMaxAgeSeconds = 365 * 24 * 60 * 60;

export function createAnonymousIdentity({
  secret,
  secure = false,
  generateId = randomUUID,
} = {}) {
  if (typeof secret !== 'string' || Buffer.byteLength(secret) < 32) {
    throw new TypeError('Anonymous identity secret must be at least 32 bytes.');
  }

  return {
    resolve(req, { isRevoked = () => false, renewRevoked = false } = {}) {
      const cookies = parseCookies(req.headers?.cookie);
      const existing = verifyToken(cookies.get(cookieName), secret);
      if (existing !== null && (!isRevoked(existing) || !renewRevoked)) {
        return { userId: existing, revoked: isRevoked(existing), headers: {} };
      }

      const userId = 'anon:' + generateId();
      const token = signToken(userId, secret);
      const attributes = [
        `${cookieName}=${token}`,
        'Path=/',
        `Max-Age=${cookieMaxAgeSeconds}`,
        'HttpOnly',
        'SameSite=Lax',
      ];
      if (secure) attributes.push('Secure');
      return {
        userId,
        headers: { 'set-cookie': attributes.join('; ') },
      };
    },
    submissionScope(userId) {
      return createHmac('sha256', secret).update('proposal-submission-scope:v1:' + userId).digest('base64url');
    },
    clearHeaders() {
      const attributes = [
        `${cookieName}=`,
        'Path=/',
        'Max-Age=0',
        'Expires=Thu, 01 Jan 1970 00:00:00 GMT',
        'HttpOnly',
        'SameSite=Lax',
      ];
      if (secure) attributes.push('Secure');
      return { 'set-cookie': attributes.join('; ') };
    },
  };
}

function signToken(userId, secret) {
  const encodedId = Buffer.from(userId, 'utf8').toString('base64url');
  return `v1.${encodedId}.${signatureFor(encodedId, secret).toString('base64url')}`;
}

function verifyToken(token, secret) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== 'v1') return null;

  let providedSignature;
  let userId;
  try {
    providedSignature = Buffer.from(parts[2], 'base64url');
    userId = Buffer.from(parts[1], 'base64url').toString('utf8');
  } catch {
    return null;
  }
  const expectedSignature = signatureFor(parts[1], secret);
  if (
    providedSignature.length !== expectedSignature.length ||
    !timingSafeEqual(providedSignature, expectedSignature) ||
    !/^anon:[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      userId,
    )
  ) {
    return null;
  }
  return userId;
}

function signatureFor(encodedId, secret) {
  return createHmac('sha256', secret).update('v1.' + encodedId).digest();
}

function parseCookies(rawCookie) {
  const cookies = new Map();
  if (typeof rawCookie !== 'string') return cookies;
  for (const item of rawCookie.split(';')) {
    const separator = item.indexOf('=');
    if (separator <= 0) continue;
    const name = item.slice(0, separator).trim();
    const value = item.slice(separator + 1).trim();
    if (name && value) cookies.set(name, value);
  }
  return cookies;
}
