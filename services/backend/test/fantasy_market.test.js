import assert from 'node:assert/strict';
import { it } from 'node:test';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { Readable } from 'node:stream';
import { createApp, createMemoryStore, createPersistentStore } from '../src/server.js';

const start = Date.parse('2026-10-08T00:00:00Z');
const lock = Date.parse('2026-10-10T00:00:00Z');
const end = Date.parse('2026-10-15T00:00:00Z');
const userId = 'anon:market-a';
function quote(store, outgoingId = 'parco-nord', incomingId = 'fontanelle-ovest') {
  const team = store.fantasy.teams.team('tuglie', userId);
  return store.fantasy.market.quote('tuglie', userId, { expectedRevision: team.revision, matchdayId: team.matchdayId, outgoingId, incomingId }).quote;
}
function command(q, key = 'market-test-key-1') { return { quoteId: q.id, expectedRevision: q.expectedRevision, idempotencyKey: key }; }

it('third and fourth transfers cost four once, duplicate replies are identical, and allowance resets by day', () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    store.fantasy.teams.enroll('tuglie', userId, {});
    let accepted;
    for (let i = 0; i < 4; i++) {
      const q = quote(store, i % 2 ? 'fontanelle-ovest' : 'parco-nord', i % 2 ? 'parco-nord' : 'fontanelle-ovest');
      assert.equal(q.penalty, i < 2 ? 0 : 4);
      assert.equal(q.creditDelta, i % 2 ? -4 : 4);
      assert.equal(q.budgetAfter, i % 2 ? 15 : 19);
      const body = command(q, `market-test-key-${i}`);
      accepted = store.fantasy.market.confirm('tuglie', userId, body);
      assert.deepEqual(store.fantasy.market.confirm('tuglie', userId, body), accepted);
      assert.equal(accepted.transfers.length, i + 1);
      assert.equal(accepted.team.confirmed, false);
      assert.equal(accepted.transferPenalty, i < 2 ? 0 : (i - 1) * 4);
      assert.throws(() => store.fantasy.market.confirm('tuglie', userId, { ...body, quoteId: 'changed' }), (e) => e.code === 'idempotency_conflict');
    }
    time = lock;
    const frozen = store.fantasy.teams.team('tuglie', userId);
    assert.equal(frozen.snapshots[0].transferPenalty, 8);
    time = end;
    const next = store.fantasy.teams.team('tuglie', userId);
    assert.equal(next.transfersRemaining, 2);
    assert.equal(next.transferPenalty, 0);
    assert.equal(next.snapshots[0].transferPenalty, 8);
    assert.equal(quote(store).penalty, 0);
  } finally { store.close(); }
});

it('quotes are revision-bound, expired at the exact deadline, and transfers are refused at lock', () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    store.fantasy.teams.enroll('tuglie', userId, {});
    const stale = quote(store);
    store.fantasy.teams.confirm('tuglie', userId, { expectedRevision: 1, matchdayId: 'matchday-1' });
    assert.throws(() => store.fantasy.market.confirm('tuglie', userId, command(stale)), (e) => e.code === 'stale_revision');
    const expires = quote(store);
    time = Date.parse(expires.expiresAt);
    assert.throws(() => store.fantasy.market.confirm('tuglie', userId, command(expires)), (e) => e.code === 'quote_expired');
    const beforeLock = quote(store);
    time = lock;
    assert.throws(() => store.fantasy.market.confirm('tuglie', userId, command(beforeLock)), (e) => e.code === 'matchday_locked');
    assert.throws(() => quote(store), (e) => e.code === 'matchday_locked');
    assert.equal(store.fantasy.teams.team('tuglie', userId).transfers.length, 0);
  } finally { store.close(); }
});

it('failed transfers never consume credits or free allowance; pending sources are allowed', () => {
  const store = createMemoryStore({ now: () => start });
  try {
    const initial = store.fantasy.teams.enroll('tuglie', userId, {});
    for (const [outgoingId, incomingId] of [['missing', 'fontanelle-ovest'], ['parco-nord', 'missing'], ['parco-nord', 'buche-centro'], ['parco-nord', 'ciclabile-est'], ['lampioni-sud', 'fontanelle-ovest']]) {
      assert.throws(() => quote(store, outgoingId, incomingId));
      const team = store.fantasy.teams.team('tuglie', userId);
      assert.equal(team.revision, initial.revision);
      assert.equal(team.transfersRemaining, 2);
      assert.equal(team.team.budgetRemaining, 15);
    }
    const pending = quote(store, 'sportello-anagrafe', 'fermata-accessibile');
    const accepted = store.fantasy.market.confirm('tuglie', userId, command(pending));
    assert.equal(accepted.transfers.length, 1);
    assert.equal(accepted.team.budgetRemaining, 16);
  } finally { store.close(); }
});

it('retry after a lost reply and a restart returns the original command outcome even after lock', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-market-retry-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let store, time = start;
  try {
    store = createPersistentStore({ databasePath, now: () => time });
    store.fantasy.teams.enroll('tuglie', userId, {});
    const q = quote(store);
    const body = command(q);
    const accepted = store.fantasy.market.confirm('tuglie', userId, body);
    store.close(); store = null;
    time = lock;
    store = createPersistentStore({ databasePath, now: () => time });
    assert.deepEqual(store.fantasy.market.confirm('tuglie', userId, body), accepted);
    assert.equal(store.fantasy.counts().transfers, 1);
    assert.equal(store.fantasy.counts().transfer_commands, 1);
    store.deleteUserData(userId);
    assert.equal(store.fantasy.counts().quotes, 0);
    assert.equal(store.fantasy.counts().transfers, 0);
    assert.equal(store.fantasy.counts().transfer_commands, 0);
  } finally { store?.close(); await rm(directory, { recursive: true, force: true }); }
});

