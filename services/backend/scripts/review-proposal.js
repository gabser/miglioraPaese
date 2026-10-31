// Internal local operation. Database credentials authorize access; operatorLabel is audit metadata.
import { loadPostgresConfig } from '../src/config/environment.js';
import { createPostgresPool } from '../src/persistence/postgres/pool.js';
import { createPostgresStore } from '../src/persistence/postgres/postgres-store.js';
import { validateProposalReview } from '../src/domain/proposal-policy.js';
const logger = { debug() {}, info() {}, warn() {}, error() {} };
let pool;
try {
  let text = '';
  for await (const chunk of process.stdin) {
    text += chunk;
    if (Buffer.byteLength(text) > 16384) throw new Error('Input exceeds 16 KiB.');
  }
  const input = JSON.parse(text);
  validateProposalReview(input);
  if (typeof input.municipalityId !== 'string' || typeof input.problemId !== 'string') throw new Error('Municipality and proposal ID are required.');
  pool = createPostgresPool(loadPostgresConfig(), { logger });
  const result = await createPostgresStore(pool, { logger }).reviewSuggestion(input);
  console.log(JSON.stringify({ id: result.id, status: result.status }));
} catch (error) {
  console.error(error.code ?? 'review_failed');
  process.exitCode = 1;
} finally { if (pool) await pool.end(); }
