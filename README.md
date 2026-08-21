# Migliora Paese · Fanta Comune

[![Flutter](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml)
[![Backend](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml)
[![License: GPL-3.0-only](https://img.shields.io/badge/license-GPL--3.0--only-blue.svg)](LICENSE)

Migliora Paese è un prototipo Flutter web di gioco civico locale. L'app, il cui
nome corrente nell'interfaccia è **Fanta Comune**, permette di scegliere un
Comune, osservare temi urbani in forma di carte, fare previsioni leggere e
confrontare esiti e percezioni aggregate.

> **Stato: prototipo v0.1.0.** La demo pubblica usa dati mock locali, non invia
> segnalazioni ufficiali e non certifica la realtà. Il backend pilot dispone di
> persistenza, identità anonima, moderazione operatore e asset di staging, ma
> non è ancora autorizzato né distribuito per contributi pubblici o dati reali.

## Funzionalità

- onboarding leggero e scelta del Comune;
- shell responsive per mobile e desktop;
- turno di gioco con previsioni, motivazioni e confidence;
- tabellone, insight, reputazione e classifica mock;
- flusso per proporre e votare i temi del prossimo turno;
- stati operativi per Comuni nuovi o senza dati;
- privacy e reset della demo locale;
- pilot API opt-in per proposte, gioco, esiti, reputazione e insight.

## Stack e struttura

- Flutter 3.44.2 / Dart 3.12;
- go_router, flutter_bloc, provider e shared_preferences;
- design system locale in **lib/core/theme** e **lib/core/widgets**;
- API HTTP Node.js 24 con SQLite nativo in **services/backend**;
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

## Pilot API locale

La demo e i default restano mock. `NextProblemsRepository` e
`GameRepository` possono usare il backend soltanto quando vengono attivati
esplicitamente e in modo indipendente.

Avvia il backend locale in-memory:

~~~bash
cd services/backend
npm test
npm run dev
~~~

Per mantenere i dati tra i riavvii, imposta
`DATABASE_PATH=./data/pilot.sqlite`. Il backend assegna l'identità anonima con
un cookie firmato `HttpOnly`; `userId` non viene più accettato come autorità dal
client.

Poi avvia Flutter con:

~~~bash
fvm flutter run -d chrome \
  --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
  --dart-define=GAME_DATA_SOURCE=api \
  --dart-define=API_BASE_URL=http://localhost:8787 \
  --dart-define=PILOT_MUNICIPALITY_ID=castel-bolognese
~~~

In locale usa `localhost` sia per Flutter Web sia per l'API: il cookie
`SameSite=Lax` rimane così nello stesso sito anche se le due applicazioni usano
porte diverse.

`ApiGameRepository` usa HTTP per attivazione, riepilogo, turno, problemi,
previsioni, risultati, reputazione, insight e classifica. In questa fase le
domande di riflessione restano generate localmente; il segnale che modifica lo
stato di un problema è rifiutato esplicitamente finché manca il relativo
endpoint. Il lookup diretto di un problema usa la cache popolata dall'elenco
del Comune.

La modalità API supporta al momento gli ID canonici **bologna** e
**castel-bolognese**, con mapping esplicito dagli ID Flutter corrispondenti.
Qualunque altro Comune produce un errore controllato e non ricade
silenziosamente sui dati di un'altra città.

Il filtro automatico rifiuta contatti personali, link, caratteri di controllo
e linguaggio abusivo noto, e limita gli invii ripetuti. In modalità pilot i voti
non promuovono contenuti: serve una decisione dell'operatore tramite endpoint
amministrativo protetto. Gli insight restano oscurati sotto la soglia minima di
partecipazione configurata.

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
docker build --tag migliorapaese/backend:local .
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
- [Runbook staging e pilot](docs/pilot_runbook.md)
- [Piano UX/UI](docs/design/ux_ui_alignment_plan.md)
- [Reference statica del mockup](docs/design/fanta-comune-standalone.html)

## Limiti noti

- la demo Pages resta esclusivamente mock; SQLite è opt-in nel backend pilot;
- identità anonima e moderazione operatore non equivalgono ad autenticazione o
  protezione anti-abuso distribuita;
- nessun canale ufficiale con i Comuni;
- il repository di gioco HTTP è opt-in e due capability restano progressive:
  reflection locale e mutazione del segnale non supportata;
- il lancio richiede ancora selezione e accordo con un Comune, provider,
  privacy/retention, cancellazione remota, alert e prova di ripristino.

## Contribuire e sicurezza

Leggi [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
e [SECURITY.md](SECURITY.md). Non inserire segnalazioni civiche reali, dati
personali o credenziali in issue, fixture, log e screenshot.

## Licenza e rilascio

Il codice sorgente è distribuito con licenza
[GPL-3.0-only](LICENSE). La provenienza dichiarata, le condizioni e i limiti
degli asset grafici sono riportati in [ASSETS.md](ASSETS.md).

La cronologia privata con metadati personali e operativi è conservata
nell'archivio separato `miglioraPaese-private`; questo repository pubblico nasce
da uno snapshot bonificato, come descritto nel
[piano di rilascio](docs/public_release_plan.md).
