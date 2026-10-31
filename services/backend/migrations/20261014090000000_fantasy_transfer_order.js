// Add an explicit durable insertion order instead of SQLite's implicit rowid.
export function up(pgm) {
  pgm.sql(`
    ALTER TABLE public.fantasy_transfers ADD COLUMN sequence_number bigint;
    WITH ordered AS (
      SELECT id, row_number() OVER (ORDER BY payload::jsonb->>'createdAt', id) AS ordinal
      FROM public.fantasy_transfers
    )
    UPDATE public.fantasy_transfers t SET sequence_number=o.ordinal FROM ordered o WHERE t.id=o.id;
    CREATE SEQUENCE public.fantasy_transfer_sequence AS bigint OWNED BY public.fantasy_transfers.sequence_number;
    SELECT setval('public.fantasy_transfer_sequence', GREATEST(COALESCE(MAX(sequence_number),0),1), COALESCE(MAX(sequence_number),0)>0)
      FROM public.fantasy_transfers;
    ALTER TABLE public.fantasy_transfers
      ALTER COLUMN sequence_number SET DEFAULT nextval('public.fantasy_transfer_sequence'),
      ALTER COLUMN sequence_number SET NOT NULL,
      ADD CONSTRAINT fantasy_transfers_sequence_unique UNIQUE(sequence_number),
      ADD CONSTRAINT fantasy_transfers_sequence_positive CHECK(sequence_number>0);
  `);
}
export function down(pgm) {
  pgm.sql('ALTER TABLE public.fantasy_transfers DROP COLUMN sequence_number;');
}
