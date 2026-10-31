export async function withTransaction(pool, callback, { logger = console } = {}) {
  if (!pool || typeof pool.connect !== 'function') {
    throw new TypeError('A PostgreSQL pool is required for transactions.');
  }
  if (typeof callback !== 'function') {
    throw new TypeError('A transaction callback is required.');
  }

  const client = await pool.connect();
  let began = false;
  try {
    await client.query('BEGIN');
    began = true;
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    if (began) {
      try {
        await client.query('ROLLBACK');
        logger.warn?.('PostgreSQL transaction rolled back.', {
          code: typeof error.code === 'string' ? error.code : 'application_error',
        });
      } catch (rollbackError) {
        logger.error?.('PostgreSQL transaction rollback failed.', {
          code:
            typeof rollbackError.code === 'string'
              ? rollbackError.code
              : 'unknown',
        });
      }
    }
    throw error;
  } finally {
    client.release();
  }
}
