import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fanta_comune/core/network/api_exception.dart';

class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required http.Client client,
    this.timeout = const Duration(seconds: 8),
  }) : _baseUrl = baseUrl,
       _client = client;

  final Uri _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<Object?> getJson(
    List<String> pathSegments, {
    Map<String, String?> queryParameters = const {},
  }) {
    final uri = _buildUri(pathSegments, queryParameters);
    return _send(() => _client.get(uri));
  }

  Future<Object?> postJson(
    List<String> pathSegments, {
    required Map<String, Object?> body,
  }) {
    final uri = _buildUri(pathSegments, const {});
    return _send(
      () => _client.post(
        uri,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  Uri _buildUri(
    List<String> pathSegments,
    Map<String, String?> queryParameters,
  ) {
    final baseSegments = _baseUrl.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final query = <String, String>{
      for (final entry in queryParameters.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    return _baseUrl.replace(
      pathSegments: [...baseSegments, ...pathSegments],
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<Object?> _send(Future<http.Response> Function() request) async {
    late final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException catch (error) {
      throw ApiException(
        kind: ApiExceptionKind.timeout,
        code: 'request_timeout',
        message: 'Il servizio non ha risposto in tempo.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        kind: ApiExceptionKind.network,
        code: 'network_error',
        message: 'Impossibile raggiungere il servizio.',
        cause: error,
      );
    }

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    late final Object? payload;
    try {
      payload = _decodeJson(response);
    } on ApiException {
      if (isSuccess) rethrow;
      throw ApiException(
        kind: ApiExceptionKind.response,
        code: 'http_error',
        message: 'Il servizio ha restituito un errore.',
        statusCode: response.statusCode,
      );
    }
    if (!isSuccess) {
      final errorBody = payload is Map<String, dynamic> ? payload : null;
      final code = errorBody?['error'];
      final message = errorBody?['message'];
      throw ApiException(
        kind: ApiExceptionKind.response,
        code: code is String && code.isNotEmpty ? code : 'http_error',
        message: message is String && message.isNotEmpty
            ? message
            : 'Il servizio ha restituito un errore.',
        statusCode: response.statusCode,
      );
    }
    return payload;
  }

  Object? _decodeJson(http.Response response) {
    if (response.body.trim().isEmpty) {
      throw ApiException.invalidPayload('La risposta JSON e\' vuota.');
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ApiException.invalidPayload(
        'La risposta non contiene JSON valido.',
        cause: error,
      );
    }
  }
}
