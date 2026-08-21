import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { it } from 'node:test';

import { createPersistentStore } from '../src/server.js';

it('persists suggestions, votes, predictions and results across restarts', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'migliorapaese-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let firstStore;
  let secondStore;
  try {
    firstStore = createPersistentStore({ databasePath });
    const suggestion = firstStore.submitNextProblem({
      municipalityId: 'castel-bolognese',
      title: 'Attraversamento persistente',
      description: 'Serve maggiore visibilita.',
      category: 'safety',
      userId: 'anon:test-user',
    });
    firstStore.voteNextProblem({
      municipalityId: 'castel-bolognese',
      problemId: suggestion.id,
      vote: 'up',
      userId: 'anon:test-user',
    });
    firstStore.upsertPrediction({
      turnId: 'turn-bologna-today',
      problemId: 'problem-green-margherita',
      userId: 'anon:test-user',
      choice: 'improve',
      motivations: ['visibleActions'],
      confidence: 'considered',
    });
    firstStore.resolvePrediction({
      problemId: 'problem-green-margherita',
      userId: 'anon:test-user',
      choice: 'improve',
    });
    assert.equal(firstStore.persistence.schemaVersion, 1);
    firstStore.close();
    firstStore = null;

    secondStore = createPersistentStore({ databasePath });
    const restoredSuggestion = secondStore
      .listNextProblems({
        municipalityId: 'castel-bolognese',
        userId: 'anon:test-user',
      })
      .find((item) => item.id === suggestion.id);
    assert.equal(restoredSuggestion.myVote, 'up');
    assert.equal(restoredSuggestion.status, 'approved');
    assert.equal(
      secondStore.getPredictions({
        turnId: 'turn-bologna-today',
        userId: 'anon:test-user',
      }).length,
      1,
    );
    assert.deepEqual(
      secondStore.getPredictionResults({
        turnId: 'turn-bologna-today',
        userId: 'anon:test-user',
      }),
      [{ problemId: 'problem-green-margherita', result: 'correct' }],
    );
  } finally {
    firstStore?.close();
    secondStore?.close();
    await rm(directory, { recursive: true, force: true });
  }
});
