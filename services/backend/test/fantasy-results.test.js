import { createApp } from '../src/server.js';
import { createTestStore as createMemoryStore, createTestFantasy as createFantasyStore, client } from './helpers/fantasy.js';
import { scoreFantasyCard } from '../src/domain/fantasy/scoring.js';
import assert from 'node:assert/strict';
import { integrationTest as it } from './helpers/fantasy.js';
import { readFileSync } from 'node:fs';
import { once } from 'node:events';
import { promisify } from 'node:util';
import { Readable } from 'node:stream';

const start = Date.parse('2026-10-08T00:00:00Z');
const end = Date.parse('2026-10-15T00:00:00Z');
const userId = 'anon:results-a';
async function bodyFor(store, cardId, observed = 'stable') {
  const card = (await store.fantasy.cards('tuglie')).items.find((card) => card.id === cardId);
  return { observed, sourceLabel: card.sourceLabel, sourceDate: new Date(end).toISOString(), sourceStatus: 'verified',
    explanation: 'Esito sintetico autorizzato', rulesVersion: 'fantasy-demo-v1', version: 1 };
}
async function confirm(store, prediction = 'stable') {
  const first = (await store.fantasy.teams.team('tuglie', userId));
  const next = (await store.fantasy.teams.update('tuglie', userId, { expectedRevision: first.revision, matchdayId: first.matchdayId,
    starterIds: first.team.starterIds, captainId: first.team.captainId, predictions: Object.fromEntries(first.team.starterIds.map((id) => [id, prediction])), motivations: {} }));
  return (await store.fantasy.teams.confirm('tuglie', userId, { expectedRevision: next.revision, matchdayId: next.matchdayId }));
}
async function publishAll(store, cards, observed = 'stable') {
  for (const id of cards) (await store.fantasy.results.publish('tuglie', 'matchday-1', id, (await bodyFor(store, id, observed))));
}

it('matches all 48 shared Dart/Node score fixtures including captain rounding and reflection', async () => {
  const fixtures = JSON.parse(readFileSync(new URL('./fixtures/fantasy_scoring.json', import.meta.url), 'utf8'));
  assert.equal(fixtures.length, 48);
  for (const fixture of fixtures) assert.deepEqual(scoreFantasyCard(fixture.input), fixture.expected, JSON.stringify(fixture.input));
});

