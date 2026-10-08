import { createFantasyResults, migrateFantasyResults, resultsSchemaReady } from './results.js';
import { createFantasyMarket, migrateFantasyMarket, marketSchemaReady, transferPenalty, transferData } from './market.js';
import { transaction } from './transaction.js';
export { transaction } from './transaction.js';
import { createFantasyTeams, migrateFantasyTeams, teamsSchemaReady } from './teams.js';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';

const fixtureCards = JSON.parse(readFileSync(new URL('./cards.demo.json', import.meta.url), 'utf8'));
const municipalities = ['bologna', 'castel-bolognese', 'tuglie'];
const dayMs = 24 * 60 * 60 * 1000;
export const fantasyRulesVersion = 'fantasy-demo-v1';
export const demoSeasonStartsAt = '2026-10-08T00:00:00.000Z';

export function migrateFantasy(database) {
  database.exec(`
    CREATE TABLE fantasy_seasons (
      id TEXT PRIMARY KEY,
      municipality_id TEXT NOT NULL,
      name TEXT NOT NULL,
      starts_at TEXT NOT NULL,
      ends_at TEXT NOT NULL,
      catalog_version INTEGER NOT NULL CHECK (catalog_version > 0),
      is_demo INTEGER NOT NULL CHECK (is_demo IN (0, 1)),
      CHECK (starts_at < ends_at),
      UNIQUE (municipality_id, starts_at)
    ) STRICT;
    CREATE TABLE fantasy_cards (
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      id TEXT NOT NULL,
      version INTEGER NOT NULL CHECK (version > 0),
      role TEXT NOT NULL CHECK (role IN ('mobility', 'environment', 'servicesAndSafety')),
      price INTEGER NOT NULL CHECK (price >= 0),
      availability TEXT NOT NULL CHECK (availability IN ('available', 'unavailable')),
      source_status TEXT NOT NULL CHECK (source_status IN ('verified', 'pending', 'unavailable')),
      payload TEXT NOT NULL CHECK (json_valid(payload)),
      PRIMARY KEY (season_id, id)
    ) STRICT;
    CREATE TABLE fantasy_matchdays (
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      id TEXT NOT NULL,
      number INTEGER NOT NULL CHECK (number BETWEEN 1 AND 8),
      starts_at TEXT NOT NULL,
      locks_at TEXT NOT NULL,
      observation_ends_at TEXT NOT NULL,
      rules_version TEXT NOT NULL,
      CHECK (starts_at < locks_at AND locks_at < observation_ends_at),
      PRIMARY KEY (season_id, id),
      UNIQUE (season_id, number)
    ) STRICT;
  `);
}

export function fantasySchemaReady(database, { includeTeams = true, includeMarket = true, includeResults = true } = {}) {
  // Also detects a damaged/missing table instead of accepting SELECT 1 alone.
  database.prepare('SELECT id, municipality_id, starts_at, ends_at, catalog_version, is_demo FROM fantasy_seasons LIMIT 1').get();
  database.prepare('SELECT season_id, id, version, role, price, availability, source_status, payload FROM fantasy_cards LIMIT 1').get();
  database.prepare('SELECT season_id, id, number, starts_at, locks_at, observation_ends_at, rules_version FROM fantasy_matchdays LIMIT 1').get();
  if (includeTeams) teamsSchemaReady(database);
  if (includeMarket) marketSchemaReady(database);
  if (includeResults) resultsSchemaReady(database);
  return database.prepare('PRAGMA foreign_key_check').all().length === 0;
}

