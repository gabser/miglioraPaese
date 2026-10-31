import { iso,digest,otpHash,requireValue,exact } from '../domain/account/rules.js';
import { rateError } from '../domain/account/rules.js';
import { accountQuery, moveFantasyOwner, moveLegacyGameOwner, moveLeagueContinuityOwner } from '../persistence/postgres/account-repository.js';
import { randomUUID, randomInt, randomBytes, timingSafeEqual } from 'node:crypto';
import { newProposalSession, sessionHash, sessionIdentity, sessionRevoked } from '../domain/proposal-session.js';
import { httpError } from '../domain/errors.js';
import { withTransaction } from '../persistence/postgres/transaction.js';

const quiet={warn(){},error(){}};
export function createAccountService({pool,emailAdapter,clock=Date.now,onCheckpoint=async()=>{},codeFactory=()=>String(randomInt(0,1000000)).padStart(6,'0')}) {
  if(emailAdapter?.delivery!=='simulated')throw new TypeError('An explicit simulated email adapter is required.');
  const tx=action=>withTransaction(pool,async client=>{await accountQuery(client,"select_transaction_1");return action(client);},{logger:quiet});
  async function lockSession(client,token,{allowRevoked=false,requireAccount=true}={}) {
    const {rows}=await accountQuery(client,"select_proposal_sessions_2",[sessionHash(token)]);
    const row=rows[0];if(!row||(!allowRevoked&&row.revoked_at))throw sessionRevoked();
    if(!allowRevoked&&row.expires_at&&Date.parse(row.expires_at)<=clock())throw httpError(401,'session_expired','Session has expired.');
    if(requireAccount&&!row.account_id)throw httpError(401,'account_required','An account session is required.');
    return row;
  }
  async function accountDto(client,id){const row=(await accountQuery(client,"select_accounts_3",[id])).rows[0];return {...row,emailVerified:true};}
  async function sessionDto(client,row){return {submissionScope:row.submission_scope,sessionId:row.device_id,account:await accountDto(client,row.account_id),expiresAt:iso(row.expires_at)};}
  const api={
    async isReady() {
      try {
        for(const operation of ['probe_sessions','probe_accounts','probe_scopes','probe_codes','probe_links','probe_abandoned'])await accountQuery(pool,operation);
        return true;
      } catch { return false; }
    },
    async requestCode(body) {
      exact(body,['email']);const email=typeof body.email==='string'?body.email.trim().toLowerCase():'';
      requireValue(/^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@(?:example\.(?:com|invalid)|[a-z0-9.-]+\.test)$/.test(email)&&email.length<=254,'synthetic_email_required','Local delivery accepts only synthetic example/test addresses.');
      const challengeId=randomUUID(),code=codeFactory(),now=clock();
      requireValue(typeof code==='string'&&/^\d{6}$/.test(code),'invalid_field','Invalid synthetic fixture code generator.');
      const result=await tx(async client=>{
        await accountQuery(client,"select_transaction_4",['account-code:'+email]);
        const recent=(await accountQuery(client,"select_account_email_codes_5",[email,iso(now-3600000)])).rows;
        if(recent[0]&&now-Date.parse(recent[0].created_at)<60000)return {error:rateError(Math.ceil((60000-now+Date.parse(recent[0].created_at))/1000))};
        if(recent.length>=6)return {error:rateError(Math.ceil((3600000-now+Date.parse(recent.at(-1).created_at))/1000))};
        await accountQuery(client,"update_account_email_codes_6",[email,iso(now)]);
        await accountQuery(client,"insert_account_email_codes_7",[challengeId,email,await otpHash(code,challengeId),iso(now),iso(now+300000)]);
        return {challengeId,expiresAt:iso(now+300000),resendAfterSeconds:60,retryAfterSeconds:60,delivery:'simulated'};
      });
      if(result.error)throw result.error;
      await emailAdapter.deliver({challengeId,email,code,expiresAt:result.expiresAt});
      return result;
    },
    async verify(body) {
      exact(body,['challengeId','code','deviceName']);requireValue(typeof body.challengeId==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(body.challengeId)&&typeof body.code==='string'&&/^\d{6}$/.test(body.code),'code_invalid','Invalid verification code.');
      const name=body.deviceName??'Dispositivo';requireValue(typeof name==='string'&&name.trim().length>=1&&name.length<=80,'invalid_field','Invalid device name.');
      const outcome=await tx(async client=>{
        const row=(await accountQuery(client,"select_account_email_codes_8",[body.challengeId])).rows[0];
        if(!row)return {error:httpError(400,'code_invalid','Invalid verification code.')};
        if(row.consumed_at)return {error:httpError(400,'code_used','The code was already consumed.')};
        if(clock()>=Date.parse(row.expires_at))return {error:httpError(400,'code_expired','The code has expired.')};
        if(row.attempts>=5)return {error:httpError(400,'code_attempts_exceeded','Request another code.')};
        await accountQuery(client,"update_account_email_codes_9",[row.id]);
        const expected=Buffer.from(row.code_hash,'hex'),given=Buffer.from(await otpHash(body.code,row.id),'hex');
        if(!timingSafeEqual(expected,given))return {error:httpError(400,row.attempts===4?'code_attempts_exceeded':'code_invalid','Invalid verification code.')};
        await accountQuery(client,"insert_accounts_10",[randomUUID(),row.email,'Sentinella '+randomBytes(4).toString('hex'),iso(clock())]);
        const account=(await accountQuery(client,"select_accounts_11",[row.email])).rows[0];
        const session=newProposalSession(),deviceId=randomUUID(),expiresAt=iso(clock()+30*86400000);
        await accountQuery(client,"insert_proposal_sessions_12",[session.tokenHash,session.submissionScope,account.id,deviceId,name.trim(),expiresAt,iso(clock())]);
        await accountQuery(client,"insert_account_scopes_13",[session.submissionScope,account.id,iso(clock())]);
        await accountQuery(client,"update_account_email_codes_14",[row.id,iso(clock())]);
        await onCheckpoint('verified');
        return {token:session.token,...await sessionDto(client,{submission_scope:session.submissionScope,device_id:deviceId,account_id:account.id,expires_at:expiresAt})};
      });
      if(outcome.error)throw outcome.error;return outcome;
    },
    me:token=>tx(async client=>sessionDto(client,await lockSession(client,token))),
    devices:token=>tx(async client=>{const session=await lockSession(client,token);const rows=(await accountQuery(client,"select_proposal_sessions_15",[session.account_id])).rows;return {items:rows.map(row=>({id:row.device_id,name:row.device_name,createdAt:iso(row.created_at),revokedAt:row.revoked_at?iso(row.revoked_at):null,isCurrent:row.device_id===session.device_id}))};}),
    logout:token=>tx(async client=>{const row=await lockSession(client,token,{allowRevoked:true});await accountQuery(client,"update_proposal_sessions_16",[row.token_hash,iso(clock())]);return {revoked:true};}),
    revokeDevice:(token,id)=>tx(async client=>{requireValue(typeof id==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id),'invalid_field','Invalid device ID.');const session=await lockSession(client,token,{allowRevoked:true});if(session.device_id!==id){if(session.revoked_at)throw sessionRevoked();if(session.expires_at&&Date.parse(session.expires_at)<=clock())throw httpError(401,'session_expired','Session has expired.');}await accountQuery(client,"update_proposal_sessions_17",[session.account_id,id,iso(clock())]);return {revoked:true};}),
    profile:(token,body)=>tx(async client=>{exact(body,['pseudonym']);const name=typeof body.pseudonym==='string'?body.pseudonym.trim():'';requireValue(/^[\p{L}\p{N} _-]{2,32}$/u.test(name),'invalid_field','Pseudonym must contain 2–32 letters, digits or spaces.');const session=await lockSession(client,token);await accountQuery(client,"update_accounts_18",[session.account_id,name]);return {account:await accountDto(client,session.account_id)};}),
  };
  api.linkGuest=(token,body)=>linkGuest({pool,token,body,clock,accountDto,onCheckpoint});
  return api;
}

