import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const backendRoot = fileURLToPath(new URL('../../../', import.meta.url));
export const migrationsDirectory = path.join(backendRoot, 'migrations');
export const migrationManifestPath = path.join(
  migrationsDirectory,
  'manifest.json',
);

const migrationFilePattern = /^(\d{17})_([a-z0-9_-]+)\.js$/;
const sha256Pattern = /^[0-9a-f]{64}$/;

export async function buildMigrationManifest() {
  const files = (await readdir(migrationsDirectory))
    .filter((file) => migrationFilePattern.test(file))
    .sort();
  const migrations = [];

  for (const file of files) {
    const match = migrationFilePattern.exec(file);
    const contents = await readFile(path.join(migrationsDirectory, file));
    migrations.push({
      id: match[1],
      name: file.slice(0, -path.extname(file).length),
      file,
      sha256: createHash('sha256').update(contents).digest('hex'),
    });
  }

  return { version: 1, migrations };
}

export async function readMigrationManifest() {
  let manifest;
  try {
    manifest = JSON.parse(await readFile(migrationManifestPath, 'utf8'));
  } catch (error) {
    throw new Error(`Cannot read migration manifest: ${error.message}`);
  }

  validateManifestShape(manifest);
  return manifest;
}

export async function verifyMigrationManifest() {
  const [recorded, actual] = await Promise.all([
    readMigrationManifest(),
    buildMigrationManifest(),
  ]);

  if (JSON.stringify(recorded) !== JSON.stringify(actual)) {
    throw new Error(
      'Migration manifest does not match the ordered migration files. ' +
        'Applied migrations must never be changed, renamed, or removed.',
    );
  }

  return recorded.migrations;
}

export async function computeMigrationArtifactDigest() {
  const packageLockPath = path.join(backendRoot, 'package-lock.json');
  const [manifestContents, lockContents] = await Promise.all([
    readFile(migrationManifestPath),
    readFile(packageLockPath),
  ]);
  return (
    'sha256:' +
    createHash('sha256')
      .update(manifestContents)
      .update('\n')
      .update(lockContents)
      .digest('hex')
  );
}

function validateManifestShape(manifest) {
  if (manifest?.version !== 1 || !Array.isArray(manifest.migrations)) {
    throw new Error('Migration manifest must use version 1 and an array.');
  }

  const names = new Set();
  let previousFile = '';
  for (const entry of manifest.migrations) {
    const match = migrationFilePattern.exec(entry?.file ?? '');
    if (
      !match ||
      entry.id !== match[1] ||
      entry.name !== entry.file.slice(0, -3) ||
      !sha256Pattern.test(entry.sha256 ?? '')
    ) {
      throw new Error(`Invalid migration manifest entry: ${entry?.file ?? '?'}`);
    }
    if (names.has(entry.name) || entry.file <= previousFile) {
      throw new Error('Migration manifest entries must be unique and ordered.');
    }
    names.add(entry.name);
    previousFile = entry.file;
  }
}
