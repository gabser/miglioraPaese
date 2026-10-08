import { randomUUID } from 'node:crypto';
import { exactFields, fantasyError } from './teams.js';
import { transaction } from './transaction.js';

export function scoreFantasyCard({ observed, prediction = null, captain = false, reflection = false }) {
  const observationPoints = observed === 'improves' ? 4 : observed === 'stable' ? 1 : 0;
  const predictionPoints = prediction == null ? 0 : prediction === observed ? 4 : prediction === 'stable' || observed === 'stable' ? 2 : 0;
  const captainMultiplier = captain ? 1.5 : 1;
  const reflectionPoints = reflection ? 1 : 0;
  const frozenTotal = Math.round((observationPoints + predictionPoints) * captainMultiplier);
  const total = Math.round((observationPoints + predictionPoints + reflectionPoints) * captainMultiplier);
  return { observationPoints, predictionPoints, reflectionPoints, captainMultiplier, frozenTotal, reflectionBonus: total - frozenTotal, total };
}

export function migrateFantasyResults(database) {
  database.exec(`
    CREATE TABLE fantasy_outcomes (
      season_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      card_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      PRIMARY KEY (season_id, matchday_id, card_id),
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id),
      FOREIGN KEY (season_id, card_id) REFERENCES fantasy_cards(season_id, id)
    ) STRICT;
    CREATE TABLE fantasy_reveals (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      card_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      PRIMARY KEY (season_id, user_id, matchday_id, card_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id, card_id) REFERENCES fantasy_outcomes(season_id, matchday_id, card_id)
    ) STRICT;
    CREATE TABLE fantasy_finalizations (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      finalized_at TEXT NOT NULL,
      PRIMARY KEY (season_id, user_id, matchday_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    ) STRICT;
    CREATE TABLE fantasy_reflections (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      card_id TEXT NOT NULL,
      answer TEXT NOT NULL CHECK (answer IN ('observedIntervention', 'externalConditions', 'insufficientInformation')),
      created_at TEXT NOT NULL,
      PRIMARY KEY (season_id, user_id, matchday_id, card_id),
      FOREIGN KEY (season_id, user_id, matchday_id, card_id) REFERENCES fantasy_reveals(season_id, user_id, matchday_id, card_id) ON DELETE CASCADE
    ) STRICT;
  `);
}

export function resultsSchemaReady(database) {
  database.prepare('SELECT season_id, user_id, matchday_id, finalized_at FROM fantasy_finalizations LIMIT 1').get();
  database.prepare('SELECT season_id, matchday_id, card_id, payload FROM fantasy_outcomes LIMIT 1').get();
  database.prepare('SELECT season_id, user_id, matchday_id, card_id, payload FROM fantasy_reveals LIMIT 1').get();
  database.prepare('SELECT season_id, user_id, matchday_id, card_id, answer, created_at FROM fantasy_reflections LIMIT 1').get();
}

