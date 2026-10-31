export function up(pgm) {
  pgm.sql(`
    CREATE TABLE public.proposal_sessions (
      token_hash char(64) PRIMARY KEY CHECK (token_hash ~ '^[0-9a-f]{64}$'),
      submission_scope uuid UNIQUE NOT NULL,
      created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
      revoked_at timestamptz NULL,
      CHECK (revoked_at IS NULL OR revoked_at >= created_at)
    );
  `);
}

export function down(pgm) {
  pgm.sql('DROP TABLE public.proposal_sessions;');
}
