import 'dart:typed_data';

Future<Uint8List?> pickMissionPhoto({required bool camera}) async {
  throw UnsupportedError(
    'Acquisizione non disponibile su questa piattaforma. Usa il profilo web locale con immagini sintetiche.',
  );
}
