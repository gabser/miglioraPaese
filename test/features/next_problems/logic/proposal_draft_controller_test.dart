import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_draft_controller.dart';
import '../../../helpers/memory_local_backend.dart';

ProposalScope scope(
  LocalDataStore storage, {
  String municipality = 'comune:Bologna',
  AppConfig? config,
}) => ProposalScope.fromConfig(
  municipalityId: municipality,
  config: config ?? AppConfig.fromValues(),
  namespace: storage.namespace,
);

void main() {
  test(
    'raw over-limit drafts and incomplete location survive wrapper/controller reconstruction',
    () async {
      final backend = MemoryLocalBackend();
      final local = LocalDataStore(backend: backend);
      final controller = ProposalDraftController(
        store: ProposalDraftStore(local),
        scope: scope(local),
      );
      final text = '  ${List.filled(130, '😀').join()}  ';
      controller.edit(
        ProposalDraft(
          title: text,
          description: ' Descrizione ',
          category: ProblemKey.green,
          locationKind: ProposalLocationKind.specific,
          locationLabel: ' ',
          civic: '12/A',
          reference: ' Ingresso nord ',
        ),
      );
      expect(await controller.flush(), isTrue);
      expect(controller.status, DraftSaveStatus.saved);
      controller.dispose();
      final restoredLocal = LocalDataStore(backend: backend);
      final restored = ProposalDraftController(
        store: ProposalDraftStore(restoredLocal),
        scope: scope(restoredLocal),
      );
      expect(restored.status, DraftSaveStatus.restored);
      expect(restored.draft.title, text);
      expect(restored.draft.locationLabel, ' ');
      expect(restored.draft.civic, '12/A');
      expect(restored.draft.reference, ' Ingresso nord ');
    },
  );

  test(
    'scope isolates municipalities, source, API origin/path and installation',
    () async {
      final backend = MemoryLocalBackend();
      final local = LocalDataStore(backend: backend);
      final store = ProposalDraftStore(local);
      final original = scope(local);
      expect(original, scope(local, municipality: 'COMUNE: bologna'));
      await store.save(
        original,
        const ProposalDraft(title: 'Bologna', revision: 1),
        epoch: local.epoch,
      );
      final alternatives = [
        scope(local, municipality: 'comune:Roma'),
        scope(
          local,
          config: AppConfig.fromValues(nextProblemsDataSource: 'api'),
        ),
        scope(
          local,
          config: AppConfig.fromValues(apiBaseUrl: 'https://example.test'),
        ),
        scope(
          local,
          config: AppConfig.fromValues(
            apiBaseUrl: 'http://127.0.0.1:8787/root',
          ),
        ),
      ];
      for (final other in alternatives) expect(store.load(other), isNull);
      final foreign = LocalDataStore(
        backend: backend,
        key: 'foreign-installation',
      );
      expect(ProposalDraftStore(foreign).load(scope(foreign)), isNull);
      expect(store.load(original)!.title, 'Bologna');
    },
  );

  test(
    'an old successful submission cannot delete a newer draft from another controller',
    () async {
      final local = LocalDataStore(backend: MemoryLocalBackend());
      final store = ProposalDraftStore(local);
      final first = ProposalDraftController(store: store, scope: scope(local));
      final second = ProposalDraftController(store: store, scope: scope(local));
      first.edit(const ProposalDraft(title: 'Invio precedente'));
      expect(await first.flush(), isTrue);
      final sentRevision = first.draft.revision;
      second.edit(const ProposalDraft(title: 'Nuova bozza'));
      expect(await second.flush(), isTrue);
      expect(second.draft.revision, greaterThan(sentRevision));
      expect(await first.deleteSentRevision(sentRevision), isFalse);
      expect(store.load(scope(local))!.title, 'Nuova bozza');
    },
  );

  test(
    'failed writes never say saved, retry persists the same revision and exit flush waits for new edits',
    () async {
      final backend = MemoryLocalBackend()..onWrite = (_, _) async => false;
      final local = LocalDataStore(backend: backend);
      final controller = ProposalDraftController(
        store: ProposalDraftStore(local),
        scope: scope(local),
      );
      controller.edit(const ProposalDraft(title: 'Da conservare'));
      expect(await controller.flush(), isFalse);
      expect(controller.status, DraftSaveStatus.failed);
      final revision = controller.draft.revision;
      backend.onWrite = null;
      controller.retry();
      expect(await controller.flush(), isTrue);
      expect(controller.status, DraftSaveStatus.saved);
      expect(controller.draft.revision, revision);
      final entered = Completer<void>();
      final release = Completer<bool>();
      backend.onWrite = (_, _) {
        if (!entered.isCompleted) entered.complete();
        return release.future;
      };
      controller.edit(const ProposalDraft(title: 'Seconda'));
      final flush = controller.flush();
      await entered.future;
      controller.edit(const ProposalDraft(title: 'Ultima'));
      release.complete(true);
      expect(await flush, isTrue);
      expect(ProposalDraftStore(local).load(scope(local))!.title, 'Ultima');
    },
  );

  test(
    'dispose allows pending saves to finish, reset cancels them and leaves no recovered draft',
    () async {
      final backend = MemoryLocalBackend();
      final local = LocalDataStore(backend: backend);
      final controller = ProposalDraftController(
        store: ProposalDraftStore(local),
        scope: scope(local),
      );
      controller.edit(const ProposalDraft(title: 'Uscita rapida'));
      controller.dispose();
      await local.flush();
      expect(
        ProposalDraftStore(local).load(scope(local))!.title,
        'Uscita rapida',
      );
      final current = ProposalDraftController(
        store: ProposalDraftStore(local),
        scope: scope(local),
      );
      final entered = Completer<void>();
      final release = Completer<bool>();
      backend.onWrite = (_, _) {
        entered.complete();
        return release.future;
      };
      current.edit(const ProposalDraft(title: 'Da cancellare'));
      await entered.future;
      final reset = local.reset();
      expect(current.status, DraftSaveStatus.reset);
      current.edit(const ProposalDraft(title: 'Tardiva'));
      release.complete(true);
      await reset;
      expect(await current.flush(), isFalse);
      expect(ProposalDraftStore(local).load(scope(local)), isNull);
    },
  );

  test(
    'corrupt draft does not claim restoration or overwrite its original data',
    () async {
      final local = LocalDataStore(backend: MemoryLocalBackend());
      final s = scope(local);
      await local.mutate(
        'draft:${s.key}',
        (_) => const LocalDataMutation({'version': 99}, true),
      );
      final controller = ProposalDraftController(
        store: ProposalDraftStore(local),
        scope: s,
      );
      expect(controller.status, DraftSaveStatus.failed);
      expect(await controller.flush(), isFalse);
      controller.edit(const ProposalDraft(title: 'Testo nuovo'));
      expect(await controller.flush(), isFalse);
      expect(local.read('draft:${s.key}'), {'version': 99});
    },
  );
}
