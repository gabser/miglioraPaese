# Design system civico

## Font e ruoli

`lib/core/theme/app_theme.dart` definisce il tema runtime: famiglia Manrope,
scala tipografica, pesi, interlinea e spaziatura. Il corpo del testo usa 16 px;
le informazioni secondarie 14 px. Titoli di sezione e pannelli usano i ruoli
`titleLarge`/`titleMedium`, senza ricorrere allo stile implicito del widget.
I testi descrittivi hanno letter spacing 0 per evitare l’aspetto troppo dilatato.
`TypographyX` deriva dal tema e applica soltanto gli adattamenti compatti.

Cambiare un ruolo nel tema aggiorna tutti i componenti che lo consumano.
Un override locale intenzionale (per esempio testo bianco su un pannello navy)
continua ad avere precedenza per le proprietà specificate.

## Superfici e componenti

- `AppTokens`: valori condivisi di colori, spaziature, raggi e breakpoint.
- `ColorScheme`: significato dei colori nel tema attivo.
- `FcPanel`: pannello generico; può avere una tinta decorativa.
- `FcPageHeader`: titolo principale con contesto del Comune, distinto dalla navigazione.
- `FcSectionHeader`: titolo/sottotitolo di sezione.
- `FcDisclosure`: sezione espandibile con titolo `titleMedium` e superficie
  definita da `ExpansionTileThemeData`, non dalla singola pagina.
- `FcSummaryPanel`: riepilogo civico condiviso tra Home e Gioca. Sfondo pieno
  `secondaryContainer`, bordo `secondary`, titolo `onSecondaryContainer`, testo
  `onSurface`. Nessuna sfumatura locale.

Il Tabellone usa `bodyMedium` per filtri e metadati dei problemi. I controlli
input derivano etichette, suggerimenti e aiuti da `InputDecorationTheme`.

## Token di riferimento e verifiche

`assets/tokens.json` descrive il sistema per gli altri strumenti: non è un
configuratore letto per costruire il tema. Quando si cambia il tema Dart,
aggiornare questo riferimento; i test controllano l’allineamento della scala.

`test/core/widgets/fc_widgets_test.dart` verifica anche la propagazione di una
variante del tema a contenuto, titolo e sfondo dei riepiloghi condivisi.
Dopo un cambio globale verificare tutta la suite Flutter e le schermate a testo
ingrandito: una tipografia diversa cambia l’altezza dei contenuti e lo scroll.

Manrope è distribuito come asset locale nei pesi 400–800, senza richieste a Google Fonts a runtime. Fonte e licenza sono in `assets/fonts/manrope/`.

## Navigazione

La sidebar personalizzata legge `NavigationRailThemeData` dal tema, come la
navigazione desktop standard: `titleSmall` (16 px), peso 700 nelle voci inattive,
800 in quella selezionata. Modificare gli stili selected/unselected nel tema
aggiorna entrambe. La navigazione mobile usa `labelMedium` (12 px), con la stessa
famiglia e la stessa gerarchia di pesi.
