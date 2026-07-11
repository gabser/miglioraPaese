enum ApiExceptionKind {
  configuration,
  network,
  timeout,
  response,
  invalidPayload,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
    this.cause,
  });

  factory ApiException.configuration({
    required String code,
    required String message,
  }) {
    return ApiException(
      kind: ApiExceptionKind.configuration,
      code: code,
      message: message,
    );
  }

  factory ApiException.invalidPayload(String message, {Object? cause}) {
    return ApiException(
      kind: ApiExceptionKind.invalidPayload,
      code: 'invalid_payload',
      message: message,
      cause: cause,
    );
  }

  final ApiExceptionKind kind;
  final String code;
  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isRetryable =>
      kind == ApiExceptionKind.network ||
      kind == ApiExceptionKind.timeout ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() {
    final status = statusCode == null ? '' : ', status: $statusCode';
    return 'ApiException(code: $code$status, message: $message)';
  }
}
