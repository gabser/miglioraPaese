import assert from 'node:assert/strict';
import { once } from 'node:events';
import { readFileSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { PassThrough, Readable } from 'node:stream';
import { DatabaseSync } from 'node:sqlite';
import { it } from 'node:test';
import { createApp, createMemoryStore, createPersistentStore, startServer } from '../src/server.js';
const base = '/v1/municipalities/castel-bolognese';
const input = { title: 'Potatura alberi', description: 'I rami invadono il passaggio pedonale.', category: 'green', location: { kind: 'specific', label: 'Via Milano' }, idempotencyKey: 'submission_key_01' };
const cookieOf = (r) => r.headers['set-cookie']?.split(';')[0];
async function request(app, path, { method = 'GET', body, cookie, req: supplied, loseResponse = false } = {}) {
  const req = supplied ?? Readable.from(body ? [Buffer.from(JSON.stringify(body))] : []);
  Object.assign(req, { method, url: path, headers: cookie ? { cookie } : {} });
  const res = { statusCode: 0, headers: {}, payload: '', writeHead(status, headers) { this.statusCode = status; this.headers = headers; }, end(payload) { this.payload = loseResponse ? '' : payload; } };
  await app(req, res);
  return { status: res.statusCode, headers: res.headers, body: res.payload ? JSON.parse(res.payload) : null };
}
it('real HTTP bootstrap, private receipt, replay and manual location survive SQLite restart', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'mp-proposal-http-'));
  let server, cookie, receipt, scope;
  try {
    for (let iteration = 0; iteration < 2; iteration++) {
      server = startServer({ host: '127.0.0.1', port: 0, databasePath: join(directory, 'pilot.sqlite'), moderationRequired: true });
      await once(server, 'listening');
      const origin = `http://127.0.0.1:${server.address().port}`;
      const initialResponse = await fetch(origin + base + '/next-problems?own=true', { headers: cookie ? { cookie } : {} });
      cookie ??= initialResponse.headers.get('set-cookie').split(';')[0];
      const initial = await initialResponse.json(); scope ??= initial.submissionScope;
      assert.equal(initial.submissionScope, scope); assert.deepEqual(initial.capabilities, { proposalSubmission: 1 }); assert.equal(initial.items.length, iteration);
      const post = await fetch(origin + base + '/next-problems', { method: 'POST', headers: { cookie }, body: JSON.stringify(input) });
      assert.equal(post.status, iteration ? 200 : 201);
      const posted = await post.json(); receipt ??= posted; assert.deepEqual(posted, receipt);
      assert.equal(posted.submissionScope, scope); assert.equal(posted.isMine, true); assert.equal(posted.municipalityId, 'castel-bolognese'); assert.deepEqual(posted.location, input.location);
      const detail = await fetch(origin + base + '/next-problems/' + posted.id, { headers: { cookie } }); assert.deepEqual((await detail.json()).location, input.location);
      const lookup = await fetch(origin + base + '/next-problem-submissions/' + input.idempotencyKey, { headers: { cookie } }); assert.deepEqual(await lookup.json(), { submissionScope: scope, receipt });
      await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve())); server = null;
    }
  } finally { if (server) await new Promise((resolve) => server.close(resolve)); await rm(directory, { recursive: true, force: true }); }
});
it('concurrent identical commands converge, lost response recovers, replay precedes quota/moderation', async () => {
  const store = createMemoryStore({ moderationRequired: true }), app = createApp({ store });
  const bootstrap = await request(app, base + '/next-problems?own=true'), cookie = cookieOf(bootstrap);
  const attempts = await Promise.all([request(app, base + '/next-problems', { method: 'POST', body: input, cookie, loseResponse: true }), request(app, base + '/next-problems', { method: 'POST', body: input, cookie })]);
  assert.deepEqual(attempts.map((r) => r.status), [201, 200]); const receipt = attempts[1].body;
  for (let n = 2; n <= 3; n++) assert.equal((await request(app, base + '/next-problems', { method: 'POST', body: { ...input, idempotencyKey: 'submission_key_0' + n, location: { kind: 'specific', label: n === 2 ? 'Via Roma' : 'Via Milano' } }, cookie })).status, 201);
  assert.equal((await request(app, base + '/next-problems', { method: 'POST', body: { ...input, idempotencyKey: 'submission_key_04' }, cookie })).status, 429);
  const replay = await request(app, base + '/next-problems', { method: 'POST', body: { ...input, title: ' Potatura alberi ', location: { label: ' Via Milano ', kind: 'specific', civic: '' } }, cookie }); assert.equal(replay.status, 200); assert.deepEqual(replay.body, receipt);
  const conflict = await request(app, base + '/next-problems', { method: 'POST', body: { ...input, description: 'www.example.invalid' }, cookie }); assert.equal(conflict.status, 409); assert.equal(conflict.body.error, 'idempotency_conflict');
  assert.deepEqual((await request(app, base + '/next-problem-submissions/' + input.idempotencyKey, { cookie })).body.receipt, receipt);
  assert.equal(store.exportState().submissionCommands.length, 3); assert.equal(store.exportState().suggestedProblems.filter((x) => x.problem.title === input.title).length, 3);
});
it('own, public, detail, votes and immutable receipts enforce privacy, identity and municipality scope', async () => {
  const store = createMemoryStore({ moderationRequired: true }), app = createApp({ store });
  const a = await request(app, base + '/next-problems?own=true'), b = await request(app, base + '/next-problems?own=true'); const cookie = cookieOf(a), other = cookieOf(b);
  assert.notEqual(a.body.submissionScope, b.body.submissionScope); assert.equal(a.body.submissionScope.includes('anon:'), false);
  const created = await request(app, base + '/next-problems', { method: 'POST', cookie, body: { ...input, userId: 'spoofed-user', submissionScope: b.body.submissionScope } }); assert.equal(created.body.submissionScope, a.body.submissionScope); assert.equal('submittedByUserId' in created.body, false);
  const internal = store.exportState().suggestedProblems.find((x) => x.problem.id === created.body.id).problem;
  store.moderateNextProblem({ municipalityId: 'castel-bolognese', problemId: internal.id, status: 'rejected', reason: 'Internal operator comment' });
  const detail = await request(app, base + '/next-problems/' + internal.id, { cookie }); assert.equal(detail.status, 200); assert.equal(detail.body.status, 'rejected'); assert.equal('moderationReason' in detail.body, false); assert.equal('submittedByUserId' in detail.body, false);
  assert.equal((await request(app, base + '/next-problems/' + internal.id, { cookie: other })).status, 404);
  assert.equal((await request(app, base + '/next-problems/' + internal.id + '/votes', { method: 'POST', cookie: other, body: { vote: 'up' } })).status, 404);
  assert.equal((await request(app, base + '/next-problems', { cookie })).body.items.some((x) => x.id === internal.id), false);
  assert.equal((await request(app, base + '/next-problems?own=true', { cookie })).body.items[0].id, internal.id);
  assert.equal((await request(app, base + '/next-problems?own=true', { cookie: other })).body.items.length, 0);
  assert.equal((await request(app, '/v1/municipalities/bologna/next-problems/' + internal.id, { cookie })).status, 404);
  for (const [path, who] of [[base, other], ['/v1/municipalities/bologna', cookie]]) { const unavailable = await request(app, path + '/next-problem-submissions/' + input.idempotencyKey, { cookie: who }); assert.equal(unavailable.status, 404); assert.equal(unavailable.body.error, 'submission_not_found'); assert.equal(typeof unavailable.body.submissionScope, 'string'); }
  assert.deepEqual((await request(app, base + '/next-problem-submissions/' + input.idempotencyKey, { cookie })).body.receipt, created.body);
  assert.deepEqual((await request(app, base + '/next-problems', { method: 'POST', body: input, cookie })).body, created.body);
});
it('reset revokes an authenticated POST paused in body read and stays revoked after SQLite restart', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'mp-proposal-reset-')); const databasePath = join(directory, 'pilot.sqlite'); let store;
  try {
    store = createPersistentStore({ databasePath }); let app = createApp({ store });
    const bootstrap = await request(app, base + '/next-problems?own=true'), cookie = cookieOf(bootstrap), paused = new PassThrough();
    const pending = request(app, base + '/next-problems', { method: 'POST', req: paused, cookie }); // resolves identity synchronously before awaiting stream
    assert.equal((await request(app, '/v1/session', { method: 'DELETE', cookie })).status, 200); paused.end(JSON.stringify(input));
    const late = await pending; assert.equal(late.status, 401); assert.equal(late.body.error, 'session_revoked');
    assert.equal(store.exportState().submissionCommands.length, 0); assert.equal(store.exportState().suggestedProblems.some((x) => x.problem.title === input.title), false);
    store.close(); store = createPersistentStore({ databasePath }); app = createApp({ store });
    assert.equal((await request(app, base + '/next-problems', { method: 'POST', body: input, cookie })).status, 401);
    const renewed = await request(app, base + '/next-problems?own=true', { cookie }); assert.notEqual(renewed.body.submissionScope, bootstrap.body.submissionScope); assert.notEqual(cookieOf(renewed), cookie); assert.equal(renewed.body.items.length, 0); assert.equal(store.exportState().revokedSessions.length, 1);
  } finally { store?.close(); await rm(directory, { recursive: true, force: true }); }
});
it('POST before reset is anonymized, receipt erased and old key cannot recreate it', async () => {
  const store = createMemoryStore(), app = createApp({ store }); const cookie = cookieOf(await request(app, base + '/next-problems?own=true'));
  const post = await request(app, base + '/next-problems', { method: 'POST', cookie, body: input }); assert.equal(post.status, 201);
  assert.equal((await request(app, '/v1/session', { method: 'DELETE', cookie })).status, 200); assert.equal((await request(app, base + '/next-problems', { method: 'POST', cookie, body: input })).status, 401);
  assert.equal(store.exportState().submissionCommands.length, 0); const remaining = store.exportState().suggestedProblems.filter((x) => x.problem.id === post.body.id); assert.equal(remaining.length, 1); assert.equal(remaining[0].problem.submittedByUserId, 'deleted');
});
it('SQLite save failure rolls back proposal, receipt, counter and failed reset revocation in memory and DB', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'mp-proposal-fault-')), databasePath = join(directory, 'pilot.sqlite'); let store, database;
  try {
    store = createPersistentStore({ databasePath }); const app = createApp({ store }), cookie = cookieOf(await request(app, base + '/next-problems?own=true')); database = new DatabaseSync(databasePath); const before = store.exportState();
    const fail = () => database.exec("CREATE TRIGGER fail_snapshot BEFORE UPDATE ON app_state BEGIN SELECT RAISE(ABORT, 'injected failure'); END;"); const heal = () => database.exec('DROP TRIGGER fail_snapshot;'); const disk = () => JSON.parse(database.prepare('SELECT payload FROM app_state').get().payload);
    fail(); assert.equal((await request(app, base + '/next-problems', { method: 'POST', body: input, cookie })).status, 500); assert.deepEqual(store.exportState(), before); assert.deepEqual(disk(), before); assert.equal((await request(app, base + '/next-problem-submissions/' + input.idempotencyKey, { cookie })).status, 404); heal();
    const successful = await request(app, base + '/next-problems', { method: 'POST', body: input, cookie }); assert.equal(successful.status, 201); assert.equal(successful.body.id, 'suggested-' + before.nextProblemCounter); const committed = store.exportState();
    fail(); assert.equal((await request(app, '/v1/session', { method: 'DELETE', cookie })).status, 500); assert.deepEqual(store.exportState(), committed); assert.deepEqual(disk(), committed); heal(); database.close(); database = null; store.close();
    store = createPersistentStore({ databasePath }); const afterRestart = await request(createApp({ store }), base + '/next-problems', { method: 'POST', body: input, cookie }); assert.equal(afterRestart.status, 200); assert.deepEqual(afterRestart.body, successful.body); assert.equal(store.persistence.schemaVersion, 6); assert.equal(store.exportState().schemaVersion, 1);
  } finally { database?.close(); store?.close(); await rm(directory, { recursive: true, force: true }); }
});
it('legacy snapshot and requests without/null location and key preserve IDs, votes, states and dates', async () => {
  const legacy = createMemoryStore().exportState(); delete legacy.submissionCommands; delete legacy.revokedSessions;
  const store = createMemoryStore({ initialState: legacy }); assert.deepEqual(store.exportState().suggestedProblems, legacy.suggestedProblems); const app = createApp({ store }); const bootstrap = await request(app, base + '/next-problems'); assert.equal(bootstrap.body.items.every((x) => x.location === null), true); const cookie = cookieOf(bootstrap);
  for (const extra of [{}, { location: null, idempotencyKey: null }]) { const { location, idempotencyKey, ...old } = input; const result = await request(app, base + '/next-problems', { method: 'POST', body: { ...old, ...extra }, cookie }); assert.equal(result.status, 201); assert.equal(result.body.location, null); }
  assert.equal(store.exportState().submissionCommands.length, 0); const bad = structuredClone(store.exportState()); bad.submissionCommands = [{ key: 'invalid' }]; assert.throws(() => createMemoryStore({ initialState: bad }), /command is invalid/);
});
it('Unicode code point limits after trim and place moderation accept civic 12/A and Via 8 Marzo', async () => {
  for (const [field, limit] of [['title', 120], ['description', 1000], ['label', 120], ['civic', 20], ['reference', 200]]) for (const count of [limit - 1, limit, limit + 1]) {
    const text = '  ' + '🌳'.repeat(count) + '  ', payload = { ...input, location: { ...input.location } }; const top = ['title', 'description'].includes(field); if (top) payload[field] = text; else payload.location[field] = text;
    const result = await request(createApp(), base + '/next-problems', { method: 'POST', body: payload }); assert.equal(result.status, count > limit ? 400 : 201, `${field} ${count}`);
    if (count > limit) assert.deepEqual(result.body.fieldErrors, { [top ? field : 'location.' + field]: 'too_long' }); else assert.equal(top ? result.body[field === 'description' ? 'shortDescription' : 'title'] : result.body.location[field], text.trim());
  }
  for (const title of ['è'.repeat(120), 'e\u0301'.repeat(60), '👩‍👩‍👧‍👦'.repeat(17) + 'a']) { const r = await request(createApp(), base + '/next-problems', { method: 'POST', body: { ...input, title } }); assert.equal(r.status, 201); assert.equal(r.body.title, title); }
  for (const location of [{ kind: 'municipality' }, { kind: 'specific', label: 'Via 8 Marzo', civic: '12/A', reference: 'Tratto fra il parco e Via 9 Novembre' }, { kind: 'specific', label: 'Parco Nord' }, { kind: 'specific', label: 'Via Milano / Via Roma' }]) { const r = await request(createApp(), base + '/next-problems', { method: 'POST', body: { ...input, location } }); assert.equal(r.status, 201); assert.deepEqual(r.body.location, location); }
  for (const location of [{ kind: 'municipality', label: 'Hidden old address' }, { kind: 'specific', label: ' ' }, { kind: 'specific', label: 'Via Milano', civic: 12 }, { kind: 'unknown' }, []]) assert.equal((await request(createApp(), base + '/next-problems', { method: 'POST', body: { ...input, location } })).status, 400);
  for (const field of ['label', 'civic', 'reference']) for (const value of ['www.example.it', 'user@example.it', '+39 333 123 4567', 'coglione', 'abc\u0000']) { const r = await request(createApp(), base + '/next-problems', { method: 'POST', body: { ...input, location: { ...input.location, [field]: value } } }); assert.equal(r.status, 422, `${field}:${value}`); assert.equal(r.body.error, 'content_rejected'); assert.equal('reason' in r.body, false); }
  for (const idempotencyKey of ['short', 'a'.repeat(129), 'bad key ', '🌳'.repeat(8)]) assert.equal((await request(createApp(), base + '/next-problems', { method: 'POST', body: { ...input, idempotencyKey } })).status, 400);
});
it('quota counts rejected, excludes invalid commands, includes hour boundary and separates sessions/municipalities', () => {
  let clock = Date.parse('2026-10-09T12:00:00Z'); const store = createMemoryStore({ now: () => clock, moderationRequired: true }); const command = { ...input, municipalityId: 'castel-bolognese', userId: 'anon:quota-test' };
  for (let i = 0; i < 3; i++) { const p = store.submitNextProblem({ ...command, idempotencyKey: 'quota-key-' + i }); store.moderateNextProblem({ municipalityId: command.municipalityId, problemId: p.id, status: 'rejected' }); }
  clock += 60 * 60 * 1000; assert.throws(() => store.submitNextProblem({ ...command, idempotencyKey: 'quota-key-next' }), (e) => e.statusCode === 429); assert.equal(store.submitNextProblem({ ...command, idempotencyKey: 'quota-key-0' }).status, 'pending');
  assert.equal(store.submitNextProblem({ ...command, municipalityId: 'bologna' }).municipalityId, 'bologna'); assert.equal(store.submitNextProblem({ ...command, userId: 'anon:another-session' }).isMine, true);
  clock += 1; assert.equal(store.submitNextProblem({ ...command, idempotencyKey: 'quota-key-next' }).status, 'pending'); assert.throws(() => store.submitNextProblem({ ...command, description: 'www.example.invalid', idempotencyKey: 'invalid-key' }), (e) => e.statusCode === 422); assert.throws(() => store.submitNextProblem({ ...command, title: '', idempotencyKey: 'invalid-key' }), (e) => e.statusCode === 400); assert.equal(store.submitNextProblem({ ...command, idempotencyKey: 'quota-final-key' }).status, 'pending');
});

