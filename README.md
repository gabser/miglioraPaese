# Migliora Paese · Fanta Comune

[![Flutter](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml)
[![Backend](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml)
[![License: GPL-3.0-only](https://img.shields.io/badge/license-GPL--3.0--only-blue.svg)](LICENSE)

Migliora Paese è un prototipo Flutter web di gioco civico locale. L'app, il cui
nome corrente nell'interfaccia è **Fanta Comune**, permette di scegliere un
Comune, osservare temi urbani in forma di carte, fare previsioni leggere e
confrontare esiti e percezioni aggregate.

> **Stato: prototipo v0.1.0.** La demo pubblica usa dati mock locali, non invia
> segnalazioni ufficiali e non certifica la realtà. Il backend è uno scaffold
> in-memory per sviluppo: non è autorizzato per un deploy pubblico o per dati
> reali.

## Funzionalità

- onboarding leggero e scelta del Comune;
- shell responsive per mobile e desktop;
- turno di gioco con previsioni, motivazioni e confidence;
- tabellone, insight, reputazione e classifica mock;
- flusso per proporre e votare i temi del prossimo turno;
- stati operativi per Comuni nuovi o senza dati;
- privacy e reset della demo locale;
- pilot API opt-in per sole proposte e voti.

## Stack e struttura

- Flutter 3.44.2 / Dart 3.12;
- go_router, flutter_bloc, provider e shared_preferences;
- design system locale in **lib/core/theme** e **lib/core/widgets**;
- API HTTP Node.js 24 zero-dependency in **services/backend**;
- contratto OpenAPI e test Node integrati;
- CI Flutter/backend e deploy della demo mock su GitHub Pages.

~~~text
.github/                    workflow e configurazione GitHub
docs/                       piani di design, backend e rilascio
lib/app/                    bootstrap, dipendenze e router
lib/core/                   config, rete, tema, copy e preferenze
lib/features/               dominio, repository, logica e UI
services/backend/           scaffold API locale e OpenAPI
test/                       test unit, repository, Cubit e widget
web/                        shell PWA Flutter
~~~

## Avvio rapido

Il repository versiona solo la piattaforma web. Usa [FVM](https://fvm.app/) o
un'installazione Flutter esattamente alla versione indicata in **.fvmrc**.

~~~bash
fvm flutter pub get
fvm flutter run -d chrome
~~~

Senza FVM:

~~~bash
flutter pub get
flutter run -d chrome
~~~

## Pilot API per proposte e voto

Il gioco resta mock. Solo NextProblemsRepository può usare il backend, e
soltanto quando viene attivato esplicitamente.

Avvia lo scaffold locale:

~~~bash
cd services/backend
npm test
npm run dev
~~~

Poi avvia Flutter con:

~~~bash
fvm flutter run -d chrome \
  --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:8787
~~~

La modalità API supporta al momento gli ID canonici **bologna** e
**castel-bolognese**, con mapping esplicito dagli ID Flutter corrispondenti.
Qualunque altro Comune produce un errore controllato e non ricade
silenziosamente sui dati di un'altra città.

Il parametro userId del pilot è ancora controllato dal client. Non usare
questa modalità per utenti o contributi reali.

## Quality gate

~~~bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release
~~~

Per il backend:

~~~bash
cd services/backend
npm test
~~~

La CI esegue gli stessi gate con Flutter 3.44.2 e Node.js 24.

## Demo web

Il workflow **.github/workflows/pages.yml** costruisce esclusivamente la demo
mock con base path **/miglioraPaese/**. Dopo aver selezionato **GitHub Actions**
come sorgente Pages, l'URL previsto è:

<https://gabser.github.io/miglioraPaese/>

Il workflow Pages non avvia e non espone **services/backend**.

## Documentazione

- [Piano di rilascio pubblico](docs/public_release_plan.md)
- [Fondazione backend](docs/backend/backend_foundation_plan.md)
- [Piano UX/UI](docs/design/ux_ui_alignment_plan.md)
- [Reference statica del mockup](docs/design/fanta-comune-standalone.html)

## Limiti noti

- dati di gioco e preferenze sono locali o in-memory;
- nessuna autenticazione, persistenza server, moderazione o rate limiting;
- nessun canale ufficiale con i Comuni;
- ApiGameRepository non è ancora implementato perché il contratto non copre
  risultati, reputazione e insight;
- il lancio di un servizio reale richiede una privacy policy completa,
  cancellazione remota, protezioni anti-abuso, staging e osservabilità.

## Contribuire e sicurezza

Leggi [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
e [SECURITY.md](SECURITY.md). Non inserire segnalazioni civiche reali, dati
personali o credenziali in issue, fixture, log e screenshot.

## Licenza e rilascio

Il codice sorgente è distribuito con licenza
[GPL-3.0-only](LICENSE). La provenienza dichiarata, le condizioni e i limiti
degli asset grafici sono riportati in [ASSETS.md](ASSETS.md).

La cronologia privata contiene metadati personali e operativi. Il proprietario
ha scelto di pubblicare uno snapshot bonificato in un nuovo repository e di
mantenere il repository corrente come archivio privato, come descritto nel
[piano di rilascio](docs/public_release_plan.md).
