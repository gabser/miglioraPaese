import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';

void main() {
  test('decodes successful JSON and preserves base path and query', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response('{"items":[]}', 200);
    });
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test/api-root'),
      client: client,
    );

    final payload = await api.getJson(
      ['v1', 'municipalities', 'castel bolognese'],
      queryParameters: const {'query': 'parco nord', 'ignored': null},
    );

    expect(payload, {'items': <Object>[]});
    expect(requestedUri.pathSegments, [
      'api-root',
      'v1',
      'municipalities',
      'castel bolognese',
    ]);
    expect(requestedUri.queryParameters, {'query': 'parco nord'});
  });

  test('preserves structured backend errors', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response(
          '{"error":"duplicate_title","message":"Already exists."}',
          409,
        ),
      ),
    );

    expect(
      () => api.postJson(['v1', 'items'], body: const {'title': 'Parco'}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiExceptionKind.response)
            .having((error) => error.code, 'code', 'duplicate_title')
            .having((error) => error.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('sends PUT requests as JSON', () async {
    late http.Request captured;
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"status":"ok"}', 200);
      }),
    );

    await api.putJson(
      ['v1', 'items', 'item/with space'],
      body: const {'choice': 'stable'},
    );

    expect(captured.method, 'PUT');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {'choice': 'stable'});
    expect(captured.url.pathSegments.last, 'item/with space');
  });

  test('rejects malformed success JSON', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test'),
      client: MockClient((_) async => http.Response('<html>', 200)),
    );

    expect(
      () => api.getJson(['v1', 'items']),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiExceptionKind.invalidPayload,
        ),
      ),
    );
  });

  test('keeps non-JSON server errors typed as retryable responses', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test'),
      client: MockClient((_) async => http.Response('<html>', 502)),
    );

    expect(
      () => api.getJson(['v1', 'items']),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiExceptionKind.response)
            .having((error) => error.statusCode, 'statusCode', 502)
            .having((error) => error.isRetryable, 'isRetryable', isTrue),
      ),
    );
  });

  test('turns a slow request into a typed timeout', () async {
    final response = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test'),
      client: MockClient((_) => response.future),
      timeout: const Duration(milliseconds: 1),
    );

    expect(
      () => api.getJson(['v1', 'items']),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiExceptionKind.timeout)
            .having((error) => error.code, 'code', 'request_timeout'),
      ),
    );
  });
}
