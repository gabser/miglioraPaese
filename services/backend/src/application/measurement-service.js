import {randomUUID} from 'node:crypto';
import {key,revision,uuid,hash} from '../domain/missions/rules.js';
import {iso,fail,exact,text,numeric,date,ids,sourceSummary,direction,evidence,evidenceFields,verdict} from '../domain/measurements/rules.js';
const emptyEvidence={afterValue:null,measuredAt:null,sourceIds:[],approvedObservationIds:[],interventionIds:[],rationale:'Deadline pubblicata scaduta: evidenze insufficienti.'};
const definitionFields=['problemId','seasonId','matchdayId','cardId','missionIds','indicator','unit','threshold','lowerIsBetter','instructions','observationStartsAt','observationEndsAt','declaredDeadline','measurementDefinition'];
const verdictFields=['disposition','observed','rationale','undeterminableReason'];
export function createMeasurementService({repository,fantasy,storage,clock=Date.now,cooperationEvents,onCheckpoint=async()=>{}}){
 const one=repository.one,many=repository.many;
 const raw=(c,operation,args=[])=>repository.many(c,operation,args);
 const rawOne=(c,operation,args=[])=>repository.one(c,operation,args);
 const now=()=>iso(clock());
 async function supervisor(c,a,m){if(!a||!await one(c,'role',[a,m]))fail('measurements_forbidden','Municipality outcomesSupervisor role required.',403);}
 async function conflict(c,a,scope,authors=[]){if(!a)return;if(authors.includes(a))fail('self_review','Authors cannot validate their own evidence.',403);if(await one(c,'conflict',[a,scope.seasonId,scope.matchdayId,scope.cardId]))fail('competitive_conflict','Supervisor competes on this card.',403);}
 async function scope(c,m,query={}){
  if((query.seasonId==null)!==(query.matchdayId==null))fail('invalid_field','seasonId and matchdayId must be selected together.');
  const season=await fantasy.teams.seasonFor(m,query.seasonId??null),day=await fantasy.teams.dayFor(season.id,query.matchdayId??null,now());
  return {municipalityId:m,seasonId:season.id,matchdayId:day.id};
 }
 async function source(c,id,m){text(id,'sourceId');const row=await one(c,'source',[id,m]);if(!row)fail('source_not_authorized','Registered scoped source required.',409);return row;}
 async function evaluation(c,id,m){uuid(id);const row=await one(c,'evaluation',[id,m]);if(!row)fail('evaluation_not_found','Evaluation not found.',404);return row;}
 const scopeOf=e=>({seasonId:e.season_id,matchdayId:e.matchday_id,cardId:e.card_id});
 async function publications(c,id){return (await many(c,'publications',[id])).map(r=>r.payload);}
 async function protocol(c,id,version,m){uuid(id);revision(version);const p=await one(c,'protocol',[id,version]);if(!p||p.payload.municipalityId!==m)fail('protocol_not_found','Protocol not found.',404);return p.payload;}
 async function observations(c,p){return (await many(c,'observations',[p.municipalityId,p.baselineSnapshot.placeId])).filter(o=>{
  const q=o.receipt.measurement;return q&&q.protocolId===p.id&&q.protocolVersion===p.version&&q.indicator===p.indicator&&q.unit===p.unit&&Date.parse(q.recordedAt)>=Date.parse(p.observationStartsAt)&&Date.parse(q.recordedAt)<=Date.parse(p.observationEndsAt)&&p.missionIds.includes(o.mission_id);
 });}
 async function proofValid(c,o){
  const ids=[...(o.receipt.proofIds??[])];const extras=await raw(c,'statement_01',[o.id]);for(const s of extras)ids.push(...s.proofs.map(p=>p.id));
  if(!ids.length)return true;
  const rows=await raw(c,'statement_02',[ids,now()]);return rows.length===new Set(ids).size;
 }
 async function validateEvidence(c,a,m,p,d,determinate=false){
  const sources=[];for(const id of d.sourceIds){const s=await source(c,id,m);if(s.place_id!==p.baselineSnapshot.placeId||s.indicator!==p.indicator||s.unit!==p.unit||Date.parse(s.measured_at)<Date.parse(p.observationStartsAt)||Date.parse(s.measured_at)>Date.parse(p.observationEndsAt)||Date.parse(s.measured_at)>clock())fail('incomparable_evidence','Source is outside the declared protocol.',409);sources.push(s);}
  for(const id of d.interventionIds){uuid(id);const i=await one(c,'intervention',[id,m]);if(!i||!i.payload.problemIds.includes(p.problemId))fail('incomparable_evidence','Intervention must be linked to this problem.',409);}
  const all=await observations(c,p),selected=all.filter(o=>d.approvedObservationIds.includes(o.id));
  if(selected.length!==d.approvedObservationIds.length)fail('incomparable_evidence','Approved quantitative observations bound to the protocol are required.',409);
  // Every available pertinent observation participates in contradiction checks;
  // selecting two matching records cannot hide a third contradictory value.
  await conflict(c,a,{seasonId:p.seasonId,matchdayId:p.matchdayId,cardId:p.cardId},selected.map(o=>o.account_id));
  for(const o of selected)if(!await proofValid(c,o))fail('evidence_expired','Selected evidence retention expired.',409);
  if(d.afterValue!==null){numeric(d.afterValue,'afterValue');if(d.measuredAt===null)fail('invalid_field','Measurement time required.');const at=Date.parse(date(d.measuredAt,'measuredAt'));if(at<Date.parse(p.observationStartsAt)||at>Date.parse(p.observationEndsAt)||at>clock())fail('incomparable_evidence','Measurement time is outside protocol.',409);}
  const documentary=await raw(c,'statement_03',[m,p.baselineSnapshot.placeId,p.indicator,p.unit,p.observationStartsAt,p.observationEndsAt,now()]);
  const comparable=[];for(const o of all)if(await proofValid(c,o))comparable.push(o);
  const values=[...documentary.map(s=>Number(s.value)),...comparable.map(o=>o.receipt.measurement.value)];
  if(determinate){
   if(d.afterValue===null||d.measuredAt===null)fail('insufficient_evidence','Quantitative evidence is required.',409);
   if(values.some(v=>v!==d.afterValue))fail('contradictory_evidence','Pertinent evidence disagrees; new verification or undeterminable is required.',409);
   const docs=sources.filter(s=>Number(s.value)===d.afterValue&&iso(s.measured_at)===iso(d.measuredAt));
   const independent=new Set(selected.filter(o=>o.receipt.measurement.value===d.afterValue).map(o=>o.account_id));
   if(!docs.length&&independent.size<2)fail('insufficient_evidence','Authorized document OR two independent quantitative accounts required.',409);
   if(!docs.length&&!selected.some(o=>iso(o.receipt.measurement.recordedAt)===iso(d.measuredAt)))fail('incomparable_evidence','Measurement time must match a selected observation.',409);
  }
  const supplements=new Map();for(const o of selected)supplements.set(o.id,(await raw(c,'statement_01',[o.id])).flatMap(r=>r.proofs));
  return {sources:sources.map(sourceSummary),observations:selected.map(o=>({id:o.id,authorId:o.account_id,measurement:o.receipt.measurement,receiptDigest:hash(JSON.stringify(o.receipt)),proofs:[...(o.receipt.proofs??[]),...(supplements.get(o.id)??[])]}))};
 }
 async function audit(c,e,a,action,details={}){await repository.query(c,'statement_04',[randomUUID(),e?.id??null,a,a?'human':'systemDeadline',now(),action,e?.revision??1,JSON.stringify(details)]);}
 async function saveEvaluation(c,e){await repository.query(c,'statement_05',[e.id,JSON.stringify(e.payload),e.revision,e.protocol_id,e.protocol_version]);}
 async function publish(c,a,e,d,v,origin='human'){
  const history=await publications(c,e.id),previous=history.at(-1);
  const p=e.protocol_id?await protocol(c,e.protocol_id,e.protocol_version,e.municipality_id):null;
  let frozen={sources:[],observations:[]};if(p)frozen=await validateEvidence(c,a,e.municipality_id,p,d,v.disposition==='determinate');
  else if(v.disposition==='determinate')fail('missing_baseline','A published protocol and baseline are required.',409);
  if(v.disposition==='determinate'&&direction(p.baselineSnapshot.value,d.afterValue,p.threshold,p.lowerIsBetter)!==v.observed)fail('direction_mismatch','Direction must match the numeric protocol comparison.',409);
  const day=await fantasy.teams.dayFor(e.season_id,e.matchday_id,now());if(origin==='human'&&clock()<Date.parse(day.observation_ends_at))fail('observation_pending','Observation window has not ended.',409);
  e.revision++;e.payload={...e.payload,...d,revision:e.revision,status:'published'};await saveEvaluation(c,e);
  const result={id:e.id,placeId:p?.baselineSnapshot.placeId??null,version:(previous?.version??0)+1,revision:e.revision,seasonId:e.season_id,matchdayId:e.matchday_id,cardId:e.card_id,protocolId:e.protocol_id,protocolVersion:e.protocol_version,disposition:v.disposition,observed:v.observed,baselineValue:p?.baselineSnapshot.value??null,afterValue:d.afterValue,unit:p?.unit??null,measuredAt:d.measuredAt,sources:frozen.sources,interventionIds:d.interventionIds,rationale:v.rationale,undeterminableReason:v.undeterminableReason,publishedAt:now(),supersedesVersion:previous?.version??null,origin};
  await repository.query(c,'statement_06',[e.id,result.version,JSON.stringify(result),JSON.stringify(frozen)]);
  const outcome={...result,matchdayId:e.matchday_id,rulesVersion:'fantasy-v2',publicationId:e.id};
  await repository.query(c,'statement_07',[e.season_id,e.matchday_id,e.card_id,JSON.stringify(outcome)]);
  await audit(c,e,a,origin==='deadline'?'deadline':'publication',{version:result.version,evidence:frozen});
  await fantasy.results.recalculate(e.season_id,e.matchday_id);
  await cooperationEvents?.published(c,e,result,p?.baselineSnapshot.placeId??null);
  await onCheckpoint('measurement_before_commit');return result;
 }
 async function reconcile(c){
  const expired=await raw(c,'statement_08',[now()]);
  if(!expired.length)return;
  await fantasy.teams.reconcile();
  for(const d of expired){let e=await rawOne(c,'statement_09',[d.season_id,d.matchday_id,d.card_id]);
   if(!e){const p=await rawOne(c,'statement_10',[d.season_id,d.matchday_id,d.card_id]);const id=randomUUID();const draft={id,municipalityId:d.municipality_id,protocolId:p?.id??null,protocolVersion:p?.version??null,seasonId:d.season_id,matchdayId:d.matchday_id,cardId:d.card_id,revision:1,status:'draft',...emptyEvidence};e=(await raw(c,'statement_11',[id,d.municipality_id,d.season_id,d.matchday_id,d.card_id,p?.id??null,p?.version??null,JSON.stringify(draft)]))[0];}
   await publish(c,null,e,emptyEvidence,{disposition:'undeterminable',observed:null,rationale:emptyEvidence.rationale,undeterminableReason:'deadlineExpired'},'deadline');
  }
 }
 const run=(token,action)=>repository.transaction(token,async(c,a)=>{await reconcile(c);return action(c,a);});
 async function currentWorkspace(c,a,m,e){await conflict(c,a,scopeOf(e));const p=e.protocol_id?await protocol(c,e.protocol_id,e.protocol_version,m):null;const selected=p?(await observations(c,p)).filter(o=>(e.payload.approvedObservationIds??[]).includes(o.id)):[];await conflict(c,a,scopeOf(e),selected.map(o=>o.account_id));const h=await publications(c,e.id);const frozen=await many(c,'publications',[e.id]);await conflict(c,a,scopeOf(e),frozen.flatMap(r=>r.evidence.observations.map(o=>o.authorId)));const currentEvidence=[];if(e.payload.status==='draft'){for(const o of selected){const supplements=await raw(c,'statement_01',[o.id]);currentEvidence.push({id:o.id,authorId:o.account_id,measurement:o.receipt.measurement,proofs:[...(o.receipt.proofs??[]),...supplements.flatMap(s=>s.proofs)]});}}else for(const publication of frozen)currentEvidence.push(...publication.evidence.observations);return {draft:e.payload.status==='draft'?e.payload:null,currentPublished:h.at(-1)??null,history:h,appeals:(await many(c,'appeals',[e.id])).map(a=>a.payload),evidence:{draft:e.payload,observations:currentEvidence,published:frozen.map(r=>({version:r.version,...r.evidence}))}};}
 async function remember(c,a,b,requestHash,response){await repository.query(c,'remember',[a,b.idempotencyKey,requestHash,JSON.stringify(response)]);return response;}
 async function command(token,m,action,id,body){return run(token,async(c,a)=>{
  if(action==='updates')uuid(id);if(action==='resolutions')uuid(id.appealId);
  key(body?.idempotencyKey);const appealAction=action==='appeals';if(!appealAction)await supervisor(c,a,m);
  const requestHash=hash(JSON.stringify([m,action,id,Object.keys(body).sort().map(k=>[k,body[k]])]));
  // Authorization is current on retries; saved snapshot precedes CAS.
  const prior=await one(c,'prior',[a,body.idempotencyKey]);if(prior&&prior.request_hash!==requestHash)fail('idempotency_conflict','Key already used for another command.',409);
  let e=null;if(['draft-updates','publications','corrections','appeals','resolutions'].includes(action)){e=await evaluation(c,action==='resolutions'?id.evaluationId:id,m);if(!appealAction)await currentWorkspace(c,a,m,e);}
  if(prior)return prior.response;
  if(!['problems','protocol-versions','interventions','evaluations'].includes(action)){revision(body.expectedRevision);const entityRevision=e?.revision;if(entityRevision!==undefined&&action!=='resolutions'&&entityRevision!==body.expectedRevision)fail('measurement_revision_conflict','Evaluation revision changed.',409);}
  let result;
  if(action==='problems'){
   exact(body,['idempotencyKey','title','placeId','baseline']);text(body.title,'title',200);text(body.placeId,'placeId');exact(body.baseline,['value','unit','measuredAt','sourceId']);numeric(body.baseline.value,'baseline.value');text(body.baseline.unit,'unit',64);date(body.baseline.measuredAt,'measuredAt');const s=await source(c,body.baseline.sourceId,m);
   if(s.place_id!==body.placeId||s.unit!==body.baseline.unit||Number(s.value)!==body.baseline.value||iso(s.measured_at)!==iso(body.baseline.measuredAt)||Date.parse(s.measured_at)>clock())fail('incomparable_evidence','Baseline must match its immutable source.',409);
   result={id:randomUUID(),municipalityId:m,placeId:body.placeId,title:body.title.trim(),baseline:{value:body.baseline.value,unit:body.baseline.unit,measuredAt:iso(s.measured_at),source:sourceSummary(s)},revision:1,publishedAt:now()};await repository.query(c,'statement_12',[result.id,m,result.placeId,JSON.stringify(result)]);await audit(c,null,a,'problem',{problemId:result.id});
  }else if(action==='protocol-versions'){
   exact(body,['idempotencyKey','expectedRevision',...definitionFields]);revision(body.expectedRevision);uuid(id);if(body.problemId!==id)fail('invalid_field','Problem mismatch.');const problem=await one(c,'problem',[id,m]);if(!problem)fail('not_found','Problem not found.',404);if(problem.revision!==body.expectedRevision)fail('measurement_revision_conflict','Problem revision changed.',409);
   text(body.seasonId,'seasonId');text(body.matchdayId,'matchdayId');text(body.cardId,'cardId');text(body.indicator,'indicator');text(body.unit,'unit',64);numeric(body.threshold,'threshold');if(body.threshold<0||typeof body.lowerIsBetter!=='boolean')fail('invalid_field','Invalid tolerance or direction.');ids(body.missionIds,'missionIds');if(!Array.isArray(body.instructions)||!body.instructions.length||body.instructions.length>20)fail('invalid_field','Instructions required.');body.instructions.forEach(i=>text(i,'instructions',1000));
   const s=await scope(c,m,body),day=await fantasy.teams.dayFor(s.seasonId,s.matchdayId,now());if(day.rules_version!=='fantasy-v2')fail('rules_version_conflict','New protocols require a v2 season.',409);await conflict(c,a,body);
   if(clock()>=Date.parse(day.locks_at))fail('protocol_locked','Protocol must be published before lock.',409);
   const start=date(body.observationStartsAt,'observationStartsAt'),end=date(body.observationEndsAt,'observationEndsAt'),deadline=date(body.declaredDeadline,'declaredDeadline');
   const calendar=await rawOne(c,'statement_13',[body.seasonId,body.matchdayId,body.cardId]);
   if(!calendar||Date.parse(start)>Date.parse(end)||Date.parse(end)>Date.parse(deadline)||iso(calendar.close_at)!==deadline||Date.parse(start)<Date.parse(day.locks_at)||Date.parse(end)>Date.parse(day.observation_ends_at)||Date.parse(problem.payload.baseline.measuredAt)>=Date.parse(start))fail('invalid_field','Protocol dates must match the predeclared v2 calendar.');
   const baselineSource=await source(c,problem.payload.baseline.source.id,m);if(baselineSource.indicator!==body.indicator||baselineSource.unit!==body.unit)fail('incomparable_evidence','Baseline indicator/unit mismatch.',409);
   const old=await rawOne(c,'statement_10',[body.seasonId,body.matchdayId,body.cardId]);
   if(old&&old.problem_id!==id)fail('protocol_scope_conflict','A card protocol cannot change its problem.',409);
   const pid=old?.id??randomUUID(),version=(old?.version??0)+1;
   if(body.missionIds.length){exact(body.measurementDefinition,['minValue','maxValue','integerOnly']);numeric(body.measurementDefinition.minValue,'minValue');numeric(body.measurementDefinition.maxValue,'maxValue');if(body.measurementDefinition.minValue>body.measurementDefinition.maxValue||typeof body.measurementDefinition.integerOnly!=='boolean')fail('invalid_field','Invalid measurement range.');}
   else if(body.measurementDefinition!==undefined&&body.measurementDefinition!==null)fail('invalid_field','Measurement definition requires linked missions.');
   for(const mid of body.missionIds){const mission=await rawOne(c,'statement_14',[mid,m]);const windows=await raw(c,'statement_15',[mid]);const booking=await rawOne(c,'statement_16',[mid]);if(!mission||mission.place_id!==problem.place_id||booking||!windows.length||windows.some(w=>Date.parse(w.starts_at)<=clock()||Date.parse(w.starts_at)<Date.parse(start)||Date.parse(w.ends_at)>Date.parse(end)))fail('protocol_locked','Mission must be compatible, unstarted and never booked.',409);}
   result={...Object.fromEntries(definitionFields.filter(k=>body[k]!==undefined).map(k=>[k,body[k]])),id:pid,version,revision:version,municipalityId:m,baselineSnapshot:{...problem.payload.baseline,placeId:problem.place_id},publishedAt:now()};
   await repository.query(c,'statement_17',[pid,version,id,body.seasonId,body.matchdayId,body.cardId,JSON.stringify(result),version]);
   for(const mid of body.missionIds){const mission=await rawOne(c,'statement_18',[mid]);await repository.query(c,'statement_19',[mid,mission.protocol.version,JSON.stringify(mission.protocol)]);const next={...mission.protocol,version:mission.protocol.version+1,measurementDefinition:{protocolId:pid,protocolVersion:version,indicator:body.indicator,unit:body.unit,...body.measurementDefinition}};await repository.query(c,'statement_20',[mid,next.version,JSON.stringify(next)]);await repository.query(c,'statement_21',[mid,JSON.stringify(next)]);await repository.query(c,'statement_22',[mid,body.seasonId,body.matchdayId,body.cardId]);}
   await repository.query(c,'statement_23',[id]);await audit(c,null,a,'protocol',{protocolId:pid,version});
  }else if(action==='interventions'||action==='updates'){
   exact(body,['idempotencyKey',...(action==='updates'?['expectedRevision']:[]),'title','problemIds','status','temporary','expectedDurationDays','sourceId','sourceDate']);text(body.title,'title',200);ids(body.problemIds,'problemIds');if(!body.problemIds.length||!['proposed','started','completed','suspended'].includes(body.status)||typeof body.temporary!=='boolean'||!(body.expectedDurationDays===null||Number.isInteger(body.expectedDurationDays)&&body.expectedDurationDays>0&&body.expectedDurationDays<=36500))fail('invalid_field','Invalid intervention.');
   const s=await source(c,body.sourceId,m);if(iso(s.measured_at)!==date(body.sourceDate,'sourceDate')||Date.parse(s.measured_at)>clock())fail('incomparable_evidence','Intervention source date mismatch.',409);
   for(const pid of body.problemIds){uuid(pid);const p=await one(c,'problem',[pid,m]);if(!p||p.place_id!==s.place_id)fail('incomparable_evidence','Intervention problem/place mismatch.',409);for(const scope of await many(c,'problemScopes',[pid]))await conflict(c,a,scope.payload);}
   const old=action==='updates'?await one(c,'intervention',[id,m]):null;if(action==='updates'&&!old)fail('not_found','Intervention not found.',404);if(old)for(const pid of old.payload.problemIds)for(const scope of await many(c,'problemScopes',[pid]))await conflict(c,a,scope.payload);if(old&&old.revision!==body.expectedRevision)fail('measurement_revision_conflict','Intervention changed.',409);
   const rev=(old?.revision??0)+1,entry={status:body.status,temporary:body.temporary,expectedDurationDays:body.expectedDurationDays,source:sourceSummary(s),sourceDate:iso(s.measured_at),revision:rev,at:now(),problemIds:body.problemIds,title:body.title};
   result={id:old?.id??randomUUID(),municipalityId:m,title:body.title,problemIds:body.problemIds,status:body.status,temporary:body.temporary,expectedDurationDays:body.expectedDurationDays,source:sourceSummary(s),sourceDate:iso(s.measured_at),revision:rev,history:[...(old?.payload.history??[]),entry]};
   await repository.query(c,'statement_24',[result.id,m,JSON.stringify(result),rev]);for(const pid of body.problemIds)await repository.query(c,'statement_25',[result.id,pid]);await audit(c,null,a,'intervention',{interventionId:result.id,revision:rev});
  }else if(action==='evaluations'||action==='draft-updates'){
   exact(body,['idempotencyKey',...(e?['expectedRevision']:['protocolId','protocolVersion']),...evidenceFields]);const d=evidence(body),p=await protocol(c,e?.protocol_id??body.protocolId,e?.protocol_version??body.protocolVersion,m);await validateEvidence(c,a,m,p,d);
   if(e&&e.payload.status!=='draft')fail('evaluation_published','Published evaluation requires a correction.',409);
   if(!e){if(await rawOne(c,'statement_26',[p.seasonId,p.matchdayId,p.cardId]))fail('evaluation_exists','An evaluation already exists for this card.',409);const eid=randomUUID();result={id:eid,municipalityId:m,protocolId:p.id,protocolVersion:p.version,seasonId:p.seasonId,matchdayId:p.matchdayId,cardId:p.cardId,revision:1,status:'draft',...d};await repository.query(c,'statement_27',[eid,m,p.seasonId,p.matchdayId,p.cardId,p.id,p.version,JSON.stringify(result)]);e=await evaluation(c,eid,m);}else{e.revision++;result=e.payload={...e.payload,...d,revision:e.revision};await saveEvaluation(c,e);}await audit(c,e,a,'draft');
  }else if(action==='publications'||action==='corrections'){
   exact(body,['idempotencyKey','expectedRevision',...verdictFields,...(action==='corrections'?[...evidenceFields,'appealId']:[])]);verdict(body);const history=await publications(c,e.id);if(action==='publications'&&history.length)fail('evaluation_published','Use a correction for published outcomes.',409);if(action==='corrections'&&!history.length)fail('evaluation_unpublished','Original publication required.',409);

   const d=action==='corrections'?evidence(body):e.payload;
   let appeal=null;if(action==='corrections'&&body.appealId!==null){uuid(body.appealId);appeal=await rawOne(c,'statement_28',[body.appealId,e.id]);if(!appeal||appeal.status!=='open')fail('appeal_closed','Open appeal required.',409);if(appeal.account_id===a)fail('self_review','Own appeal cannot be resolved.',403);}
   result=await publish(c,a,e,d,body);if(appeal){appeal.payload={...appeal.payload,status:'accepted',revision:appeal.revision+1};await repository.query(c,'statement_29',[appeal.id,JSON.stringify(appeal.payload)]);await audit(c,e,a,'appeal:accepted',{appealId:appeal.id});}
  }else if(action==='appeals'){
   exact(body,['idempotencyKey','expectedRevision','publishedVersion','reason']);revision(body.publishedVersion);text(body.reason,'reason',2000);const h=await publications(c,e.id);if(!h.some(p=>p.version===body.publishedVersion))fail('not_found','Published version not found.',404);if(await rawOne(c,'statement_30',[e.id,body.publishedVersion,a]))fail('appeal_exists','One open appeal per account/version.',409);
   result={id:randomUUID(),evaluationId:e.id,publishedVersion:body.publishedVersion,reason:body.reason.trim(),submittedAt:now(),status:'open',revision:1};await repository.query(c,'statement_31',[result.id,e.id,body.publishedVersion,a,JSON.stringify(result)]);await audit(c,e,a,'appeal',{appealId:result.id});
  }else if(action==='resolutions'){
   exact(body,['idempotencyKey','expectedRevision','decision','reason']);text(body.reason,'reason',2000);if(body.decision!=='reject')fail('invalid_field','Acceptance requires an atomic correction.');const appeal=await rawOne(c,'statement_28',[id.appealId,e.id]);if(!appeal)fail('not_found','Appeal not found.',404);if(appeal.account_id===a)fail('self_review','Own appeal cannot be resolved.',403);if(appeal.revision!==body.expectedRevision||appeal.status!=='open')fail('measurement_revision_conflict','Appeal changed.',409);result={...appeal.payload,status:'rejected',revision:appeal.revision+1};await repository.query(c,'statement_32',[appeal.id,JSON.stringify(result)]);await audit(c,e,a,'appeal:rejected',{appealId:appeal.id,reason:body.reason});
  }else fail('not_found','Measurement command not found.',404);
  await onCheckpoint('measurement_command_before_commit');return remember(c,a,body,requestHash,result);
 });}
 const api={isReady:()=>repository.ready(),command,reconcile,
  overview:(m,q={})=>run(null,async c=>{const s=await scope(c,m,q),evaluations=[];for(const e of await many(c,'evaluations',[s.seasonId,s.matchdayId])){const p=(await publications(c,e.id)).at(-1);if(p)evaluations.push(p);}const cards=await raw(c,'statement_33',[s.seasonId,s.matchdayId]);const protocols=(await many(c,'protocols',[s.seasonId,s.matchdayId])).map(r=>r.payload);const latest=[...new Map(protocols.map(p=>[p.id,p])).values()];const expected=new Set(),validated=new Set();for(const p of latest){for(const mid of p.missionIds){const windows=await raw(c,'statement_34',[mid]);for(const w of windows)expected.add(p.baselineSnapshot.placeId+'/'+iso(w.starts_at)+'/'+iso(w.ends_at));}for(const o of await observations(c,p))if(await proofValid(c,o))validated.add(o.place_id+'/'+iso(o.starts_at)+'/'+iso(o.ends_at));}const reasons=new Map();for(const e of evaluations)if(e.undeterminableReason)reasons.set(e.undeterminableReason,(reasons.get(e.undeterminableReason)??0)+1);return {...s,serverTime:now(),revision:evaluations.reduce((n,e)=>n+e.revision,protocols.reduce((n,p)=>n+p.revision,0)),problems:(await many(c,'problems',[m])).map(r=>r.payload),protocols,interventions:(await many(c,'interventions',[m])).map(r=>r.payload),evaluations,coverage:{expectedCards:cards.length,evaluableCards:evaluations.filter(e=>e.disposition==='determinate').length,closedUndeterminableCards:evaluations.filter(e=>e.disposition==='undeterminable').length,validatedPlaceWindows:validated.size,expectedPlaceWindows:expected.size,reasons:[...reasons].map(([code,count])=>({code,count}))}};}),
  published:(m,id,history=false)=>run(null,async c=>{const e=await evaluation(c,id,m),h=await publications(c,e.id);if(!h.length)fail('not_found','Published evaluation not found.',404);return history?{items:h}:h.at(-1);}),
  workspace:(token,m,q={})=>run(token,async(c,a)=>{await supervisor(c,a,m);const s=await scope(c,m,q),protos=(await many(c,'protocols',[s.seasonId,s.matchdayId])).map(r=>r.payload),evals=await many(c,'evaluations',[s.seasonId,s.matchdayId]);const approved=[];for(const p of protos){await conflict(c,a,p);for(const o of await observations(c,p)){await conflict(c,a,p,[o.account_id]);approved.push({id:o.id,municipalityId:m,seasonId:p.seasonId,matchdayId:p.matchdayId,cardId:p.cardId,authorId:o.account_id,protocolId:p.id,protocolVersion:p.version,submittedAt:iso(o.submitted_at),status:o.status,measurement:o.receipt.measurement});}}for(const e of evals)await currentWorkspace(c,a,m,e);return {scope:s,revision:evals.reduce((n,e)=>n+e.revision,0),problems:(await many(c,'problems',[m])).map(r=>r.payload),protocols:protos,interventions:(await many(c,'interventions',[m])).map(r=>r.payload),evaluationDrafts:evals.filter(e=>e.payload.status==='draft').map(e=>e.payload),appeals:(await raw(c,'statement_35',[s.seasonId,s.matchdayId])).map(r=>r.payload),sources:(await many(c,'sources',[m])).map(s=>({...sourceSummary(s),placeId:s.place_id,indicator:s.indicator,unit:s.unit,value:Number(s.value)})),approvedObservations:approved};}),
  detail:(token,m,id)=>run(token,async(c,a)=>{await supervisor(c,a,m);return currentWorkspace(c,a,m,await evaluation(c,id,m));}),
  appeal:(token,m,id,appealId)=>run(token,async(c,a)=>{uuid(appealId);await evaluation(c,id,m);const appeal=await rawOne(c,'statement_36',[appealId,id,a]);if(!appeal)fail('not_found','Own appeal not found.',404);return appeal.payload;}),
  proof:(token,m,id,uploadId)=>run(token,async(c,a)=>{uuid(uploadId);await supervisor(c,a,m);const e=await evaluation(c,id,m),w=await currentWorkspace(c,a,m,e);const frozenProofIds=w.evidence.published.flatMap(p=>p.observations.flatMap(o=>o.proofs.map(v=>v.id)));const allowedDraft=w.draft!==null;const observationIds=new Set([...(w.evidence.draft.approvedObservationIds??[]),...w.evidence.published.flatMap(p=>p.observations.map(o=>o.id))]);const u=await rawOne(c,'statement_37',[uploadId,[...observationIds],now()]);if(!u?.file_key||!allowedDraft&&!frozenProofIds.includes(uploadId))fail('proof_not_found','Case proof unavailable.',404);const bytes=await storage.get(u.file_key);return {id:u.id,bookingId:u.booking_id,mimeType:u.mime_type,totalBytes:u.total_bytes,receivedBytes:u.received_bytes,status:u.status,revision:u.revision,expiresAt:iso(u.expires_at),width:u.width,height:u.height,sha256:hash(bytes),sanitizedBytes:bytes.length,dataBase64:bytes.toString('base64')};}),
 };
 fantasy.database.setBeforeAction(reconcile);return api;
}
