export function runtimeIdentity(env, persistence) {
  if (env.CANDIDATE_ID !== undefined && !/^[a-f0-9]{64}$/.test(env.CANDIDATE_ID)) throw new TypeError('CANDIDATE_ID must be a lowercase 64 hexadecimal digest.');
  const features = Object.fromEntries(Object.entries({fantasy:'FANTASY_ENABLED', accounts:'ACCOUNT_ENABLED', missions:'MISSIONS_ENABLED', review:'REVIEW_ENABLED', measurements:'MEASUREMENTS_ENABLED', leagueContinuity:'LEAGUE_CONTINUITY_ENABLED', cooperation:'COOPERATION_ENABLED', opsLocal:'OPS_LOCAL_ENABLED'}).map(([k,v])=>[k,env[v]==='true']));
  return Object.freeze({candidateId:env.CANDIDATE_ID??null, version:'0.2.0', persistence, profile:features.opsLocal?'synthetic-local':'legacy-local',features});
}

// Only this bounded projection can reach the log sink. Never pass request/error objects.
export function createRequestObserver({logger, candidateId=null}={}) {
  let logFailures=0;
  const metrics=new Map();
  return {
    record({route,status,durationMs,requestId}) {
      const event={event:'http_request',route,status,durationMs:Math.max(0,Math.round(durationMs)),requestId,candidateId};
      const key=route+':'+status;
      const prior=metrics.get(key)??{route,status,count:0,durationMs:0};prior.count++;prior.durationMs+=event.durationMs;metrics.set(key,prior);
      try { const result=logger?.info?.(event);if(result?.catch)result.catch(()=>{logFailures++;}); } catch { logFailures++; }
    },
    snapshot:()=>({logFailures,requests:[...metrics.values()].map(x=>({...x}))}),
    isReady:()=>logFailures===0,
  };
}
