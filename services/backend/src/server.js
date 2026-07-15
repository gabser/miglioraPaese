import http from 'node:http';

import { loadServerConfig } from './config/environment.js';
import { createApp } from './http/app.js';
import { createMemoryStore } from './infrastructure/memory-store.js';

export { createApp, createMemoryStore };

export function startServer(options = {}) {
  const config = loadServerConfig({
    env: options.env ?? process.env,
    port: options.port,
    host: options.host,
    allowedOrigins: options.allowedOrigins,
  });
  const server = http.createServer(
    createApp({
      store: options.store,
      allowedOrigins: config.allowedOrigins,
    }),
  );
  server.listen(config.port, config.host);
  return server;
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
}
