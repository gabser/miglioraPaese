import { constants } from 'node:fs';
import { access, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { backup, DatabaseSync } from 'node:sqlite';

const databasePath = requiredPath('DATABASE_PATH');
const backupPath = requiredPath('BACKUP_PATH');
if (databasePath === backupPath) {
  throw new Error('BACKUP_PATH must differ from DATABASE_PATH.');
}

await access(databasePath, constants.R_OK);
try {
  await access(backupPath, constants.F_OK);
  throw new Error('BACKUP_PATH already exists; backups are not overwritten.');
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
await mkdir(dirname(backupPath), { recursive: true });

const database = new DatabaseSync(databasePath, { readOnly: true });
try {
  await backup(database, backupPath);
  console.log(
    JSON.stringify({
      event: 'sqlite_backup_completed',
      source: databasePath,
      destination: backupPath,
    }),
  );
} finally {
  database.close();
}

function requiredPath(name) {
  const value = process.env[name];
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${name} is required.`);
  }
  return resolve(value);
}
