import { randomUUID } from 'node:crypto';
import { exact,key,revision,uuid,hash,fail } from '../domain/missions/rules.js';
const iso=value=>new Date(value).toISOString();
const states=['pendingReview','screened','needsIntegration','approved','rejected'];
const text=(value,field)=>{if(typeof value!=='string'||!value.trim()||value.length>1000)fail('invalid_field',field+' requires 1–1000 characters.');return value.trim();};
const proof=p=>({id:p.id,sha256:p.sha256,sizeBytes:p.sanitized_bytes,mimeType:p.mime_type,width:p.width,height:p.height});
const booking=b=>({id:b.id,missionId:b.mission_id,windowId:b.window_id,protocolVersion:b.protocol_version,status:b.status,expiresAt:iso(b.expires_at),revision:b.revision,replicationRequestId:b.replication_request_id??null});
const upload=u=>({id:u.id,bookingId:u.booking_id,mimeType:u.mime_type,totalBytes:u.total_bytes,receivedBytes:u.received_bytes,status:u.status,revision:u.revision,expiresAt:iso(u.expires_at),...(u.width?{width:u.width,height:u.height,sha256:u.sha256,sanitizedBytes:u.sanitized_bytes}:{})});
const replication=r=>({id:r.id,authorId:r.account_id,municipalityId:r.municipality_id,missionId:r.mission_id,placeId:r.place_id,windowId:r.window_id,protocolVersion:r.protocol_version,dueAt:iso(r.due_at),status:r.status,bookingId:r.booking_id??null});
export function createReviewService({repository,storage,clock=Date.now,retentionDays=1,cooperationEvents,onCheckpoint=async()=>{}}){
 const rows=async(c,sql,args=[])=>(await c.query(sql,args)).rows,one=async(c,sql,args)=>(await rows(c,sql,args))[0];
 const roles=(c,a,m)=>rows(c,'SELECT role FROM review_roles WHERE account_id=$1 AND municipality_id=$2 ORDER BY role',[a,m]).then(v=>v.map(r=>r.role));
 async function requireRole(c,a,m,allowed=['moderator','verifier']){const r=await roles(c,a,m);if(!allowed.some(v=>r.includes(v)))fail('review_forbidden','Municipality review role required.',403);return r;}
 async function observation(c,id,municipality=null){
  uuid(id);
  const o=await one(c,`SELECT o.*,b.account_id,b.mission_id,b.window_id,b.protocol_version,b.replication_request_id,m.municipality_id,m.protocol,w.starts_at,w.ends_at FROM mission_observations o JOIN mission_bookings b ON b.id=o.booking_id JOIN missions m ON m.id=b.mission_id JOIN mission_windows w ON w.id=b.window_id WHERE o.id=$1 AND ($2::text IS NULL OR m.municipality_id=$2) FOR UPDATE OF o,b`,[id,municipality]);
  if(!o)fail('observation_not_found','Private observation not found.',404);
  await c.query(`INSERT INTO mission_places SELECT id,municipality_id||':area:'||md5(area::text) FROM missions WHERE id=$1 ON CONFLICT DO NOTHING`,[o.mission_id]);
  await c.query('INSERT INTO observation_reviews(observation_id,place_id) SELECT $1,place_id FROM mission_places WHERE mission_id=$2 ON CONFLICT DO NOTHING',[id,o.mission_id]);
  return {...o,...await one(c,'SELECT * FROM observation_reviews WHERE observation_id=$1 FOR UPDATE',[id])};
 }
 async function conflict(c,a,o){
  if(o.account_id===a)fail('self_review','Authors cannot review themselves.',403);
  const linked=await one(c,`SELECT 1 FROM mission_card_links l JOIN fantasy_players p ON p.season_id=l.season_id AND p.user_id IN (SELECT 'account:'||$2::text UNION SELECT 'session:'||submission_scope::text FROM account_scopes WHERE account_id=$2::uuid) LEFT JOIN fantasy_snapshots s ON s.season_id=l.season_id AND s.user_id=p.user_id AND s.matchday_id=l.matchday_id WHERE l.mission_id=$1 AND (CASE WHEN s.payload IS NOT NULL THEN s.payload::jsonb->'squadIds' ELSE p.squad_ids::jsonb END) ? l.card_id LIMIT 1`,[o.mission_id,a]);
  if(linked)fail('competitive_conflict','Operator competes on a linked card.',403);
 }
 async function live(c,o,withProofs=true){
  const i=await one(c,'SELECT * FROM integration_requests WHERE observation_id=$1 ORDER BY requested_at DESC,id DESC LIMIT 1',[o.id]);
  const audit=await rows(c,'SELECT * FROM review_audit WHERE observation_id=$1 ORDER BY revision,id',[o.id]);
  const supplements=await rows(c,'SELECT * FROM observation_supplements WHERE observation_id=$1 ORDER BY submitted_at,id',[o.id]);
  const xp=await one(c,'SELECT amount FROM xp_ledger WHERE observation_id=$1',[o.id]);
  return {id:o.id,bookingId:o.booking_id,municipalityId:o.municipality_id,missionId:o.mission_id,placeId:o.place_id,windowId:o.window_id,protocolVersion:o.protocol_version,answer:o.answer,...(o.receipt.measurement?{measurement:o.receipt.measurement}:{}),notes:o.notes,submittedAt:iso(o.submitted_at),status:o.status,revision:o.revision,assignedTo:o.assigned_to,xpAwarded:xp?.amount??0,proofs:withProofs?o.receipt.proofs:[],integrationRequest:i?{id:i.id,message:i.message,requestedAt:iso(i.requested_at),dueAt:iso(i.due_at),status:i.status,revision:i.revision}:null,supplements:supplements.map(s=>({id:s.id,notes:s.notes,proofs:withProofs?s.proofs:[],submittedAt:iso(s.submitted_at)})),audit:audit.map(a=>({id:a.id,action:a.action,actorId:a.actor_id,reason:a.reason,at:iso(a.at),revision:a.revision}))};
 }
 async function audit(c,o,a,action,reason){await c.query('INSERT INTO review_audit VALUES($1,$2,$3,$4,$5,$6,$7)',[randomUUID(),o.id,action,a,reason,iso(clock()),o.revision]);}
 async function update(c,o,status,assigned=o.assigned_to){const r=await one(c,'UPDATE observation_reviews SET status=$2,assigned_to=$3,revision=revision+1 WHERE observation_id=$1 RETURNING *',[o.id,status,assigned]);Object.assign(o,r);}
 async function replay(c,a,body,scope){const requestHash=hash(JSON.stringify([scope,Object.keys(body).sort().map(k=>[k,body[k]])]));const prior=await one(c,'SELECT * FROM review_commands WHERE account_id=$1 AND command_key=$2',[a,body.idempotencyKey]);if(prior&&prior.request_hash!==requestHash)fail('idempotency_conflict','Key already used for another command.',409);return {requestHash,prior};}
 async function remember(c,a,body,r,result){await c.query('INSERT INTO review_commands VALUES($1,$2,$3,$4)',[a,body.idempotencyKey,r.requestHash,JSON.stringify(result)]);return result;}
 const command=(token,m,id,action,body)=>repository.transaction(token,async(c,a)=>{
  const extras={assignment:[],screening:['decision','reason'],'integration-requests':['message'],decisions:['decision','reason'],'replication-requests':['reason']}[action];
  exact(body,['expectedRevision','idempotencyKey',...extras]);key(body.idempotencyKey);revision(body.expectedRevision);
  const rls=await requireRole(c,a,m,action==='screening'?['moderator']:action==='assignment'?['moderator','verifier']:['verifier']);
  const o=await observation(c,id,m);await conflict(c,a,o);
  const r=await replay(c,a,body,[m,id,action]);if(r.prior)return r.prior.response;
  if(o.revision!==body.expectedRevision)fail('review_revision_conflict','Observation revision changed.',409);
  if(action==='assignment'){
   if(!(o.status==='pendingReview'&&rls.includes('moderator')||['screened','needsIntegration'].includes(o.status)&&rls.includes('verifier')))fail('review_forbidden','Role cannot own this review stage.',403);
   await update(c,o,o.status,a);await audit(c,o,a,'assignment','Assigned');
  }else{
   if(o.assigned_to!==a)fail('review_forbidden','Assigned operator required.',403);
   if(action==='screening'){
    if(o.status!=='pendingReview')fail('review_revision_conflict','Screening stage closed.',409);
    if(!['forward','reject'].includes(body.decision))fail('invalid_field','Invalid screening decision.');text(body.reason,'reason');
    await update(c,o,body.decision==='forward'?'screened':'rejected',null);await audit(c,o,a,'screening:'+body.decision,body.reason.trim());
   }else if(action==='integration-requests'){
    if(o.status!=='screened')fail('integration_closed','Integration request unavailable.',409);text(body.message,'message');
    await c.query('INSERT INTO integration_requests VALUES($1,$2,$3,$4,$5,$6,1)',[randomUUID(),id,body.message.trim(),iso(clock()),iso(clock()+86400000),'open']);
    await update(c,o,'needsIntegration');await audit(c,o,a,'integration_requested',body.message.trim());
   }else if(action==='decisions'){
    if(!['screened','needsIntegration'].includes(o.status))fail('review_revision_conflict','Review stage closed.',409);
    if(!['approve','reject'].includes(body.decision))fail('invalid_field','Invalid quality decision.');text(body.reason,'reason');
    if(o.status==='needsIntegration'&&body.decision==='approve')fail('integration_closed','Awaiting author integration.',409);
    await update(c,o,body.decision==='approve'?'approved':'rejected');
    await c.query("UPDATE integration_requests SET status='closed',revision=revision+1 WHERE observation_id=$1 AND status='open'",[id]);
    if(body.decision==='approve')await c.query(`INSERT INTO xp_ledger(id,observation_id,account_id,place_id,window_id,window_scope,amount,awarded_at,rule_version,replication_request_id) VALUES($1,$2,$3,$4,$5,$6,10,$7,1,$8) ON CONFLICT DO NOTHING`,[randomUUID(),id,o.account_id,o.place_id,o.window_id,iso(o.starts_at)+'/'+iso(o.ends_at),iso(clock()),o.replication_request_id]);
    await audit(c,o,a,'decision:'+body.decision,body.reason.trim());
   }else{
    if(o.status!=='approved')fail('replication_closed','Validated observation required for replica.',409);text(body.reason,'reason');
    if(clock()>=Date.parse(o.ends_at))fail('replication_closed','Replication window closed.',409);
    const request=await one(c,'INSERT INTO replication_requests VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *',[randomUUID(),id,o.account_id,o.mission_id,m,o.place_id,o.window_id,o.protocol_version,body.reason.trim(),iso(clock()),iso(o.ends_at),'open']);
    await update(c,o,o.status);await audit(c,o,a,'replication_requested',body.reason.trim());
    await cooperationEvents?.reviewed(c,o,'recheckRequested',request);await onCheckpoint('review_before_commit');
    return remember(c,a,body,r,replication(request));
   }
  }
  if(action==='integration-requests')await cooperationEvents?.reviewed(c,o,'integrationRequested');
  if(action==='decisions'||action==='screening'&&o.status==='rejected')await cooperationEvents?.reviewed(c,o,o.status==='approved'?'observationApproved':'observationRejected');
  await onCheckpoint('review_before_commit');return remember(c,a,body,r,await live(c,o));
 });
 return {
  isReady:()=>repository.ready(),command,
  capabilities:(token,m)=>repository.transaction(token,async(c,a)=>({roles:await roles(c,a,m),synthetic:true})),
  queue:(token,m,status=null)=>repository.transaction(token,async(c,a)=>{await requireRole(c,a,m);if(status!==null&&!states.includes(status))fail('invalid_field','Invalid review status.');const ids=await rows(c,'SELECT o.id FROM mission_observations o JOIN mission_bookings b ON b.id=o.booking_id JOIN missions m ON m.id=b.mission_id WHERE m.municipality_id=$1 ORDER BY o.submitted_at,o.id',[m]);const items=[];for(const {id} of ids){const o=await observation(c,id,m);if(!status||o.status===status)items.push(await live(c,o,o.assigned_to===a));}return {items};}),
  detail:(token,m,id)=>repository.transaction(token,async(c,a)=>{await requireRole(c,a,m);const o=await observation(c,id,m);await conflict(c,a,o);if(o.assigned_to!==a)fail('review_forbidden','Assigned operator required for private case.',403);return live(c,o);}),
  own:(token,id)=>repository.transaction(token,async(c,a)=>{const o=await observation(c,id);if(o.account_id!==a)fail('observation_not_found','Private observation not found.',404);return live(c,o);}),
  xp:(token)=>repository.transaction(token,async(c,a)=>{const events=await rows(c,'SELECT * FROM xp_ledger WHERE account_id=$1 ORDER BY awarded_at,id',[a]);return {balance:events.reduce((n,e)=>n+e.amount,0),items:events.map(e=>({id:e.id,observationId:e.observation_id,placeId:e.place_id,windowId:e.window_id,amount:e.amount,awardedAt:iso(e.awarded_at),ruleVersion:e.rule_version,replicationRequestId:e.replication_request_id}))};}),
  proof:(token,m,id)=>repository.transaction(token,async(c,a)=>{uuid(id);await requireRole(c,a,m);const u=await one(c,`SELECT u.* FROM mission_uploads u JOIN mission_observations o ON o.booking_id=u.booking_id JOIN observation_reviews r ON r.observation_id=o.id JOIN mission_bookings b ON b.id=o.booking_id JOIN missions m ON m.id=b.mission_id WHERE u.id=$1 AND m.municipality_id=$2 AND r.assigned_to=$3 AND (u.id=ANY(o.proof_ids) OR EXISTS(SELECT 1 FROM observation_supplements s WHERE s.observation_id=o.id AND s.proofs @> jsonb_build_array(jsonb_build_object('id',u.id)))) AND u.status='complete' AND u.expires_at>$4`,[id,m,a,iso(clock())]);if(!u||!u.file_key)fail('proof_not_found','Private proof unavailable.',404);const o=await one(c,'SELECT account_id,mission_id FROM mission_bookings WHERE id=$1',[u.booking_id]);await conflict(c,a,o);const bytes=await storage.get(u.file_key);return {...upload(u),sha256:hash(bytes),sanitizedBytes:bytes.length,dataBase64:bytes.toString('base64')};}),
  createUpload:(token,id,body)=>repository.transaction(token,async(c,a)=>{
   exact(body,['integrationRequestId','mimeType','totalBytes','synthetic','idempotencyKey']);key(body.idempotencyKey);uuid(body.integrationRequestId);
   const o=await observation(c,id);if(o.account_id!==a)fail('observation_not_found','Private observation not found.',404);
   const i=await one(c,'SELECT * FROM integration_requests WHERE id=$1 AND observation_id=$2 FOR UPDATE',[body.integrationRequestId,id]);
   const r=await replay(c,a,body,[id,'integration-upload']);if(r.prior)return r.prior.response;
   if(!i||i.status!=='open'||o.status!=='needsIntegration'||clock()>=Date.parse(i.due_at))fail('integration_closed','Active integration request required.',409);
   if(body.mimeType!=='image/png'||body.synthetic!==true)fail('proof_invalid','Synthetic PNG required.');if(!Number.isInteger(body.totalBytes)||body.totalBytes<1||body.totalBytes>2097152)fail('proof_too_large','Proof exceeds bounds.');
   if((await one(c,'SELECT count(*)::int AS n FROM mission_uploads WHERE integration_request_id=$1',[i.id])).n>=3)fail('upload_limit','At most three photos per integration.',409);
   const u=await one(c,"INSERT INTO mission_uploads(id,booking_id,command_key,mime_type,total_bytes,status,created_at,expires_at,integration_request_id) VALUES($1,$2,$3,'image/png',$4,'uploading',$5,$6,$7) RETURNING *",[randomUUID(),o.booking_id,body.idempotencyKey,body.totalBytes,iso(clock()),iso(clock()+retentionDays*86400000),i.id]);return remember(c,a,body,r,upload(u));
  }),
  supplement:(token,id,body)=>repository.transaction(token,async(c,a)=>{
   exact(body,['expectedRevision','idempotencyKey','integrationRequestId','notes','proofIds']);key(body.idempotencyKey);revision(body.expectedRevision);uuid(body.integrationRequestId);
   const o=await observation(c,id);if(o.account_id!==a)fail('observation_not_found','Private observation not found.',404);const r=await replay(c,a,body,[id,'supplement']);if(r.prior)return r.prior.response;
   if(o.revision!==body.expectedRevision)fail('review_revision_conflict','Observation revision changed.',409);
   const i=await one(c,'SELECT * FROM integration_requests WHERE id=$1 AND observation_id=$2 FOR UPDATE',[body.integrationRequestId,id]);if(!i||i.status!=='open'||o.status!=='needsIntegration'||clock()>=Date.parse(i.due_at))fail('integration_closed','Integration request closed.',409);
   if(typeof body.notes!=='string'||body.notes.length>1000||!Array.isArray(body.proofIds)||body.proofIds.length>3||new Set(body.proofIds).size!==body.proofIds.length)fail('invalid_field','Invalid supplement.');body.proofIds.forEach(uuid);if(!body.notes.trim()&&!body.proofIds.length)fail('invalid_field','Supplement requires notes or proofs.');
   const proofs=await rows(c,"SELECT * FROM mission_uploads WHERE integration_request_id=$1 AND booking_id=$2 AND id=ANY($3::uuid[]) AND status='complete' AND expires_at>$4",[i.id,o.booking_id,body.proofIds,iso(clock())]);if(proofs.length!==body.proofIds.length)fail('proof_invalid','Proof must belong to this author integration.');
   await c.query('INSERT INTO observation_supplements VALUES($1,$2,$3,$4,$5,$6)',[randomUUID(),id,i.id,body.notes,JSON.stringify(proofs.map(proof)),iso(clock())]);await c.query("UPDATE integration_requests SET status='answered',revision=revision+1 WHERE id=$1",[i.id]);await update(c,o,'screened');await audit(c,o,a,'supplement_submitted',body.notes);return remember(c,a,body,r,await live(c,o));
  }),
  replication:(token,id)=>repository.transaction(token,async(c,a)=>{uuid(id);const r=await one(c,'SELECT r.*,b.id AS booking_id FROM replication_requests r LEFT JOIN mission_bookings b ON b.replication_request_id=r.id WHERE r.id=$1 AND r.account_id=$2',[id,a]);if(!r)fail('observation_not_found','Private replication request not found.',404);return replication(r);}),
  bookReplica:(token,id,body)=>repository.transaction(token,async(c,a)=>{
   exact(body,['idempotencyKey']);key(body.idempotencyKey);uuid(id);const request=await one(c,'SELECT * FROM replication_requests WHERE id=$1 AND account_id=$2 FOR UPDATE',[id,a]);if(!request)fail('observation_not_found','Private replication request not found.',404);
   const r=await replay(c,a,body,[id,'replication-booking']);if(r.prior)return r.prior.response;
   const w=await one(c,'SELECT * FROM mission_windows WHERE id=$1 FOR UPDATE',[request.window_id]);const now=clock();if(request.status!=='open'||now>=Date.parse(request.due_at)||now<Date.parse(w.starts_at)||now>=Date.parse(w.ends_at))fail('replication_closed','Replication request closed.',409);
   await c.query("UPDATE mission_bookings SET status='expired',revision=revision+1 WHERE status='active' AND expires_at<=$1",[iso(now)]);
   if((await one(c,"SELECT count(*)::int AS n FROM mission_bookings WHERE window_id=$1 AND status IN('active','submitted')",[w.id])).n>=w.capacity)fail('mission_full','No slots available.',409);
   const protocol=await one(c,'SELECT protocol FROM missions WHERE id=$1',[request.mission_id]);if(protocol.protocol.version!==request.protocol_version)fail('replication_closed','Replication protocol changed.',409);
   const b=await one(c,"INSERT INTO mission_bookings(id,mission_id,window_id,account_id,command_key,protocol_version,status,expires_at,revision,created_at,replication_request_id) VALUES($1,$2,$3,$4,$5,$6,'active',$7,1,$8,$9) RETURNING *",[randomUUID(),request.mission_id,w.id,a,body.idempotencyKey,request.protocol_version,iso(Math.min(now+1800000,Date.parse(w.ends_at),Date.parse(request.due_at))),iso(now),id]);await c.query("UPDATE replication_requests SET status='booked' WHERE id=$1",[id]);return remember(c,a,body,r,booking(b));
  }),
 };
}
