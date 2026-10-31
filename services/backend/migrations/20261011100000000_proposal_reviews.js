export function up(pgm) {
  pgm.sql(`CREATE TABLE public.proposal_reviews (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    suggestion_id text NOT NULL,
    municipality_id text NOT NULL,
    decision text NOT NULL CHECK (decision IN ('reject','reopen')),
    from_status text NOT NULL CHECK (from_status IN ('pending','rejected')),
    to_status text NOT NULL CHECK (to_status IN ('pending','rejected')),
    operator_label text NOT NULL CHECK (char_length(operator_label) BETWEEN 1 AND 160),
    private_reason text NOT NULL CHECK (char_length(private_reason) BETWEEN 1 AND 1000),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    FOREIGN KEY (suggestion_id, municipality_id) REFERENCES public.suggestions (id, municipality_id) ON DELETE CASCADE,
    CHECK ((decision = 'reject' AND from_status = 'pending' AND to_status = 'rejected') OR
           (decision = 'reopen' AND from_status = 'rejected' AND to_status = 'pending'))
  );`);
}
export function down(pgm) { pgm.sql('DROP TABLE public.proposal_reviews;'); }
