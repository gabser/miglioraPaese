import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import { before, after, describe, it } from 'node:test';
import pg from 'pg';
import { createRemoteGameService, evaluateRemotePrediction } from '../src/application/remote-game-service.js';
import { createRemoteGameRepository } from '../src/persistence/postgres/remote-game-repository.js';
import { createPostgresStore } from '../src/persistence/postgres/postgres-store.js';
import { runPostgresMigrations } from '../src/persistence/postgres/migrator.js';
import { seedPostgres } from '../src/persistence/postgres/seed.js';
import { sessionIdentity } from '../src/domain/proposal-session.js';
import { createApp } from '../src/http/app.js';

const logger = { warn() {}, error() {}, debug() {}, info() {} };
const databaseUrl = process.env.TEST_DATABASE_URL;
const turnId = 'turn-bologna-today';
const problemId = 'problem-traffic-indipendenza';
let admin, pool, connectionString, name, store, service;
const makeService = options => createRemoteGameService({ repository: createRemoteGameRepository(pool, options) });

it('retains the source legacy remote scoring cases, separate from fantasy and XP', () => {
  const choices = ['improve', 'stable', 'worsen'];
  const expected = [['correct','partial','wrong'],['partial','correct','partial'],['wrong','partial','correct']];
  choices.forEach((observed, i) => choices.forEach((prediction, j) =>
    assert.equal(evaluateRemotePrediction(observed, prediction), expected[i][j])));
});

