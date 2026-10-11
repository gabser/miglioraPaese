import { createHash } from 'node:crypto';

import { httpError } from '../../domain/errors.js';

export async function runIdempotentWrite(
  {
    target,
    query,
    operation,
    idempotencyKey,
    request,
    responseStatus,
  },
  callback,
) {
  const requestSha256 = fingerprintRequest(request);
  const claimed = await query(
    'claim-write-idempotency-key',
    `INSERT INTO public.write_idempotency
       (operation, idempotency_key, request_sha256)
     VALUES ($1, $2, $3)
     ON CONFLICT (operation, idempotency_key) DO NOTHING
     RETURNING operation`,
    [operation, idempotencyKey, requestSha256],
    target,
  );

  if (claimed.rowCount === 0) {
    const existing = await query(
      'read-write-idempotency-result',
      `SELECT request_sha256, response_status, response_body
       FROM public.write_idempotency
       WHERE operation = $1 AND idempotency_key = $2
       FOR UPDATE`,
      [operation, idempotencyKey],
      target,
    );
    const record = existing.rows[0];
    if (!record || record.request_sha256 !== requestSha256) {
      throw httpError(
        409,
        'idempotency_key_reused',
        'Idempotency-Key was already used for a different request.',
      );
    }
    if (record.response_status === null || record.response_body === null) {
      throw httpError(
        409,
        'idempotency_in_progress',
        'The original idempotent request has not completed.',
      );
    }
    return { replayed: true, value: record.response_body };
  }

  const value = await callback();
  await query(
    'complete-write-idempotency-key',
    `UPDATE public.write_idempotency
     SET response_status = $3,
         response_body = $4::jsonb,
         completed_at = clock_timestamp()
     WHERE operation = $1 AND idempotency_key = $2`,
    [operation, idempotencyKey, responseStatus, JSON.stringify(value)],
    target,
  );
  return { replayed: false, value };
}

export function fingerprintRequest(request) {
  return createHash('sha256').update(JSON.stringify(request)).digest('hex');
}
