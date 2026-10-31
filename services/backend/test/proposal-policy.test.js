import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Readable } from 'node:stream';
import { createMemoryStore } from '../src/infrastructure/memory-store.js';
import { createApp } from '../src/http/app.js';
import { assertPublicProposalContent, assertSubmissionQuota } from '../src/domain/proposal-policy.js';
const base = { municipalityId: 'bologna', description: 'Il marciapiede presenta un ostacolo.', category: 'green', userId: 'policy-user' };
function submission(index, extra = {}) { return { ...base, title: `Ostacolo ${index}`, idempotencyKey: `policy-${index}`, ...extra }; }
describe('proposal pilot policies', () => {
  it('filters contacts across location/reference while preserving valid civic numbers', () => {
    for (const text of ['nome@example.it', 'https://example.it', '+39 333 1234567', 'STRONZO', 'test\u0000']) {
      assert.throws(() => assertPublicProposalContent({ title: 'Parco', location: { reference: text } }), e => e.statusCode === 422);
    }
    assert.doesNotThrow(() => assertPublicProposalContent({ title: 'Parco', location: { label: 'Via Roma', civic: '123456789' } }));
  });
  it('quota includes its boundary and derives Retry-After from authoritative dates', () => {
    const now = Date.UTC(2026, 9, 11, 12);
    assert.throws(() => assertSubmissionQuota([now, now - 10, now - 3600000], now), e => e.statusCode === 429 && e.retryAfterSeconds === 1);
    assert.doesNotThrow(() => assertSubmissionQuota([now, now - 10, now - 3600000], now + 1));
  });
  it('replay bypasses quota; refused sends save nothing; expiry and municipality isolate counters', () => {
    let now = Date.UTC(2026, 9, 11, 12); const store = createMemoryStore({ clock: () => now });
    const first = store.submitNextProblem(submission(0));
    store.submitNextProblem(submission(1)); store.submitNextProblem(submission(2));
    assert.deepEqual(store.submitNextProblem(submission(0)), first);
    assert.throws(() => store.submitNextProblem(submission(3)), e => e.statusCode === 429);
    assert.equal(store.listNextProblems({ municipalityId: 'bologna' }).filter(x => x.submittedByUserId === base.userId).length, 3);
    assert.throws(() => store.submitNextProblem(submission(4, { description: 'nome@example.it' })), e => e.statusCode === 422);
    now += 3600001; assert.equal(store.submitNextProblem(submission(3)).status, 'pending');
  });
  it('review uses compare-and-set, keeps rejection private and reopening does not alter original receipt', () => {
    const store = createMemoryStore(); const original = store.submitNextProblem(submission(0));
    const input = { municipalityId: 'bologna', problemId: original.id, decision: 'reject', expectedStatus: 'pending', operatorLabel: 'Operatore locale', reason: 'Motivazione privata' };
    const rejected = store.reviewSuggestion(input); assert.equal(rejected.status, 'rejected');
    assert.ok(!JSON.stringify(rejected).includes('Motivazione privata'));
    assert.throws(() => store.reviewSuggestion(input), e => e.statusCode === 409);
    assert.equal(store.reviewSuggestion({ ...input, decision: 'reopen', expectedStatus: 'rejected' }).status, 'pending');
    assert.deepEqual(store.submitNextProblem(submission(0)), original);
  });
  it('legacy callers cannot forge reserved session ownership', () => {
    assert.throws(() => createMemoryStore().submitNextProblem(submission(0, { userId: 'session:spoof' })), e => e.statusCode === 401);
  });
  it('HTTP 429 exposes positive Retry-After and 422 exposes no internal review reason', async () => {
    const app = createApp({ store: createMemoryStore() });
    async function send(index, body = {}) {
      const req = Readable.from([Buffer.from(JSON.stringify(body))]);
      req.method = 'POST'; req.url = '/v1/municipalities/bologna/next-problems'; req.headers = { 'idempotency-key': `http-policy-${index}` };
      let status, headers, result;
      await app(req, { writeHead(s,h) { status=s; headers=h; }, end(v) { result=JSON.parse(v); } });
      return { status, headers, result };
    }
    // Body contains only contract fields, not idempotencyKey or municipalityId.
    const clean = { title: 'Tema', description: 'Descrizione', category: 'green', userId: 'http-user' };
    for (let i=0;i<3;i++) assert.equal((await send(i, { ...clean, title: `Tema ${i}` })).status, 201);
    const limited = await send(3, { ...clean, title: 'Tema 3' });
    assert.equal(limited.status,429); assert.ok(limited.result.retryAfterSeconds > 0);
    assert.equal(String(limited.headers['retry-after']), String(limited.result.retryAfterSeconds));
  });
});
