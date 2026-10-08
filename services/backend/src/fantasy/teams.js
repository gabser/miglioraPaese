import { transaction } from './transaction.js';

const initialSquad = ['buche-centro', 'bus-stazione', 'parco-nord', 'rifiuti-mercato', 'lampioni-sud', 'attraversamenti-scuole', 'alberi-viale', 'sportello-anagrafe'];
const roles = ['mobility', 'environment', 'servicesAndSafety'];
const trends = ['improves', 'stable', 'worsens'];

export function migrateFantasyTeams(database) {
  database.exec(`
    CREATE TABLE fantasy_players (
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      user_id TEXT NOT NULL,
      revision INTEGER NOT NULL CHECK (revision > 0),
      squad_ids TEXT NOT NULL CHECK (json_valid(squad_ids)),
      created_at TEXT NOT NULL,
      PRIMARY KEY (season_id, user_id)
    ) STRICT;
    CREATE TABLE fantasy_drafts (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      PRIMARY KEY (season_id, user_id, matchday_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    ) STRICT;
    CREATE TABLE fantasy_snapshots (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      PRIMARY KEY (season_id, user_id, matchday_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    ) STRICT;
  `);
}

export function teamsSchemaReady(database) {
  database.prepare('SELECT season_id, user_id, revision, squad_ids, created_at FROM fantasy_players LIMIT 1').get();
  database.prepare('SELECT season_id, user_id, matchday_id, payload FROM fantasy_drafts LIMIT 1').get();
  database.prepare('SELECT season_id, user_id, matchday_id, payload FROM fantasy_snapshots LIMIT 1').get();
  return true;
}

export function fantasyError(statusCode, code, message) {
  return Object.assign(new Error(message), { statusCode, code });
}
function requireValue(valid, message) {
  if (!valid) throw fantasyError(400, 'invalid_field', message);
}
export function exactFields(body, fields) {
  requireValue(body && typeof body === 'object' && !Array.isArray(body) && Object.keys(body).every((key) => fields.includes(key)), 'Unsupported command field.');
}

