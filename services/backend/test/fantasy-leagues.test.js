import { createApp } from '../src/server.js';
import { createTestStore as createMemoryStore, createTestFantasy as createFantasyStore, client } from './helpers/fantasy.js';
import { scoreFantasyCard } from '../src/domain/fantasy/scoring.js';
import assert from 'node:assert/strict';
import { integrationTest as it } from './helpers/fantasy.js';
import { Readable } from 'node:stream';

const start=Date.parse('2026-10-08T00:00:00Z'), lock=Date.parse('2026-10-10T00:00:00Z'), end=Date.parse('2026-10-15T00:00:00Z');
const a='anon:league-a',b='anon:league-b',c='anon:league-c',d='anon:league-outsider';
async function enroll(store,ids=[a,b,c,d],municipality='tuglie') { for(const id of ids) (await store.fantasy.teams.enroll(municipality,id,{})); }
async function create(store,user=a,key='create-league-1',name='Amici') { return (await store.fantasy.leagues.create('tuglie',user,{name,idempotencyKey:key})).league; }
async function invite(store,id,user=a,hours=24) { return (await store.fantasy.leagues.invite('tuglie',user,id,{expiresInHours:hours})).invite; }
async function joinLeague(store,token,user) { return (await store.fantasy.leagues.join('tuglie',user,{token})); }
async function fullLeague(store) { (await enroll(store)); const league=(await create(store)), token=(await invite(store,league.id)).token; (await joinLeague(store,token,b)); (await joinLeague(store,token,c)); return {league,token}; }
async function confirm(store,user,prediction='stable') {
  let t=(await store.fantasy.teams.team('tuglie',user));
  t=(await store.fantasy.teams.update('tuglie',user,{expectedRevision:t.revision,matchdayId:t.matchdayId,starterIds:t.team.starterIds,captainId:t.team.captainId,predictions:Object.fromEntries(t.team.starterIds.map(id=>[id,prediction])),motivations:{}}));
  return (await store.fantasy.teams.confirm('tuglie',user,{expectedRevision:t.revision,matchdayId:t.matchdayId}));
}
async function publish(store) {
  for(const card of (await store.fantasy.cards('tuglie')).items.filter(c=>c.sourceStatus==='verified')) (await store.fantasy.results.publish('tuglie','matchday-1',card.id,{observed:'stable',sourceStatus:'verified',sourceLabel:card.sourceLabel,sourceDate:new Date(end).toISOString(),explanation:'Fixture',rulesVersion:'fantasy-demo-v1',version:1}));
}
it('private leagues are idempotent, thresholded and do not expose identities, teams or arbitrary text', async () => {
  const store=(await createMemoryStore({now:()=>start}));
  try {
    (await enroll(store)); const league=(await create(store));
    assert.deepEqual((await create(store)),league);
    await assert.rejects(async()=>(await create(store,a,'create-league-1','Quartiere')),e=>e.code==='idempotency_conflict');
    await assert.rejects(async()=>(await create(store,a,'create-league-x','Mario Rossi')),e=>e.code==='invalid_field');
    await assert.rejects(async()=>(await store.fantasy.leagues.read('tuglie',d,league.id)),e=>e.statusCode===404);
    await assert.rejects(async()=>(await invite(store,league.id,b)),e=>e.statusCode===404);
    const token=(await invite(store,league.id)).token; (await joinLeague(store,token,b));
    assert.equal((await store.fantasy.leagues.read('tuglie',a,league.id)).entries.length,0);
    (await joinLeague(store,token,c)); (await joinLeague(store,token,c));
    const view=(await store.fantasy.leagues.read('tuglie',a,league.id));
    assert.equal(view.league.memberCount,3); assert.equal(view.entries.length,3);
    assert.deepEqual(view.entries.map(e=>e.rank),[1,1,1]);
    assert.deepEqual(view.entries.map(e=>e.memberId),[...view.entries.map(e=>e.memberId)].sort());
    for(const row of view.entries) { assert.match(row.pseudonym,/^Manager [a-f0-9]{8}$/); assert.deepEqual(Object.keys(row),['memberId','pseudonym','points','rank','isCurrentUser']); }
    const serialized=JSON.stringify(view); for(const user of [a,b,c]) assert.ok(!serialized.includes(user));
    assert.equal(view.cooperativeScore,null);
    assert.deepEqual((await store.fantasy.leagues.read('tuglie',b,league.id)).entries.map(e=>[e.memberId,e.rank,e.points]),view.entries.map(e=>[e.memberId,e.rank,e.points]));
  } finally {(await store.close());}
});
it('invite rotation, expiry, revocation and season/municipality isolation are enforced', async () => {
  let time=start; const store=(await createMemoryStore({now:()=>time}));
  try {
    (await enroll(store)); const league=(await create(store)), first=(await invite(store,league.id)), second=(await invite(store,league.id));
    await assert.rejects(async()=>(await joinLeague(store,first.token,b)),e=>e.code==='invalid_invite');
    await assert.rejects(async()=>(await invite(store,league.id,b)),e=>e.statusCode===404);
    (await joinLeague(store,second.token,b));
    await assert.rejects(async()=>(await invite(store,league.id,b)),e=>e.statusCode===403);
    (await store.fantasy.leagues.revoke('tuglie',a,league.id,second.id)); (await store.fantasy.leagues.revoke('tuglie',a,league.id,second.id));
    await assert.rejects(async()=>(await joinLeague(store,second.token,c)),e=>e.code==='invalid_invite');
    const third=(await invite(store,league.id,a,1)); time=start+3600000;
    await assert.rejects(async()=>(await joinLeague(store,third.token,c)),e=>e.code==='invalid_invite');
    (await enroll(store,[c],'bologna'));
    await assert.rejects(async()=>(await store.fantasy.leagues.join('bologna',c,{token:third.token})),e=>e.code==='invalid_invite');
    await assert.rejects(async()=>(await store.fantasy.leagues.read('bologna',c,league.id)),e=>e.statusCode===404);
    time=Date.parse('2027-10-08T00:00:00Z');
    await assert.rejects(async()=>(await create(store,a,'next-season-key')),e=>e.code==='season_ended');
    await assert.rejects(async()=>(await joinLeague(store,third.token,c)),e=>e.code==='season_ended');
  } finally {(await store.close());}
});
it('late entrants are spectators and exit/rejoin cannot retroactively turn them into competitors', async () => {
  let time=start; const store=(await createMemoryStore({now:()=>time}));
  try {
    const {league}=(await fullLeague(store)), token=(await invite(store,league.id,a,168)).token;
    time=lock;
    assert.equal((await joinLeague(store,token,d)).league.role,'spectator');
    assert.equal((await store.fantasy.leagues.read('tuglie',d,league.id)).entries.length,3);
    assert.equal((await store.fantasy.leagues.read('tuglie',d,league.id)).entries.some(e=>e.isCurrentUser),false);
    (await store.fantasy.leagues.leave('tuglie',b,league.id)); (await store.fantasy.leagues.leave('tuglie',b,league.id));
    assert.equal((await joinLeague(store,token,b)).league.role,'spectator');
    assert.equal((await store.fantasy.leagues.read('tuglie',a,league.id)).entries.length,0);
    assert.equal((await store.fantasy.leagues.read('tuglie',a,league.id)).league.competitiveCount,2);
    time=start; (await store.fantasy.leagues.leave('tuglie',d,league.id));
    assert.equal((await joinLeague(store,token,d)).league.role,'spectator');
  } finally {(await store.close());}
});
it('ranking derives server points including penalties and reflection with stable shared ties', async () => {
  let time=start; const store=(await createMemoryStore({now:()=>time}));
  try {
    const {league}=(await fullLeague(store));
    for(const user of [a,b,c]) (await confirm(store,user));
    for(const [outgoingId,incomingId] of [['parco-nord','fontanelle-ovest'],['fontanelle-ovest','parco-nord'],['parco-nord','fontanelle-ovest'],['fontanelle-ovest','parco-nord']]) {
      const t=(await store.fantasy.teams.team('tuglie',c)),q=(await store.fantasy.market.quote('tuglie',c,{expectedRevision:t.revision,matchdayId:t.matchdayId,outgoingId,incomingId})).quote;
      (await store.fantasy.market.confirm('tuglie',c,{quoteId:q.id,expectedRevision:q.expectedRevision,idempotencyKey:`league-transfer-${t.revision}`}));
    }
    (await confirm(store,c)); time=end; (await publish(store));
    let view=(await store.fantasy.leagues.read('tuglie',a,league.id));
    assert.deepEqual(view.entries.map(e=>e.points),[28,28,20]); assert.deepEqual(view.entries.map(e=>e.rank),[1,1,3]);
    const t=(await store.fantasy.teams.team('tuglie',a));
    (await store.fantasy.results.reflect('tuglie',a,'matchday-1','buche-centro',{expectedRevision:t.revision,answer:'observedIntervention'}));
    view=(await store.fantasy.leagues.read('tuglie',a,league.id));
    assert.deepEqual(view.entries.map(e=>e.points),[29,28,20]); assert.deepEqual(view.entries.map(e=>e.rank),[1,2,3]);
    assert.equal(view.entries[0].isCurrentUser,true);
  } finally {(await store.close());}
});
it('session deletion archives an owned league, revokes invitations and preserves other teams', async () => {
  const store=(await createMemoryStore({now:()=>start}));
  try {
    const {league,token}=(await fullLeague(store)); (await confirm(store,b));
    (await store.deleteUserData(a));
    const view=(await store.fantasy.leagues.read('tuglie',b,league.id));
    assert.equal(view.league.status,'archived'); assert.equal(view.league.isOwner,false); assert.equal(view.league.memberCount,2); assert.equal(view.entries.length,0);
    assert.equal((await store.fantasy.teams.team('tuglie',b)).team.confirmed,true);
    await assert.rejects(async()=>(await joinLeague(store,token,d)),e=>e.code==='invalid_invite');
    await assert.rejects(async()=>(await store.fantasy.leagues.list('tuglie',a)),e=>e.statusCode===404);
    (await store.deleteUserData(c)); assert.equal((await store.fantasy.leagues.read('tuglie',b,league.id)).league.memberCount,1);
  } finally {(await store.close());}
});
it('owner exit archives the league and prevents future invitation rotation', async () => {
  const store=(await createMemoryStore({now:()=>start}));
  try { const {league}=(await fullLeague(store)); (await store.fantasy.leagues.leave('tuglie',a,league.id));
    assert.equal((await store.fantasy.leagues.read('tuglie',b,league.id)).league.status,'archived');
    await assert.rejects(async()=>(await invite(store,league.id)),e=>e.statusCode===404);
    await assert.rejects(async()=>(await create(store)),e=>e.code==='league_archived');
    assert.equal((await store.fantasy.counts()).leagues,1);
    (await store.deleteUserData(a));
    assert.equal((await store.fantasy.leagues.read('tuglie',b,league.id)).league.status,'archived');
  } finally {(await store.close());}
});

it('HTTP signed sessions authorize every league operation, enforce pilot scope',async()=> {
  const events=[],store=(await createMemoryStore({now:()=>start}));
  try {
    const app=createApp({fantasy:store.fantasy,store,pilotMunicipalityId:'tuglie'});
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
    const dto=JSON.stringify((await clients[1](`${base}/leagues/${id}`)).body); assert.ok(!dto.includes(token)); assert.ok(!dto.includes('session:'));
  } finally {(await store.close());}
});
