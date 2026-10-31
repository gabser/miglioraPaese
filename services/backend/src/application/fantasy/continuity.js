import { createHash, randomUUID } from 'node:crypto';
import { exactFields, fantasyError } from './teams.js';

export function createLeagueContinuity({db,teams,now,context,leagueFor,memberFor,owner}) {
  const iso=()=>new Date(now()).toISOString();
  const fail=(code,message,status=409)=>{throw fantasyError(status,code,message);};
  const rows=async(sql,args=[])=>(await db.raw(sql,args)).rows;
  const one=async(sql,args=[])=>(await rows(sql,args))[0];
  const bump=async id=>(await one('UPDATE fantasy_leagues SET revision=revision+1 WHERE id=$1 RETURNING revision',[id])).revision;
  async function audit(leagueId,offerId,memberId,action,revision){await db.raw('INSERT INTO fantasy_ownership_audit(id,league_id,offer_id,actor_member_id,action,revision,created_at) VALUES($1,$2,$3,$4,$5,$6,$7)',[randomUUID(),leagueId,offerId,memberId,action,revision,iso()]);}
  async function cancel(leagueId,{userId=null,action='cancelled'}={}){
    const offers=await rows("UPDATE fantasy_ownership_offers SET status='cancelled' WHERE league_id=$1 AND status='pending' AND ($2::text IS NULL OR from_user_id=$2 OR to_user_id=$2) RETURNING id",[leagueId,userId]);
    for(const o of offers)await audit(leagueId,o.id,null,action,await bump(leagueId));
  }
  async function role(league){
    const frozen=await db.one('select_snapshots_by_season_id',league.season_id);
    const reason=now()>=Date.parse(league.first_locks_at)?'firstLockReached':frozen?'snapshotFrozen':null;
    return {expectedRole:reason?'spectator':'competitor',lateJoinReason:reason};
  }
  async function offerDto(offer,userId){
    const member=await one("SELECT m.member_id,COALESCE(a.pseudonym,m.pseudonym) AS pseudonym FROM fantasy_members m LEFT JOIN accounts a ON m.user_id='account:' || a.id::text WHERE m.league_id=$1 AND m.user_id=$2",[offer.league_id,offer.to_user_id]);
    return {id:offer.id,targetMemberId:offer.target_member_id,targetPseudonym:member?.pseudonym??'Manager',status:offer.status,expiresAt:offer.expires_at,isTarget:offer.to_user_id===userId};
  }
  async function expire(league){
    const expired=await rows("UPDATE fantasy_ownership_offers SET status='expired' WHERE league_id=$1 AND status='pending' AND expires_at<=$2 RETURNING id",[league.id,iso()]);
    for(const o of expired)await audit(league.id,o.id,null,'expired',await bump(league.id));
    if(expired.length)league.revision=(await one('SELECT revision FROM fantasy_leagues WHERE id=$1',[league.id])).revision;
  }
  return {
    bump,cancel,role,audit,
    async preview(body,{pilotMunicipalityId,rateBucket='local'}={}) {
      exactFields(body,['token']);
      // Commit attempts independently of token validity; only a bounded hash of
      // the peer participates, never the credential or supplied forwarding data.
      await db.transaction(async()=>{
        const bucket=createHash('sha256').update(rateBucket).digest('hex');
        const previous=await one('SELECT * FROM fantasy_invite_preview_attempts WHERE bucket=$1',[bucket]);
        const reset=!previous||now()-Number(previous.window_start)>=60000;
        if(!reset&&previous.attempts>=30)fail('invite_rate_limited','Wait before trying another invite.',429);
        await db.raw('INSERT INTO fantasy_invite_preview_attempts(bucket,window_start,attempts) VALUES($1,$2,$3) ON CONFLICT(bucket) DO UPDATE SET window_start=excluded.window_start,attempts=excluded.attempts',[bucket,reset?now():previous.window_start,reset?1:previous.attempts+1]);
        await db.raw('DELETE FROM fantasy_invite_preview_attempts WHERE window_start<$1',[now()-120000]);
      });
      return db.transaction(async()=>{
        if(typeof body.token!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(body.token))fail('not_found','Invite not available.',404);
        const l=await one("SELECT l.*,i.expires_at,s.municipality_id,s.ends_at FROM fantasy_invites i JOIN fantasy_leagues l ON l.id=i.league_id JOIN fantasy_seasons s ON s.id=l.season_id WHERE i.token_hash=$1 AND i.revoked=0 AND i.expires_at>$2 AND l.status='active'",[createHash('sha256').update(body.token).digest('hex'),iso()]);
        if(!l||now()>=Date.parse(l.ends_at)||(pilotMunicipalityId&&l.municipality_id!==pilotMunicipalityId))fail('not_found','Invite not available.',404);
        return {serverTime:iso(),municipalityId:l.municipality_id,seasonId:l.season_id,leagueId:l.id,name:l.name,leagueRevision:l.revision,expiresAt:l.expires_at,firstLocksAt:l.first_locks_at,...await role(l)};
      });
    },
    async ownership(municipalityId,userId,id){return db.transaction(async()=>{
      const c=await context(municipalityId,userId,id),l=await leagueFor(c,id);await memberFor(c,l);await expire(l);
      const isOwner=l.owner_id===userId&&l.status==='active';
      const candidates=isOwner?await rows("SELECT m.member_id AS \"memberId\",COALESCE(a.pseudonym,m.pseudonym) AS pseudonym FROM fantasy_members m LEFT JOIN accounts a ON m.user_id='account:' || a.id::text WHERE m.league_id=$1 AND m.user_id<>$2 ORDER BY m.member_id",[id,userId]):[];
      const pending=await one("SELECT * FROM fantasy_ownership_offers WHERE league_id=$1 AND status='pending' AND ($2=from_user_id OR $2=to_user_id)",[id,userId]);
      return {serverTime:iso(),seasonId:l.season_id,leagueId:id,revision:l.revision,isOwner,candidates,pendingOffer:pending?await offerDto(pending,userId):null};
    });},
    async ownershipCommand(municipalityId,userId,id,action,offerId,body){
      exactFields(body,action==='offer'?['targetMemberId','expectedRevision','idempotencyKey']:['expectedRevision','idempotencyKey']);
      if(!Number.isSafeInteger(body.expectedRevision)||body.expectedRevision<1||typeof body.idempotencyKey!=='string'||!/^[A-Za-z0-9_-]{8,128}$/.test(body.idempotencyKey)||(action==='offer'&&(typeof body.targetMemberId!=='string'||!body.targetMemberId||body.targetMemberId.length>128)))fail('invalid_field','Invalid ownership command.',400);
      return db.transaction(async()=>{
        const c=await context(municipalityId,userId,id),l=await leagueFor(c,id),member=await memberFor(c,l);
        const requestHash=createHash('sha256').update(JSON.stringify([action,offerId??null,body.expectedRevision,body.targetMemberId??null])).digest('hex');
        const prior=await one('SELECT * FROM fantasy_ownership_commands WHERE league_id=$1 AND user_id=$2 AND command_key=$3',[id,userId,body.idempotencyKey]);
        if(prior){if(prior.request_hash!==requestHash)fail('idempotency_conflict','Key already used for another command.');return prior.response;}
        if(l.status!=='active')fail('league_archived','League is archived.');
        // All authority and time checks are inside the shared serialization lock.
        if(now()>=Date.parse(c.season.ends_at))fail('season_ended','Season has ended.');
        let offer=action==='offer'?null:await one('SELECT * FROM fantasy_ownership_offers WHERE league_id=$1 AND id=$2',[id,offerId]);
        if(action==='accept'){
          if(!offer)fail('not_found','Offer not found.',404);
          if(offer.to_user_id!==userId)fail('forbidden','Only the target can accept.',403);
        }else await owner(c,l);
        if(offer&&(offer.status!=='pending'||now()>=Date.parse(offer.expires_at)))fail('offer_closed','Offer is no longer pending.');
        if(l.revision!==body.expectedRevision)fail('league_revision_conflict','League has changed. Refresh before confirming.');
        if(action==='offer'){
          const target=await one('SELECT * FROM fantasy_members WHERE league_id=$1 AND member_id=$2',[id,body.targetMemberId]);
          if(!target)fail('not_found','Member not found.',404);
          if(target.user_id===userId)fail('invalid_field','Choose another member.',400);
          await expire(l);
          if(await one("SELECT id FROM fantasy_ownership_offers WHERE league_id=$1 AND status='pending'",[id]))fail('offer_closed','A pending offer already exists.');
          const expiresAt=new Date(Math.min(now()+7*86400000,Date.parse(c.season.ends_at))).toISOString();
          offer=await one("INSERT INTO fantasy_ownership_offers(id,league_id,season_id,from_user_id,to_user_id,target_member_id,status,expires_at,created_at) VALUES($1,$2,$3,$4,$5,$6,'pending',$7,$8) RETURNING *",[randomUUID(),id,l.season_id,userId,target.user_id,target.member_id,expiresAt,iso()]);
        }else{
          if(!offer)fail('not_found','Offer not found.',404);
          if(offer.from_user_id!==l.owner_id)fail('offer_closed','Offer owner has changed.');
          if(action==='accept'){
            const target=await one('SELECT member_id FROM fantasy_members WHERE league_id=$1 AND user_id=$2',[id,userId]);
            if(!target||target.member_id!==offer.target_member_id||userId===l.owner_id)fail('offer_closed','Target membership has changed.');
            const count=await db.one('select_leagues_by_season_id_owner_id',l.season_id,userId);
            if(Number(count.n)>=3)fail('league_limit','At most three owned leagues per season.');
            await db.raw('UPDATE fantasy_leagues SET owner_id=$2 WHERE id=$1',[id,userId]);
          }
          offer=await one('UPDATE fantasy_ownership_offers SET status=$2 WHERE id=$1 RETURNING *',[offer.id,action==='accept'?'accepted':'revoked']);
        }
        const revision=await bump(id);
        await audit(id,offer.id,member.member_id,action==='offer'?'offered':action==='accept'?'accepted':'revoked',revision);
        const response={serverTime:iso(),seasonId:l.season_id,leagueId:id,revision,offer:await offerDto(offer,userId)};
        await db.raw('INSERT INTO fantasy_ownership_commands(league_id,season_id,user_id,command_key,request_hash,response) VALUES($1,$2,$3,$4,$5,$6)',[id,l.season_id,userId,body.idempotencyKey,requestHash,JSON.stringify(response)]);
        return response;
      });
    },
  };
}
