import assert from 'node:assert/strict';
import { it } from 'node:test';
import { readFileSync } from 'node:fs';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { once } from 'node:events';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { createApp, createMemoryStore, createPersistentStore, startServer } from '../src/server.js';
import { scoreFantasyCard } from '../src/fantasy/results.js';

const start = Date.parse('2026-10-08T00:00:00Z');
const end = Date.parse('2026-10-15T00:00:00Z');
const userId = 'anon:results-a';
function bodyFor(store, cardId, observed = 'stable') {
  const card = store.fantasy.cards('tuglie').items.find((card) => card.id === cardId);
  return { observed, sourceLabel: card.sourceLabel, sourceDate: new Date(end).toISOString(), sourceStatus: 'verified',
    explanation: 'Esito sintetico autorizzato', rulesVersion: 'fantasy-demo-v1', version: 1 };
}
function confirm(store, prediction = 'stable') {
  const first = store.fantasy.teams.team('tuglie', userId);
  const next = store.fantasy.teams.update('tuglie', userId, { expectedRevision: first.revision, matchdayId: first.matchdayId,
    starterIds: first.team.starterIds, captainId: first.team.captainId, predictions: Object.fromEntries(first.team.starterIds.map((id) => [id, prediction])), motivations: {} });
  return store.fantasy.teams.confirm('tuglie', userId, { expectedRevision: next.revision, matchdayId: next.matchdayId });
}
function publishAll(store, cards, observed = 'stable') {
  for (const id of cards) store.fantasy.results.publish('tuglie', 'matchday-1', id, bodyFor(store, id, observed));
}

it('matches all 48 shared Dart/Node score fixtures including captain rounding and reflection', () => {
  const fixtures = JSON.parse(readFileSync(new URL('../../../test/fixtures/fantasy_scoring.json', import.meta.url), 'utf8'));
  assert.equal(fixtures.length, 48);
  for (const fixture of fixtures) assert.deepEqual(scoreFantasyCard(fixture.input), fixture.expected, JSON.stringify(fixture.input));
});

it('freezes reveal points, distinguishes provisional/final and accepts each reflection only once', () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    store.fantasy.teams.enroll('tuglie', userId, {});
    const team = confirm(store);
    assert.throws(() => store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', { expectedRevision: team.revision, answer: 'observedIntervention' }), (e) => e.code === 'reflection_not_available');
    time = end;
    publishAll(store, ['buche-centro']);
    let result = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    assert.equal(result.summary.status, 'provisional');
    assert.equal(result.summary.total, 8);
    assert.equal(result.summary.cooperativeScore, null);
    assert.equal(result.summary.reflectionBonus, 0);
    const reflection = { expectedRevision: result.revision, answer: 'observedIntervention' };
    const reflected = store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', reflection);
    assert.equal(reflected.summary.total, 9);
    assert.equal(reflected.summary.frozenPoints, 8);
    assert.equal(reflected.summary.reflectionBonus, 1);
    assert.equal(store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', reflection).summary.total, 9);
    assert.throws(() => store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', { ...reflection, answer: 'externalConditions' }), (e) => e.code === 'reflection_immutable');
    publishAll(store, team.team.starterIds.filter((id) => id !== 'buche-centro'));
    result = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    assert.equal(result.summary.status, 'final');
    assert.equal(result.results.length, 5);
    assert.equal(result.summary.total, 29);
    const next = store.fantasy.teams.team('tuglie', userId);
    store.fantasy.teams.update('tuglie', userId, { expectedRevision: next.revision, matchdayId: next.matchdayId,
      starterIds: next.team.starterIds, captainId: 'bus-stazione', predictions: { 'buche-centro': 'worsens' }, motivations: {} });
    const history = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    assert.deepEqual(history.results, result.results);
    assert.deepEqual(history.summary, result.summary);
    time = start;
    assert.equal(store.fantasy.results.read('tuglie', userId, 'matchday-1').summary.status, 'final');
  } finally { store.close(); }
});

it('pending sources, reserves and unconfirmed snapshots cannot award personal points or reflection', () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    const first = store.fantasy.teams.enroll('tuglie', userId, {});
    const otherId = 'anon:unconfirmed';
    store.fantasy.teams.enroll('tuglie', otherId, {});
    const updated = store.fantasy.teams.update('tuglie', userId, { expectedRevision: first.revision, matchdayId: first.matchdayId,
      starterIds: first.team.starterIds.map((id) => id === 'parco-nord' ? 'alberi-viale' : id), captainId: first.team.captainId,
      predictions: {}, motivations: {} });
    store.fantasy.teams.confirm('tuglie', userId, { expectedRevision: updated.revision, matchdayId: updated.matchdayId });
    time = end;
    assert.throws(() => store.fantasy.results.publish('tuglie', 'matchday-1', 'alberi-viale', bodyFor(store, 'alberi-viale')), (e) => e.code === 'source_not_verified');
    publishAll(store, ['buche-centro', 'bus-stazione', 'lampioni-sud', 'rifiuti-mercato', 'sportello-anagrafe']);
    const result = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    assert.equal(result.summary.status, 'provisional');
    assert.equal(result.results.length, 4);
    assert.ok(result.outcomes.some((o) => o.cardId === 'sportello-anagrafe'));
    assert.ok(result.results.every((r) => r.cardId !== 'sportello-anagrafe'));
    for (const cardId of ['alberi-viale', 'sportello-anagrafe']) {
      assert.throws(() => store.fantasy.results.reflect('tuglie', userId, 'matchday-1', cardId, { expectedRevision: result.revision, answer: 'externalConditions' }), (e) => e.code === 'reflection_not_available');
    }
    const unconfirmed = store.fantasy.results.read('tuglie', otherId, 'matchday-1');
    assert.equal(unconfirmed.summary.total, 0);
    assert.equal(unconfirmed.summary.eligible, false);
    assert.equal(unconfirmed.summary.status, 'final');
    assert.deepEqual(unconfirmed.results, []);
  } finally { store.close(); }
});