it('scope precondition rejects cookie changes between bootstrap and POST without commit or quota', async () => {
  const store = createMemoryStore(), app = createApp({ store });
  const a = await request(app, base + '/next-problems?own=true'), b = await request(app, base + '/next-problems?own=true');
  const before = store.exportState();
  const mismatch = await request(app, base + '/next-problems', { method: 'POST', cookie: cookieOf(b), body: { ...input, expectedSubmissionScope: a.body.submissionScope } });
  assert.equal(mismatch.status, 409); assert.equal(mismatch.body.error, 'submission_scope_changed'); assert.deepEqual(store.exportState(), before);
  const accepted = await request(app, base + '/next-problems', { method: 'POST', cookie: cookieOf(b), body: { ...input, expectedSubmissionScope: b.body.submissionScope } });
  assert.equal(accepted.status, 201);
  const wrongReplay = await request(app, base + '/next-problems', { method: 'POST', cookie: cookieOf(b), body: { ...input, expectedSubmissionScope: a.body.submissionScope } });
  assert.equal(wrongReplay.status, 409); assert.equal(store.exportState().submissionCommands.length, 1);
});

it('shared Dart/Node corpus passes real POST code point boundaries and normalization', async () => {
  const corpus = JSON.parse(readFileSync(new URL('../../../test/fixtures/proposal_text_boundaries.json', import.meta.url), 'utf8'));
  for (const sample of corpus.samples) {
    // The checked-in count is the independent oracle shared with Dart.
    assert.equal(Array.from(sample.text.trim()).length, sample.count);
    const result = await request(createApp(), base + '/next-problems', { method: 'POST', body: { ...input, title: sample.text } });
    assert.equal(result.status, 201); assert.equal(result.body.title, sample.text.trim());
  }
  for (const boundary of corpus.boundaries) {
    const value = '  ' + boundary.unit.repeat(boundary.repeat) + '  ';
    assert.equal(Array.from(value.trim()).length, boundary.count);
    const top = ['title', 'description'].includes(boundary.field);
    const payload = { ...input, location: { ...input.location } };
    if (top) payload[boundary.field] = value; else payload.location[boundary.field] = value;
    const result = await request(createApp(), base + '/next-problems', { method: 'POST', body: payload });
    assert.equal(result.status, boundary.valid ? 201 : 400);
    if (boundary.valid) assert.equal(top ? result.body[boundary.field === 'description' ? 'shortDescription' : 'title'] : result.body.location[boundary.field], value.trim());
    else assert.deepEqual(result.body.fieldErrors, { [top ? boundary.field : 'location.' + boundary.field]: 'too_long' });
  }
});
it('configured pilot supports proposal detail, lookup and canonical alias but excludes other towns', async () => {
  const app = createApp({ pilotMunicipalityId: 'tuglie' });
  const path = '/v1/municipalities/tuglie';
  const bootstrap = await request(app, path + '/next-problems?own=true'), cookie = cookieOf(bootstrap);
  const created = await request(app, path + '/next-problems', { method: 'POST', cookie, body: { ...input, expectedSubmissionScope: bootstrap.body.submissionScope } });
  assert.equal(created.status, 201);
  const alias = '/v1/municipalities/comune%3ATuglie';
  assert.equal((await request(app, alias + '/next-problems/' + created.body.id, { cookie })).status, 200);
  assert.equal((await request(app, alias + '/next-problem-submissions/' + input.idempotencyKey, { cookie })).status, 200);
  assert.equal((await request(app, base + '/next-problems/' + created.body.id, { cookie })).status, 404);
  assert.equal((await request(app, '/v1/session', { method: 'DELETE', cookie })).status, 200);
  assert.equal((await request(app, '/v1/session', { method: 'DELETE', cookie })).status, 200);
});

it('promotion keeps the full manual place including civic and reference, and legacy fallback', () => {
  for (const [location, expected] of [
    [{ kind: 'specific', label: 'Via Milano', civic: '12/A', reference: 'Tratto davanti al parco' }, 'Via Milano · 12/A · Tratto davanti al parco'],
    [{ kind: 'municipality' }, 'Intero Comune'],
    [null, 'Tema scelto dai cittadini'],
  ]) {
    const store = createMemoryStore();
    const proposal = store.submitNextProblem({ ...input, municipalityId: 'castel-bolognese', userId: 'anon:promotion', location });
    store.voteNextProblem({ municipalityId: 'castel-bolognese', userId: 'anon:promotion', problemId: proposal.id, vote: 'up' });
    assert.equal(store.listProblems('castel-bolognese').find((item) => item.id === 'proposal_' + proposal.id).zoneName, expected);
  }
});
