// Additive organizational state. Mutable principals use deferred FKs so that
// phase-2 guest linking can move all rows atomically in either update order.
export function up(pgm) { pgm.sql(`
ALTER TABLE fantasy_leagues ADD COLUMN revision INTEGER NOT NULL DEFAULT 1 CHECK(revision > 0);
CREATE TABLE fantasy_ownership_offers (
 id TEXT PRIMARY KEY,
 league_id TEXT NOT NULL,
 season_id TEXT NOT NULL,
 from_user_id TEXT NOT NULL,
 to_user_id TEXT NOT NULL,
 target_member_id TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('pending','accepted','revoked','expired','cancelled')),
 expires_at TEXT NOT NULL,
 created_at TEXT NOT NULL,
 FOREIGN KEY(league_id,season_id) REFERENCES fantasy_leagues(id,season_id) DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY(season_id,from_user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY(season_id,to_user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE UNIQUE INDEX fantasy_one_pending_ownership ON fantasy_ownership_offers(league_id) WHERE status='pending';
CREATE TABLE fantasy_ownership_commands (
 league_id TEXT NOT NULL,
 season_id TEXT NOT NULL,
 user_id TEXT NOT NULL,
 command_key TEXT NOT NULL,
 request_hash TEXT NOT NULL,
 response JSONB NOT NULL CHECK(jsonb_typeof(response)='object'),
 PRIMARY KEY(league_id,user_id,command_key),
 FOREIGN KEY(league_id,season_id) REFERENCES fantasy_leagues(id,season_id) DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY(season_id,user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE fantasy_ownership_audit (
 id TEXT PRIMARY KEY,
 league_id TEXT NOT NULL REFERENCES fantasy_leagues(id) DEFERRABLE INITIALLY DEFERRED,
 offer_id TEXT,
 actor_member_id TEXT,
 action TEXT NOT NULL CHECK(action IN ('offered','accepted','revoked','cancelled','expired','archived')),
 revision INTEGER NOT NULL,
 created_at TEXT NOT NULL
);
CREATE TABLE fantasy_invite_preview_attempts (
 bucket TEXT PRIMARY KEY,
 window_start BIGINT NOT NULL,
 attempts INTEGER NOT NULL
);
`); }
export function down(pgm) { pgm.sql(`
DROP TABLE fantasy_invite_preview_attempts;
DROP TABLE fantasy_ownership_audit;
DROP TABLE fantasy_ownership_commands;
DROP TABLE fantasy_ownership_offers;
ALTER TABLE fantasy_leagues DROP COLUMN revision;
`); }