it('rechecks catalog version, availability, price, budget and role and rolls back a failed ledger commit', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-market-validation-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let store, database;
  try {
    store = createPersistentStore({ databasePath, now: () => start });
    store.fantasy.teams.enroll('tuglie', userId, {});
    database = new DatabaseSync(databasePath);
    const q = quote(store);
    database.exec("UPDATE fantasy_seasons SET catalog_version = 2 WHERE municipality_id = 'tuglie';");
    assert.throws(() => store.fantasy.market.confirm('tuglie', userId, command(q)), (e) => e.code === 'stale_quote');
    database.exec("UPDATE fantasy_seasons SET catalog_version = 1 WHERE municipality_id = 'tuglie';");
    for (const [column, value, expected] of [['availability', 'unavailable', 'card_unavailable'], ['source_status', 'unavailable', 'card_unavailable'], ['price', 200, 'invalid_squad'], ['role', 'mobility', 'stale_quote'], ['price', 9, 'stale_quote']]) {
      const original = database.prepare(`SELECT ${column} AS value FROM fantasy_cards WHERE season_id = ? AND id = ?`).get(q.seasonId, q.incomingId).value;
      database.prepare(`UPDATE fantasy_cards SET ${column} = ? WHERE season_id = ? AND id = ?`).run(value, q.seasonId, q.incomingId);
      assert.throws(() => store.fantasy.market.confirm('tuglie', userId, command(q)), (e) => e.code === expected);
      database.prepare(`UPDATE fantasy_cards SET ${column} = ? WHERE season_id = ? AND id = ?`).run(original, q.seasonId, q.incomingId);
      assert.equal(store.fantasy.counts().transfers, 0);
    }
    database.exec("CREATE TRIGGER fail_command BEFORE INSERT ON fantasy_transfer_commands BEGIN SELECT RAISE(ABORT, 'injected commit failure'); END;");
    assert.throws(() => store.fantasy.market.confirm('tuglie', userId, command(q)), /injected commit failure/);
    assert.equal(store.fantasy.counts().transfers, 0);
    assert.equal(store.fantasy.teams.team('tuglie', userId).team.budgetRemaining, 15);
    assert.equal(store.fantasy.teams.team('tuglie', userId).revision, 1);
    database.exec('DROP TRIGGER fail_command;');
    assert.equal(store.fantasy.market.confirm('tuglie', userId, command(q)).transfers.length, 1);
  } finally { database?.close(); store?.close(); await rm(directory, { recursive: true, force: true }); }
});

it('two concurrent confirmations cannot spend the same revision twice', async () => {
  const store = createMemoryStore({ now: () => start });
  try {
    store.fantasy.teams.enroll('tuglie', userId, {});
    const q1 = quote(store), q2 = quote(store);
    const results = await Promise.allSettled([
      Promise.resolve().then(() => store.fantasy.market.confirm('tuglie', userId, command(q1, 'concurrent-key-1'))),
      Promise.resolve().then(() => store.fantasy.market.confirm('tuglie', userId, command(q2, 'concurrent-key-2'))),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    assert.equal(results.find((r) => r.status === 'rejected').reason.code, 'stale_revision');
    assert.equal(store.fantasy.counts().transfers, 1);
  } finally { store.close(); }
});

it('HTTP quotes and confirmations use the signed session and deny another manager quote', async () => {
  const store = createMemoryStore({ now: () => start });
  try {
    const app = createApp({ store, pilotMunicipalityId: 'tuglie' });
    function client() {
      let cookie;
      return async (path, body) => {
        const req = Readable.from([Buffer.from(JSON.stringify(body))]);
        Object.assign(req, { method: 'POST', url: path, headers: cookie ? { cookie } : {} });
        const res = { writeHead(status, headers) { this.status = status; this.headers = headers; }, end(data) { this.body = JSON.parse(data); } };
        await app(req, res);
        if (res.headers['set-cookie']) cookie = res.headers['set-cookie'].split(';')[0];
        return res;
      };
    }
    const a = client(), b = client();
    const base = '/v1/fantasy/municipalities/tuglie';
    const first = await a(`${base}/enrollment`, {});
    await b(`${base}/enrollment`, {});
    const quoted = await a(`${base}/transfers/quote`, { expectedRevision: first.body.revision, matchdayId: first.body.matchdayId, outgoingId: 'parco-nord', incomingId: 'fontanelle-ovest' });
    assert.equal(quoted.status, 200);
    assert.equal((await b(`${base}/transfers/confirmation`, command(quoted.body.quote))).status, 404);
    const accepted = await a(`${base}/transfers/confirmation`, command(quoted.body.quote));
    assert.equal(accepted.status, 200);
    assert.deepEqual((await a(`${base}/transfers/confirmation`, command(quoted.body.quote))).body, accepted.body);
    assert.equal((await a('/v1/fantasy/municipalities/bologna/transfers/quote', {})).status, 404);
  } finally { store.close(); }
});
