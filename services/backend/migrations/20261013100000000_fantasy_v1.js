export function up(pgm) {
  pgm.sql(`
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
    );
    CREATE TABLE fantasy_cards (
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      id TEXT NOT NULL,
      version INTEGER NOT NULL CHECK (version > 0),
      role TEXT NOT NULL CHECK (role IN ('mobility', 'environment', 'servicesAndSafety')),
      price INTEGER NOT NULL CHECK (price >= 0),
      availability TEXT NOT NULL CHECK (availability IN ('available', 'unavailable')),
      source_status TEXT NOT NULL CHECK (source_status IN ('verified', 'pending', 'unavailable')),
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      PRIMARY KEY (season_id, id)
    );
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
    );
  

    CREATE TABLE fantasy_players (
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      user_id TEXT NOT NULL,
      revision INTEGER NOT NULL CHECK (revision > 0),
      squad_ids TEXT NOT NULL CHECK (jsonb_typeof(squad_ids::jsonb) = 'array'),
      created_at TEXT NOT NULL,
      PRIMARY KEY (season_id, user_id)
    );
    CREATE TABLE fantasy_drafts (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      PRIMARY KEY (season_id, user_id, matchday_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    );
    CREATE TABLE fantasy_snapshots (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      PRIMARY KEY (season_id, user_id, matchday_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    );
  

    CREATE TABLE fantasy_quotes (
      id TEXT PRIMARY KEY,
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    );
    CREATE TABLE fantasy_transfer_commands (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      command_key TEXT NOT NULL,
      request_hash TEXT NOT NULL,
      response TEXT NOT NULL CHECK (jsonb_typeof(response::jsonb) = 'object'),
      PRIMARY KEY (season_id, user_id, command_key),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE
    );
    CREATE TABLE fantasy_transfers (
      id TEXT PRIMARY KEY,
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      command_key TEXT NOT NULL,
      cost INTEGER NOT NULL CHECK (cost IN (0, 4)),
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      UNIQUE (season_id, user_id, command_key),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    );
  

    CREATE TABLE fantasy_outcomes (
      season_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      card_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      PRIMARY KEY (season_id, matchday_id, card_id),
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id),
      FOREIGN KEY (season_id, card_id) REFERENCES fantasy_cards(season_id, id)
    );
    CREATE TABLE fantasy_reveals (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      card_id TEXT NOT NULL,
      payload TEXT NOT NULL CHECK (jsonb_typeof(payload::jsonb) = 'object'),
      PRIMARY KEY (season_id, user_id, matchday_id, card_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id, card_id) REFERENCES fantasy_outcomes(season_id, matchday_id, card_id)
    );
    CREATE TABLE fantasy_finalizations (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      finalized_at TEXT NOT NULL,
      PRIMARY KEY (season_id, user_id, matchday_id),
      FOREIGN KEY (season_id, user_id) REFERENCES fantasy_players(season_id, user_id) ON DELETE CASCADE,
      FOREIGN KEY (season_id, matchday_id) REFERENCES fantasy_matchdays(season_id, id)
    );
    CREATE TABLE fantasy_reflections (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      matchday_id TEXT NOT NULL,
      card_id TEXT NOT NULL,
      answer TEXT NOT NULL CHECK (answer IN ('observedIntervention', 'externalConditions', 'insufficientInformation')),
      created_at TEXT NOT NULL,
      PRIMARY KEY (season_id, user_id, matchday_id, card_id),
      FOREIGN KEY (season_id, user_id, matchday_id, card_id) REFERENCES fantasy_reveals(season_id, user_id, matchday_id, card_id) ON DELETE CASCADE
    );
  

    CREATE TABLE fantasy_leagues (
      id TEXT PRIMARY KEY,
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      owner_id TEXT,
      creation_key TEXT NOT NULL,
      name TEXT NOT NULL CHECK (name IN ('Amici', 'Quartiere', 'Comune')),
      status TEXT NOT NULL CHECK (status IN ('active','archived')),
      first_locks_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE (id, season_id),
      UNIQUE (season_id, owner_id, creation_key)
    );
    CREATE TABLE fantasy_members (
      league_id TEXT NOT NULL,
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      member_id TEXT NOT NULL UNIQUE,
      pseudonym TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('competitor','spectator')),
      joined_at TEXT NOT NULL,
      PRIMARY KEY (league_id,user_id),
      FOREIGN KEY (league_id,season_id) REFERENCES fantasy_leagues(id,season_id),
      FOREIGN KEY (season_id,user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE
    );
    CREATE TABLE fantasy_invites (
      id TEXT PRIMARY KEY,
      league_id TEXT NOT NULL REFERENCES fantasy_leagues(id),
      token_hash TEXT NOT NULL UNIQUE,
      expires_at TEXT NOT NULL,
      revoked INTEGER NOT NULL CHECK (revoked IN (0,1))
    );
    CREATE TABLE fantasy_invite_attempts (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      window_start BIGINT NOT NULL,
      attempts INTEGER NOT NULL,
      PRIMARY KEY (season_id,user_id),
      FOREIGN KEY (season_id,user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE
    );
  `);
}

export function down(pgm) {
  pgm.sql(`DROP TABLE fantasy_invite_attempts;
DROP TABLE fantasy_invites;
DROP TABLE fantasy_members;
DROP TABLE fantasy_leagues;
DROP TABLE fantasy_reflections;
DROP TABLE fantasy_finalizations;
DROP TABLE fantasy_reveals;
DROP TABLE fantasy_outcomes;
DROP TABLE fantasy_transfers;
DROP TABLE fantasy_transfer_commands;
DROP TABLE fantasy_quotes;
DROP TABLE fantasy_snapshots;
DROP TABLE fantasy_drafts;
DROP TABLE fantasy_players;
DROP TABLE fantasy_matchdays;
DROP TABLE fantasy_cards;
DROP TABLE fantasy_seasons;
`);
}
