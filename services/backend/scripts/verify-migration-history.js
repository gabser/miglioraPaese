import { verifyAppendOnlyMigrationHistory } from '../src/persistence/postgres/migration-history.js';

try {
  const result = await verifyAppendOnlyMigrationHistory();
  console.log(`Migration history is append-only relative to ${result.baseRef}.`);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
