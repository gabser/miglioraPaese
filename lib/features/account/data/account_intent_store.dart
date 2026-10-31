import 'package:fanta_comune/core/persistence/local_data_store.dart';

/// A navigation intention, never an invitation token or a competitive command.
class AccountIntentStore {
  AccountIntentStore(this.data, String environment)
    : key = 'account-return-intent:$environment';
  final LocalDataStore data;
  final String key;
  static const destinations = {
    '/home',
    '/profile',
    '/squad',
    '/matchday',
    '/leagues',
    '/league-invite',
    '/missions',
    '/review',
    '/measurements',
    '/measurements/workspace',
    '/xp',
  };
  static bool allows(String route) =>
      destinations.contains(route) ||
      RegExp(
        r'^/measurements/(?:workspace/)?evaluations/[a-zA-Z0-9_-]{1,80}$',
      ).hasMatch(route) ||
      RegExp(
        r'^/(missions|observations|review)/[a-zA-Z0-9_-]{1,80}$',
      ).hasMatch(route) ||
      RegExp(
        r'^/missions/[a-zA-Z0-9_-]{1,80}\?bookingId=[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(route);
  Future<void> remember(String route) async {
    if (!allows(route)) throw ArgumentError.value(route, 'route');
    await data.mutate<void>(
      key,
      (_) =>
          LocalDataMutation({'kind': 'navigation', 'destination': route}, null),
    );
  }

  Future<String?> consume() async => data.mutate<String?>(key, (raw) {
    if (raw == null) return const LocalDataMutation(null, null);
    if (raw is! Map ||
        raw['kind'] != 'navigation' ||
        raw['destination'] is! String ||
        !allows(raw['destination'] as String))
      throw const LocalDataCorruptException();
    return LocalDataMutation(null, raw['destination'] as String);
  });
}
