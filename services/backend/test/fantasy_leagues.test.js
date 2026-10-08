import assert from 'node:assert/strict';
import { it } from 'node:test';
import { Readable } from 'node:stream';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createApp, createMemoryStore, createPersistentStore } from '../src/server.js';

const start=Date.parse('2026-10-08T00:00:00Z'), lock=Date.parse('2026-10-10T00:00:00Z'), end=Date.parse('2026-10-15T00:00:00Z');
const a='anon:league-a',b='anon:league-b',c='anon:league-c',d='anon:league-outsider';
function enroll(store,ids=[a,b,c,d],municipality='tuglie') { for(const id of ids) store.fantasy.teams.enroll(municipality,id,{}); }
function create(store,user=a,key='create-league-1',name='Amici') { return store.fantasy.leagues.create('tuglie',user,{name,idempotencyKey:key}).league; }
function invite(store,id,user=a,hours=24) { return store.fantasy.leagues.invite('tuglie',user,id,{expiresInHours:hours}).invite; }
function joinLeague(store,token,user) { return store.fantasy.leagues.join('tuglie',user,{token}); }
function fullLeague(store) { enroll(store); const league=create(store), token=invite(store,league.id).token; joinLeague(store,token,b); joinLeague(store,token,c); return {league,token}; }
function confirm(store,user,prediction='stable') {
  let t=store.fantasy.teams.team('tuglie',user);
  t=store.fantasy.teams.update('tuglie',user,{expectedRevision:t.revision,matchdayId:t.matchdayId,starterIds:t.team.starterIds,captainId:t.team.captainId,predictions:Object.fromEntries(t.team.starterIds.map(id=>[id,prediction])),motivations:{}});
  return store.fantasy.teams.confirm('tuglie',user,{expectedRevision:t.revision,matchdayId:t.matchdayId});
}
function publish(store) {
  for(const card of store.fantasy.cards('tuglie').items.filter(c=>c.sourceStatus==='verified')) store.fantasy.results.publish('tuglie','matchday-1',card.id,{observed:'stable',sourceStatus:'verified',sourceLabel:card.sourceLabel,sourceDate:new Date(end).toISOString(),explanation:'Fixture',rulesVersion:'fantasy-demo-v1',version:1});
}
function client(app) {
  let cookie;
  return async(path,method='GET',body) => {
    const req=Readable.from(body===undefined?[]:[Buffer.from(JSON.stringify(body))]);
    Object.assign(req,{url:path,method,headers:cookie?{cookie}:{}});
    const res={writeHead(status,headers){this.status=status;this.headers=headers;},end(payload){this.body=JSON.parse(payload);}};
    await app(req,res); if(res.headers['set-cookie']) cookie=res.headers['set-cookie'].split(';')[0]; return res;
  };
}
it('private leagues are idempotent, thresholded and do not expose identities, teams or arbitrary text',()=> {
  const store=createMemoryStore({now:()=>start});
  try {
    enroll(store); const league=create(store);
    assert.deepEqual(create(store),league);
    assert.throws(()=>create(store,a,'create-league-1','Quartiere'),e=>e.code==='idempotency_conflict');
    assert.throws(()=>create(store,a,'create-league-x','Mario Rossi'),e=>e.code==='invalid_field');
    assert.throws(()=>store.fantasy.leagues.read('tuglie',d,league.id),e=>e.statusCode===404);
    assert.throws(()=>invite(store,league.id,b),e=>e.statusCode===404);
    const token=invite(store,league.id).token; joinLeague(store,token,b);
    assert.equal(store.fantasy.leagues.read('tuglie',a,league.id).entries.length,0);
    joinLeague(store,token,c); joinLeague(store,token,c);
    const view=store.fantasy.leagues.read('tuglie',a,league.id);
    assert.equal(view.league.memberCount,3); assert.equal(view.entries.length,3);
    assert.deepEqual(view.entries.map(e=>e.rank),[1,1,1]);
    assert.deepEqual(view.entries.map(e=>e.memberId),[...view.entries.map(e=>e.memberId)].sort());
    for(const row of view.entries) { assert.match(row.pseudonym,/^Manager [a-f0-9]{8}$/); assert.deepEqual(Object.keys(row),['memberId','pseudonym','points','rank','isCurrentUser']); }
    const serialized=JSON.stringify(view); for(const user of [a,b,c]) assert.ok(!serialized.includes(user));
    assert.equal(view.cooperativeScore,null);
    assert.deepEqual(store.fantasy.leagues.read('tuglie',b,league.id).entries.map(e=>[e.memberId,e.rank,e.points]),view.entries.map(e=>[e.memberId,e.rank,e.points]));
  } finally {store.close();}
});
it('invite rotation, expiry, revocation and season/municipality isolation are enforced',()=> {
  let time=start; const store=createMemoryStore({now:()=>time});
  try {
    enroll(store); const league=create(store), first=invite(store,league.id), second=invite(store,league.id);
    assert.throws(()=>joinLeague(store,first.token,b),e=>e.code==='invalid_invite');
    assert.throws(()=>invite(store,league.id,b),e=>e.statusCode===404);
    joinLeague(store,second.token,b);
    assert.throws(()=>invite(store,league.id,b),e=>e.statusCode===403);
    store.fantasy.leagues.revoke('tuglie',a,league.id,second.id); store.fantasy.leagues.revoke('tuglie',a,league.id,second.id);
    assert.throws(()=>joinLeague(store,second.token,c),e=>e.code==='invalid_invite');
    const third=invite(store,league.id,a,1); time=start+3600000;
    assert.throws(()=>joinLeague(store,third.token,c),e=>e.code==='invalid_invite');
    enroll(store,[c],'bologna');
    assert.throws(()=>store.fantasy.leagues.join('bologna',c,{token:third.token}),e=>e.code==='invalid_invite');
    assert.throws(()=>store.fantasy.leagues.read('bologna',c,league.id),e=>e.statusCode===404);
    time=Date.parse('2027-10-08T00:00:00Z');
    assert.throws(()=>create(store,a,'next-season-key'),e=>e.code==='season_ended');
    assert.throws(()=>joinLeague(store,third.token,c),e=>e.code==='season_ended');
  } finally {store.close();}
});
it('late entrants are spectators and exit/rejoin cannot retroactively turn them into competitors',()=> {
  let time=start; const store=createMemoryStore({now:()=>time});
  try {
    const {league}=fullLeague(store), token=invite(store,league.id,a,168).token;
    time=lock;
    assert.equal(joinLeague(store,token,d).league.role,'spectator');
    assert.equal(store.fantasy.leagues.read('tuglie',d,league.id).entries.length,3);
    assert.equal(store.fantasy.leagues.read('tuglie',d,league.id).entries.some(e=>e.isCurrentUser),false);
    store.fantasy.leagues.leave('tuglie',b,league.id); store.fantasy.leagues.leave('tuglie',b,league.id);
    assert.equal(joinLeague(store,token,b).league.role,'spectator');
    assert.equal(store.fantasy.leagues.read('tuglie',a,league.id).entries.length,0);
    assert.equal(store.fantasy.leagues.read('tuglie',a,league.id).league.competitiveCount,2);
    time=start; store.fantasy.leagues.leave('tuglie',d,league.id);
    assert.equal(joinLeague(store,token,d).league.role,'spectator');
  } finally {store.close();}
});
it('ranking derives server points including penalties and reflection with stable shared ties',()=> {
  let time=start; const store=createMemoryStore({now:()=>time});
  try {
    const {league}=fullLeague(store);
    for(const user of [a,b,c]) confirm(store,user);
    for(const [outgoingId,incomingId] of [['parco-nord','fontanelle-ovest'],['fontanelle-ovest','parco-nord'],['parco-nord','fontanelle-ovest'],['fontanelle-ovest','parco-nord']]) {
      const t=store.fantasy.teams.team('tuglie',c),q=store.fantasy.market.quote('tuglie',c,{expectedRevision:t.revision,matchdayId:t.matchdayId,outgoingId,incomingId}).quote;
      store.fantasy.market.confirm('tuglie',c,{quoteId:q.id,expectedRevision:q.expectedRevision,idempotencyKey:`league-transfer-${t.revision}`});
    }
    confirm(store,c); time=end; publish(store);
    let view=store.fantasy.leagues.read('tuglie',a,league.id);
    assert.deepEqual(view.entries.map(e=>e.points),[28,28,20]); assert.deepEqual(view.entries.map(e=>e.rank),[1,1,3]);
    const t=store.fantasy.teams.team('tuglie',a);
    store.fantasy.results.reflect('tuglie',a,'matchday-1','buche-centro',{expectedRevision:t.revision,answer:'observedIntervention'});
    view=store.fantasy.leagues.read('tuglie',a,league.id);
    assert.deepEqual(view.entries.map(e=>e.points),[29,28,20]); assert.deepEqual(view.entries.map(e=>e.rank),[1,2,3]);
    assert.equal(view.entries[0].isCurrentUser,true);
  } finally {store.close();}
});
it('session deletion archives an owned league, revokes invitations and preserves other teams',()=> {
  const store=createMemoryStore({now:()=>start});
  try {
    const {league,token}=fullLeague(store); confirm(store,b);
    store.deleteUserData(a);
    const view=store.fantasy.leagues.read('tuglie',b,league.id);
    assert.equal(view.league.status,'archived'); assert.equal(view.league.isOwner,false); assert.equal(view.league.memberCount,2); assert.equal(view.entries.length,0);
    assert.equal(store.fantasy.teams.team('tuglie',b).team.confirmed,true);
    assert.throws(()=>joinLeague(store,token,d),e=>e.code==='invalid_invite');
    assert.throws(()=>store.fantasy.leagues.list('tuglie',a),e=>e.statusCode===404);
    store.deleteUserData(c); assert.equal(store.fantasy.leagues.read('tuglie',b,league.id).league.memberCount,1);
  } finally {store.close();}
});
it('owner exit archives the league and prevents future invitation rotation',()=> {
  const store=createMemoryStore({now:()=>start});
  try { const {league}=fullLeague(store); store.fantasy.leagues.leave('tuglie',a,league.id);
    assert.equal(store.fantasy.leagues.read('tuglie',b,league.id).league.status,'archived');
    assert.throws(()=>invite(store,league.id),e=>e.statusCode===404);
  } finally {store.close();}
});
it('hash-only invites and rate limit survive restart; failed deletion rolls all league state back',async()=> {
  const dir=await mkdtemp(join(tmpdir(),'fantasy-leagues-')); const databasePath=join(dir,'state.sqlite');
  let store,db;
  try {
    store=createPersistentStore({databasePath,now:()=>start}); const {league,token}=fullLeague(store);
    for(let i=0;i<5;i++) assert.throws(()=>joinLeague(store,'x'.repeat(43),d),e=>e.code==='invalid_invite');
    db=new DatabaseSync(databasePath,{enableForeignKeyConstraints:true});
    assert.equal(db.prepare('SELECT token_hash FROM fantasy_invites WHERE league_id = ?').get(league.id).token_hash.length,64);
    assert.ok(!JSON.stringify(db.prepare('SELECT * FROM fantasy_invites').all()).includes(token));
    db.exec("CREATE TRIGGER fail_league_delete BEFORE DELETE ON fantasy_players BEGIN SELECT RAISE(ABORT, 'failure'); END;");
    assert.throws(()=>store.deleteUserData(a),/failure/);
    assert.equal(store.fantasy.leagues.read('tuglie',b,league.id).league.status,'active');
    db.exec('DROP TRIGGER fail_league_delete;'); db.close(); db=null; store.close();
    store=createPersistentStore({databasePath,now:()=>start});
    assert.throws(()=>joinLeague(store,token,d),e=>e.statusCode===429);
    assert.equal(store.fantasy.leagues.read('tuglie',a,league.id).entries.length,3);
    store.deleteUserData(a); db=new DatabaseSync(databasePath);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM fantasy_leagues WHERE owner_id = ?').get(a).n,0);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM fantasy_members WHERE user_id = ?').get(a).n,0);
  } finally {db?.close(); store?.close(); await rm(dir,{recursive:true,force:true});}
});
it('HTTP signed sessions authorize every league operation, keep logs private and enforce pilot scope',async()=> {
  const events=[],store=createMemoryStore({now:()=>start});
  try {
    const {createObservability}=await import('../src/observability.js');
    const app=createApp({store,pilotMunicipalityId:'tuglie',observability:createObservability({logger:event=>events.push(event)})});
    const clients=[client(app),client(app),client(app),client(app)],base='/v1/fantasy/municipalities/tuglie';
    for(const request of clients) assert.equal((await request(`${base}/enrollment`,'POST',{})).status,200);
    const created=await clients[0](`${base}/leagues`,'POST',{name:'Quartiere',idempotencyKey:'http-create-key'}),id=created.body.league.id;
    const invitation=await clients[0](`${base}/leagues/${id}/invites`,'POST',{expiresInHours:24}),token=invitation.body.invite.token;
    for(const request of clients.slice(1,3)) assert.equal((await request(`${base}/leagues/join`,'POST',{token})).status,200);
    assert.equal((await clients[3](`${base}/leagues/${id}`)).status,404);
    assert.equal((await clients[1](`${base}/leagues/${id}/invites`,'POST',{expiresInHours:24})).status,403);
    assert.equal((await clients[0](`${base}/leagues/${id}`)).body.entries.length,3);
    assert.equal((await clients[0](`/v1/fantasy/municipalities/bologna/leagues/${id}`)).status,404);
    assert.equal((await clients[0](`${base}/leagues`,'POST',{name:'Amici',idempotencyKey:'spoofing-key',userId:'spoof'})).status,400);
    assert.equal((await clients[0](`${base}/leagues/${id}/invites/${invitation.body.invite.id}`,'DELETE')).status,200);
    assert.equal((await clients[3](`${base}/leagues/join`,'POST',{token})).status,404);
    assert.equal((await clients[0]('/v1/session','DELETE')).status,200);
    assert.equal((await clients[1](`${base}/leagues/${id}`)).body.league.status,'archived');
    const log=JSON.stringify(events); assert.ok(!log.includes(token)); assert.ok(!log.includes(id)); assert.ok(!log.includes('Manager '));
  } finally {store.close();}
});
