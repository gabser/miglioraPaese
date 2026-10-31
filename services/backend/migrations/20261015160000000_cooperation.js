// Coverage remains anonymous and survives membership departure/account erasure.
export function up(pgm){pgm.sql(`
CREATE TABLE cooperation_goals (
 id text PRIMARY KEY, municipality_id text NOT NULL, season_id text NOT NULL, matchday_id text NOT NULL,
 title text NOT NULL, version integer NOT NULL CHECK(version>0), published_at timestamptz NOT NULL,
 UNIQUE(season_id,matchday_id),
 FOREIGN KEY(season_id,matchday_id) REFERENCES fantasy_matchdays(season_id,id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE cooperation_targets (
 goal_id text NOT NULL REFERENCES cooperation_goals(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 place_id text NOT NULL, starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL,
 PRIMARY KEY(goal_id,place_id,starts_at,ends_at), CHECK(ends_at>starts_at)
);
CREATE TABLE cooperation_coverage (
 goal_id text NOT NULL,place_id text NOT NULL,starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,validated_at timestamptz NOT NULL,
 PRIMARY KEY(goal_id,place_id,starts_at,ends_at),
 FOREIGN KEY(goal_id,place_id,starts_at,ends_at) REFERENCES cooperation_targets(goal_id,place_id,starts_at,ends_at) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE cooperation_league_coverage (
 league_id text NOT NULL REFERENCES fantasy_leagues(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 goal_id text NOT NULL,place_id text NOT NULL,starts_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,validated_at timestamptz NOT NULL,
 PRIMARY KEY(league_id,goal_id,place_id,starts_at,ends_at),
 FOREIGN KEY(goal_id,place_id,starts_at,ends_at) REFERENCES cooperation_targets(goal_id,place_id,starts_at,ends_at) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE cooperation_follows (
 account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 municipality_id text NOT NULL,place_id text NOT NULL,
 PRIMARY KEY(account_id,municipality_id,place_id)
);
CREATE TABLE cooperation_outbox (
 id uuid PRIMARY KEY,event_key text NOT NULL,event_version integer NOT NULL CHECK(event_version>0),
 recipient_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 municipality_id text NOT NULL,type text NOT NULL CHECK(type IN ('integrationRequested','observationApproved','observationRejected','outcomePublished','outcomeCorrected','recheckRequested')),
 target jsonb NOT NULL CHECK(jsonb_typeof(target)='object'),created_at timestamptz NOT NULL,delivered_at timestamptz,
 UNIQUE(event_key,event_version,recipient_id)
);
CREATE TABLE cooperation_inbox (
 id uuid PRIMARY KEY REFERENCES cooperation_outbox(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 recipient_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 read_at timestamptz
);
CREATE INDEX cooperation_recipient_order ON cooperation_outbox(recipient_id,created_at DESC,id DESC);
CREATE TABLE cooperation_calendar_receipts (
 command_key text PRIMARY KEY,digest text NOT NULL,receipt jsonb NOT NULL,created_at timestamptz NOT NULL
);
`);}
export function down(pgm){pgm.sql(`DROP TABLE cooperation_calendar_receipts,cooperation_inbox,cooperation_outbox,cooperation_follows,cooperation_league_coverage,cooperation_coverage,cooperation_targets,cooperation_goals;`);}
