import assert from 'node:assert/strict';
import { it } from 'node:test';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { once } from 'node:events';
import http from 'node:http';
import { createMemoryStore, startServer, createApp } from '../src/server.js';
import { runFantasyRehearsal } from '../scripts/rehearse_fantasy.js';
import { evaluatePilotSignals } from '../src/pilot_signals.js';
const exec=promisify(execFile);

it('rehearses the complete fantasy backup/restore and privacy journey on disposable SQLite only',async()=> {
  const result=await runFantasyRehearsal();
  assert.deepEqual(result.ranking,[29,28,20]);
  for(const field of ['backupRestore','privacyRollback','ownerDeletion','nonMutatingSmoke','privateLogs']) assert.equal(result[field],true);
  assert.equal(result.operationalGoLive,'not_authorized'); assert.equal(result.sessions,3);
  assert.equal(result.localAlertSignals.length,5);
});
it('smoke profiles use only GET, preserve every fantasy table and respect an API prefix',async()=> {
  const store=createMemoryStore({now:()=>Date.parse('2026-10-15T00:00:00Z')});
  const app=createApp({store,pilotMunicipalityId:'tuglie'}),methods=[];
  const server=http.createServer((req,res)=> { methods.push(req.method); req.url=req.url.replace(/^\/api/,''); app(req,res); });
  server.listen(0,'127.0.0.1'); await once(server,'listening');
  try {
    const before=store.fantasy.counts(),url=`http://127.0.0.1:${server.address().port}/api`;
    for(const profile of ['legacy-api','fantasy-api']) {
      const {stdout}=await exec(process.execPath,['scripts/smoke.js'],{cwd:new URL('..',import.meta.url),env:{...process.env,STAGING_BASE_URL:url,PILOT_MUNICIPALITY_ID:'tuglie',STAGING_PROFILE:profile}});
      const result=JSON.parse(stdout.trim()); assert.equal(result.profile,profile); assert.equal(result.checks,profile==='fantasy-api'?6:8);
      assert.deepEqual(store.fantasy.counts(),before);
    }
    assert.ok(methods.length>0 && methods.every(method=>method==='GET'));
  } finally {await new Promise(resolve=>server.close(resolve)); store.close();}
});
it('fantasy smoke fails safely on missing or incoherent data and degraded readiness',async()=> {
  const store=createMemoryStore({now:()=>Date.parse('2026-10-08T00:00:00Z')});
  const server=startServer({port:0,store,pilotMunicipalityId:'tuglie'}); await once(server,'listening');
  const options={cwd:new URL('..',import.meta.url),env:{...process.env,STAGING_BASE_URL:`http://127.0.0.1:${server.address().port}`,PILOT_MUNICIPALITY_ID:'tuglie',STAGING_PROFILE:'fantasy-api'}};
  try {
    const original=store.fantasy.cards;
    store.fantasy.cards=(municipality)=>({...original(municipality),seasonId:'wrong-season'});
    await assert.rejects(exec(process.execPath,['scripts/smoke.js'],options),/Incoherent fantasy/);
    store.fantasy.cards=original; store.isReady=()=>false;
    await assert.rejects(exec(process.execPath,['scripts/smoke.js'],options),/ready returned HTTP 503/);
    await assert.rejects(exec(process.execPath,['scripts/smoke.js'],{...options,env:{...options.env,STAGING_PROFILE:'unknown'}}),/STAGING_PROFILE/);
  } finally {await new Promise(resolve=>server.close(resolve));store.close();}
});
it('candidate manifests require an explicit profile and safe HTTPS URL; no deployment is authorized',async()=> {
  const command=['scripts/validate_candidate_config.js'],cwd=new URL('..',import.meta.url);
  for(const profile of ['legacy-api','fantasy-api']) {
    const env={...process.env,STAGING_PROFILE:profile,PILOT_MUNICIPALITY_ID:'tuglie',API_BASE_URL:'https://fixture.invalid/api',GITHUB_SHA:'synthetic-revision'};
    const {stdout}=await exec(process.execPath,command,{cwd,env}),result=JSON.parse(stdout.trim());
    assert.equal(result.profile,profile); assert.equal(result.fantasyDataSource,profile==='fantasy-api'?'api':'mock');
    assert.equal(result.deploymentAuthorized,false); assert.equal(result.revision,'synthetic-revision');
    for(const url of ['http://fixture.invalid','https://user:synthetic-secret@fixture.invalid','https://fixture.invalid/?token=synthetic-secret']) {
      await assert.rejects(exec(process.execPath,command,{cwd,env:{...env,API_BASE_URL:url}}),error=>error.code===1 && !error.stderr.includes('synthetic-secret'));
    }
  }
});
it('local alert evaluator detects fault, stale backup, low disk and scraping loss without pretending provider alerts are installed',()=> {
  const now=Date.parse('2026-10-09T00:00:00Z');
  const good={ready:true,consecutiveReadinessFailures:0,fiveXxIncrease:0,diskAvailableRatio:0.5,backupVerifiedAt:now-3600000,now,scrapeHealthy:true};
  assert.deepEqual(evaluatePilotSignals(good),[]);
  assert.deepEqual(evaluatePilotSignals({...good,ready:false,consecutiveReadinessFailures:1}),[]);
  assert.deepEqual(evaluatePilotSignals({...good,ready:false,consecutiveReadinessFailures:2}),['readiness_unavailable']);
  assert.deepEqual(evaluatePilotSignals({...good,fiveXxIncrease:1}),['http_5xx_increase']);
  assert.deepEqual(evaluatePilotSignals({...good,diskAvailableRatio:0.199}),['disk_space_low_or_unknown']);
  assert.deepEqual(evaluatePilotSignals({...good,backupVerifiedAt:now-86400000}),['backup_stale_or_unknown']);
  assert.deepEqual(evaluatePilotSignals({...good,backupVerifiedAt:now+1}),['backup_stale_or_unknown']);
  assert.deepEqual(evaluatePilotSignals({...good,scrapeHealthy:false}),['metrics_scrape_unavailable']);
});
