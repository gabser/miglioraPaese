# Migliora Paese · Fanta Comune

[![Flutter](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml)
[![Backend](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml)
[![License: GPL-3.0-only](https://img.shields.io/badge/license-GPL--3.0--only-blue.svg)](LICENSE)

Migliora Paese è un prototipo Flutter web di gioco civico locale. L'app, il cui
nome corrente nell'interfaccia è **Fanta Comune**, permette di scegliere un
Comune, osservare temi urbani in forma di carte, fare previsioni leggere e
confrontare esiti e percezioni aggregate.

> **Stato: prototipo v0.1.0.** La demo pubblica usa dati mock locali, non invia
> segnalazioni ufficiali e non certifica la realtà. Il backend locale dispone
> di persistenza PostgreSQL opt-in per proposte, voti e previsioni, ma non è
> autorizzato per un deploy pubblico o per dati reali.

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

- Flutter 3.47.5 / Dart 3.13.4;
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
npm ci
npm test
DATA_STORE=memory npm run dev
~~~

Per usare il percorso persistente locale, prepara esplicitamente PostgreSQL e
avvia lo stesso contratto HTTP con l'adapter database:

~~~bash
DATABASE_URL=postgres://... npm run migrate:up
DATABASE_URL=postgres://... npm run seed:local
DATA_STORE=postgres DATABASE_URL=postgres://... npm run dev
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

Le proposte e i voti API usano una `Idempotency-Key` generata per ogni azione.
In caso di timeout o errore di rete il client esegue al massimo un retry con la
stessa chiave, così il backend persistente applica la mutazione una sola volta.

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
npm ci
npm test
~~~

La CI esegue gli stessi gate con Flutter 3.47.5, Node.js 24 e PostgreSQL 17
effimero per migrazioni e vincoli.

## Demo web

Il workflow **.github/workflows/pages.yml** costruisce esclusivamente la demo
mock con base path **/miglioraPaese/**. Dopo aver selezionato **GitHub Actions**
come sorgente Pages, l'URL previsto è:

<https://gabser.github.io/miglioraPaese/>

Il workflow Pages non avvia e non espone **services/backend**.

## Documentazione

- [Guida operativa completa al rilascio Sentinelle: GitHub Pages, Supabase e Resend](docs/sentinelle_deploy_guida_operativa.md)
- [Playbook e taccuino di avanzamento del rilascio Sentinelle](docs/sentinelle_deploy_taccuino.md)
- [Roadmap delle evoluzioni e percorso criptovalute](docs/evolution/README.md)
- [Procedura deploy Sentinelle con budget zero](docs/sentinelle_deploy_zero_budget_runbook.md)
- [Architettura target Supabase e Resend: diagramma prodotti](docs/sentinelle_cloud_architecture.md)
- [Piano di rilascio pubblico](docs/public_release_plan.md)
- [Fondazione backend](docs/backend/backend_foundation_plan.md)
- [Consolidamento backend e pilot funzionante](docs/backend/backend_productization_plan.md)
- [Registro decisioni backend](docs/backend/backend_decision_register.md)
- [Piano UX/UI](docs/design/ux_ui_alignment_plan.md)
- [Reference statica del mockup](docs/design/fanta-comune-standalone.html)

## Limiti noti

- dati di gioco e preferenze restano locali; la persistenza PostgreSQL copre
  solo i flussi backend attualmente contrattualizzati e backup/restore e
  verifica attraverso restart restano da chiudere in `UC-02.5`;
- nessuna autenticazione, moderazione o rate limiting;
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
[GPL-3.0-only](LICENSE). Prima del cambio di visibilità il proprietario deve
confermare la provenienza e i diritti di distribuzione degli asset grafici,
come indicato nel [piano di rilascio](docs/public_release_plan.md).

La cronologia privata contiene metadati personali e operativi: la strategia
raccomandata è pubblicare uno snapshot bonificato e mantenere l'attuale
repository privato come archivio. Nessuna riscrittura della storia o creazione
di un nuovo repository deve avvenire senza approvazione esplicita.

## Esecuzione locale Sentinelle

L'esecuzione è registrata in [sentinelle_execution_log.md](docs/sentinelle_execution_log.md).
Il [piano](docs/sentinelle_gap_resolution_plan.md) governa le dipendenze fra le
fasi; la [matrice di porting](docs/sentinelle_porting_matrix.md) identifica il
lavoro locale preesistente. Le verifiche usano dati sintetici; nessun pilot,
servizio esterno o deploy è autorizzato da questi comandi.

Il porting fantasy PostgreSQL è opt-in. Sul backend locale migrato:

```bash
DATA_STORE=postgres DATABASE_URL=postgres://... \
  FANTASY_ENABLED=true FANTASY_DEMO_SEED=true npm --prefix services/backend run dev
```

Il seed fantasy usa un calendario demo fisso e non rinnova stagioni scadute.
Nel client, il profilo fantasy API richiede configurazione esplicita:

```bash
fvm flutter run -d chrome \
  --dart-define=FANTASY_MODE_ENABLED=true \
  --dart-define=FANTASY_DATA_SOURCE=api \
  --dart-define=GAME_DATA_SOURCE=api \
  --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
  --dart-define=PILOT_MUNICIPALITY_ID=bologna \
  --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

Le nuove suite Flutter di integrazione richiedono Node 24 e un PostgreSQL locale
usa e getta indicato da `TEST_DATABASE_URL` (loopback, nome terminante in `_test`).
Il ruolo locale deve poter creare database per le fixture isolate (`CREATEDB`).
Le fixture fantasy Flutter creano database privati e li rimuovono al termine;
le suite backend esistenti resettano il database di test indicato. Non usare un
database operativo. Con i binari corretti nel PATH:

```bash
TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test \
  FANTASY_TEST_NODE="$(command -v node)" fvm flutter test
```

Il registro distingue controlli superati e verifiche ancora aperte: la presenza
dei nuovi file non attesta il completamento di una fase.

Gli account recuperabili locali sono anch'essi opt-in: backend
`ACCOUNT_ENABLED=true EMAIL_DELIVERY=simulated` su PostgreSQL e client
`--dart-define=ACCOUNT_MODE_ENABLED=true`. La consegna è simulata e accetta solo
indirizzi sintetici; i codici sono accessibili all'owner della fixture privata,
senza endpoint pubblico di test. Il login non importa squadre demo. In caso di
conflitto fra ospite e account, la squadra account resta preservata e la scelta
di abbandonare lo stato ospite è esplicita. Nessuna email reale è inviata.

Il laboratorio missioni richiede backend `MISSIONS_ENABLED=true`,
`MISSION_STORAGE=local-synthetic`, `MISSION_STORAGE_ROOT` assoluto privato e
`MISSION_RETENTION_DAYS` esplicito (1–30), oltre agli account su PostgreSQL.
`MISSIONS_DEMO_SEED=true` pubblica solo le finestre sintetiche fisse di Tuglie;
il client usa `--dart-define=MISSIONS_MODE_ENABLED=true`, account abilitati e
`--dart-define=PILOT_MUNICIPALITY_ID=tuglie`. Le foto sintetiche JPEG/PNG vengono
normalizzate e caricate privatamente; prenotazione e invio richiedono conferma
server. Il picker è disponibile sul web; l'acquisizione nativa non è supportata
dal laboratorio attuale. La ricevuta di invio resta in attesa di revisione, XP0.
Configurazione e limiti in `services/backend/README.md`; gate fase 3 nel registro.

La revisione sintetica locale richiede inoltre backend `REVIEW_ENABLED=true` e
client `--dart-define=REVIEW_MODE_ENABLED=true`, entrambi opt-in. I grant dei ruoli
per Comune provengono dal comando locale documentato nel README backend; nessuna
auto-promozione nell'app. Moderatore e verificatore gestiscono screening,
integrazioni e decisione; solo il server accredita 10 XP una volta. La ricevuta
originale XP0 resta immutabile, mentre stato corrente e ledger mostrano la
validazione. La separazione nominativa e l'autenticazione forte degli operatori
restano gate del pilot reale. Fase 4 e limiti verificati nel registro Sentinelle.

Misurazioni ed esiti richiedono anche backend `MEASUREMENTS_ENABLED=true` e
client `--dart-define=MEASUREMENTS_MODE_ENABLED=true`, con fantasy API, account,
missioni e revisione abilitati. Il laboratorio usa fonti sintetiche autorizzate,
protocolli pubblicati prima del lock e valutazioni motivate del responsabile.
Le nuove stagioni `fantasy-v2` distinguono esito non determinabile e direzione;
rettifiche e revisioni dei risultati conservano lo storico e non cambiano gli XP.
Le stagioni v1 mantengono le proprie regole. Configurazione e contratti sono nel
README backend e nell'envelope della fase 5; il gate operativo reale resta aperto.

La continuità delle leghe è opt-in: backend `LEAGUE_CONTINUITY_ENABLED=true`
su fantasy PostgreSQL e client `--dart-define=LEAGUE_CONTINUITY_MODE_ENABLED=true`
su fantasy API. Il link invito conserva il token nel frammento, rimosso prima
del router; il riepilogo non iscrive automaticamente alla lega. Il trasferimento
richiede proposta dell'owner e accettazione del destinatario. Dopo utilizzo della
feature, il rollback della migrazione15 può richiedere restore controllato con
scritture sospese; non riscrivere le chiavi di creazione per forzare il downgrade.
