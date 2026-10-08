import assert from 'node:assert/strict';
import { it } from 'node:test';
import { Readable } from 'node:stream';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createApp, createMemoryStore, createPersistentStore } from '../src/server.js';

const base = '/v1/fantasy/municipalities/tuglie';
const start = Date.parse('2026-10-08T00:00:00Z');
const lock = Date.parse('2026-10-10T00:00:00Z');
const end = Date.parse('2026-10-15T00:00:00Z');

function client(app) {
  let cookie;
  return async (path, method = 'GET', body) => {
    const req = Readable.from(body === undefined ? [] : [Buffer.from(JSON.stringify(body))]);
    Object.assign(req, { url: path, method, headers: cookie ? { cookie } : {} });
    const res = { writeHead(status, headers) { this.status = status; this.headers = headers; },
      end(payload) { this.body = JSON.parse(payload); } };
    await app(req, res);
    if (res.headers['set-cookie']) cookie = res.headers['set-cookie'].split(';')[0];
    return res;
  };
}
function draft(team, changes = {}) {
  return { expectedRevision: team.revision, matchdayId: team.matchdayId,
    starterIds: team.team.starterIds, captainId: team.team.captainId,
    predictions: team.team.predictions, motivations: team.team.motivations, ...changes };
}

it('enrolls idempotently, isolates signed sessions and rejects body-supplied identities', async () => {
  const store = createMemoryStore({ now: () => start });
  try {
    const app = createApp({ store, pilotMunicipalityId: 'tuglie' });
    const a = client(app), b = client(app);
    assert.equal((await a(`${base}/team`)).status, 404);
    const first = await a(`${base}/enrollment`, 'POST', {});
    assert.equal(first.status, 200);
    assert.equal(first.body.team.squadIds.length, 8);
    assert.equal(first.body.team.budgetRemaining, 15);
    const again = await a(`${base}/enrollment`, 'POST', {});
    assert.deepEqual(again.body, first.body);
    assert.equal((await b(`${base}/team`)).status, 404);
    const second = await b(`${base}/enrollment`, 'POST', {});
    const updated = await a(`${base}/team`, 'PUT', draft(first.body, { predictions: { 'buche-centro': 'improves' }, motivations: { 'buche-centro': 'Segnale sintetico' } }));
    assert.equal(updated.status, 200);
    assert.equal(updated.body.revision, 2);
    assert.deepEqual((await b(`${base}/team`)).body.team.predictions, {});
    assert.equal((await a(`${base}/team`, 'PUT', { ...draft(updated.body), userId: 'spoof' })).status, 400);
    assert.equal((await a('/v1/fantasy/municipalities/bologna/enrollment', 'POST', {})).status, 404);
    assert.equal(second.body.revision, 1);
  } finally { store.close(); }
});

it('validates roster, budget, roles, predictions and revision without consuming a revision on failure', async () => {
  const store = createMemoryStore({ now: () => start });
  try {
    const api = client(createApp({ store }));
    for (const squadIds of [[], Array(8).fill('buche-centro'), ['unknown']]) {
      assert.equal((await api(`${base}/enrollment`, 'POST', { squadIds })).status, 400);
    }
    const first = (await api(`${base}/enrollment`, 'POST', {})).body;
    for (const fields of [
      { starterIds: ['buche-centro'] },
      { starterIds: ['buche-centro', 'bus-stazione', 'attraversamenti-scuole', 'parco-nord', 'rifiuti-mercato'] },
      { captainId: 'sportello-anagrafe' }, { predictions: { 'alberi-viale': 'stable' } },
      { predictions: { 'buche-centro': 'unknown' } }, { motivations: { 'buche-centro': 'x'.repeat(1001) } },
      { expectedRevision: -1 }, { matchdayId: 'missing' },
    ]) {
      const result = await api(`${base}/team`, 'PUT', draft(first, fields));
      assert.ok([400, 404].includes(result.status), JSON.stringify(result.body));
      assert.equal((await api(`${base}/team`)).body.revision, 1);
    }
    const updated = await api(`${base}/team`, 'PUT', draft(first, { captainId: 'bus-stazione' }));
    assert.equal(updated.status, 200);
    const stale = await api(`${base}/team`, 'PUT', draft(first));
    assert.equal(stale.status, 409);
    assert.equal(stale.body.error, 'stale_revision');
    const confirmed = await api(`${base}/team/confirmation`, 'POST', { expectedRevision: 2, matchdayId: 'matchday-1' });
    assert.equal(confirmed.body.team.confirmed, true);
    const edited = await api(`${base}/team`, 'PUT', draft(confirmed.body, { captainId: 'lampioni-sud' }));
    assert.equal(edited.body.team.confirmed, false);
  } finally { store.close(); }
});

