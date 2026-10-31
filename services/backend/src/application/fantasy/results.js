import { scoreVersionedFantasyCard } from '../../domain/fantasy/scoring.js';
import { randomUUID } from 'node:crypto';
import { exactFields, fantasyError } from './teams.js';
import { transaction } from '../../persistence/postgres/fantasy-repository.js';

export function createFantasyResults({ database, teams, catalog, now = Date.now }) {
  const isoNow = () => new Date(now()).toISOString();
  function fail(code, message, status = 409) { throw fantasyError(status, code, message); }
  async function context(municipalityId, userId, matchdayId, time) {
    const season = (await teams.seasonFor(municipalityId));
    return { season, player: (await teams.playerFor(season.id, userId)), day: (await teams.dayFor(season.id, matchdayId, time)), time };
  }
  async function snapshotFor(c) {
    const row = (await database.one("select_snapshots_by_season_id_user_id_matchday_id_2", c.season.id, c.player.user_id, c.day.id));
    return row ? JSON.parse(row.payload) : null;
  }
  async function freeze(c) {
    const snapshot = (await snapshotFor(c));
    if (!snapshot?.eligible || Date.parse(c.time) < Date.parse(c.day.observation_ends_at)) return;
    const insert = 'insert_reveals';
    for (const cardId of snapshot.starterIds) {
      const row = (await database.one("select_outcomes_by_season_id_matchday_id_card_id", c.season.id, c.day.id, cardId));
      if (!row) continue;
      const outcome = JSON.parse(row.payload);
      const prediction = snapshot.predictions[cardId] ?? null;
      const score = scoreVersionedFantasyCard({rulesVersion:snapshot.rulesVersion,outcome,prediction,captain:snapshot.captainId===cardId});
      await database.execute(insert, c.season.id, c.player.user_id, c.day.id, cardId, JSON.stringify({ cardId, matchdayId: c.day.id,
        outcome, prediction, score, rulesVersion: snapshot.rulesVersion }));
    }
  }
  async function view(c,options={}) {
    const snapshot = (await snapshotFor(c));
    const outcomes = (await database.many("select_outcomes_by_season_id_matchday_id", c.season.id, c.day.id)).map((row) => JSON.parse(row.payload));
    const results = await Promise.all((await database.many("select_reveals_by_season_id_user_id_matchday_id", c.season.id, c.player.user_id, c.day.id)).map(async (row) => {
        const result = JSON.parse(row.payload);
        const reflection = options.frozenOriginal?null:(await database.one("select_reflections_by_season_id_user_id_matchday_id_card_id", c.season.id, c.player.user_id, c.day.id, result.cardId));
        const score = reflection ? scoreVersionedFantasyCard({rulesVersion:result.rulesVersion,outcome:result.outcome,prediction:result.prediction,captain:result.score.captainMultiplier===1.5,reflection:true}) : result.score;
        return { ...result, reflection: reflection?.answer ?? null, score: { ...score, frozenTotal: result.score.frozenTotal } };
      }));
    const frozenPoints = results.reduce((sum, r) => sum + r.score.frozenTotal, 0);
    const reflectionBonus = results.reduce((sum, r) => sum + r.score.reflectionBonus, 0);
    const eligible = Boolean(snapshot?.eligible);
    const transferPenalty = snapshot?.transferPenalty ?? 0;
    const canFinalize = Date.parse(c.time) >= Date.parse(c.day.observation_ends_at) && snapshot != null && (!eligible || results.length === snapshot.starterIds.length);
    if (canFinalize) (await database.execute("insert_finalizations", c.season.id, c.player.user_id, c.day.id, c.time));
    const definitive = Boolean((await database.one("select_finalizations_by_season_id_user_id_matchday_id", c.season.id, c.player.user_id, c.day.id)));
    const response={ serverTime: c.time, isDemo: Boolean(c.season.is_demo), seasonId: c.season.id, matchdayId: c.day.id, revision: c.player.revision,
      outcomes, results, summary: { status: definitive ? 'final' : 'provisional', eligible, frozenPoints, reflectionBonus, transferPenalty,
        total: eligible ? frozenPoints + reflectionBonus - transferPenalty : 0, cooperativeScore: null } };
    if(snapshot?.rulesVersion==='fantasy-v2'){
      const current=await database.raw('SELECT * FROM fantasy_result_revisions WHERE season_id=$1 AND user_id=$2 AND matchday_id=$3 ORDER BY result_revision DESC LIMIT 1',[c.season.id,c.player.user_id,c.day.id]);
      response.resultRevision=current.rows[0]?.result_revision??0;response.currentRevision=response.resultRevision;
      response.summary.coverage={expectedCards:eligible?snapshot.starterIds.length:0,evaluableCards:results.filter(r=>r.outcome.disposition==='determinate').length,closedUndeterminableCards:results.filter(r=>r.outcome.disposition==='undeterminable').length};
      if(current.rows[0]&&!options.original)return {...response,...current.rows[0].payload,revision:c.player.revision,serverTime:c.time,resultRevision:response.resultRevision,currentRevision:response.currentRevision};
    }
    return response;
  }
  const canonical=v=>v===null||typeof v!=='object'?JSON.stringify(v):Array.isArray(v)?'['+v.map(canonical).join(',')+']':'{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+canonical(v[k])).join(',')+'}';
  async function recalculate(seasonId,matchdayId){
    return transaction(database,async()=>{
      const day=await teams.dayFor(seasonId,matchdayId,isoNow());if(day.rules_version!=='fantasy-v2')return;
      await teams.reconcile();
      const season=(await database.raw('SELECT * FROM fantasy_seasons WHERE id=$1',[seasonId])).rows[0];
      const outcomes=(await database.many('select_outcomes_by_season_id_matchday_id',seasonId,matchdayId)).map(r=>JSON.parse(r.payload));
      const versions=Object.fromEntries(outcomes.map(o=>[o.cardId,o.version]));
      const snapshots=(await database.raw('SELECT * FROM fantasy_snapshots WHERE season_id=$1 AND matchday_id=$2',[seasonId,matchdayId])).rows;
      for(const row of snapshots){const snapshot=JSON.parse(row.payload);if(!snapshot.eligible)continue;
        const player=await teams.playerFor(seasonId,row.user_id),c={season,player,day,time:isoNow()};await freeze(c);
        const original=await view(c,{original:true}),results=[];
        for(const cardId of snapshot.starterIds){const outcome=outcomes.find(o=>o.cardId===cardId);if(!outcome)continue;const reflection=await database.one('select_reflections_by_season_id_user_id_matchday_id_card_id',seasonId,row.user_id,matchdayId,cardId);const prediction=snapshot.predictions[cardId]??null;const score=scoreVersionedFantasyCard({rulesVersion:snapshot.rulesVersion,outcome,prediction,captain:snapshot.captainId===cardId,reflection:Boolean(reflection)});results.push({cardId,matchdayId,outcome,prediction,score,reflection:reflection?.answer??null,rulesVersion:snapshot.rulesVersion});}
        const frozenPoints=results.reduce((n,r)=>n+r.score.frozenTotal,0),reflectionBonus=results.reduce((n,r)=>n+r.score.reflectionBonus,0),transferPenalty=snapshot.transferPenalty??0;
        const summary={status:results.length===snapshot.starterIds.length?'final':'provisional',eligible:true,frozenPoints,reflectionBonus,transferPenalty,total:frozenPoints+reflectionBonus-transferPenalty,cooperativeScore:null,coverage:{expectedCards:snapshot.starterIds.length,evaluableCards:results.filter(r=>r.outcome.disposition==='determinate').length,closedUndeterminableCards:results.filter(r=>r.outcome.disposition==='undeterminable').length}};
        const previous=(await database.raw('SELECT * FROM fantasy_result_revisions WHERE season_id=$1 AND user_id=$2 AND matchday_id=$3 ORDER BY result_revision DESC LIMIT 1',[seasonId,row.user_id,matchdayId])).rows[0];
        const payload={outcomes,results,summary};if(previous&&canonical(previous.evaluation_versions)===canonical(versions)&&canonical(previous.payload)===canonical(payload))continue;
        await database.raw('INSERT INTO fantasy_result_revisions(season_id,user_id,matchday_id,result_revision,evaluation_versions,payload,at) VALUES($1,$2,$3,$4,$5,$6,$7)',[seasonId,row.user_id,matchdayId,(previous?.result_revision??0)+1,JSON.stringify(versions),JSON.stringify(payload),isoNow()]);
      }
    });
  }
  return {
    recalculate,
    async history(municipalityId,userId,matchdayId){await teams.reconcile();return transaction(database,async()=>{const c=await context(municipalityId,userId,matchdayId,isoNow());await freeze(c);const original=await view(c,{original:true,frozenOriginal:true});const rows=(await database.raw('SELECT * FROM fantasy_result_revisions WHERE season_id=$1 AND user_id=$2 AND matchday_id=$3 ORDER BY result_revision',[c.season.id,userId,c.day.id])).rows;return {seasonId:c.season.id,matchdayId:c.day.id,original,items:rows.map(r=>({resultRevision:r.result_revision,evaluationVersions:r.evaluation_versions,...r.payload,at:new Date(r.at).toISOString()})),currentRevision:rows.at(-1)?.result_revision??0};});},
    async publish(municipalityId, matchdayId, cardId, body) {
      exactFields(body, ['observed', 'sourceLabel', 'sourceDate', 'sourceStatus', 'explanation', 'rulesVersion', 'version']);
      return (await transaction(database, async () => {
        const time = isoNow();
        const season = (await teams.seasonFor(municipalityId));
        const day = (await teams.dayFor(season.id, matchdayId, time));
        if(day.rules_version==='fantasy-v2')fail('measurements_required','V2 outcomes require supervisor evidence publication.',403);
        const card = (await catalog(municipalityId)).items.find((c) => c.id === cardId);
        if (!card) fail('not_found', 'Card not found.', 404);
        if (!['improves', 'stable', 'worsens'].includes(body.observed) || body.version !== 1 || body.rulesVersion !== day.rules_version || typeof body.explanation !== 'string' || body.explanation.length < 1 || body.explanation.length > 1000) {
          fail('invalid_field', 'Invalid outcome, rules version or explanation.', 400);
        }
        if (body.sourceStatus !== 'verified' || card.sourceStatus !== 'verified' || body.sourceLabel !== card.sourceLabel) fail('source_not_verified', 'An authorized verified catalog source is required.');
        const dateValue = typeof body.sourceDate === 'string' && /(?:Z|[+-]\d{2}:\d{2})$/.test(body.sourceDate) ? Date.parse(body.sourceDate) : NaN;
        if (!Number.isFinite(dateValue) || dateValue < Date.parse(day.locks_at) || dateValue > Date.parse(day.observation_ends_at)) fail('invalid_field', 'Source date must be within the observation window and include a timezone.', 400);
        if (Date.parse(time) < Date.parse(day.observation_ends_at) || dateValue > Date.parse(time)) fail('observation_pending', 'Observation window has not ended.');
        const content = { matchdayId, cardId, observed: body.observed, sourceLabel: card.sourceLabel,
          sourceDate: new Date(dateValue).toISOString(), sourceStatus: 'verified', explanation: body.explanation,
          rulesVersion: body.rulesVersion, version: body.version, isDemo: Boolean(season.is_demo) };
        const row = (await database.one("select_outcomes_by_season_id_matchday_id_card_id", season.id, matchdayId, cardId));
        if (row) {
          const original = JSON.parse(row.payload);
          if (Object.entries(content).some(([key, value]) => original[key] !== value)) fail('outcome_immutable', 'Published outcomes cannot be overwritten.');
          return { serverTime: time, isDemo: Boolean(season.is_demo), outcome: original };
        }
        const outcome = { ...content, publicationId: randomUUID(), publishedAt: time, publisherRole: 'pilotModerator' };
        (await database.execute("insert_outcomes", season.id, matchdayId, cardId, JSON.stringify(outcome)));
        return { serverTime: time, isDemo: Boolean(season.is_demo), outcome };
      }));
    },
    async read(municipalityId, userId, matchdayId) {
      (await teams.reconcile());
      return (await transaction(database, async () => {
        const c = (await context(municipalityId, userId, matchdayId, isoNow()));
        (await freeze(c));
        return (await view(c));
      }));
    },
    async reflect(municipalityId, userId, matchdayId, cardId, body) {
      exactFields(body, ['expectedRevision', 'answer']);
      if (!['observedIntervention', 'externalConditions', 'insufficientInformation'].includes(body.answer) || !Number.isSafeInteger(body.expectedRevision) || body.expectedRevision < 1) fail('invalid_field', 'Expected revision and a structured reflection answer are required.', 400);
      (await teams.reconcile());
      return (await transaction(database, async () => {
        const c = (await context(municipalityId, userId, matchdayId, isoNow()));
        const prior = (await database.one("select_reflections_by_season_id_user_id_matchday_id_card_id", c.season.id, userId, c.day.id, cardId));
        if (prior) {
          if (prior.answer !== body.answer) fail('reflection_immutable', 'A reflection was already accepted.');
          return (await view(c));
        }
        if (body.expectedRevision !== c.player.revision) fail('stale_revision', 'Team revision has changed.');
        const revealed = (await database.one("select_reveals_by_season_id_user_id_matchday_id_card_id", c.season.id, userId, c.day.id, cardId));
        if (!revealed) fail('reflection_not_available', 'Reveal an eligible starter result before reflecting.');
        (await database.execute("insert_reflections", c.season.id, userId, c.day.id, cardId, body.answer, c.time));
        (await database.execute("update_players_by_season_id_user_id", c.season.id, userId));
        c.player = (await teams.playerFor(c.season.id, userId));
        if(c.day.rules_version==='fantasy-v2')await recalculate(c.season.id,c.day.id);
        return (await view(c));
      }));
    },
  };
}
