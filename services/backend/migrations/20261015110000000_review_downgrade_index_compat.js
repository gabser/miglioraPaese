// Migration 10 is already attested and immutable. Its down path removes the
// replica column before dropping the index named mission_active_account_window_idx.
// PostgreSQL automatically drops column-dependent indexes on DROP COLUMN. Keep
// that historical name for a column-independent nonunique compatibility index.
export function up(pgm){pgm.sql(`
DO $$ BEGIN
 IF to_regclass('public.mission_base_account_window_idx') IS NULL THEN
  ALTER INDEX public.mission_active_account_window_idx RENAME TO mission_base_account_window_idx;
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS mission_active_account_window_idx ON public.mission_bookings(account_id,window_id);
`);}
// Intentionally persistent shim. Removing it here would make the immutable down
// of migration 10 fail again. Down 10 auto-drops the real partial unique index,
// explicitly drops this shim and restores the original phase 3 unique index.
// Reapplying 11 after down 11 is safe. This is schema rollback support only;
// populated replica data cannot be represented by phase 3 uniqueness.
export function down(pgm){pgm.sql('SELECT 1;');}
