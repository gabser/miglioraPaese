import { fail,exact } from '../missions/rules.js';
export {fail,exact};
export const iso=v=>new Date(v).toISOString();
export function text(v,field,max=128){if(typeof v!=='string'||!v.trim()||v.length>max||/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(v))fail('invalid_field',field+' is invalid.');return v.trim();}
export function numeric(v,field){if(typeof v!=='number'||!Number.isFinite(v)||Math.abs(v)>1e9)fail('invalid_field',field+' must be a finite bounded number.');return v;}
export function date(v,field){if(typeof v!=='string'||!/(?:Z|[+-]\d{2}:\d{2})$/.test(v)||!Number.isFinite(Date.parse(v)))fail('invalid_field',field+' requires a UTC timestamp.');return iso(v);}
export function ids(v,field){if(!Array.isArray(v)||v.length>20||new Set(v).size!==v.length)fail('invalid_field',field+' requires distinct IDs.');return v.map(id=>text(id,field));}
export const sourceSummary=s=>({id:s.id,label:s.label,sourceDate:iso(s.measured_at)});
// Compare the canonical decimal values carried by JSON, avoiding cancellation
// at large baselines and preserving decimal threshold equality without epsilon.
export function direction(baseline,after,threshold,lowerIsBetter){
 const parts=value=>{const [mantissa,exponent='0']=String(value).toLowerCase().split('e');const fraction=(mantissa.split('.')[1]??'').length;return {integer:BigInt(mantissa.replace('.','')),scale:fraction-Number(exponent)};};
 const values=[baseline,after,threshold].map(parts),scale=Math.max(0,...values.map(v=>v.scale));
 const [beforeValue,afterValue,tolerance]=values.map(v=>v.integer*10n**BigInt(scale-v.scale));
 const delta=afterValue-beforeValue,absolute=delta<0n?-delta:delta;
 if(absolute<=tolerance)return 'stable';
 return (lowerIsBetter?-delta:delta)>0n?'improves':'worsens';
}

export const reasons=['insufficientEvidence','contradictoryEvidence','incomparableEvidence','missingBaseline','deadlineExpired'];
export const evidenceFields=['afterValue','measuredAt','sourceIds','approvedObservationIds','interventionIds','rationale'];
export function evidence(body){numericNullable(body.afterValue,'afterValue');if(body.measuredAt!==null)date(body.measuredAt,'measuredAt');ids(body.sourceIds,'sourceIds');ids(body.approvedObservationIds,'approvedObservationIds');ids(body.interventionIds,'interventionIds');text(body.rationale,'rationale',2000);return Object.fromEntries(evidenceFields.map(k=>[k,body[k]]));}
export function numericNullable(v,field){if(v!==null)numeric(v,field);}
export function verdict(body){if(!['determinate','undeterminable'].includes(body.disposition))fail('invalid_field','Invalid disposition.');text(body.rationale,'rationale',2000);if(body.disposition==='determinate'){if(!['improves','stable','worsens'].includes(body.observed)||body.undeterminableReason!==null)fail('invalid_field','Determinate requires a direction and null reason.');}else if(body.observed!==null||!reasons.includes(body.undeterminableReason))fail('invalid_field','Undeterminable requires null direction and an explicit reason.');}
