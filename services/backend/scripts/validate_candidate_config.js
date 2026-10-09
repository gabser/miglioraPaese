const profile=process.env.STAGING_PROFILE, municipalityId=process.env.PILOT_MUNICIPALITY_ID;
if(!['legacy-api','fantasy-api'].includes(profile)) throw new Error('Explicit staging profile required.');
if(!['tuglie','castel-bolognese','bologna'].includes(municipalityId)) throw new Error('Supported pilot municipality required.');
let url;
try { url=new URL(process.env.API_BASE_URL); }
catch { throw new Error('Valid HTTPS API_BASE_URL required.'); }
if(url.protocol!=='https:' || url.username || url.password || url.search || url.hash) throw new Error('Protected staging requires an HTTPS URL without credentials, query or fragment.');
console.log(JSON.stringify({profile,municipalityId,apiBaseUrl:url.toString(),revision:process.env.GITHUB_SHA ?? null,
  fantasyModeEnabled:profile==='fantasy-api',fantasyDataSource:profile==='fantasy-api'?'api':'mock',gameDataSource:'api',nextProblemsDataSource:'api',deploymentAuthorized:false}));
