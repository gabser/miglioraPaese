import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {Readable} from 'node:stream';
import {readFileSync} from 'node:fs';
import {createTestStore,integrationTest as it} from './helpers/fantasy.js';
import {createAccountService} from '../src/application/account-service.js';
import {createSimulatedEmailAdapter} from '../src/infrastructure/simulated-email.js';
import {createCooperationService} from '../src/application/cooperation-service.js';
import {createCooperationEvents} from '../src/application/cooperation-events.js';
import {createReviewService} from '../src/application/review-service.js';
import {createReviewRepository} from '../src/persistence/postgres/review-repository.js';
import {createMeasurementService} from '../src/application/measurement-service.js';
import {createMeasurementRepository} from '../src/persistence/postgres/measurement-repository.js';
import {createFantasyStore} from '../src/application/fantasy/store.js';
import {publishSyntheticCalendar} from '../src/application/calendar-publication.js';
import {createApp,startServer} from '../src/server.js';
import {unitOfWork} from '../src/persistence/postgres/unit-of-work.js';
const start=Date.parse('2026-12-01T00:00:00Z'),day=86400000,iso=v=>new Date(v).toISOString(),id=()=>randomUUID();
function calendar(suffix='one',municipalityId='tuglie'){
 const sid='coop-'+suffix,dayId=sid+'-day',placeId=sid+'-place';
 const cards=JSON.parse(readFileSync(new URL('../src/domain/fantasy/cards.demo.json',import.meta.url))).map(c=>({...c,id:sid+'-'+c.id,version:1,sourceStatus:'pending',sourceLabel:'Synthetic local unratified',isDemo:true}));
 return {idempotencyKey:'calendar-'+suffix,municipalityId,season:{id:sid,name:'Synthetic calendar '+suffix,startsAt:iso(start),endsAt:iso(start+10*day),catalogVersion:1,synthetic:true},cards,matchdays:[{id:dayId,number:1,startsAt:iso(start),locksAt:iso(start+day),observationEndsAt:iso(start+2*day),closeAt:iso(start+3*day)}],missions:[{id:sid+'-mission',matchdayId:dayId,cardId:cards[0].id,zoneId:'synthetic',title:'Synthetic weekly control',area:{label:'Synthetic public area',boundary:'Fixture boundary',public:true},placeId,durationMinutes:15,protocol:{id:sid+'-protocol',version:1,instructions:['Count visible synthetic items'],photoPoints:[],minPhotos:0,indicator:'Visible items',unit:'items',threshold:0,lowerIsBetter:true,measurementDefinition:{minValue:0,maxValue:100,integerOnly:true}},windows:[{id:sid+'-window',startsAt:iso(start+day),endsAt:iso(start+2*day),capacity:20}],baseline:{value:10,unit:'items',measuredAt:iso(start-day),label:'Synthetic baseline',provenance:'Local test fixture only'}}],coverageGoals:[{id:sid+'-goal',matchdayId:dayId,title:'Cover the declared public places',version:1,targets:[{placeId,startsAt:iso(start+day),endsAt:iso(start+2*day)}]}]};
}
async function fixture({onCheckpoint}={}){
 let time=start;const store=await createTestStore({now:()=>time}),pool=store.pool;
 await pool.query('TRUNCATE measurement_sources,measurement_problems,missions,accounts,account_email_codes,cooperation_calendar_receipts CASCADE');
 const mail=createSimulatedEmailAdapter(),accounts=createAccountService({pool,emailAdapter:mail,clock:()=>time}),login=async email=>{const ch=await accounts.requestCode({email});return accounts.verify({challengeId:ch.challengeId,code:mail.inspect().at(-1).code});};
 const a=await login('author@example.invalid'),b=await login('other@example.invalid'),op=await login('review@example.invalid');
 const input=calendar();await publishSyntheticCalendar({pool,input,clock:()=>time,loopbackSynthetic:true});
 const events=createCooperationEvents({clock:()=>time,onCheckpoint}),roles=createReviewRepository(pool,{clock:()=>time}),review=createReviewService({repository:roles,clock:()=>time,cooperationEvents:events});
 await roles.setRole(op.account.id,'tuglie','moderator',true);await roles.setRole(op.account.id,'tuglie','verifier',true);await roles.setRole(op.account.id,'tuglie','outcomesSupervisor',true);
 const api=createCooperationService({pool,fantasy:store.fantasy,clock:()=>time,onCheckpoint});
 const f={store,pool,input,a,b,op,api,events,review,roles,accounts,login,time:v=>time=v,now:()=>time,close:()=>store.close()};
 f.scope={seasonId:input.season.id,matchdayId:input.matchdays[0].id};
 f.league=async(account=a)=>store.fantasy.scoped(input.season.id,async()=>{await store.fantasy.teams.enroll('tuglie','account:'+account.account.id,{});return (await store.fantasy.leagues.create('tuglie','account:'+account.account.id,{name:'Amici',idempotencyKey:id()})).league;});
 f.observation=async(account=a,mission=input.missions[0],offset=0)=>{const booking=id(),observation=id();await pool.query(`INSERT INTO mission_bookings(id,mission_id,window_id,account_id,command_key,protocol_version,status,expires_at,revision,created_at) VALUES($1,$2,$3,$4,$5,1,'submitted',$6,1,$7)`,[booking,mission.id,mission.windows[0].id,account.account.id,id(),iso(time+day),iso(time+offset)]);await pool.query(`INSERT INTO mission_observations(id,booking_id,command_key,request_hash,receipt,answer,notes,proof_ids,submitted_at) VALUES($1,$2,$3,'hash','{"proofs":[]}','noIssue','PRIVATE NOTE: do not copy','{}',$4)`,[observation,booking,id(),iso(time+offset)]);await pool.query('INSERT INTO observation_reviews(observation_id,place_id) VALUES($1,$2)',[observation,mission.placeId]);return observation;};
 f.command=async(o,action,extra={})=>{const r=(await pool.query('SELECT revision FROM observation_reviews WHERE observation_id=$1',[o])).rows[0];return review.command(op.token,'tuglie',o,action,{idempotencyKey:id(),expectedRevision:r.revision,...extra});};
 f.approve=async o=>{await f.command(o,'assignment');await f.command(o,'screening',{decision:'forward',reason:'Synthetic screening'});await f.command(o,'assignment');return f.command(o,'decisions',{decision:'approve',reason:'PRIVATE reason do not copy'});};
 return f;
}
async function request(app,url,method='GET',data,token){const req=Readable.from(data===undefined?[]:[Buffer.from(JSON.stringify(data))]);Object.assign(req,{url,method,headers:token?{authorization:'Bearer '+token}:{}});const res={writeHead(s,h){this.status=s;this.headers=h;},end(v){this.body=JSON.parse(v);}};await app(req,res);return res;}
it('calendar canonical replay/restart, conflict, validation, rollback and explicit zero goal',async()=>{const f=await fixture();try{
 const {pool,input}=f;const replay=await publishSyntheticCalendar({pool,input:Object.fromEntries(Object.entries(input).reverse()),clock:()=>start+100,loopbackSynthetic:true});assert.equal(replay.seasonId,input.season.id);
 await assert.rejects(publishSyntheticCalendar({pool,input:{...input,municipalityId:'bologna'},loopbackSynthetic:true}),e=>e.code==='idempotency_conflict');
 await assert.rejects(publishSyntheticCalendar({pool,input:{...input,idempotencyKey:'new-calendar-key'},clock:()=>start,loopbackSynthetic:true}),e=>e.code==='calendar_conflict');
 const invalid=calendar('bad');invalid.cards[0].sourceStatus='verified';await assert.rejects(publishSyntheticCalendar({pool,input:invalid,clock:()=>start,loopbackSynthetic:true}),e=>e.code==='invalid_field');
 const failed=calendar('rollback','bologna');await assert.rejects(publishSyntheticCalendar({pool,input:failed,clock:()=>start,loopbackSynthetic:true,onCheckpoint:async()=>{throw Error('fault');}}),/fault/);assert.equal((await pool.query('SELECT count(*)::int n FROM fantasy_seasons WHERE id=$1',[failed.season.id])).rows[0].n,0);
 const empty=calendar('zero','bologna');empty.coverageGoals[0].targets=[];await publishSyntheticCalendar({pool,input:empty,clock:()=>start,loopbackSynthetic:true});assert.equal((await f.api.municipal('bologna',{seasonId:empty.season.id,matchdayId:empty.matchdays[0].id})).coverage.ratio,null);
 const absent=await f.api.municipal('tuglie',{seasonId:'fantasy-demo-tuglie-2026-autumn',matchdayId:'matchday-1'});assert.equal(absent.goal,null);assert.equal(absent.coverage.ratio,null);
 assert.equal((await f.store.fantasy.season('tuglie')).season.id,input.season.id);
 }finally{await f.close();}});
