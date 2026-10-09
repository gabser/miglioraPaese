const rawBaseUrl=process.env.STAGING_BASE_URL;
const municipalityId=process.env.PILOT_MUNICIPALITY_ID;
const profile=process.env.STAGING_PROFILE ?? 'legacy-api';
if(typeof rawBaseUrl!=='string' || rawBaseUrl.trim()==='') throw new Error('STAGING_BASE_URL is required.');
if(!['tuglie','castel-bolognese','bologna'].includes(municipalityId)) throw new Error('A supported PILOT_MUNICIPALITY_ID is required.');
if(!['legacy-api','fantasy-api'].includes(profile)) throw new Error('STAGING_PROFILE must be legacy-api or fantasy-api.');
let baseUrl;
try { baseUrl=new URL(rawBaseUrl.endsWith('/')?rawBaseUrl:`${rawBaseUrl}/`); }
catch { throw new Error('Valid STAGING_BASE_URL required.'); }
if(!['http:','https:'].includes(baseUrl.protocol) || baseUrl.username || baseUrl.password || baseUrl.search || baseUrl.hash) throw new Error('STAGING_BASE_URL must be HTTP(S) without credentials, query or fragment.');
const fantasyBase=`/v1/fantasy/municipalities/${municipalityId}`;
const common=[['/health','application/json'],['/ready','application/json'],['/metrics','text/plain']];
const checks=profile==='fantasy-api' ? [...common,...['season','cards','matchday'].map(resource=>[`${fantasyBase}/${resource}`,'application/json'])]
  : [...common,...['activation','summary','turn','problems','next-problems'].map(resource=>[`/v1/municipalities/${municipalityId}/${resource}`,'application/json'])];
const payloads=new Map();
for(const [path,contentType] of checks) {
  const response=await fetch(new URL(path.slice(1),baseUrl),{method:'GET',redirect:'error',
    headers:{'x-request-id':'staging-smoke-check'},signal:AbortSignal.timeout(8000)});
  if(!response.ok) throw new Error(`${path} returned HTTP ${response.status}.`);
  if(!response.headers.get('content-type')?.startsWith(contentType)) throw new Error(`${path} returned an unexpected content type.`);
  if(contentType==='application/json') payloads.set(path,await response.json()); else await response.text();
}
if(profile==='fantasy-api') {
  const season=payloads.get(`${fantasyBase}/season`),catalog=payloads.get(`${fantasyBase}/cards`),calendar=payloads.get(`${fantasyBase}/matchday`);
  for(const payload of [season,catalog,calendar]) if(!Number.isFinite(Date.parse(payload.serverTime)) || typeof payload.isDemo!=='boolean') throw new Error('Missing server time or demo provenance.');
  if(season.season?.municipalityId!==municipalityId || catalog.seasonId!==season.season.id || calendar.matchday?.seasonId!==season.season.id || calendar.matchday.number!==season.season.currentMatchday || !Array.isArray(catalog.items) || catalog.items.length!==12) throw new Error('Incoherent fantasy catalog/season/calendar.');
  const day=calendar.matchday;
  if(!(Date.parse(day.startsAt)<Date.parse(day.locksAt) && Date.parse(day.locksAt)<Date.parse(day.observationEndsAt)) || day.rulesVersion!=='fantasy-demo-v1') throw new Error('Invalid fantasy calendar or rules.');
}
console.log(JSON.stringify({event:'staging_smoke_completed',profile,baseUrl:baseUrl.origin,municipalityId,checks:checks.length}));
