import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

import { runner } from 'node-pg-migrate';
import pg from 'pg';

import {
  backendRoot,
  computeMigrationArtifactDigest,
  migrationsDirectory,
  verifyMigrationManifest,
} from './migration-manifest.js';
import {
  readAppliedMigrations,
  recordMigrationAttestation,
  verifyDatabaseMigrationState,
} from './migration-ledger.js';

const { Client } = pg;
const migrationCoordinatorLockId = 734_662_021;

export async function runPostgresMigrations(options = {}) {
  const direction = options.direction ?? 'up';
  if (!['up', 'down'].includes(direction)) {
    throw new Error('Migration direction must be up or down.');
  }

  const databaseUrl =
    options.databaseUrl ??
    process.env.MIGRATION_DATABASE_URL ??
    process.env.DATABASE_URL;
  const attestationDatabaseUrl =
    options.attestationDatabaseUrl ??
    process.env.ATTESTATION_DATABASE_URL ??
    databaseUrl;
  if (!databaseUrl || !attestationDatabaseUrl) {
    throw new Error(
      'MIGRATION_DATABASE_URL (or DATABASE_URL) and an attestation connection are required.',
    );
  }

  const manifest = await verifyMigrationManifest();
  const versions = await readInstalledMigrationVersions();
  const sourceCommit = options.sourceCommit ?? readSourceCommit();
  const artifactDigest =
    options.artifactDigest ?? (await computeMigrationArtifactDigest());
  return withMigrationCoordinator(attestationDatabaseUrl, async (client) => {
    const before = await verifyDatabaseMigrationState(client, manifest);
    const migrated = await runner({
      databaseUrl,
      migrationsTable: 'pgmigrations',
      migrationsSchema: 'public',
      schema: 'public',
      dir: migrationsDirectory,
      ignorePattern: '^manifest\\.json$',
      checkOrder: true,
      direction,
      count: direction === 'down' ? (options.count ?? 1) : options.count,
      singleTransaction: true,
      noLock: false,
      fake: false,
      createSchema: false,
      createMigrationsSchema: false,
      logger: options.logger ?? console,
    });

    const appliedAfter = await readAppliedMigrations(client);
    const appliedAfterByName = new Map(
      appliedAfter.map((migration) => [migration.name, migration]),
    );
    const appliedBeforeByName = new Map(
      before.applied.map((migration) => [migration.name, migration]),
    );

    for (const result of migrated) {
      const migration = manifest.find((entry) => entry.name === result.name);
      if (!migration) {
        throw new Error(`Migrated file ${result.name} is absent from the manifest.`);
      }
      const tracking =
        direction === 'up'
          ? appliedAfterByName.get(result.name)
          : appliedBeforeByName.get(result.name);
      if (!tracking) {
        throw new Error(`Missing pgmigrations tracking id for ${result.name}.`);
      }
      await recordMigrationAttestation(client, {
        migration,
        migrationTableId: tracking.migration_table_id,
        action: direction === 'up' ? 'apply' : 'revert',
        sourceCommit,
        artifactDigest,
        driverVersion: versions.driver,
        runnerVersion: versions.runner,
      });
    }

    await verifyDatabaseMigrationState(client, manifest);
    return migrated;
  });
}

export async function verifyPostgresMigrations(options = {}) {
  const databaseUrl =
    options.attestationDatabaseUrl ??
    process.env.ATTESTATION_DATABASE_URL ??
    process.env.MIGRATION_DATABASE_URL ??
    process.env.DATABASE_URL;
  if (!databaseUrl) throw new Error('A database URL is required.');
  const manifest = await verifyMigrationManifest();
  return withClient(databaseUrl, (client) =>
    verifyDatabaseMigrationState(client, manifest),
  );
}

async function readInstalledMigrationVersions() {
  const [backendPackage, driverPackage, runnerPackage] = await Promise.all([
    readJson(path.join(backendRoot, 'package.json')),
    readJson(path.join(backendRoot, 'node_modules/pg/package.json')),
    readJson(
      path.join(backendRoot, 'node_modules/node-pg-migrate/package.json'),
    ),
  ]);
  if (
    backendPackage.dependencies?.pg !== driverPackage.version ||
    backendPackage.devDependencies?.['node-pg-migrate'] !== runnerPackage.version
  ) {
    throw new Error('Installed migration versions do not match exact package pins.');
  }
  return { driver: driverPackage.version, runner: runnerPackage.version };
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}

function readSourceCommit() {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: backendRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    throw new Error(
      'MIGRATION_SOURCE_COMMIT is required when git metadata is unavailable.',
    );
  }
}

async function withClient(databaseUrl, callback) {
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    return await callback(client);
  } finally {
    await client.end();
  }
}

async function withMigrationCoordinator(databaseUrl, callback) {
  return withClient(databaseUrl, async (client) => {
    await client.query('SELECT pg_advisory_lock($1)', [
      migrationCoordinatorLockId,
    ]);
    try {
      return await callback(client);
    } finally {
      await client.query('SELECT pg_advisory_unlock($1)', [
        migrationCoordinatorLockId,
      ]);
    }
  });
}
