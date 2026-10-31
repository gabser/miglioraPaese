import { createApp } from '../src/server.js';
import { createTestStore as createMemoryStore, createTestFantasy as createFantasyStore, client } from './helpers/fantasy.js';
import { scoreFantasyCard } from '../src/domain/fantasy/scoring.js';
import assert from 'node:assert/strict';
import { integrationTest as it } from './helpers/fantasy.js';
import { Readable } from 'node:stream';

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
  const store = (await createMemoryStore({ now: () => time }));
  try {
    const app = createApp({ fantasy:store.fantasy, store });
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
  } finally { (await store.close()); }
});

it('isolates pilot municipality and allows the same read routes in CORS preflight', async () => {
  const store = (await createMemoryStore());
  try {
    const app = createApp({ fantasy:store.fantasy, store, pilotMunicipalityId: 'tuglie' });
    for (const resource of ['season', 'cards', 'matchday', 'matchdays/matchday-1']) {
      assert.equal((await request(app, `/v1/fantasy/municipalities/bologna/${resource}`)).status, 404);
      assert.equal((await request(app, `/v1/fantasy/municipalities/comune%3ATuglie/${resource}`)).status, 200);
      const preflight = await request(app, `/v1/fantasy/municipalities/tuglie/${resource}`, 'OPTIONS',
        { origin: 'http://localhost:3000', 'access-control-request-method': 'GET' });
      assert.equal(preflight.status, 200);
    }
  } finally { (await store.close()); }
});

it('calendar handles timezone offsets and observation boundaries without season renewal', async () => {
  let now = Date.parse('2026-10-14T23:59:59.999Z');
  const store = (await createFantasyStore({ now: () => now, seedStartsAt: '2026-10-08T02:00:00+02:00' }));
  try {
    assert.equal((await store.matchday('tuglie')).matchday.number, 1);
    now++;
    assert.equal((await store.matchday('tuglie')).matchday.number, 2);
    now = Date.parse('2027-10-08T00:00:00Z');
    assert.equal((await store.season('tuglie')).season.status, 'ended');
    assert.equal((await store.matchday('tuglie')).matchday.number, 8);
    assert.deepEqual((await store.counts()), { seasons: 3, cards: 36, matchdays: 24, players: 0, drafts: 0, snapshots: 0, quotes: 0, transfers: 0, transfer_commands: 0, outcomes: 0, reveals: 0, reflections: 0, finalizations: 0, leagues: 0, members: 0, invites: 0, invite_attempts: 0 });
  } finally { (await store.close()); }
  await assert.rejects(async () => (await createFantasyStore({ seedStartsAt: '2026-10-08T00:00:00' })), /timezone/);
});
