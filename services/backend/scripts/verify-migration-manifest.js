import { verifyMigrationManifest } from '../src/persistence/postgres/migration-manifest.js';

try {
  const migrations = await verifyMigrationManifest();
  console.log(`Verified ${migrations.length} migration manifest entry.`);
} catch (error) {
  console.error(`Migration manifest verification failed: ${error.message}`);
  process.exitCode = 1;
}