export function createFantasyTeams({ database, now = Date.now, catalog, getTransferPenalty = () => 0, getTransferData = () => ({}) }) {
  const isoNow = () => new Date(now()).toISOString();
  const seasonFor = (municipalityId) => database.prepare('SELECT * FROM fantasy_seasons WHERE municipality_id = ? ORDER BY starts_at DESC LIMIT 1').get(municipalityId)
    ?? missing();
  const playerFor = (seasonId, userId) => database.prepare('SELECT * FROM fantasy_players WHERE season_id = ? AND user_id = ?').get(seasonId, userId)
    ?? missing('Season enrollment required.');
  const daysFor = (seasonId) => database.prepare('SELECT * FROM fantasy_matchdays WHERE season_id = ? ORDER BY number').all(seasonId);
  function missing(message = 'Fantasy resource not found.') { throw fantasyError(404, 'not_found', message); }
  function dayFor(seasonId, matchdayId, time) {
    const days = daysFor(seasonId);
    return (matchdayId ? days.find((d) => d.id === matchdayId) : days.find((d) => d.observation_ends_at > time) ?? days.at(-1)) ?? missing();
  }
  function cardsFor(season) { return new Map(catalog(season.municipality_id).items.map((card) => [card.id, card])); }
  function validSquad(ids, cards) {
    return Array.isArray(ids) && ids.length === 8 && new Set(ids).size === 8 && ids.every((id) => typeof id === 'string' && cards.has(id))
      && ids.reduce((sum, id) => sum + cards.get(id).price, 0) <= 100
      && roles.every((role) => ids.filter((id) => cards.get(id).role === role).length >= 2);
  }
  function validLineup(draft, squad, cards) {
    return Array.isArray(draft.starterIds) && draft.starterIds.length === 5 && new Set(draft.starterIds).size === 5
      && draft.starterIds.every((id) => squad.includes(id)) && draft.starterIds.includes(draft.captainId)
      && roles.every((role) => draft.starterIds.some((id) => cards.get(id).role === role));
  }
  function defaultDraft(player, cards) {
    const squad = JSON.parse(player.squad_ids);
    const starters = roles.map((role) => squad.find((id) => cards.get(id).role === role));
    for (const id of squad) { if (starters.length < 5 && !starters.includes(id)) starters.push(id); }
    return { starterIds: starters, captainId: starters[0], confirmed: false, predictions: {}, motivations: {} };
  }
  function draftFor(player, day, cards) {
    const row = database.prepare('SELECT payload FROM fantasy_drafts WHERE season_id = ? AND user_id = ? AND matchday_id = ?').get(player.season_id, player.user_id, day.id);
    return row ? JSON.parse(row.payload) : defaultDraft(player, cards);
  }
  function writeDraft(player, day, draft) {
    database.prepare(`INSERT INTO fantasy_drafts VALUES (?, ?, ?, ?) ON CONFLICT(season_id, user_id, matchday_id) DO UPDATE SET payload = excluded.payload`)
      .run(player.season_id, player.user_id, day.id, JSON.stringify(draft));
  }
  function reconcileInside(time) {
    for (const player of database.prepare('SELECT * FROM fantasy_players').all()) {
      const season = database.prepare('SELECT * FROM fantasy_seasons WHERE id = ?').get(player.season_id);
      const cards = cardsFor(season);
      for (const day of daysFor(player.season_id)) {
        if (time < day.locks_at || player.created_at >= day.observation_ends_at) continue;
        const exists = database.prepare('SELECT 1 FROM fantasy_snapshots WHERE season_id = ? AND user_id = ? AND matchday_id = ?').get(player.season_id, player.user_id, day.id);
        if (exists) continue;
        const squad = JSON.parse(player.squad_ids);
        const draft = draftFor(player, day, cards);
        const snapshot = { matchdayId: day.id, seasonId: season.id, rulesVersion: day.rules_version, catalogVersion: season.catalog_version,
          locksAt: day.locks_at, observationEndsAt: day.observation_ends_at,
          squadIds: squad, ...draft, transferPenalty: getTransferPenalty(player, day),
          eligible: player.created_at < day.locks_at && draft.confirmed && validSquad(squad, cards) && validLineup(draft, squad, cards) };
        database.prepare('INSERT INTO fantasy_snapshots VALUES (?, ?, ?, ?)').run(player.season_id, player.user_id, day.id, JSON.stringify(snapshot));
      }
    }
  }
  function reconcile() { return transaction(database, () => reconcileInside(isoNow())); }
  function view(season, player, day, time) {
    const cards = cardsFor(season);
    const squad = JSON.parse(player.squad_ids);
    const draft = draftFor(player, day, cards);
    const snapshots = database.prepare('SELECT payload FROM fantasy_snapshots WHERE season_id = ? AND user_id = ? ORDER BY matchday_id').all(season.id, player.user_id).map((row) => JSON.parse(row.payload));
    return { serverTime: time, isDemo: Boolean(season.is_demo), seasonId: season.id, matchdayId: day.id, revision: player.revision,
      ...getTransferData(player, day), team: { squadIds: squad, ...draft, budgetRemaining: 100 - squad.reduce((sum, id) => sum + cards.get(id).price, 0) }, snapshots };
  }
  function checkRevision(player, revision) {
    requireValue(Number.isSafeInteger(revision) && revision > 0, 'expectedRevision must be a positive integer.');
    if (player.revision !== revision) throw fantasyError(409, 'stale_revision', 'Team revision has changed. Reload before retrying.');
  }
  function assertOpen(day, time, player) {
    const frozen = database.prepare('SELECT 1 FROM fantasy_snapshots WHERE season_id = ? AND user_id = ? AND matchday_id = ?').get(player.season_id, player.user_id, day.id);
    if (frozen) throw fantasyError(409, 'matchday_locked', 'Matchday is already frozen.');
    if (time >= day.locks_at) throw fantasyError(409, 'matchday_locked', 'Matchday is locked.');
    if (time < day.starts_at) throw fantasyError(409, 'matchday_not_open', 'Matchday has not started.');
  }
  function withOpenTeam(municipalityId, userId, revision, matchdayId, action) {
    requireValue(typeof matchdayId === 'string' && matchdayId.length > 0, 'matchdayId is required.');
    reconcile();
    return transaction(database, () => {
      const time = isoNow();
      const season = seasonFor(municipalityId);
      const player = playerFor(season.id, userId);
      const day = dayFor(season.id, matchdayId, time);
      checkRevision(player, revision);
      assertOpen(day, time, player);
      const cards = cardsFor(season);
      return action({ season, player, day, time, cards, squad: JSON.parse(player.squad_ids), draft: draftFor(player, day, cards) });
    });
  }

  function mutate(municipalityId, userId, body, confirm) {
    // Reconcile in its own committed transaction: a rejected late command must
    // still leave the last accepted formation frozen.
    reconcile();
    return transaction(database, () => {
      const time = isoNow();
      exactFields(body, confirm ? ['expectedRevision', 'matchdayId'] : ['expectedRevision', 'matchdayId', 'starterIds', 'captainId', 'predictions', 'motivations']);
      requireValue(typeof body.matchdayId === 'string', 'matchdayId is required.');
      const season = seasonFor(municipalityId);
      const player = playerFor(season.id, userId);
      const day = dayFor(season.id, body.matchdayId, time);
      checkRevision(player, body.expectedRevision);
      assertOpen(day, time, player); // Checked using server time inside the write transaction.
      const cards = cardsFor(season);
      const squad = JSON.parse(player.squad_ids);
      const previous = draftFor(player, day, cards);
      const draft = confirm ? { ...previous, confirmed: true } : { ...previous,
        starterIds: body.starterIds, captainId: body.captainId, predictions: body.predictions, motivations: body.motivations };
      requireValue(validSquad(squad, cards) && validLineup(draft, squad, cards), 'Invalid squad, roles, captain or lineup.');
      for (const [field, values] of [['predictions', trends], ['motivations', null]]) {
        const map = draft[field];
        requireValue(map && typeof map === 'object' && !Array.isArray(map) && Object.keys(map).every((id) => draft.starterIds.includes(id)), `${field} must contain only starter card IDs.`);
        for (const value of Object.values(map)) requireValue(values ? values.includes(value) : typeof value === 'string' && value.length <= 1000, `Invalid ${field} value.`);
      }
      if (!confirm && (JSON.stringify(previous.starterIds) !== JSON.stringify(draft.starterIds) || previous.captainId !== draft.captainId)) draft.confirmed = false;
      writeDraft(player, day, draft);
      database.prepare('UPDATE fantasy_players SET revision = revision + 1 WHERE season_id = ? AND user_id = ?').run(season.id, userId);
      return view(season, playerFor(season.id, userId), day, time);
    });
  }
  const api = {
    enroll(municipalityId, userId, body) {
      exactFields(body, ['squadIds']);
      reconcile();
      return transaction(database, () => {
        const time = isoNow();
        const season = seasonFor(municipalityId);
        const day = dayFor(season.id, null, time);
        let player = database.prepare('SELECT * FROM fantasy_players WHERE season_id = ? AND user_id = ?').get(season.id, userId);
        if (!player) {
          if (time >= season.ends_at) throw fantasyError(409, 'season_ended', 'Season has ended.');
          const ids = body.squadIds ?? initialSquad;
          const cards = cardsFor(season);
          requireValue(validSquad(ids, cards), 'Squad requires eight unique cards, roles and a budget of 100 credits.');
          requireValue(ids.every((id) => cards.get(id).availability === 'available' && cards.get(id).sourceStatus !== 'unavailable'), 'A squad card is unavailable.');
          database.prepare('INSERT INTO fantasy_players VALUES (?, ?, 1, ?, ?)').run(season.id, userId, JSON.stringify(ids), time);
          player = playerFor(season.id, userId);
          writeDraft(player, day, defaultDraft(player, cards));
          reconcileInside(time);
        }
        return view(season, player, day, time);
      });
    },
    team(municipalityId, userId, matchdayId = null) {
      reconcile();
      const time = isoNow();
      const season = seasonFor(municipalityId);
      return view(season, playerFor(season.id, userId), dayFor(season.id, matchdayId, time), time);
    },
    update: (municipalityId, userId, body) => mutate(municipalityId, userId, body, false),
    confirm: (municipalityId, userId, body) => mutate(municipalityId, userId, body, true),
    withOpenTeam, seasonFor, playerFor, dayFor, validSquad, writeDraft, view,
    reconcile,
    erase(userId) { database.prepare('DELETE FROM fantasy_players WHERE user_id = ?').run(userId); },
  };
  reconcile(); // Recovery also occurs when the process was stopped at the deadline.
  return api;
}
