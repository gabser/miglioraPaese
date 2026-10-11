import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { after, before, describe, it } from 'node:test';
import pg from 'pg';
import { createApp } from '../src/http/app.js';
import { createMemoryStore } from '../src/infrastructure/memory-store.js';
import { createPostgresStore } from '../src/persistence/postgres/postgres-store.js';
import { runPostgresMigrations } from '../src/persistence/postgres/migrator.js';
import { seedPostgres } from '../src/persistence/postgres/seed.js';

const base = '/v1/municipalities/bologna/next-problems';
const body = { title: 'Alberi', description: 'Serve ombra', category: 'green',
  userId: 'attacker-chosen-id', location: { kind: 'municipality' } };
const logger = { info() {}, warn() {}, debug() {}, error() {} };
const databaseUrl = process.env.TEST_DATABASE_URL;
let pool;

async function request(app, path, { method = 'GET', body, key, token } = {}) {
  const req = Readable.from(body === undefined ? [] : [Buffer.from(JSON.stringify(body))]);
  Object.assign(req, { method, url: path, headers: {
    ...(key ? { 'idempotency-key': key } : {}),
    ...(token ? { authorization: 'Bearer ' + token } : {}),
  }});
  let status, payload, headers;
  await app(req, { writeHead(value, fields) { status = value; headers = fields; },
    end(value) { payload = JSON.parse(value); } });
  return { status, body: payload, headers };
}

