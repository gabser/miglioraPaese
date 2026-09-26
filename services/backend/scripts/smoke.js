const rawBaseUrl = process.env.STAGING_BASE_URL;
const municipalityId = process.env.PILOT_MUNICIPALITY_ID;
if (typeof rawBaseUrl !== 'string' || rawBaseUrl.trim() === '') {
  throw new Error('STAGING_BASE_URL is required.');
}
if (typeof municipalityId !== 'string' || municipalityId.trim() === '') {
  throw new Error('PILOT_MUNICIPALITY_ID is required.');
}
const baseUrl = new URL(rawBaseUrl);
if (!['http:', 'https:'].includes(baseUrl.protocol)) {
  throw new Error('STAGING_BASE_URL must use HTTP or HTTPS.');
}

const checks = [
  ['/health', 'application/json'],
  ['/ready', 'application/json'],
  ['/metrics', 'text/plain'],
  [
    `/v1/municipalities/${encodeURIComponent(municipalityId)}/activation`,
    'application/json',
  ],
  [
    `/v1/municipalities/${encodeURIComponent(municipalityId)}/summary`,
    'application/json',
  ],
  [
    `/v1/municipalities/${encodeURIComponent(municipalityId)}/turn`,
    'application/json',
  ],
  [
    `/v1/municipalities/${encodeURIComponent(municipalityId)}/problems`,
    'application/json',
  ],
  [
    `/v1/municipalities/${encodeURIComponent(municipalityId)}/next-problems`,
    'application/json',
  ],
];

for (const [path, contentType] of checks) {
  const response = await fetch(new URL(path, baseUrl), {
    headers: { 'x-request-id': 'staging-smoke-check' },
    signal: AbortSignal.timeout(8_000),
  });
  if (!response.ok) {
    throw new Error(`${path} returned HTTP ${response.status}.`);
  }
  if (!response.headers.get('content-type')?.startsWith(contentType)) {
    throw new Error(`${path} returned an unexpected content type.`);
  }
  await response.text();
}

console.log(
  JSON.stringify({
    event: 'staging_smoke_completed',
    baseUrl: baseUrl.origin,
    municipalityId,
    checks: checks.length,
  }),
);
