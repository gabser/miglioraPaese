import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { loadServerConfig } from '../src/config/environment.js';
import { startServer } from '../src/server.js';

describe('backend environment configuration', () => {
  it('uses explicit local defaults when the environment is empty', () => {
    const config = loadServerConfig({ env: { DATA_STORE: 'memory' } });

    assert.equal(config.port, 8787);
    assert.equal(config.host, '127.0.0.1');
    assert.deepEqual([...config.allowedOrigins], []);
    assert.equal(config.dataStore, 'memory');
    assert.equal(config.postgres, null);
  });

  it('normalizes validated environment values before startup', () => {
    const config = loadServerConfig({
      env: {
        DATA_STORE: 'memory',
        PORT: '9090',
        HOST: ' 0.0.0.0 ',
        CORS_ALLOWED_ORIGINS:
          'https://pilot.example/path, http://localhost:7357',
      },
    });

    assert.equal(config.port, 9090);
    assert.equal(config.host, '0.0.0.0');
    assert.deepEqual([...config.allowedOrigins], [
      'https://pilot.example',
      'http://localhost:7357',
    ]);
  });

  it('rejects invalid ports, hosts and CORS origins before listening', () => {
    for (const port of ['invalid', -1, 65_536, 1.5]) {
      assert.throws(
        () => startServer({ env: { DATA_STORE: 'memory' }, port }),
        /PORT must be an integer between 0 and 65535/,
      );
    }

    assert.throws(
      () => startServer({ env: { DATA_STORE: 'memory' }, host: '   ' }),
      /HOST must be a non-empty string/,
    );
    assert.throws(
      () =>
        startServer({
          env: { DATA_STORE: 'memory' },
          allowedOrigins: '*',
        }),
      /CORS origins must be explicit HTTP\(S\) origins/,
    );
    assert.throws(
      () =>
        startServer({
          env: { DATA_STORE: 'memory' },
          allowedOrigins: 'ftp://pilot.example',
        }),
      /CORS origins must use HTTP or HTTPS/,
    );
  });

  it('requires an explicit store and never falls back from PostgreSQL', () => {
    assert.throws(
      () => loadServerConfig({ env: {} }),
      /DATA_STORE must be explicitly set to memory or postgres/,
    );
    assert.throws(
      () => loadServerConfig({ env: { DATA_STORE: 'postgres' } }),
      /PostgreSQL requires DATABASE_URL or explicit PGHOST/,
    );
    assert.throws(
      () =>
        loadServerConfig({
          env: {
            DATA_STORE: 'postgres',
            DATABASE_URL: 'postgres://localhost/migliorapaese',
            PG_POOL_MAX: '0',
          },
        }),
      /PG_POOL_MAX must be an integer between 1 and 20/,
    );
  });

  it('builds a bounded PostgreSQL pool configuration', () => {
    const config = loadServerConfig({
      env: {
        DATA_STORE: 'postgres',
        DATABASE_URL: 'postgres://localhost/migliorapaese',
        PG_POOL_MAX: '4',
        PG_POOL_IDLE_TIMEOUT_MS: '11000',
        PG_CONNECTION_TIMEOUT_MS: '2000',
        PG_STATEMENT_TIMEOUT_MS: '4000',
        PG_QUERY_TIMEOUT_MS: '4500',
        PG_LOCK_TIMEOUT_MS: '750',
        PG_IDLE_IN_TRANSACTION_TIMEOUT_MS: '3500',
      },
    });

    assert.equal(config.dataStore, 'postgres');
    assert.deepEqual(config.postgres, {
      connectionString: 'postgres://localhost/migliorapaese',
      max: 4,
      idleTimeoutMillis: 11000,
      connectionTimeoutMillis: 2000,
      statement_timeout: 4000,
      query_timeout: 4500,
      lock_timeout: 750,
      idle_in_transaction_session_timeout: 3500,
      application_name: 'migliorapaese-backend',
    });
  });
});
