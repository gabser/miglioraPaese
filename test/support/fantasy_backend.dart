import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CookieClient extends http.BaseClient {
  final http.Client inner = http.Client();
  String? cookie;
  bool loseTransferReply = false;
  Completer<void>? teamReplyArrived;
  Completer<void>? teamReplyGate;
  int sessionCreations = 0;
  bool offline = false;
  bool loseLeagueReply = false;
  final List<String> leagueKeys = [];
  bool refuseDeletion = false;
  final List<String> keys = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('offline');
    if (refuseDeletion && request.method == 'DELETE') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode('{"error":"unavailable","message":"Riprova"}'),
        ),
        503,
      );
    }
    if (cookie != null) request.headers['cookie'] = cookie!;
    if (request.method == 'POST' && request.url.path == '/v1/proposal-session')
      sessionCreations++;
    final response = await inner.send(request);
    if (request.method == 'PUT' &&
        request.url.path.endsWith('/team') &&
        teamReplyGate != null) {
      teamReplyArrived?.complete();
      await teamReplyGate!.future;
    }
    cookie = response.headers['set-cookie']?.split(';').first ?? cookie;
    if (request.method == 'POST' && request.url.path.endsWith('/leagues')) {
      leagueKeys.add(
        (jsonDecode((request as http.Request).body) as Map)['idempotencyKey']
            as String,
      );
      if (loseLeagueReply) {
        loseLeagueReply = false;
        await response.stream.drain<void>();
        throw http.ClientException('lost league reply');
      }
    }
    if (request.url.path.endsWith('/transfers/confirmation')) {
      keys.add(
        (jsonDecode((request as http.Request).body) as Map)['idempotencyKey']
            as String,
      );
      if (loseTransferReply) {
        loseTransferReply = false;
        await response.stream.drain<void>();
        throw http.ClientException('reply lost after commit');
      }
    }
    return response;
  }

  @override
  void close() => inner.close();
}

class BackendFixture {
  late Process process;
  late StreamIterator<String> lines;
  late String url;
  final StringBuffer _stderr = StringBuffer();
  Future<void> start() async {
    final node = Platform.environment['FANTASY_TEST_NODE'] ?? 'node';
    process = await Process.start(node, [
      'test/support/fantasy_backend_fixture.mjs',
    ]);
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    url = (await read())['url'] as String;
  }

  Future<Map<String, dynamic>> read() async {
    final available = await lines.moveNext().timeout(
      const Duration(seconds: 15),
    );
    if (!available)
      throw StateError('Fantasy PostgreSQL fixture exited: $_stderr');
    return (jsonDecode(lines.current) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> privateCommand(
    String action, [
    Object? value,
  ]) async {
    process.stdin.writeln(jsonEncode({'action': action, 'value': value}));
    return read();
  }

  Future<String> accountCode(String email) async {
    process.stdin.writeln(
      jsonEncode({'action': 'accountCode', 'value': email}),
    );
    final result = await read();
    if (result['code'] is! String)
      throw StateError('Missing synthetic delivery');
    return result['code'] as String;
  }

  Future<void> command(String action, [String? value]) async {
    process.stdin.writeln(jsonEncode({'action': action, 'value': value}));
    final result = await read();
    if (result['error'] != null) throw StateError(result['error'] as String);
    if (result['url'] != null) url = result['url'] as String;
  }

  Future<void> stop() async {
    process.stdin.writeln('{"action":"stop"}');
    await process.stdin.close();
    await process.exitCode.timeout(const Duration(seconds: 10));
    await lines.cancel();
  }
}
