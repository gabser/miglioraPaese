import {createHash,randomUUID} from 'node:crypto';
import {unitOfWork} from '../persistence/postgres/unit-of-work.js';
import {writeV2Calendar} from '../persistence/postgres/calendar-v2-writer.js';
import {exact,text,date,numeric,fail} from '../domain/measurements/rules.js';
import {key} from '../domain/missions/rules.js';
const iso=v=>new Date(v).toISOString();
export const canonicalJson=v=>JSON.stringify(sort(v));
function sort(v){if(Array.isArray(v))return v.map(sort);if(v&&typeof v==='object')return Object.fromEntries(Object.keys(v).sort().map(k=>[k,sort(v[k])]));return v;}
const list=(v,max,field)=>{if(!Array.isArray(v)||v.length>max)fail('invalid_field',field+' exceeds bounds.');};
const unique=(v,field='id')=>{if(v.some(x=>!x||typeof x!=='object'||Array.isArray(x)))fail('invalid_field','Invalid record.');if(field==='id')v.forEach(x=>text(x[field],field));if(new Set(v.map(x=>x[field])).size!==v.length)fail('invalid_field','Duplicate '+field);};
function identifier(v,field){if(typeof v!=='string'||!v.trim()||v.length>128||/[\u0000-\u001f\u007f-\u009f/\\?#%]/u.test(v)||v==='.'||v==='..')fail('invalid_field','Invalid '+field);}
function positive(v,field,max=1e6){if(!Number.isInteger(v)||v<1||v>max)fail('invalid_field','Invalid '+field);}
// This local format declares synthetic provenance; it cannot ratify real sources.
export function validateCalendar(input,clock=Date.now){
 if(Buffer.byteLength(JSON.stringify(input))>262144)fail('payload_too_large','Calendar exceeds 256 KiB.',413);
 exact(input,['idempotencyKey','municipalityId','season','cards','matchdays','missions','coverageGoals']);key(input.idempotencyKey);text(input.municipalityId,'municipalityId');
 identifier(input.municipalityId,'municipalityId');
 const s=input.season;exact(s,['id','name','startsAt','endsAt','catalogVersion','synthetic']);text(s.id,'season.id');text(s.name,'season.name');positive(s.catalogVersion,'catalogVersion');if(s.synthetic!==true)fail('invalid_field','Explicit synthetic season required.');const starts=Date.parse(date(s.startsAt,'startsAt')),ends=Date.parse(date(s.endsAt,'endsAt'));if(starts>=ends)fail('invalid_field','Invalid season range.');
 for(const [field,max]of [['cards',200],['matchdays',52],['missions',500],['coverageGoals',52]]){list(input[field],max,field);unique(input[field]);}
 if(!input.cards.length||!input.matchdays.length)fail('invalid_field','Cards and matchdays required.');
 identifier(s.id,'season.id');
 for(const field of ['cards','matchdays','missions','coverageGoals'])for(const item of input[field])identifier(item.id,field+'.id');
 for(const m of input.missions){identifier(m.placeId,'placeId');identifier(m.protocol?.id,'protocol.id');if(Array.isArray(m.windows))for(const w of m.windows)identifier(w?.id,'window.id');}
 const cardIds=new Set(input.cards.map(c=>c.id)),days=new Map(input.matchdays.map(d=>[d.id,d]));unique(input.matchdays,'number');
 for(const c of input.cards){if(!['mobility','environment','servicesAndSafety'].includes(c.role)||!['available','unavailable'].includes(c.availability))fail('invalid_field','Invalid card role/availability.');positive(c.version,'card.version');positive(c.price,'card.price',100);for(const f of ['title','zone','sourceLabel','illustrationKey','observationWindow'])text(c[f],f,256);if(Object.hasOwn(c,'verified')||c.sourceStatus==='verified')fail('invalid_field','Synthetic publisher cannot attest verified sources.');if(!['pending','unavailable'].includes(c.sourceStatus))fail('invalid_field','Invalid synthetic source status.');}
 for(const d of input.matchdays){exact(d,['id','number','startsAt','locksAt','observationEndsAt','closeAt']);positive(d.number,'number',52);const ds=Date.parse(date(d.startsAt,'startsAt')),lock=Date.parse(date(d.locksAt,'locksAt')),de=Date.parse(date(d.observationEndsAt,'observationEndsAt')),close=Date.parse(date(d.closeAt,'closeAt'));if(ds<starts||ds>=lock||lock>=de||de>close||close>ends||clock()>=lock)fail('calendar_locked','Calendar dates must be coherent and published before lock.',409);}
 const windows=new Set(),protocolIds=new Set();
 for(const m of input.missions){
  exact(m,['id','zoneId','title','area','placeId','durationMinutes','protocol','windows','matchdayId','cardId','baseline']);text(m.zoneId,'zoneId');text(m.title,'title');text(m.placeId,'placeId');positive(m.durationMinutes,'durationMinutes',1440);
  exact(m.area,['label','boundary','public']);text(m.area.label,'area.label');text(m.area.boundary,'area.boundary',1000);if(m.area.public!==true)fail('invalid_field','Public synthetic area required.');
  const d=days.get(m.matchdayId);if(!d||!cardIds.has(m.cardId))fail('invalid_field','Mission requires a scoped matchday/card.');
  const p=m.protocol;exact(p,['id','version','instructions','photoPoints','minPhotos','indicator','unit','threshold','lowerIsBetter','measurementDefinition']);text(p.id,'protocol.id');if(protocolIds.has(p.id))fail('invalid_field','Duplicate protocol ID.');protocolIds.add(p.id);if(p.version!==1)fail('invalid_field','New mission protocol version must be 1.');
  list(p.instructions,20,'instructions');if(!p.instructions.length)fail('invalid_field','Published instructions required.');p.instructions.forEach(i=>text(i,'instruction',1000));list(p.photoPoints,20,'photoPoints');p.photoPoints.forEach(i=>{exact(i,['id','label']);text(i.id,'photoPoint.id');text(i.label,'photoPoint.label',256);});if(!Number.isInteger(p.minPhotos)||p.minPhotos<0||p.minPhotos>3)fail('invalid_field','Invalid photo requirement.');text(p.indicator,'indicator');text(p.unit,'unit',64);numeric(p.threshold,'threshold');if(p.threshold<0||typeof p.lowerIsBetter!=='boolean')fail('invalid_field','Invalid threshold/direction.');
  const md=p.measurementDefinition;exact(md,['minValue','maxValue','integerOnly']);numeric(md.minValue,'minValue');numeric(md.maxValue,'maxValue');if(md.minValue>md.maxValue||typeof md.integerOnly!=='boolean')fail('invalid_field','Invalid measurement range.');
  exact(m.baseline,['value','unit','measuredAt','label','provenance']);numeric(m.baseline.value,'baseline');if(m.baseline.unit!==p.unit||Date.parse(date(m.baseline.measuredAt,'baseline.measuredAt'))>=Date.parse(d.locksAt)||Date.parse(m.baseline.measuredAt)>clock())fail('invalid_field','Baseline predates observation and matches unit.');text(m.baseline.label,'label');text(m.baseline.provenance,'provenance',1000);
  list(m.windows,52,'windows');if(!m.windows.length)fail('invalid_field','Mission requires windows.');for(const w of m.windows){exact(w,['id','startsAt','endsAt','capacity']);text(w.id,'window.id');if(windows.has(w.id))fail('invalid_field','Duplicate window ID.');windows.add(w.id);positive(w.capacity,'capacity',10000);const ws=Date.parse(date(w.startsAt,'startsAt')),we=Date.parse(date(w.endsAt,'endsAt'));if(ws< Date.parse(d.locksAt)||ws<=clock()||we<=ws||we>Date.parse(d.observationEndsAt))fail('invalid_field','Window outside published matchday.');}
 }
 const grouped=new Map();for(const m of input.missions){const k=JSON.stringify([m.matchdayId,m.cardId]),fingerprint=canonicalJson([m.placeId,m.baseline,Object.fromEntries(Object.entries(m.protocol).filter(([k])=>!['id','version'].includes(k)))]);if(grouped.has(k)&&grouped.get(k)!==fingerprint)fail('invalid_field','Missions sharing a card require comparable baseline and protocol.');grouped.set(k,fingerprint);}
 const goalDays=new Set();for(const g of input.coverageGoals){exact(g,['id','matchdayId','title','version','targets']);text(g.title,'title',256);if(!days.has(g.matchdayId)||goalDays.has(g.matchdayId)||g.version!==1)fail('invalid_field','One new goal per day required.');goalDays.add(g.matchdayId);list(g.targets,1000,'targets');const targets=new Set();for(const t of g.targets){exact(t,['placeId','startsAt','endsAt']);text(t.placeId,'placeId');const start=date(t.startsAt,'startsAt'),end=date(t.endsAt,'endsAt'),key=JSON.stringify([t.placeId,start,end]);if(targets.has(key))fail('invalid_field','Duplicate target.');targets.add(key);if(!input.missions.some(m=>m.matchdayId===g.matchdayId&&m.placeId===t.placeId&&m.windows.some(w=>iso(w.startsAt)===start&&iso(w.endsAt)===end)))fail('invalid_field','Target requires a declared mission/window.');}}
 return input;
}
export async function publishSyntheticCalendar({pool,input,loopbackSynthetic=false,clock=Date.now,onCheckpoint=async()=>{}}){
 if(loopbackSynthetic!==true)throw new TypeError('Explicit local synthetic publication required.');
 exact(input,['idempotencyKey','municipalityId','season','cards','matchdays','missions','coverageGoals']);key(input.idempotencyKey);
 if(Buffer.byteLength(JSON.stringify(input))>262144)fail('payload_too_large','Calendar exceeds 256 KiB.',413);
 const digest=createHash('sha256').update(canonicalJson(input)).digest('hex');
 return unitOfWork(pool).run(async c=>{
  const previous=(await c.query('SELECT digest,receipt FROM cooperation_calendar_receipts WHERE command_key=$1',[input.idempotencyKey])).rows[0];if(previous){if(previous.digest!==digest)fail('idempotency_conflict','Calendar key reused with different content.',409);return previous.receipt;}
  validateCalendar(input,clock);
  const s=input.season;
  const conflicts=await c.query('SELECT 1 FROM fantasy_seasons WHERE id=$1 OR (municipality_id=$5 AND starts_at::timestamptz=$6::timestamptz) UNION ALL SELECT 1 FROM missions WHERE id=ANY($2::text[]) UNION ALL SELECT 1 FROM cooperation_goals WHERE id=ANY($3::text[]) UNION ALL SELECT 1 FROM mission_windows WHERE id=ANY($4::text[]) LIMIT 1',[s.id,input.missions.map(m=>m.id),input.coverageGoals.map(g=>g.id),input.missions.flatMap(m=>m.windows.map(w=>w.id)),input.municipalityId,s.startsAt]);if(conflicts.rows.length)fail('calendar_conflict','Published IDs are immutable.',409);
  await writeV2Calendar(c,{...input,publishedAt:iso(clock())});
  // Bind each quantitative mission to a frozen synthetic baseline and protocol.
  const groups=new Map();for(const m of input.missions){const key=JSON.stringify([m.matchdayId,m.cardId]);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(m);}
  for(const group of groups.values()){
   const m=group[0];
   const d=input.matchdays.find(d=>d.id===m.matchdayId),problemId=randomUUID(),protocolId=randomUUID(),sourceId='calendar:'+s.id+':'+m.id,base={...m.baseline,source:{id:sourceId,label:m.baseline.label,sourceDate:iso(m.baseline.measuredAt)}};
   await c.query('INSERT INTO measurement_sources(id,municipality_id,place_id,indicator,unit,value,measured_at,label,provenance,registered_by) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',[sourceId,input.municipalityId,m.placeId,m.protocol.indicator,m.protocol.unit,m.baseline.value,m.baseline.measuredAt,m.baseline.label,m.baseline.provenance,'local-synthetic-calendar']);
   const problem={id:problemId,municipalityId:input.municipalityId,placeId:m.placeId,title:m.title,baseline:base,revision:1,publishedAt:iso(clock())};await c.query('INSERT INTO measurement_problems(id,municipality_id,place_id,payload,revision) VALUES($1,$2,$3,$4,1)',[problemId,input.municipalityId,m.placeId,JSON.stringify(problem)]);
   const p={id:protocolId,version:1,revision:1,municipalityId:input.municipalityId,problemId,seasonId:s.id,matchdayId:d.id,cardId:m.cardId,missionIds:group.map(m=>m.id),indicator:m.protocol.indicator,unit:m.protocol.unit,threshold:m.protocol.threshold,lowerIsBetter:m.protocol.lowerIsBetter,instructions:m.protocol.instructions,observationStartsAt:d.locksAt,observationEndsAt:d.observationEndsAt,declaredDeadline:d.closeAt,measurementDefinition:m.protocol.measurementDefinition,baselineSnapshot:{...base,placeId:m.placeId},publishedAt:iso(clock())};
   await c.query('INSERT INTO measurement_protocols(id,version,problem_id,season_id,matchday_id,card_id,payload,revision) VALUES($1,1,$2,$3,$4,$5,$6,1)',[protocolId,problemId,s.id,d.id,m.cardId,JSON.stringify(p)]);
   for(const m of group){
   const bound={...m.protocol,threshold:String(m.protocol.threshold)+' '+m.protocol.unit,measurementDefinition:{...m.protocol.measurementDefinition,protocolId,protocolVersion:1,indicator:p.indicator,unit:p.unit}};
   await c.query('UPDATE missions SET protocol=$2 WHERE id=$1',[m.id,JSON.stringify(bound)]);
   await c.query('INSERT INTO measurement_mission_protocols(mission_id,mission_protocol_version,payload) VALUES($1,1,$2)',[m.id,JSON.stringify(bound)]);
   await c.query('INSERT INTO mission_card_links(mission_id,season_id,matchday_id,card_id) VALUES($1,$2,$3,$4)',[m.id,s.id,d.id,m.cardId]);
   }
  }
  for(const g of input.coverageGoals){await c.query('INSERT INTO cooperation_goals(id,municipality_id,season_id,matchday_id,title,version,published_at) VALUES($1,$2,$3,$4,$5,$6,$7)',[g.id,input.municipalityId,s.id,g.matchdayId,g.title,g.version,iso(clock())]);for(const t of g.targets)await c.query('INSERT INTO cooperation_targets(goal_id,place_id,starts_at,ends_at) VALUES($1,$2,$3,$4)',[g.id,t.placeId,t.startsAt,t.endsAt]);}
  const receipt={idempotencyKey:input.idempotencyKey,digest,municipalityId:input.municipalityId,seasonId:s.id,catalogVersion:s.catalogVersion,rulesVersion:'fantasy-v2',matchdayIds:input.matchdays.map(d=>d.id),missionIds:input.missions.map(m=>m.id),goalVersions:input.coverageGoals.map(g=>({id:g.id,version:g.version})),publishedAt:iso(clock()),synthetic:true};
  await c.query('INSERT INTO cooperation_calendar_receipts(command_key,digest,receipt,created_at) VALUES($1,$2,$3,$4)',[input.idempotencyKey,digest,JSON.stringify(receipt),iso(clock())]);await onCheckpoint('calendar_before_commit');
  if(input.matchdays.some(d=>clock()>=Date.parse(d.locksAt)))fail('calendar_locked','Calendar lock elapsed before commit.',409);
  return receipt;
 });
}
