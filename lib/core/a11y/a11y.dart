import 'package:flutter/material.dart';

/// Helper minimalisti per migliorare l'accessibilità senza boilerplate.
Widget semanticsButton({required String label, required Widget child}) {
  return Semantics(button: true, label: label, child: child);
}

/// Wrapper per icone interattive con tooltip descrittivo.
Widget iconTooltip({required String message, required Widget child}) {
  return Tooltip(message: message, child: child);
}

/// Gruppo di focus per controllare la navigazione da tastiera.
Widget focusGroup({required Widget child}) {
  return FocusTraversalGroup(child: child);
}
