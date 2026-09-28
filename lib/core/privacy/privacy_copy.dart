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
    'Niente foto; titolo e descrizione della proposta sono gli unici testi liberi',
    'Nessun dato sensibile richiesto',
    'Le preferenze demo sono cancellabili; lo stato mock si azzera ricaricando l\'app',
    'Il pilot usa una sessione anonima firmata; l\'ID locale non è accettato come identità dal server',
    'Voti, previsioni ed esiti del pilot associati alla sessione possono essere cancellati',
    'Obiettivo: consapevolezza e confronto, non reclami',
  ];
}
