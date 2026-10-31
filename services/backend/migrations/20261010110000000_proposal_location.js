export function up(pgm) {
  pgm.sql(`
    ALTER TABLE public.suggestions
      DROP CONSTRAINT suggestions_municipality_id_normalized_title_key,
      ALTER COLUMN normalized_title TYPE text,
      ADD COLUMN location jsonb NULL,
      ADD CONSTRAINT suggestions_location_valid CHECK (
        location IS NULL OR coalesce(
          jsonb_typeof(location) = 'object' AND (
            (location->>'kind' = 'municipality'
              AND location - 'kind' = '{}'::jsonb)
            OR
            (location->>'kind' = 'specific'
              AND location - ARRAY['kind', 'label', 'civic', 'reference']::text[] = '{}'::jsonb
              AND jsonb_typeof(location->'label') = 'string'
              AND length(btrim(location->>'label')) BETWEEN 1 AND 120
              AND (NOT location ? 'civic' OR (
                jsonb_typeof(location->'civic') = 'string'
                AND length(btrim(location->>'civic')) BETWEEN 1 AND 20))
              AND (NOT location ? 'reference' OR (
                jsonb_typeof(location->'reference') = 'string'
                AND length(btrim(location->>'reference')) BETWEEN 1 AND 200)))
          ), false
        )
      );
    COMMENT ON COLUMN public.suggestions.location IS
      'Explicit specific place or whole municipality; NULL means legacy place not supplied.';
  `);
}

export function down(pgm) {
  // PostgreSQL validates before commit: duplicate titles prevent this rollback,
  // preserving all records instead of deleting proposals to restore uniqueness.
  pgm.sql(`
    ALTER TABLE public.suggestions
      ADD CONSTRAINT suggestions_municipality_id_normalized_title_key
        UNIQUE (municipality_id, normalized_title),
      ALTER COLUMN normalized_title TYPE varchar(120),
      DROP COLUMN location;
  `);
}