function sessionContract(makeStore) {
  it('uses distinct server scopes, overrides client identity and isolates keys by session and municipality', async () => {
    const store = makeStore();
    const app = createApp({ store });
    const a = await request(app, '/v1/proposal-session', { method: 'POST' });
    const b = await request(app, '/v1/proposal-session', { method: 'POST' });
    assert.equal(a.status, 201);
    assert.match(a.body.token, /^[A-Za-z0-9_-]{43}$/);
    assert.notEqual(a.body.token, b.body.token);
    assert.notEqual(a.body.submissionScope, b.body.submissionScope);
    assert.equal(a.headers['cache-control'], 'no-store');
    const token = a.body.token;
    const active = await request(app, '/v1/proposal-session', { token });
    assert.equal(active.status, 200);
    assert.equal(active.body.token, undefined);
    assert.equal(active.body.capabilities.scopedIdempotency, true);
    const key = 'same-intent-key';
    const created = await request(app, base, { method: 'POST', body, key, token });
    assert.equal(created.status, 201);
    const internal = await store.getNextProblem({ municipalityId: 'bologna', problemId: created.body.id });
    assert.equal(internal.submittedByUserId, 'session:' + a.body.submissionScope);
    const lookup = '/v1/municipalities/bologna/submissions/' + key;
    const recovered = await request(app, lookup, { token });
    assert.equal(recovered.status, 200);
    assert.deepEqual(recovered.body, created.body);
    assert.equal(recovered.headers['cache-control'], 'no-store');
    assert.equal((await request(app, lookup, { token: b.body.token })).status, 404);
    assert.equal((await request(app, lookup)).status, 401);
    assert.equal((await request(app, '/v1/municipalities/castel-bolognese/submissions/' + key, { token })).status, 404);
    const ownPath = base + '/' + created.body.id + '/own';
    assert.equal((await request(app, ownPath, { token })).status, 200);
    assert.equal((await request(app, ownPath + '?userId=' + internal.submittedByUserId, { token: b.body.token })).status, 404);
    const replay = await request(app, base, { method: 'POST', body: { ...body, userId: 'another-client-id' }, key, token });
    assert.equal(replay.status, 201);
    assert.deepEqual(replay.body, created.body);
    assert.equal((await request(app, base, { method: 'POST', body: { ...body, title: 'Different' }, key, token })).status, 409);
    const otherSession = await request(app, base, { method: 'POST', body, key, token: b.body.token });
    assert.equal(otherSession.status, 201);
    assert.notEqual(otherSession.body.id, created.body.id);
    const otherTown = await request(app, '/v1/municipalities/castel-bolognese/next-problems', { method: 'POST', body, key, token });
    assert.equal(otherTown.status, 201);
    assert.notEqual(otherTown.body.id, created.body.id);
    const aliasReplay = await request(app, '/v1/municipalities/comune%3ABologna/next-problems', { method: 'POST', body, key, token });
    assert.deepEqual(aliasReplay.body, created.body);
  });

  it('personalizes public reads and votes from the bearer identity rather than query/body userId', async () => {
    const store = makeStore();
    const app = createApp({ store });
    const owner = await store.createProposalSession();
    const stranger = await store.createProposalSession();
    const created = await request(app, base, { method: 'POST', body, key: 'session-vote-create', token: owner.token });
    const detail = base + '/' + created.body.id;
    const voted = await request(app, detail + '/votes', { method: 'POST', body: { vote: 'up', userId: 'forged-vote-owner' }, key: 'session-vote-key', token: owner.token });
    assert.equal(voted.status, 200);
    assert.equal(voted.body.myVote, 'up');
    const actual = await request(app, detail + '?userId=forged-vote-owner', { token: owner.token });
    assert.equal(actual.body.myVote, 'up');
    const other = await request(app, detail + '?userId=session:' + owner.submissionScope, { token: stranger.token });
    assert.equal(other.body.myVote, 'none');
    const list = await request(app, base + '?userId=forged-vote-owner', { token: owner.token });
    assert.equal(list.body.items.find(value => value.id === created.body.id).myVote, 'up');
  });

  it('revokes private reads and writes including cached replay, while preserving public proposals', async () => {
    const store = makeStore();
    const app = createApp({ store });
    const { token } = await store.createProposalSession();
    const key = 'revoke-intent-key';
    const created = await request(app, base, { method: 'POST', body, key, token });
    assert.equal(created.status, 201);
    for (let repeat = 0; repeat < 2; repeat++) {
      assert.equal((await request(app, '/v1/proposal-session/revoke', { method: 'POST', token })).status, 200);
    }
    for (const path of ['/v1/proposal-session', base + '/' + created.body.id + '/own',
      '/v1/municipalities/bologna/submissions/' + key]) {
      assert.equal((await request(app, path, { token })).status, 401);
    }
    assert.equal((await request(app, base, { method: 'POST', body, key, token })).status, 401);
    assert.equal((await request(app, base, { method: 'POST', body, key: 'brand-new-key', token })).status, 401);
    assert.equal((await request(app, base + '/' + created.body.id)).status, 200);
  });
}

describe('proposal session memory HTTP contract', () => sessionContract(() => createMemoryStore()));

