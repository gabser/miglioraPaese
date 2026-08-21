# Fanta Comune mockup implementation plan

## Fonte

- Mockup standalone: [fanta-comune-standalone.html](fanta-comune-standalone.html)
- Flutter Agent Skills: https://docs.flutter.dev/ai/agent-skills
- Repository skills Flutter: https://github.com/flutter/skills

Il file HTML e' una reference visuale di progetto, non un asset runtime dell'app. L'implementazione Flutter deve ricostruire layout, componenti e stati in Dart, mantenendo il codice testabile e performante.

## Direzione prodotto

Il mockup sposta Fanta Comune da uno stile vintage/carta a un prodotto civic game moderno:

- identita' blu/navy con superfici chiare, accenti verdi/gialli/rossi per stato e previsione;
- shell responsive con sidebar desktop/tablet e bottom navigation mobile;
- home dashboard con turno del giorno, problemi prioritari, reputazione, classifica e insight;
- carte problema piu' dense, leggibili e orientate all'azione;
- mobile first, ma con desktop web non trattato come semplice stretch della UI mobile.

## Schermate da sostituire o riallineare

- `BootScreen`: mantenere breve, allineare palette e tipografia.
- `WarmWelcomePage`, `CynicOnboardingPage`, `OnboardingPage`: aggiornare con identita' moderna e scelta Comune piu' compatta.
- `ShellPage`: introdurre shell responsive con sidebar desktop e bottom nav mobile.
- `HomePage`: trasformare in dashboard principale, vicina al mockup.
- `PlayPage`: ridisegnare il turno di gioco con card leggere, progressione chiara e CTA primaria.
- `BoardPage`: tabellone problemi con status, distribuzione previsioni e ordinamento leggibile.
- `LeaderboardPage`: classifica con evidenza utente e ranghi.
- `ProfilePage`: reputazione, livello, accuratezza e storico.
- `NextProblemsPage`: voto problemi prossimi con card compatte e stati.
- `SuggestProblemPage`: form coerente, scrollabile e senza salti layout.
- `HowItWorksPage`, `PrivacyPage`: aggiornamento visuale minimo per coerenza.

## Componenti

### Introdurre

- `FcScaffold`: layout base responsive e background applicativo.
- `FcSidebar`: navigazione desktop/tablet con stato tab attivo.
- `FcBottomNav`: navigazione mobile stabile.
- `FcPanel`: superficie card/pannello standard.
- `FcMetricCard`: metriche sintetiche, reputazione, accuratezza, ranking.
- `FcProblemTile`: problema compatto con categoria, stato, trend e CTA.
- `FcPredictionBar`: barra distribuzione "migliora / stabile / peggiora".
- `FcReputationCard`: livello, punti e avanzamento.
- `FcStatusChip`: stati semantici coerenti.
- `FcSectionHeader`: intestazioni con azione secondaria.
- `FcActionButton`: CTA primaria/secondaria/icon-only.

### Rifattorizzare

- `ProblemCard`: sostituire la composizione pesante con tile/panel piu' leggeri.
- `InsightCard`: ridurre decorazione e separare trend/insight/testo.
- `GameBanner`: riallineare a dashboard e turno del giorno.
- `SegmentedChoice`: mantenere, ma adeguare palette, hit area e stati.
- `TicketProgress`: trasformare in progress line/card piu' moderna.

### Ritirare o limitare

- `VintagePaper`
- `PaperTexture`
- `StampActionButton`
- `StampBadge`
- `StickerBadge`
- `PinnedNote`
- `WaxSealHighlight`

Questi elementi possono restare temporaneamente durante la migrazione, ma non devono essere usati nei nuovi layout principali.

## Piano operativo

### 1. Ingest reference e setup skills

- Tenere il mockup in `docs/design/fanta-comune-standalone.html`.
- Installare i Flutter Agent Skills nel repo prima della PR UI, se vogliamo rendere ripetibile il workflow:

```bash
npx skills add flutter/skills --skill '*' --agent universal
```

- Usare in particolare le skill per responsive layout, layout issues, widget preview, widget test, declarative routing e architecture best practices.

### 2. Design tokens

- Rifare `lib/core/theme/app_tokens.dart` con nuova scala colore:
  - primary navy/blue;
  - success green;
  - warning amber;
  - danger red;
  - neutral grays;
  - surface/background chiari.
- Aggiornare `AppTheme` e `TypographyX` per una gerarchia piu' compatta e leggibile.
- Limitare ombre pesanti, texture e decorazioni per non peggiorare lo scroll.

