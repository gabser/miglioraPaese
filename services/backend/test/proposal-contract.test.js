import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { describe, it } from 'node:test';
import { createApp, createMemoryStore } from '../src/server.js';
import { normalizeProposalLocation, proposalText } from '../src/domain/proposal-location.js';

const route = '/v1/municipalities/bologna/next-problems';
const valid = { title: 'Alberi', description: 'Potatura necessaria', category: 'green' };

describe('proposal location and Unicode HTTP contract', () => {
  it('returns additive stable field errors and searches actual place/ref/civic without mixing municipality', async () => {
    const app = createApp({ store: createMemoryStore() });
    for (const [body, path, code] of [
      [{ ...valid, title: '😀'.repeat(121) }, 'title', 'too_long'],
      [{ ...valid, category: 'unknown' }, 'category', 'invalid_choice'],
      [{ ...valid, location: { kind: 'specific', label: ' ' } }, 'location.label', 'invalid_text'],
      [{ ...valid, location: { kind: 'unknown' } }, 'location', 'invalid_location'],
    ]) {
      const result = await request(app, route, { method:'POST',body,key:'fields-safe-key' });
      assert.equal(result.status,400); assert.deepEqual(result.body.fieldErrors,{ [path]:code });
    }
    const created = await request(app, route, { method:'POST',body:{ ...valid, location:{kind:'specific',label:'Via Milano',civic:'12/A',reference:'Ingresso nord'} },key:'search-place-key' });
    for (const term of ['milano','12/A','ingresso nord']) {
      const result = await request(app, route + '?query=' + encodeURIComponent(term));
      assert.deepEqual(result.body.items.map(x=>x.id),[created.body.id]);
    }
    assert.equal((await request(app,'/v1/municipalities/castel-bolognese/next-problems?query=milano')).body.items.length,0);
  });

  it('preserves explicit places, whole municipality and legacy absence through POST/list/vote/promotion', async () => {
    const app = createApp({ store: createMemoryStore() });
    const places = [
      { kind: 'specific', label: 'Via Milano' },
      { kind: 'specific', label: 'Parco delle Rose', reference: 'Ingresso nord' },
      { kind: 'specific', label: 'Incrocio Roma / Verdi' },
      { kind: 'specific', label: 'Tratto della ciclabile', civic: '12/A' },
      { kind: 'municipality' },
      null,
    ];
    for (const [index, location] of places.entries()) {
      const body = { ...valid, userId: `location-user-${index}`, location };
      const created = await request(app, route, { method: 'POST', body, key: `location-case-${index}` });
      assert.equal(created.status, 201);
      assert.deepEqual(created.body.location, location);
      const replay = await request(app, route, { method: 'POST', body, key: `location-case-${index}` });
      assert.deepEqual(replay, created);
      const changed = await request(app, route, {
        method: 'POST', body: { ...body, location: { kind: 'specific', label: 'Altrove' } }, key: `location-case-${index}`,
      });
      assert.equal(changed.status, 409);
      assert.equal(changed.body.error, 'idempotency_key_reused');
      const voted = await request(app, `${route}/${created.body.id}/votes`, {
        method: 'POST', body: { vote: 'up' }, key: `location-vote-${index}`,
      });
      assert.equal(voted.status, 200);
      assert.deepEqual(voted.body.location, location);
    }
    const listed = await request(app, route);
    const submitted = listed.body.items.filter((item) => item.title === valid.title);
    assert.equal(submitted.length, places.length);
    assert.equal(new Set(submitted.map((item) => item.id)).size, places.length);
    const problems = await request(app, '/v1/municipalities/bologna/problems');
    const zones = problems.body.items.map((item) => item.zoneName);
    for (const label of ['Via Milano', 'Parco delle Rose', 'Incrocio Roma / Verdi', 'Tratto della ciclabile, 12/A', 'Intero Comune', 'Luogo non indicato']) {
      assert.ok(zones.includes(label), label);
    }
  });

  for (const [field, limit] of Object.entries({ title: 120, description: 1000, label: 120, civic: 20, reference: 200 })) {
    it(`counts trimmed Unicode code points at ${field} boundaries without truncating`, async () => {
      const app = createApp({ store: createMemoryStore() });
      for (const length of [limit - 1, limit, limit + 1]) {
        // A non-BMP emoji takes two UTF-16 units. ZWJ is its own code point.
        const text = '👩\u200d🌳' + '😀'.repeat(length - 3);
        const body = field === 'title' || field === 'description'
          ? { ...valid, [field]: `  ${text}  ` }
          : { ...valid, location: { kind: 'specific', label: 'Parco', [field]: `  ${text}  ` } };
        const result = await request(app, route, { method: 'POST', body, key: `unicode-${field}-${length}` });
        assert.equal(result.status, length > limit ? 400 : 201);
        if (length <= limit) {
          const actual = field === 'description' ? result.body.shortDescription
            : field === 'title' ? result.body.title : result.body.location[field];
          assert.equal(actual, text);
        } else assert.equal(result.body.error, 'invalid_field');
      }
    });
  }

  it('rejects malformed shapes, extra fields, blank places and invalid Unicode before mutation', async () => {
    const app = createApp({ store: createMemoryStore() });
    const malformed = [false, [], 'Via Roma', {}, { kind: 'unknown' },
      { kind: 'municipality', label: 'Hidden' }, { kind: 'specific' },
      { kind: 'specific', label: '  ' }, { kind: 'specific', label: 12 },
      { kind: 'specific', label: 'Parco', coordinates: [1, 2] },
      { kind: 'specific', label: 'Parco', civic: null },
      { kind: 'specific', label: 'Parco', reference: {} },
      { kind: 'specific', label: '\ud800' }, { kind: 'specific', label: 'Via\u0000Roma' }];
    for (const [index, location] of malformed.entries()) {
      const result = await request(app, route, { method: 'POST', body: { ...valid, location }, key: `invalid-place-${index}` });
      assert.equal(result.status, 400);
      assert.equal(result.body.error, 'invalid_field');
    }
    const brokenTitle = await request(app, route, { method: 'POST', body: { ...valid, title: '\ud800' }, key: 'invalid-title-unicode' });
    assert.equal(brokenTitle.status, 400);
    assert.equal((await request(app, route)).body.items.length, 1);
    assert.deepEqual(normalizeProposalLocation({ kind: 'specific', label: ' Via Roma ', civic: ' ', reference: ' Sud ' }), {
      kind: 'specific', label: 'Via Roma', reference: 'Sud',
    });
    assert.equal(proposalText(' a\u0301 ', 'title', 2), 'a\u0301');
  });
});

async function request(app, path, { method = 'GET', body, key } = {}) {
  const req = Readable.from(body === undefined ? [] : [Buffer.from(JSON.stringify(body))]);
  Object.assign(req, { method, url: path, headers: key ? { 'idempotency-key': key } : {} });
  let status;
  let payload;
  await app(req, {
    writeHead(value) { status = value; },
    end(value) { payload = JSON.parse(value); },
  });
  return { status, body: payload };
}