it('calendar identifiers preserve opaque colon/space scope; unsafe IDs and elapsed commit lock roll back',async()=>{const f=await fixture();try{
 const input=calendar('opaque','bologna');input.season.id='season: weekly à';input.missions[0].id='mission:weekly';input.matchdays[0].id='day: weekly';input.missions[0].matchdayId='day: weekly';input.coverageGoals[0].matchdayId='day: weekly';input.idempotencyKey='opaque-calendar';
 const receipt=await publishSyntheticCalendar({pool:f.pool,input,clock:()=>start,loopbackSynthetic:true});assert.equal(receipt.seasonId,input.season.id);assert.equal(receipt.missionIds[0],'mission:weekly');
 for(const unsafe of ['bad/id','bad\\id','bad?id','bad#id','bad%id','.', '..','bad\u0000id','bad\u0085id','x'.repeat(129)]){const bad=calendar('unsafe');bad.missions[0].id=unsafe;await assert.rejects(publishSyntheticCalendar({pool:f.pool,input:bad,clock:()=>start,loopbackSynthetic:true}),e=>e.code==='invalid_field');}
 const expired=calendar('expires','bologna');expired.season.startsAt=iso(start-1);let now=start;await assert.rejects(publishSyntheticCalendar({pool:f.pool,input:expired,clock:()=>now,loopbackSynthetic:true,onCheckpoint:async()=>{now=start+day;}}),e=>e.code==='calendar_locked');
 assert.equal((await f.pool.query('SELECT count(*)::int n FROM fantasy_seasons WHERE id=$1',[expired.season.id])).rows[0].n,0);assert.equal((await f.pool.query('SELECT count(*)::int n FROM cooperation_calendar_receipts WHERE command_key=$1',[expired.idempotencyKey])).rows[0].n,0);
 assert.deepEqual(await publishSyntheticCalendar({pool:f.pool,input,clock:()=>start+20*day,loopbackSynthetic:true}),receipt);
 }finally{await f.close();}});
