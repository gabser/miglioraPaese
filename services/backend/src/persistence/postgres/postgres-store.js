import { assertPublicProposalContent, assertSubmissionQuota, validateProposalReview } from '../../domain/proposal-policy.js';
import { newProposalSession, sessionHash, sessionIdentity, sessionRevoked, scopedSubmissionKey } from '../../domain/proposal-session.js';
import { randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';

import {
  canonicalMunicipalityId,
  statusToChoice,
} from '../../domain/catalog.js';
import { httpError } from '../../domain/errors.js';
import { normalizeProposalLocation, proposalLocationLabel } from '../../domain/proposal-location.js';
import { translatePostgresWriteError } from './errors.js';
import { runIdempotentWrite } from './idempotency.js';
import {
  mapMunicipalityRow,
  mapPredictionRow,
  mapProblemRow,
  mapSuggestedProblemRow,
  mapTurnRow,
} from './mappers.js';
import { withTransaction } from './transaction.js';

export function createPostgresStore(
  queryable,
  {
    logger = console,
    createId = randomUUID,
    clock = Date.now,
    onWriteCheckpoint = async () => {},
  } = {},
) {
  if (
    !queryable ||
    typeof queryable.query !== 'function' ||
    typeof queryable.connect !== 'function'
  ) {
    throw new TypeError('A PostgreSQL pool is required.');
  }
  if (typeof clock !== 'function') throw new TypeError('A server clock is required.');
  if (typeof createId !== 'function') {
    throw new TypeError('A suggestion id factory is required.');
  }
  if (typeof onWriteCheckpoint !== 'function') {
    throw new TypeError('Write checkpoint hook must be a function.');
  }

  async function query(name, text, values = [], target = queryable) {
    const startedAt = performance.now();
    try {
      return await target.query({ name, text, values });
    } catch (error) {
      logger.warn?.('PostgreSQL query failed.', {
        name,
        code: typeof error.code === 'string' ? error.code : 'unknown',
      });
      throw error;
    } finally {
      logger.debug?.('PostgreSQL query completed.', {
        name,
        durationMs: Math.round((performance.now() - startedAt) * 100) / 100,
      });
    }
  }

  async function createProposalSession() {
    const session = newProposalSession();
    await query('create-proposal-session',
      'INSERT INTO public.proposal_sessions (token_hash, submission_scope) VALUES ($1,$2)',
      [session.tokenHash, session.submissionScope]);
    return { token: session.token, submissionScope: session.submissionScope };
  }

  async function lockSession(token, target) {
    const result = await query('lock-proposal-session',
      'SELECT submission_scope, revoked_at FROM public.proposal_sessions WHERE token_hash = $1 FOR UPDATE',
      [sessionHash(token)], target);
    const row = result.rows[0];
    if (!row || row.revoked_at !== null) throw sessionRevoked();
    return { submissionScope: row.submission_scope };
  }

  async function getProposalSession(token) {
    return withTransaction(queryable, client => lockSession(token, client), { logger });
  }

  async function revokeProposalSession(token) {
    return withTransaction(queryable, async client => {
      const result = await query('revoke-proposal-session',
        `UPDATE public.proposal_sessions SET revoked_at = COALESCE(revoked_at, clock_timestamp())
         WHERE token_hash = $1 RETURNING submission_scope`, [sessionHash(token)], client);
      if (!result.rowCount) throw sessionRevoked();
      return { revoked: true };
    }, { logger });
  }

  async function lookupSubmission({ sessionToken, municipalityId, idempotencyKey }) {
    return withTransaction(queryable, async client => {
      const session = await lockSession(sessionToken, client);
      const municipality = await readMunicipality(municipalityId, client);
      const key = scopedSubmissionKey(session.submissionScope, municipality.id, idempotencyKey);
      const result = await query('lookup-private-submission',
        `SELECT response_body FROM public.write_idempotency
         WHERE operation = 'submit_suggestion' AND idempotency_key = $1 AND completed_at IS NOT NULL`,
        [key], client);
      if (!result.rowCount) throw httpError(404, 'submission_not_found', 'Submission not found.');
      return result.rows[0].response_body;
    }, { logger });
  }

  async function getOwnNextProblem({ sessionToken, municipalityId, problemId }) {
    return withTransaction(queryable, async client => {
      const session = await lockSession(sessionToken, client);
      const municipality = await readMunicipality(municipalityId, client);
      const userId = sessionIdentity(session);
      const value = await readSuggestion({ municipalityId: municipality.id, problemId, userId, target: client });
      if (value.submittedByUserId !== userId) {
        throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
      }
      return value;
    }, { logger });
  }

  async function getMunicipality(municipalityId) {
    return readMunicipality(municipalityId, queryable);
  }

  async function readMunicipality(municipalityId, target) {
    const id = canonicalMunicipalityId(municipalityId);
    const result = await query(
      'municipality-by-id',
      `SELECT id, name, activation_state, base_activation_state
       FROM public.municipalities
      WHERE id = $1`,
      [id],
      target,
    );
    if (result.rowCount === 0) {
      throw httpError(404, 'municipality_not_found', 'Municipality not found.');
    }
    return mapMunicipalityRow(result.rows[0]);
  }

  async function getCurrentTurn(municipalityId) {
    return readCurrentTurn(municipalityId, queryable);
  }

  async function readCurrentTurn(municipalityId, target) {
    const municipality = await readMunicipality(municipalityId, target);
    const result = await query(
      'current-turn-by-municipality',
      `SELECT id, municipality_id, state, start_at, end_at
       FROM public.turns
       WHERE municipality_id = $1
         AND state IN ('open', 'calculating')
       ORDER BY start_at DESC
      LIMIT 1`,
      [municipality.id],
      target,
    );
    if (result.rowCount === 0) {
      throw httpError(404, 'turn_not_found', 'Turn not found.');
    }
    return mapTurnRow(result.rows[0]);
  }

  async function listProblems(municipalityId) {
    const turn = await getCurrentTurn(municipalityId);
    const result = await query(
      'problems-by-current-turn',
      `SELECT id, problem_key, title, zone_name, status, trend_percent,
              updated_at
       FROM public.problems
       WHERE municipality_id = $1 AND turn_id = $2
       ORDER BY updated_at DESC, id`,
      [turn.municipalityId, turn.id],
    );
    return result.rows.map(mapProblemRow);
  }

  async function listNextProblems({
    municipalityId,
    status = null,
    query: searchQuery = null,
    userId = 'demo-user',
  }) {
    const municipality = await readMunicipality(municipalityId, queryable);
    return readSuggestions({
      municipalityId: municipality.id,
      status,
      searchQuery,
      userId,
      target: queryable,
    });
  }

  async function readSuggestions({
    municipalityId,
    status = null,
    searchQuery = null,
    userId,
    problemId = null,
    target,
  }) {
    const result = await query(
      problemId === null
        ? 'suggestions-by-municipality'
        : 'suggestion-by-municipality-and-id',
      `SELECT
         s.id,
         s.title,
         s.description,
         s.location,
         s.category,
         s.status,
         s.submitted_by_user_id,
         s.submitted_by_display_name,
         s.created_at,
         count(*) FILTER (WHERE v.vote = 'up') AS votes_up,
         count(*) FILTER (WHERE v.vote = 'down') AS votes_down,
         coalesce(max(v.vote) FILTER (WHERE v.user_id = $2), 'none') AS my_vote
       FROM public.suggestions s
       LEFT JOIN public.suggestion_votes v
         ON v.suggestion_id = s.id
        AND v.municipality_id = s.municipality_id
       WHERE s.municipality_id = $1
         AND ($3::text IS NULL OR s.status = $3)
         AND (
           $4::text IS NULL
           OR s.title ILIKE '%' || $4 || '%'
           OR s.description ILIKE '%' || $4 || '%'
           OR s.location->>'label' ILIKE '%' || $4 || '%'
           OR s.location->>'civic' ILIKE '%' || $4 || '%'
           OR s.location->>'reference' ILIKE '%' || $4 || '%'
           OR (s.location->>'kind' = 'municipality' AND 'Intero Comune' ILIKE '%' || $4 || '%')
         )
         AND ($5::text IS NULL OR s.id = $5)
       GROUP BY s.id
       ORDER BY s.created_at DESC, s.id`,
      [municipalityId, userId, status, searchQuery, problemId],
      target,
    );
    return result.rows.map(mapSuggestedProblemRow);
  }

  async function readSuggestion({ municipalityId, problemId, userId, target }) {
    const items = await readSuggestions({
      municipalityId,
      problemId,
      userId,
      target,
    });
    if (items.length === 0) {
      throw httpError(
        404,
        'suggested_problem_not_found',
        'Suggested problem not found.',
      );
    }
    return items[0];
  }

  async function getNextProblem({ municipalityId, problemId, userId = 'demo-user' }) {
    const municipality = await readMunicipality(municipalityId, queryable);
    return readSuggestion({ municipalityId: municipality.id, problemId, userId,
      target: queryable });
  }

  async function submitNextProblem({
    idempotencyKey,
    municipalityId,
    title,
    description,
    category,
    userId,
    sessionToken = null,
    location: rawLocation = null,
  }) {
    const location = normalizeProposalLocation(rawLocation);
    if (sessionToken === null && userId?.startsWith('session:')) throw httpError(401, 'proposal_session_required', 'A valid proposal session is required.');
    try {
      return await withTransaction(
        queryable,
        async (client) => {
          if (sessionToken !== null) {
            const session = await lockSession(sessionToken, client);
            const municipality = await readMunicipality(municipalityId, client);
            municipalityId = municipality.id;
            userId = sessionIdentity(session);
            idempotencyKey = scopedSubmissionKey(session.submissionScope, municipalityId, idempotencyKey);
            await onWriteCheckpoint('proposal_session_locked');
          }
          const idempotent = await runIdempotentWrite(
            {
              target: client,
              query,
              operation: 'submit_suggestion',
              idempotencyKey,
              request: {
                municipalityId,
                title,
                description,
                category,
                userId,
                ...(location === null ? {} : { location }),
              },
              responseStatus: 201,
            },
            async () => {
              const municipality = await readMunicipality(
                municipalityId,
                client,
              );
              assertPublicProposalContent({ title, description, location });
              const nowMs = clock();
              // Covers both authoritative sessions and the explicitly legacy scaffold.
              // The session lock already serializes bearer writes and revocation.
              await query('lock-proposal-quota', 'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
                [JSON.stringify(['proposal-quota', municipality.id, userId])], client);
              const recent = await query('recent-proposals-for-quota',
                `SELECT created_at FROM public.suggestions
                 WHERE municipality_id = $1 AND submitted_by_user_id = $2
                   AND created_at >= $3::timestamptz
                 ORDER BY created_at DESC LIMIT 3`,
                [municipality.id, userId, new Date(nowMs - 3600000).toISOString()], client);
              assertSubmissionQuota(recent.rows.map(row => row.created_at), nowMs);
              const timestamp = new Date(nowMs).toISOString();
              const problemId = `suggested-${createId()}`;
              await query(
                'insert-suggestion',
                `INSERT INTO public.suggestions (
                   id, municipality_id, title, normalized_title, description,
                   category, status, submitted_by_user_id,
                   submitted_by_display_name, location, created_at, updated_at
                 ) VALUES (
                   $1, $2, $3::text,
                   lower(regexp_replace(btrim($3::text), '[[:space:]]+', ' ', 'g')),
                   $4, $5, 'pending', $6, $7, $8::jsonb, $9::timestamptz, $9::timestamptz
                 )`,
                [
                  problemId,
                  municipality.id,
                  title,
                  description,
                  category,
                  userId,
                  userId === 'demo-user' ? 'Tu' : 'Cittadino',
                  location === null ? null : JSON.stringify(location),
                  timestamp,
                ],
                client,
              );
              await onWriteCheckpoint('submit_after_insert');
              return readSuggestion({
                municipalityId: municipality.id,
                problemId,
                userId,
                target: client,
              });
            },
          );
          return idempotent.value;
        },
        { logger },
      );
    } catch (error) {
      throw translatePostgresWriteError(error, 'submit_suggestion');
    }
  }

  // Used by the local operator CLI with database credentials, never by public HTTP.
  async function reviewSuggestion(input) {
    const review = validateProposalReview(input);
    return withTransaction(queryable, async client => {
      const municipality = await readMunicipality(input.municipalityId, client);
      const locked = await query('lock-suggestion-for-review',
        'SELECT status FROM public.suggestions WHERE id = $1 AND municipality_id = $2 FOR UPDATE',
        [input.problemId, municipality.id], client);
      if (!locked.rowCount) throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
      if (locked.rows[0].status !== review.expectedStatus) throw httpError(409, 'review_conflict', 'The proposal state changed.');
      await query('apply-proposal-review',
        'UPDATE public.suggestions SET status = $3, updated_at = GREATEST(created_at, clock_timestamp()) WHERE id = $1 AND municipality_id = $2',
        [input.problemId, municipality.id, review.targetStatus], client);
      await onWriteCheckpoint('review_after_update');
      await query('append-proposal-review',
        `INSERT INTO public.proposal_reviews (suggestion_id, municipality_id, decision, from_status, to_status, operator_label, private_reason)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [input.problemId, municipality.id, review.decision, review.expectedStatus, review.targetStatus, review.operatorLabel, review.reason], client);
      return readSuggestion({ municipalityId: municipality.id, problemId: input.problemId, userId: input.userId ?? 'operator', target: client });
    }, { logger });
  }

  async function voteNextProblem({
    idempotencyKey,
    municipalityId,
    problemId,
    vote,
    userId,
    sessionToken = null,
  }) {
    try {
      return await withTransaction(
        queryable,
        async (client) => {
          if (sessionToken !== null) {
            const session = await lockSession(sessionToken, client);
            const municipality = await readMunicipality(municipalityId, client);
            municipalityId = municipality.id;
            userId = sessionIdentity(session);
            idempotencyKey = scopedSubmissionKey(session.submissionScope, municipalityId, idempotencyKey);
            await onWriteCheckpoint('proposal_session_locked');
          }
          const idempotent = await runIdempotentWrite(
            {
              target: client,
              query,
              operation: 'vote_suggestion',
              idempotencyKey,
              request: { municipalityId, problemId, vote, userId },
              responseStatus: 200,
            },
            async () => {
          const municipality = await readMunicipality(municipalityId, client);
          const locked = await query(
            'lock-suggestion-for-vote',
            `SELECT id, title, description, category, status, location
             FROM public.suggestions
             WHERE id = $1 AND municipality_id = $2
             FOR UPDATE`,
            [problemId, municipality.id],
            client,
          );
          if (locked.rowCount === 0) {
            throw httpError(
              404,
              'suggested_problem_not_found',
              'Suggested problem not found.',
            );
          }

          const suggestion = locked.rows[0];
          if (suggestion.status === 'rejected') {
            throw httpError(404, 'suggested_problem_not_found', 'Suggested problem not found.');
          }
          const previous = await query(
            'suggestion-vote-by-owner',
            `SELECT vote
             FROM public.suggestion_votes
             WHERE suggestion_id = $1 AND user_id = $2`,
            [problemId, userId],
            client,
          );
          const previousVote = previous.rows[0]?.vote ?? 'none';
          if (previousVote === vote) {
            await query(
              'delete-suggestion-vote',
              `DELETE FROM public.suggestion_votes
               WHERE suggestion_id = $1 AND user_id = $2`,
              [problemId, userId],
              client,
            );
          } else {
            await query(
              'upsert-suggestion-vote',
              `INSERT INTO public.suggestion_votes
                 (suggestion_id, municipality_id, user_id, vote)
               VALUES ($1, $2, $3, $4)
               ON CONFLICT (suggestion_id, user_id) DO UPDATE SET
                 vote = excluded.vote,
                 updated_at = clock_timestamp()`,
              [problemId, municipality.id, userId, vote],
              client,
            );
          }
          await onWriteCheckpoint('vote_after_vote_mutation');

          const counts = await query(
            'suggestion-vote-counts',
            `SELECT
               count(*) FILTER (WHERE vote = 'up') AS votes_up,
               count(*) FILTER (WHERE vote = 'down') AS votes_down
             FROM public.suggestion_votes
             WHERE suggestion_id = $1 AND municipality_id = $2`,
            [problemId, municipality.id],
            client,
          );
          const votesUp = safeInteger(
            counts.rows[0].votes_up,
            'suggestion.votes_up',
          );
          const votesDown = safeInteger(
            counts.rows[0].votes_down,
            'suggestion.votes_down',
          );
          const status =
            suggestion.status === 'rejected'
              ? 'rejected'
              : votesUp - votesDown >= 1
                ? 'approved'
                : 'pending';
          await query(
            'update-suggestion-status',
            `UPDATE public.suggestions
             SET status = $3, updated_at = clock_timestamp()
             WHERE id = $1 AND municipality_id = $2`,
            [problemId, municipality.id, status],
            client,
          );

          if (status === 'approved') {
            const turn = await readCurrentTurn(municipality.id, client);
            const promoted = await query(
              'upsert-promoted-problem',
              `INSERT INTO public.problems (
                 id, municipality_id, turn_id, source_suggestion_id,
                 problem_key, title, zone_name, status, trend_percent
               ) VALUES (
                 $1, $2, $3, $4, $5, $6,
                 $7, 'stable', 0
               )
               ON CONFLICT (id) DO UPDATE SET
                 turn_id = excluded.turn_id,
                 source_suggestion_id = excluded.source_suggestion_id,
                 problem_key = excluded.problem_key,
                 title = excluded.title,
                 zone_name = excluded.zone_name,
                 status = excluded.status,
                 trend_percent = excluded.trend_percent,
                 updated_at = clock_timestamp()
               WHERE public.problems.municipality_id = excluded.municipality_id
                 AND public.problems.source_suggestion_id =
                   excluded.source_suggestion_id
               RETURNING id`,
              [
                `proposal_${problemId}`,
                municipality.id,
                turn.id,
                problemId,
                suggestion.category,
                suggestion.title,
                proposalLocationLabel(normalizeProposalLocation(suggestion.location)),
              ],
              client,
            );
            if (promoted.rowCount !== 1) {
              throw httpError(
                409,
                'write_conflict',
                'The promoted problem id conflicts with existing data.',
              );
            }
          } else {
            await query(
              'delete-demoted-problem',
              `DELETE FROM public.problems
               WHERE municipality_id = $1 AND source_suggestion_id = $2`,
              [municipality.id, problemId],
              client,
            );
          }

          await query(
            'sync-municipality-activation',
            `UPDATE public.municipalities m
             SET activation_state = CASE
               WHEN m.base_activation_state = 'active'
                 OR EXISTS (
                   SELECT 1
                   FROM public.suggestions s
                   WHERE s.municipality_id = m.id
                     AND s.status = 'approved'
                 )
               THEN 'active'
               ELSE 'collectingSignals'
             END,
             updated_at = clock_timestamp()
             WHERE m.id = $1`,
            [municipality.id],
            client,
          );

          return readSuggestion({
            municipalityId: municipality.id,
            problemId,
            userId,
            target: client,
          });
            },
          );
          return idempotent.value;
        },
        { logger },
      );
    } catch (error) {
      throw translatePostgresWriteError(error, 'vote_suggestion');
    }
  }

  async function upsertPrediction({
    idempotencyKey,
    turnId,
    problemId,
    userId,
    choice,
    motivations,
    confidence,
  }) {
    try {
      return await withTransaction(
        queryable,
        async (client) => {
          const idempotent = await runIdempotentWrite(
            {
              target: client,
              query,
              operation: 'upsert_prediction',
              idempotencyKey,
              request: {
                turnId,
                problemId,
                userId,
                choice,
                motivations,
                confidence,
              },
              responseStatus: 200,
            },
            async () => {
          const turnResult = await query(
            'turn-by-id-for-prediction-write',
            `SELECT id, municipality_id, state, start_at, end_at
             FROM public.turns
             WHERE id = $1
             FOR KEY SHARE`,
            [turnId],
            client,
          );
          if (turnResult.rowCount === 0) {
            throw httpError(404, 'turn_not_found', 'Turn not found.');
          }
          const turn = mapTurnRow(turnResult.rows[0]);
          const problemResult = await query(
            'problem-scope-for-prediction-write',
            `SELECT municipality_id, turn_id
             FROM public.problems
             WHERE id = $1
             FOR KEY SHARE`,
            [problemId],
            client,
          );
          if (problemResult.rowCount === 0) {
            throw httpError(404, 'problem_not_found', 'Problem not found.');
          }
          const problemScope = problemResult.rows[0];
          if (
            problemScope.municipality_id !== turn.municipalityId ||
            problemScope.turn_id !== turn.id
          ) {
            throw httpError(
              409,
              'problem_turn_mismatch',
              'Problem does not belong to this turn.',
            );
          }
          if (turn.state !== 'open') {
            throw httpError(409, 'turn_not_open', 'Turn is not open.');
          }

          const existingResult = await query(
            'prediction-by-owner-for-update',
            `SELECT id, turn_id, problem_id, user_id, choice, motivations,
                    confidence, created_at, updated_at
             FROM public.predictions
             WHERE turn_id = $1 AND problem_id = $2 AND user_id = $3
             FOR UPDATE`,
            [turn.id, problemId, userId],
            client,
          );
          const existing =
            existingResult.rowCount === 0
              ? null
              : mapPredictionRow(existingResult.rows[0]);
          if (existing && existing.choice !== choice) {
            throw httpError(
              409,
              'prediction_locked',
              'Prediction choice is already locked for this turn.',
            );
          }

          const saved = existing
            ? await query(
                'update-prediction-metadata',
                `UPDATE public.predictions
                 SET motivations = $4,
                     confidence = $5,
                     updated_at = clock_timestamp()
                 WHERE turn_id = $1 AND problem_id = $2 AND user_id = $3
                 RETURNING id, turn_id, problem_id, user_id, choice,
                           motivations, confidence, created_at, updated_at`,
                [turn.id, problemId, userId, motivations, confidence],
                client,
              )
            : await query(
                'insert-prediction',
                `INSERT INTO public.predictions (
                   id, municipality_id, turn_id, problem_id, user_id, choice,
                   motivations, confidence
                 ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                 RETURNING id, turn_id, problem_id, user_id, choice,
                           motivations, confidence, created_at, updated_at`,
                [
                  `${turn.id}:${problemId}:${userId}`,
                  turn.municipalityId,
                  turn.id,
                  problemId,
                  userId,
                  choice,
                  motivations,
                  confidence,
                ],
                client,
              );
          await onWriteCheckpoint('prediction_after_save');
          return mapPredictionRow(saved.rows[0]);
            },
          );
          return idempotent.value;
        },
        { logger },
      );
    } catch (error) {
      throw translatePostgresWriteError(error, 'upsert_prediction');
    }
  }

  async function getPredictions({ turnId, userId }) {
    const turn = await findTurn(turnId);
    const result = await query(
      'predictions-by-owner-and-turn',
      `SELECT id, turn_id, problem_id, user_id, choice, motivations,
              confidence, created_at, updated_at
       FROM public.predictions
       WHERE turn_id = $1 AND municipality_id = $2 AND user_id = $3
       ORDER BY updated_at DESC, id`,
      [turn.id, turn.municipalityId, userId],
    );
    return result.rows.map(mapPredictionRow);
  }

  async function getCivicLoopSummary(municipalityId) {
    const municipality = await getMunicipality(municipalityId);
    const turn = await getCurrentTurn(municipality.id);
    const [problems, suggestions, predictions] = await Promise.all([
      listProblems(municipality.id),
      listNextProblems({ municipalityId: municipality.id }),
      getPredictions({ turnId: turn.id, userId: 'demo-user' }),
    ]);
    const confirmed = suggestions
      .filter((item) => item.status === 'approved')
      .sort((left, right) => right.score - left.score);
    return {
      municipalityName: municipality.name,
      proposedThemes: suggestions.length,
      confirmedThemes: confirmed.length,
      cardsInTurn: problems.length,
      predictions: predictions.length,
      outcomes: 0,
      reputationPoints: 0,
      topThemeTitle: confirmed[0]?.title ?? null,
    };
  }

  async function getLeaderboard(municipalityId) {
    const municipality = await getMunicipality(municipalityId);
    const result = await query(
      'leaderboard-by-municipality',
      `SELECT user_id, sum(points_delta)::bigint AS points
       FROM public.reputation_events
       WHERE municipality_id = $1
       GROUP BY user_id
       ORDER BY points DESC, user_id`,
      [municipality.id],
    );
    return result.rows.map((row, index) => ({
      userId: requiredText(row.user_id, 'leaderboard.user_id'),
      displayName: row.user_id === 'demo-user' ? 'Tu' : row.user_id,
      rank: index + 1,
      points: safeInteger(row.points, 'leaderboard.points'),
    }));
  }

  async function resolvePrediction({ problemId, choice }) {
    const problem = await findProblem(problemId);
    const winningChoice = statusToChoice(problem.status);
    const correct = choice === winningChoice;
    return {
      problemId,
      choice,
      winningChoice,
      correct,
      pointsDelta: correct ? 12 : -3,
      resolvedAt: new Date().toISOString(),
    };
  }

  async function findTurn(turnId) {
    const result = await query(
      'turn-by-id',
      `SELECT id, municipality_id, state, start_at, end_at
       FROM public.turns
       WHERE id = $1`,
      [turnId],
    );
    if (result.rowCount === 0) {
      throw httpError(404, 'turn_not_found', 'Turn not found.');
    }
    return mapTurnRow(result.rows[0]);
  }

  async function findProblem(problemId) {
    const result = await query(
      'problem-by-id',
      `SELECT id, problem_key, title, zone_name, status, trend_percent,
              updated_at
       FROM public.problems
       WHERE id = $1`,
      [problemId],
    );
    if (result.rowCount === 0) {
      throw httpError(404, 'problem_not_found', 'Problem not found.');
    }
    return mapProblemRow(result.rows[0]);
  }

  return {
    createProposalSession, getProposalSession, revokeProposalSession, lookupSubmission, getOwnNextProblem,
    getMunicipality,
    getCurrentTurn,
    listProblems,
    listNextProblems,
    getNextProblem,
    submitNextProblem,
    reviewSuggestion,
    voteNextProblem,
    getPredictions,
    upsertPrediction,
    resolvePrediction,
    getCivicLoopSummary,
    getLeaderboard,
  };
}

function requiredText(value, field) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`${field} must be a non-empty string.`);
  }
  return value;
}

function safeInteger(value, field) {
  const parsed = typeof value === 'string' ? Number(value) : value;
  if (!Number.isSafeInteger(parsed)) {
    throw new TypeError(`${field} must be a safe integer.`);
  }
  return parsed;
}
