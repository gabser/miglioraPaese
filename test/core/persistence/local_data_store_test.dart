import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import '../../helpers/memory_local_backend.dart';

void main() {
  test(
    'scope guard rollback failure blocks all access until explicit reset',
    () async {
      final backend = MemoryLocalBackend();
      final store = LocalDataStore(backend: backend);
      await store.mutate(
        'draft',
        (_) => const LocalDataMutation('prior', true),
      );
      var changed = false, writes = 0;
      backend.onWrite = (_, __) async {
        writes++;
        changed = true;
        return writes == 1;
      };
      await expectLater(
        store.mutate(
          'draft',
          (_) => const LocalDataMutation('stale', true),
          check: () {
            if (changed) throw const LocalDataResetException();
          },
        ),
        throwsA(isA<LocalDataWriteException>()),
      );
      expect(
        () => store.read('draft'),
        throwsA(isA<LocalDataResetException>()),
      );
      await expectLater(
        store.mutate('later', (_) => const LocalDataMutation('blocked', true)),
        throwsA(isA<LocalDataResetException>()),
      );
      backend.onWrite = null;
      await store.reset();
      expect(store.read('draft'), isNull);
    },
  );
  test(
    'scope guard rollback exception blocks all access until explicit reset',
    () async {
      final backend = MemoryLocalBackend();
      final store = LocalDataStore(backend: backend);
      await store.mutate(
        'draft',
        (_) => const LocalDataMutation('prior', true),
      );
      var changed = false, writes = 0;
      backend.onWrite = (_, __) async {
        writes++;
        changed = true;
        if (writes != 1) throw StateError('synthetic disk failure');
        return true;
      };
      await expectLater(
        store.mutate(
          'draft',
          (_) => const LocalDataMutation('stale', true),
          check: () {
            if (changed) throw const LocalDataResetException();
          },
        ),
        throwsA(isA<LocalDataWriteException>()),
      );
      expect(
        () => store.read('draft'),
        throwsA(isA<LocalDataResetException>()),
      );
      await expectLater(
        store.mutate('later', (_) => const LocalDataMutation('blocked', true)),
        throwsA(isA<LocalDataResetException>()),
      );
      backend.onWrite = null;
      await store.reset();
      expect(store.read('draft'), isNull);
    },
  );
  test(
    'serializes changes and reconstructs an isolated snapshot with the same namespace',
    () async {
      final backend = MemoryLocalBackend();
      final store = LocalDataStore(backend: backend);
      final first = store.mutate(
        'first',
        (_) => const LocalDataMutation({'text': 'Prima'}, true),
      );
      final second = store.mutate(
        'second',
        (_) => const LocalDataMutation({'text': 'Seconda'}, true),
      );
      await Future.wait([first, second]);
      final restored = LocalDataStore(backend: backend);
      expect(restored.namespace, store.namespace);
      expect(restored.read('first'), {'text': 'Prima'});
      expect(restored.read('second'), {'text': 'Seconda'});
      (restored.read('first') as Map)['text'] = 'Mutazione esterna';
      expect(restored.read('first'), {'text': 'Prima'});
    },
  );

  test(
    'failed write never publishes or replaces committed data and can be retried',
    () async {
      final backend = MemoryLocalBackend();
      final store = LocalDataStore(backend: backend);
      await store.mutate(
        'draft',
        (_) => const LocalDataMutation('Originale', true),
      );
      backend.onWrite = (_, _) async => false;
      await expectLater(
        store.mutate('draft', (_) => const LocalDataMutation('Nuova', true)),
        throwsA(isA<LocalDataWriteException>()),
      );
      expect(store.read('draft'), 'Originale');
      expect(LocalDataStore(backend: backend).read('draft'), 'Originale');
      backend.onWrite = null;
      await store.mutate(
        'draft',
        (_) => const LocalDataMutation('Nuova', true),
      );
      expect(LocalDataStore(backend: backend).read('draft'), 'Nuova');
    },
  );

  test(
    'reset waits for in-flight data and prevents queued or late work from resurrecting it',
    () async {
      final backend = MemoryLocalBackend();
      final store = LocalDataStore(backend: backend);
      final namespace = store.namespace;
      final entered = Completer<void>();
      final release = Completer<bool>();
      backend.onWrite = (_, _) {
        entered.complete();
        return release.future;
      };
      final first = store.mutate(
        'draft',
        (_) => const LocalDataMutation('Vecchia', true),
      );
      final firstCheck = expectLater(
        first,
        throwsA(isA<LocalDataResetException>()),
      );
      final queued = store.mutate(
        'other',
        (_) => const LocalDataMutation('In coda', true),
      );
      final queuedCheck = expectLater(
        queued,
        throwsA(isA<LocalDataResetException>()),
      );
      await entered.future;
      final oldEpoch = store.epoch;
      final reset = store.reset();
      await expectLater(
        store.mutate('late', (_) => const LocalDataMutation('Tardiva', true)),
        throwsA(isA<LocalDataResetException>()),
      );
      release.complete(true);
      await Future.wait([firstCheck, queuedCheck, reset]);
      expect(backend.values, isEmpty);
      expect(backend.writeCalls, 1);
      expect(store.namespace, isNot(namespace));
      expect(store.read('draft'), isNull);
      backend.onWrite = null;
      await expectLater(
        store.run(() async => true, expectedEpoch: oldEpoch),
        throwsA(isA<LocalDataResetException>()),
      );
      await store.mutate(
        'new',
        (_) => const LocalDataMutation('Dopo reset', true),
      );
      expect(LocalDataStore(backend: backend).read('new'), 'Dopo reset');
    },
  );

  test(
    'a failed clear reports failure and blocks mutations until a successful retry',
    () async {
      final backend = MemoryLocalBackend();
      final store = LocalDataStore(backend: backend);
      await store.mutate(
        'draft',
        (_) => const LocalDataMutation('Testo', true),
      );
      backend.onClear = () async => false;
      await expectLater(store.reset(), throwsA(isA<LocalDataWriteException>()));
      expect(
        () => store.read('draft'),
        throwsA(isA<LocalDataResetException>()),
      );
      await expectLater(
        store.mutate('late', (_) => const LocalDataMutation('Nuova', true)),
        throwsA(isA<LocalDataResetException>()),
      );
      backend.onClear = null;
      await store.reset();
      expect(store.read('draft'), isNull);
    },
  );

  test(
    'corrupt data is preserved rather than overwritten and explicit reset recovers the store',
    () async {
      final backend = MemoryLocalBackend()
        ..values['proposal_local_data_v1'] = '{broken';
      final store = LocalDataStore(backend: backend);
      expect(
        () => store.read('draft'),
        throwsA(isA<LocalDataCorruptException>()),
      );
      await expectLater(
        store.mutate('draft', (_) => const LocalDataMutation('Testo', true)),
        throwsA(isA<LocalDataCorruptException>()),
      );
      expect(backend.values['proposal_local_data_v1'], '{broken');
      expect(backend.writeCalls, 0);
      await store.reset();
      await store.mutate(
        'draft',
        (_) => const LocalDataMutation('Testo', true),
      );
      expect(store.read('draft'), 'Testo');
    },
  );
}
