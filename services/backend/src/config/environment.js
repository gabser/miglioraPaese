import { URL } from 'node:url';

export function loadServerConfig({
  env = process.env,
  port,
  host,
  allowedOrigins,
} = {}) {
  return {
    port: normalizePort(port ?? env.PORT ?? 8787),
    host: normalizeHost(host ?? env.HOST ?? '127.0.0.1'),
    allowedOrigins: normalizeAllowedOrigins(
      allowedOrigins ?? env.CORS_ALLOWED_ORIGINS,
    ),
  };
}

export function normalizeAllowedOrigins(value) {
  if (value == null || value === '') return new Set();
  const entries =
    typeof value === 'string'
      ? value.split(',')
      : value instanceof Set
        ? [...value]
        : value;
  if (!Array.isArray(entries)) {
    throw new TypeError('allowedOrigins must be a comma-separated string or array.');
  }
  return new Set(
    entries
      .map((entry) => normalizeOrigin(entry))
      .filter((entry) => entry !== null),
  );
}

export function normalizeOrigin(value) {
  if (typeof value !== 'string' || value.trim() === '' || value.trim() === '*') {
    throw new TypeError('CORS origins must be explicit HTTP(S) origins.');
  }
  const url = new URL(value.trim());
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new TypeError('CORS origins must use HTTP or HTTPS.');
  }
  return url.origin;
}

export function normalizePort(value) {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new RangeError('PORT must be an integer between 0 and 65535.');
  }
  return port;
}

function normalizeHost(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError('HOST must be a non-empty string.');
  }
  return value.trim();
}
