import { constants } from 'node:fs';
import { access, copyFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, join, resolve } from 'node:path';

import { createPersistentStore } from '../src/server.js';

const configuredPath = process.env.BACKUP_PATH;
if (typeof configuredPath !== 'string' || configuredPath.trim() === '') {
  throw new Error('BACKUP_PATH is required.');
}

const backupPath = resolve(configuredPath);
await access(backupPath, constants.R_OK);
const rehearsalDirectory = await mkdtemp(
  join(tmpdir(), 'migliorapaese-restore-rehearsal-'),
);
const restoredPath = join(rehearsalDirectory, basename(backupPath));
let store;

try {
  await copyFile(backupPath, restoredPath, constants.COPYFILE_EXCL);
  store = createPersistentStore({ databasePath: restoredPath });
  if (store.isReady() !== true) {
    throw new Error('Restored store is not ready.');
  }
  const state = store.exportState();
  console.log(
    JSON.stringify({
      event: 'sqlite_restore_rehearsal_completed',
      schemaVersion: store.persistence.schemaVersion,
      municipalities: state.municipalities.length,
      fantasy: store.fantasy.counts(),
      suggestions: state.suggestedProblems.length,
      predictions: state.predictions.length,
      predictionResults: state.predictionResults.length,
    }),
  );
} finally {
  store?.close();
  await rm(rehearsalDirectory, { recursive: true, force: true });
}
