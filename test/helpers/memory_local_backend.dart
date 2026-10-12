import 'package:fanta_comune/core/persistence/local_data_store.dart';

class MemoryLocalBackend implements LocalDataBackend {
  final Map<String, String> values = {};
  Future<bool> Function(String key, String value)? onWrite;
  Future<bool> Function()? onClear;
  int writeCalls = 0;
  @override
  String? readString(String key) => values[key];
  @override
  Future<bool> writeString(String key, String value) async {
    writeCalls++;
    final result = await (onWrite?.call(key, value) ?? Future.value(true));
    if (result) values[key] = value;
    return result;
  }

  @override
  Future<bool> clear() async {
    final result = await (onClear?.call() ?? Future.value(true));
    if (result) values.clear();
    return result;
  }
}
