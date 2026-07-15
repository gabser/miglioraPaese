import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { loadServerConfig } from '../src/config/environment.js';
import { startServer } from '../src/server.js';

describe('backend environment configuration', () => {
  it('uses explicit local defaults when the environment is empty', () => {
    const config = loadServerConfig({ env: {} });

    assert.equal(config.port, 8787);
    assert.equal(config.host, '127.0.0.1');
    assert.deepEqual([...config.allowedOrigins], []);
  });

  it('normalizes validated environment values before startup', () => {
    const config = loadServerConfig({
      env: {
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
        () => startServer({ env: {}, port }),
        /PORT must be an integer between 0 and 65535/,
      );
    }

    assert.throws(
      () => startServer({ env: {}, host: '   ' }),
      /HOST must be a non-empty string/,
    );
    assert.throws(
      () => startServer({ env: {}, allowedOrigins: '*' }),
      /CORS origins must be explicit HTTP\(S\) origins/,
    );
    assert.throws(
      () => startServer({ env: {}, allowedOrigins: 'ftp://pilot.example' }),
      /CORS origins must use HTTP or HTTPS/,
    );
  });
});
