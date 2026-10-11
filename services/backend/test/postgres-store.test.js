import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import { after, before, describe, it } from 'node:test';

import pg from 'pg';

import { loadPostgresConfig } from '../src/config/environment.js';
import { createApp } from '../src/http/app.js';
import {
  mapPredictionRow,
  mapSuggestedProblemRow,
} from '../src/persistence/postgres/mappers.js';
import { runPostgresMigrations } from '../src/persistence/postgres/migrator.js';
import { createPostgresPool } from '../src/persistence/postgres/pool.js';
import { createPostgresStore } from '../src/persistence/postgres/postgres-store.js';
import { seedPostgres } from '../src/persistence/postgres/seed.js';
import { withTransaction } from '../src/persistence/postgres/transaction.js';
import { fingerprintRequest } from '../src/persistence/postgres/idempotency.js';
import { startServer } from '../src/server.js';

const { Client } = pg;
const databaseUrl = process.env.TEST_DATABASE_URL;
const silentLogger = {
  debug() {},
  info() {},
  warn() {},
  error() {},
};

describe('strict PostgreSQL mappers', () => {
  it('maps nullable confidence, bigint counts and UTC timestamps explicitly', () => {
    const prediction = mapPredictionRow({
      id: 'prediction-a',
      turn_id: 'turn-a',
      problem_id: 'problem-a',
      user_id: 'user-a',
      choice: 'stable',
      motivations: [],
      confidence: null,
      created_at: new Date('2026-07-16T08:00:00+02:00'),
      updated_at: '2026-07-16T06:01:00Z',
    });
    const suggestion = mapSuggestedProblemRow({
      id: 'suggestion-a',
      title: 'Tema',
      description: 'Descrizione',
      location: null,
      category: 'green',
      status: 'pending',
      submitted_by_user_id: 'user-a',
      submitted_by_display_name: 'Cittadino',
      created_at: '2026-07-16T06:00:00Z',
      votes_up: '3',
      votes_down: '1',
      my_vote: 'up',
    });

    assert.equal(prediction.confidence, null);
    assert.equal(prediction.createdAt, '2026-07-16T06:00:00.000Z');
    assert.equal(suggestion.votesUp, 3);
    assert.equal(suggestion.score, 2);
  });

  it('fails closed on enum drift, implicit timezone and unexpected columns', () => {
    const base = {
      id: 'prediction-a',
      turn_id: 'turn-a',
      problem_id: 'problem-a',
      user_id: 'user-a',
      choice: 'stable',
      motivations: [],
      confidence: null,
      created_at: '2026-07-16T06:00:00Z',
      updated_at: '2026-07-16T06:01:00Z',
    };

    assert.throws(
      () => mapPredictionRow({ ...base, choice: 'unknown' }),
      /unknown enum value/,
    );
    assert.throws(
      () => mapPredictionRow({ ...base, created_at: '2026-07-16 06:00:00' }),
      /explicit timezone/,
    );
    assert.throws(
      () => mapPredictionRow({ ...base, leaked_column: 'value' }),
      /Unexpected PostgreSQL row shape/,
    );
  });
});

describe('PostgreSQL transaction helper', () => {
  it('uses one acquired client and commits before release', async () => {
    const calls = [];
    const client = {
      async query(sql) {
        calls.push(sql);
      },
      release() {
        calls.push('RELEASE');
      },
    };
    const result = await withTransaction(
      { async connect() { calls.push('CONNECT'); return client; } },
      async (transactionClient) => {
        assert.equal(transactionClient, client);
        calls.push('CALLBACK');
        return 'saved';
      },
      { logger: silentLogger },
    );

    assert.equal(result, 'saved');
    assert.deepEqual(calls, [
      'CONNECT',
      'BEGIN',
      'CALLBACK',
      'COMMIT',
      'RELEASE',
    ]);
  });

  it('rolls back application failures and always releases the client', async () => {
    const calls = [];
    const client = {
      async query(sql) {
        calls.push(sql);
      },
      release() {
        calls.push('RELEASE');
      },
    };
    await assert.rejects(
      withTransaction(
        { async connect() { calls.push('CONNECT'); return client; } },
        async () => {
          calls.push('CALLBACK');
          throw new Error('failure injection');
        },
        { logger: silentLogger },
      ),
      /failure injection/,
    );
    assert.deepEqual(calls, [
      'CONNECT',
      'BEGIN',
      'CALLBACK',
      'ROLLBACK',
      'RELEASE',
    ]);
  });
});