export function createFantasyStore({ database, now = Date.now, seedStartsAt = demoSeasonStartsAt } = {}) {
  // Validate before opening a database so rejected fixture configuration leaks no handle.
  const startsAt = typeof seedStartsAt === 'string' && /(?:Z|[+-]\d{2}:\d{2})$/.test(seedStartsAt) ? Date.parse(seedStartsAt) : NaN;
  if (!Number.isFinite(startsAt)) throw new TypeError('seedStartsAt requires an ISO date with timezone.');
  const ownsDatabase = !database;
  database ??= new DatabaseSync(':memory:', { enableForeignKeyConstraints: true });
  if (ownsDatabase) { migrateFantasy(database); migrateFantasyTeams(database); migrateFantasyMarket(database); migrateFantasyResults(database); }
  // A fixed fixture calendar, persisted once. An expired season is never renewed.
  const iso = (value) => new Date(value).toISOString();
  transaction(database, () => {
    for (const municipalityId of municipalities) {
      const id = `fantasy-demo-${municipalityId}-2026-autumn`;
      if (database.prepare('SELECT 1 FROM fantasy_seasons WHERE id = ?').get(id)) continue;
      database.prepare(`INSERT INTO fantasy_seasons VALUES (?, ?, ?, ?, ?, 1, 1)`)
        .run(id, municipalityId, 'Stagione civica · Autunno demo', iso(startsAt), iso(startsAt + 56 * dayMs));
      const insertCard = database.prepare('INSERT INTO fantasy_cards VALUES (?, ?, 1, ?, ?, ?, ?, ?)');
      for (const card of fixtureCards) {
        insertCard.run(id, card.id, card.role, card.price, card.availability, card.sourceStatus,
          JSON.stringify({ ...card, sourceUpdatedAt: card.sourceStatus === 'unavailable' ? null : iso(startsAt), isDemo: true }));
      }
      const insertDay = database.prepare('INSERT INTO fantasy_matchdays VALUES (?, ?, ?, ?, ?, ?, ?)');
      for (let number = 1; number <= 8; number++) {
        const start = startsAt + (number - 1) * 7 * dayMs;
        insertDay.run(id, `matchday-${number}`, number, iso(start), iso(start + 2 * dayMs), iso(start + 7 * dayMs), fantasyRulesVersion);
      }
    }
  });

  function fail(message = 'Fantasy resource not found.') {
    const error = new Error(message);
    error.statusCode = 404;
    error.code = 'not_found';
    throw error;
  }
  function seasonRow(municipalityId) {
    return database.prepare('SELECT * FROM fantasy_seasons WHERE municipality_id = ? ORDER BY starts_at DESC LIMIT 1').get(municipalityId) ?? fail();
  }
  function dayDto(row) {
    return { id: row.id, number: row.number, seasonId: row.season_id, startsAt: row.starts_at,
      locksAt: row.locks_at, observationEndsAt: row.observation_ends_at, rulesVersion: row.rules_version };
  }
  function currentDay(season, time) {
    return database.prepare('SELECT * FROM fantasy_matchdays WHERE season_id = ? AND observation_ends_at > ? ORDER BY number LIMIT 1').get(season.id, time)
      ?? database.prepare('SELECT * FROM fantasy_matchdays WHERE season_id = ? ORDER BY number DESC LIMIT 1').get(season.id)
      ?? fail();
  }
  function envelope(season, serverTime) { return { serverTime, isDemo: Boolean(season.is_demo) }; }
  const api = {
    season(municipalityId) {
      const row = seasonRow(municipalityId);
      const serverTime = iso(now());
      const day = currentDay(row, serverTime);
      return { ...envelope(row, serverTime), season: { id: row.id, municipalityId: row.municipality_id, name: row.name,
        startsAt: row.starts_at, endsAt: row.ends_at, totalMatchdays: 8, currentMatchday: day.number,
        catalogVersion: row.catalog_version, status: serverTime < row.starts_at ? 'upcoming' : serverTime >= row.ends_at ? 'ended' : 'active' } };
    },
    cards(municipalityId) {
      const season = seasonRow(municipalityId);
      const items = database.prepare('SELECT * FROM fantasy_cards WHERE season_id = ? ORDER BY id').all(season.id).map((row) => ({
        ...JSON.parse(row.payload), id: row.id, version: row.version, role: row.role, price: row.price,
        availability: row.availability, sourceStatus: row.source_status, isDemo: Boolean(season.is_demo),
      }));
      return { ...envelope(season, iso(now())), seasonId: season.id, catalogVersion: season.catalog_version, items };
    },
    matchday(municipalityId, matchdayId) {
      const season = seasonRow(municipalityId);
      const serverTime = iso(now());
      const row = matchdayId == null ? currentDay(season, serverTime)
        : database.prepare('SELECT * FROM fantasy_matchdays WHERE season_id = ? AND id = ?').get(season.id, matchdayId) ?? fail();
      return { ...envelope(season, serverTime), matchday: dayDto(row) };
    },
    isReady: () => fantasySchemaReady(database),
    counts() {
      return Object.fromEntries(['seasons', 'cards', 'matchdays', 'players', 'drafts', 'snapshots', 'quotes', 'transfers', 'transfer_commands', 'outcomes', 'reveals', 'reflections', 'finalizations'].map((name) => [name,
        database.prepare(`SELECT COUNT(*) AS count FROM fantasy_${name}`).get().count]));
    },
    close() { if (ownsDatabase && database.isOpen) database.close(); },
  };
  api.teams = createFantasyTeams({ database, now, catalog: api.cards, getTransferPenalty: (player, day) => transferPenalty(database, player, day), getTransferData: (player, day) => transferData(database, player, day) });
  api.market = createFantasyMarket({ database, teams: api.teams, now });
  api.results = createFantasyResults({ database, teams: api.teams, catalog: api.cards, now });
  api.atomic = (action) => transaction(database, action);
  api.eraseUserData = api.teams.erase;
  return api;
}
