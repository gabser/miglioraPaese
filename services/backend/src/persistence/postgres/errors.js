import { httpError } from '../../domain/errors.js';

export function translatePostgresWriteError(error, operation) {
  if (error?.statusCode) return error;

  if (
    operation === 'upsert_prediction' &&
    error?.code === '23514' &&
    error?.constraint === 'predictions_choice_immutable'
  ) {
    return httpError(
      409,
      'prediction_locked',
      'Prediction choice is already locked for this turn.',
    );
  }

  if (operation === 'vote_suggestion' && error?.code === '23503') {
    return httpError(
      409,
      'promotion_in_use',
      'The promoted problem is already in use.',
    );
  }

  if (['23505', '40001', '40P01', '55P03'].includes(error?.code)) {
    return httpError(
      409,
      'write_conflict',
      'The write conflicted with another operation. Retry the request.',
    );
  }

  return error;
}
