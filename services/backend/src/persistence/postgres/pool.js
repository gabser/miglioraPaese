import pg from 'pg';

const { Pool } = pg;

export function createPostgresPool(config, { logger = console } = {}) {
  if (!config || typeof config !== 'object') {
    throw new TypeError('Validated PostgreSQL pool configuration is required.');
  }
  const pool = new Pool(config);
  pool.on('error', (error) => {
    logger.error?.('PostgreSQL pool error.', {
      code: 'pool_error',
    });
  });
  return pool;
}
