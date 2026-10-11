import { URL } from 'node:url';

export function loadServerConfig({
  env = process.env,
  port,
  host,
  allowedOrigins,
  dataStore,
} = {}) {
  const normalizedDataStore = normalizeDataStore(
    dataStore ?? env.DATA_STORE,
  );
  return {
    port: normalizePort(port ?? env.PORT ?? 8787),
    host: normalizeHost(host ?? env.HOST ?? '127.0.0.1'),
    allowedOrigins: normalizeAllowedOrigins(
      allowedOrigins ?? env.CORS_ALLOWED_ORIGINS,
    ),
    dataStore: normalizedDataStore,
    postgres:
      normalizedDataStore === 'postgres'
        ? loadPostgresConfig({ env })
        : null,
  };
}

export function loadPostgresConfig({ env = process.env } = {}) {
  const connection = normalizePostgresConnection(env);
  return {
    ...connection,
    max: normalizeInteger(env.PG_POOL_MAX ?? 5, 'PG_POOL_MAX', {
      min: 1,
      max: 20,
    }),
    idleTimeoutMillis: normalizeInteger(
      env.PG_POOL_IDLE_TIMEOUT_MS ?? 10_000,
      'PG_POOL_IDLE_TIMEOUT_MS',
      { min: 1, max: 300_000 },
    ),
    connectionTimeoutMillis: normalizeInteger(
      env.PG_CONNECTION_TIMEOUT_MS ?? 3_000,
      'PG_CONNECTION_TIMEOUT_MS',
      { min: 1, max: 60_000 },
    ),
    statement_timeout: normalizeInteger(
      env.PG_STATEMENT_TIMEOUT_MS ?? 5_000,
      'PG_STATEMENT_TIMEOUT_MS',
      { min: 1, max: 300_000 },
    ),
    query_timeout: normalizeInteger(
      env.PG_QUERY_TIMEOUT_MS ?? 6_000,
      'PG_QUERY_TIMEOUT_MS',
      { min: 1, max: 300_000 },
    ),
    lock_timeout: normalizeInteger(
      env.PG_LOCK_TIMEOUT_MS ?? 1_000,
      'PG_LOCK_TIMEOUT_MS',
      { min: 1, max: 60_000 },
    ),
    idle_in_transaction_session_timeout: normalizeInteger(
      env.PG_IDLE_IN_TRANSACTION_TIMEOUT_MS ?? 5_000,
      'PG_IDLE_IN_TRANSACTION_TIMEOUT_MS',
      { min: 1, max: 300_000 },
    ),
    application_name: 'migliorapaese-backend',
  };
}

export function normalizeDataStore(value) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError('DATA_STORE must be explicitly set to memory or postgres.');
  }
  const normalized = value.trim().toLowerCase();
  if (normalized !== 'memory' && normalized !== 'postgres') {
    throw new TypeError('DATA_STORE must be memory or postgres.');
  }
  return normalized;
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

function normalizePostgresConnection(env) {
  if (typeof env.DATABASE_URL === 'string' && env.DATABASE_URL.trim() !== '') {
    return { connectionString: env.DATABASE_URL.trim() };
  }

  const required = ['PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER'];
  const missing = required.filter(
    (name) => typeof env[name] !== 'string' || env[name].trim() === '',
  );
  if (missing.length > 0) {
    throw new TypeError(
      'PostgreSQL requires DATABASE_URL or explicit PGHOST, PGPORT, PGDATABASE and PGUSER.',
    );
  }

  return {
    host: env.PGHOST.trim(),
    port: normalizeInteger(env.PGPORT, 'PGPORT', { min: 1, max: 65_535 }),
    database: env.PGDATABASE.trim(),
    user: env.PGUSER.trim(),
    ...(typeof env.PGPASSWORD === 'string' ? { password: env.PGPASSWORD } : {}),
  };
}

function normalizeInteger(value, name, { min, max }) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new RangeError(`${name} must be an integer between ${min} and ${max}.`);
  }
  return parsed;
}
