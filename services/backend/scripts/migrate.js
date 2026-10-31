import {
  runPostgresMigrations,
  verifyPostgresMigrations,
} from '../src/persistence/postgres/migrator.js';

const command = process.argv[2];

try {
  if (command === 'up' || command === 'down') {
    const migrated = await runPostgresMigrations({ direction: command });
    console.log(
      migrated.length === 0
        ? 'Migration state is already current.'
        : `${command} completed for ${migrated.length} migration(s).`,
    );
  } else if (command === 'verify') {
    const state = await verifyPostgresMigrations();
    console.log(`Verified ${state.applied.length} applied migration(s).`);
  } else {
    throw new Error('Usage: node scripts/migrate.js <up|down|verify>');
  }
} catch (error) {
  console.error(`Migration ${command ?? 'command'} failed: ${error.message}`);
  process.exitCode = 1;
}
