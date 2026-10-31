// Creation command identity survives ownership changes. A historical creator
// deliberately has no player FK: erasure can remove the team while the league
// remains archived with its command key reserved.
export function up(pgm) { pgm.sql(`
ALTER TABLE fantasy_leagues ADD COLUMN creator_id TEXT;
ALTER TABLE fantasy_leagues DROP CONSTRAINT fantasy_leagues_season_id_owner_id_creation_key_key;
ALTER TABLE fantasy_leagues ADD CONSTRAINT fantasy_leagues_creator_command_key UNIQUE(season_id,creator_id,creation_key);
UPDATE fantasy_leagues SET creator_id=owner_id;
`); }
export function down(pgm) { pgm.sql(`
ALTER TABLE fantasy_leagues DROP CONSTRAINT fantasy_leagues_creator_command_key;
ALTER TABLE fantasy_leagues DROP COLUMN creator_id;
ALTER TABLE fantasy_leagues ADD CONSTRAINT fantasy_leagues_season_id_owner_id_creation_key_key UNIQUE(season_id,owner_id,creation_key);
`); }
