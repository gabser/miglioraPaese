import assert from 'node:assert/strict';
import { Readable } from 'node:stream';
import { describe, it } from 'node:test';
import { createApp, createMemoryStore } from '../src/server.js';
import { createSuggestedProblem } from '../src/domain/catalog.js';
import { publicSuggestion } from '../src/domain/public-suggestion.js';

const route = '/v1/municipalities/bologna/next-problems';
const input = { title: 'Alberi in piazza', description: 'Potatura necessaria',
  category: 'green', userId: 'private-author-id',
  location: { kind: 'specific', label: 'Piazza delle Rose', civic: '12/A' } };
const publicKeys = ['id', 'title', 'shortDescription', 'location', 'category',
  'status', 'votesUp', 'votesDown', 'score', 'myVote', 'submittedByDisplayName',
  'createdAt', 'promotionRule'].sort();

function assertPublic(problem) {
  assert.deepEqual(Object.keys(problem).sort(), publicKeys);
  assert.deepEqual(Object.keys(problem.promotionRule).sort(), ['reason','scopeLabel','threshold']);
  assert.equal(JSON.stringify(problem).includes('private-author-id'), false);
}

describe('public proposal detail contract', () => {
  it('keeps ID/place/date and current status while creation replay remains an acceptance snapshot', async () => {
    const app = createApp({ store: createMemoryStore() });
    const created = await request(app, route, { method: 'POST', body: input, key: 'public-create-key' });
    assert.equal(created.status, 201);
    assertPublic(created.body);
    assert.deepEqual(created.body.location, input.location);
    const detailPath = `${route}/${created.body.id}`;
    const detail = await request(app, detailPath);
    assert.equal(detail.status, 200);
    assert.deepEqual(detail.body, created.body);
    const alias = await request(app, `/v1/municipalities/comune%3ABologna/next-problems/${created.body.id}`);
    assert.deepEqual(alias, detail);
    const list = await request(app, route);
    for (const item of list.body.items) assertPublic(item);
    const voted = await request(app, `${detailPath}/votes`, {
      method: 'POST', body: {vote:'up',userId:'private-author-id'}, key:'public-vote-key',
    });
    assert.equal(voted.status, 200);
    assertPublic(voted.body);
    assert.equal(voted.body.status, 'approved');
    const current = await request(app, `${detailPath}?userId=private-author-id`);
    assert.deepEqual(current.body, voted.body);
    assert.equal(current.body.createdAt, created.body.createdAt);
    assert.equal(current.body.myVote, 'up');
    const replay = await request(app, route, { method:'POST',body:input,key:'public-create-key' });
    assert.deepEqual(replay, created);
    assert.equal(replay.body.status, 'pending');
  });

  it('returns identical 404s for unknown ID, wrong municipality and missing municipality', async () => {
    const app = createApp({ store:createMemoryStore() });
    const created = await request(app, route, {method:'POST',body:input,key:'notfound-create-key'});
    const paths = [`${route}/unknown-id`,
      `/v1/municipalities/castel-bolognese/next-problems/${created.body.id}`,
      `/v1/municipalities/unknown/next-problems/${created.body.id}`];
    const responses = await Promise.all(paths.map(path=>request(app,path)));
    for (const response of responses) {
      assert.equal(response.status,404);
      assert.deepEqual(response.body,{error:'suggested_problem_not_found',message:'Suggested problem not found.'});
    }
  });

  it('does not grant private rejected access through a client-controlled userId', async () => {
    const rejected = createSuggestedProblem({id:'rejected-1',title:'Riservata',
      shortDescription:'Descrizione privata',category:'green',status:'rejected',
      votesUp:0,votesDown:0,submittedByUserId:'private-author-id'});
    const visible = {...rejected,id:'visible-1',status:'pending'};
    let voteCalls = 0;
    const app = createApp({store:{
      listNextProblems() {return [visible,rejected];},
      getNextProblem() {return rejected;},
      voteNextProblem() {voteCalls++;return rejected;},
    }});
    const list = await request(app, `${route}?userId=private-author-id`);
    assert.deepEqual(list.body.items.map(p=>p.id),['visible-1']);
    assertPublic(list.body.items[0]);
    const detail = await request(app, `${route}/rejected-1?userId=private-author-id`);
    assert.equal(detail.status,404);
    assert.equal(JSON.stringify(detail.body).includes('Riservata'),false);
    const vote = await request(app, `${route}/rejected-1/votes`, {
      method:'POST',body:{vote:'up',userId:'private-author-id'},key:'rejected-vote-key',
    });
    assert.equal(vote.status,404);
    assert.equal(voteCalls,0);
  });

  it('projects nested DTOs and removes future secrets without mutating stored values', () => {
    const record = createSuggestedProblem({id:'internal-1',title:'Alberi',
      shortDescription:'Descrizione',category:'green',status:'pending',votesUp:0,
      votesDown:0,submittedByUserId:'private-author-id',location:input.location});
    record.sessionToken = 'secret-token';
    record.promotionRule.internalOwner = 'private-author-id';
    const dto = publicSuggestion(record);
    assertPublic(dto);
    assert.equal(JSON.stringify(dto).includes('secret-token'),false);
    dto.location.label = 'Modificato';
    dto.promotionRule.reason = 'Modificato';
    assert.equal(record.location.label,'Piazza delle Rose');
    assert.notEqual(record.promotionRule.reason,'Modificato');
    assert.equal(record.submittedByUserId,'private-author-id');
  });

  it('returns JSON validation errors for malformed encoding and an invalid personalization parameter', async () => {
    const app=createApp({store:createMemoryStore()});
    for (const path of [`${route}/%E0%A4`,`${route}/an-id?userId=${'x'.repeat(129)}`]) {
      const response=await request(app,path);
      assert.equal(response.status,400);
      assert.equal(response.body.error,'invalid_field');
    }
  });
});

async function request(app,path,{method='GET',body,key}={}) {
  const req=Readable.from(body===undefined?[]:[Buffer.from(JSON.stringify(body))]);
  Object.assign(req,{method,url:path,headers:key?{'idempotency-key':key}:{}});
  let status,payload;
  await app(req,{writeHead(value){status=value;},end(value){payload=JSON.parse(value);}});
  return {status,body:payload};
}