it('published outcomes are versioned, source-validated, immutable and explicitly synthetic', () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    const body = bodyFor(store, 'buche-centro');
    assert.throws(() => store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', body), (e) => e.code === 'observation_pending');
    time = end;
    for (const changes of [{ sourceDate: '2026-10-09T00:00:00Z' }, { sourceDate: '2026-10-16T00:00:00Z' }, { sourceDate: '2026-10-15T00:00:00' }, { observed: 'unknown' }, { version: 2 }, { rulesVersion: 'future' }]) {
      assert.throws(() => store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', { ...body, ...changes }), (e) => e.code === 'invalid_field');
    }
    assert.throws(() => store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', { ...body, sourceLabel: 'Untrusted' }), (e) => e.code === 'source_not_verified');
    const first = store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', body);
    assert.equal(first.isDemo, true);
    assert.equal(first.outcome.isDemo, true);
    assert.equal(first.outcome.publisherRole, 'pilotModerator');
    assert.equal(first.outcome.version, 1);
    assert.deepEqual(store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', body), first);
    assert.throws(() => store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', { ...body, observed: 'improves' }), (e) => e.code === 'outcome_immutable');
  } finally { store.close(); }
});

it('allows a negative total and applies transfer penalties only once', () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  try {
    store.fantasy.teams.enroll('tuglie', userId, {});
    for (let i = 0; i < 4; i++) {
      const current = store.fantasy.teams.team('tuglie', userId);
      const quote = store.fantasy.market.quote('tuglie', userId, { expectedRevision: current.revision, matchdayId: current.matchdayId,
        outgoingId: i % 2 ? 'fontanelle-ovest' : 'parco-nord', incomingId: i % 2 ? 'parco-nord' : 'fontanelle-ovest' }).quote;
      store.fantasy.market.confirm('tuglie', userId, { expectedRevision: quote.expectedRevision, quoteId: quote.id, idempotencyKey: `negative-transfer-${i}` });
    }
    const team = confirm(store, 'improves');
    time = end;
    publishAll(store, team.team.starterIds, 'worsens');
    const result = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    assert.equal(result.summary.total, -8);
    assert.equal(result.summary.transferPenalty, 8);
    assert.deepEqual(store.fantasy.results.read('tuglie', userId, 'matchday-1').summary, result.summary);
  } finally { store.close(); }
});

it('persists results and reflections through restart and erases personal rows without erasing publications', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-results-restart-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let time = start, store;
  try {
    store = createPersistentStore({ databasePath, now: () => time });
    store.fantasy.teams.enroll('tuglie', userId, {});
    const team = confirm(store);
    time = end;
    publishAll(store, team.team.starterIds);
    const first = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    const reflected = store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', { expectedRevision: first.revision, answer: 'insufficientInformation' });
    store.close(); store = null;
    store = createPersistentStore({ databasePath, now: () => time });
    assert.deepEqual(store.fantasy.results.read('tuglie', userId, 'matchday-1'), reflected);
    store.deleteUserData(userId);
    assert.equal(store.fantasy.counts().reveals, 0);
    assert.equal(store.fantasy.counts().reflections, 0);
    assert.equal(store.fantasy.counts().finalizations, 0);
    assert.equal(store.fantasy.counts().outcomes, 5);
  } finally { store?.close(); await rm(directory, { recursive: true, force: true }); }
});

it('HTTP publication requires the administrator token; players can only reveal and reflect on their own results', async () => {
  let time = start;
  const store = createMemoryStore({ now: () => time });
  const token = 'fantasy-test-admin-token-32-characters';
  try {
    const app = createApp({ store, moderationAdminToken: token, pilotMunicipalityId: 'tuglie' });
    let cookie;
    async function request(path, method = 'GET', body, admin = false) {
      const req = Readable.from(body == null ? [] : [Buffer.from(JSON.stringify(body))]);
      Object.assign(req, { method, url: path, headers: { ...(cookie ? { cookie } : {}), ...(admin ? { authorization: `Bearer ${token}` } : {}) } });
      const res = { writeHead(status, headers) { this.status = status; this.headers = headers; }, end(data) { this.body = JSON.parse(data); } };
      await app(req, res);
      if (res.headers['set-cookie']) cookie = res.headers['set-cookie'].split(';')[0];
      return res;
    }
    const base = '/v1/fantasy/municipalities/tuglie';
    const enrolled = await request(`${base}/enrollment`, 'POST', {});
    await request(`${base}/team/confirmation`, 'POST', { expectedRevision: enrolled.body.revision, matchdayId: 'matchday-1' });
    time = end;
    const publishPath = '/v1/fantasy/admin/municipalities/tuglie/matchdays/matchday-1/outcomes/buche-centro';
    assert.equal((await request(publishPath, 'PUT', bodyFor(store, 'buche-centro'))).status, 401);
    assert.equal((await request(publishPath, 'PUT', bodyFor(store, 'buche-centro'), true)).status, 200);
    assert.equal((await request(publishPath.replace('tuglie', 'bologna'), 'PUT', bodyFor(store, 'buche-centro'), true)).status, 404);
    const revealed = await request(`${base}/matchdays/matchday-1/reveal`);
    assert.equal(revealed.status, 200);
    assert.equal(revealed.body.results.length, 1);
    assert.equal((await request(`${base}/matchdays/matchday-1/summary`)).status, 200);
    const reflected = await request(`${base}/matchdays/matchday-1/cards/buche-centro/reflection`, 'POST', { expectedRevision: revealed.body.revision, answer: 'observedIntervention' });
    assert.equal(reflected.status, 200);
    assert.equal(reflected.body.summary.reflectionBonus, 1);
  } finally { store.close(); }
});

it('administrator publication tool uses an authorized isolated fixture and prints no token or source text', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-admin-tool-'));
  const tokenPath = join(directory, 'test-token');
  const fixturePath = join(directory, 'outcome.json');
  const token = 'authorized-local-test-token-32-characters';
  const store = createMemoryStore({ now: () => end });
  const logs = [];
  const server = startServer({ port: 0, store, moderationAdminToken: token, logger: (line) => logs.push(line) });
  try {
    await once(server, 'listening');
    const fixture = { municipalityId: 'tuglie', matchdayId: 'matchday-1', cardId: 'buche-centro', outcome: bodyFor(store, 'buche-centro') };
    await writeFile(tokenPath, token);
    await writeFile(fixturePath, JSON.stringify(fixture));
    const { stdout, stderr } = await promisify(execFile)(process.execPath, ['scripts/publish_fantasy_outcome.js'], {
      cwd: new URL('..', import.meta.url),
      env: { ...process.env, API_BASE_URL: `http://127.0.0.1:${server.address().port}`, MODERATION_ADMIN_TOKEN_FILE: tokenPath, FANTASY_OUTCOME_FILE: fixturePath },
    });
    const output = JSON.parse(stdout.trim());
    assert.equal(output.event, 'fantasy_outcome_published');
    assert.equal(output.isDemo, true);
    assert.equal(store.fantasy.counts().outcomes, 1);
    for (const privateValue of [token, fixture.outcome.sourceLabel, fixture.outcome.explanation]) {
      assert.equal((stdout + stderr + logs.join('')).includes(privateValue), false);
    }
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    store.close(); await rm(directory, { recursive: true, force: true });
  }
});

it('a failed reflection insert leaves its bonus and team revision unchanged', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'fantasy-reflection-failure-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let store, database, time = start;
  try {
    store = createPersistentStore({ databasePath, now: () => time });
    store.fantasy.teams.enroll('tuglie', userId, {});
    const team = confirm(store);
    time = end;
    publishAll(store, team.team.starterIds);
    const before = store.fantasy.results.read('tuglie', userId, 'matchday-1');
    database = new DatabaseSync(databasePath);
    database.exec("CREATE TRIGGER fail_reflection BEFORE INSERT ON fantasy_reflections BEGIN SELECT RAISE(ABORT, 'injected reflection failure'); END;");
    assert.throws(() => store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', { expectedRevision: before.revision, answer: 'externalConditions' }), /injected reflection failure/);
    assert.deepEqual(store.fantasy.results.read('tuglie', userId, 'matchday-1'), before);
    assert.equal(store.fantasy.counts().reflections, 0);
  } finally { database?.close(); store?.close(); await rm(directory, { recursive: true, force: true }); }
});
