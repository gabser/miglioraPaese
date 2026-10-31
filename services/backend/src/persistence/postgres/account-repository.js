import { accountStatements } from './account-statements.js';
export function accountQuery(client,operation,values=[]) {
  const sql=accountStatements[operation];if(!sql)throw new TypeError('Unknown account persistence operation.');
  return client.query(sql,values);
}
export function moveFantasyOwner(client,table,guestId,accountId,excluded) {
  if(!['players','drafts','snapshots','result_revisions','quotes','transfer_commands','transfers','reveals','finalizations','reflections','members','invite_attempts'].includes(table))throw new TypeError('Unknown fantasy ownership resource.');
  return client.query(`UPDATE public.fantasy_${table} SET user_id=$2 WHERE user_id=$1 AND NOT(season_id=ANY($3::text[]))`,[guestId,accountId,excluded]);
}
export function moveLegacyGameOwner(client,table,guestId,accountId,excluded) {
  if(!['predictions','prediction_results','reputation_events'].includes(table))throw new TypeError('Unknown legacy ownership resource.');
  return client.query(`UPDATE public.${table} SET user_id=$2 WHERE user_id=$1 AND NOT(turn_id=ANY($3::text[]))`,[guestId,accountId,excluded]);
}

// Called in the same advisory-locked phase-2 transaction as players/members.
// Immutable command responses and audit member IDs are historical snapshots.
export async function moveLeagueContinuityOwner(client,guestId,accountId,excluded) {
  // When an erased account team left a historical creation command with the
  // same key, retain the account command and the guest creator snapshot. The
  // league/membership still move; an ambiguous key must never replay another
  // creation or abort an otherwise valid link.
  await client.query(`UPDATE fantasy_leagues g SET creator_id=$2
    WHERE g.creator_id=$1 AND NOT(g.season_id=ANY($3::text[]))
    AND NOT EXISTS(SELECT 1 FROM fantasy_leagues a WHERE a.creator_id=$2
      AND a.season_id=g.season_id AND a.creation_key=g.creation_key)`,[guestId,accountId,excluded]);
  await client.query(`UPDATE fantasy_ownership_offers SET
    from_user_id=CASE WHEN from_user_id=$1 THEN $2 ELSE from_user_id END,
    to_user_id=CASE WHEN to_user_id=$1 THEN $2 ELSE to_user_id END
    WHERE (from_user_id=$1 OR to_user_id=$1) AND NOT(season_id=ANY($3::text[]))`,[guestId,accountId,excluded]);
  await client.query('UPDATE fantasy_ownership_commands SET user_id=$2 WHERE user_id=$1 AND NOT(season_id=ANY($3::text[]))',[guestId,accountId,excluded]);
  const cancelled=await client.query(`UPDATE fantasy_ownership_offers SET status='cancelled'
    WHERE status='pending' AND (from_user_id=to_user_id OR
      (season_id=ANY($2::text[]) AND (from_user_id=$1 OR to_user_id=$1))) RETURNING id,league_id`,[guestId,excluded]);
  for(const offer of cancelled.rows){
    const league=(await client.query('UPDATE fantasy_leagues SET revision=revision+1 WHERE id=$1 RETURNING revision',[offer.league_id])).rows[0];
    await client.query("INSERT INTO fantasy_ownership_audit(id,league_id,offer_id,actor_member_id,action,revision,created_at) VALUES(gen_random_uuid()::text,$1,$2,NULL,'cancelled',$3,$4)",[offer.league_id,offer.id,league.revision,new Date().toISOString()]);
  }
}