it('validated coverage and league ledger dedup, spectators, two leagues, late join, exit and archive',async()=>{const f=await fixture();try{
 const league=await f.league(),league2=await f.league();f.time(start+day+100);const o=await f.observation();const late=await f.observation(f.b);
 const join=async(l,a,joined,role='spectator')=>{await f.pool.query('INSERT INTO fantasy_players(season_id,user_id,revision,squad_ids,created_at) VALUES($1,$2,1,\'[]\',$3) ON CONFLICT DO NOTHING',[f.input.season.id,'account:'+a.account.id,iso(start)]);await f.pool.query('INSERT INTO fantasy_members(league_id,season_id,user_id,member_id,pseudonym,role,joined_at) VALUES($1,$2,$3,$4,$5,$6,$7) ON CONFLICT DO NOTHING',[l.id,f.input.season.id,'account:'+a.account.id,id(),'Manager synthetic',role,iso(joined)]);};
 await join(league,f.b,start+day+101);assert.equal((await f.api.municipal('tuglie',f.scope)).coverage.validatedPlaceWindows,0);
 await f.approve(late);assert.equal((await f.api.league(f.a.token,'tuglie',league.id,f.scope)).coverage.validatedPlaceWindows,0);
 await f.approve(o);for(const l of [league,league2])assert.equal((await f.api.league(f.a.token,'tuglie',l.id,f.scope)).coverage.validatedPlaceWindows,1);
 const pub=await f.api.municipal('tuglie',f.scope);assert.equal(pub.coverage.validatedPlaceWindows,1);assert.equal(pub.coverage.ratio,1);assert(!JSON.stringify(pub).includes(f.a.account.id));
 await assert.rejects(f.api.league(f.b.token,'bologna',league.id,f.scope),e=>e.statusCode===404);await assert.rejects(f.api.league(f.b.token,'tuglie',league2.id,f.scope),e=>e.statusCode===404);
 await f.pool.query('DELETE FROM fantasy_members WHERE league_id=$1 AND user_id=$2',[league.id,'account:'+f.a.account.id]);assert.equal((await f.api.league(f.b.token,'tuglie',league.id,f.scope)).coverage.validatedPlaceWindows,1);
 // Spectator membership before submission qualifies, never imports prior submissions.
 const c=await f.login('spectator@example.invalid');await join(league2,c,start+day);const third=await f.observation(c);await f.approve(third);assert.equal((await f.api.league(c.token,'tuglie',league2.id,f.scope)).coverage.validatedPlaceWindows,1);
 await f.pool.query("UPDATE fantasy_leagues SET status='archived' WHERE id=$1",[league2.id]);assert.equal((await f.api.league(c.token,'tuglie',league2.id,f.scope)).coverage.validatedPlaceWindows,1);
 const before=(await f.pool.query('SELECT count(*)::int n FROM cooperation_league_coverage')).rows[0].n;assert.equal(before,2);
 }finally{await f.close();}});
