import {unitOfWork} from '../persistence/postgres/unit-of-work.js';
import {sessionHash} from '../domain/proposal-session.js';
import {fail,uuid,exact} from '../domain/missions/rules.js';
import {text} from '../domain/measurements/rules.js';
import {drainCooperationOutbox} from './cooperation-events.js';
const iso=v=>new Date(v).toISOString();
const titles={integrationRequested:'Integrazione richiesta',observationApproved:'Contributo validato',observationRejected:'Revisione conclusa',outcomePublished:'Esito pubblicato',outcomeCorrected:'Esito rettificato',recheckRequested:'Ricontrollo richiesto'};
export function createCooperationService({pool,fantasy,clock=Date.now,onCheckpoint=async()=>{}}){
 const uow=unitOfWork(pool),one=async(c,q,a=[])=>(await c.query(q,a)).rows[0];
 async function authenticated(token,action){return uow.run(async c=>{
  const r=await one(c,'SELECT account_id,revoked_at,expires_at FROM proposal_sessions WHERE token_hash=$1 FOR UPDATE',[sessionHash(token)]);
  if(!r?.account_id||r.revoked_at)fail('account_required','Verified active account required.',401);
  if(r.expires_at&&Date.parse(r.expires_at)<=clock())fail('session_expired','Session expired.',401);
  const result=await action(c,r.account_id);
  if(r.expires_at&&Date.parse(r.expires_at)<=clock())fail('session_expired','Session expired before commit.',401);
  return result;
 });}
 async function scope(m,query){if((query.seasonId==null)!==(query.matchdayId==null))fail('invalid_field','Select seasonId and matchdayId together.');const season=await fantasy.teams.seasonFor(m,query.seasonId??null),day=await fantasy.teams.dayFor(season.id,query.matchdayId??null,iso(clock()));return {municipalityId:m,seasonId:season.id,matchdayId:day.id};}
 async function progress(c,s,leagueId=null){
  const g=await one(c,'SELECT * FROM cooperation_goals WHERE municipality_id=$1 AND season_id=$2 AND matchday_id=$3',[s.municipalityId,s.seasonId,s.matchdayId]);
  const expected=g?Number((await one(c,'SELECT count(*) AS n FROM cooperation_targets WHERE goal_id=$1',[g.id])).n):0;
  const municipal=g?Number((await one(c,'SELECT count(*) AS n FROM cooperation_coverage WHERE goal_id=$1',[g.id])).n):0;
  const league=leagueId&&g?Number((await one(c,'SELECT count(*) AS n FROM cooperation_league_coverage WHERE goal_id=$1 AND league_id=$2',[g.id,leagueId])).n):0;
  const coverage=n=>({expectedPlaceWindows:expected,validatedPlaceWindows:n,ratio:expected?n/expected:null});
  return {goal:g?{id:g.id,title:g.title,version:g.version,publishedAt:iso(g.published_at),expectedPlaceWindows:expected}:null,coverage:coverage(leagueId?league:municipal),...(leagueId?{municipalCoverage:coverage(municipal)}:{})};
 }
 async function place(c,m,p){text(m,'municipalityId');text(p,'placeId');const r=await one(c,'SELECT m.area FROM mission_places p JOIN missions m ON m.id=p.mission_id WHERE p.place_id=$1 AND m.municipality_id=$2 AND m.area->>\'public\'=\'true\' LIMIT 1',[p,m]);if(!r)fail('place_not_found','Public place not found.',404);return r;}
 return {
  isReady:async()=>{try{await pool.query('SELECT id FROM cooperation_goals LIMIT 0');await pool.query('SELECT recipient_id,read_at FROM cooperation_inbox LIMIT 0');return true;}catch{return false;}},
  municipal:(m,q={})=>uow.run(async c=>{const s=await scope(m,q);return {...s,serverTime:iso(clock()),...await progress(c,s)};}),
  league:(token,m,id,q={})=>authenticated(token,async(c,a)=>{text(id,'leagueId');const l=await one(c,`SELECT l.* FROM fantasy_leagues l JOIN fantasy_seasons s ON s.id=l.season_id JOIN fantasy_members b ON b.league_id=l.id WHERE l.id=$1 AND s.municipality_id=$2 AND b.user_id='account:'||$3::text`,[id,m,a]);if(!l)fail('league_not_found','League not found.',404);const day=await fantasy.teams.dayFor(l.season_id,q.matchdayId??null,iso(clock())),s={municipalityId:m,seasonId:l.season_id,matchdayId:day.id};return {...s,leagueId:id,serverTime:iso(clock()),...await progress(c,s,id)};}),
  inbox:(token,q={})=>authenticated(token,async(c,a)=>{
   if(q.municipalityId!==undefined)text(q.municipalityId,'municipalityId');
   const limit=q.limit===undefined?20:Number(q.limit);if(!Number.isInteger(limit)||limit<1||limit>50||typeof q.limit==='string'&&!/^[0-9]{1,2}$/.test(q.limit))fail('invalid_field','limit must be 1–50.');
   let cursor=null;if(q.cursor!==undefined){if(typeof q.cursor!=='string'||q.cursor.length>512||!/^[A-Za-z0-9_-]+$/.test(q.cursor))fail('invalid_field','Invalid cursor.');try{cursor=JSON.parse(Buffer.from(q.cursor,'base64url').toString());exact(cursor,['at','id','municipalityId']);uuid(cursor.id);if(typeof cursor.at!=='string'||!Number.isFinite(Date.parse(cursor.at))||cursor.municipalityId!==(q.municipalityId??null))throw Error();}catch{fail('invalid_field','Invalid cursor.');}}
   await drainCooperationOutbox(c,{clock,onCheckpoint});
   const rows=(await c.query(`SELECT o.*,i.read_at FROM cooperation_outbox o JOIN cooperation_inbox i ON i.id=o.id AND i.recipient_id=o.recipient_id WHERE o.recipient_id=$1 AND ($2::text IS NULL OR o.municipality_id=$2) AND ($3::timestamptz IS NULL OR (o.created_at,o.id)<($3::timestamptz,$4::uuid)) ORDER BY o.created_at DESC,o.id DESC LIMIT $5`,[a,q.municipalityId??null,cursor?.at??null,cursor?.id??null,limit+1])).rows;
   const selected=rows.slice(0,limit),last=selected.at(-1),n=await one(c,`SELECT count(*) AS n FROM cooperation_inbox i JOIN cooperation_outbox o ON o.id=i.id WHERE i.recipient_id=$1 AND i.read_at IS NULL AND ($2::text IS NULL OR o.municipality_id=$2)`,[a,q.municipalityId??null]);
   return {serverTime:iso(clock()),items:selected.map(r=>({id:r.id,type:r.type,title:titles[r.type],createdAt:iso(r.created_at),readAt:r.read_at?iso(r.read_at):null,municipalityId:r.municipality_id,target:r.target})),nextCursor:rows.length>limit?Buffer.from(JSON.stringify({at:iso(last.created_at),id:last.id,municipalityId:q.municipalityId??null})).toString('base64url'):null,unreadCount:Number(n.n)};
  }),
  read:(token,id)=>authenticated(token,async(c,a)=>{uuid(id);await drainCooperationOutbox(c,{clock,onCheckpoint});const r=await one(c,'UPDATE cooperation_inbox SET read_at=COALESCE(read_at,$3) WHERE id=$1 AND recipient_id=$2 RETURNING read_at',[id,a,iso(clock())]);if(!r)fail('not_found','Message not found.',404);return {messageId:id,readAt:iso(r.read_at)};}),
  follows:(token,m)=>authenticated(token,async(c,a)=>{if(m!==undefined)text(m,'municipalityId');const rows=(await c.query('SELECT place_id,municipality_id FROM cooperation_follows WHERE account_id=$1 AND ($2::text IS NULL OR municipality_id=$2) ORDER BY municipality_id,place_id',[a,m??null])).rows;return {items:rows.map(r=>({placeId:r.place_id,municipalityId:r.municipality_id}))};}),
  follow:(token,m,p,following)=>authenticated(token,async(c,a)=>{await place(c,m,p);if(following)await c.query('INSERT INTO cooperation_follows(account_id,municipality_id,place_id) VALUES($1,$2,$3) ON CONFLICT DO NOTHING',[a,m,p]);else await c.query('DELETE FROM cooperation_follows WHERE account_id=$1 AND municipality_id=$2 AND place_id=$3',[a,m,p]);return {placeId:p,municipalityId:m,following};}),
 };
}
