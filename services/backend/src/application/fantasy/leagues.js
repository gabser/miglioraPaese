import { createLeagueContinuity } from './continuity.js';
import { randomBytes, randomUUID, createHash } from 'node:crypto';
import { exactFields, fantasyError } from './teams.js';
import { transaction } from '../../persistence/postgres/fantasy-repository.js';

export function createFantasyLeagues({database: db, teams, results, now=Date.now}) {
  const iso = () => new Date(now()).toISOString();
  function fail(code,message,status=409) { throw fantasyError(status,code,message); }
  async function context(municipalityId,userId,leagueId=null) {
    if(leagueId){const row=(await db.raw('SELECT * FROM fantasy_leagues WHERE id=$1',[leagueId])).rows[0];if(!row)fail('not_found','League not found.',404);if(db.seasonHint()&&db.seasonHint()!==row.season_id)fail('season_scope_conflict','League belongs to a different season.',409);const season=await teams.seasonFor(municipalityId,row.season_id);await teams.playerFor(season.id,userId);return {season,userId};}
    const season=(await teams.seasonFor(municipalityId));
    (await teams.playerFor(season.id,userId));
    return {season,userId};
  }
  async function leagueFor(c,id) {
    return (await db.one("select_leagues_by_id_season_id", id,c.season.id))
      ?? fail('not_found','League not found.',404);
  }
  async function memberFor(c,league) {
    return (await db.one("select_members_by_league_id_user_id", league.id,c.userId))
      ?? fail('not_found','League not found.',404);
  }
  async function owner(c,league) {
    (await memberFor(c,league));
    if(league.owner_id !== c.userId || league.status !== 'active') fail('forbidden','Active league owner required.',403);
  }
  function activeSeason(c) { if(Date.parse(iso()) >= Date.parse(c.season.ends_at)) fail('season_ended','Season has ended.'); }
  async function addMember(c,league) {
    if(await db.one("select_members_by_league_id_user_id",league.id,c.userId))return;
    const memberId=randomUUID();
    const frozen = (await db.one("select_snapshots_by_season_id", c.season.id));
    (await db.execute("insert_members", league.id,c.season.id,c.userId,memberId,`Manager ${memberId.replaceAll('-','').slice(0,8)}`,
        Date.parse(iso()) < Date.parse(league.first_locks_at) && !frozen ? 'competitor' : 'spectator',iso()));
    await continuity.bump(league.id);
    league.revision++;
  }
  async function metadata(c,league) {
    const membership=(await memberFor(c,league));
    const members=(await db.many("select_members_by_league_id", league.id));
    return {id:league.id,seasonId:league.season_id,municipalityId:c.season.municipality_id,name:league.name,
      revision:league.revision,status:league.status,firstLocksAt:league.first_locks_at,role:membership.role,isOwner:league.owner_id===c.userId,
      memberCount:members.length,competitiveCount:members.filter(m=>m.role==='competitor').length,minimumParticipants:3};
  }
  function envelope(c) { return {serverTime:iso(),isDemo:Boolean(c.season.is_demo),seasonId:c.season.id}; }
  async function archive(id, eraseOwner = true) {
    if (eraseOwner) (await db.execute("update_leagues_by_id", id));
    else (await db.execute("update_leagues_by_id_2", id));
    (await db.execute("update_invites_by_league_id", id));
    const revision=await continuity.bump(id);
    await continuity.cancel(id);
    await continuity.audit(id,null,null,'archived',revision);
  }
  async function rateLimit(c) {
    // Committed separately: failed guesses must consume their attempt as well.
    (await transaction(db,async () => {
      const previous=(await db.one("select_invite_attempts_by_season_id_user_id", c.season.id,c.userId));
      const reset=!previous || now()-previous.window_start>=60000;
      if(!reset && previous.attempts>=5) fail('invite_rate_limited','Wait before trying another invite.',429);
      (await db.execute("insert_invite_attempts", c.season.id,c.userId,reset?now():previous.window_start,reset?1:previous.attempts+1));
    }));
  }
  const continuity=createLeagueContinuity({db,teams,now,context,leagueFor,memberFor,owner});
  return {
    preview:continuity.preview,ownership:continuity.ownership,ownershipCommand:continuity.ownershipCommand,
    async create(municipalityId,userId,body) {
      exactFields(body,['name','idempotencyKey']);
      if(!['Amici','Quartiere','Comune'].includes(body.name) || typeof body.idempotencyKey!=='string' || !/^[A-Za-z0-9_-]{8,128}$/.test(body.idempotencyKey)) fail('invalid_field','Choose a league template and an idempotency key.',400);
      const c=(await context(municipalityId,userId)); activeSeason(c);
      return (await transaction(db,async () => {
        let league=(await db.one("select_leagues_by_season_id_owner_id_creation_key", c.season.id,userId,body.idempotencyKey));
        if (league?.status === 'archived') fail('league_archived', 'This creation command belongs to an archived league.');
        if(league && league.name!==body.name) fail('idempotency_conflict','Key already used for another league.');
        if(!league) {
          const count=(await db.one("select_leagues_by_season_id_owner_id", c.season.id,userId)).n;
          if(count>=3) fail('league_limit','At most three owned leagues per season.');
          const first=(await db.one("select_matchdays_by_season_id_4", c.season.id));
          const id=randomUUID();
          (await db.execute("insert_leagues", id,c.season.id,userId,userId,body.idempotencyKey,body.name,first.locks_at,iso()));
          league=(await leagueFor(c,id)); (await addMember(c,league));
        }
        return {...envelope(c),league:(await metadata(c,league))};
      }));
    },
    async list(municipalityId,userId) {
      return transaction(db, async () => {
      const c=(await context(municipalityId,userId));
      const leagues=(await db.many("select_leagues_by_user_id_season_id", userId,c.season.id));
      return {...envelope(c),items:await Promise.all(leagues.map(l=>metadata(c,l)))};
      });
    },
    async read(municipalityId,userId,id) {
      await teams.reconcile();
      return transaction(db, async () => {
      const c=(await context(municipalityId,userId,id)), league=(await leagueFor(c,id)), meta=(await metadata(c,league));
      (await teams.reconcile());
      let entries=[];
      if(meta.competitiveCount>=3) {
        const members=(await db.many("select_members_by_league_id_2", id));
        for (const m of members) {
          const days = await db.many("select_snapshots_by_season_id_user_id_2", c.season.id, m.user_id);
          let points = 0;
          for (const d of days) points += (await db.scoped(c.season.id,()=>results.read(municipalityId, m.user_id, d.matchday_id))).summary.total;
          entries.push({memberId:m.member_id,pseudonym:m.pseudonym,points,rank:0,isCurrentUser:m.user_id===userId});
        }
        entries.sort((a,b)=>b.points-a.points || a.memberId.localeCompare(b.memberId));
        for(let i=0;i<entries.length;i++) entries[i].rank=i>0 && entries[i].points===entries[i-1].points ? entries[i-1].rank : i+1;
      }
      return {...envelope(c),league:meta,entries,cooperativeScore:null};
      });
    },
    async invite(municipalityId,userId,id,body) {
      exactFields(body,['expiresInHours']);
      if(!Number.isInteger(body.expiresInHours) || body.expiresInHours<1 || body.expiresInHours>168) fail('invalid_field','Invite expiry must be 1..168 hours.',400);
      const c=(await context(municipalityId,userId,id)); activeSeason(c);
      return (await transaction(db,async () => {
        const league=(await leagueFor(c,id)); activeSeason(c); (await owner(c,league));
        const token=randomBytes(32).toString('base64url'), inviteId=randomUUID();
        const expiresAt=new Date(Math.min(now()+body.expiresInHours*3600000,Date.parse(c.season.ends_at))).toISOString();
        // Rotation makes retry safe without persisting a recoverable raw token.
        (await db.execute("update_invites_by_league_id", id));
        (await db.execute("insert_invites", inviteId,id,createHash('sha256').update(token).digest('hex'),expiresAt));
        await continuity.bump(id);
        return {...envelope(c),invite:{id:inviteId,token,expiresAt}};
      }));
    },
    async revoke(municipalityId,userId,id,inviteId) {
      const c=(await context(municipalityId,userId,id));
      return (await transaction(db,async () => {
        (await owner(c,(await leagueFor(c,id))));
        const changed=await db.raw("UPDATE fantasy_invites SET revoked=1 WHERE id=$1 AND league_id=$2 AND revoked=0 RETURNING id",[inviteId,id]);
        if(changed.rowCount)await continuity.bump(id);
        return {...envelope(c),status:'revoked'};
      }));
    },
    async join(municipalityId,userId,body) {
      exactFields(body,['token','expectedLeagueRevision','expectedRole']);
      const guided=body.expectedLeagueRevision!==undefined||body.expectedRole!==undefined;
      if(guided&&(!Number.isSafeInteger(body.expectedLeagueRevision)||body.expectedLeagueRevision<1||!['competitor','spectator'].includes(body.expectedRole)))fail('invalid_field','Both guided confirmation fields are required.',400);
      if(typeof body.token!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(body.token)){
        const c=await context(municipalityId,userId);activeSeason(c);await rateLimit(c);
        fail('invalid_invite','Invite not available.',404);
      }
      // Resolve the authoritative league season, including after a new season is
      // published. The provided municipality/hint remains a strict scope check.
      const resolve=async(countInvalid=false)=>{
        const row=(await db.raw('SELECT l.* FROM fantasy_invites i JOIN fantasy_leagues l ON l.id=i.league_id JOIN fantasy_seasons s ON s.id=l.season_id WHERE i.token_hash=$1 AND s.municipality_id=$2',[createHash('sha256').update(body.token).digest('hex'),municipalityId])).rows[0];
        if(!row){const c=await context(municipalityId,userId);activeSeason(c);if(countInvalid)await rateLimit(c);fail('invalid_invite','Invite not available.',404);}
        return context(municipalityId,userId,row.id);
      };
      const initial=await resolve(true);activeSeason(initial);await rateLimit(initial);
      return transaction(db,async()=>{
        const c=await resolve();activeSeason(c);
        const invite=await db.one('select_invites_by_token_hash_season_id',createHash('sha256').update(body.token).digest('hex'),iso(),c.season.id);
        if(!invite)fail('invalid_invite','Invite not available.',404);
        const league=await leagueFor(c,invite.league_id);
        const existing=await db.one('select_members_by_league_id_user_id',league.id,userId);
        // A lost successful response is recoverable even though its own join
        // changed the revision; revoked credentials still fail above.
        if(!existing){
          const role=await continuity.role(league);
          if(guided&&(league.revision!==body.expectedLeagueRevision||role.expectedRole!==body.expectedRole))fail('league_revision_conflict','League or role has changed. Refresh the invite summary.');
          await addMember(c,league);
        }
        return {...envelope(c),league:await metadata(c,league)};
      });
    },
    async leave(municipalityId,userId,id) {
      const c=(await context(municipalityId,userId,id));
      return (await transaction(db,async () => {
        const league=(await leagueFor(c,id));
        if(league.owner_id===userId) (await archive(id, false));
        const changed=await db.raw("DELETE FROM fantasy_members WHERE league_id=$1 AND user_id=$2 RETURNING member_id",[id,userId]);
        if(changed.rowCount){await continuity.cancel(id,{userId});await continuity.bump(id);}
        return {...envelope(c),status:'left'};
      }));
    },
    async erase(userId) {
      for(const league of (await db.many("select_leagues_by_owner_id", userId))) (await archive(league.id));
      for(const membership of (await db.raw("SELECT league_id FROM fantasy_members WHERE user_id=$1",[userId])).rows){await continuity.cancel(membership.league_id,{userId});await continuity.bump(membership.league_id);}
      (await db.execute("delete_members_by_user_id", userId));
      (await db.execute("delete_invite_attempts_by_user_id", userId));
    },
  };
}
