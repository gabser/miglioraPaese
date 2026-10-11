import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Readable } from 'node:stream';
import { describe, it } from 'node:test';

import { createApp, createMemoryStore, startServer } from '../src/server.js';

describe('backend HTTP contract', () => {
  it('starts a real server on an ephemeral port and serves health', async () => {
    const server = startServer({
      env: { DATA_STORE: 'memory' },
      port: 0,
      host: '127.0.0.1',
    });
    try {
      await once(server, 'listening');
      const address = server.address();
      assert.notEqual(typeof address, 'string');

      const response = await fetch(
        'http://127.0.0.1:' + address.port + '/health',
      );
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type'), /^application\/json/);
      assert.deepEqual(await response.json(), { status: 'ok' });
    } finally {
      await closeServer(server);
    }
  });

  it('accepts canonical municipality slugs and legacy Flutter aliases', async () => {
    const app = createMemoryApp();
    const canonical = await fetchJson(
      '/v1/municipalities/bologna/activation',
      { app },
    );
    const legacy = await fetchJson(
      '/v1/municipalities/comune%3ABologna/activation',
      { app },
    );
    const collecting = await fetchJson(
      '/v1/municipalities/comune%3ACastel%20Bolognese/activation',
      { app },
    );

    assert.deepEqual(canonical.body, { municipalityId: 'bologna', state: 'active' });
    assert.deepEqual(legacy.body, canonical.body);
    assert.equal(collecting.body.state, 'collectingSignals');
  });

  it('returns Flutter-compatible turn field names', async () => {
    const response = await fetchJson('/v1/municipalities/bologna/turn');

    assert.equal(response.status, 200);
    assert.equal(typeof response.body.startAt, 'string');
    assert.equal(typeof response.body.endAt, 'string');
    assert.equal('startsAt' in response.body, false);
    assert.equal('endsAt' in response.body, false);
  });

  it('preserves the public MemoryStore civic summary surface', () => {
    const store = createMemoryStore();

    assert.deepEqual(store.getCivicLoopSummary('bologna'), {
      municipalityName: 'Bologna',
      proposedThemes: 1,
      confirmedThemes: 1,
      cardsInTurn: 2,
      predictions: 0,
      outcomes: 0,
      reputationPoints: 0,
      topThemeTitle: "Tempi d'attesa all'anagrafe",
    });
  });

  it('requires explicit composition instead of falling back to MemoryStore', () => {
    assert.throws(
      () => createApp(),
      /createApp requires an explicit application or store/,
    );
  });

  it('promotes an approved suggestion into a card and activates the town', async () => {
    const app = createMemoryApp();
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        body: {
          title: 'Attraversamento della scuola',
          description: 'Serve un passaggio più leggibile.',
          category: 'safety',
          userId: 'user-a',
        },
      },
    );
    const voted = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems/' +
        created.body.id +
        '/votes',
      {
        app,
        method: 'POST',
        body: { vote: 'up', userId: 'user-a' },
      },
    );
    const activation = await fetchJson(
      '/v1/municipalities/castel-bolognese/activation',
      { app },
    );
    const problems = await fetchJson(
      '/v1/municipalities/castel-bolognese/problems',
      { app },
    );
    const summary = await fetchJson(
      '/v1/municipalities/castel-bolognese/summary',
      { app },
    );

    assert.equal(voted.body.status, 'approved');
    assert.equal(activation.body.state, 'active');
    assert.equal(
      problems.body.items.some(
        (item) => item.id === 'proposal_' + created.body.id,
      ),
      true,
    );
    assert.equal(summary.body.confirmedThemes, 1);
    assert.equal(summary.body.cardsInTurn, 1);
    assert.equal(summary.body.topThemeTitle, created.body.title);
  });

  it('computes myVote independently for each client-provided user id', async () => {
    const app = createMemoryApp();
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        body: {
          title: 'Panchina alla fermata',
          description: 'Una seduta per chi aspetta il bus.',
          category: 'transport',
          userId: 'user-a',
        },
      },
    );
    await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems/' +
        created.body.id +
        '/votes',
      {
        app,
        method: 'POST',
        body: { vote: 'up', userId: 'user-a' },
      },
    );

    const forA = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems?userId=user-a',
      { app },
    );
    const forB = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems?userId=user-b',
      { app },
    );
    const itemA = forA.body.items.find((item) => item.id === created.body.id);
    const itemB = forB.body.items.find((item) => item.id === created.body.id);

    assert.equal(itemA.myVote, 'up');
    assert.equal(itemB.myVote, 'none');
  });

  it('replays idempotent votes once and rejects key reuse with new input', async () => {
    const app = createMemoryApp();
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        idempotencyKey: 'memory-submit-replay-0001',
        body: {
          title: 'Voto retry safe',
          description: 'La stessa intenzione non deve essere applicata due volte.',
          category: 'safety',
          userId: 'user-retry',
        },
      },
    );
    const path =
      '/v1/municipalities/castel-bolognese/next-problems/' +
      created.body.id +
      '/votes';
    const options = {
      app,
      method: 'POST',
      idempotencyKey: 'memory-vote-replay-0001',
      body: { vote: 'up', userId: 'user-retry' },
    };
    const first = await fetchJson(path, options);
    const replay = await fetchJson(path, options);
    const reused = await fetchJson(path, {
      ...options,
      body: { vote: 'down', userId: 'user-retry' },
    });

    assert.deepEqual(replay.body, first.body);
    assert.equal(first.body.myVote, 'up');
    assert.equal(first.body.votesUp, 1);
    assert.equal(reused.status, 409);
    assert.equal(reused.body.error, 'idempotency_key_reused');
  });

  it('requires a valid Idempotency-Key for state-changing repository routes', async () => {
    const missing = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        method: 'POST',
        disableIdempotencyKey: true,
        body: {
          title: 'Senza chiave',
          description: 'Richiesta non retry-safe.',
          category: 'green',
        },
      },
    );
    const invalid = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        method: 'POST',
        idempotencyKey: 'short',
        body: {
          title: 'Chiave corta',
          description: 'Richiesta non valida.',
          category: 'green',
        },
      },
    );

    assert.equal(missing.status, 400);
    assert.equal(missing.body.error, 'invalid_field');
    assert.equal(invalid.status, 400);
    assert.equal(invalid.body.error, 'invalid_field');
  });

  it('supports loopback and configured CORS origins with preflight', async () => {
    const loopback = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        method: 'OPTIONS',
        headers: {
          origin: 'http://localhost:7357',
          'access-control-request-method': 'GET',
        },
      },
    );
    assert.equal(loopback.status, 200);
    assert.equal(
      loopback.headers['access-control-allow-origin'],
      'http://localhost:7357',
    );
    assert.match(
      loopback.headers['access-control-allow-headers'],
      /Idempotency-Key/,
    );

    const configuredApp = createMemoryApp({
      allowedOrigins: ['https://pilot.example'],
    });
    const configured = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        app: configuredApp,
        headers: { origin: 'https://pilot.example' },
      },
    );
    assert.equal(configured.status, 200);
    assert.equal(
      configured.headers['access-control-allow-origin'],
      'https://pilot.example',
    );

    const rejected = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      { headers: { origin: 'https://attacker.example' } },
    );
    assert.equal(rejected.status, 403);
    assert.equal(rejected.body.error, 'origin_not_allowed');
  });

  it('rejects bodies over 64 KiB and non-object JSON bodies', async () => {
    const oversized = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        method: 'POST',
        rawBody: '{"padding":"' + 'x'.repeat(65_536) + '"}',
      },
    );
    const nullBody = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      { method: 'POST', rawBody: 'null' },
    );
    const arrayBody = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      { method: 'POST', rawBody: '[]' },
    );

    assert.equal(oversized.status, 413);
    assert.equal(oversized.body.error, 'payload_too_large');
    assert.equal(nullBody.status, 400);
    assert.equal(nullBody.body.error, 'invalid_body');
    assert.equal(arrayBody.status, 400);
    assert.equal(arrayBody.body.error, 'invalid_body');
  });

  it('validates title, description, status and motivations', async () => {
    const longTitle = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        method: 'POST',
        body: {
          title: 'x'.repeat(121),
          description: 'Descrizione',
          category: 'safety',
        },
      },
    );
    const invalidStatus = await fetchJson(
      '/v1/municipalities/bologna/next-problems?status=unknown',
    );
    const tooManyMotivations = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita',
      {
        method: 'PUT',
        body: {
          choice: 'improve',
          motivations: ['visibleActions', 'recentDecline', 'seasonality'],
        },
      },
    );
    const unknownMotivation = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita',
      {
        method: 'PUT',
        body: { choice: 'improve', motivations: ['invented'] },
      },
    );

    assert.equal(longTitle.status, 400);
    assert.equal(invalidStatus.status, 400);
    assert.equal(tooManyMotivations.status, 400);
    assert.equal(unknownMotivation.status, 400);
  });

  it('validates turn and problem existence and municipality coherence', async () => {
    const unknownTurn = await fetchJson(
      '/v1/turns/missing/predictions',
    );
    const unknownProblem = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/missing',
      { method: 'PUT', body: { choice: 'stable' } },
    );
    const mismatch = await fetchJson(
      '/v1/turns/turn-castel-bolognese-today/predictions/problem-green-margherita',
      { method: 'PUT', body: { choice: 'stable' } },
    );

    assert.equal(unknownTurn.status, 404);
    assert.equal(unknownTurn.body.error, 'turn_not_found');
    assert.equal(unknownProblem.status, 404);
    assert.equal(unknownProblem.body.error, 'problem_not_found');
    assert.equal(mismatch.status, 409);
    assert.equal(mismatch.body.error, 'problem_turn_mismatch');
  });

  it('locks the prediction choice while allowing metadata updates', async () => {
    const app = createMemoryApp();
    const path =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    const first = await fetchJson(path, {
      app,
      method: 'PUT',
      body: { choice: 'improve', userId: 'user-a' },
    });
    const metadata = await fetchJson(path, {
      app,
      method: 'PUT',
      body: {
        choice: 'improve',
        motivations: ['visibleActions'],
        userId: 'user-a',
      },
    });
    const changed = await fetchJson(path, {
      app,
      method: 'PUT',
      body: { choice: 'worsen', userId: 'user-a' },
    });

    assert.equal(first.status, 200);
    assert.equal(metadata.status, 200);
    assert.equal(metadata.body.createdAt, first.body.createdAt);
    assert.equal(changed.status, 409);
    assert.equal(changed.body.error, 'prediction_locked');
  });

  it('returns stable JSON errors and accepts titles describing distinct proposals', async () => {
    const app = createMemoryApp();
    const malformed = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      { app, method: 'POST', rawBody: '{' },
    );
    const first = {
      title: 'Tema con spazi',
      description: 'Descrizione',
      category: 'decor',
    };
    await fetchJson('/v1/municipalities/bologna/next-problems', {
      app,
      method: 'POST',
      body: first,
    });
    const duplicate = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        app,
        method: 'POST',
        body: { ...first, title: '  Tema   con   spazi  ' },
      },
    );
    const missing = await fetchJson(
      '/v1/municipalities/missing/next-problems',
      { app },
    );

    assert.equal(malformed.status, 400);
    assert.equal(malformed.body.error, 'invalid_json');
    assert.equal(duplicate.status, 201);
    assert.equal(duplicate.body.title, 'Tema   con   spazi');
    assert.equal(missing.status, 404);
    assert.equal(missing.body.error, 'municipality_not_found');
  });

  it('filters suggested problems by positive status and text query', async () => {
    const app = createMemoryApp();
    await fetchJson('/v1/municipalities/bologna/next-problems', {
      app,
      method: 'POST',
      body: {
        title: 'Nuova illuminazione in piazza',
        description: 'Lampioni poco leggibili nelle ore serali.',
        category: 'lighting',
      },
    });

    const approved = await fetchJson(
      '/v1/municipalities/bologna/next-problems?status=approved',
      { app },
    );
    const matching = await fetchJson(
      '/v1/municipalities/bologna/next-problems?query=lampioni',
      { app },
    );

    assert.deepEqual(
      approved.body.items.map((item) => item.id),
      ['suggested-queues-registry'],
    );
    assert.deepEqual(
      matching.body.items.map((item) => item.title),
      ['Nuova illuminazione in piazza'],
    );
  });

  it('preserves vote switching, toggle removal and promotion rollback', async () => {
    const app = createMemoryApp();
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        body: {
          title: 'Attraversamento via Roma',
          description: 'Migliorare visibilità e sicurezza.',
          category: 'safety',
          userId: 'user-a',
        },
      },
    );
    const path =
      '/v1/municipalities/castel-bolognese/next-problems/' +
      created.body.id +
      '/votes';

    const down = await fetchJson(path, {
      app,
      method: 'POST',
      body: { vote: 'down', userId: 'user-a' },
    });
    const switched = await fetchJson(path, {
      app,
      method: 'POST',
      body: { vote: 'up', userId: 'user-a' },
    });
    const toggledOff = await fetchJson(path, {
      app,
      method: 'POST',
      body: { vote: 'up', userId: 'user-a' },
    });
    const activation = await fetchJson(
      '/v1/municipalities/castel-bolognese/activation',
      { app },
    );
    const problems = await fetchJson(
      '/v1/municipalities/castel-bolognese/problems',
      { app },
    );

    assert.deepEqual(
      {
        votesUp: down.body.votesUp,
        votesDown: down.body.votesDown,
        score: down.body.score,
        myVote: down.body.myVote,
        status: down.body.status,
      },
      { votesUp: 0, votesDown: 1, score: -1, myVote: 'down', status: 'pending' },
    );
    assert.deepEqual(
      {
        votesUp: switched.body.votesUp,
        votesDown: switched.body.votesDown,
        myVote: switched.body.myVote,
        status: switched.body.status,
      },
      { votesUp: 1, votesDown: 0, myVote: 'up', status: 'approved' },
    );
    assert.deepEqual(
      {
        votesUp: toggledOff.body.votesUp,
        votesDown: toggledOff.body.votesDown,
        myVote: toggledOff.body.myVote,
        status: toggledOff.body.status,
      },
      { votesUp: 0, votesDown: 0, myVote: 'none', status: 'pending' },
    );
    assert.equal(activation.body.state, 'collectingSignals');
    assert.equal(
      problems.body.items.some(
        (item) => item.id === 'proposal_' + created.body.id,
      ),
      false,
    );
  });

  it('lists only predictions owned by the selected client-provided user id', async () => {
    const app = createMemoryApp();
    const path =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    await fetchJson(path, {
      app,
      method: 'PUT',
      body: { choice: 'improve', userId: 'user-a' },
    });
    await fetchJson(path, {
      app,
      method: 'PUT',
      body: { choice: 'stable', userId: 'user-b' },
    });

    const forA = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions?userId=user-a',
      { app },
    );
    const forB = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions?userId=user-b',
      { app },
    );

    assert.deepEqual(forA.body.items.map((item) => item.userId), ['user-a']);
    assert.deepEqual(forB.body.items.map((item) => item.userId), ['user-b']);
    assert.equal(forA.body.items[0].choice, 'improve');
    assert.equal(forB.body.items[0].choice, 'stable');
  });

  it('keeps the original prediction resolution happy path', async () => {
    const result = await fetchJson(
      '/v1/problems/problem-green-margherita/resolve',
      { method: 'POST', body: { choice: 'improve' } },
    );

    assert.equal(result.status, 200);
    assert.equal(result.body.correct, true);
    assert.equal(result.body.winningChoice, 'improve');
  });
});

