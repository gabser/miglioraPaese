import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/game/data/api_game_repository.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/logic/play_cubit.dart';

class NoReflectionRepository extends MockGameRepository
    implements GameRepositoryCapabilities {
  @override
  bool get supportsReflection => false;
  @override
  bool get supportsSignals => false;
  @override
  Future<ReflectionQuestion> getReflectionQuestion(String problemId) =>
      throw StateError('Unavailable action was requested');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'API advertises disabled unsupported actions without network or mock fallback',
    () async {
      final api = ApiGameRepository(
        client: ApiClient(
          baseUrl: Uri.parse('http://localhost'),
          client: MockClient(
            (_) => throw StateError('Unsupported action called network'),
          ),
        ),
        userId: 'local',
      );
      expect(api.supportsReflection, isFalse);
      expect(api.supportsSignals, isFalse);
      expect(
        () => api.getReflectionQuestion('problem'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.tapSignal(problemId: 'problem', resolved: true),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'play loads with unavailable reflection omitted, preserving the game',
    () async {
      SharedPreferences.setMockInitialValues({
        'municipality_id': 'comune:Bologna',
      });
      final prefs = AppPrefs(await SharedPreferences.getInstance());
      final repo = NoReflectionRepository();
      final cubit = PlayCubit(repository: repo, prefs: prefs);
      addTearDown(cubit.close);
      addTearDown(repo.dispose);
      addTearDown(prefs.dispose);
      await cubit.load();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.problems, isNotEmpty);
      expect(cubit.state.reflectionQuestions, isEmpty);
    },
  );
}
