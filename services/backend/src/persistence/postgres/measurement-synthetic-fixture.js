import {writeV2Calendar} from './calendar-v2-writer.js';
// Explicit local synthetic adapter. No HTTP caller can register or ratify sources.
import {readFileSync} from 'node:fs';
import {unitOfWork} from './unit-of-work.js';
import {exact,text,numeric,date,fail} from '../../domain/measurements/rules.js';
const cards=JSON.parse(readFileSync(new URL('../../domain/fantasy/cards.demo.json',import.meta.url),'utf8'));
const day=86400000,iso=v=>new Date(v).toISOString();
export async function registerSyntheticMeasurementSource({pool,source,loopbackSynthetic=false}){
 if(loopbackSynthetic!==true)throw new TypeError('Explicit loopbackSynthetic=true required.');
 exact(source,['id','municipalityId','placeId','indicator','unit','value','measuredAt','label','provenance','registeredBy']);for(const field of ['id','municipalityId','placeId','indicator','label','provenance','registeredBy'])text(source[field],field);text(source.unit,'unit',64);numeric(source.value,'value');date(source.measuredAt,'measuredAt');
 return unitOfWork(pool).run(async c=>{const values=[source.id,source.municipalityId,source.placeId,source.indicator,source.unit,source.value,iso(source.measuredAt),source.label,source.provenance,source.registeredBy];const old=(await c.query('SELECT * FROM measurement_sources WHERE id=$1',[source.id])).rows[0];if(old){const previous=[old.id,old.municipality_id,old.place_id,old.indicator,old.unit,Number(old.value),iso(old.measured_at),old.label,old.provenance,old.registered_by];if(JSON.stringify(values)!==JSON.stringify(previous))fail('source_immutable','Registered source cannot be replaced.',409);return source;}
 await c.query('INSERT INTO measurement_sources(id,municipality_id,place_id,indicator,unit,value,measured_at,label,provenance,registered_by) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',values);return source;});
}
export async function seedSyntheticMeasurementSeason({pool,municipalityId='tuglie',seasonId='synthetic-measurements-tuglie-v2',startsAt='2026-12-01T00:00:00Z',loopbackSynthetic=false}){
 if(loopbackSynthetic!==true)throw new TypeError('Explicit loopbackSynthetic=true required.');text(seasonId,'seasonId');text(municipalityId,'municipalityId');date(startsAt,'startsAt');const at=Date.parse(startsAt),locksAt=iso(at+day),observationEndsAt=iso(at+2*day),closeAt=iso(at+3*day),matchdayId=seasonId+'-day',missionId=seasonId+'-mission',windowId=seasonId+'-window',placeId=seasonId+'-place';
 const newCards=cards.map(card=>({...card,id:seasonId+'-'+card.id,isDemo:true}));
 const scope={municipalityId,seasonId,matchdayId,cardId:newCards.find(c=>c.id.endsWith('rifiuti-mercato')).id,cardIds:newCards.map(c=>c.id),squadIds:cards.slice(0,0),missionId,windowId,placeId,startsAt:iso(at),locksAt,observationStartsAt:locksAt,observationEndsAt,closeAt,indicator:'Synthetic visible items',unit:'items',baselineSourceId:seasonId+'-baseline',afterSourceId:seasonId+'-after'};
 const initial=['buche-centro','bus-stazione','parco-nord','rifiuti-mercato','lampioni-sud','attraversamenti-scuole','alberi-viale','sportello-anagrafe'];scope.squadIds=initial.map(id=>seasonId+'-'+id);
 await unitOfWork(pool).run(async c=>{
  if((await c.query('SELECT 1 FROM fantasy_seasons WHERE id=$1',[seasonId])).rows.length)throw new TypeError('Synthetic fixture requires a new season ID.');
  const protocol={id:missionId+'-protocol',version:1,instructions:['Synthetic quantitative test only'],photoPoints:[],minPhotos:0,indicator:scope.indicator,threshold:'Unbound synthetic mission'};
  await writeV2Calendar(c,{municipalityId,season:{id:seasonId,name:'Synthetic measurement fixture',startsAt:iso(at),endsAt:iso(at+4*day),catalogVersion:1},cards:newCards,matchdays:[{id:matchdayId,number:1,startsAt:iso(at),locksAt,observationEndsAt,closeAt}],missions:[{id:missionId,zoneId:'synthetic-centre',title:'Synthetic measurement mission',area:{label:placeId,boundary:'Synthetic fixture only',public:true},protocol,durationMinutes:15,placeId,windows:[{id:windowId,startsAt:locksAt,endsAt:observationEndsAt,capacity:20}]}],publishedAt:iso(at)});
  for(const [id,value,measuredAt,label]of [[scope.baselineSourceId,10,iso(at-day),'Synthetic baseline'],[scope.afterSourceId,5,iso(at+1.5*day),'Synthetic after document']])await registerSyntheticMeasurementSource({pool,loopbackSynthetic:true,source:{id,municipalityId,placeId,indicator:scope.indicator,unit:scope.unit,value,measuredAt,label,provenance:'Local synthetic test fixture; no ratification',registeredBy:'synthetic-fixture'}});
 });return scope;
}
