import assert from 'node:assert/strict';
import { it } from 'node:test';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { Readable } from 'node:stream';
import { execFileSync } from 'node:child_process';

import { createApp, createMemoryStore, createPersistentStore } from '../src/server.js';
import { migrateFantasyResults } from '../src/fantasy/results.js';
import { migrateFantasyMarket } from '../src/fantasy/market.js';
import { migrateFantasyTeams } from '../src/fantasy/teams.js';
import { createFantasyStore, migrateFantasy, transaction } from '../src/fantasy/store.js';

async function request(app, url, method = 'GET', headers = {}) {
  const req = Readable.from([]);
  Object.assign(req, { url, method, headers });
  const res = { writeHead(status, headers) { this.status = status; this.headers = headers; },
    end(payload) { this.body = JSON.parse(payload); } };
  await app(req, res);
  return res;
}

it('serves a coherent versioned synthetic season, catalog and calendar with server UTC time', async () => {
  const time = Date.parse('2026-10-09T02:00:00+02:00');
  const store = createMemoryStore({ now: () => time });
  try {
    const app = createApp({ store });
    const base = '/v1/fantasy/municipalities/tuglie';
    const season = await request(app, `${base}/season`);
    const cards = await request(app, `${base}/cards`);
    const day = await request(app, `${base}/matchday`);
    const explicitDay = await request(app, `${base}/matchdays/matchday-1`);
    for (const result of [season, cards, day, explicitDay]) {
      assert.equal(result.status, 200);
      assert.equal(result.body.serverTime, '2026-10-09T00:00:00.000Z');
      assert.equal(result.body.isDemo, true);
    }
    assert.equal(season.body.season.municipalityId, 'tuglie');
    assert.equal(season.body.season.currentMatchday, 1);
    assert.equal(cards.body.seasonId, season.body.season.id);
    assert.equal(day.body.matchday.seasonId, season.body.season.id);
    assert.equal(cards.body.catalogVersion, 1);
    assert.equal(cards.body.items.length, 12);
    assert.deepEqual(new Set(cards.body.items.map((c) => c.role)), new Set(['mobility', 'environment', 'servicesAndSafety']));
    for (const card of cards.body.items) {
      assert.equal(card.version, 1);
      assert.equal(card.isDemo, true);
      assert.match(card.sourceLabel, /demo/);
      assert.ok(Number.isInteger(card.price));
    }
    assert.deepEqual(day.body, explicitDay.body);
    assert.equal(day.body.matchday.startsAt, '2026-10-08T00:00:00.000Z');
    assert.equal(day.body.matchday.locksAt, '2026-10-10T00:00:00.000Z');
    assert.equal(day.body.matchday.observationEndsAt, '2026-10-15T00:00:00.000Z');
    assert.equal(day.body.matchday.rulesVersion, 'fantasy-demo-v1');
    for (const path of ['unknown/season', 'tuglie/matchdays/missing']) {
      const response = await request(app, `/v1/fantasy/municipalities/${path}`);
      assert.equal(response.status, 404);
      assert.equal(response.body.error, 'not_found');
    }
    assert.equal((await request(app, `${base}/cards`, 'POST')).status, 404);
  } finally { store.close(); }
});

it('isolates pilot municipality and allows the same read routes in CORS preflight', async () => {
  const store = createMemoryStore();
  try {
    const app = createApp({ store, pilotMunicipalityId: 'tuglie' });
    for (const resource of ['season', 'cards', 'matchday', 'matchdays/matchday-1']) {
      assert.equal((await request(app, `/v1/fantasy/municipalities/bologna/${resource}`)).status, 404);
      assert.equal((await request(app, `/v1/fantasy/municipalities/comune%3ATuglie/${resource}`)).status, 200);
      const preflight = await request(app, `/v1/fantasy/municipalities/tuglie/${resource}`, 'OPTIONS',
        { origin: 'http://localhost:3000', 'access-control-request-method': 'GET' });
      assert.equal(preflight.status, 200);
    }
  } finally { store.close(); }
});

it('calendar handles timezone offsets and observation boundaries without season renewal', () => {
  let now = Date.parse('2026-10-14T23:59:59.999Z');
  const store = createFantasyStore({ now: () => now, seedStartsAt: '2026-10-08T02:00:00+02:00' });
  try {
    assert.equal(store.matchday('tuglie').matchday.number, 1);
    now++;
    assert.equal(store.matchday('tuglie').matchday.number, 2);
    now = Date.parse('2027-10-08T00:00:00Z');
    assert.equal(store.season('tuglie').season.status, 'ended');
    assert.equal(store.matchday('tuglie').matchday.number, 8);
    assert.deepEqual(store.counts(), { seasons: 3, cards: 36, matchdays: 24, players: 0, drafts: 0, snapshots: 0, quotes: 0, transfers: 0, transfer_commands: 0, outcomes: 0, reveals: 0, reflections: 0, finalizations: 0 });
  } finally { store.close(); }
  assert.throws(() => createFantasyStore({ seedStartsAt: '2026-10-08T00:00:00' }), /timezone/);
});

