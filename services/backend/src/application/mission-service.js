import { randomUUID } from 'node:crypto';
import { exact,key,revision,uuid,hash,sanitizePng,fail } from '../domain/missions/rules.js';
const iso=value=>new Date(value).toISOString();
export function createMissionService({repository,storage,clock=Date.now,retentionDays,onCheckpoint=async()=>{}}){
 if(storage?.kind!=='local-synthetic'||!Number.isInteger(retentionDays)||retentionDays<1||retentionDays>30)throw new TypeError('Explicit local synthetic proof storage and retentionDays 1–30 required.');
 const q=(c,op,args)=>repository.query(op,args,c),one=async(c,op,args)=>(await q(c,op,args)).rows[0];
 const mission=row=>({id:row.id,placeId:row.place_id??null,municipalityId:row.municipality_id,zoneId:row.zone_id,title:row.title,area:row.area,protocol:row.protocol,windowId:row.window_id,startsAt:iso(row.starts_at),endsAt:iso(row.ends_at),durationMinutes:row.duration_minutes,availableSlots:Math.max(0,row.capacity-row.used),rewardXp:10,synthetic:true});
 const booking=row=>({id:row.id,missionId:row.mission_id,windowId:row.window_id,protocolVersion:row.protocol_version,status:row.status,expiresAt:iso(row.expires_at),revision:row.revision,replicationRequestId:row.replication_request_id??null});
 const upload=row=>({id:row.id,bookingId:row.booking_id,mimeType:row.mime_type,totalBytes:row.total_bytes,receivedBytes:row.received_bytes,status:row.status,revision:row.revision,expiresAt:iso(row.expires_at),...(row.width?{width:row.width,height:row.height,sha256:row.sha256,sanitizedBytes:row.sanitized_bytes}:{})});
 async function ownBooking(c,account,id,active=false){uuid(id);const row=await one(c,'booking',[id,account]);if(!row)fail('booking_not_found','Booking not found.',404);if(active&&(row.status!=='active'||Date.parse(row.expires_at)<=clock()))fail('booking_expired','An active booking is required.',409);return row;}
 async function ownUpload(c,account,id){uuid(id);const row=await one(c,'upload',[id,account]);if(!row||Date.parse(row.expires_at)<=clock())fail('upload_not_found','Private upload unavailable.',404);return row;}
 async function activeUpload(c,account,row){
  if(!row.integration_request_id)return ownBooking(c,account,row.booking_id,true);
  const result=await c.query("SELECT i.*,r.status AS review_status FROM integration_requests i JOIN observation_reviews r ON r.observation_id=i.observation_id JOIN mission_observations o ON o.id=i.observation_id JOIN mission_bookings b ON b.id=o.booking_id WHERE i.id=$1 AND b.id=$2 AND b.account_id=$3 FOR UPDATE OF i,r",[row.integration_request_id,row.booking_id,account]);
  const i=result.rows[0];if(!i||i.status!=='open'||i.review_status!=='needsIntegration'||Date.parse(i.due_at)<=clock())fail('integration_closed','Active integration request required.',409);
 }
 const service={
 isReady:()=>repository.ready(),
 async catalog(municipalityId,zoneId=null){return {items:(await repository.query('catalog',[municipalityId,iso(clock()),zoneId])).rows.map(mission)};},
 async detail(municipalityId,missionId){const row=await one(undefined,'detail',[municipalityId,missionId,iso(clock())]);if(!row)fail('mission_not_found','Mission not found.',404);return {mission:mission(row)};},
 book:(token,municipalityId,missionId,body)=>repository.transaction(token,async(c,account)=>{
  exact(body,['windowId','idempotencyKey']);key(body.idempotencyKey);if(typeof body.windowId!=='string')fail('invalid_field','windowId required.');
  const w=await one(c,'lockWindow',[body.windowId,missionId,municipalityId]);if(!w)fail('mission_not_found','Mission window not found.',404);
  const now=clock();await q(c,'expire',[iso(now)]);
  const prior=await one(c,'priorBooking',[account,body.idempotencyKey]);if(prior){if(prior.mission_id!==missionId||prior.window_id!==body.windowId)fail('idempotency_conflict','Booking key used for another scope.',409);return booking(prior);}
  if(now<Date.parse(w.starts_at)||now>=Date.parse(w.ends_at))fail('mission_window_closed','Mission window is closed.',409);
  const active=await one(c,'activeBooking',[account,missionId,municipalityId,iso(clock())]);if(active&&active.window_id===body.windowId)fail('booking_exists','Recover the existing booking before starting another command.',409);
  if((await one(c,'countBookings',[w.id])).n>=w.capacity)fail('mission_full','No slots available.',409);
  const row=await one(c,'insertBooking',[randomUUID(),missionId,w.id,account,body.idempotencyKey,w.protocol.version,iso(Math.min(now+30*60000,Date.parse(w.ends_at))),iso(now)]);await onCheckpoint('booking_before_commit');return booking(row);
 }),
 current:(token,municipalityId,missionId)=>repository.transaction(token,async(c,account)=>{await q(c,'expire',[iso(clock())]);const row=await one(c,'activeBooking',[account,missionId,municipalityId,iso(clock())]);return {booking:row?booking(row):null};}),
 getBooking:(token,id)=>repository.transaction(token,async(c,account)=>{await q(c,'expire',[iso(clock())]);return booking(await ownBooking(c,account,id));}),
 release:(token,id,body)=>repository.transaction(token,async(c,account)=>{exact(body,['expectedRevision']);revision(body.expectedRevision);const row=await ownBooking(c,account,id);if(row.status==='released')return booking(row);if(row.revision!==body.expectedRevision)fail('booking_revision_conflict','Booking revision changed.',409);if(row.status==='submitted')fail('booking_submitted','Submitted booking cannot be released.',409);return booking(await one(c,'release',[id]));}),
 createUpload:(token,id,body)=>repository.transaction(token,async(c,account)=>{
  exact(body,['mimeType','totalBytes','synthetic','idempotencyKey']);key(body.idempotencyKey);await ownBooking(c,account,id,true);
  if(body.mimeType!=='image/png'||body.synthetic!==true)fail('proof_invalid','Local synthetic PNG required.');if(!Number.isInteger(body.totalBytes)||body.totalBytes<1||body.totalBytes>2097152)fail('proof_too_large','Proof must be 1 byte to 2 MiB.');
  const prior=await one(c,'priorUpload',[id,body.idempotencyKey]);if(prior){if(prior.total_bytes!==body.totalBytes||prior.mime_type!==body.mimeType)fail('idempotency_conflict','Upload key used for different metadata.',409);return upload(prior);}
  if((await one(c,'uploadCount',[id])).n>=3)fail('upload_limit','At most three photos per booking.',409);
  return upload(await one(c,'insertUpload',[randomUUID(),id,body.idempotencyKey,body.totalBytes,iso(clock()),iso(clock()+retentionDays*86400000)]));
 }),
 getUpload:(token,id)=>repository.transaction(token,async(c,account)=>upload(await ownUpload(c,account,id))),
 chunk:(token,id,body)=>repository.transaction(token,async(c,account)=>{
  exact(body,['offset','dataBase64']);const row=await ownUpload(c,account,id);await activeUpload(c,account,row);
  if(!Number.isInteger(body.offset)||body.offset<0||typeof body.dataBase64!=='string'||body.dataBase64.length>43692||!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(body.dataBase64))fail('invalid_field','Invalid bounded base64 chunk.');
  const bytes=Buffer.from(body.dataBase64,'base64');if(bytes.length<1||bytes.length>32768)fail('proof_too_large','Chunk exceeds 32 KiB.');
  const prior=row.chunks.find(v=>v.offset===body.offset);if(prior){if(prior.sha256!==hash(bytes))fail('upload_offset_conflict','Offset contains different bytes.',409);return upload(row);}
  if(row.status!=='uploading'||body.offset!==row.received_bytes)fail('upload_offset_conflict','Resume from confirmed receivedBytes.',409);if(row.received_bytes+bytes.length>row.total_bytes)fail('proof_too_large','Chunk exceeds declared total.');
  if(row.chunks.length>=128)fail('upload_chunk_limit','At most 128 chunks per proof.',409);
  const fileKey=await storage.put(bytes),chunks=[...row.chunks,{offset:body.offset,size:bytes.length,key:fileKey,sha256:hash(bytes)}];
  await activeUpload(c,account,row);
  return upload(await one(c,'append',[id,row.received_bytes+bytes.length,JSON.stringify(chunks)]));
 }),
 complete:async(token,id)=>{let chunks=[];const result=await repository.transaction(token,async(c,account)=>{
  const row=await ownUpload(c,account,id);if(row.status==='complete')return upload(row);await activeUpload(c,account,row);if(row.received_bytes!==row.total_bytes)fail('upload_incomplete','Upload incomplete.',409);
  const buffers=[];for(const chunk of row.chunks)buffers.push(await storage.get(chunk.key));const proof=sanitizePng(Buffer.concat(buffers));
  const fileKey=await storage.put(proof.bytes);await activeUpload(c,account,row);chunks=row.chunks.map(v=>v.key);return upload(await one(c,'complete',[id,fileKey,proof.width,proof.height,proof.sha256,proof.bytes.length]));
 });
  // Remove raw metadata-bearing staging chunks only after the DB commit.
  // Failed cleanup cannot invalidate an accepted finalized proof; phase 8 sweeps orphans.
  for(const chunk of chunks){try{await storage.delete(chunk);}catch{}}
  return result;
 },
 proof:(token,id)=>repository.transaction(token,async(c,account)=>{const row=await ownUpload(c,account,id);if(row.status!=='complete')fail('upload_incomplete','Proof not finalized.',409);const bytes=await storage.get(row.file_key);return {...upload(row),sha256:hash(bytes),sanitizedBytes:bytes.length,dataBase64:bytes.toString('base64')};}),
 submit:(token,id,body)=>repository.transaction(token,async(c,account)=>{
  exact(body,['idempotencyKey','expectedRevision','protocolVersion','answer','notes','proofIds','measurement']);key(body.idempotencyKey);revision(body.expectedRevision);
  const row=await ownBooking(c,account,id),requestHash=hash(JSON.stringify([body.idempotencyKey,body.expectedRevision,body.protocolVersion,body.answer,body.notes,body.proofIds,...(Object.hasOwn(body,'measurement')?[body.measurement]:[])])),prior=await one(c,'priorObservation',[id]);
  if(prior){if(prior.command_key!==body.idempotencyKey||prior.request_hash!==requestHash)fail('idempotency_conflict','Observation was already submitted.',409);return prior.receipt;}
  await ownBooking(c,account,id,true);if(row.revision!==body.expectedRevision)fail('booking_revision_conflict','Booking revision changed.',409);if(body.protocolVersion!==row.protocol_version||body.protocolVersion!==row.protocol.version)fail('protocol_version_conflict','Protocol version changed.',409);
  if(!['noIssue','nonObservable','unsure','visibleWaste'].includes(body.answer)||typeof body.notes!=='string'||body.notes.length>1000||!Array.isArray(body.proofIds)||body.proofIds.length>3||new Set(body.proofIds).size!==body.proofIds.length||body.proofIds.some(v=>typeof v!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(v)))fail('invalid_field','Invalid questionnaire or proof identifiers.');
  const definition=row.protocol.measurementDefinition;let measurement;
  if(definition){
   if(['nonObservable','unsure'].includes(body.answer)){if(body.measurement!==undefined&&body.measurement!==null)fail('invalid_field','Unknown or non observable is not a numeric zero.');}
   else {exact(body.measurement,['value']);const value=body.measurement.value;if(typeof value!=='number'||!Number.isFinite(value)||Math.abs(value)>1e9||value<definition.minValue||value>definition.maxValue||definition.integerOnly&&!Number.isInteger(value))fail('invalid_field','Measurement is outside the protocol bounds.');measurement={value,unit:definition.unit,indicator:definition.indicator,protocolId:definition.protocolId,protocolVersion:definition.protocolVersion,recordedAt:iso(clock())};}
  }else if(body.measurement!==undefined&&body.measurement!==null)fail('invalid_field','This mission has no numeric measurement protocol.');
  const proofs=(await q(c,'proofs',[id,body.proofIds,iso(clock())])).rows;if(proofs.length!==body.proofIds.length)fail('proof_invalid','Private finalized proof from this booking required.');
  if(['noIssue','visibleWaste'].includes(body.answer)&&proofs.length<row.protocol.minPhotos)fail('proof_required','Repeatable photo required.');
  if(Date.parse(row.expires_at)<=clock())fail('booking_expired','Booking expired before submission.',409);
  const receipt={id:randomUUID(),bookingId:id,missionId:row.mission_id,municipalityId:row.municipality_id,windowId:row.window_id,protocolVersion:row.protocol_version,status:'pendingReview',answer:body.answer,submittedAt:iso(clock()),xpAwarded:0,proofIds:body.proofIds,...(measurement?{measurement}:{}),...(row.replication_request_id?{replicationRequestId:row.replication_request_id}:{}),proofs:proofs.map(p=>({id:p.id,sha256:p.sha256,sizeBytes:p.sanitized_bytes,mimeType:p.mime_type,width:p.width,height:p.height}))};
  await c.query("INSERT INTO mission_places SELECT id,municipality_id||':area:'||md5(area::text) FROM missions WHERE id=$1 ON CONFLICT DO NOTHING",[row.mission_id]);
  await q(c,'insertObservation',[receipt.id,id,body.idempotencyKey,requestHash,JSON.stringify(receipt),body.answer,body.notes,body.proofIds,receipt.submittedAt]);await c.query('INSERT INTO observation_reviews(observation_id,place_id) SELECT $1,COALESCE(r.place_id,p.place_id) FROM mission_places p LEFT JOIN replication_requests r ON r.id=$3 WHERE p.mission_id=$2',[receipt.id,row.mission_id,row.replication_request_id??null]);await q(c,'submitBooking',[id]);await onCheckpoint('observation_before_commit');return receipt;
 }),
 receipt:(token,id,commandKey)=>repository.transaction(token,async(c,account)=>{key(commandKey);uuid(id);const row=await one(c,'receipt',[id,account,commandKey]);if(!row)fail('receipt_not_found','Receipt not found.',404);return row.receipt;}),
 purgeExpired:(token)=>repository.transaction(token,async(c,account)=>{const rows=(await q(c,'expiredUploads',[iso(clock()),account])).rows;for(const row of rows){for(const chunk of row.chunks)await storage.delete(chunk.key);if(row.file_key)await storage.delete(row.file_key);await q(c,'deleteUploadBytes',[row.id]);}return {purged:rows.length};}),
 };
 return service;
}
