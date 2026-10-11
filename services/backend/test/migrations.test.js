import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';

import { runner } from 'node-pg-migrate';
import pg from 'pg';

import {
  backendRoot,
  verifyMigrationManifest,
} from '../src/persistence/postgres/migration-manifest.js';
import { findMigrationHistoryViolations } from '../src/persistence/postgres/migration-history.js';
import { runPostgresMigrations } from '../src/persistence/postgres/migrator.js';

const { Client } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const artifactDigest = 'sha256:' + 'a'.repeat(64);

describe('migration manifest', () => {
  it('pins the approved tools and exact migration checksum', async () => {
    const [migrations, packageJson, packageLock] = await Promise.all([
      verifyMigrationManifest(),
      readJson(path.join(backendRoot, 'package.json')),
      readJson(path.join(backendRoot, 'package-lock.json')),
    ]);

    assert.equal(packageJson.dependencies.pg, '8.22.0');
    assert.equal(packageJson.devDependencies['node-pg-migrate'], '8.0.4');
    assert.equal(packageLock.packages['node_modules/pg'].version, '8.22.0');
    assert.equal(
      packageLock.packages['node_modules/node-pg-migrate'].version,
      '8.0.4',
    );
    assert.equal(migrations.length, 5);
    assert.equal(
      migrations[0].name,
      '20260715090000000_initial_persistence_schema',
    );
    assert.equal(
      migrations[1].name,
      '20260716190000000_write_idempotency',
    );
    assert.equal(migrations.every((entry) => /^[0-9a-f]{64}$/.test(entry.sha256)), true);
  });

  it('allows additions and rejects mutation, removal or rename of history', () => {
    assert.deepEqual(
      findMigrationHistoryViolations(
        'A\tmigrations/20260716190000000_write_idempotency.js\n' +
          'M\tmigrations/manifest.json\n',
      ),
      [],
    );
    assert.deepEqual(
      findMigrationHistoryViolations(
        'M\tmigrations/20260715090000000_initial_persistence_schema.js\n' +
          'D\tmigrations/20260714090000000_removed.js\n' +
          'R100\tmigrations/20260713090000000_old.js\t' +
          'migrations/20260713090000000_new.js\n',
      ),
      [
        'M:migrations/20260715090000000_initial_persistence_schema.js',
        'D:migrations/20260714090000000_removed.js',
        'R100:migrations/20260713090000000_old.js->migrations/20260713090000000_new.js',
      ],
    );
  });
});