it('inbox account isolation, private follow, pagination, read/new device/revocation, no notes or tokens',async()=>{const f=await fixture();try{
 const p=f.input.missions[0].placeId;await f.api.follow(f.b.token,'tuglie',p,true);assert.equal((await f.api.follows(f.a.token)).items.length,0);assert.equal((await f.api.follows(f.b.token)).items.length,1);await assert.rejects(f.api.follow(f.a.token,'bologna',p,true),e=>e.statusCode===404);
 f.time(start+day);const o=await f.observation();await f.approve(o);const decision=(await f.api.inbox(f.a.token)).items[0];assert.equal(decision.type,'observationApproved');assert.equal((await f.api.inbox(f.b.token)).items.length,0);
 const replica=await f.command(o,'replication-requests',{reason:'PRIVATE replication reason'});const b=(await f.api.inbox(f.b.token)).items;assert.equal(b.length,1);assert.deepEqual(b[0].target,{kind:'mission',missionId:f.input.missions[0].id});assert.equal((await f.pool.query('SELECT count(*)::int n FROM replication_requests')).rows[0].n,1);
 const page=await f.api.inbox(f.a.token,{limit:1});assert(page.nextCursor);assert.equal((await f.api.inbox(f.a.token,{limit:1,cursor:page.nextCursor})).items.length,1);await assert.rejects(f.api.inbox(f.a.token,{cursor:'bad'}),e=>e.code==='invalid_field');
 await assert.rejects(f.api.read(f.b.token,decision.id),e=>e.statusCode===404);const read=await f.api.read(f.a.token,decision.id);assert.deepEqual(await f.api.read(f.a.token,decision.id),read);
 const device=await f.login('author@example.invalid');assert.equal((await f.api.inbox(device.token)).items.find(i=>i.id===decision.id).readAt,read.readAt);
 await f.api.follow(f.b.token,'tuglie',p,false);await f.command(o,'replication-requests',{reason:'Another private reason'});assert.equal((await f.api.inbox(f.b.token)).items.length,1);
 const serial=JSON.stringify(await f.api.inbox(device.token));for(const forbidden of ['PRIVATE','reason',f.a.token,replica.reason??'SENTINEL_NO_TOKEN'])assert(!serial.includes(forbidden));
 await f.accounts.logout(device.token);await assert.rejects(f.api.inbox(device.token),e=>e.statusCode===401);
 }finally{await f.close();}});
it('outbox and coverage roll back with review; restart drain idempotent and HTTP rejects body identities',async()=>{let fault=false;const f=await fixture({onCheckpoint:async p=>{if(fault&&p==='cooperation_coverage_before_commit')throw Error('fault');}});try{
 const league=await f.league();f.time(start+day);const o=await f.observation();await f.command(o,'assignment');await f.command(o,'screening',{decision:'forward',reason:'Screen'});await f.command(o,'assignment');fault=true;
 await assert.rejects(f.command(o,'decisions',{decision:'approve',reason:'Private'}),/fault/);assert.equal((await f.pool.query('SELECT count(*)::int n FROM xp_ledger')).rows[0].n,0);assert.equal((await f.api.inbox(f.a.token)).items.length,0);assert.equal((await f.api.league(f.a.token,'tuglie',league.id,f.scope)).coverage.validatedPlaceWindows,0);fault=false;
 const r=(await f.pool.query('SELECT revision FROM observation_reviews WHERE observation_id=$1',[o])).rows[0].revision,body={idempotencyKey:id(),expectedRevision:r,decision:'approve',reason:'Private'};await Promise.all([f.review.command(f.op.token,'tuglie',o,'decisions',body),f.review.command(f.op.token,'tuglie',o,'decisions',body)]);assert.equal((await f.api.inbox(f.a.token)).items.length,1);
 const restarted=createCooperationService({pool:f.pool,fantasy:f.store.fantasy,clock:f.now});assert.equal((await restarted.inbox(f.a.token)).items.length,1);
 const app=createApp({store:f.store,cooperation:restarted});assert.equal((await request(app,'/v1/me/inbox')).status,401);assert.equal((await request(app,'/v1/me/inbox?userId='+f.a.account.id,'GET',undefined,f.a.token)).status,400);assert.equal((await request(app,'/v1/me/inbox?limit=51','GET',undefined,f.a.token)).status,400);
 assert.equal((await request(app,'/v1/me/followed-places/'+f.input.missions[0].placeId+'?municipalityId=tuglie','PUT',{accountId:f.b.account.id},f.a.token)).status,400);
 assert.equal((await request(createApp({store:f.store}),'/v1/me/inbox','GET',undefined,f.a.token)).status,404);
 }finally{await f.close();}});
