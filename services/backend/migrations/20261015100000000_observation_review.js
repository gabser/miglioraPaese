export function up(pgm){pgm.sql(`
CREATE TABLE review_roles(account_id uuid NOT NULL REFERENCES accounts(id), municipality_id text NOT NULL,
 role text NOT NULL CHECK(role IN('moderator','verifier','outcomesSupervisor')), PRIMARY KEY(account_id,municipality_id,role));
CREATE TABLE mission_places(mission_id text PRIMARY KEY REFERENCES missions(id),place_id text NOT NULL);
INSERT INTO mission_places SELECT id,municipality_id||':area:'||md5(area::text) FROM missions;
CREATE TABLE mission_card_links(mission_id text NOT NULL REFERENCES missions(id),season_id text NOT NULL,matchday_id text NOT NULL,card_id text NOT NULL,
 PRIMARY KEY(mission_id,season_id,matchday_id,card_id),FOREIGN KEY(season_id,matchday_id) REFERENCES fantasy_matchdays(season_id,id),FOREIGN KEY(season_id,card_id) REFERENCES fantasy_cards(season_id,id));
CREATE TABLE observation_reviews(observation_id uuid PRIMARY KEY REFERENCES mission_observations(id),place_id text NOT NULL,
 status text NOT NULL DEFAULT 'pendingReview' CHECK(status IN('pendingReview','screened','needsIntegration','approved','rejected')),
 revision integer NOT NULL DEFAULT 1 CHECK(revision>0),assigned_to uuid REFERENCES accounts(id));
CREATE TABLE review_commands(account_id uuid NOT NULL REFERENCES accounts(id),command_key text NOT NULL,request_hash text NOT NULL,response jsonb NOT NULL,PRIMARY KEY(account_id,command_key));
CREATE TABLE review_audit(id uuid PRIMARY KEY,observation_id uuid NOT NULL REFERENCES mission_observations(id),action text NOT NULL,actor_id uuid NOT NULL REFERENCES accounts(id),reason text NOT NULL,at timestamptz NOT NULL,revision integer NOT NULL);
CREATE TABLE integration_requests(id uuid PRIMARY KEY,observation_id uuid NOT NULL REFERENCES mission_observations(id),message text NOT NULL,requested_at timestamptz NOT NULL,due_at timestamptz NOT NULL,status text NOT NULL CHECK(status IN('open','answered','closed')),revision integer NOT NULL CHECK(revision>0));
CREATE UNIQUE INDEX integration_open_idx ON integration_requests(observation_id) WHERE status='open';
CREATE TABLE observation_supplements(id uuid PRIMARY KEY,observation_id uuid NOT NULL REFERENCES mission_observations(id),integration_request_id uuid NOT NULL UNIQUE REFERENCES integration_requests(id),notes text NOT NULL,proofs jsonb NOT NULL,submitted_at timestamptz NOT NULL);
CREATE TABLE replication_requests(id uuid PRIMARY KEY,observation_id uuid NOT NULL REFERENCES mission_observations(id),account_id uuid NOT NULL REFERENCES accounts(id),mission_id text NOT NULL REFERENCES missions(id),municipality_id text NOT NULL,place_id text NOT NULL,window_id text NOT NULL,protocol_version integer NOT NULL,reason text NOT NULL,requested_at timestamptz NOT NULL,due_at timestamptz NOT NULL,status text NOT NULL CHECK(status IN('open','booked')),FOREIGN KEY(window_id,mission_id) REFERENCES mission_windows(id,mission_id));
ALTER TABLE mission_bookings ADD COLUMN replication_request_id uuid UNIQUE REFERENCES replication_requests(id);
DROP INDEX mission_active_account_window_idx;
CREATE UNIQUE INDEX mission_active_account_window_idx ON mission_bookings(account_id,window_id) WHERE status IN('active','submitted') AND replication_request_id IS NULL;
ALTER TABLE mission_uploads ADD COLUMN integration_request_id uuid REFERENCES integration_requests(id);
CREATE TABLE xp_ledger(id uuid PRIMARY KEY,observation_id uuid NOT NULL UNIQUE REFERENCES mission_observations(id),account_id uuid NOT NULL REFERENCES accounts(id),place_id text NOT NULL,window_id text NOT NULL,window_scope text NOT NULL,amount integer NOT NULL CHECK(amount=10),awarded_at timestamptz NOT NULL,rule_version integer NOT NULL CHECK(rule_version=1),replication_request_id uuid UNIQUE REFERENCES replication_requests(id));
CREATE UNIQUE INDEX xp_base_account_place_window_idx ON xp_ledger(account_id,place_id,window_scope) WHERE replication_request_id IS NULL;
`);}
export function down(pgm){pgm.sql(`DROP TABLE xp_ledger;ALTER TABLE mission_uploads DROP COLUMN integration_request_id;ALTER TABLE mission_bookings DROP COLUMN replication_request_id;DROP INDEX mission_active_account_window_idx;CREATE UNIQUE INDEX mission_active_account_window_idx ON mission_bookings(account_id,window_id) WHERE status IN('active','submitted');DROP TABLE replication_requests,observation_supplements,integration_requests,review_audit,review_commands,observation_reviews,mission_card_links,mission_places,review_roles;`);}