describe(
  'PostgreSQL migration integration',
  { skip: databaseUrl ? false : 'TEST_DATABASE_URL is not configured.' },
  () => {
    before(async () => {
      assertDisposableTestDatabase(databaseUrl);
      await resetPublicSchema(databaseUrl);
    });

    after(async () => {
      await resetPublicSchema(databaseUrl);
    });

    it('recovers a failed transactional migration without partial schema', async () => {
      const previousInjection = process.env.MIGRATION_FAILURE_INJECTION;
      process.env.MIGRATION_FAILURE_INJECTION = 'enabled';
      try {
        await assert.rejects(runFailureRecoveryMigration(), (error) => {
          return error.code === '42883';
        });

        await withClient(databaseUrl, async (client) => {
          const partial = await client.query(
            "SELECT to_regclass('public.transactional_recovery_probe') AS table_name",
          );
          const tracked = await client.query(
            'SELECT count(*)::integer AS count FROM public.pgmigrations',
          );
          assert.equal(partial.rows[0].table_name, null);
          assert.equal(tracked.rows[0].count, 0);
        });

        delete process.env.MIGRATION_FAILURE_INJECTION;
        const recovered = await runFailureRecoveryMigration();
        assert.equal(recovered.length, 1);

        await withClient(databaseUrl, async (client) => {
          const probe = await client.query(
            "SELECT to_regclass('public.transactional_recovery_probe') AS table_name",
          );
          assert.equal(
            probe.rows[0].table_name,
            'transactional_recovery_probe',
          );
        });
      } finally {
        if (previousInjection === undefined) {
          delete process.env.MIGRATION_FAILURE_INJECTION;
        } else {
          process.env.MIGRATION_FAILURE_INJECTION = previousInjection;
        }
        await resetPublicSchema(databaseUrl);
      }
    });

    it('upgrades the prior schema without inventing a place or losing IDs and votes', async () => {
      try {
        await runPostgresMigrations({
          databaseUrl, attestationDatabaseUrl: databaseUrl,
          count: 2, sourceCommit: 'legacy-upgrade-test', artifactDigest,
          logger: { debug() {}, info() {}, warn() {}, error() {} },
        });
        await withClient(databaseUrl, async (client) => {
          await client.query(`
            INSERT INTO public.municipalities (id, name, activation_state, base_activation_state)
              VALUES ('legacy-town', 'Legacy Town', 'collectingSignals', 'collectingSignals');
            INSERT INTO public.suggestions (
              id, municipality_id, title, normalized_title, description, category,
              status, submitted_by_user_id, submitted_by_display_name, created_at
            ) VALUES ('legacy-proposal', 'legacy-town', 'Alberi', 'alberi',
              'Ombra', 'green', 'pending', 'legacy-user', 'Cittadino', '2026-07-16T10:00:00Z');
            INSERT INTO public.suggestion_votes (suggestion_id, municipality_id, user_id, vote)
              VALUES ('legacy-proposal', 'legacy-town', 'legacy-voter', 'up');
          `);
        });
        assert.equal((await migrate('up')).length, 3);
        await withClient(databaseUrl, async (client) => {
          const rows = await client.query(`
            SELECT s.id, s.status, s.location, s.created_at, v.vote
            FROM public.suggestions s JOIN public.suggestion_votes v ON v.suggestion_id = s.id
          `);
          assert.deepEqual(rows.rows, [{
            id: 'legacy-proposal', status: 'pending', location: null,
            created_at: new Date('2026-07-16T10:00:00Z'), vote: 'up',
          }]);
          for (const location of [{}, [], { kind: 'municipality', label: 'Hidden' },
            { kind: 'specific' }, { kind: 'specific', label: ' ' },
            { kind: 'specific', label: 'Via Roma', civic: null },
            { kind: 'specific', label: '😀'.repeat(121) },
            { kind: 'specific', label: 'Via Roma', reference: 'x'.repeat(201) }]) {
            await assert.rejects(client.query(
              'UPDATE public.suggestions SET location = $1::jsonb WHERE id = $2',
              [JSON.stringify(location), 'legacy-proposal'],
            ), (error) => error.code === '23514' && error.constraint === 'suggestions_location_valid');
          }
          await client.query('UPDATE public.suggestions SET location = $1::jsonb WHERE id = $2', [
            JSON.stringify({ kind: 'specific', label: '😀'.repeat(120), civic: '😀'.repeat(20), reference: '😀'.repeat(200) }),
            'legacy-proposal',
          ]);
          const saved = await client.query('SELECT location FROM public.suggestions WHERE id = $1', ['legacy-proposal']);
          assert.equal(Array.from(saved.rows[0].location.label).length, 120);
        });
      } finally {
        await resetPublicSchema(databaseUrl);
      }
    });

    it('serializes two runners from empty, attests checksums and is idempotent', async () => {
      const [first, second] = await Promise.all([migrate('up'), migrate('up')]);
      const third = await migrate('up');

      assert.deepEqual([first.length, second.length].sort(), [0, 5]);
      assert.equal(third.length, 0);

      await withClient(databaseUrl, async (client) => {
        const tables = await client.query(`
          SELECT table_name
          FROM information_schema.tables
          WHERE table_schema = 'public'
          ORDER BY table_name
        `);
        assert.deepEqual(
          tables.rows.map((row) => row.table_name),
          [
            'migration_attestations',
            'municipalities',
            'pgmigrations',
            'prediction_results',
            'predictions',
            'problem_events',
            'problems',
            'proposal_reviews',
            'proposal_sessions',
            'reputation_events',
            'suggestion_votes',
            'suggestions',
            'turns',
            'write_idempotency',
          ],
        );

        const attestations = await client.query(`
          SELECT migration_name, migration_sha256, action,
                 driver_version, runner_version
          FROM public.migration_attestations
          ORDER BY migration_id
        `);
        const manifest = await verifyMigrationManifest();
        assert.deepEqual(
          attestations.rows,
          manifest.map((migration) => ({
            migration_name: migration.name,
            migration_sha256: migration.sha256,
            action: 'apply',
            driver_version: '8.22.0',
            runner_version: '8.0.4',
          })),
        );
        await assert.rejects(
          client.query(
            "UPDATE public.migration_attestations SET action = 'reconcile'",
          ),
          (error) => error.code === '55000',
        );
      });
    });

    it('allows distinct same-title proposals and enforces municipality scope and choice lock', async () => {
      await withClient(databaseUrl, async (client) => {
        await client.query(`
          INSERT INTO public.municipalities
            (id, name, activation_state, base_activation_state)
          VALUES
            ('town-a', 'Town A', 'active', 'active'),
            ('town-b', 'Town B', 'collectingSignals', 'collectingSignals');

          INSERT INTO public.turns
            (id, municipality_id, state, start_at, end_at)
          VALUES
            ('turn-a', 'town-a', 'open', now(), now() + interval '7 days'),
            ('turn-b', 'town-b', 'open', now(), now() + interval '7 days');

          INSERT INTO public.suggestions (
            id, municipality_id, title, normalized_title, description,
            category, status, submitted_by_user_id, submitted_by_display_name
          ) VALUES (
            'suggestion-a', 'town-a', '  Parco   pulito ', 'parco pulito',
            'Descrizione', 'cleanliness', 'pending', 'user-a', 'Cittadino'
          );

          INSERT INTO public.problems (
            id, municipality_id, turn_id, problem_key, title, zone_name,
            status, trend_percent
          ) VALUES (
            'problem-a', 'town-a', 'turn-a', 'green', 'Parco', 'Centro',
            'stable', 0
          );

          INSERT INTO public.predictions (
            id, municipality_id, turn_id, problem_id, user_id, choice
          ) VALUES (
            'prediction-a', 'town-a', 'turn-a', 'problem-a', 'user-a',
            'stable'
          );
        `);

        await client.query(`
            INSERT INTO public.suggestions (
              id, municipality_id, title, normalized_title, description,
              category, status, submitted_by_user_id,
              submitted_by_display_name
            ) VALUES (
              'suggestion-duplicate', 'town-a', 'Parco pulito',
              'parco pulito', 'Altra descrizione', 'green', 'pending',
              'user-b', 'Cittadino'
            )
          `);

        await assert.rejects(
          client.query(`
            INSERT INTO public.problems (
              id, municipality_id, turn_id, problem_key, title, zone_name,
              status, trend_percent
            ) VALUES (
              'problem-cross-town', 'town-b', 'turn-a', 'green', 'Parco',
              'Centro', 'stable', 0
            )
          `),
          (error) => error.code === '23503',
        );

        await assert.rejects(
          client.query(`
            UPDATE public.predictions
            SET choice = 'improve', updated_at = now()
            WHERE id = 'prediction-a'
          `),
          (error) =>
            error.code === '23514' &&
            error.constraint === 'predictions_choice_immutable',
        );

        const metadataUpdate = await client.query(`
          UPDATE public.predictions
          SET motivations = ARRAY['visibleActions'], updated_at = now()
          WHERE id = 'prediction-a'
          RETURNING choice, motivations
        `);
        assert.deepEqual(metadataUpdate.rows[0], {
          choice: 'stable',
          motivations: ['visibleActions'],
        });
      });
    });

    it('reverses and reapplies the newest schema migration', async () => {
      await assert.rejects(migrate('down', 3), (error) => error.code === '23505');
      await withClient(databaseUrl, async (client) => {
        const result = await client.query('SELECT count(*)::integer AS count FROM public.suggestions');
        assert.equal(result.rows[0].count, 2);
        await client.query("DELETE FROM public.suggestions WHERE id = 'suggestion-duplicate'");
      });
      const down = await migrate('down', 3);
      assert.equal(down.length, 3);

      await withClient(databaseUrl, async (client) => {
        const result = await client.query(
          "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'suggestions' AND column_name = 'location'",
        );
        assert.equal(result.rows.length, 0);
      });

      const up = await migrate('up');
      assert.equal(up.length, 3);
    });
  },
);

