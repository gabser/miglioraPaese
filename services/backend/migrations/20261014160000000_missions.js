export function up(pgm){pgm.sql(`
CREATE TABLE public.missions (
 id text PRIMARY KEY, municipality_id text NOT NULL, zone_id text NOT NULL,
 title text NOT NULL, area jsonb NOT NULL, protocol jsonb NOT NULL,
 duration_minutes integer NOT NULL CHECK(duration_minutes>0), synthetic boolean NOT NULL CHECK(synthetic),
 UNIQUE(id,municipality_id)
);
CREATE TABLE public.mission_windows (
 id text PRIMARY KEY, mission_id text NOT NULL REFERENCES public.missions(id),
 starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL, capacity integer NOT NULL CHECK(capacity>0),
 CHECK(ends_at>starts_at), UNIQUE(id,mission_id)
);
CREATE TABLE public.mission_bookings (
 id uuid PRIMARY KEY, mission_id text NOT NULL, window_id text NOT NULL,
 account_id uuid NOT NULL REFERENCES public.accounts(id), command_key text NOT NULL,
 protocol_version integer NOT NULL, status text NOT NULL CHECK(status IN('active','released','expired','submitted')),
 expires_at timestamptz NOT NULL, revision integer NOT NULL CHECK(revision>0), created_at timestamptz NOT NULL,
 FOREIGN KEY(window_id,mission_id) REFERENCES public.mission_windows(id,mission_id),
 UNIQUE(account_id,command_key)
);
CREATE UNIQUE INDEX mission_active_account_window_idx ON public.mission_bookings(account_id,window_id) WHERE status IN('active','submitted');
CREATE TABLE public.mission_uploads (
 id uuid PRIMARY KEY, booking_id uuid NOT NULL REFERENCES public.mission_bookings(id),
 command_key text NOT NULL, mime_type text NOT NULL CHECK(mime_type='image/png'),
 total_bytes integer NOT NULL CHECK(total_bytes BETWEEN 1 AND 2097152), received_bytes integer NOT NULL DEFAULT 0,
 chunks jsonb NOT NULL DEFAULT '[]', status text NOT NULL CHECK(status IN('uploading','complete')),
 revision integer NOT NULL DEFAULT 1, file_key uuid, width integer, height integer, sha256 text, sanitized_bytes integer,
 created_at timestamptz NOT NULL, expires_at timestamptz NOT NULL,
 CHECK(received_bytes BETWEEN 0 AND total_bytes), UNIQUE(booking_id,command_key)
);
CREATE TABLE public.mission_observations (
 id uuid PRIMARY KEY, booking_id uuid NOT NULL UNIQUE REFERENCES public.mission_bookings(id),
 command_key text NOT NULL, request_hash text NOT NULL, receipt jsonb NOT NULL,
 answer text NOT NULL CHECK(answer IN('noIssue','nonObservable','unsure','visibleWaste')),
 notes text NOT NULL, proof_ids uuid[] NOT NULL, submitted_at timestamptz NOT NULL
);
`);}
export function down(pgm){pgm.sql('DROP TABLE public.mission_observations,public.mission_uploads,public.mission_bookings,public.mission_windows,public.missions;');}
