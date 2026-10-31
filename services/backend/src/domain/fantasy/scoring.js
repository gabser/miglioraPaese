export function scoreFantasyCard({ observed, prediction = null, captain = false, reflection = false }) {
  const observationPoints = observed === 'improves' ? 4 : observed === 'stable' ? 1 : 0;
  const predictionPoints = prediction == null ? 0 : prediction === observed ? 4 : prediction === 'stable' || observed === 'stable' ? 2 : 0;
  const captainMultiplier = captain ? 1.5 : 1;
  const reflectionPoints = reflection ? 1 : 0;
  const frozenTotal = Math.round((observationPoints + predictionPoints) * captainMultiplier);
  const total = Math.round((observationPoints + predictionPoints + reflectionPoints) * captainMultiplier);
  return { observationPoints, predictionPoints, reflectionPoints, captainMultiplier, frozenTotal, reflectionBonus: total - frozenTotal, total };
}


// Explicit dispatch preserves every v1 fixture and never scores unknown v2 as stable.
export function scoreVersionedFantasyCard({rulesVersion,outcome,prediction=null,captain=false,reflection=false}){
 if(rulesVersion==='fantasy-demo-v1')return scoreFantasyCard({observed:outcome.observed,prediction,captain,reflection});
 if(rulesVersion!=='fantasy-v2')throw new TypeError('Unsupported fantasy rules version.');
 if(outcome.disposition==='determinate'&&['improves','stable','worsens'].includes(outcome.observed))return scoreFantasyCard({observed:outcome.observed,prediction,captain,reflection});
 if(outcome.disposition!=='undeterminable'||outcome.observed!==null)throw new TypeError('Invalid closed v2 outcome.');
 const captainMultiplier=captain?1.5:1,reflectionPoints=reflection?1:0;
 const reflectionBonus=Math.round(reflectionPoints*captainMultiplier);
 return {observationPoints:0,predictionPoints:0,reflectionPoints,captainMultiplier,frozenTotal:0,reflectionBonus,total:reflectionBonus};
}