export function createFantasyResults({ database, teams, catalog, now = Date.now }) {
  const isoNow = () => new Date(now()).toISOString();
  function fail(code, message, status = 409) { throw fantasyError(status, code, message); }
  function context(municipalityId, userId, matchdayId, time) {
    const season = teams.seasonFor(municipalityId);
    return { season, player: teams.playerFor(season.id, userId), day: teams.dayFor(season.id, matchdayId, time), time };
  }
  function snapshotFor(c) {
    const row = database.prepare('SELECT payload FROM fantasy_snapshots WHERE season_id = ? AND user_id = ? AND matchday_id = ?')
      .get(c.season.id, c.player.user_id, c.day.id);
    return row ? JSON.parse(row.payload) : null;
  }
  function freeze(c) {
    const snapshot = snapshotFor(c);
    if (!snapshot?.eligible || c.time < c.day.observation_ends_at) return;
    const insert = database.prepare('INSERT INTO fantasy_reveals VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING');
    for (const cardId of snapshot.starterIds) {
      const row = database.prepare('SELECT payload FROM fantasy_outcomes WHERE season_id = ? AND matchday_id = ? AND card_id = ?').get(c.season.id, c.day.id, cardId);
      if (!row) continue;
      const outcome = JSON.parse(row.payload);
      const prediction = snapshot.predictions[cardId] ?? null;
      const score = scoreFantasyCard({ observed: outcome.observed, prediction, captain: snapshot.captainId === cardId });
      insert.run(c.season.id, c.player.user_id, c.day.id, cardId, JSON.stringify({ cardId, matchdayId: c.day.id,
        outcome, prediction, score, rulesVersion: snapshot.rulesVersion }));
    }
  }
  function view(c) {
    const snapshot = snapshotFor(c);
    const outcomes = database.prepare('SELECT payload FROM fantasy_outcomes WHERE season_id = ? AND matchday_id = ? ORDER BY card_id').all(c.season.id, c.day.id).map((row) => JSON.parse(row.payload));
    const results = database.prepare('SELECT payload FROM fantasy_reveals WHERE season_id = ? AND user_id = ? AND matchday_id = ? ORDER BY card_id')
      .all(c.season.id, c.player.user_id, c.day.id).map((row) => {
        const result = JSON.parse(row.payload);
        const reflection = database.prepare('SELECT answer FROM fantasy_reflections WHERE season_id = ? AND user_id = ? AND matchday_id = ? AND card_id = ?')
          .get(c.season.id, c.player.user_id, c.day.id, result.cardId);
        const score = reflection ? scoreFantasyCard({ observed: result.outcome.observed, prediction: result.prediction, captain: result.score.captainMultiplier === 1.5, reflection: true }) : result.score;
        return { ...result, reflection: reflection?.answer ?? null, score: { ...score, frozenTotal: result.score.frozenTotal } };
      });
    const frozenPoints = results.reduce((sum, r) => sum + r.score.frozenTotal, 0);
    const reflectionBonus = results.reduce((sum, r) => sum + r.score.reflectionBonus, 0);
    const eligible = Boolean(snapshot?.eligible);
    const transferPenalty = snapshot?.transferPenalty ?? 0;
    const canFinalize = c.time >= c.day.observation_ends_at && snapshot != null && (!eligible || results.length === snapshot.starterIds.length);
    if (canFinalize) database.prepare('INSERT INTO fantasy_finalizations VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING').run(c.season.id, c.player.user_id, c.day.id, c.time);
    const definitive = Boolean(database.prepare('SELECT 1 FROM fantasy_finalizations WHERE season_id = ? AND user_id = ? AND matchday_id = ?').get(c.season.id, c.player.user_id, c.day.id));
    return { serverTime: c.time, isDemo: Boolean(c.season.is_demo), seasonId: c.season.id, matchdayId: c.day.id, revision: c.player.revision,
      outcomes, results, summary: { status: definitive ? 'final' : 'provisional', eligible, frozenPoints, reflectionBonus, transferPenalty,
        total: eligible ? frozenPoints + reflectionBonus - transferPenalty : 0, cooperativeScore: null } };
  }
  return {
    publish(municipalityId, matchdayId, cardId, body) {
      exactFields(body, ['observed', 'sourceLabel', 'sourceDate', 'sourceStatus', 'explanation', 'rulesVersion', 'version']);
      return transaction(database, () => {
        const time = isoNow();
        const season = teams.seasonFor(municipalityId);
        const day = teams.dayFor(season.id, matchdayId, time);
        const card = catalog(municipalityId).items.find((c) => c.id === cardId);
        if (!card) fail('not_found', 'Card not found.', 404);
        if (!['improves', 'stable', 'worsens'].includes(body.observed) || body.version !== 1 || body.rulesVersion !== day.rules_version || typeof body.explanation !== 'string' || body.explanation.length < 1 || body.explanation.length > 1000) {
          fail('invalid_field', 'Invalid outcome, rules version or explanation.', 400);
        }
        if (body.sourceStatus !== 'verified' || card.sourceStatus !== 'verified' || body.sourceLabel !== card.sourceLabel) fail('source_not_verified', 'An authorized verified catalog source is required.');
        const dateValue = typeof body.sourceDate === 'string' && /(?:Z|[+-]\d{2}:\d{2})$/.test(body.sourceDate) ? Date.parse(body.sourceDate) : NaN;
        if (!Number.isFinite(dateValue) || dateValue < Date.parse(day.locks_at) || dateValue > Date.parse(day.observation_ends_at)) fail('invalid_field', 'Source date must be within the observation window and include a timezone.', 400);
        if (time < day.observation_ends_at || dateValue > Date.parse(time)) fail('observation_pending', 'Observation window has not ended.');
        const content = { matchdayId, cardId, observed: body.observed, sourceLabel: card.sourceLabel,
          sourceDate: new Date(dateValue).toISOString(), sourceStatus: 'verified', explanation: body.explanation,
          rulesVersion: body.rulesVersion, version: body.version, isDemo: Boolean(season.is_demo) };
        const row = database.prepare('SELECT payload FROM fantasy_outcomes WHERE season_id = ? AND matchday_id = ? AND card_id = ?').get(season.id, matchdayId, cardId);
        if (row) {
          const original = JSON.parse(row.payload);
          if (Object.entries(content).some(([key, value]) => original[key] !== value)) fail('outcome_immutable', 'Published outcomes cannot be overwritten.');
          return { serverTime: time, isDemo: Boolean(season.is_demo), outcome: original };
        }
        const outcome = { ...content, publicationId: randomUUID(), publishedAt: time, publisherRole: 'pilotModerator' };
        database.prepare('INSERT INTO fantasy_outcomes VALUES (?, ?, ?, ?)').run(season.id, matchdayId, cardId, JSON.stringify(outcome));
        return { serverTime: time, isDemo: Boolean(season.is_demo), outcome };
      });
    },
    read(municipalityId, userId, matchdayId) {
      teams.reconcile();
      return transaction(database, () => {
        const c = context(municipalityId, userId, matchdayId, isoNow());
        freeze(c);
        return view(c);
      });
    },
    reflect(municipalityId, userId, matchdayId, cardId, body) {
      exactFields(body, ['expectedRevision', 'answer']);
      if (!['observedIntervention', 'externalConditions', 'insufficientInformation'].includes(body.answer) || !Number.isSafeInteger(body.expectedRevision) || body.expectedRevision < 1) fail('invalid_field', 'Expected revision and a structured reflection answer are required.', 400);
      teams.reconcile();
      return transaction(database, () => {
        const c = context(municipalityId, userId, matchdayId, isoNow());
        const prior = database.prepare('SELECT answer FROM fantasy_reflections WHERE season_id = ? AND user_id = ? AND matchday_id = ? AND card_id = ?').get(c.season.id, userId, c.day.id, cardId);
        if (prior) {
          if (prior.answer !== body.answer) fail('reflection_immutable', 'A reflection was already accepted.');
          return view(c);
        }
        if (body.expectedRevision !== c.player.revision) fail('stale_revision', 'Team revision has changed.');
        const revealed = database.prepare('SELECT 1 FROM fantasy_reveals WHERE season_id = ? AND user_id = ? AND matchday_id = ? AND card_id = ?').get(c.season.id, userId, c.day.id, cardId);
        if (!revealed) fail('reflection_not_available', 'Reveal an eligible starter result before reflecting.');
        database.prepare('INSERT INTO fantasy_reflections VALUES (?, ?, ?, ?, ?, ?)').run(c.season.id, userId, c.day.id, cardId, body.answer, c.time);
        database.prepare('UPDATE fantasy_players SET revision = revision + 1 WHERE season_id = ? AND user_id = ?').run(c.season.id, userId);
        c.player = teams.playerFor(c.season.id, userId);
        return view(c);
      });
    },
  };
}
