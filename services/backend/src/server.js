import http from 'node:http';

import { loadServerConfig } from './config/environment.js';
import { createApp } from './http/app.js';
import { createMemoryStore } from './infrastructure/memory-store.js';
import { createPostgresPool } from './persistence/postgres/pool.js';
import { createPostgresStore } from './persistence/postgres/postgres-store.js';

export {
  createApp,
  createMemoryStore,
  createPostgresPool,
  createPostgresStore,
};

export function startServer(options = {}) {
  const logger = options.logger ?? console;
  const config = loadServerConfig({
    env: options.env ?? process.env,
    port: options.port,
    host: options.host,
    allowedOrigins: options.allowedOrigins,
    dataStore: options.dataStore,
  });
  const runtime = createRuntimeStore(config, options);
  const server = http.createServer(
    createApp({
      store: runtime.store,
      allowedOrigins: config.allowedOrigins,
    }),
  );
  let closingResources;
  const closeResources = () => {
    closingResources ??= Promise.resolve().then(runtime.close);
    return closingResources;
  };
  const closeResourcesSafely = () => {
    void closeResources().catch((error) => {
      logger.error?.('Backend resources failed to close.', {
        code: typeof error.code === 'string' ? error.code : 'unknown',
      });
    });
  };
  Object.defineProperty(server, 'closeResources', {
    value: closeResources,
    enumerable: false,
  });
  server.once('close', () => {
    closeResourcesSafely();
  });
  server.once('error', () => {
    closeResourcesSafely();
  });
  server.listen(config.port, config.host);
  return server;
}

function createRuntimeStore(config, options) {
  if (options.store) {
    return {
      store: options.store,
      close: options.closeStore ?? (() => {}),
    };
  }
  if (config.dataStore === 'memory') {
    return { store: createMemoryStore(), close: () => {} };
  }

  const pool = options.pool ?? createPostgresPool(config.postgres, {
    logger: options.logger,
  });
  return {
    store: createPostgresStore(pool, { logger: options.logger }),
    close: () => pool.end(),
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const server = startServer();
  server.once('listening', () => {
    const address = server.address();
    const location =
      typeof address === 'string'
        ? address
        : 'http://' + address.address + ':' + address.port;
    console.log('Backend listening on ' + location);
  });
  server.once('error', (error) => {
    console.error('Backend failed to start:', error.message);
    process.exitCode = 1;
  });
  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.once(signal, () => {
      server.close((error) => {
        if (error) {
          console.error('Backend failed to stop:', error.message);
          process.exitCode = 1;
        }
      });
    });
  }
}
