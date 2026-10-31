import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';

void main() {
  test(
    'reads only stable field codes, independently of server message language',
    () async {
      final api = ApiClient(
        baseUrl: Uri.parse('https://example.test'),
        client: MockClient(
          (_) async => http.Response(
            '{"error":"invalid_field","message":"Untrusted English message","fieldErrors":{"title":"too_long","location.label":"invalid_text","description":"private_reason","category":7}}',
            400,
          ),
        ),
      );
      await expectLater(
        () => api.postJson(['v1', 'items'], body: const {}),
        throwsA(
          isA<ApiException>().having((e) => e.fieldErrors, 'stable fields', {
            'title': 'too_long',
            'location.label': 'invalid_text',
          }),
        ),
      );
    },
  );

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

  test('reads server Retry-After without inventing a countdown', () async {
    for (final sample in [
      (
        '{"error":"submission_rate_limited","message":"Limit","retryAfterSeconds":42}',
        <String, String>{},
        42,
      ),
      (
        '{"error":"submission_rate_limited","message":"Limit"}',
        <String, String>{'retry-after': '17'},
        17,
      ),
      (
        '{"error":"submission_rate_limited","message":"Limit","retryAfterSeconds":-1}',
        <String, String>{},
        null,
      ),
    ]) {
      final api = ApiClient(
        baseUrl: Uri.parse('https://example.test'),
        client: MockClient(
          (_) async => http.Response(sample.$1, 429, headers: sample.$2),
        ),
      );
      await expectLater(
        () => api.postJson(['v1', 'items'], body: const {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.retryAfterSeconds,
            'retry delay',
            sample.$3,
          ),
        ),
      );
    }
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

  test('retries an idempotent write once with the same key', () async {
    var attempts = 0;
    final capturedKeys = <String?>[];
    final api = ApiClient(
      baseUrl: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        attempts++;
        capturedKeys.add(request.headers['idempotency-key']);
        if (attempts == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        return http.Response('{"ok":true}', 200);
      }),
      timeout: const Duration(milliseconds: 5),
    );

    final payload = await api.postJson(
      ['v1', 'items'],
      headers: const {'Idempotency-Key': 'flutter-test-key'},
      body: const {'title': 'Parco'},
    );

    expect(payload, {'ok': true});
    expect(attempts, 2);
    expect(capturedKeys, ['flutter-test-key', 'flutter-test-key']);
  });
}
