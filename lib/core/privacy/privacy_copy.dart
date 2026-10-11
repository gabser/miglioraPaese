/// Copy centralizzato per messaggi di privacy e tono del prodotto.
class PrivacyCopy {
  const PrivacyCopy._();

  /// Nome dell'applicazione.
  static const String appName = 'Fanta Comune';

  /// Micropitch breve per spiegare lo scopo del gioco civico.
  static const String micropitch =
      'Il Fantacalcio dei problemi del tuo Comune.';

  /// Avvertenza che chiarisce il carattere probabilistico e non ufficiale.
  static const String disclaimer =
      'È un gioco probabilistico basato su percezioni aggregate: non è una segnalazione ufficiale e non certifica la realtà.';

  /// Principi di privacy-by-design sintetizzati in elenco.
  static const List<String> principles = [
    'Niente foto e nessun dato sensibile richiesto',
    'Nessun dato sensibile richiesto',
    'Bozze, proposte e voti della demo restano su questo dispositivo e sono cancellabili dalla pagina Privacy',
    'Il pilot API invia ID locale, Comune, proposte e voti al server configurato',
    'Obiettivo: consapevolezza e confronto, non reclami',
  ];
}
