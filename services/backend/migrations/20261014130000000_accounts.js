export function up(pgm) {
  pgm.sql(`
    CREATE TABLE public.accounts (
      id uuid PRIMARY KEY, email text NOT NULL UNIQUE,
      pseudonym varchar(32) NOT NULL CHECK(length(btrim(pseudonym)) BETWEEN 2 AND 32),
      created_at timestamptz NOT NULL,
      CHECK(email=lower(btrim(email)))
    );
    ALTER TABLE public.proposal_sessions
      ADD COLUMN account_id uuid REFERENCES public.accounts(id),
      ADD COLUMN device_id uuid UNIQUE,
      ADD COLUMN device_name varchar(80),
      ADD COLUMN expires_at timestamptz;
    CREATE INDEX proposal_sessions_account_idx ON public.proposal_sessions(account_id);
    CREATE TABLE public.account_scopes (
      submission_scope uuid PRIMARY KEY,
      account_id uuid NOT NULL REFERENCES public.accounts(id),
      linked_at timestamptz NOT NULL
    );
    CREATE TABLE public.account_email_codes (
      id uuid PRIMARY KEY, email text NOT NULL, code_hash text NOT NULL,
      created_at timestamptz NOT NULL, expires_at timestamptz NOT NULL,
      attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 5),
      consumed_at timestamptz, CHECK(expires_at>created_at)
    );
    CREATE INDEX account_email_codes_email_idx ON public.account_email_codes(email,created_at);
    CREATE TABLE public.account_guest_links (
      guest_scope uuid PRIMARY KEY,
      account_id uuid NOT NULL REFERENCES public.accounts(id),
      command_key text NOT NULL, request_hash text NOT NULL,
      response jsonb NOT NULL CHECK(jsonb_typeof(response)='object'),
      linked_at timestamptz NOT NULL
    );
    CREATE TABLE public.account_abandoned_teams (
      account_id uuid NOT NULL REFERENCES public.accounts(id),
      guest_scope uuid NOT NULL REFERENCES public.account_guest_links(guest_scope) DEFERRABLE INITIALLY DEFERRED,
      season_id text NOT NULL REFERENCES public.fantasy_seasons(id),
      PRIMARY KEY(account_id,guest_scope,season_id)
    );
    DO $$ DECLARE c record; BEGIN
      FOR c IN SELECT conrelid::regclass AS tab,conname FROM pg_constraint
        WHERE contype='f' AND (conrelid::regclass::text LIKE 'fantasy_%'
          OR conrelid IN ('public.prediction_results'::regclass,'public.reputation_events'::regclass))
      LOOP EXECUTE format('ALTER TABLE %s ALTER CONSTRAINT %I DEFERRABLE INITIALLY DEFERRED',c.tab,c.conname); END LOOP;
    END $$;
  `);
}
export function down(pgm) {
  pgm.sql(`
    DROP TABLE public.account_abandoned_teams;
    DROP TABLE public.account_guest_links;
    DROP TABLE public.account_email_codes;
    DROP TABLE public.account_scopes;
    ALTER TABLE public.proposal_sessions DROP COLUMN expires_at,DROP COLUMN device_name,DROP COLUMN device_id,DROP COLUMN account_id;
    DROP TABLE public.accounts;
    DO $$ DECLARE c record; BEGIN
      FOR c IN SELECT conrelid::regclass AS tab,conname FROM pg_constraint
        WHERE contype='f' AND (conrelid::regclass::text LIKE 'fantasy_%'
          OR conrelid IN ('public.prediction_results'::regclass,'public.reputation_events'::regclass))
      LOOP EXECUTE format('ALTER TABLE %s ALTER CONSTRAINT %I NOT DEFERRABLE INITIALLY IMMEDIATE',c.tab,c.conname); END LOOP;
    END $$;
  `);
}
