export function httpError(statusCode, code, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  return error;
}

export function fieldError(field, publicCode, message) {
  const error = httpError(400, 'invalid_field', message);
  error.fieldErrors = { [field]: publicCode };
  return error;
}
