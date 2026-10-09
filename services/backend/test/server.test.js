import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Readable } from 'node:stream';
import { describe, it } from 'node:test';

import {
  createApp,
  createMemoryStore,
  startServer,
} from '../src/server.js';

describe('backend HTTP contract', () => {
  it('starts a real server on an ephemeral port and serves health', async () => {
    const logs = [];
    const server = startServer({
      port: 0,
      host: '127.0.0.1',
      logger: (line) => logs.push(JSON.parse(line)),
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

      const ready = await fetch(
        'http://127.0.0.1:' + address.port + '/ready',
      );
      assert.equal(ready.status, 200);
      assert.deepEqual(await ready.json(), { status: 'ready' });

      const activation = await fetch(
        'http://127.0.0.1:' +
          address.port +
          '/v1/municipalities/bologna/activation?userId=not-logged',
        { headers: { 'x-request-id': 'contract-check' } },
      );
      assert.equal(activation.headers.get('x-request-id'), 'contract-check');
      await activation.json();

      const metrics = await fetch(
        'http://127.0.0.1:' + address.port + '/metrics',
      );
      assert.match(metrics.headers.get('content-type'), /^text\/plain/);
      const metricsBody = await metrics.text();
      assert.match(metricsBody, /migliorapaese_http_requests_total/);
      assert.match(metricsBody, /route="municipalityActivation"/);
      assert.equal(logs.some((entry) => entry.route === 'ready'), true);
      assert.equal(JSON.stringify(logs).includes('not-logged'), false);
    } finally {
      await closeServer(server);
    }
  });

  it('accepts canonical municipality slugs and legacy Flutter aliases', async () => {
    const app = createApp();
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
    const tuglie = await fetchJson(
      '/v1/municipalities/comune%3ATuglie/activation',
      { app },
    );

    assert.deepEqual(canonical.body, { municipalityId: 'bologna', state: 'active' });
    assert.deepEqual(legacy.body, canonical.body);
    assert.equal(collecting.body.state, 'collectingSignals');
    assert.deepEqual(tuglie.body, {
      municipalityId: 'tuglie',
      state: 'active',
    });
  });

  it('serves clearly synthetic seed data for the Tuglie local pilot', async () => {
    const app = createApp({ pilotMunicipalityId: 'tuglie' });
    const problems = await fetchJson('/v1/municipalities/tuglie/problems', {
      app,
    });
    const suggestions = await fetchJson(
      '/v1/municipalities/tuglie/next-problems',
      { app },
    );
    const turn = await fetchJson('/v1/municipalities/tuglie/turn', { app });
    const prediction = await fetchJson(
      '/v1/turns/turn-tuglie-demo/predictions/problem-tuglie-lighting-demo',
      {
        app,
        method: 'PUT',
        body: { choice: 'stable' },
      },
    );
    const outsidePilot = await fetchJson(
      '/v1/municipalities/bologna/activation',
      { app },
    );

    assert.equal(problems.status, 200);
    assert.ok(
      problems.body.items.every((item) => item.title.includes('Scenario demo')),
    );
    assert.equal(suggestions.status, 200);
    assert.ok(
      suggestions.body.items.every((item) =>
        item.shortDescription.includes('sintetico'),
      ),
    );
    assert.equal(turn.body.id, 'turn-tuglie-demo');
    assert.equal(prediction.status, 200);
    assert.equal(prediction.body.choice, 'stable');
    assert.equal(outsidePilot.status, 404);
  });

  it('returns Flutter-compatible turn field names', async () => {
    const response = await fetchJson('/v1/municipalities/bologna/turn');

    assert.equal(response.status, 200);
    assert.equal(typeof response.body.startAt, 'string');
    assert.equal(typeof response.body.endAt, 'string');
    assert.equal('startsAt' in response.body, false);
    assert.equal('endsAt' in response.body, false);
  });

  it('promotes an approved suggestion into a card and activates the town', async () => {
    const app = createApp();
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

  it('computes myVote from server-issued sessions and ignores spoofed ids', async () => {
    const app = createApp();
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        session: 'a',
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
        session: 'a',
        body: { vote: 'up', userId: 'user-a' },
      },
    );

    const forA = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems?userId=user-a',
      { app, session: 'a' },
    );
    const forB = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems?userId=user-b',
      { app, session: 'b' },
    );
    const itemA = forA.body.items.find((item) => item.id === created.body.id);
    const itemB = forB.body.items.find((item) => item.id === created.body.id);

    assert.equal(itemA.myVote, 'up');
    assert.equal(itemB.myVote, 'none');
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
    assert.equal(
      loopback.headers['access-control-allow-credentials'],
      'true',
    );

    const deletionPreflight = await fetchJson('/v1/session', {
      method: 'OPTIONS',
      headers: {
        origin: 'http://localhost:7357',
        'access-control-request-method': 'DELETE',
      },
    });
    assert.equal(deletionPreflight.status, 200);
    assert.match(
      deletionPreflight.headers['access-control-allow-methods'],
      /(?:^|,\s*)DELETE(?:,|$)/,
    );

    const configuredApp = createApp({
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
    const app = createApp();
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

  it('returns stable JSON errors for malformed JSON, advisory duplicates and missing data', async () => {
    const app = createApp();
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

  it('issues a signed HttpOnly anonymous session cookie', async () => {
    const app = createApp();
    const first = await fetchJson('/v1/municipalities/bologna/summary', {
      app,
      session: 'identity',
    });
    const second = await fetchJson('/v1/municipalities/bologna/summary', {
      app,
      session: 'identity',
    });

    assert.match(first.headers['set-cookie'], /^mp_anon=v1\./);
    assert.match(first.headers['set-cookie'], /; HttpOnly;/);
    assert.match(first.headers['set-cookie'], /; SameSite=Lax$/);
    assert.equal(second.headers['set-cookie'], undefined);
  });

  it('deletes data linked to an anonymous session and rotates its cookie', async () => {
    const store = createMemoryStore({ moderationRequired: true });
    const app = createApp({ store, secureCookies: true });
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        session: 'a',
        body: {
          title: 'Fontanella nel parco',
          description: 'Una proposta civica senza dati personali.',
          category: 'green',
        },
      },
    );
    const originalCookie = created.headers['set-cookie'];
    await fetchJson(
      `/v1/municipalities/castel-bolognese/next-problems/${created.body.id}/votes`,
      { app, method: 'POST', session: 'a', body: { vote: 'up' } },
    );
    await fetchJson(
      `/v1/municipalities/castel-bolognese/next-problems/${created.body.id}/votes`,
      { app, method: 'POST', session: 'b', body: { vote: 'down' } },
    );
    const predictionPath =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    for (const session of ['a', 'b']) {
      await fetchJson(predictionPath, {
        app,
        method: 'PUT',
        session,
        body: { choice: 'improve' },
      });
    }
    await fetchJson('/v1/problems/problem-green-margherita/resolve', {
      app,
      method: 'POST',
      session: 'a',
      body: { choice: 'improve' },
    });

    const deleted = await fetchJson('/v1/session', {
      app,
      method: 'DELETE',
      session: 'a',
    });

    assert.equal(deleted.status, 200);
    assert.deepEqual(deleted.body, { status: 'deleted' });
    assert.match(deleted.headers['set-cookie'], /^mp_anon=;/);
    assert.match(deleted.headers['set-cookie'], /Max-Age=0/);
    assert.match(deleted.headers['set-cookie'], /Expires=Thu, 01 Jan 1970/);
    assert.match(deleted.headers['set-cookie'], /; Secure$/);

    const listed = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      { app, session: 'b' },
    );
    const retained = listed.body.items.find(
      (item) => item.id === created.body.id,
    );
    assert.equal('submittedByUserId' in retained, false);
    assert.equal(retained.isMine, false);
    assert.equal(retained.submittedByDisplayName, 'Utente rimosso');
    assert.equal(retained.votesUp, 0);
    assert.equal(retained.votesDown, 1);
    assert.equal(retained.myVote, 'down');

    const predictions = await fetchJson(
      '/v1/turns/turn-bologna-today/predictions',
      { app, session: 'a' },
    );
    const results = await fetchJson(
      '/v1/turns/turn-bologna-today/prediction-results',
      { app, session: 'a' },
    );
    const insight = await fetchJson(
      '/v1/problems/problem-green-margherita/insight',
      { app, session: 'b' },
    );
    assert.deepEqual(predictions.body.items, []);
    assert.deepEqual(results.body.items, []);
    assert.equal(insight.body.totalPredictions, 1);
    assert.match(predictions.headers['set-cookie'], /^mp_anon=v1\./);
    assert.notEqual(predictions.headers['set-cookie'], originalCookie);
  });

  it('rejects unsafe suggestion content before storing it', async () => {
    const app = createApp();
    const samples = [
      ['Contattami', 'Scrivi a mario@example.test per i dettagli.'],
      ['Foto del problema', 'Guarda https://example.test/foto'],
      ['Titolo offensivo', 'Questa strada e una merda.'],
    ];

    for (const [title, description] of samples) {
      const response = await fetchJson(
        '/v1/municipalities/bologna/next-problems',
        {
          app,
          method: 'POST',
          body: { title, description, category: 'decor' },
        },
      );
      assert.equal(response.status, 422);
      assert.equal(response.body.error, 'content_rejected');
    }
    const listed = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      { app },
    );
    assert.equal(listed.body.items.length, 1);
  });

  it('rate limits repeated submissions for the same anonymous identity', async () => {
    const app = createApp();
    for (let index = 0; index < 3; index += 1) {
      const response = await fetchJson(
        '/v1/municipalities/bologna/next-problems',
        {
          app,
          method: 'POST',
          body: {
            title: `Tema civico ${index}`,
            description: `Descrizione civica ${index}`,
            category: 'decor',
          },
        },
      );
      assert.equal(response.status, 201);
    }
    const limited = await fetchJson(
      '/v1/municipalities/bologna/next-problems',
      {
        app,
        method: 'POST',
        body: {
          title: 'Tema civico oltre il limite',
          description: 'Descrizione civica oltre il limite.',
          category: 'decor',
        },
      },
    );
    assert.equal(limited.status, 429);
    assert.equal(limited.body.error, 'submission_rate_limited');
  });

  it('requires an authorized moderator before promotion in pilot mode', async () => {
    const moderationAdminToken = 'moderation-test-token-at-least-32-bytes';
    const store = createMemoryStore({ moderationRequired: true });
    const app = createApp({ store, moderationAdminToken });
    const created = await fetchJson(
      '/v1/municipalities/castel-bolognese/next-problems',
      {
        app,
        method: 'POST',
        body: {
          title: 'Passaggio protetto davanti alla scuola',
          description: 'La proposta attende la verifica del moderatore.',
          category: 'safety',
        },
      },
    );
    const voted = await fetchJson(
      `/v1/municipalities/castel-bolognese/next-problems/${created.body.id}/votes`,
      { app, method: 'POST', body: { vote: 'up' } },
    );
    assert.equal(voted.body.status, 'pending');

    const moderationPath =
      `/v1/admin/municipalities/castel-bolognese/next-problems/` +
      `${created.body.id}/moderation`;
    const unauthorized = await fetchJson(moderationPath, {
      app,
      method: 'POST',
      body: { status: 'approved' },
    });
    assert.equal(unauthorized.status, 401);

    const approved = await fetchJson(moderationPath, {
      app,
      method: 'POST',
      headers: { authorization: `Bearer ${moderationAdminToken}` },
      body: { status: 'approved', reason: 'Verifica operatore completata.' },
    });
    assert.equal(approved.status, 200);
    assert.equal(approved.body.status, 'approved');
    assert.equal(typeof approved.body.moderatedAt, 'string');

    const problems = await fetchJson(
      '/v1/municipalities/castel-bolognese/problems',
      { app },
    );
    assert.equal(
      problems.body.items.some(
        (problem) => problem.id === `proposal_${created.body.id}`,
      ),
      true,
    );
  });

  it('limits a configured pilot to one municipality', async () => {
    const app = createApp({ pilotMunicipalityId: 'castel-bolognese' });
    const pilot = await fetchJson(
      '/v1/municipalities/castel-bolognese/activation',
      { app },
    );
    const outside = await fetchJson('/v1/municipalities/bologna/activation', {
      app,
    });
    const outsideProblem = await fetchJson(
      '/v1/problems/problem-green-margherita/insight',
      { app },
    );

    assert.equal(pilot.status, 200);
    assert.equal(outside.status, 404);
    assert.equal(outsideProblem.status, 404);
  });

  it('keeps the original prediction resolution happy path', async () => {
    const app = createApp();
    await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita',
      { app, method: 'PUT', body: { choice: 'improve' } },
    );
    const result = await fetchJson(
      '/v1/problems/problem-green-margherita/resolve',
      { app, method: 'POST', body: { choice: 'improve' } },
    );

    assert.equal(result.status, 200);
    assert.equal(result.body.correct, true);
    assert.equal(result.body.result, 'correct');
    assert.equal(result.body.pointsDelta, 10);
    assert.equal(result.body.winningChoice, 'improve');
  });

  it('stores prediction results and reputation independently by user', async () => {
    const app = createApp();
    const predictionPath =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    const resolutionPath =
      '/v1/problems/problem-green-margherita/resolve';

    await fetchJson(predictionPath, {
      app,
      method: 'PUT',
      session: 'a',
      body: { choice: 'improve', userId: 'user-a' },
    });
    await fetchJson(predictionPath, {
      app,
      method: 'PUT',
      session: 'b',
      body: { choice: 'worsen', userId: 'user-b' },
    });
    await fetchJson(resolutionPath, {
      app,
      method: 'POST',
      session: 'a',
      body: { choice: 'improve', userId: 'user-a' },
    });
    await fetchJson(resolutionPath, {
      app,
      method: 'POST',
      session: 'b',
      body: { choice: 'worsen', userId: 'user-b' },
    });

    const resultsA = await fetchJson(
      '/v1/turns/turn-bologna-today/prediction-results?userId=user-a',
      { app, session: 'a' },
    );
    const resultsB = await fetchJson(
      '/v1/turns/turn-bologna-today/prediction-results?userId=user-b',
      { app, session: 'b' },
    );
    const reputationA = await fetchJson(
      '/v1/turns/turn-bologna-today/reputation?userId=user-a',
      { app, session: 'a' },
    );
    const reputationB = await fetchJson(
      '/v1/turns/turn-bologna-today/reputation?userId=user-b',
      { app, session: 'b' },
    );
    const summaryA = await fetchJson(
      '/v1/municipalities/bologna/summary?userId=user-a',
      { app, session: 'a' },
    );

    assert.deepEqual(resultsA.body.items, [
      { problemId: 'problem-green-margherita', result: 'correct' },
    ]);
    assert.deepEqual(resultsB.body.items, [
      { problemId: 'problem-green-margherita', result: 'wrong' },
    ]);
    assert.deepEqual(reputationA.body, {
      totalPoints: 10,
      accuracy: 1,
      predictionsCount: 1,
    });
    assert.deepEqual(reputationB.body, {
      totalPoints: 0,
      accuracy: 0,
      predictionsCount: 1,
    });
    assert.equal(summaryA.body.outcomes, 1);
    assert.equal(summaryA.body.reputationPoints, 10);
  });

  it('computes partial results and exposes municipality reputation history', async () => {
    const app = createApp();
    await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita',
      {
        app,
        method: 'PUT',
        body: { choice: 'stable', userId: 'user-a' },
      },
    );
    await fetchJson(
      '/v1/turns/turn-bologna-today/predictions/problem-traffic-indipendenza',
      {
        app,
        method: 'PUT',
        body: { choice: 'improve', userId: 'user-a' },
      },
    );
    await fetchJson('/v1/problems/problem-green-margherita/resolve', {
      app,
      method: 'POST',
      body: { choice: 'stable', userId: 'user-a' },
    });
    await fetchJson('/v1/problems/problem-traffic-indipendenza/resolve', {
      app,
      method: 'POST',
      body: { choice: 'improve', userId: 'user-a' },
    });

    const results = await fetchJson(
      '/v1/turns/turn-bologna-today/prediction-results?userId=user-a',
      { app },
    );
    const history = await fetchJson(
      '/v1/municipalities/bologna/reputation-history?userId=user-a',
      { app },
    );

    assert.deepEqual(
      results.body.items.map((item) => item.result).sort(),
      ['partial', 'wrong'],
    );
    assert.deepEqual(history.body.items, [
      { totalPoints: 4, accuracy: 0.25, predictionsCount: 2 },
    ]);
  });

  it('aggregates predictions into current and historical insights', async () => {
    const app = createApp();
    const path =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    await fetchJson(path, {
      app,
      method: 'PUT',
      session: 'a',
      body: {
        choice: 'improve',
        motivations: ['visibleActions'],
        userId: 'user-a',
      },
    });
    await fetchJson(path, {
      app,
      method: 'PUT',
      session: 'b',
      body: {
        choice: 'improve',
        motivations: ['visibleActions', 'seasonality'],
        userId: 'user-b',
      },
    });
    await fetchJson(path, {
      app,
      method: 'PUT',
      session: 'c',
      body: {
        choice: 'stable',
        motivations: ['personalExperience'],
        userId: 'user-c',
      },
    });

    const insight = await fetchJson(
      '/v1/problems/problem-green-margherita/insight',
      { app },
    );
    const history = await fetchJson(
      '/v1/problems/problem-green-margherita/insight-history',
      { app },
    );

    assert.equal(insight.body.totalPredictions, 3);
    assert.deepEqual(insight.body.choiceDistribution, {
      improve: 2,
      stable: 1,
      worsen: 0,
    });
    assert.equal(insight.body.motivationDistribution.visibleActions, 2);
    assert.equal(history.body.snapshots.length, 1);
    assert.equal(history.body.snapshots[0].turnId, 'turn-bologna-today');
    assert.deepEqual(history.body.snapshots[0].motivationTop, [
      'visibleActions',
      'personalExperience',
    ]);
  });

  it('suppresses aggregates below the configured privacy threshold', () => {
    const store = createMemoryStore({ minimumAggregateSampleSize: 3 });
    for (const userId of ['anon:first', 'anon:second']) {
      store.upsertPrediction({
        turnId: 'turn-bologna-today',
        problemId: 'problem-green-margherita',
        userId,
        choice: 'improve',
        motivations: ['visibleActions'],
        confidence: 'considered',
      });
    }

    const suppressed = store.getAggregatedInsight(
      'problem-green-margherita',
    );
    assert.equal(suppressed.totalPredictions, 0);
    assert.deepEqual(suppressed.choiceDistribution, {
      improve: 0,
      stable: 0,
      worsen: 0,
    });

    store.upsertPrediction({
      turnId: 'turn-bologna-today',
      problemId: 'problem-green-margherita',
      userId: 'anon:third',
      choice: 'stable',
      motivations: ['seasonality'],
      confidence: 'gutFeeling',
    });
    const visible = store.getAggregatedInsight('problem-green-margherita');
    assert.equal(visible.totalPredictions, 3);
    assert.deepEqual(visible.choiceDistribution, {
      improve: 2,
      stable: 1,
      worsen: 0,
    });
  });

  it('returns critical insights and validates their optional context', async () => {
    const app = createApp();
    const empty = await fetchJson(
      '/v1/problems/problem-green-margherita/critical-insights',
      { app },
    );
    assert.equal(empty.body.items[0].headline, 'Dati in raccolta');

    const predictionPath =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    await fetchJson(predictionPath, {
      app,
      method: 'PUT',
      session: 'a',
      body: { choice: 'improve', userId: 'user-a' },
    });
    const contextual = await fetchJson(
      '/v1/problems/problem-green-margherita/critical-insights' +
        '?userChoice=improve&userConfidence=considered&userReflectionIndex=1',
      { app },
    );
    const invalid = await fetchJson(
      '/v1/problems/problem-green-margherita/critical-insights' +
        '?userReflectionIndex=outside',
      { app },
    );

    assert.equal(contextual.status, 200);
    assert.equal(contextual.body.items.length, 3);
    assert.match(contextual.body.items[0].supporting, /^100%/);
    assert.equal(invalid.status, 400);
    assert.equal(invalid.body.error, 'invalid_field');
  });

  it('returns stable not-found errors for result and insight resources', async () => {
    const missingTurnResults = await fetchJson(
      '/v1/turns/missing/prediction-results',
    );
    const missingTurnReputation = await fetchJson(
      '/v1/turns/missing/reputation',
    );
    const missingProblemInsight = await fetchJson(
      '/v1/problems/missing/insight',
    );

    assert.equal(missingTurnResults.body.error, 'turn_not_found');
    assert.equal(missingTurnReputation.body.error, 'turn_not_found');
    assert.equal(missingProblemInsight.body.error, 'problem_not_found');
  });

  it('resolves only the prediction saved for the same user and choice', async () => {
    const app = createApp();
    const predictionPath =
      '/v1/turns/turn-bologna-today/predictions/problem-green-margherita';
    await fetchJson(predictionPath, {
      app,
      method: 'PUT',
      session: 'a',
      body: { choice: 'improve', userId: 'user-a' },
    });

    const missing = await fetchJson(
      '/v1/problems/problem-green-margherita/resolve',
      {
        app,
        method: 'POST',
        session: 'b',
        body: { choice: 'improve', userId: 'user-b' },
      },
    );
    const mismatch = await fetchJson(
      '/v1/problems/problem-green-margherita/resolve',
      {
        app,
        method: 'POST',
        session: 'a',
        body: { choice: 'worsen', userId: 'user-a' },
      },
    );

    assert.equal(missing.status, 404);
    assert.equal(missing.body.error, 'prediction_not_found');
    assert.equal(mismatch.status, 409);
    assert.equal(mismatch.body.error, 'prediction_choice_mismatch');
  });
});

const cookiesByApp = new WeakMap();

async function fetchJson(path, options = {}) {
  const app = options.app ?? createApp();
  const session = options.session ?? 'default';
  let sessionCookies = cookiesByApp.get(app);
  if (!sessionCookies) {
    sessionCookies = new Map();
    cookiesByApp.set(app, sessionCookies);
  }
  const rawBody =
    options.rawBody ??
    (Object.hasOwn(options, 'body') ? JSON.stringify(options.body) : '');
  const req = Readable.from(rawBody ? [Buffer.from(rawBody)] : []);
  req.method = options.method ?? 'GET';
  req.url = path;
  const requestHeaders = { ...options.headers };
  if (!Object.hasOwn(requestHeaders, 'cookie')) {
    const cookie = sessionCookies.get(session);
    if (cookie) requestHeaders.cookie = cookie;
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

  const setCookie = res.headers['set-cookie'];
  if (typeof setCookie === 'string') {
    sessionCookies.set(session, setCookie.split(';', 1)[0]);
  }

  return {
    status: res.statusCode,
    headers: res.headers,
    body: JSON.parse(res.payload),
  };
}

async function closeServer(server) {
  if (!server.listening) return;
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}