describe('remote legacy game PostgreSQL continuity', { skip: !databaseUrl }, () => {
  before(async () => {
    const url = new URL(databaseUrl);
    assert.ok(['127.0.0.1','localhost','[::1]'].includes(url.hostname));
    assert.match(url.pathname, /_test$/);
    name = 'remote_game_' + randomUUID().replaceAll('-', '') + '_test';
    admin = new pg.Pool({ connectionString: databaseUrl });
    await admin.query('CREATE DATABASE ' + name);
    url.pathname = '/' + name;
    connectionString = url.href;
    pool = new pg.Pool({ connectionString });
    await runPostgresMigrations({ databaseUrl: connectionString, sourceCommit: 'sentinelle-remote-game-test', logger });
    await seedPostgres(pool, { profile: 'test' });
    store = createPostgresStore(pool, { logger });
    service = makeService();
  });
  after(async () => {
    await pool?.end();
    if (admin && name) await admin.query('DROP DATABASE IF EXISTS ' + name + ' WITH (FORCE)');
    await admin?.end();
  });

  async function predicted(choice = 'worsen', target = problemId) {
    const session = await store.createProposalSession();
    await store.upsertPrediction({ turnId, problemId: target,
      sessionToken: session.token,
      userId: sessionIdentity(session), choice, motivations: ['visibleActions'], confidence: 'considered',
      idempotencyKey: 'fixture-' + randomUUID() });
    return session;
  }

  async function request(path, { token, method='GET', body, key } = {}) {
    const req = Readable.from(body === undefined ? [] : [Buffer.from(JSON.stringify(body))]);
    Object.assign(req,{method,url:path,headers:{
      ...(token?{authorization:'Bearer '+token}:{}),...(key?{'idempotency-key':key}:{}) }});
    let status,payload,headers;
    await createApp({store,remoteGame:service})(req,{
      writeHead(value,fields){status=value;headers=fields;},end(value){payload=JSON.parse(value);} });
    return {status,body:payload,headers};
  }

  it('serves JSON routes with bearer ownership, source DTOs, validation and public insights', async () => {
    const owner = await store.createProposalSession();
    const stranger = await store.createProposalSession();
    const predictionPath = `/v1/turns/${turnId}/predictions`;
    const saved = await request(predictionPath+'/'+problemId, {token:owner.token,method:'PUT',key:'http-prediction-key',
      body:{choice:'worsen',userId:'attacker-id',motivations:['visibleActions']} });
    assert.equal(saved.status,200); assert.equal(saved.body.userId,sessionIdentity(owner));
    const own = await request(predictionPath+'?userId=attacker-id',{token:owner.token});
    assert.equal(own.body.items.length,1);
    const other = await request(predictionPath+'?userId='+encodeURIComponent(sessionIdentity(owner)),{token:stranger.token});
    assert.deepEqual(other.body.items,[]);
    const path = '/v1/problems/'+problemId+'/resolve';
    assert.equal((await request(path,{token:owner.token,method:'POST',body:{choice:'invalid'}})).status,400);
    assert.equal((await request(path,{token:stranger.token,method:'POST',body:{choice:'worsen'}})).status,404);
    const resolution = await request(path,{token:owner.token,method:'POST',body:{choice:'worsen',userId:'attacker-id'}});
    assert.equal(resolution.status,200);assert.equal(resolution.body.result,'correct');
    const publicRanking = await request('/v1/municipalities/bologna/leaderboard');
    assert.equal(publicRanking.status,200);
    assert.equal(JSON.stringify(publicRanking.body).includes(sessionIdentity(owner)),false);
    assert.ok(publicRanking.body.items.every(row=>!row.userId.startsWith('session:')));
    for (const suffix of ['prediction-results','reputation']) {
      const target = `/v1/turns/${turnId}/${suffix}`;
      assert.equal((await request(target)).status,401);
      const read = await request(target,{token:owner.token});
      assert.equal(read.status,200);assert.equal(read.headers['cache-control'],'no-store');
      assert.equal((await request(`/v1/turns/missing/${suffix}`,{token:owner.token})).status,404);
    }
    assert.equal((await request('/v1/municipalities/bologna/reputation-history',{token:owner.token})).body.items[0].totalPoints,10);
    for (const resource of ['insight','insight-history','critical-insights']) {
      assert.equal((await request(`/v1/problems/${problemId}/${resource}`)).status,200);
      assert.equal((await request(`/v1/problems/missing/${resource}`)).status,404);
    }
    assert.equal((await request(`/v1/problems/${problemId}/critical-insights?userReflectionIndex=21`)).status,400);
    assert.equal((await request(`/v1/problems/${problemId}/critical-insights?userChoice=invalid`)).status,400);
    assert.equal((await request(`/v1/problems/${problemId}/critical-insights?userConfidence=invalid`)).status,400);
  });

  it('resolves from the real session, persists one ledger event and replays concurrently and after restart', async () => {
    const owner = await predicted();
    const stranger = await store.createProposalSession();
    const input = { problemId, choice: 'worsen', sessionToken: owner.token };
    await assert.rejects(service.getPredictionResults({ turnId }), e => e.statusCode === 401);
    await assert.rejects(service.resolvePrediction({ ...input, sessionToken:'forged-token' }), e => e.statusCode === 401);
    await assert.rejects(service.resolvePrediction({ ...input, sessionToken: stranger.token }), e => e.code === 'prediction_not_found');
    await assert.rejects(service.resolvePrediction({ ...input, choice: 'stable' }), e => e.code === 'prediction_choice_mismatch');
    const [a,b] = await Promise.all([service.resolvePrediction(input), service.resolvePrediction(input)]);
    assert.deepEqual(a,b);
    assert.equal(a.result, 'correct'); assert.equal(a.pointsDelta,10);
    const records = await pool.query('SELECT count(*)::int count FROM public.reputation_events WHERE user_id=$1', [sessionIdentity(owner)]);
    assert.equal(records.rows[0].count,1);
    await pool.end();
    pool = new pg.Pool({ connectionString });
    store = createPostgresStore(pool, { logger });
    service = makeService();
    assert.deepEqual(await service.resolvePrediction(input),a);
    assert.deepEqual(await service.getPredictionResults({ turnId, sessionToken: owner.token }), { items: [{ problemId, result:'correct' }] });
    assert.deepEqual(await service.getReputationScore({ turnId, sessionToken: owner.token }), { totalPoints:10,accuracy:1,predictionsCount:1 });
    assert.deepEqual(await service.getPredictionResults({ turnId, sessionToken: stranger.token }), { items: [] });
  });

  it('awards source partial and wrong results without deriving civic XP', async () => {
    for (const [choice,result,points,accuracy] of [['stable','partial',4,0.5],['improve','wrong',0,0]]) {
      const session = await predicted(choice);
      const resolution = await service.resolvePrediction({ problemId, choice, sessionToken: session.token });
      assert.equal(resolution.result,result); assert.equal(resolution.pointsDelta,points);
      assert.deepEqual(await service.getReputationScore({ turnId, sessionToken: session.token }),
        { totalPoints:points,accuracy,predictionsCount:1 });
      const history = await service.getReputationHistory({ municipalityId:'comune:Bologna',sessionToken:session.token });
      assert.deepEqual(history.items,[{totalPoints:points,accuracy,predictionsCount:1}]);
    }
  });

  it('rolls back result and ledger together on failure', async () => {
    const session = await predicted();
    const failing = makeService({ onWriteCheckpoint: async () => { throw new Error('synthetic-write-failure'); } });
    const input = { problemId, choice:'worsen',sessionToken:session.token };
    await assert.rejects(failing.resolvePrediction(input), /synthetic-write-failure/);
    assert.deepEqual(await service.getPredictionResults({ turnId,sessionToken:session.token }),{items:[]});
    assert.deepEqual(await service.getReputationScore({ turnId,sessionToken:session.token }),{totalPoints:0,accuracy:0,predictionsCount:0});
    assert.equal((await service.resolvePrediction(input)).pointsDelta,10);
  });

  it('suppresses small aggregates, publishes sufficient samples and rejects unknown scopes', async () => {
    const green = 'problem-remote-aggregate-fixture';
    await pool.query(`INSERT INTO public.problems
      (id,municipality_id,turn_id,problem_key,title,zone_name,status,trend_percent)
      VALUES($1,'bologna',$2,'green','Synthetic aggregate fixture','Test zone','improving',9)`, [green,turnId]);
    await predicted('improve',green); await predicted('stable',green);
    const hidden = await service.getAggregatedInsight(green);
    assert.equal(hidden.totalPredictions,0);
    assert.ok(Object.values(hidden.choiceDistribution).every(n=>n===0));
    assert.deepEqual(await service.getCriticalInsights({ problemId:green }), { items:[{
      headline:'Dati in raccolta',supporting:'Non ci sono ancora previsioni aggregate per questo tema.',note:null }] });
    await predicted('improve',green);
    const visible = await service.getAggregatedInsight(green);
    assert.equal(visible.totalPredictions,3);
    assert.deepEqual(visible.choiceDistribution,{improve:2,stable:1,worsen:0});
    assert.equal(visible.motivationDistribution.visibleActions,3);
    const history = await service.getInsightHistory(green);
    assert.equal(history.snapshots[0].totalPredictions,3);
    assert.deepEqual(history.snapshots[0].motivationTop,['visibleActions']);
    assert.equal((await service.getCriticalInsights({ problemId:green,userChoice:'stable',userReflectionIndex:0 })).items.length,3);
    await assert.rejects(service.getAggregatedInsight('missing'),e=>e.code==='problem_not_found');
    const session = await store.createProposalSession();
    await assert.rejects(service.getPredictionResults({ turnId:'missing',sessionToken:session.token }),e=>e.code==='turn_not_found');
    await assert.rejects(service.getReputationHistory({ municipalityId:'missing',sessionToken:session.token }),e=>e.code==='municipality_not_found');
  });

  it('revocation waits for a committed resolution then rejects both replay and private reads', async () => {
    const session = await predicted();
    let release, entered;
    const blocked = new Promise(resolve=>{release=resolve;});
    const checkpoint = new Promise(resolve=>{entered=resolve;});
    const delayed = makeService({ onWriteCheckpoint: async () => { entered(); await blocked; } });
    const input = { problemId,choice:'worsen',sessionToken:session.token };
    const resolving = delayed.resolvePrediction(input);
    await checkpoint;
    const revoking = store.revokeProposalSession(session.token);
    try {
      let observed = false;
      for (let attempt=0;attempt<200;attempt++) {
        const wait = await pool.query("SELECT count(*)::int count FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query LIKE '%UPDATE public.proposal_sessions%'");
        if (wait.rows[0].count>0) { observed=true;break; }
        await new Promise(resolve=>setTimeout(resolve,5));
      }
      assert.equal(observed,true,'Revocation must wait for the actual locked session row');
    } finally { release(); }
    assert.equal((await resolving).pointsDelta,10);
    await revoking;
    await assert.rejects(service.resolvePrediction(input),e=>e.code==='proposal_session_revoked');
    await assert.rejects(service.getPredictionResults({ turnId,sessionToken:session.token }),e=>e.code==='proposal_session_revoked');
  });
});