for (const offset of [-1, 0, 1]) {
  it(`enforces server lock at ${offset}ms for every team mutation and freezes last accepted state`, async () => {
    let time = start;
    const store = createMemoryStore({ now: () => time });
    try {
      const api = client(createApp({ store }));
      let team = (await api(`${base}/enrollment`, 'POST', {})).body;
      team = (await api(`${base}/team`, 'PUT', draft(team, { predictions: { 'buche-centro': 'stable' } }))).body;
      team = (await api(`${base}/team/confirmation`, 'POST', { expectedRevision: team.revision, matchdayId: team.matchdayId })).body;
      time = lock + offset;
      const update = await api(`${base}/team`, 'PUT', draft(team, { predictions: { 'buche-centro': 'worsens' } }));
      if (offset < 0) {
        assert.equal(update.status, 200);
        assert.equal(update.body.snapshots.length, 0);
      } else {
        assert.equal(update.status, 409);
        assert.equal(update.body.error, 'matchday_locked');
        const confirmed = await api(`${base}/team/confirmation`, 'POST', { expectedRevision: team.revision, matchdayId: team.matchdayId });
        assert.equal(confirmed.status, 409);
        const current = (await api(`${base}/team`)).body;
        assert.equal(current.snapshots.length, 1);
        assert.equal(current.snapshots[0].eligible, true);
        assert.deepEqual(current.snapshots[0].predictions, { 'buche-centro': 'stable' });
        assert.equal(current.team.predictions['buche-centro'], 'stable');
        time = end;
        const next = (await api(`${base}/team`)).body;
        assert.equal(next.matchdayId, 'matchday-2');
        assert.equal(next.team.confirmed, false);
        assert.deepEqual(next.team.predictions, {});
        const changed = await api(`${base}/team`, 'PUT', draft(next, { predictions: { 'buche-centro': 'improves' } }));
        assert.equal(changed.status, 200);
        assert.deepEqual(changed.body.snapshots, current.snapshots);
      }
    } finally { store.close(); }
  });
}

it('unconfirmed and late enrollment snapshots are ineligible, and two tabs cannot overwrite each other', async () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    const app = createApp({ store });
    const api = client(app), late = client(app);
    const first = (await api(`${base}/enrollment`, 'POST', {})).body;
    const writes = await Promise.all([
      api(`${base}/team`, 'PUT', draft(first, { captainId: 'bus-stazione' })),
      api(`${base}/team`, 'PUT', draft(first, { captainId: 'lampioni-sud' })),
    ]);
    assert.deepEqual(writes.map((r) => r.status).sort(), [200, 409]);
    time = lock;
    assert.equal((await api(`${base}/team`)).body.snapshots[0].eligible, false);
    const joinedLate = await late(`${base}/enrollment`, 'POST', {});
    assert.equal(joinedLate.body.snapshots[0].eligible, false);
    assert.equal((await late(`${base}/team/confirmation`, 'POST', { expectedRevision: 1, matchdayId: 'matchday-1' })).status, 409);
  } finally { store.close(); }
});

it('recovers a lock missed while the process was stopped and erases all personal fantasy data on restart', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-lock-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let time = start;
  let store;
  try {
    store = createPersistentStore({ databasePath, now: () => time });
    const first = store.fantasy.teams.enroll('tuglie', 'anon:test-a', {});
    store.fantasy.teams.confirm('tuglie', 'anon:test-a', { expectedRevision: first.revision, matchdayId: first.matchdayId });
    store.fantasy.teams.enroll('tuglie', 'anon:test-b', {});
    store.close(); store = null;
    time = lock;
    store = createPersistentStore({ databasePath, now: () => time });
    const frozen = store.fantasy.teams.team('tuglie', 'anon:test-a');
    assert.equal(frozen.snapshots[0].eligible, true);
    store.deleteUserData('anon:test-a');
    assert.throws(() => store.fantasy.teams.team('tuglie', 'anon:test-a'), /enrollment/);
    assert.equal(store.fantasy.teams.team('tuglie', 'anon:test-b').snapshots[0].eligible, false);
    store.close(); store = null;
    store = createPersistentStore({ databasePath, now: () => time });
    assert.equal(store.fantasy.counts().players, 1);
    assert.equal(store.fantasy.counts().drafts, 1);
    assert.equal(store.fantasy.counts().snapshots, 1);
  } finally { store?.close(); await rm(directory, { recursive: true, force: true }); }
});

