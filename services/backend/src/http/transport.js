import { URL } from 'node:url';

import { normalizeOrigin } from '../config/environment.js';
import { inputLimits } from '../domain/catalog.js';
import { httpError } from '../domain/errors.js';

export function getHeader(req, name) {
  const value = req.headers?.[name];
  return Array.isArray(value) ? value[0] : value ?? null;
}

export function corsHeadersForRequest(req, allowedOrigins) {
  const rawOrigin = getHeader(req, 'origin');
  if (!rawOrigin) {
    return { allowed: true, origin: null, headers: {} };
  }

  let origin;
  try {
    origin = normalizeOrigin(rawOrigin);
  } catch {
    return { allowed: false, origin: null, headers: { vary: 'Origin' } };
  }
  const url = new URL(origin);
  const loopbackHosts = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);
  const allowed = loopbackHosts.has(url.hostname) || allowedOrigins.has(origin);
  if (!allowed) {
    return { allowed: false, origin, headers: { vary: 'Origin' } };
  }
  return {
    allowed: true,
    origin,
    headers: {
      'access-control-allow-origin': origin,
      'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'access-control-allow-headers': 'Content-Type, Idempotency-Key, Authorization',
      'access-control-max-age': '600',
      'access-control-expose-headers': 'Retry-After',
      vary: 'Origin',
    },
  };
}

export async function readJson(req) {
  const contentLength = Number(getHeader(req, 'content-length'));
  if (
    Number.isFinite(contentLength) &&
    contentLength > inputLimits.jsonBodyBytes
  ) {
    throw httpError(413, 'payload_too_large', 'Request body exceeds 64 KiB.');
  }

  const chunks = [];
  let totalBytes = 0;
  for await (const chunk of req) {
    totalBytes += chunk.length;
    if (totalBytes > inputLimits.jsonBodyBytes) {
      throw httpError(413, 'payload_too_large', 'Request body exceeds 64 KiB.');
    }
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw.trim()) return {};
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw httpError(400, 'invalid_json', 'Request body must be valid JSON.');
  }
  if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
    throw httpError(400, 'invalid_body', 'Request body must be a JSON object.');
  }
  return parsed;
}

export function sendJson(res, statusCode, body, headers = {}) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    ...headers,
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(payload),
  });
  res.end(payload);
}
