import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { describe, it } from 'node:test';

import { createApp } from '../src/server.js';

const app = createApp();

describe('backend HTTP contract', () => {
  it('returns health status', async () => {
    const response = await fetchJson('/health');

    assert.equal(response.status, 200);
    assert.deepEqual(response.body, { status: 'ok' });
  });

  it('returns municipality activation and summary', async () => {
    const activation = await fetchJson(
      '/v1/municipalities/castel-bolognese/activation',
    );
    const summary = await fetchJson('/v1/municipalities/castel-bolognese/summary');

    assert.equal(activation.status, 200);
    assert.equal(activation.body.state, 'activating');
    assert.equal(summary.status, 200);
    assert.equal(summary.body.municipalityName, 'Castel Bolognese');
    assert.equal(typeof summary.body.proposedThemes, 'number');
  });

  it('creates and votes on a suggested problem', async () => {
    const created = await fetchJson('/v1/municipalities/castel-bolognese/next-problems', {
      method: 'POST',
      body: {
        title: 'Nuovo attraversamento pedonale',
        description: 'Punto molto usato vicino alla scuola.',
        category: 'safety',
      },
    });

    assert.equal(created.status, 201);
    assert.equal(created.body.status, 'pending');
    assert.equal(created.body.category, 'safety');

    const voted = await fetchJson(
      `/v1/municipalities/castel-bolognese/next-problems/${created.body.id}/votes`,
      {
        method: 'POST',
        body: { vote: 'up' },
      },
    );

    assert.equal(voted.status, 200);
    assert.equal(voted.body.myVote, 'up');
    assert.equal(voted.body.status, 'approved');
  });

  it('stores a prediction and resolves it against the problem status', async () => {
    const prediction = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita',
      {
        method: 'PUT',
        body: {
          choice: 'improve',
          confidence: 'considered',
          motivations: ['visibleActions'],
        },
      },
    );

    assert.equal(prediction.status, 200);
    assert.equal(prediction.body.choice, 'improve');
    assert.equal(prediction.body.problemId, 'problem-green-margherita');

    const list = await fetchJson('/v1/turns/turn-bologna-today/predictions');
    assert.equal(list.status, 200);
    assert.equal(list.body.items.length, 1);

    const result = await fetchJson('/v1/problems/problem-green-margherita/resolve', {
      method: 'POST',
      body: { choice: 'improve' },
    });

    assert.equal(result.status, 200);
    assert.equal(result.body.correct, true);
    assert.equal(result.body.winningChoice, 'improve');
  });
});

async function fetchJson(path, options = {}) {
  const rawBody = options.body ? JSON.stringify(options.body) : '';
  const req = Readable.from(rawBody ? [Buffer.from(rawBody)] : []);
  req.method = options.method ?? 'GET';
  req.url = path;

  const res = {
    statusCode: 0,
    headers: {},
    payload: '',
    writeHead(statusCode, headers) {
      this.statusCode = statusCode;
      this.headers = headers;
    },
    end(payload) {
      this.payload = payload ?? '';
    },
  };

  await app(req, res);

  return {
    status: res.statusCode,
    body: JSON.parse(res.payload),
  };
}