function migrate(direction, count) {
  return runPostgresMigrations({
    direction,
    ...(count === undefined ? {} : { count }),
    databaseUrl,
    attestationDatabaseUrl: databaseUrl,
    sourceCommit: 'integration-test',
    artifactDigest,
    logger: {
      debug() {},
      info() {},
      warn() {},
      error() {},
    },
  });
}

function runFailureRecoveryMigration() {
  return runner({
    databaseUrl,
    migrationsTable: 'pgmigrations',
    migrationsSchema: 'public',
    schema: 'public',
    dir: path.join(
      backendRoot,
      'test',
      'fixtures',
      'transactional-failure-migrations',
    ),
    checkOrder: true,
    direction: 'up',
    singleTransaction: true,
    noLock: false,
    fake: false,
    createSchema: false,
    createMigrationsSchema: false,
    logger: {
      debug() {},
      info() {},
      warn() {},
      error() {},
    },
  });
}

function assertDisposableTestDatabase(value) {
  const url = new URL(value);
  const databaseName = url.pathname.slice(1);
  if (!databaseName.endsWith('_test')) {
    throw new Error('TEST_DATABASE_URL must name a database ending in _test.');
  }
  if (!['127.0.0.1', 'localhost', '::1'].includes(url.hostname)) {
    throw new Error('Migration integration tests require a loopback database.');
  }
}

async function resetPublicSchema(value) {
  await withClient(value, (client) =>
    client.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;'),
  );
}

async function withClient(value, callback) {
  const client = new Client({ connectionString: value });
  await client.connect();
  try {
    return await callback(client);
  } finally {
    await client.end();
  }
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}