it('migrates a version 1 fixture additively, preserves exact legacy payload, and never reseeds on restart', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-migration-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let database;
  let store;
  try {
    const legacy = createMemoryStore();
    const payload = JSON.stringify(legacy.exportState());
    legacy.close();
    database = new DatabaseSync(databasePath);
    database.exec(`CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL) STRICT;
      INSERT INTO schema_migrations VALUES (1, '2026-01-01');
      CREATE TABLE app_state (id INTEGER PRIMARY KEY, revision INTEGER NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL) STRICT;`);
    database.prepare('INSERT INTO app_state VALUES (1, 7, ?, ?)').run(payload, '2026-01-01');
    database.close(); database = null;
    store = createPersistentStore({ databasePath, now: () => Date.parse('2026-10-09T00:00:00Z') });
    const firstDay = store.fantasy.matchday('tuglie', 'matchday-1').matchday;
    const firstCards = store.fantasy.cards('tuglie').items;
    assert.equal(store.isReady(), true);
    store.close(); store = null;
    database = new DatabaseSync(databasePath);
    assert.deepEqual(database.prepare('SELECT revision, payload, updated_at FROM app_state').get(),
      { __proto__: null, revision: 7, payload, updated_at: '2026-01-01' });
    database.close(); database = null;
    store = createPersistentStore({ databasePath, now: () => Date.parse('2027-10-09T00:00:00Z') });
    assert.deepEqual(store.fantasy.matchday('tuglie', 'matchday-1').matchday, firstDay);
    assert.deepEqual(store.fantasy.cards('tuglie').items, firstCards);
    assert.deepEqual(store.fantasy.counts(), { seasons: 3, cards: 36, matchdays: 24, players: 0, drafts: 0, snapshots: 0, quotes: 0, transfers: 0, transfer_commands: 0, outcomes: 0, reveals: 0, reflections: 0, finalizations: 0 });
    assert.equal(store.fantasy.season('tuglie').season.status, 'ended');
    store.close(); store = null;
    const output = execFileSync(process.execPath, ['scripts/verify_database.js'],
      { cwd: new URL('..', import.meta.url), env: { ...process.env, BACKUP_PATH: databasePath }, encoding: 'utf8' });
    assert.equal(JSON.parse(output).schemaVersion, 5);
  } finally {
    database?.close(); store?.close();
    await rm(directory, { recursive: true, force: true });
  }
});

it('rolls back all fantasy schema changes on failure and detects missing tables in readiness', () => {
  const database = new DatabaseSync(':memory:');
  try {
    assert.throws(() => transaction(database, () => { migrateFantasy(database); throw new Error('injected failure'); }), /injected failure/);
    assert.equal(database.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE name LIKE 'fantasy_%'").get().count, 0);
    migrateFantasy(database);
    migrateFantasyTeams(database);
    migrateFantasyMarket(database);
    migrateFantasyResults(database);
    const store = createFantasyStore({ database });
    assert.equal(store.isReady(), true);
    assert.throws(() => transaction(database, () => {
      database.prepare('UPDATE fantasy_cards SET price = 999 WHERE id = ?').run('buche-centro');
      database.prepare('UPDATE fantasy_cards SET price = -1 WHERE id = ?').run('parco-nord');
    }));
    assert.equal(store.cards('tuglie').items.find((c) => c.id === 'buche-centro').price, 13);
    database.exec('DROP TABLE fantasy_cards;');
    assert.throws(() => store.isReady(), /fantasy_cards/);
  } finally { database.close(); }
});

it('backup and isolated restore preserve the full fantasy catalog and calendar', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-backup-'));
  const sourcePath = join(directory, 'source.sqlite');
  const backupPath = join(directory, 'backup.sqlite');
  let store;
  try {
    store = createPersistentStore({ databasePath: sourcePath });
    const day = store.fantasy.matchday('tuglie', 'matchday-1').matchday;
    const cards = store.fantasy.cards('tuglie').items;
    execFileSync(process.execPath, ['scripts/backup.js'], {
      cwd: new URL('..', import.meta.url),
      env: { ...process.env, DATABASE_PATH: sourcePath, BACKUP_PATH: backupPath },
    });
    const restored = createPersistentStore({ databasePath: backupPath });
    try {
      assert.deepEqual(restored.fantasy.matchday('tuglie', 'matchday-1').matchday, day);
      assert.deepEqual(restored.fantasy.cards('tuglie').items, cards);
      assert.equal(restored.isReady(), true);
    } finally { restored.close(); }
    const rehearsal = execFileSync(process.execPath, ['scripts/rehearse_restore.js'], {
      cwd: new URL('..', import.meta.url), env: { ...process.env, BACKUP_PATH: backupPath }, encoding: 'utf8',
    });
    assert.deepEqual(JSON.parse(rehearsal).fantasy, { seasons: 3, cards: 36, matchdays: 24, players: 0, drafts: 0, snapshots: 0, quotes: 0, transfers: 0, transfer_commands: 0, outcomes: 0, reveals: 0, reflections: 0, finalizations: 0 });
    const damaged = new DatabaseSync(sourcePath);
    damaged.exec('DROP TABLE fantasy_cards;');
    damaged.close();
    const response = await request(createApp({ store }), '/ready');
    assert.equal(response.status, 503);
    assert.equal(response.body.error, 'service_unavailable');
  } finally {
    store?.close();
    await rm(directory, { recursive: true, force: true });
  }
});