describe('proposal session PostgreSQL contract', { skip: !databaseUrl }, () => {
  before(async () => {
    const url = new URL(databaseUrl);
    assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname));
    assert.match(url.pathname, /_test$/);
    pool = new pg.Pool({ connectionString: databaseUrl });
    await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public');
    await runPostgresMigrations({ databaseUrl, attestationDatabaseUrl: databaseUrl,
      sourceCommit: 'proposal-session-test', artifactDigest: 'sha256:' + 'a'.repeat(64), logger });
    await seedPostgres(pool, { profile: 'local', logger });
  });
  after(async () => {
    if (pool) {
      await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public');
      await pool.end();
    }
  });
  sessionContract(() => createPostgresStore(pool, { logger }));

  it('returns rejected proposals only to their real session owner and keeps lookup as the acceptance snapshot', async () => {
    const store = createPostgresStore(pool, { logger });
    const app = createApp({ store });
    const owner = await store.createProposalSession();
    const stranger = await store.createProposalSession();
    const key = 'rejected-own-key';
    const accepted = await request(app, base, { method: 'POST', body, key, token: owner.token });
    await pool.query("UPDATE public.suggestions SET status='rejected' WHERE id=$1", [accepted.body.id]);
    const detail = base + '/' + accepted.body.id;
    assert.equal((await request(app, detail)).status, 404);
    const own = await request(app, detail + '/own', { token: owner.token });
    assert.equal(own.status, 200);
    assert.equal(own.body.status, 'rejected');
    assert.equal(own.body.submittedByUserId, undefined);
    assert.equal((await request(app, detail + '/own?userId=session:' + owner.submissionScope, { token: stranger.token })).status, 404);
    const recovered = await request(app, '/v1/municipalities/bologna/submissions/' + key, { token: owner.token });
    assert.deepEqual(recovered.body, accepted.body);
    const publicList = await request(app, base);
    assert.equal(publicList.body.items.some(value => value.id === accepted.body.id), false);
  });

  it('rolls back proposal and cached response together, keeping the same scope usable', async () => {
    const store = createPostgresStore(pool, { logger, onWriteCheckpoint: async name => {
      if (name === 'submit_after_insert') throw new Error('Injected response loss before commit');
    }});
    const { token } = await store.createProposalSession();
    const input = { ...body, municipalityId: 'bologna', sessionToken: token, idempotencyKey: 'rollback-key-1' };
    await assert.rejects(store.submitNextProblem(input), /Injected response loss/);
    await assert.rejects(store.lookupSubmission(input), e => e.statusCode === 404);
    const rows = await pool.query('SELECT count(*)::integer AS count FROM public.suggestions WHERE submitted_by_user_id LIKE $1', ['session:%']);
    const before = rows.rows[0].count;
    const good = createPostgresStore(pool, { logger });
    const value = await good.submitNextProblem(input);
    assert.equal((await good.lookupSubmission(input)).id, value.id);
    const after = await pool.query('SELECT count(*)::integer AS count FROM public.suggestions WHERE submitted_by_user_id LIKE $1', ['session:%']);
    assert.equal(after.rows[0].count, before + 1);
  });

  it('serializes revocation after an in-flight commit, then rejects subsequent replay and writes', async () => {
    let entered, release;
    const locked = new Promise(resolve => { entered = resolve; });
    const barrier = new Promise(resolve => { release = resolve; });
    const store = createPostgresStore(pool, { logger, onWriteCheckpoint: async name => {
      if (name === 'proposal_session_locked') { entered(); await barrier; }
    }});
    const session = await store.createProposalSession();
    const input = { ...body, municipalityId: 'bologna', sessionToken: session.token, idempotencyKey: 'race-intent-key' };
    const submitting = store.submitNextProblem(input);
    await locked;
    const revoking = store.revokeProposalSession(session.token);
    let waitObserved = false;
    try {
      for (let attempt = 0; attempt < 100; attempt++) {
        const rows = await pool.query("SELECT count(*)::integer AS count FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock' AND query LIKE '%UPDATE public.proposal_sessions%'");
        if (rows.rows[0].count > 0) { waitObserved = true; break; }
        await new Promise(resolve => setTimeout(resolve, 5));
      }
      assert.equal(waitObserved, true, 'Revocation must wait on the actual session row lock');
    } finally { release(); }
    const created = await submitting;
    await revoking;
    await assert.rejects(store.submitNextProblem(input), e => e.statusCode === 401);
    await assert.rejects(store.lookupSubmission(input), e => e.statusCode === 401);
    const recreated = createPostgresStore(pool, { logger });
    await assert.rejects(recreated.getProposalSession(session.token), e => e.statusCode === 401);
    assert.equal((await recreated.getNextProblem({ municipalityId: 'bologna', problemId: created.id })).id, created.id);
    const hashes = await pool.query('SELECT token_hash::text FROM public.proposal_sessions');
    assert.ok(hashes.rows.every(row => /^[0-9a-f]{64}$/.test(row.token_hash)));
    assert.ok(hashes.rows.every(row => row.token_hash !== session.token));
  });
});
