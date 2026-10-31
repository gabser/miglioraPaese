import {randomUUID} from 'node:crypto';
const iso=v=>new Date(v).toISOString();
// All functions require the caller's transaction client. No independent writes,
// domain-history scans or registration at boot can create historical events.
export function createCooperationEvents({clock=Date.now,onCheckpoint=async()=>{}}={}){
 async function enqueue(c,{eventKey,version,type,municipalityId,target,recipients}){
  for(const account of new Set(recipients.filter(Boolean)))await c.query(`INSERT INTO cooperation_outbox(id,event_key,event_version,recipient_id,municipality_id,type,target,created_at) SELECT $1,$2,$3,id,$4,$5,$6,$7 FROM accounts WHERE id=$8 ON CONFLICT(event_key,event_version,recipient_id) DO NOTHING`,[randomUUID(),eventKey,version,municipalityId,type,JSON.stringify(target),iso(clock()),account]);
  await onCheckpoint('cooperation_outbox_before_commit');
 }
 async function followers(c,m,p){return (await c.query('SELECT account_id FROM cooperation_follows WHERE municipality_id=$1 AND place_id=$2',[m,p])).rows.map(r=>r.account_id);}
 return {
  async reviewed(c,o,type,request=null){
   const recheck=type==='recheckRequested';
   if(recheck){
    const recipients=new Set([o.account_id,...await followers(c,o.municipality_id,o.place_id)]);
    for(const recipient of recipients){
     const target=recipient===o.account_id?{kind:'recheck',replicationRequestId:request.id,missionId:o.mission_id}:{kind:'mission',missionId:o.mission_id};
     await enqueue(c,{eventKey:'recheck:'+request.id,version:o.revision,type,municipalityId:o.municipality_id,target,recipients:[recipient]});
    }
   }else await enqueue(c,{eventKey:'observation:'+o.id+':'+type,version:o.revision,type,municipalityId:o.municipality_id,target:{kind:'observation',observationId:o.id},recipients:[o.account_id]});
   if(type!=='observationApproved')return;
   const targets=(await c.query(`SELECT t.*,g.season_id FROM cooperation_targets t JOIN cooperation_goals g ON g.id=t.goal_id WHERE g.municipality_id=$1 AND t.place_id=$2 AND t.starts_at=$3 AND t.ends_at=$4`,[o.municipality_id,o.place_id,iso(o.starts_at),iso(o.ends_at)])).rows;
   for(const t of targets){
    const args=[t.goal_id,t.place_id,iso(t.starts_at),iso(t.ends_at),iso(clock())];
    await c.query('INSERT INTO cooperation_coverage(goal_id,place_id,starts_at,ends_at,validated_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING',args);
    await c.query(`INSERT INTO cooperation_league_coverage(league_id,goal_id,place_id,starts_at,ends_at,validated_at) SELECT DISTINCT l.id,$1,$2,$3::timestamptz,$4::timestamptz,$5::timestamptz FROM fantasy_leagues l JOIN fantasy_members m ON m.league_id=l.id WHERE l.season_id=$6 AND l.status='active' AND m.user_id='account:'||$7::text AND m.joined_at::timestamptz<=$8::timestamptz ON CONFLICT DO NOTHING`,[...args,t.season_id,o.account_id,iso(o.submitted_at)]);
   }
   await onCheckpoint('cooperation_coverage_before_commit');
  },
  async published(c,e,result,placeId){
   const recipients=placeId?await followers(c,e.municipality_id,placeId):[];
   if(placeId){const contributors=await c.query(`SELECT DISTINCT b.account_id FROM mission_observations o JOIN mission_bookings b ON b.id=o.booking_id JOIN missions m ON m.id=b.mission_id JOIN mission_places p ON p.mission_id=m.id JOIN mission_windows w ON w.id=b.window_id WHERE m.municipality_id=$1 AND p.place_id=$2 AND EXISTS(SELECT 1 FROM mission_card_links l WHERE l.mission_id=m.id AND l.season_id=$3 AND l.matchday_id=$4 AND l.card_id=$5)`,[e.municipality_id,placeId,e.season_id,e.matchday_id,e.card_id]);recipients.push(...contributors.rows.map(r=>r.account_id));}
   const players=await c.query(`SELECT a.id FROM accounts a JOIN fantasy_snapshots s ON s.user_id='account:'||a.id::text WHERE s.season_id=$1 AND s.matchday_id=$2 AND s.payload::jsonb->'squadIds' ? $3`,[e.season_id,e.matchday_id,e.card_id]);recipients.push(...players.rows.map(r=>r.id));
   await enqueue(c,{eventKey:'evaluation:'+e.id,version:result.version,type:result.version===1?'outcomePublished':'outcomeCorrected',municipalityId:e.municipality_id,target:{kind:'evaluation',evaluationId:e.id,seasonId:e.season_id,matchdayId:e.matchday_id},recipients});
  },
 };
}
export async function drainCooperationOutbox(c,{clock=Date.now,onCheckpoint=async()=>{}}={}){
 await c.query(`INSERT INTO cooperation_inbox(id,recipient_id) SELECT id,recipient_id FROM cooperation_outbox WHERE delivered_at IS NULL ON CONFLICT DO NOTHING`);
 await onCheckpoint('cooperation_drain_before_commit');
 await c.query('UPDATE cooperation_outbox SET delivered_at=$1 WHERE delivered_at IS NULL',[iso(clock())]);
}
