const municipalities = [
  ['castel-bolognese', 'Castel Bolognese', 'collectingSignals', 'collectingSignals'],
  ['bologna', 'Bologna', 'active', 'active'],
];

const suggestions = [
  [
    'suggested-potholes-station',
    'castel-bolognese',
    'Buche vicino alla stazione',
    'buche vicino alla stazione',
    'Segnalazioni ricorrenti su marciapiedi e attraversamenti.',
    'potholes',
    'pending',
    'seed',
    'Comune',
  ],
  [
    'suggested-lighting-park',
    'castel-bolognese',
    'Illuminazione al parco',
    'illuminazione al parco',
    'Percorsi poco leggibili nelle ore serali.',
    'lighting',
    'pending',
    'seed',
    'Comune',
  ],
  [
    'suggested-queues-registry',
    'bologna',
    "Tempi d'attesa all'anagrafe",
    "tempi d'attesa all'anagrafe",
    'Coda percepita alta negli orari centrali.',
    'queues',
    'approved',
    'seed',
    'Comune',
  ],
];

const problems = [
  [
    'problem-traffic-indipendenza',
    'bologna',
    'turn-bologna-today',
    'transport',
    'Traffico Via Indipendenza',
    'Centro',
    'worsening',
    -14,
  ],
  [
    'problem-green-margherita',
    'bologna',
    'turn-bologna-today',
    'green',
    'Verde ai Giardini Margherita',
    'Santo Stefano',
    'improving',
    9,
  ],
];

const votes = [
  ['suggested-queues-registry', 'bologna', 'demo-user', 'up'],
  ['suggested-queues-registry', 'bologna', 'user-luca', 'up'],
  ['suggested-queues-registry', 'bologna', 'user-giulia', 'up'],
  ['suggested-queues-registry', 'bologna', 'user-marta', 'up'],
  ['suggested-queues-registry', 'bologna', 'user-a', 'down'],
];

export async function seedPostgres(
  queryable,
  { profile = 'local', now = new Date() } = {},
) {
  if (!queryable || typeof queryable.connect !== 'function') {
    throw new TypeError('A PostgreSQL pool is required for seeding.');
  }
  if (profile !== 'local' && profile !== 'test') {
    throw new TypeError('Seed profile must be local or test.');
  }
  if (!(now instanceof Date) || Number.isNaN(now.valueOf())) {
    throw new TypeError('Seed clock must be a valid Date.');
  }

  const client = await queryable.connect();
  try {
    await client.query('BEGIN');
    for (const values of municipalities) {
      await client.query(
        `INSERT INTO public.municipalities
           (id, name, activation_state, base_activation_state)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (id) DO UPDATE SET
           name = excluded.name,
           activation_state = excluded.activation_state,
           base_activation_state = excluded.base_activation_state,
           updated_at = now()`,
        values,
      );
    }

    const startAt = new Date(now.valueOf() - 24 * 60 * 60 * 1000);
    const endAt = new Date(now.valueOf() + 6 * 24 * 60 * 60 * 1000);
    for (const municipalityId of municipalities.map(([id]) => id)) {
      await client.query(
        `INSERT INTO public.turns
           (id, municipality_id, state, start_at, end_at)
         VALUES ($1, $2, 'open', $3, $4)
         ON CONFLICT (id) DO UPDATE SET
           state = excluded.state,
           start_at = excluded.start_at,
           end_at = excluded.end_at,
           updated_at = now()`,
        [`turn-${municipalityId}-today`, municipalityId, startAt, endAt],
      );
    }

    for (const values of suggestions) {
      await client.query(
        `INSERT INTO public.suggestions
           (id, municipality_id, title, normalized_title, description,
            category, status, submitted_by_user_id,
            submitted_by_display_name)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (id) DO UPDATE SET
           title = excluded.title,
           normalized_title = excluded.normalized_title,
           description = excluded.description,
           category = excluded.category,
           status = excluded.status,
           submitted_by_user_id = excluded.submitted_by_user_id,
           submitted_by_display_name = excluded.submitted_by_display_name,
           updated_at = now()`,
        values,
      );
    }

    for (const values of problems) {
      await client.query(
        `INSERT INTO public.problems
           (id, municipality_id, turn_id, problem_key, title, zone_name,
            status, trend_percent)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (id) DO UPDATE SET
           problem_key = excluded.problem_key,
           title = excluded.title,
           zone_name = excluded.zone_name,
           status = excluded.status,
           trend_percent = excluded.trend_percent,
           updated_at = now()`,
        values,
      );
    }

    for (const values of votes) {
      await client.query(
        `INSERT INTO public.suggestion_votes
           (suggestion_id, municipality_id, user_id, vote)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (suggestion_id, user_id) DO UPDATE SET
           vote = excluded.vote,
           updated_at = now()`,
        values,
      );
    }

    await client.query(
      `INSERT INTO public.predictions
         (id, municipality_id, turn_id, problem_id, user_id, choice,
          motivations, confidence)
       VALUES
         ($1, 'bologna', 'turn-bologna-today',
          'problem-green-margherita', 'demo-user', 'improve', $2, NULL),
         ($3, 'bologna', 'turn-bologna-today',
          'problem-traffic-indipendenza', 'user-a', 'worsen', $4, 'considered')
       ON CONFLICT (id) DO UPDATE SET
         motivations = excluded.motivations,
         confidence = excluded.confidence,
         updated_at = now()`,
      [
        'turn-bologna-today:problem-green-margherita:demo-user',
        [],
        'turn-bologna-today:problem-traffic-indipendenza:user-a',
        ['recentDecline'],
      ],
    );

    if (profile === 'test') {
      await client.query(
        `INSERT INTO public.predictions
           (id, municipality_id, turn_id, problem_id, user_id, choice,
            motivations, confidence)
         VALUES
           ($1, 'bologna', 'turn-bologna-today',
            'problem-green-margherita', 'user-isolated', 'stable', $2,
            'gutFeeling')
         ON CONFLICT (id) DO NOTHING`,
        [
          'turn-bologna-today:problem-green-margherita:user-isolated',
          ['personalExperience'],
        ],
      );
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
