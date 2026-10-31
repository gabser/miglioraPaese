import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('document.createElement')
external JSObject _createElement(JSString name);
Future<Uint8List?> pickMissionPhoto({required bool camera}) async {
  final input = _createElement('input'.toJS);
  input.setProperty('type'.toJS, 'file'.toJS);
  input.setProperty('accept'.toJS, 'image/png,image/jpeg'.toJS);
  if (camera) input.setProperty('capture'.toJS, 'environment'.toJS);
  final result = Completer<Uint8List?>();
  input.callMethod(
    'addEventListener'.toJS,
    'cancel'.toJS,
    (() {
      if (!result.isCompleted) result.complete(null);
    }).toJS,
  );
  Future<void> readSelection() async {
    try {
      final files = input.getProperty<JSObject>('files'.toJS);
      if (files.getProperty<JSNumber>('length'.toJS).toDartInt == 0) {
        if (!result.isCompleted) result.complete(null);
        return;
      }
      final file = files.callMethod<JSObject>('item'.toJS, 0.toJS);
      if (file.getProperty<JSNumber>('size'.toJS).toDartInt > 2 * 1024 * 1024)
        throw StateError(
          'File troppo grande: massimo 2 MB prima della normalizzazione.',
        );
      final bytes = await file
          .callMethod<JSPromise<JSArrayBuffer>>('arrayBuffer'.toJS)
          .toDart;
      if (!result.isCompleted) result.complete(bytes.toDart.asUint8List());
    } catch (error) {
      if (!result.isCompleted) result.completeError(error);
    }
  }

  input.callMethod(
    'addEventListener'.toJS,
    'change'.toJS,
    (() {
      unawaited(readSelection());
    }).toJS,
  );
  input.callMethod('click'.toJS);
  return result.future;
}
