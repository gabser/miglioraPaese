/// Stato complessivo di un turno di gioco.
enum TurnState {
  /// Il turno è aperto e accetta nuove previsioni.
  open,

  /// Il turno è in fase di calcolo risultati.
  calculating,

  /// Il turno è chiuso e non accetta altre modifiche.
  closed,
}