it('deadline at store startup captures only new publications in same UoW and survives retry restart',async()=>{const f=await fixture();try{
 await f.api.follow(f.a.token,'tuglie',f.input.missions[0].placeId,true);f.time(start+4*day);
 const fantasy=await createFantasyStore({pool:f.pool,now:f.now,cooperationEvents:f.events});await fantasy.teams.reconcile();
 const api=createCooperationService({pool:f.pool,fantasy,clock:f.now}),items=(await api.inbox(f.a.token)).items;assert.equal(items.length,1);assert.equal(items[0].type,'outcomePublished');
 await createFantasyStore({pool:f.pool,now:f.now,cooperationEvents:f.events});assert.equal((await api.inbox(f.a.token)).items.length,1);
 const second=calendar('off','bologna');await publishSyntheticCalendar({pool:f.pool,input:second,loopbackSynthetic:true,clock:()=>start});await f.api.follow(f.b.token,'bologna',second.missions[0].placeId,true);await createFantasyStore({pool:f.pool,now:f.now});await createFantasyStore({pool:f.pool,now:f.now,cooperationEvents:f.events});assert.equal((await api.inbox(f.b.token)).items.length,0);
 }finally{await f.close();}});
it('cross-mission units, spectator new unit, archived new unit and rejected observations have distinct effects',async()=>{const f=await fixture();try{
 const league=await f.league();const m=f.input.missions[0],alias={...m,id:'equivalent-mission',windows:[{...m.windows[0],id:'equivalent-window'}]};
 await f.pool.query('INSERT INTO missions(id,municipality_id,zone_id,title,area,protocol,duration_minutes,synthetic) SELECT $2,municipality_id,zone_id,title,area,protocol,duration_minutes,synthetic FROM missions WHERE id=$1',[m.id,alias.id]);await f.pool.query('INSERT INTO mission_places(mission_id,place_id) VALUES($1,$2)',[alias.id,m.placeId]);await f.pool.query('INSERT INTO mission_windows(id,mission_id,starts_at,ends_at,capacity) VALUES($1,$2,$3,$4,20)',[alias.windows[0].id,alias.id,alias.windows[0].startsAt,alias.windows[0].endsAt]);
 f.time(start+day+100);const base=await f.observation(),duplicate=await f.observation(f.a,alias);await f.approve(base);await f.approve(duplicate);assert.equal((await f.api.municipal('tuglie',f.scope)).coverage.validatedPlaceWindows,1);assert.equal((await f.pool.query('SELECT sum(amount)::int n FROM xp_ledger')).rows[0].n,10);
 // Add independent published targets, then exercise events exclusively on those units.
 const makeUnit=async(n)=>{const w={id:'additional-window-'+n,startsAt:iso(start+day+n*1000),endsAt:iso(start+2*day)};await f.pool.query('INSERT INTO mission_windows(id,mission_id,starts_at,ends_at,capacity) VALUES($1,$2,$3,$4,20)',[w.id,m.id,w.startsAt,w.endsAt]);await f.pool.query('INSERT INTO cooperation_targets(goal_id,place_id,starts_at,ends_at) VALUES($1,$2,$3,$4)',[f.input.coverageGoals[0].id,m.placeId,w.startsAt,w.endsAt]);return {...m,windows:[w]};};
 const spectator=await f.login('spectator-new@example.invalid');await f.pool.query('INSERT INTO fantasy_players(season_id,user_id,revision,squad_ids,created_at) VALUES($1,$2,1,\'[]\',$3)',[f.input.season.id,'account:'+spectator.account.id,iso(start)]);await f.pool.query("INSERT INTO fantasy_members(league_id,season_id,user_id,member_id,pseudonym,role,joined_at) VALUES($1,$2,$3,$4,'Manager spectator','spectator',$5)",[league.id,f.input.season.id,'account:'+spectator.account.id,id(),iso(start+day)]);
 const unit2=await makeUnit(2),sp=await f.observation(spectator,unit2);await f.approve(sp);assert.equal((await f.api.league(spectator.token,'tuglie',league.id,f.scope)).coverage.validatedPlaceWindows,2);
 await f.pool.query("UPDATE fantasy_leagues SET status='archived' WHERE id=$1",[league.id]);const unit3=await makeUnit(3),arc=await f.observation(spectator,unit3);await f.approve(arc);assert.equal((await f.api.league(spectator.token,'tuglie',league.id,f.scope)).coverage.validatedPlaceWindows,2);assert.equal((await f.api.municipal('tuglie',f.scope)).coverage.validatedPlaceWindows,3);
 const unit4=await makeUnit(4),rejected=await f.observation(f.b,unit4);await f.command(rejected,'assignment');await f.command(rejected,'screening',{decision:'reject',reason:'Private rejection'});assert.equal((await f.api.municipal('tuglie',f.scope)).coverage.validatedPlaceWindows,3);
 }finally{await f.close();}});
