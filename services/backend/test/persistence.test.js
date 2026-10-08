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
    assert.equal(firstStore.persistence.schemaVersion, 3);
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

it('persists anonymous session erasure across restarts', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'migliorapaese-erasure-'));
  const databasePath = join(directory, 'pilot.sqlite');
  let firstStore;
  let secondStore;
  try {
    firstStore = createPersistentStore({
      databasePath,
      moderationRequired: true,
    });
    const userId = 'anon:test-user';
    const suggestion = firstStore.submitNextProblem({
      municipalityId: 'castel-bolognese',
      title: 'Area ombreggiata',
      description: 'Una proposta da conservare senza legame alla sessione.',
      category: 'green',
      userId,
    });
    firstStore.voteNextProblem({
      municipalityId: 'castel-bolognese',
      problemId: suggestion.id,
      vote: 'up',
      userId,
    });
    firstStore.upsertPrediction({
      turnId: 'turn-bologna-today',
      problemId: 'problem-green-margherita',
      userId,
      choice: 'improve',
      motivations: [],
      confidence: null,
    });
    firstStore.resolvePrediction({
      problemId: 'problem-green-margherita',
      userId,
      choice: 'improve',
    });

    assert.deepEqual(firstStore.deleteUserData(userId), {
      suggestions: 1,
      votes: 1,
      predictions: 1,
      predictionResults: 1,
    });
    firstStore.close();
    firstStore = null;

    secondStore = createPersistentStore({ databasePath });
    const retained = secondStore
      .listNextProblems({
        municipalityId: 'castel-bolognese',
        userId: 'anon:other-user',
      })
      .find((item) => item.id === suggestion.id);
    assert.equal(retained.submittedByUserId, 'deleted');
    assert.equal(retained.votesUp, 0);
    assert.deepEqual(
      secondStore.getPredictions({
        turnId: 'turn-bologna-today',
        userId,
      }),
      [],
    );
    assert.deepEqual(
      secondStore.getPredictionResults({
        turnId: 'turn-bologna-today',
        userId,
      }),
      [],
    );
  } finally {
    firstStore?.close();
    secondStore?.close();
    await rm(directory, { recursive: true, force: true });
  }
});