it('freezes reveal points, distinguishes provisional/final and accepts each reflection only once', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    (await store.fantasy.teams.enroll('tuglie', userId, {}));
    const team = (await confirm(store));
    await assert.rejects(async () => (await store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', { expectedRevision: team.revision, answer: 'observedIntervention' })), (e) => e.code === 'reflection_not_available');
    time = end;
    (await publishAll(store, ['buche-centro']));
    let result = (await store.fantasy.results.read('tuglie', userId, 'matchday-1'));
    assert.equal(result.summary.status, 'provisional');
    assert.equal(result.summary.total, 8);
    assert.equal(result.summary.cooperativeScore, null);
    assert.equal(result.summary.reflectionBonus, 0);
    const reflection = { expectedRevision: result.revision, answer: 'observedIntervention' };
    const reflected = (await store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', reflection));
    assert.equal(reflected.summary.total, 9);
    assert.equal(reflected.summary.frozenPoints, 8);
    assert.equal(reflected.summary.reflectionBonus, 1);
    assert.equal((await store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', reflection)).summary.total, 9);
    await assert.rejects(async () => (await store.fantasy.results.reflect('tuglie', userId, 'matchday-1', 'buche-centro', { ...reflection, answer: 'externalConditions' })), (e) => e.code === 'reflection_immutable');
    (await publishAll(store, team.team.starterIds.filter((id) => id !== 'buche-centro')));
    result = (await store.fantasy.results.read('tuglie', userId, 'matchday-1'));
    assert.equal(result.summary.status, 'final');
    assert.equal(result.results.length, 5);
    assert.equal(result.summary.total, 29);
    const next = (await store.fantasy.teams.team('tuglie', userId));
    (await store.fantasy.teams.update('tuglie', userId, { expectedRevision: next.revision, matchdayId: next.matchdayId,
      starterIds: next.team.starterIds, captainId: 'bus-stazione', predictions: { 'buche-centro': 'worsens' }, motivations: {} }));
    const history = (await store.fantasy.results.read('tuglie', userId, 'matchday-1'));
    assert.deepEqual(history.results, result.results);
    assert.deepEqual(history.summary, result.summary);
    time = start;
    assert.equal((await store.fantasy.results.read('tuglie', userId, 'matchday-1')).summary.status, 'final');
  } finally { (await store.close()); }
});

it('pending sources, reserves and unconfirmed snapshots cannot award personal points or reflection', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    const first = (await store.fantasy.teams.enroll('tuglie', userId, {}));
    const otherId = 'anon:unconfirmed';
    (await store.fantasy.teams.enroll('tuglie', otherId, {}));
    const updated = (await store.fantasy.teams.update('tuglie', userId, { expectedRevision: first.revision, matchdayId: first.matchdayId,
      starterIds: first.team.starterIds.map((id) => id === 'parco-nord' ? 'alberi-viale' : id), captainId: first.team.captainId,
      predictions: {}, motivations: {} }));
    (await store.fantasy.teams.confirm('tuglie', userId, { expectedRevision: updated.revision, matchdayId: updated.matchdayId }));
    time = end;
    await assert.rejects(async () => (await store.fantasy.results.publish('tuglie', 'matchday-1', 'alberi-viale', (await bodyFor(store, 'alberi-viale')))), (e) => e.code === 'source_not_verified');
    (await publishAll(store, ['buche-centro', 'bus-stazione', 'lampioni-sud', 'rifiuti-mercato', 'sportello-anagrafe']));
    const result = (await store.fantasy.results.read('tuglie', userId, 'matchday-1'));
    assert.equal(result.summary.status, 'provisional');
    assert.equal(result.results.length, 4);
    assert.ok(result.outcomes.some((o) => o.cardId === 'sportello-anagrafe'));
    assert.ok(result.results.every((r) => r.cardId !== 'sportello-anagrafe'));
    for (const cardId of ['alberi-viale', 'sportello-anagrafe']) {
      await assert.rejects(async () => (await store.fantasy.results.reflect('tuglie', userId, 'matchday-1', cardId, { expectedRevision: result.revision, answer: 'externalConditions' })), (e) => e.code === 'reflection_not_available');
    }
    const unconfirmed = (await store.fantasy.results.read('tuglie', otherId, 'matchday-1'));
    assert.equal(unconfirmed.summary.total, 0);
    assert.equal(unconfirmed.summary.eligible, false);
    assert.equal(unconfirmed.summary.status, 'final');
    assert.deepEqual(unconfirmed.results, []);
  } finally { (await store.close()); }
});

it('published outcomes are versioned, source-validated, immutable and explicitly synthetic', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    const body = (await bodyFor(store, 'buche-centro'));
    await assert.rejects(async () => (await store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', body)), (e) => e.code === 'observation_pending');
    time = end;
    for (const changes of [{ sourceDate: '2026-10-09T00:00:00Z' }, { sourceDate: '2026-10-16T00:00:00Z' }, { sourceDate: '2026-10-15T00:00:00' }, { observed: 'unknown' }, { version: 2 }, { rulesVersion: 'future' }]) {
      await assert.rejects(async () => (await store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', { ...body, ...changes })), (e) => e.code === 'invalid_field');
    }
    await assert.rejects(async () => (await store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', { ...body, sourceLabel: 'Untrusted' })), (e) => e.code === 'source_not_verified');
    const first = (await store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', body));
    assert.equal(first.isDemo, true);
    assert.equal(first.outcome.isDemo, true);
    assert.equal(first.outcome.publisherRole, 'pilotModerator');
    assert.equal(first.outcome.version, 1);
    assert.deepEqual((await store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', body)), first);
    await assert.rejects(async () => (await store.fantasy.results.publish('tuglie', 'matchday-1', 'buche-centro', { ...body, observed: 'improves' })), (e) => e.code === 'outcome_immutable');
  } finally { (await store.close()); }
});

it('allows a negative total and applies transfer penalties only once', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    (await store.fantasy.teams.enroll('tuglie', userId, {}));
    for (let i = 0; i < 4; i++) {
      const current = (await store.fantasy.teams.team('tuglie', userId));
      const quote = (await store.fantasy.market.quote('tuglie', userId, { expectedRevision: current.revision, matchdayId: current.matchdayId,
        outgoingId: i % 2 ? 'fontanelle-ovest' : 'parco-nord', incomingId: i % 2 ? 'parco-nord' : 'fontanelle-ovest' })).quote;
      (await store.fantasy.market.confirm('tuglie', userId, { expectedRevision: quote.expectedRevision, quoteId: quote.id, idempotencyKey: `negative-transfer-${i}` }));
    }
    const team = (await confirm(store, 'improves'));
    time = end;
    (await publishAll(store, team.team.starterIds, 'worsens'));
    const result = (await store.fantasy.results.read('tuglie', userId, 'matchday-1'));
    assert.equal(result.summary.total, -8);
    assert.equal(result.summary.transferPenalty, 8);
    assert.deepEqual((await store.fantasy.results.read('tuglie', userId, 'matchday-1')).summary, result.summary);
  } finally { (await store.close()); }
});
