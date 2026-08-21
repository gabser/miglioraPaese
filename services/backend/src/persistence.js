import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const schemaVersion = 1;

export function createSqliteStateRepository({ databasePath }) {
  if (typeof databasePath !== 'string' || databasePath.trim() === '') {
    throw new TypeError('databasePath must be a non-empty string.');
  }
  const resolvedPath = resolve(databasePath);
  mkdirSync(dirname(resolvedPath), { recursive: true });
  const database = new DatabaseSync(resolvedPath, {
    timeout: 5_000,
    enableForeignKeyConstraints: true,
  });
  database.exec('PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL;');
  migrate(database);

  const loadStatement = database.prepare(
    'SELECT payload FROM app_state WHERE id = 1',
  );
  const saveStatement = database.prepare(`
    INSERT INTO app_state (id, revision, payload, updated_at)
    VALUES (1, 1, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      revision = app_state.revision + 1,
      payload = excluded.payload,
      updated_at = excluded.updated_at
  `);

  return {
    path: resolvedPath,
    schemaVersion,
    load() {
      const row = loadStatement.get();
      if (!row) return null;
      try {
        return JSON.parse(row.payload);
      } catch (error) {
        throw new Error('Persistent state contains invalid JSON.', {
          cause: error,
        });
      }
    },
    save(state) {
      saveStatement.run(JSON.stringify(state), new Date().toISOString());
    },
    close() {
      if (database.isOpen) database.close();
    },
  };
}

function migrate(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version INTEGER PRIMARY KEY,
      applied_at TEXT NOT NULL
    ) STRICT;
  `);
  const row = database
    .prepare('SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations')
    .get();
  const currentVersion = Number(row.version);
  if (currentVersion > schemaVersion) {
    throw new Error(
      `Database schema ${currentVersion} is newer than supported ${schemaVersion}.`,
    );
  }
  if (currentVersion >= 1) return;

  database.exec('BEGIN IMMEDIATE;');
  try {
    database.exec(`
      CREATE TABLE app_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        revision INTEGER NOT NULL CHECK (revision > 0),
        payload TEXT NOT NULL CHECK (json_valid(payload)),
        updated_at TEXT NOT NULL
      ) STRICT;
    `);
    database
      .prepare(
        'INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)',
      )
      .run(1, new Date().toISOString());
    database.exec('COMMIT;');
  } catch (error) {
    database.exec('ROLLBACK;');
    throw error;
  }
}