async function linkGuest({pool,token,body,clock,accountDto,onCheckpoint}) {
  exact(body,['guestToken','idempotencyKey','conflictChoice']);requireValue(typeof body.idempotencyKey==='string'&&/^[A-Za-z0-9_-]{8,128}$/.test(body.idempotencyKey)&&(!body.conflictChoice||body.conflictChoice==='keepAccount'),'invalid_field','Invalid linking command.');
  const guestHash=sessionHash(body.guestToken),accountHash=sessionHash(token);
  return withTransaction(pool,async client=>{
    await accountQuery(client,"select_transaction_1");
    const sessions=(await accountQuery(client,"select_proposal_sessions_19",[[guestHash,accountHash]])).rows;
    const accountSession=sessions.find(s=>s.token_hash===accountHash),guest=sessions.find(s=>s.token_hash===guestHash);
    if(!accountSession||accountSession.revoked_at||!accountSession.account_id||Date.parse(accountSession.expires_at)<=clock())throw httpError(401,'account_required','An active account session is required.');
    requireValue(guest&&guest.token_hash!==accountHash&&!guest.revoked_at,'link_guest_invalid','An active guest session is required.');
    const prior=(await accountQuery(client,"select_account_guest_links_20",[guest.submission_scope])).rows[0];
    const hash=digest(JSON.stringify([accountSession.account_id,body.conflictChoice??null]));
    if(prior){if(prior.account_id!==accountSession.account_id)throw httpError(409,'link_guest_already_linked','Guest data belongs to another account.');if(prior.command_key===body.idempotencyKey&&prior.request_hash!==hash)throw httpError(409,'idempotency_conflict','Link key was used for another choice.');return prior.response;}
    requireValue(!guest.account_id,'link_guest_invalid','The supplied session is not a guest.');
    const guestId=sessionIdentity({submissionScope:guest.submission_scope}),accountId='account:'+accountSession.account_id;
    const conflicts=(await accountQuery(client,"select_fantasy_players_21",[guestId,accountId])).rows;
    if(conflicts.length&&!body.conflictChoice)return {status:'conflict',conflicts,account:await accountDto(client,accountSession.account_id)};
    const excluded=conflicts.map(c=>c.seasonId);
    const fantasyTables=['players','drafts','snapshots','result_revisions','quotes','transfer_commands','transfers','reveals','finalizations','reflections','members','invite_attempts'];
    for(const table of fantasyTables)await moveFantasyOwner(client,table,guestId,accountId,excluded);
    await accountQuery(client,"update_fantasy_leagues_22",[guestId,accountId,excluded]);
    await moveLeagueContinuityOwner(client,guestId,accountId,excluded);
    // Abandoned guest seasons retain their original history; they do not award
    // account points or overwrite the account roster. Their invites are revoked.
    await accountQuery(client,"update_fantasy_leagues_23",[guestId,excluded]);
    await accountQuery(client,"update_fantasy_invites_24",[guestId,excluded]);
    // No legacy game result/prediction merge: overlapping turns preserve both
    // histories under the old identity; non-overlapping server history moves.
    const overlap=(await accountQuery(client,"select_predictions_25",[guestId,accountId])).rows.map(r=>r.turn_id);
    for(const table of ['predictions','prediction_results','reputation_events'])await moveLegacyGameOwner(client,table,guestId,accountId,overlap);
    // Original proposal authors/scopes stay intact; account recovery uses owned-scope aliases.
    await accountQuery(client,"delete_suggestion_votes_26",[guestId,accountId]);
    await accountQuery(client,"update_suggestion_votes_27",[guestId,accountId]);
    // The guest credential keeps its guest principal and receipt namespace.
    await accountQuery(client,"insert_account_scopes_13",[guest.submission_scope,accountSession.account_id,iso(clock())]);
    const response={status:'linked',conflicts,account:await accountDto(client,accountSession.account_id)};
    await accountQuery(client,"insert_account_guest_links_28",[guest.submission_scope,accountSession.account_id,body.idempotencyKey,hash,JSON.stringify(response),iso(clock())]);
    for(const season of excluded)await accountQuery(client,"insert_account_abandoned_teams_29",[accountSession.account_id,guest.submission_scope,season]);
    await onCheckpoint('guest_link_before_commit');return response;
  },{logger:quiet});
}
