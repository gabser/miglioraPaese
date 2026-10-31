import { createApp } from '../src/server.js';
import { createTestStore as createMemoryStore, createTestFantasy as createFantasyStore, client } from './helpers/fantasy.js';
import { scoreFantasyCard } from '../src/domain/fantasy/scoring.js';
import assert from 'node:assert/strict';
import { integrationTest as it } from './helpers/fantasy.js';
import { Readable } from 'node:stream';

const start = Date.parse('2026-10-08T00:00:00Z');
const lock = Date.parse('2026-10-10T00:00:00Z');
const end = Date.parse('2026-10-15T00:00:00Z');
const userId = 'anon:market-a';
async function quote(store, outgoingId = 'parco-nord', incomingId = 'fontanelle-ovest') {
  const team = (await store.fantasy.teams.team('tuglie', userId));
  return (await store.fantasy.market.quote('tuglie', userId, { expectedRevision: team.revision, matchdayId: team.matchdayId, outgoingId, incomingId })).quote;
}
function command(q, key = 'market-test-key-1') { return { quoteId: q.id, expectedRevision: q.expectedRevision, idempotencyKey: key }; }

it('third and fourth transfers cost four once, duplicate replies are identical, and allowance resets by day', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    (await store.fantasy.teams.enroll('tuglie', userId, {}));
    let accepted;
    for (let i = 0; i < 4; i++) {
      const q = (await quote(store, i % 2 ? 'fontanelle-ovest' : 'parco-nord', i % 2 ? 'parco-nord' : 'fontanelle-ovest'));
      assert.equal(q.penalty, i < 2 ? 0 : 4);
      assert.equal(q.creditDelta, i % 2 ? -4 : 4);
      assert.equal(q.budgetAfter, i % 2 ? 15 : 19);
      const body = command(q, `market-test-key-${i}`);
      accepted = (await store.fantasy.market.confirm('tuglie', userId, body));
      assert.deepEqual((await store.fantasy.market.confirm('tuglie', userId, body)), accepted);
      assert.equal(accepted.transfers.length, i + 1);
      assert.deepEqual(accepted.transfers.map(t=>t.outgoingCardId), Array.from({length:i+1},(_,n)=>n%2?'fontanelle-ovest':'parco-nord'));
      assert.equal(accepted.team.confirmed, false);
      assert.equal(accepted.transferPenalty, i < 2 ? 0 : (i - 1) * 4);
      await assert.rejects(async () => (await store.fantasy.market.confirm('tuglie', userId, { ...body, quoteId: 'changed' })), (e) => e.code === 'idempotency_conflict');
    }
    time = lock;
    const frozen = (await store.fantasy.teams.team('tuglie', userId));
    assert.equal(frozen.snapshots[0].transferPenalty, 8);
    time = end;
    const next = (await store.fantasy.teams.team('tuglie', userId));
    assert.equal(next.transfersRemaining, 2);
    assert.equal(next.transferPenalty, 0);
    assert.equal(next.snapshots[0].transferPenalty, 8);
    assert.equal((await quote(store)).penalty, 0);
  } finally { (await store.close()); }
});

it('quotes are revision-bound, expired at the exact deadline, and transfers are refused at lock', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    (await store.fantasy.teams.enroll('tuglie', userId, {}));
    const stale = (await quote(store));
    (await store.fantasy.teams.confirm('tuglie', userId, { expectedRevision: 1, matchdayId: 'matchday-1' }));
    await assert.rejects(async () => (await store.fantasy.market.confirm('tuglie', userId, command(stale))), (e) => e.code === 'stale_revision');
    const expires = (await quote(store));
    time = Date.parse(expires.expiresAt);
    await assert.rejects(async () => (await store.fantasy.market.confirm('tuglie', userId, command(expires))), (e) => e.code === 'quote_expired');
    const beforeLock = (await quote(store));
    time = lock;
    await assert.rejects(async () => (await store.fantasy.market.confirm('tuglie', userId, command(beforeLock))), (e) => e.code === 'matchday_locked');
    await assert.rejects(async () => (await quote(store)), (e) => e.code === 'matchday_locked');
    assert.equal((await store.fantasy.teams.team('tuglie', userId)).transfers.length, 0);
  } finally { (await store.close()); }
});

it('failed transfers never consume credits or free allowance; pending sources are allowed', async () => {
  const store = (await createMemoryStore({ now: () => start }));
  try {
    const initial = (await store.fantasy.teams.enroll('tuglie', userId, {}));
    for (const [outgoingId, incomingId] of [['missing', 'fontanelle-ovest'], ['parco-nord', 'missing'], ['parco-nord', 'buche-centro'], ['parco-nord', 'ciclabile-est'], ['lampioni-sud', 'fontanelle-ovest']]) {
      await assert.rejects(async () => (await quote(store, outgoingId, incomingId)));
      const team = (await store.fantasy.teams.team('tuglie', userId));
      assert.equal(team.revision, initial.revision);
      assert.equal(team.transfersRemaining, 2);
      assert.equal(team.team.budgetRemaining, 15);
    }
    const pending = (await quote(store, 'sportello-anagrafe', 'fermata-accessibile'));
    const accepted = (await store.fantasy.market.confirm('tuglie', userId, command(pending)));
    assert.equal(accepted.transfers.length, 1);
    assert.equal(accepted.team.budgetRemaining, 16);
  } finally { (await store.close()); }
});

it('two concurrent confirmations cannot spend the same revision twice', async () => {
  const store = (await createMemoryStore({ now: () => start }));
  try {
    (await store.fantasy.teams.enroll('tuglie', userId, {}));
    const q1 = (await quote(store)), q2 = (await quote(store));
    const results = await Promise.allSettled([
      Promise.resolve().then(async () => (await store.fantasy.market.confirm('tuglie', userId, command(q1, 'concurrent-key-1')))),
      Promise.resolve().then(async () => (await store.fantasy.market.confirm('tuglie', userId, command(q2, 'concurrent-key-2')))),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    assert.equal(results.find((r) => r.status === 'rejected').reason.code, 'stale_revision');
    assert.equal((await store.fantasy.counts()).transfers, 1);
  } finally { (await store.close()); }
});

it('HTTP quotes and confirmations use the signed session and deny another manager quote', async () => {
  const store = (await createMemoryStore({ now: () => start }));
  try {
    const app = createApp({ fantasy:store.fantasy, store, pilotMunicipalityId: 'tuglie' });
    const requestA=client(app),requestB=client(app);
    const a=(path,body)=>requestA(path,'POST',body),b=(path,body)=>requestB(path,'POST',body);
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
  } finally { (await store.close()); }
});