it('session erasure rolls back both SQLite stores and in-memory legacy state when a delete fails', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-erasure-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let store, database;
  try {
    store = createPersistentStore({ databasePath, now: () => start });
    const userId = 'anon:test-a';
    store.upsertPrediction({ turnId: 'turn-bologna-today', problemId: 'problem-green-margherita', userId, choice: 'improve', motivations: [], confidence: null });
    store.fantasy.teams.enroll('tuglie', userId, {});
    const before = structuredClone(store.exportState());
    database = new DatabaseSync(databasePath);
    database.exec("CREATE TRIGGER fail_fantasy_delete BEFORE DELETE ON fantasy_players BEGIN SELECT RAISE(ABORT, 'injected delete failure'); END;");
    assert.throws(() => store.deleteUserData(userId), /injected delete failure/);
    assert.deepEqual(store.exportState(), before);
    assert.equal(store.fantasy.counts().players, 1);
    assert.deepEqual(JSON.parse(database.prepare('SELECT payload FROM app_state WHERE id = 1').get().payload), before);
    database.exec('DROP TRIGGER fail_fantasy_delete;');
    store.deleteUserData(userId);
    assert.equal(store.fantasy.counts().players, 0);
    assert.equal(store.fantasy.counts().drafts, 0);
    assert.equal(store.fantasy.counts().snapshots, 0);
    assert.equal(store.getPredictions({ turnId: 'turn-bologna-today', userId }).length, 0);
  } finally { database?.close(); store?.close(); await rm(directory, { recursive: true, force: true }); }
});

it('signed-session HTTP deletion isolates the other team and expires the cookie', async () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    const app = createApp({ store });
    const a = client(app), b = client(app);
    await a(`${base}/enrollment`, 'POST', {});
    await b(`${base}/enrollment`, 'POST', {});
    time = lock;
    await a(`${base}/team`);
    const erased = await a('/v1/session', 'DELETE');
    assert.equal(erased.status, 200);
    assert.match(erased.headers['set-cookie'], /Max-Age=0/);
    assert.equal((await a(`${base}/team`)).status, 404);
    assert.equal((await b(`${base}/team`)).body.snapshots.length, 1);
    assert.equal(store.fantasy.counts().players, 1);
  } finally { store.close(); }
});

it('a frozen day stays locked after clock rollback, and client time cannot unlock it', async () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    const api = client(createApp({ store }));
    const first = (await api(`${base}/enrollment`, 'POST', {})).body;
    time = lock;
    const frozen = (await api(`${base}/team?clientTime=2020-01-01`)).body;
    time = start;
    assert.equal((await api(`${base}/team`, 'PUT', draft(first))).body.error, 'matchday_locked');
    assert.deepEqual((await api(`${base}/team`)).body.snapshots, frozen.snapshots);
    time = end + 100 * 24 * 60 * 60 * 1000;
    const newcomer = client(createApp({ store }));
    assert.equal((await newcomer(`${base}/enrollment`, 'POST', {})).body.error, 'season_ended');
  } finally { store.close(); }
});

it('failed team writes roll back the draft and revision together', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-draft-failure-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let store, database;
  try {
    store = createPersistentStore({ databasePath, now: () => start });
    const first = store.fantasy.teams.enroll('tuglie', 'anon:test-a', {});
    database = new DatabaseSync(databasePath);
    database.exec("CREATE TRIGGER fail_draft BEFORE UPDATE ON fantasy_drafts BEGIN SELECT RAISE(ABORT, 'injected write failure'); END;");
    assert.throws(() => store.fantasy.teams.update('tuglie', 'anon:test-a', draft(first, { captainId: 'bus-stazione' })), /injected write failure/);
    assert.deepEqual(store.fantasy.teams.team('tuglie', 'anon:test-a'), first);
    database.exec('DROP TRIGGER fail_draft;');
    const accepted = store.fantasy.teams.update('tuglie', 'anon:test-a', draft(first, { captainId: 'bus-stazione' }));
    assert.equal(accepted.revision, first.revision + 1);
    assert.equal(accepted.team.captainId, 'bus-stazione');
  } finally { database?.close(); store?.close(); await rm(directory, { recursive: true, force: true }); }
});
