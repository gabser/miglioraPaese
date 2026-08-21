import 'package:equatable/equatable.dart';

/// Domanda di riflessione leggera legata a un problema.
class ReflectionQuestion extends Equatable {
  /// Crea una domanda con tre opzioni e un follow-up opzionale.
  const ReflectionQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.followUpCopy,
  });

  /// Identificativo stabile della domanda.
  final String id;

  /// Testo principale della domanda.
  final String prompt;

  /// Opzioni di risposta (attese 3).
  final List<String> options;

  /// Copy di follow-up mostrata dopo la selezione.
  final String followUpCopy;

  @override
  List<Object?> get props => [id, prompt, options, followUpCopy];
}
