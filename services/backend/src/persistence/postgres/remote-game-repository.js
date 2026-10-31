import { withTransaction } from './transaction.js';
import { createHash } from 'node:crypto';
import { sessionHash, sessionIdentity, sessionRevoked } from '../../domain/proposal-session.js';
import { canonicalMunicipalityId } from '../../domain/catalog.js';
import { httpError } from '../../domain/errors.js';

const iso = value => new Date(value).toISOString();
const silentLogger = { warn() {}, error() {} };

export function createRemoteGameRepository(pool, { clock = Date.now, onWriteCheckpoint = async () => {} } = {}) {
  async function transaction(token, action, { consistent = true } = {}) {
    try {
    return await withTransaction(pool, async client => {
      if (consistent) await client.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
      let userId = null;
      if (token !== undefined) {
        const result = await client.query(
          'SELECT submission_scope, revoked_at, account_id, expires_at FROM public.proposal_sessions WHERE token_hash=$1 FOR SHARE', [sessionHash(token)]);
        const row = result.rows[0];
        if (!row || row.revoked_at !== null) throw sessionRevoked();
        if(row.expires_at&&Date.parse(row.expires_at)<=clock())throw httpError(401,'session_expired','Session has expired.');
        userId = sessionIdentity({ submissionScope: row.submission_scope, accountId:row.account_id });
      }
      return action(client, userId);
    }, { logger: silentLogger });
    } catch (error) {
      if (error.code === '40001') throw httpError(409, 'stale_revision', 'The state changed concurrently; retry.');
      throw error;
    }
  }
  async function turn(client, id) {
    const { rows } = await client.query('SELECT id,municipality_id FROM public.turns WHERE id=$1', [id]);
    if (!rows[0]) throw httpError(404, 'turn_not_found', 'Turn not found.');
    return rows[0];
  }
  async function results(client, turnId, userId) {
    return (await client.query(`SELECT r.problem_id,r.winning_choice,r.points_delta,p.choice
      FROM public.prediction_results r JOIN public.predictions p ON p.id=r.prediction_id
      WHERE r.turn_id=$1 AND r.user_id=$2 ORDER BY r.problem_id`, [turnId, userId])).rows;
  }
  function authenticated(token, action, options) {
    sessionHash(token);
    return transaction(token, action, options);
  }
  return {
    async resultsForTurn({ turnId, sessionToken }) {
      return authenticated(sessionToken, async (client, userId) => {
        await turn(client, turnId);
        return results(client, turnId, userId);
      });
    },
    async resultsForMunicipality({ municipalityId, sessionToken }) {
      return authenticated(sessionToken, async (client, userId) => {
        const id = canonicalMunicipalityId(municipalityId);
        if (!(await client.query('SELECT id FROM public.municipalities WHERE id=$1', [id])).rowCount) {
          throw httpError(404, 'municipality_not_found', 'Municipality not found.');
        }
        const { rows } = await client.query('SELECT id FROM public.turns WHERE municipality_id=$1 ORDER BY start_at,id', [id]);
        const groups = [];
        for (const row of rows) groups.push({ turnId: row.id, results: await results(client, row.id, userId) });
        return groups;
      });
    },
    async predictionsForProblem(problemId) {
      return transaction(undefined, async client => {
        const problem = (await client.query('SELECT municipality_id FROM public.problems WHERE id=$1', [problemId])).rows[0];
        if (!problem) throw httpError(404, 'problem_not_found', 'Problem not found.');
        const turns = (await client.query('SELECT id,start_at FROM public.turns WHERE municipality_id=$1 ORDER BY start_at,id', [problem.municipality_id])).rows;
        const groups = [];
        for (const row of turns) {
          const predictions = (await client.query(`SELECT choice,motivations,updated_at FROM public.predictions
            WHERE turn_id=$1 AND problem_id=$2 ORDER BY id`, [row.id, problemId])).rows;
          groups.push({ turnId: row.id, startAt: iso(row.start_at),
            predictions: predictions.map(item => ({ ...item, updated_at: iso(item.updated_at) })) });
        }
        return groups;
      });
    },
    async resolvePrediction({ problemId, choice, sessionToken }, evaluate) {
      try {
        return await authenticated(sessionToken, async (client, userId) => {
          const problem = (await client.query('SELECT id,municipality_id,turn_id,status FROM public.problems WHERE id=$1 FOR SHARE', [problemId])).rows[0];
          if (!problem) throw httpError(404, 'problem_not_found', 'Problem not found.');
          const prediction = (await client.query(`SELECT * FROM public.predictions
            WHERE turn_id=$1 AND problem_id=$2 AND user_id=$3 FOR UPDATE`, [problem.turn_id, problemId, userId])).rows[0];
          if (!prediction) throw httpError(404, 'prediction_not_found', 'Prediction not found for this session.');
          if (prediction.choice !== choice) throw httpError(409, 'prediction_choice_mismatch', 'Resolution choice differs from the saved prediction.');
          const prior = (await client.query('SELECT * FROM public.prediction_results WHERE prediction_id=$1', [prediction.id])).rows[0];
          let row = prior;
          if (!row) {
            const scoring = evaluate(prediction, problem);
            const resolvedAt = iso(clock());
            row = (await client.query(`INSERT INTO public.prediction_results
              (prediction_id,municipality_id,turn_id,problem_id,user_id,winning_choice,correct,points_delta,resolved_at)
              VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
            [prediction.id, problem.municipality_id, problem.turn_id, problemId, userId,
              scoring.winningChoice, scoring.correct, scoring.pointsDelta, resolvedAt])).rows[0];
            await onWriteCheckpoint('remote_result_after_insert');
            await client.query(`INSERT INTO public.reputation_events
              (municipality_id,turn_id,user_id,prediction_id,event_type,points_delta,idempotency_key,occurred_at)
              VALUES($1,$2,$3,$4,'demo_prediction_result',$5,$6,$7)`,
            [problem.municipality_id, problem.turn_id, userId, prediction.id, row.points_delta,
              'remote-result:' + createHash('sha256').update(prediction.id).digest('hex'), resolvedAt]);
          }
          return { turnId: row.turn_id, problemId, choice, winningChoice: row.winning_choice,
            result: choice === row.winning_choice ? 'correct' : choice === 'stable' || row.winning_choice === 'stable' ? 'partial' : 'wrong',
            correct: row.correct, pointsDelta: row.points_delta, resolvedAt: iso(row.resolved_at) };
        }, { consistent: false });
      } catch (error) {
        if (error.code === '40001') throw httpError(409, 'stale_revision', 'The prediction changed concurrently; retry.');
        throw error;
      }
    },
  };
}
