import { loadPostgresConfig } from '../src/config/environment.js';
import { createPostgresPool } from '../src/persistence/postgres/pool.js';
import { seedPostgres } from '../src/persistence/postgres/seed.js';

const profile = process.argv[2] ?? 'local';
const pool = createPostgresPool(loadPostgresConfig());

try {
  await seedPostgres(pool, { profile });
  console.log(`PostgreSQL ${profile} seed applied.`);
} catch (error) {
  console.error('PostgreSQL seed failed:', error.message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
