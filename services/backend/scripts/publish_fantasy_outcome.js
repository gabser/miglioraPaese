import { readFileSync } from 'node:fs';

try {
  const { API_BASE_URL, MODERATION_ADMIN_TOKEN_FILE, FANTASY_OUTCOME_FILE } = process.env;
  if (!API_BASE_URL || !MODERATION_ADMIN_TOKEN_FILE || !FANTASY_OUTCOME_FILE) {
    throw new Error('Required environment: API_BASE_URL, MODERATION_ADMIN_TOKEN_FILE, FANTASY_OUTCOME_FILE.');
  }
  const base = new URL(API_BASE_URL.endsWith('/') ? API_BASE_URL : API_BASE_URL + '/');
  if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password) throw new Error('Invalid API base URL.');
  const token = readFileSync(MODERATION_ADMIN_TOKEN_FILE, 'utf8').trim();
  if (Buffer.byteLength(token) < 32) throw new Error('Invalid administrator token file.');
  const { municipalityId, matchdayId, cardId, outcome } = JSON.parse(readFileSync(FANTASY_OUTCOME_FILE, 'utf8'));
  if ([municipalityId, matchdayId, cardId].some((value) => typeof value !== 'string' || !value) || !outcome) throw new Error('Invalid outcome fixture.');
  const path = `v1/fantasy/admin/municipalities/${encodeURIComponent(municipalityId)}/matchdays/${encodeURIComponent(matchdayId)}/outcomes/${encodeURIComponent(cardId)}`;
  const response = await fetch(new URL(path, base), { method: 'PUT', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify(outcome), signal: AbortSignal.timeout(10000) });
  const body = await response.json();
  if (!response.ok) {
    const error = typeof body.error === 'string' && /^[a-z_]{1,64}$/.test(body.error) ? body.error : 'request_failed';
    console.error(JSON.stringify({ event: 'fantasy_outcome_publication_failed', status: response.status, error }));
    process.exitCode = 1;
  } else {
    console.log(JSON.stringify({ event: 'fantasy_outcome_published', publicationId: body.outcome.publicationId, isDemo: body.isDemo }));
  }
} catch {
  console.error(JSON.stringify({ event: 'fantasy_outcome_publication_failed', error: 'configuration_or_transport_error' }));
  process.exitCode = 1;
}