async function fetchJson(path, options = {}) {
  const app = options.app ?? createMemoryApp();
  const rawBody =
    options.rawBody ??
    (Object.hasOwn(options, 'body') ? JSON.stringify(options.body) : '');
  const req = Readable.from(rawBody ? [Buffer.from(rawBody)] : []);
  req.method = options.method ?? 'GET';
  req.url = path;
  const requestHeaders = { ...(options.headers ?? {}) };
  if (
    !options.disableIdempotencyKey &&
    (req.method === 'POST' || req.method === 'PUT')
  ) {
    requestHeaders['idempotency-key'] =
      options.idempotencyKey ?? `backend-test-key-${++idempotencyCounter}`;
  }
  req.headers = Object.fromEntries(
    Object.entries(requestHeaders).map(([key, value]) => [
      key.toLowerCase(),
      value,
    ]),
  );

  const res = {
    statusCode: 0,
    headers: {},
    payload: '',
    writeHead(statusCode, headers) {
      this.statusCode = statusCode;
      this.headers = Object.fromEntries(
        Object.entries(headers).map(([key, value]) => [
          key.toLowerCase(),
          value,
        ]),
      );
    },
    end(payload) {
      this.payload = payload ?? '';
    },
  };

  await app(req, res);

  return {
    status: res.statusCode,
    headers: res.headers,
    body: JSON.parse(res.payload),
  };
}

let idempotencyCounter = 0;

function createMemoryApp(options = {}) {
  return createApp({ store: createMemoryStore(), ...options });
}

async function closeServer(server) {
  if (!server.listening) return;
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}
