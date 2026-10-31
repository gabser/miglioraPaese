const problemKeys = [
  'lighting',
  'potholes',
  'waste',
  'cleanliness',
  'green',
  'signage',
  'transport',
  'parking',
  'decor',
  'noise',
  'safety',
  'construction',
  'queues',
];

const motivationValues = [
  'visibleActions',
  'recentDecline',
  'seasonality',
  'unmetPromises',
  'personalExperience',
];

function sqlList(values) {
  return values.map((value) => `'${value}'`).join(', ');
}

export function up(pgm) {
  pgm.sql(`
    CREATE TABLE public.migration_attestations (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      migration_id bigint NOT NULL,
      migration_table_id integer NOT NULL,
      migration_name varchar(255) NOT NULL,
      migration_sha256 char(64) NOT NULL
        CHECK (migration_sha256 ~ '^[0-9a-f]{64}$'),
      action text NOT NULL
        CHECK (action IN ('apply', 'revert', 'reconcile')),
      source_commit text NOT NULL CHECK (length(source_commit) > 0),
      artifact_digest text NOT NULL
        CHECK (artifact_digest ~ '^sha256:[0-9a-f]{64}$'),
      driver_version text NOT NULL CHECK (length(driver_version) > 0),
      runner_version text NOT NULL CHECK (length(runner_version) > 0),
      reconciles_attestation_id bigint NULL
        REFERENCES public.migration_attestations (id) ON DELETE RESTRICT,
      recorded_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE INDEX migration_attestations_migration_history_idx
      ON public.migration_attestations (migration_name, id DESC);

    CREATE FUNCTION public.prevent_migration_attestation_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $function$
    BEGIN
      RAISE EXCEPTION 'migration attestations are append-only'
        USING ERRCODE = '55000';
    END;
    $function$;

    CREATE TRIGGER migration_attestations_append_only
      BEFORE UPDATE OR DELETE ON public.migration_attestations
      FOR EACH ROW
      EXECUTE FUNCTION public.prevent_migration_attestation_mutation();

    CREATE TABLE public.municipalities (
      id varchar(96) PRIMARY KEY
        CHECK (id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
      name varchar(160) NOT NULL CHECK (length(btrim(name)) > 0),
      activation_state text NOT NULL
        CHECK (activation_state IN ('active', 'collectingSignals', 'newMunicipality')),
      base_activation_state text NOT NULL
        CHECK (base_activation_state IN ('active', 'collectingSignals', 'newMunicipality')),
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      CHECK (updated_at >= created_at)
    );

    CREATE TABLE public.turns (
      id varchar(160) PRIMARY KEY,
      municipality_id varchar(96) NOT NULL
        REFERENCES public.municipalities (id) ON DELETE RESTRICT,
      state text NOT NULL CHECK (state IN ('open', 'calculating', 'closed')),
      start_at timestamptz NOT NULL,
      end_at timestamptz NOT NULL,
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (id, municipality_id),
      CHECK (end_at > start_at),
      CHECK (updated_at >= created_at)
    );

    CREATE UNIQUE INDEX turns_one_current_per_municipality_idx
      ON public.turns (municipality_id)
      WHERE state IN ('open', 'calculating');

    CREATE TABLE public.suggestions (
      id varchar(160) PRIMARY KEY,
      municipality_id varchar(96) NOT NULL
        REFERENCES public.municipalities (id) ON DELETE RESTRICT,
      title varchar(120) NOT NULL CHECK (length(btrim(title)) > 0),
      normalized_title varchar(120) NOT NULL,
      description varchar(1000) NOT NULL CHECK (length(btrim(description)) > 0),
      category text NOT NULL CHECK (category IN (${sqlList(problemKeys)})),
      status text NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
      submitted_by_user_id varchar(128) NOT NULL
        CHECK (length(btrim(submitted_by_user_id)) > 0),
      submitted_by_display_name varchar(160) NOT NULL
        CHECK (length(btrim(submitted_by_display_name)) > 0),
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (id, municipality_id),
      UNIQUE (municipality_id, normalized_title),
      CHECK (
        normalized_title = lower(
          regexp_replace(btrim(title), '[[:space:]]+', ' ', 'g')
        )
      ),
      CHECK (updated_at >= created_at)
    );

    COMMENT ON COLUMN public.suggestions.submitted_by_user_id IS
      'Legacy client-controlled user id. Replaced by a principal foreign key in UC-03.';

    CREATE TABLE public.problems (
      id varchar(200) PRIMARY KEY,
      municipality_id varchar(96) NOT NULL,
      turn_id varchar(160) NOT NULL,
      source_suggestion_id varchar(160) NULL,
      problem_key text NOT NULL CHECK (problem_key IN (${sqlList(problemKeys)})),
      title varchar(160) NOT NULL CHECK (length(btrim(title)) > 0),
      zone_name varchar(160) NOT NULL CHECK (length(btrim(zone_name)) > 0),
      status text NOT NULL CHECK (status IN ('improving', 'stable', 'worsening')),
      trend_percent integer NOT NULL CHECK (trend_percent BETWEEN -100 AND 100),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (id, turn_id, municipality_id),
      FOREIGN KEY (turn_id, municipality_id)
        REFERENCES public.turns (id, municipality_id) ON DELETE RESTRICT,
      FOREIGN KEY (source_suggestion_id, municipality_id)
        REFERENCES public.suggestions (id, municipality_id) ON DELETE RESTRICT
    );

    CREATE INDEX problems_turn_idx
      ON public.problems (turn_id, updated_at DESC);

    CREATE TABLE public.suggestion_votes (
      suggestion_id varchar(160) NOT NULL,
      municipality_id varchar(96) NOT NULL,
      user_id varchar(128) NOT NULL CHECK (length(btrim(user_id)) > 0),
      vote text NOT NULL CHECK (vote IN ('up', 'down')),
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (suggestion_id, user_id),
      FOREIGN KEY (suggestion_id, municipality_id)
        REFERENCES public.suggestions (id, municipality_id) ON DELETE CASCADE,
      CHECK (updated_at >= created_at)
    );

    COMMENT ON COLUMN public.suggestion_votes.user_id IS
      'Legacy client-controlled user id. Replaced by a principal foreign key in UC-03.';

    CREATE INDEX suggestion_votes_municipality_idx
      ON public.suggestion_votes (municipality_id, suggestion_id);

    CREATE TABLE public.predictions (
      id varchar(520) PRIMARY KEY,
      municipality_id varchar(96) NOT NULL,
      turn_id varchar(160) NOT NULL,
      problem_id varchar(200) NOT NULL,
      user_id varchar(128) NOT NULL CHECK (length(btrim(user_id)) > 0),
      choice text NOT NULL CHECK (choice IN ('improve', 'stable', 'worsen')),
      motivations text[] NOT NULL DEFAULT ARRAY[]::text[],
      confidence text NULL CHECK (
        confidence IS NULL OR confidence IN ('gutFeeling', 'considered', 'convinced')
      ),
      created_at timestamptz NOT NULL DEFAULT now(),
      updated_at timestamptz NOT NULL DEFAULT now(),
      UNIQUE (turn_id, problem_id, user_id),
      UNIQUE (id, municipality_id, turn_id, user_id),
      UNIQUE (id, municipality_id, turn_id, problem_id, user_id),
      FOREIGN KEY (turn_id, municipality_id)
        REFERENCES public.turns (id, municipality_id) ON DELETE RESTRICT,
      FOREIGN KEY (problem_id, turn_id, municipality_id)
        REFERENCES public.problems (id, turn_id, municipality_id) ON DELETE RESTRICT,
      CHECK (cardinality(motivations) <= 2),
      CHECK (motivations <@ ARRAY[${sqlList(motivationValues)}]::text[]),
      CHECK (updated_at >= created_at)
    );

    COMMENT ON COLUMN public.predictions.user_id IS
      'Legacy client-controlled user id. Replaced by a principal foreign key in UC-03.';

    CREATE FUNCTION public.prevent_prediction_choice_change()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $function$
    BEGIN
      IF NEW.choice IS DISTINCT FROM OLD.choice THEN
        RAISE EXCEPTION 'prediction choice is immutable'
          USING ERRCODE = '23514', CONSTRAINT = 'predictions_choice_immutable';
      END IF;
      RETURN NEW;
    END;
    $function$;

    CREATE TRIGGER predictions_choice_immutable
      BEFORE UPDATE OF choice ON public.predictions
      FOR EACH ROW
      EXECUTE FUNCTION public.prevent_prediction_choice_change();

    CREATE INDEX predictions_owner_turn_idx
      ON public.predictions (user_id, turn_id, updated_at DESC);

    CREATE TABLE public.prediction_results (
      prediction_id varchar(520) PRIMARY KEY,
      municipality_id varchar(96) NOT NULL,
      turn_id varchar(160) NOT NULL,
      problem_id varchar(200) NOT NULL,
      user_id varchar(128) NOT NULL,
      winning_choice text NOT NULL
        CHECK (winning_choice IN ('improve', 'stable', 'worsen')),
      correct boolean NOT NULL,
      points_delta integer NOT NULL,
      resolved_at timestamptz NOT NULL DEFAULT now(),
      FOREIGN KEY (prediction_id, municipality_id, turn_id, problem_id, user_id)
        REFERENCES public.predictions
          (id, municipality_id, turn_id, problem_id, user_id)
        ON DELETE RESTRICT
    );

    CREATE TABLE public.problem_events (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      municipality_id varchar(96) NOT NULL,
      turn_id varchar(160) NOT NULL,
      problem_id varchar(200) NOT NULL,
      event_type varchar(80) NOT NULL CHECK (length(btrim(event_type)) > 0),
      payload jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(payload) = 'object'),
      idempotency_key varchar(160) NOT NULL UNIQUE,
      occurred_at timestamptz NOT NULL DEFAULT now(),
      FOREIGN KEY (problem_id, turn_id, municipality_id)
        REFERENCES public.problems (id, turn_id, municipality_id)
        ON DELETE RESTRICT
    );

    CREATE INDEX problem_events_problem_history_idx
      ON public.problem_events (problem_id, occurred_at, id);

    CREATE TABLE public.reputation_events (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      municipality_id varchar(96) NOT NULL,
      turn_id varchar(160) NOT NULL,
      user_id varchar(128) NOT NULL,
      prediction_id varchar(520) NULL,
      event_type varchar(80) NOT NULL CHECK (length(btrim(event_type)) > 0),
      points_delta integer NOT NULL,
      idempotency_key varchar(160) NOT NULL UNIQUE,
      occurred_at timestamptz NOT NULL DEFAULT now(),
      FOREIGN KEY (turn_id, municipality_id)
        REFERENCES public.turns (id, municipality_id) ON DELETE RESTRICT,
      FOREIGN KEY (prediction_id, municipality_id, turn_id, user_id)
        REFERENCES public.predictions (id, municipality_id, turn_id, user_id)
        ON DELETE RESTRICT
    );

    CREATE INDEX reputation_events_owner_history_idx
      ON public.reputation_events
        (municipality_id, user_id, occurred_at, id);
  `);
}

export function down(pgm) {
  pgm.sql(`
    DROP TABLE public.reputation_events;
    DROP TABLE public.problem_events;
    DROP TABLE public.prediction_results;
    DROP TABLE public.predictions;
    DROP FUNCTION public.prevent_prediction_choice_change();
    DROP TABLE public.suggestion_votes;
    DROP TABLE public.problems;
    DROP TABLE public.suggestions;
    DROP TABLE public.turns;
    DROP TABLE public.municipalities;
    DROP TABLE public.migration_attestations;
    DROP FUNCTION public.prevent_migration_attestation_mutation();
  `);
}
