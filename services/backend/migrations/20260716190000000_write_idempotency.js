export function up(pgm) {
  pgm.sql(`
    CREATE TABLE public.write_idempotency (
      operation varchar(80) NOT NULL CHECK (length(btrim(operation)) > 0),
      idempotency_key varchar(160) NOT NULL
        CHECK (idempotency_key ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{7,159}$'),
      request_sha256 char(64) NOT NULL
        CHECK (request_sha256 ~ '^[0-9a-f]{64}$'),
      response_status smallint NULL
        CHECK (response_status BETWEEN 200 AND 299),
      response_body jsonb NULL
        CHECK (
          response_body IS NULL OR jsonb_typeof(response_body) = 'object'
        ),
      created_at timestamptz NOT NULL DEFAULT now(),
      completed_at timestamptz NULL,
      PRIMARY KEY (operation, idempotency_key),
      CHECK (
        (response_status IS NULL AND response_body IS NULL AND completed_at IS NULL)
        OR
        (response_status IS NOT NULL AND response_body IS NOT NULL
          AND completed_at IS NOT NULL AND completed_at >= created_at)
      )
    );

    CREATE INDEX write_idempotency_created_at_idx
      ON public.write_idempotency (created_at);
  `);
}

export function down(pgm) {
  pgm.sql('DROP TABLE public.write_idempotency;');
}
