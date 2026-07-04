# Fanta Comune

Fanta Comune e' un prototipo Flutter di gioco civico locale. L'utente sceglie un Comune, osserva problemi urbani in forma di carte, fa previsioni leggere su come evolveranno, poi vede esiti, reputazione e percezioni aggregate.

Il repository e' ancora basato su dati mock in-memory: non c'e' un backend reale e non vengono inviate segnalazioni ufficiali.

## Stack

- Flutter / Dart
- `go_router` per routing dichiarativo
- `flutter_bloc` per Cubit e stato UI
- `provider` per dependency injection semplice
- `shared_preferences` per preferenze locali
- design system locale in `lib/core/theme` e `lib/core/widgets`
- backend HTTP iniziale in `services/backend`

## Funzionalita'

- boot screen e onboarding leggero
- scelta Comune locale
- tab shell responsive
- play loop con previsioni, motivazioni e confidence
- tabellone dei problemi
- insight aggregati e trend mock
- reputazione e classifica mock
- proposta e voto dei prossimi problemi
- pagine info/privacy con reset locale

## Setup

```bash
flutter pub get
```

Per avviare su web:

```bash
flutter run -d chrome
```

Per avviare su un device/emulatore:

```bash
flutter devices
flutter run -d <device-id>
```

## Qualita'

I check minimi attesi prima di una PR sono:

```bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

La CI GitHub esegue gli stessi passaggi su ogni push e pull request verso `main`. Il gate analyzer iniziale fallisce sugli errori; warning e info restano visibili e andranno ridotti progressivamente.

## Design

La reference del nuovo mockup e il piano di migrazione UI sono in:

- `docs/design/fanta-comune-standalone.html`
- `docs/design/mockup_implementation_plan.md`
- `docs/design/ux_ui_alignment_plan.md`

## Backend

La fondazione backend vive in:

- `docs/backend/backend_foundation_plan.md`
- `services/backend`

Per provarla localmente:

```bash
cd services/backend
npm test
npm run dev
```

Richiede Node.js 20 o superiore.

## Struttura

```text
.github/workflows/          CI Flutter e backend
docs/                       piani tecnici e design reference
lib/app/                    router e shell applicativa
lib/core/                   tema, copy, preferenze e widget condivisi
lib/features/boot/          schermata iniziale
lib/features/onboarding/    welcome e scelta Comune
lib/features/game/          dominio, repository mock, Cubit e UI di gioco
lib/features/next_problems/ proposta e voto prossimi problemi
lib/features/profile/       profilo e reputazione
lib/features/leaderboard/   classifica mock
lib/features/info/          come funziona e privacy
services/backend/           API HTTP iniziale e contratto OpenAPI
test/                       widget e routing smoke test
```

## Note di prodotto

Questa app non sostituisce canali ufficiali del Comune. E' un'esperienza giocosa per raccogliere percezioni, previsioni e priorita' leggere.

## Roadmap tecnica breve

- aumentare copertura dei Cubit
- aggiungere integration test del flusso onboarding -> play
- isolare e testare `ProblemCard` e `InsightCard`
- preparare repository reali dietro le interfacce esistenti