### 3. Shell responsive

- Rifattorizzare `ShellPage` in mobile/tablet/desktop con breakpoint espliciti.
- Mobile: bottom navigation stabile.
- Desktop/tablet: sidebar sinistra e contenuto centrale con max width.
- Evitare nested scroll inutili: una sola superficie scrollabile per schermata.

### 4. Home dashboard

- Portare `HomePage` verso il mockup:
  - header con Comune e stato turno;
  - card "turno di oggi";
  - lista problemi prioritari;
  - reputazione/classifica/insight come rail desktop o sezioni mobile.
- Estrarre i blocchi in componenti riusabili prima di usarli su altre pagine.

### 4bis. Cold start Comune e primi segnali

Il caso di un Comune senza problemi, segnalazioni o previsioni non deve apparire come una dashboard vuota. Deve diventare un flusso di attivazione esplicito, perche' nei paesi piccoli sara' probabilmente la prima esperienza reale.

- Introdurre uno stato `municipality activation` nei dati mock e poi nelle repository reali:
  - Comune con problemi attivi;
  - Comune senza problemi ma con proposte;
  - Comune completamente nuovo.
- In `HomePage`, quando `problems.isEmpty`, sostituire metriche fredde e pannelli vuoti con:
  - banner "Comune in attivazione";
  - CTA primaria verso `SuggestProblemPage`;
  - CTA secondaria verso `NextProblemsPage`;
  - micro-obiettivo visibile, ad esempio "Servono 5 contributi per aprire il primo turno civico".
- In `PlayPage`, quando non ci sono carte, non mostrare solo un testo vuoto:
  - spiegare che il turno non e' ancora partito;
  - proporre 3-5 missioni leggere di osservazione: buche, illuminazione, rifiuti, verde, sicurezza pedonale;
  - portare l'utente a proporre il primo tema invece di invitarlo solo a tornare piu' tardi.
- In `BoardPage`, trattare la board vuota come mappa in costruzione:
  - mostrare categorie suggerite e zone da osservare;
  - evitare segnalazioni finte;
  - rendere trasparente che non e' un canale ufficiale del Comune.
- In `NextProblemsPage`, rendere lo stato vuoto operativo:
  - CTA "Proponi il primo tema";
  - esempi concreti di temi locali;
  - conferma che anche un solo contributo avvia il monitoraggio leggero.
- Aggiungere fixture/test per simulare almeno un Comune vuoto, per evitare che il flusso resti irraggiungibile nel prototipo.

### 5. Play flow e performance scroll

- Ridisegnare `PlayPage` e `ProblemCard` puntando a 60fps in profile mode.
- Usare `ListView.builder` o `SliverList` quando la lista puo' crescere.
- Isolare rebuild con widget piccoli, `const`, selector dove utile e dati gia' derivati nel Cubit.
- Aggiungere `RepaintBoundary` solo intorno a elementi realmente costosi.
- Evitare `CustomPaint`, gradienti complessi, blur e shadow profonde dentro ogni item scrollabile.

### 6. Board, leaderboard e profile

- Applicare i nuovi componenti a `BoardPage`.
- Allineare `LeaderboardPage` al rail del mockup: top utenti, posizione corrente, score.
- Allineare `ProfilePage` a reputazione, livello, accuratezza, avanzamento.

### 7. Next problems e suggest

- Sostituire le card di voto con `FcProblemTile`.
- Tenere il form di proposta leggibile, mobile first e con CTA sempre raggiungibile.
- Verificare overflow tastiera e scroll su viewport piccola.

### 8. Test e quality gate

- Aggiornare/aggiungere widget test per:
  - shell mobile e desktop;
  - home dashboard;
  - card problema/play flow;
  - next problems voting;
  - suggest problem form scrollabile.
- Eseguire sempre:

```bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

- Per la PR UI, fare anche una verifica manuale in profile mode su viewport mobile circa `390x844` e desktop circa `1440x900`.

## Criteri di accettazione

- Il mockup standalone e' tracciato nel repo come reference.
- Le schermate principali non usano piu' il linguaggio vintage/carta.
- Mobile e desktop hanno layout intenzionali, non solo responsivi per compressione.
- Lo scroll della lista problemi resta fluido su mobile.
- Gli elementi testuali non vanno in overflow nelle viewport target.
- Analyzer e test passano.
- La migrazione avviene in PR piccole: tokens/shell, home, play, board/profile/classifica, next problems.
