import {createMeasurementRepository} from '../../persistence/postgres/measurement-repository.js';
import {createMeasurementService} from '../measurement-service.js';
import { readFileSync } from 'node:fs';
import { createFantasyRepository } from '../../persistence/postgres/fantasy-repository.js';
import { createFantasyTeams, fantasyError } from './teams.js';
import { createFantasyMarket, transferPenalty, transferData } from './market.js';
import { createFantasyResults } from './results.js';
import { createFantasyLeagues } from './leagues.js';

const fixtureCards = JSON.parse(readFileSync(new URL('../../domain/fantasy/cards.demo.json', import.meta.url), 'utf8'));
const dayMs = 86400000;
export const fantasyRulesVersion = 'fantasy-demo-v1';
export const demoSeasonStartsAt = '2026-10-08T00:00:00.000Z';
const tables = ['seasons','cards','matchdays','players','drafts','snapshots','quotes','transfers','transfer_commands','outcomes','reveals','reflections','finalizations','leagues','members','invites','invite_attempts'];

export async function createFantasyStore({pool, now=Date.now, seedDemo=false, seedStartsAt=demoSeasonStartsAt,onTransactionCheckpoint,cooperationEvents} = {}) {
  const database = createFantasyRepository(pool,{onTransactionCheckpoint,clock:now});
  const start = typeof seedStartsAt === 'string' && /(?:Z|[+-]\d{2}:\d{2})$/.test(seedStartsAt) ? Date.parse(seedStartsAt) : NaN;
  if (!Number.isFinite(start)) throw new TypeError('seedStartsAt requires an ISO date with timezone.');
  const iso = (value) => new Date(value).toISOString();
  const time = () => iso(now());
  if (seedDemo) await database.transaction(async () => {
    for (const municipalityId of ['bologna','castel-bolognese','tuglie']) {
      const id = `fantasy-demo-${municipalityId}-2026-autumn`;
      if (await database.one("select_seasons_by_id_2", id)) continue;
      await database.execute("insert_seasons", id,municipalityId,'Stagione civica · Autunno demo',iso(start),iso(start+56*dayMs));
      for (const card of fixtureCards) await database.execute("insert_cards", id,card.id,card.role,card.price,card.availability,card.sourceStatus,JSON.stringify({...card,sourceUpdatedAt:card.sourceStatus==='unavailable'?null:iso(start),isDemo:true}));
      for (let number=1;number<=8;number++) {
        const begins=start+(number-1)*7*dayMs;
        await database.execute("insert_matchdays",id,`matchday-${number}`,number,iso(begins),iso(begins+2*dayMs),iso(begins+7*dayMs),fantasyRulesVersion);
      }
    }
  });
  const missing = () => {throw fantasyError(404,'not_found','Fantasy resource not found.');};
  const seasonRow = async (municipalityId) => api.teams.seasonFor(municipalityId);
  const currentDay = async (season,at) => await database.one("select_matchdays_by_season_id_2",season.id,at)
    ?? await database.one("select_matchdays_by_season_id_3",season.id) ?? missing();
  const envelope = (season,serverTime) => ({serverTime,isDemo:Boolean(season.is_demo)});
  let measurementReadiness=async()=>true;
  const api = {
    database,
    scoped:(seasonId,action)=>database.scoped(seasonId,action),
    async season(municipalityId) {
      const row=await seasonRow(municipalityId),serverTime=time(),day=await currentDay(row,serverTime);
      return {...envelope(row,serverTime),seasonId:row.id,season:{id:row.id,municipalityId:row.municipality_id,name:row.name,startsAt:row.starts_at,endsAt:row.ends_at,totalMatchdays:Number((await database.raw('SELECT count(*) AS n FROM fantasy_matchdays WHERE season_id=$1',[row.id])).rows[0].n),currentMatchday:day.number,catalogVersion:row.catalog_version,status:Date.parse(serverTime)<Date.parse(row.starts_at)?'upcoming':Date.parse(serverTime)>=Date.parse(row.ends_at)?'ended':'active'}};
    },
    async cards(municipalityId) {
      const season=await seasonRow(municipalityId);
      const items=(await database.many("select_cards_by_season_id",season.id)).map(row=>({...JSON.parse(row.payload),id:row.id,version:row.version,role:row.role,price:row.price,availability:row.availability,sourceStatus:row.source_status,isDemo:Boolean(season.is_demo)}));
      return {...envelope(season,time()),seasonId:season.id,catalogVersion:season.catalog_version,items};
    },
    async matchday(municipalityId,matchdayId) {
      const season=await seasonRow(municipalityId),serverTime=time();
      const row=matchdayId==null?await currentDay(season,serverTime):await database.one("select_matchdays_by_season_id_id",season.id,matchdayId)??missing();
      return {...envelope(season,serverTime),seasonId:season.id,matchday:{id:row.id,number:row.number,seasonId:row.season_id,startsAt:row.starts_at,locksAt:row.locks_at,observationEndsAt:row.observation_ends_at,rulesVersion:row.rules_version}};
    },
    async isReady() {
      try {
        if(!await measurementReadiness())return false;
        for (const name of tables) await database.one('probe_'+name);
        await database.raw('SELECT revision,creator_id FROM fantasy_leagues LIMIT 0');
        await database.raw('SELECT id,from_user_id,to_user_id,target_member_id,status FROM fantasy_ownership_offers LIMIT 0');
        await database.raw('SELECT user_id,command_key,response FROM fantasy_ownership_commands LIMIT 0');
        await database.raw('SELECT league_id,action,revision FROM fantasy_ownership_audit LIMIT 0');
        await database.raw('SELECT bucket,window_start,attempts FROM fantasy_invite_preview_attempts LIMIT 0');
        const constraints=await database.many('schema_foreign_keys');
        const continuityKeys=(await database.raw("SELECT count(*)::integer AS n,bool_and(convalidated AND condeferrable AND condeferred) AS valid FROM pg_constraint WHERE contype='f' AND conrelid IN ('fantasy_ownership_offers'::regclass,'fantasy_ownership_commands'::regclass,'fantasy_ownership_audit'::regclass)")).rows[0];
        if(continuityKeys.n!==6||continuityKeys.valid!==true)return false;
        const byTable=new Map(constraints.map(row=>[row.table_name,row]));
        const expected={"fantasy_seasons": 0, "fantasy_cards": 1, "fantasy_matchdays": 1, "fantasy_players": 1, "fantasy_drafts": 2, "fantasy_snapshots": 2, "fantasy_quotes": 2, "fantasy_transfer_commands": 1, "fantasy_transfers": 2, "fantasy_outcomes": 2, "fantasy_reveals": 2, "fantasy_finalizations": 2, "fantasy_reflections": 1, "fantasy_leagues": 1, "fantasy_members": 2, "fantasy_invites": 1, "fantasy_invite_attempts": 1};
        return Object.entries(expected).every(([name,count])=>count===0 ||
          byTable.get(name)?.count===count && byTable.get(name)?.valid===true);
      } catch(error) {
        if(['42P01','42703'].includes(error.code))return false;
        throw error;
      }
    },
    async counts() {const counts={};for(const name of tables)counts[name]=Number((await database.one('count_'+name)).count);return counts;},
    close() {}, // Pool lifecycle belongs to the composition root.
    atomic: action=>database.transaction(action),
    authenticated: (token,action,principal)=>database.authenticated(token,action,principal),
  };
  api.teams=createFantasyTeams({database,now,catalog:api.cards,getTransferPenalty:(p,d)=>transferPenalty(database,p,d),getTransferData:(p,d)=>transferData(database,p,d)});
  api.market=createFantasyMarket({database,teams:api.teams,now});
  api.results=createFantasyResults({database,teams:api.teams,catalog:api.cards,now});
  api.leagues=createFantasyLeagues({database,teams:api.teams,results:api.results,now});
  for(const method of ['season','cards','matchday']){const original=api[method];api[method]=(...args)=>database.transaction(()=>original(...args));}
  api.eraseUserData=userId=>database.transaction(async()=>{await api.leagues.erase(userId);await api.teams.erase(userId);return {status:'erased'};});
  // Persisted v2 rules and deadlines remain authoritative even when the
  // optional measurement HTTP console is disabled. No source/season is seeded.
  const measurementRepository=createMeasurementRepository(pool,{clock:now});
  measurementReadiness=()=>measurementRepository.ready();
  createMeasurementService({repository:measurementRepository,fantasy:api,clock:now,cooperationEvents});
  if(!await api.isReady())throw new Error('Fantasy schema is not ready. Apply the verified migrations.');
  await api.teams.reconcile(); // Recovery after process downtime at a lock deadline.
  return api;
}
