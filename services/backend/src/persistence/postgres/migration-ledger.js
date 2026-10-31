const appliedMigrationTable = 'public.pgmigrations';
const attestationTable = 'public.migration_attestations';

export async function readAppliedMigrations(client) {
  if (!(await tableExists(client, appliedMigrationTable))) return [];
  const result = await client.query(`
    SELECT id::text AS migration_table_id, name
    FROM public.pgmigrations
    ORDER BY run_on, id
  `);
  return result.rows;
}

export async function verifyDatabaseMigrationState(client, manifest) {
  const applied = await readAppliedMigrations(client);
  const manifestByName = new Map(manifest.map((entry) => [entry.name, entry]));
  for (const migration of applied) {
    if (!manifestByName.has(migration.name)) {
      throw new Error(
        `Applied migration ${migration.name} is absent from the manifest.`,
      );
    }
  }

  const hasLedger = await tableExists(client, attestationTable);
  if (!hasLedger) {
    if (applied.length > 0) {
      throw new Error('Applied migrations exist without an attestation ledger.');
    }
    return { applied, attestations: [] };
  }

  const result = await client.query(`
    SELECT DISTINCT ON (migration_name)
      id::text,
      migration_table_id::text,
      migration_name,
      migration_sha256,
      action
    FROM public.migration_attestations
    ORDER BY migration_name, public.migration_attestations.id DESC
  `);
  const latestByName = new Map(
    result.rows.map((row) => [row.migration_name, row]),
  );
  const appliedNames = new Set(applied.map((migration) => migration.name));

  for (const migration of applied) {
    const entry = manifestByName.get(migration.name);
    const attestation = latestByName.get(migration.name);
    if (!attestation || attestation.action !== 'apply') {
      throw new Error(
        `Applied migration ${migration.name} has no current apply attestation.`,
      );
    }
    if (
      attestation.migration_sha256 !== entry.sha256 ||
      attestation.migration_table_id !== migration.migration_table_id
    ) {
      throw new Error(`Attestation mismatch for migration ${migration.name}.`);
    }
  }

  for (const [name, attestation] of latestByName) {
    if (attestation.action === 'apply' && !appliedNames.has(name)) {
      throw new Error(`Ledger marks unapplied migration ${name} as applied.`);
    }
  }

  return { applied, attestations: result.rows };
}

export async function recordMigrationAttestation(
  client,
  {
    migration,
    migrationTableId,
    action,
    sourceCommit,
    artifactDigest,
    driverVersion,
    runnerVersion,
  },
) {
  if (!(await tableExists(client, attestationTable))) return false;
  await client.query(
    `
      INSERT INTO public.migration_attestations (
        migration_id,
        migration_table_id,
        migration_name,
        migration_sha256,
        action,
        source_commit,
        artifact_digest,
        driver_version,
        runner_version
      ) VALUES ($1::bigint, $2::integer, $3, $4, $5, $6, $7, $8, $9)
    `,
    [
      migration.id,
      migrationTableId,
      migration.name,
      migration.sha256,
      action,
      sourceCommit,
      artifactDigest,
      driverVersion,
      runnerVersion,
    ],
  );
  return true;
}

async function tableExists(client, qualifiedName) {
  const result = await client.query(
    'SELECT to_regclass($1) IS NOT NULL AS exists',
    [qualifiedName],
  );
  return result.rows[0].exists;
}
