// Shared persistence construction for the explicit phase-5 fixture and local
// calendar publisher. The caller validates input and supplies one UoW client.
export async function writeV2Calendar(c,{municipalityId,season,cards,matchdays,missions,publishedAt}){
 await c.query('INSERT INTO fantasy_seasons(id,municipality_id,name,starts_at,ends_at,catalog_version,is_demo) VALUES($1,$2,$3,$4,$5,$6,1)',[season.id,municipalityId,season.name,season.startsAt,season.endsAt,season.catalogVersion]);
 for(const card of cards)await c.query('INSERT INTO fantasy_cards(season_id,id,version,role,price,availability,source_status,payload) VALUES($1,$2,$3,$4,$5,$6,$7,$8)',[season.id,card.id,card.version??1,card.role,card.price,card.availability,card.sourceStatus,JSON.stringify({...card,isDemo:true})]);
 for(const d of matchdays){
  await c.query('INSERT INTO fantasy_matchdays(season_id,id,number,starts_at,locks_at,observation_ends_at,rules_version) VALUES($1,$2,$3,$4,$5,$6,\'fantasy-v2\')',[season.id,d.id,d.number,d.startsAt,d.locksAt,d.observationEndsAt]);
  for(const card of cards)await c.query('INSERT INTO measurement_card_deadlines(season_id,matchday_id,card_id,close_at,published_at) VALUES($1,$2,$3,$4,$5)',[season.id,d.id,card.id,d.closeAt,publishedAt]);
 }
 for(const m of missions){
  await c.query('INSERT INTO missions(id,municipality_id,zone_id,title,area,protocol,duration_minutes,synthetic) VALUES($1,$2,$3,$4,$5,$6,$7,true)',[m.id,municipalityId,m.zoneId,m.title,JSON.stringify(m.area),JSON.stringify(m.protocol),m.durationMinutes]);
  await c.query('INSERT INTO mission_places(mission_id,place_id) VALUES($1,$2)',[m.id,m.placeId]);
  for(const w of m.windows)await c.query('INSERT INTO mission_windows(id,mission_id,starts_at,ends_at,capacity) VALUES($1,$2,$3,$4,$5)',[w.id,m.id,w.startsAt,w.endsAt,w.capacity]);
 }
}
