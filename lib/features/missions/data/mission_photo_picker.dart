import 'dart:typed_data';
import 'dart:ui' as ui;
import 'mission_photo_picker_stub.dart'
    if (dart.library.js_interop) 'mission_photo_picker_web.dart'
    as platform;
import 'mission_draft_store.dart';

abstract interface class MissionPhotoPicker {
  Future<Uint8List?> pick({required bool camera});
}

class DeviceMissionPhotoPicker implements MissionPhotoPicker {
  @override
  Future<Uint8List?> pick({required bool camera}) =>
      platform.pickMissionPhoto(camera: camera);
}

class MissionPhotoNormalizer {
  static Future<Uint8List> normalize(Uint8List source) async {
    if (source.isEmpty || source.length > 2 * 1024 * 1024)
      throw StateError('Scegli un file PNG o JPEG sintetico di massimo 2 MB.');
    final png =
        source.length >= 8 &&
        source[0] == 137 &&
        source[1] == 80 &&
        source[2] == 78 &&
        source[3] == 71;
    final jpeg =
        source.length >= 3 &&
        source[0] == 255 &&
        source[1] == 216 &&
        source[2] == 255;
    if (!png && !jpeg)
      throw StateError('Formato non valido: scegli PNG o JPEG.');
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(source);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width * descriptor.height > 16000000)
        throw StateError(
          'Immagine troppo grande: massimo 16 milioni di pixel.',
        );
      final largest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final factor = largest > 1280 ? 1280 / largest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * factor).round(),
        targetHeight: (descriptor.height * factor).round(),
      );
      image = (await codec.getNextFrame()).image;
      final raw = await image.toByteData(format: ui.ImageByteFormat.png);
      if (raw == null || raw.lengthInBytes > MissionDraftStore.maxPhotoBytes)
        throw StateError(
          'La prova normalizzata supera 256 KB. Usa un’immagine sintetica più piccola: la bozza è conservata.',
        );
      return Uint8List.fromList(
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
