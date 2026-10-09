import { randomBytes, randomUUID, createHash } from 'node:crypto';
import { exactFields, fantasyError } from './teams.js';
import { transaction } from './transaction.js';

export function migrateFantasyLeagues(db) {
  db.exec(`
    CREATE TABLE fantasy_leagues (
      id TEXT PRIMARY KEY,
      season_id TEXT NOT NULL REFERENCES fantasy_seasons(id),
      owner_id TEXT,
      creation_key TEXT NOT NULL,
      name TEXT NOT NULL CHECK (name IN ('Amici', 'Quartiere', 'Comune')),
      status TEXT NOT NULL CHECK (status IN ('active','archived')),
      first_locks_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE (id, season_id),
      UNIQUE (season_id, owner_id, creation_key)
    ) STRICT;
    CREATE TABLE fantasy_members (
      league_id TEXT NOT NULL,
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      member_id TEXT NOT NULL UNIQUE,
      pseudonym TEXT NOT NULL,
      role TEXT NOT NULL CHECK (role IN ('competitor','spectator')),
      joined_at TEXT NOT NULL,
      PRIMARY KEY (league_id,user_id),
      FOREIGN KEY (league_id,season_id) REFERENCES fantasy_leagues(id,season_id),
      FOREIGN KEY (season_id,user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE
    ) STRICT;
    CREATE TABLE fantasy_invites (
      id TEXT PRIMARY KEY,
      league_id TEXT NOT NULL REFERENCES fantasy_leagues(id),
      token_hash TEXT NOT NULL UNIQUE,
      expires_at TEXT NOT NULL,
      revoked INTEGER NOT NULL CHECK (revoked IN (0,1))
    ) STRICT;
    CREATE TABLE fantasy_invite_attempts (
      season_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      window_start INTEGER NOT NULL,
      attempts INTEGER NOT NULL,
      PRIMARY KEY (season_id,user_id),
      FOREIGN KEY (season_id,user_id) REFERENCES fantasy_players(season_id,user_id) ON DELETE CASCADE
    ) STRICT;
  `);
}
export function leaguesSchemaReady(db) {
  db.prepare('SELECT id, season_id, owner_id, creation_key, name, status, first_locks_at, created_at FROM fantasy_leagues LIMIT 1').get();
  db.prepare('SELECT league_id, season_id, user_id, member_id, pseudonym, role, joined_at FROM fantasy_members LIMIT 1').get();
  db.prepare('SELECT id, league_id, token_hash, expires_at, revoked FROM fantasy_invites LIMIT 1').get();
  db.prepare('SELECT season_id, user_id, window_start, attempts FROM fantasy_invite_attempts LIMIT 1').get();
}
export function createFantasyLeagues({database: db, teams, results, now=Date.now}) {
  const iso = () => new Date(now()).toISOString();
  function fail(code,message,status=409) { throw fantasyError(status,code,message); }
  function context(municipalityId,userId) {
    const season=teams.seasonFor(municipalityId);
    teams.playerFor(season.id,userId);
    return {season,userId};
  }
  function leagueFor(c,id) {
    return db.prepare('SELECT * FROM fantasy_leagues WHERE id = ? AND season_id = ?').get(id,c.season.id)
      ?? fail('not_found','League not found.',404);
  }
  function memberFor(c,league) {
    return db.prepare('SELECT * FROM fantasy_members WHERE league_id = ? AND user_id = ?').get(league.id,c.userId)
      ?? fail('not_found','League not found.',404);
  }
  function owner(c,league) {
    memberFor(c,league);
    if(league.owner_id !== c.userId || league.status !== 'active') fail('forbidden','Active league owner required.',403);
  }
  function activeSeason(c) { if(iso() >= c.season.ends_at) fail('season_ended','Season has ended.'); }
  function addMember(c,league) {
    const memberId=randomUUID();
    const frozen = db.prepare('SELECT 1 FROM fantasy_snapshots s JOIN fantasy_matchdays d ON d.season_id=s.season_id AND d.id=s.matchday_id WHERE s.season_id = ? AND d.number = 1 LIMIT 1').get(c.season.id);
    db.prepare('INSERT INTO fantasy_members VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(league_id,user_id) DO NOTHING')
      .run(league.id,c.season.id,c.userId,memberId,`Manager ${memberId.replaceAll('-','').slice(0,8)}`,
        iso() < league.first_locks_at && !frozen ? 'competitor' : 'spectator',iso());
  }
  function metadata(c,league) {
    const membership=memberFor(c,league);
    const members=db.prepare('SELECT role FROM fantasy_members WHERE league_id = ?').all(league.id);
    return {id:league.id,seasonId:league.season_id,municipalityId:c.season.municipality_id,name:league.name,
      status:league.status,firstLocksAt:league.first_locks_at,role:membership.role,isOwner:league.owner_id===c.userId,
      memberCount:members.length,competitiveCount:members.filter(m=>m.role==='competitor').length,minimumParticipants:3};
  }
  function envelope(c) { return {serverTime:iso(),isDemo:Boolean(c.season.is_demo),seasonId:c.season.id}; }
  function archive(id, eraseOwner = true) {
    if (eraseOwner) db.prepare("UPDATE fantasy_leagues SET status = 'archived', owner_id = NULL, creation_key = '' WHERE id = ?").run(id);
    else db.prepare("UPDATE fantasy_leagues SET status = 'archived' WHERE id = ?").run(id);
    db.prepare('UPDATE fantasy_invites SET revoked = 1 WHERE league_id = ?').run(id);
  }
  function rateLimit(c) {
    // Committed separately: failed guesses must consume their attempt as well.
    transaction(db,()=> {
      const previous=db.prepare('SELECT * FROM fantasy_invite_attempts WHERE season_id = ? AND user_id = ?').get(c.season.id,c.userId);
      const reset=!previous || now()-previous.window_start>=60000;
      if(!reset && previous.attempts>=5) fail('invite_rate_limited','Wait before trying another invite.',429);
      db.prepare('INSERT INTO fantasy_invite_attempts VALUES (?, ?, ?, ?) ON CONFLICT(season_id,user_id) DO UPDATE SET window_start=excluded.window_start, attempts=excluded.attempts')
        .run(c.season.id,c.userId,reset?now():previous.window_start,reset?1:previous.attempts+1);
    });
  }
  return {
    create(municipalityId,userId,body) {
      exactFields(body,['name','idempotencyKey']);
      if(!['Amici','Quartiere','Comune'].includes(body.name) || typeof body.idempotencyKey!=='string' || !/^[A-Za-z0-9_-]{8,128}$/.test(body.idempotencyKey)) fail('invalid_field','Choose a league template and an idempotency key.',400);
      const c=context(municipalityId,userId); activeSeason(c);
      return transaction(db,()=> {
        let league=db.prepare('SELECT * FROM fantasy_leagues WHERE season_id = ? AND owner_id = ? AND creation_key = ?').get(c.season.id,userId,body.idempotencyKey);
        if (league?.status === 'archived') fail('league_archived', 'This creation command belongs to an archived league.');
        if(league && league.name!==body.name) fail('idempotency_conflict','Key already used for another league.');
        if(!league) {
          const count=db.prepare("SELECT COUNT(*) AS n FROM fantasy_leagues WHERE season_id = ? AND owner_id = ? AND status = 'active'").get(c.season.id,userId).n;
          if(count>=3) fail('league_limit','At most three owned leagues per season.');
          const first=db.prepare('SELECT locks_at FROM fantasy_matchdays WHERE season_id = ? ORDER BY number LIMIT 1').get(c.season.id);
          const id=randomUUID();
          db.prepare("INSERT INTO fantasy_leagues VALUES (?, ?, ?, ?, ?, 'active', ?, ?)").run(id,c.season.id,userId,body.idempotencyKey,body.name,first.locks_at,iso());
          league=leagueFor(c,id); addMember(c,league);
        }
        return {...envelope(c),league:metadata(c,league)};
      });
    },
    list(municipalityId,userId) {
      const c=context(municipalityId,userId);
      const leagues=db.prepare('SELECT l.* FROM fantasy_leagues l JOIN fantasy_members m ON m.league_id=l.id WHERE m.user_id = ? AND l.season_id = ? ORDER BY l.created_at,l.id').all(userId,c.season.id);
      return {...envelope(c),items:leagues.map(l=>metadata(c,l))};
    },
    read(municipalityId,userId,id) {
      const c=context(municipalityId,userId), league=leagueFor(c,id), meta=metadata(c,league);
      teams.reconcile();
      let entries=[];
      if(meta.competitiveCount>=3) {
        const members=db.prepare("SELECT * FROM fantasy_members WHERE league_id = ? AND role = 'competitor' ORDER BY member_id").all(id);
        entries=members.map(m=> {
          const days=db.prepare('SELECT matchday_id FROM fantasy_snapshots WHERE season_id = ? AND user_id = ? ORDER BY matchday_id').all(c.season.id,m.user_id);
          const points=days.reduce((sum,d)=>sum+results.read(municipalityId,m.user_id,d.matchday_id).summary.total,0);
          return {memberId:m.member_id,pseudonym:m.pseudonym,points,rank:0,isCurrentUser:m.user_id===userId};
        }).sort((a,b)=>b.points-a.points || a.memberId.localeCompare(b.memberId));
        for(let i=0;i<entries.length;i++) entries[i].rank=i>0 && entries[i].points===entries[i-1].points ? entries[i-1].rank : i+1;
      }
      return {...envelope(c),league:meta,entries,cooperativeScore:null};
    },
    invite(municipalityId,userId,id,body) {
      exactFields(body,['expiresInHours']);
      if(!Number.isInteger(body.expiresInHours) || body.expiresInHours<1 || body.expiresInHours>168) fail('invalid_field','Invite expiry must be 1..168 hours.',400);
      const c=context(municipalityId,userId); activeSeason(c);
      return transaction(db,()=> {
        const league=leagueFor(c,id); owner(c,league);
        const token=randomBytes(32).toString('base64url'), inviteId=randomUUID();
        const expiresAt=new Date(Math.min(now()+body.expiresInHours*3600000,Date.parse(c.season.ends_at))).toISOString();
        // Rotation makes retry safe without persisting a recoverable raw token.
        db.prepare('UPDATE fantasy_invites SET revoked = 1 WHERE league_id = ?').run(id);
        db.prepare('INSERT INTO fantasy_invites VALUES (?, ?, ?, ?, 0)').run(inviteId,id,createHash('sha256').update(token).digest('hex'),expiresAt);
        return {...envelope(c),invite:{id:inviteId,token,expiresAt}};
      });
    },
    revoke(municipalityId,userId,id,inviteId) {
      const c=context(municipalityId,userId);
      return transaction(db,()=> {
        owner(c,leagueFor(c,id));
        db.prepare('UPDATE fantasy_invites SET revoked = 1 WHERE id = ? AND league_id = ?').run(inviteId,id);
        return {...envelope(c),status:'revoked'};
      });
    },
    join(municipalityId,userId,body) {
      exactFields(body,['token']);
      const c=context(municipalityId,userId); activeSeason(c); rateLimit(c);
      return transaction(db,()=> {
        if(typeof body.token!=='string' || !/^[A-Za-z0-9_-]{43}$/.test(body.token)) fail('invalid_invite','Invite not available.',404);
        const invite=db.prepare("SELECT i.* FROM fantasy_invites i JOIN fantasy_leagues l ON l.id=i.league_id WHERE i.token_hash = ? AND i.revoked = 0 AND i.expires_at > ? AND l.season_id = ? AND l.status = 'active'")
          .get(createHash('sha256').update(body.token).digest('hex'),iso(),c.season.id);
        if(!invite) fail('invalid_invite','Invite not available.',404);
        const league=leagueFor(c,invite.league_id); addMember(c,league);
        return {...envelope(c),league:metadata(c,league)};
      });
    },
    leave(municipalityId,userId,id) {
      const c=context(municipalityId,userId);
      return transaction(db,()=> {
        const league=leagueFor(c,id);
        if(league.owner_id===userId) archive(id, false);
        db.prepare('DELETE FROM fantasy_members WHERE league_id = ? AND user_id = ?').run(id,userId);
        return {...envelope(c),status:'left'};
      });
    },
    erase(userId) {
      for(const league of db.prepare('SELECT id FROM fantasy_leagues WHERE owner_id = ?').all(userId)) archive(league.id);
      db.prepare('DELETE FROM fantasy_members WHERE user_id = ?').run(userId);
      db.prepare('DELETE FROM fantasy_invite_attempts WHERE user_id = ?').run(userId);
    },
  };
}
