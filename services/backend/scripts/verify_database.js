import { constants } from 'node:fs';
import { access } from 'node:fs/promises';
import { resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const configuredPath = process.env.BACKUP_PATH ?? process.env.DATABASE_PATH;
if (typeof configuredPath !== 'string' || configuredPath.trim() === '') {
  throw new Error('BACKUP_PATH or DATABASE_PATH is required.');
}
const databasePath = resolve(configuredPath);
await access(databasePath, constants.R_OK);

const database = new DatabaseSync(databasePath, { readOnly: true });
try {
  const integrity = database.prepare('PRAGMA integrity_check').all();
  const version = database
    .prepare('SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations')
    .get();
  if (integrity.length !== 1 || integrity[0].integrity_check !== 'ok') {
    throw new Error('SQLite integrity check failed.');
  }
  if (Number(version.version) !== 1) {
    throw new Error(`Unsupported schema version ${version.version}.`);
  }
  console.log(
    JSON.stringify({
      event: 'sqlite_database_verified',
      databasePath,
      schemaVersion: Number(version.version),
    }),
  );
} finally {
  database.close();
}
