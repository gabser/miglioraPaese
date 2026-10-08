import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { it } from 'node:test';

import { createPersistentStore } from '../src/server.js';

const execFileAsync = promisify(execFile);

it('rehearses an isolated restore with the application store', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'migliorapaese-rehearsal-'));
  const backupPath = join(directory, 'pilot-backup.sqlite');
  let store;
  try {
    store = createPersistentStore({ databasePath: backupPath });
    store.submitNextProblem({
      municipalityId: 'castel-bolognese',
      title: 'Backup del tema civico',
      description: 'Contenuto usato per la prova isolata.',
      category: 'decor',
      userId: 'anon:backup-user',
    });
    store.close();
    store = null;

    const { stdout } = await execFileAsync(
      process.execPath,
      ['scripts/rehearse_restore.js'],
      {
        cwd: new URL('..', import.meta.url),
        env: { ...process.env, BACKUP_PATH: backupPath },
      },
    );
    const result = JSON.parse(stdout.trim());
    assert.deepEqual(result, {
      event: 'sqlite_restore_rehearsal_completed',
      schemaVersion: 4,
      fantasy: { seasons: 3, cards: 36, matchdays: 24, players: 0, drafts: 0, snapshots: 0, quotes: 0, transfers: 0, transfer_commands: 0 },
      municipalities: 3,
      suggestions: 6,
      predictions: 0,
      predictionResults: 0,
    });
  } finally {
    store?.close();
    await rm(directory, { recursive: true, force: true });
  }
});
