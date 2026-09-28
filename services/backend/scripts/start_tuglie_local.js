import { resolve } from 'node:path';

import { startServer } from '../src/server.js';

if (process.env.NODE_ENV === 'production') {
  throw new Error('dev:tuglie is a loopback-only development command.');
}

const port = process.env.PORT ?? 8787;
const databasePath = resolve(
  process.env.DATABASE_PATH ?? './data/tuglie-local.sqlite',
);
const server = startServer({
  port,
  host: '127.0.0.1',
  databasePath,
  identitySecret:
    process.env.ANON_IDENTITY_SECRET ??
    'tuglie-local-identity-secret-for-synthetic-data-only',
  moderationAdminToken:
    process.env.MODERATION_ADMIN_TOKEN ??
    'tuglie-local-moderator-token-for-synthetic-data-only',
  pilotMunicipalityId: 'tuglie',
  moderationRequired: true,
  minimumAggregateSampleSize: 3,
  secureCookies: false,
  allowedOrigins: ['http://localhost:7357'],
  logger: (entry) => console.log(entry),
});

server.once('listening', () => {
  console.log(
    JSON.stringify({
      event: 'tuglie_local_pilot_listening',
      baseUrl: `http://127.0.0.1:${port}`,
      municipalityId: 'tuglie',
      dataMode: 'synthetic',
      databasePath,
    }),
  );
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.once(signal, () => {
    server.close((error) => {
      if (error) {
        console.error(error.message);
        process.exitCode = 1;
      }
    });
  });
}
