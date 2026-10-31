// Match the account-link ownership transaction's existing deferred fantasy FKs.
export function up(pgm){pgm.sql('ALTER TABLE fantasy_result_revisions ALTER CONSTRAINT fantasy_result_revisions_season_id_user_id_matchday_id_fkey DEFERRABLE INITIALLY DEFERRED');}
export function down(pgm){pgm.sql('ALTER TABLE fantasy_result_revisions ALTER CONSTRAINT fantasy_result_revisions_season_id_user_id_matchday_id_fkey NOT DEFERRABLE INITIALLY IMMEDIATE');}
