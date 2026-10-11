import { execFileSync } from 'node:child_process';

import { backendRoot, verifyMigrationManifest } from './migration-manifest.js';

export async function verifyAppendOnlyMigrationHistory({
  baseRef = process.env.MIGRATION_BASE_REF,
  execute = execFileSync,
} = {}) {
  if (
    typeof baseRef !== 'string' ||
    baseRef.trim() === '' ||
    baseRef.startsWith('-')
  ) {
    throw new TypeError('MIGRATION_BASE_REF must be an explicit safe git ref.');
  }
  await verifyMigrationManifest();
  const output = execute(
    'git',
    [
      'diff',
      '--name-status',
      '--find-renames',
      baseRef.trim(),
      '--',
      'migrations',
    ],
    { cwd: backendRoot, encoding: 'utf8' },
  );
  const violations = findMigrationHistoryViolations(output);
  if (violations.length > 0) {
    throw new Error(
      'Migration history is not append-only: ' + violations.join(', '),
    );
  }
  return { baseRef: baseRef.trim() };
}

export function findMigrationHistoryViolations(output) {
  if (typeof output !== 'string') {
    throw new TypeError('Git migration diff output must be a string.');
  }
  const violations = [];
  for (const line of output.split(/\r?\n/)) {
    if (!line.trim()) continue;
    const [status, ...paths] = line.split('\t');
    const migrationPaths = paths.filter(
      (file) => /^migrations\/\d{17}_[a-z0-9_-]+\.js$/.test(file),
    );
    if (migrationPaths.length > 0 && status !== 'A') {
      violations.push(`${status}:${migrationPaths.join('->')}`);
    }
  }
  return violations;
}
