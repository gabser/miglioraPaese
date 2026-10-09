// Provider-neutral signal evaluation. Installation/routing of alerts remains an
// operational gate; no monitoring service or notification is created here.
export function evaluatePilotSignals({ready,consecutiveReadinessFailures=0,fiveXxIncrease=0,
  diskAvailableRatio,backupVerifiedAt,now=Date.now(),scrapeHealthy}) {
  const alerts=[];
  if(!ready && consecutiveReadinessFailures>=2) alerts.push('readiness_unavailable');
  if(fiveXxIncrease>0) alerts.push('http_5xx_increase');
  if(typeof diskAvailableRatio!=='number' || diskAvailableRatio<0.2) alerts.push('disk_space_low_or_unknown');
  if(!Number.isFinite(backupVerifiedAt) || now-backupVerifiedAt>=86400000 || backupVerifiedAt>now) alerts.push('backup_stale_or_unknown');
  if(scrapeHealthy!==true) alerts.push('metrics_scrape_unavailable');
  return alerts;
}