it('outcome contributor/player/follower overlap dedups; correction and rollback are atomic with result revision',async()=>{const f=await fixture();try{
 await f.store.fantasy.scoped(f.input.season.id,async()=>{await f.store.fantasy.teams.enroll('tuglie','account:'+f.a.account.id,{});const t=await f.store.fantasy.teams.team('tuglie','account:'+f.a.account.id);await f.store.fantasy.teams.confirm('tuglie','account:'+f.a.account.id,{expectedRevision:t.revision,matchdayId:f.scope.matchdayId});});
 await f.api.follow(f.a.token,'tuglie',f.input.missions[0].placeId,true);await f.api.follow(f.b.token,'tuglie',f.input.missions[0].placeId,true);f.time(start+day);const o=await f.observation();await f.approve(o);
 let fault=false;const api=createMeasurementService({repository:createMeasurementRepository(f.pool,{clock:f.now}),fantasy:f.store.fantasy,clock:f.now,cooperationEvents:createCooperationEvents({clock:f.now,onCheckpoint:async()=>{if(fault)throw Error('event fault');}})}),protocol=(await f.pool.query('SELECT id FROM measurement_protocols WHERE season_id=$1',[f.input.season.id])).rows[0];
 f.time(start+2*day);const cmd=(action,e,extra)=>api.command(f.op.token,'tuglie',action,e,{idempotencyKey:id(),...extra}),evidence={afterValue:null,measuredAt:null,sourceIds:[],approvedObservationIds:[],interventionIds:[],rationale:'Synthetic insufficient evidence'},draft=await cmd('evaluations',null,{protocolId:protocol.id,protocolVersion:1,...evidence});
 fault=true;await assert.rejects(cmd('publications',draft.id,{expectedRevision:draft.revision,disposition:'undeterminable',observed:null,undeterminableReason:'insufficientEvidence',rationale:'Private operational reasoning'}),/event fault/);assert.equal((await f.pool.query('SELECT count(*)::int n FROM measurement_publications WHERE evaluation_id=$1',[draft.id])).rows[0].n,0);assert.equal((await f.api.inbox(f.b.token)).items.length,0);fault=false;
 const published=await cmd('publications',draft.id,{expectedRevision:draft.revision,disposition:'undeterminable',observed:null,undeterminableReason:'insufficientEvidence',rationale:'Public synthetic explanation'});assert.equal(published.placeId,f.input.missions[0].placeId);
 assert.equal((await f.api.inbox(f.a.token)).items.filter(i=>i.type==='outcomePublished').length,1);assert.equal((await f.api.inbox(f.b.token)).items.length,1);
 const corrected=await cmd('corrections',draft.id,{expectedRevision:published.revision,...evidence,disposition:'undeterminable',observed:null,undeterminableReason:'contradictoryEvidence',appealId:null});assert.equal(corrected.version,2);assert.equal((await f.api.inbox(f.b.token)).items.filter(i=>i.type==='outcomeCorrected').length,1);
 await f.api.follow(f.b.token,'tuglie',f.input.missions[0].placeId,false);await cmd('corrections',draft.id,{expectedRevision:corrected.revision,...evidence,disposition:'undeterminable',observed:null,undeterminableReason:'incomparableEvidence',appealId:null});assert.equal((await f.api.inbox(f.b.token)).items.length,2);assert.equal((await f.api.inbox(f.a.token)).items.length,4);
 }finally{await f.close();}});
