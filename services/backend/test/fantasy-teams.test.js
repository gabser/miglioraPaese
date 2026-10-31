import { createApp } from '../src/server.js';
import { createTestStore as createMemoryStore, createTestFantasy as createFantasyStore, client } from './helpers/fantasy.js';
import { scoreFantasyCard } from '../src/domain/fantasy/scoring.js';
import assert from 'node:assert/strict';
import { integrationTest as it } from './helpers/fantasy.js';
import { Readable } from 'node:stream';

const base = '/v1/fantasy/municipalities/tuglie';
const start = Date.parse('2026-10-08T00:00:00Z');
const lock = Date.parse('2026-10-10T00:00:00Z');
const end = Date.parse('2026-10-15T00:00:00Z');

function draft(team, changes = {}) {
  return { expectedRevision: team.revision, matchdayId: team.matchdayId,
    starterIds: team.team.starterIds, captainId: team.team.captainId,
    predictions: team.team.predictions, motivations: team.team.motivations, ...changes };
}

it('enrolls idempotently, isolates signed sessions and rejects body-supplied identities', async () => {
  const store = (await createMemoryStore({ now: () => start }));
  try {
    const app = createApp({ fantasy:store.fantasy, store, pilotMunicipalityId: 'tuglie' });
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
  } finally { (await store.close()); }
});

it('validates roster, budget, roles, predictions and revision without consuming a revision on failure', async () => {
  const store = (await createMemoryStore({ now: () => start }));
  try {
    const api = client(createApp({ fantasy:store.fantasy, store }));
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
  } finally { (await store.close()); }
});

for (const offset of [-1, 0, 1]) {
  it(`enforces server lock at ${offset}ms for every team mutation and freezes last accepted state`, async () => {
    let time = start;
    const store = (await createMemoryStore({ now: () => time }));
    try {
      const api = client(createApp({ fantasy:store.fantasy, store }));
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
    } finally { (await store.close()); }
  });
}

it('unconfirmed and late enrollment snapshots are ineligible, and two tabs cannot overwrite each other', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    const app = createApp({ fantasy:store.fantasy, store });
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
  } finally { (await store.close()); }
});

it('a frozen day stays locked after clock rollback, and client time cannot unlock it', async () => {
  let time = start;
  const store = (await createMemoryStore({ now: () => time }));
  try {
    const api = client(createApp({ fantasy:store.fantasy, store }));
    const first = (await api(`${base}/enrollment`, 'POST', {})).body;
    time = lock;
    const frozen = (await api(`${base}/team?clientTime=2020-01-01`)).body;
    time = start;
    assert.equal((await api(`${base}/team`, 'PUT', draft(first))).body.error, 'matchday_locked');
    assert.deepEqual((await api(`${base}/team`)).body.snapshots, frozen.snapshots);
    time = end + 100 * 24 * 60 * 60 * 1000;
    const newcomer = client(createApp({ fantasy:store.fantasy, store }));
    assert.equal((await newcomer(`${base}/enrollment`, 'POST', {})).body.error, 'season_ended');
  } finally { (await store.close()); }
});