describe(
  'PostgreSQL repository adapter integration',
  { skip: databaseUrl ? false : 'TEST_DATABASE_URL is not configured.' },
  () => {
    let pool;
    let store;
    let idempotencyCounter = 0;

    before(async () => {
      assertDisposableTestDatabase(databaseUrl);
      await resetPublicSchema(databaseUrl);
      await runPostgresMigrations({
        databaseUrl,
        attestationDatabaseUrl: databaseUrl,
        sourceCommit: 'postgres-store-integration-test',
        artifactDigest: 'sha256:' + 'b'.repeat(64),
        logger: silentLogger,
      });
      pool = createPostgresPool(
        loadPostgresConfig({
          env: {
            DATABASE_URL: databaseUrl,
            PG_POOL_MAX: '3',
          },
        }),
        { logger: silentLogger },
      );
      await seedPostgres(pool, {
        profile: 'test',
        now: new Date('2026-07-16T10:00:00Z'),
      });
      await seedPostgres(pool, {
        profile: 'test',
        now: new Date('2026-07-16T10:00:00Z'),
      });
      const postgresStore = createPostgresStore(pool, { logger: silentLogger });
      const withKey = (input) => ({
        idempotencyKey:
          input.idempotencyKey ?? `integration-key-${++idempotencyCounter}`,
        ...input,
      });
      store = {
        ...postgresStore,
        submitNextProblem: (input) =>
          postgresStore.submitNextProblem(withKey(input)),
        voteNextProblem: (input) =>
          postgresStore.voteNextProblem(withKey(input)),
        upsertPrediction: (input) =>
          postgresStore.upsertPrediction(withKey(input)),
      };
    });

    after(async () => {
      await pool?.end();
      await resetPublicSchema(databaseUrl);
    });

    it('serializes concurrent quota, replays receipts, and persists private review with rollback', async () => {
      const now = Date.UTC(2026, 9, 11, 12);
      const policyStore = createPostgresStore(pool, { logger: silentLogger, clock: () => now });
      const input = index => ({ municipalityId: 'bologna', title: `Quota race ${index}`, description: 'Ostacolo nel parco', category: 'green', userId: 'quota-race', idempotencyKey: `quota-race-${index}` });
      const attempts = await Promise.allSettled(Array.from({ length: 5 }, (_,i) => policyStore.submitNextProblem(input(i))));
      assert.equal(attempts.filter(x => x.status === 'fulfilled').length, 3);
      for (const x of attempts.filter(x => x.status === 'rejected')) assert.equal(x.reason.statusCode, 429);
      const winner = attempts.findIndex(x => x.status === 'fulfilled'); const original = attempts[winner].value;
      assert.deepEqual(await policyStore.submitNextProblem(input(winner)), original);
      const review = { municipalityId: 'bologna', problemId: original.id, decision: 'reject', expectedStatus: 'pending', operatorLabel: 'Test locale', reason: 'Motivo riservato' };
      const broken = createPostgresStore(pool, { logger: silentLogger, onWriteCheckpoint: async name => { if (name === 'review_after_update') throw new Error('injected rollback'); } });
      await assert.rejects(broken.reviewSuggestion(review), /injected rollback/);
      assert.equal((await policyStore.getNextProblem({ municipalityId: 'bologna', problemId: original.id })).status, 'pending');
      assert.equal((await policyStore.reviewSuggestion(review)).status, 'rejected');
      const fresh = createPostgresStore(pool, { logger: silentLogger, clock: () => now });
      assert.equal((await fresh.getNextProblem({ municipalityId: 'bologna', problemId: original.id })).status, 'rejected');
      const audit = await pool.query('SELECT private_reason FROM public.proposal_reviews WHERE suggestion_id = $1', [original.id]);
      assert.deepEqual(audit.rows, [{ private_reason: 'Motivo riservato' }]);
      await assert.rejects(fresh.reviewSuggestion(review), e => e.statusCode === 409);
      await fresh.reviewSuggestion({ ...review, decision: 'reopen', expectedStatus: 'rejected' });
      assert.deepEqual(await fresh.submitNextProblem(input(winner)), original);
      await assert.rejects(fresh.submitNextProblem(input(6)), e => e.statusCode === 429);
      assert.equal((await createPostgresStore(pool, { logger: silentLogger, clock: () => now + 3600001 }).submitNextProblem(input(6))).status, 'pending');
      await assert.rejects(fresh.submitNextProblem({ ...input(7), userId: 'session:spoof' }), e => e.statusCode === 401);
      await pool.query("DELETE FROM public.suggestions WHERE submitted_by_user_id = 'quota-race'");
    });

    it('reads municipalities, current turns and problems through strict mappers', async () => {
      const municipality = await store.getMunicipality('comune:Bologna');
      const turn = await store.getCurrentTurn('bologna');
      const problems = await store.listProblems('bologna');

      assert.deepEqual(municipality, {
        id: 'bologna',
        name: 'Bologna',
        activationState: 'active',
        baseActivationState: 'active',
      });
      assert.equal(turn.id, 'turn-bologna-today');
      assert.match(turn.startAt, /Z$/);
      assert.match(turn.endAt, /Z$/);
      assert.deepEqual(
        problems.map((problem) => problem.id).sort(),
        ['problem-green-margherita', 'problem-traffic-indipendenza'],
      );
      assert.equal(typeof problems[0].trendPercent, 'number');
      assert.match(problems[0].updatedAt, /Z$/);
    });

    it('reads filtered suggestions with vote isolation per user', async () => {
      const forDemo = await store.listNextProblems({
        municipalityId: 'bologna',
        userId: 'demo-user',
      });
      const forOther = await store.listNextProblems({
        municipalityId: 'bologna',
        userId: 'user-isolated',
      });
      const matching = await store.listNextProblems({
        municipalityId: 'bologna',
        status: 'approved',
        query: 'centrali',
        userId: 'user-isolated',
      });

      assert.equal(forDemo.length, 1);
      assert.equal(forDemo[0].votesUp, 4);
      assert.equal(forDemo[0].votesDown, 1);
      assert.equal(forDemo[0].myVote, 'up');
      assert.equal(forOther[0].myVote, 'none');
      assert.deepEqual(matching.map((item) => item.id), [
        'suggested-queues-registry',
      ]);
    });

    it('reads only the requested owner predictions and preserves null values', async () => {
      const demo = await store.getPredictions({
        turnId: 'turn-bologna-today',
        userId: 'demo-user',
      });
      const isolated = await store.getPredictions({
        turnId: 'turn-bologna-today',
        userId: 'user-isolated',
      });

      assert.equal(demo.length, 1);
      assert.equal(demo[0].userId, 'demo-user');
      assert.equal(demo[0].confidence, null);
      assert.match(demo[0].createdAt, /Z$/);
      assert.equal(isolated.length, 1);
      assert.equal(isolated[0].userId, 'user-isolated');
      assert.equal(isolated[0].confidence, 'gutFeeling');
    });

    it('replays prior idempotency records without changing the legacy fingerprint', async () => {
      const input = {
        municipalityId: 'bologna', title: 'Legacy replay', description: 'Legacy description',
        category: 'green', userId: 'legacy-user',
      };
      const response = {
        id: 'historical-proposal', title: input.title, shortDescription: input.description,
        category: 'green', status: 'pending', votesUp: 0, votesDown: 0, score: 0,
        myVote: 'none', submittedByUserId: input.userId, submittedByDisplayName: 'Cittadino',
        createdAt: '2026-07-16T10:00:00.000Z',
        promotionRule: { threshold: 1, scopeLabel: 'green', reason: 'Regola demo' },
      };
      await pool.query(`
        INSERT INTO public.write_idempotency
          (operation, idempotency_key, request_sha256, response_status, response_body, completed_at)
        VALUES ('submit_suggestion', 'legacy-record-key', $1, 201, $2::jsonb, clock_timestamp())
      `, [fingerprintRequest(input), JSON.stringify(response)]);
      const before = await store.listNextProblems({ municipalityId: 'bologna' });
      assert.deepEqual(await store.submitNextProblem({ ...input, location: null, idempotencyKey: 'legacy-record-key' }), response);
      assert.equal((await store.listNextProblems({ municipalityId: 'bologna' })).length, before.length);
    });

    it('persists places and accepts same-title proposals with separate IDs', async () => {
      const input = {
        municipalityId: 'castel-bolognese',
        title: '  Alberi   in piazza  ',
        description: 'Aumentare ombra e qualità dello spazio pubblico.',
        category: 'green',
        userId: 'user-submit',
        location: { kind: 'specific', label: 'Via Milano', civic: '12/A', reference: 'Di fronte al parco' },
      };
      const created = await store.submitNextProblem(input);

      assert.equal(created.title, input.title);
      assert.equal(created.status, 'pending');
      assert.equal(created.submittedByUserId, 'user-submit');
      assert.equal(created.submittedByDisplayName, 'Cittadino');
      assert.equal(created.myVote, 'none');
      assert.deepEqual(created.location, input.location);
      const second = await store.submitNextProblem({
          ...input,
          title: 'alberi in PIAZZA',
          userId: 'another-user',
          location: { kind: 'specific', label: 'Via Roma' },
        });
      assert.notEqual(created.id, second.id);

      const persisted = await store.listNextProblems({
        municipalityId: 'castel-bolognese',
        query: 'alberi',
        userId: 'user-submit',
      });
      assert.deepEqual(new Set(persisted.map((item) => item.id)), new Set([created.id, second.id]));
      assert.deepEqual(persisted.find((item) => item.id === created.id).location, input.location);
      const count = await pool.query(
        `SELECT count(*)::integer AS count
         FROM public.suggestions
         WHERE municipality_id = $1 AND normalized_title = $2`,
        ['castel-bolognese', 'alberi in piazza'],
      );
      assert.equal(count.rows[0].count, 2);
    });

    it('retains all place kinds through a fresh adapter and promoted cards', async () => {
      const places = [
        { kind: 'specific', label: 'Via Milano' },
        { kind: 'specific', label: 'Parco delle Rose', reference: 'Ingresso nord' },
        { kind: 'specific', label: 'Incrocio Roma / Verdi' },
        { kind: 'specific', label: 'Tratto della ciclabile', civic: '12/A' },
        { kind: 'municipality' },
        null,
      ];
      const created = [];
      for (const [index, location] of places.entries()) {
        const input = {
          municipalityId: 'bologna', title: 'Potatura distinta persistente',
          description: 'Descrizione', category: 'green', userId: `place-test-${index}`, location,
          idempotencyKey: `postgres-place-case-${index}`,
        };
        const item = await store.submitNextProblem(input);
        created.push(item);
        assert.deepEqual(item.location, location);
        assert.deepEqual(await store.submitNextProblem(input), item);
        const vote = await store.voteNextProblem({ municipalityId: 'bologna', problemId: item.id, userId: 'place-test', vote: 'up' });
        assert.deepEqual(vote.location, location);
      }
      const fresh = createPostgresStore(pool, { logger: silentLogger });
      const listed = await fresh.listNextProblems({ municipalityId: 'bologna', userId: 'place-test' });
      const problems = await fresh.listProblems('bologna');
      for (const [term, index] of [['milano',0],['ingresso nord',1],['12/A',3],['intero comune',4]]) {
        const found = await fresh.listNextProblems({ municipalityId:'bologna', query:term, userId:'place-test' });
        assert.ok(found.some(x=>x.id===created[index].id),term);
        assert.ok(!found.some(x=>x.id===created[5].id), 'Legacy null is not an invented place');
      }
      for (const [index, item] of created.entries()) {
        assert.deepEqual(listed.find((entry) => entry.id === item.id).location, places[index]);
        const expected = places[index] === null ? 'Luogo non indicato'
          : places[index].kind === 'municipality' ? 'Intero Comune'
          : [places[index].label, places[index].civic].filter(Boolean).join(', ');
        assert.equal(problems.find((entry) => entry.id === `proposal_${item.id}`).zoneName, expected);
      }
      // Case folding can grow text or differ by locale; SQL computes its own normalized title.
      const unicode = await store.submitNextProblem({
        municipalityId: 'bologna', title: 'İ'.repeat(120), description: '😀'.repeat(1000),
        category: 'green', userId: 'place-test', location: { kind: 'specific', label: '😀'.repeat(120) },
      });
      assert.equal(unicode.shortDescription, '😀'.repeat(1000));
    });

    it('commits vote switching, promotion, demotion and activation atomically', async () => {
      const created = await store.submitNextProblem({
        municipalityId: 'castel-bolognese',
        title: 'Attraversamento via Roma persistente',
        description: 'Migliorare visibilità e sicurezza.',
        category: 'safety',
        userId: 'user-vote',
      });
      const down = await store.voteNextProblem({
        municipalityId: 'castel-bolognese',
        problemId: created.id,
        vote: 'down',
        userId: 'user-vote',
      });
      const promoted = await store.voteNextProblem({
        municipalityId: 'castel-bolognese',
        problemId: created.id,
        vote: 'up',
        userId: 'user-vote',
      });
      const active = await store.getMunicipality('castel-bolognese');
      const promotedProblems = await store.listProblems('castel-bolognese');
      const demoted = await store.voteNextProblem({
        municipalityId: 'castel-bolognese',
        problemId: created.id,
        vote: 'up',
        userId: 'user-vote',
      });
      const collecting = await store.getMunicipality('castel-bolognese');
      const remainingProblems = await store.listProblems('castel-bolognese');

      assert.deepEqual(
        {
          votesUp: down.votesUp,
          votesDown: down.votesDown,
          myVote: down.myVote,
          status: down.status,
        },
        { votesUp: 0, votesDown: 1, myVote: 'down', status: 'pending' },
      );
      assert.deepEqual(
        {
          votesUp: promoted.votesUp,
          votesDown: promoted.votesDown,
          myVote: promoted.myVote,
          status: promoted.status,
        },
        { votesUp: 1, votesDown: 0, myVote: 'up', status: 'approved' },
      );
      assert.equal(active.activationState, 'active');
      assert.equal(
        promotedProblems.some((item) => item.id === `proposal_${created.id}`),
        true,
      );
      assert.deepEqual(
        {
          votesUp: demoted.votesUp,
          votesDown: demoted.votesDown,
          myVote: demoted.myVote,
          status: demoted.status,
        },
        { votesUp: 0, votesDown: 0, myVote: 'none', status: 'pending' },
      );
      assert.equal(collecting.activationState, 'collectingSignals');
      assert.equal(
        remainingProblems.some((item) => item.id === `proposal_${created.id}`),
        false,
      );
    });

    it('persists prediction inserts and metadata while keeping choice locked', async () => {
      const input = {
        turnId: 'turn-bologna-today',
        problemId: 'problem-green-margherita',
        userId: 'user-persistent-prediction',
        choice: 'improve',
        motivations: [],
        confidence: null,
      };
      const created = await store.upsertPrediction(input);
      const updated = await store.upsertPrediction({
        ...input,
        motivations: ['visibleActions'],
        confidence: 'convinced',
      });

      assert.equal(updated.createdAt, created.createdAt);
      assert.deepEqual(updated.motivations, ['visibleActions']);
      assert.equal(updated.confidence, 'convinced');
      await assert.rejects(
        store.upsertPrediction({ ...input, choice: 'worsen' }),
        (error) =>
          error.statusCode === 409 && error.code === 'prediction_locked',
      );
      const persisted = await store.getPredictions({
        turnId: input.turnId,
        userId: input.userId,
      });
      assert.equal(persisted.length, 1);
      assert.equal(persisted[0].choice, 'improve');
      assert.deepEqual(persisted[0].motivations, ['visibleActions']);
    });

    it('rolls back a vote when promotion cannot find a current turn', async () => {
      await pool.query(`
        INSERT INTO public.municipalities
          (id, name, activation_state, base_activation_state)
        VALUES
          ('town-without-turn', 'Town Without Turn',
           'collectingSignals', 'collectingSignals');

        INSERT INTO public.suggestions (
          id, municipality_id, title, normalized_title, description,
          category, status, submitted_by_user_id, submitted_by_display_name
        ) VALUES (
          'suggestion-without-turn', 'town-without-turn', 'Tema senza turno',
          'tema senza turno', 'Descrizione', 'green', 'pending', 'seed',
          'Comune'
        );
      `);

      await assert.rejects(
        store.voteNextProblem({
          municipalityId: 'town-without-turn',
          problemId: 'suggestion-without-turn',
          vote: 'up',
          userId: 'user-rollback',
        }),
        (error) => error.statusCode === 404 && error.code === 'turn_not_found',
      );
      const state = await pool.query(`
        SELECT
          s.status,
          m.activation_state,
          count(v.*)::integer AS votes
        FROM public.suggestions s
        JOIN public.municipalities m ON m.id = s.municipality_id
        LEFT JOIN public.suggestion_votes v ON v.suggestion_id = s.id
        WHERE s.id = 'suggestion-without-turn'
        GROUP BY s.status, m.activation_state
      `);
      assert.deepEqual(state.rows[0], {
        status: 'pending',
        activation_state: 'collectingSignals',
        votes: 0,
      });
    });

    it('rolls back demotion when the promoted problem is already in use', async () => {
      const created = await store.submitNextProblem({
        municipalityId: 'castel-bolognese',
        title: 'Promozione referenziata',
        description: 'Fixture per verificare rollback e vincoli.',
        category: 'transport',
        userId: 'user-referenced-promotion',
      });
      await store.voteNextProblem({
        municipalityId: 'castel-bolognese',
        problemId: created.id,
        vote: 'up',
        userId: 'user-referenced-promotion',
      });
      await store.upsertPrediction({
        turnId: 'turn-castel-bolognese-today',
        problemId: `proposal_${created.id}`,
        userId: 'user-promotion-prediction',
        choice: 'stable',
        motivations: [],
        confidence: null,
      });

      await assert.rejects(
        store.voteNextProblem({
          municipalityId: 'castel-bolognese',
          problemId: created.id,
          vote: 'up',
          userId: 'user-referenced-promotion',
        }),
        (error) =>
          error.statusCode === 409 && error.code === 'promotion_in_use',
      );
      const persisted = await store.listNextProblems({
        municipalityId: 'castel-bolognese',
        userId: 'user-referenced-promotion',
      });
      const suggestion = persisted.find((item) => item.id === created.id);
      const problems = await store.listProblems('castel-bolognese');

      assert.deepEqual(
        {
          votesUp: suggestion.votesUp,
          votesDown: suggestion.votesDown,
          myVote: suggestion.myVote,
          status: suggestion.status,
        },
        { votesUp: 1, votesDown: 0, myVote: 'up', status: 'approved' },
      );
      assert.equal(
        problems.some((item) => item.id === `proposal_${created.id}`),
        true,
      );
    });

    it('applies concurrent retries with one idempotency key only once', async () => {
      const created = await store.submitNextProblem({
        idempotencyKey: 'postgres-submit-concurrent-0001',
        municipalityId: 'castel-bolognese',
        title: 'Voto concorrente retry safe',
        description: 'Una sola intenzione applicata nonostante due richieste.',
        category: 'safety',
        userId: 'user-concurrent-retry',
      });
      const input = {
        idempotencyKey: 'postgres-vote-concurrent-0001',
        municipalityId: 'castel-bolognese',
        problemId: created.id,
        vote: 'up',
        userId: 'user-concurrent-retry',
      };

      const [first, replay] = await Promise.all([
        store.voteNextProblem(input),
        store.voteNextProblem(input),
      ]);
      assert.deepEqual(replay, first);
      assert.equal(first.myVote, 'up');
      assert.equal(first.votesUp, 1);

      await assert.rejects(
        store.voteNextProblem({ ...input, vote: 'down' }),
        (error) =>
          error.statusCode === 409 &&
          error.code === 'idempotency_key_reused',
      );
      const records = await pool.query(
        `SELECT request_sha256, response_status, response_body
         FROM public.write_idempotency
         WHERE operation = 'vote_suggestion' AND idempotency_key = $1`,
        [input.idempotencyKey],
      );
      assert.equal(records.rowCount, 1);
      assert.equal(records.rows[0].response_status, 200);
      assert.equal(records.rows[0].response_body.myVote, 'up');
    });

    it('keeps one prediction choice under concurrent conflicting writes', async () => {
      const base = {
        turnId: 'turn-bologna-today',
        problemId: 'problem-green-margherita',
        userId: 'user-concurrent-prediction',
        motivations: [],
        confidence: null,
      };
      const outcomes = await Promise.allSettled([
        store.upsertPrediction({
          ...base,
          idempotencyKey: 'prediction-concurrent-improve-0001',
          choice: 'improve',
        }),
        store.upsertPrediction({
          ...base,
          idempotencyKey: 'prediction-concurrent-worsen-0001',
          choice: 'worsen',
        }),
      ]);
      const fulfilled = outcomes.filter((item) => item.status === 'fulfilled');
      const rejected = outcomes.filter((item) => item.status === 'rejected');

      assert.equal(fulfilled.length, 1);
      assert.equal(rejected.length, 1);
      assert.equal(rejected[0].reason.statusCode, 409);
      assert.ok(
        ['prediction_locked', 'write_conflict'].includes(
          rejected[0].reason.code,
        ),
      );
      const persisted = await store.getPredictions({
        turnId: base.turnId,
        userId: base.userId,
      });
      assert.equal(persisted.length, 1);
      assert.equal(persisted[0].choice, fulfilled[0].value.choice);
    });

    it('rolls back data and idempotency records after failure injection', async () => {
      const created = await store.submitNextProblem({
        idempotencyKey: 'failure-submit-key-0001',
        municipalityId: 'castel-bolognese',
        title: 'Failure injection voto',
        description: 'Il voto non deve lasciare side effect parziali.',
        category: 'green',
        userId: 'user-failure-injection',
      });
      const faultStore = createPostgresStore(pool, {
        logger: silentLogger,
        onWriteCheckpoint(checkpoint) {
          if (checkpoint === 'vote_after_vote_mutation') {
            throw new Error('injected vote failure');
          }
        },
      });
      const idempotencyKey = 'failure-vote-key-0001';

      await assert.rejects(
        faultStore.voteNextProblem({
          idempotencyKey,
          municipalityId: 'castel-bolognese',
          problemId: created.id,
          vote: 'up',
          userId: 'user-failure-injection',
        }),
        /injected vote failure/,
      );
      const persisted = await store.listNextProblems({
        municipalityId: 'castel-bolognese',
        userId: 'user-failure-injection',
      });
      const suggestion = persisted.find((item) => item.id === created.id);
      const record = await pool.query(
        `SELECT 1
         FROM public.write_idempotency
         WHERE operation = 'vote_suggestion' AND idempotency_key = $1`,
        [idempotencyKey],
      );

      assert.equal(suggestion.status, 'pending');
      assert.equal(suggestion.myVote, 'none');
      assert.equal(suggestion.votesUp, 0);
      assert.equal(record.rowCount, 0);
    });

    it('keeps HTTP response shapes compatible for persistent writes', async () => {
      const server = http.createServer(createApp({ store }));
      server.listen(0, '127.0.0.1');
      await once(server, 'listening');
      try {
        const address = server.address();
        assert.notEqual(typeof address, 'string');
        const baseUrl = `http://127.0.0.1:${address.port}`;
        const [activation, turn, suggestions, predictions, write] =
          await Promise.all([
            fetch(`${baseUrl}/v1/municipalities/bologna/activation`),
            fetch(`${baseUrl}/v1/municipalities/bologna/turn`),
            fetch(
              `${baseUrl}/v1/municipalities/bologna/next-problems?userId=demo-user`,
            ),
            fetch(
              `${baseUrl}/v1/turns/turn-bologna-today/predictions?userId=demo-user`,
            ),
            fetch(`${baseUrl}/v1/municipalities/bologna/next-problems`, {
              method: 'POST',
              headers: {
                'content-type': 'application/json',
                'idempotency-key': 'http-submit-key-0001',
              },
              body: JSON.stringify({
                title: 'Scrittura HTTP persistente',
                description: 'UC-02.3 salva la proposta nel database.',
                category: 'green',
              }),
            }),
          ]);

        assert.deepEqual(await activation.json(), {
          municipalityId: 'bologna',
          state: 'active',
        });
        assert.equal(typeof (await turn.json()).startAt, 'string');
        assert.equal(Array.isArray((await suggestions.json()).items), true);
        assert.equal(Array.isArray((await predictions.json()).items), true);
        assert.equal(write.status, 201);
        const created = await write.json();
        assert.equal(created.title, 'Scrittura HTTP persistente');

        const voted = await fetch(
          `${baseUrl}/v1/municipalities/bologna/next-problems/${created.id}/votes`,
          {
            method: 'POST',
            headers: {
              'content-type': 'application/json',
              'idempotency-key': 'http-vote-key-0001',
            },
            body: JSON.stringify({ vote: 'up', userId: 'user-http' }),
          },
        );
        assert.equal(voted.status, 200);
        assert.equal((await voted.json()).myVote, 'up');

        const prediction = await fetch(
          `${baseUrl}/v1/turns/turn-bologna-today/predictions/problem-green-margherita`,
          {
            method: 'PUT',
            headers: {
              'content-type': 'application/json',
              'idempotency-key': 'http-prediction-key-0001',
            },
            body: JSON.stringify({
              choice: 'improve',
              motivations: ['visibleActions'],
              confidence: 'considered',
              userId: 'user-http',
            }),
          },
        );
        assert.equal(prediction.status, 200);
        assert.equal((await prediction.json()).confidence, 'considered');
      } finally {
        await new Promise((resolve, reject) => {
          server.close((error) => (error ? reject(error) : resolve()));
        });
      }
    });

    it('serves sanitized persistent detail with uniform privacy errors and sanitized legacy replay', async () => {
      const server = http.createServer(createApp({ store }));
      server.listen(0, '127.0.0.1');
      await once(server, 'listening');
      const origin = `http://127.0.0.1:${server.address().port}`;
      const collection = '/v1/municipalities/castel-bolognese/next-problems';
      const request = async (path, { method = 'GET', body, key } = {}) => {
        const response = await fetch(origin + path, {
          method, headers: { ...(key ? { 'Idempotency-Key': key } : {}),
            ...(body ? { 'Content-Type': 'application/json' } : {}) },
          ...(body ? { body: JSON.stringify(body) } : {}),
        });
        return { status: response.status, body: await response.json() };
      };
      try {
        const input = { title: 'C2 dettaglio pubblico', description: 'Descrizione C2',
          category: 'green', userId: 'c2-private-owner',
          location: { kind: 'specific', label: 'Piazza delle Rose', reference: 'Ingresso nord' } };
        const created = await request(collection, { method: 'POST', body: input, key: 'c2-pg-create-key' });
        assert.equal(created.status, 201);
        assert.equal('submittedByUserId' in created.body, false);
        assert.equal(JSON.stringify(created.body).includes('c2-private-owner'), false);
        const detail = `${collection}/${created.body.id}`;
        assert.deepEqual(await request(detail), {status:200,body:created.body});
        const raw = await store.getNextProblem({ municipalityId:'castel-bolognese',
          problemId:created.body.id,userId:input.userId });
        assert.equal(raw.submittedByUserId,input.userId);
        const voted = await request(`${detail}/votes`, {method:'POST',
          body:{vote:'up',userId:input.userId},key:'c2-pg-vote-key'});
        assert.equal(voted.status,200);
        assert.equal(voted.body.status,'approved');
        assert.equal('submittedByUserId' in voted.body,false);
        assert.deepEqual((await request(`${detail}?userId=${input.userId}`)).body,voted.body);
        assert.deepEqual(voted.body.location,input.location);
        assert.equal(voted.body.createdAt,created.body.createdAt);
        const replay = await request(collection,{method:'POST',body:input,key:'c2-pg-create-key'});
        assert.deepEqual(replay,created);
        const missing = await request(`${collection}/does-not-exist`);
        assert.equal(missing.status,404);
        for (const municipality of ['bologna','missing']) {
          assert.deepEqual(await request(`/v1/municipalities/${municipality}/next-problems/${created.body.id}`),missing);
        }
        // Simulate a moderation state in the actual disposable database.
        await pool.query('UPDATE public.suggestions SET status = $2 WHERE id = $1',
          [created.body.id,'rejected']);
        assert.deepEqual(await request(`${detail}?userId=${input.userId}`),missing);
        const list = await request(collection);
        assert.equal(list.body.items.some(p=>p.id===created.body.id),false);
        assert.ok(list.body.items.every(p=>!('submittedByUserId' in p)));
        const rejectedFilter = await request(`${collection}?status=rejected&userId=${input.userId}`);
        assert.deepEqual(rejectedFilter,{status:200,body:{items:[]}});
        assert.deepEqual(await request(`${detail}/votes`,{method:'POST',
          body:{vote:'up',userId:input.userId},key:'c2-pg-vote-key'}),missing);
        await assert.rejects(store.voteNextProblem({municipalityId:'castel-bolognese',
          problemId:created.body.id,vote:'down',userId:input.userId,
          idempotencyKey:'c2-rejected-new-key'}),e=>e.statusCode===404);
        const votes = await pool.query('SELECT vote FROM public.suggestion_votes WHERE suggestion_id = $1',[created.body.id]);
        assert.deepEqual(votes.rows,[{vote:'up'}]);
        const blockedKey = await pool.query("SELECT 1 FROM public.write_idempotency WHERE idempotency_key = 'c2-rejected-new-key'");
        assert.equal(blockedKey.rowCount,0);
        const legacyInput = { municipalityId:'bologna',title:'Legacy replay',
          description:'Legacy description',category:'green',userId:'legacy-user' };
        const before = await pool.query("SELECT request_sha256, response_body FROM public.write_idempotency WHERE idempotency_key = 'legacy-record-key'");
        const legacy = await request('/v1/municipalities/bologna/next-problems',
          {method:'POST',body:legacyInput,key:'legacy-record-key'});
        assert.equal(legacy.status,201);
        assert.equal(legacy.body.id,'historical-proposal');
        assert.equal('submittedByUserId' in legacy.body,false);
        assert.equal(legacy.body.location,null);
        const after = await pool.query("SELECT request_sha256, response_body FROM public.write_idempotency WHERE idempotency_key = 'legacy-record-key'");
        assert.deepEqual(after.rows,before.rows);
      } finally {
        await new Promise((resolve,reject)=>server.close(e=>e?reject(e):resolve()));
      }
    });

    it('composes PostgreSQL explicitly at startup and closes its pool', async () => {
      const runtimePool = createPostgresPool(
        loadPostgresConfig({ env: { DATABASE_URL: databaseUrl } }),
        { logger: silentLogger },
      );
      const server = startServer({
        env: {
          DATA_STORE: 'postgres',
          DATABASE_URL: databaseUrl,
        },
        pool: runtimePool,
        logger: silentLogger,
        port: 0,
        host: '127.0.0.1',
      });
      await once(server, 'listening');
      const address = server.address();
      assert.notEqual(typeof address, 'string');
      const response = await fetch(
        `http://127.0.0.1:${address.port}/v1/municipalities/bologna/activation`,
      );
      assert.deepEqual(await response.json(), {
        municipalityId: 'bologna',
        state: 'active',
      });

      await new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
      await server.closeResources();
      await assert.rejects(
        runtimePool.query('SELECT 1'),
        /Cannot use a pool after calling end/,
      );
    });
  },
);

function assertDisposableTestDatabase(value) {
  const url = new URL(value);
  const databaseName = url.pathname.slice(1);
  if (!databaseName.endsWith('_test')) {
    throw new Error('TEST_DATABASE_URL must name a database ending in _test.');
  }
  if (!['127.0.0.1', 'localhost', '::1'].includes(url.hostname)) {
    throw new Error('PostgreSQL integration tests require a loopback database.');
  }
}

async function resetPublicSchema(value) {
  const client = new Client({ connectionString: value });
  await client.connect();
  try {
    await client.query('DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;');
  } finally {
    await client.end();
  }
}
