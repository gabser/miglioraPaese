# Sentinelle — baseline e matrice di porting

13 ottobre 2026. Audit locale fase 0; nessuna attestazione sul remoto.

## Task envelope fase 0 — FG-15

Obiettivo: congelare la baseline locale, verificare le regressioni e identificare
il porting fantasy senza sostituire proposte, bozze, ricevute e PostgreSQL.
Orchestratore: agente principale; inventario indipendente: `porting_inventory`
(sola lettura). Nessun AGENTS.md trovato negli antenati o nei sottoalberi dei
checkout. Nessun push, deploy, provider o dato reale autorizzato.

Destinazione: workspace indicato dal piano, HEAD
`1fad162218e758efa3a556790e42b335a6196959`, branch
`codex/uc-02-postgres-migrations`. Baseline comprende 72 file tracked modificati
e 68 voci untracked di status (alcune sono directory), tutti preservati.
Sorgente: `/Users/gabrieleserra/miglioraPaese`, HEAD
`14b0edf18caa070a3d4a28667251a7b175ca0ce6`, branch
`codex/fantasy-staging-rehearsal`; unica voce untracked
`docs/backend/fanta_comune_incremental_pr_plan.md`, esclusa dal porting.

Snapshot prima delle modifiche: `/tmp/sentinelle-baseline-20261013/` contiene
`workspace-before.tar.gz`, `files-before.json`, `git-status-before.txt` e
`git-diff-before.patch`. Manifest SHA-256:
`cf6d31f8ac156ae3739883fa58f5df0fbc78d39165d4b72916197c961c900447`.
322 file tracciati o non ignorati inventariati; nessun commit prodotto.
Gli artefatti in /tmp sono temporanei e non costituiscono backup operativo.

Toolchain selezionata: Node 24.18.0 (PATH iniziale 22.23.2), Flutter 3.44.2 /
Dart 3.12.2 da FVM, PostgreSQL 17.10. Database sintetico usa e getta, cluster
`/tmp/sentinelle-baseline-20261013/pgdata`, loopback porta 55432, nome
`migliorapaese_test`; nessun database operativo toccato.

## Controlli iniziali sulla baseline

| Comando | Esito e artefatto in /tmp/sentinelle-baseline-20261013 |
|---|---|
| Node 24, `TEST_DATABASE_URL=… npm --prefix services/backend test` | PASS, 81 test, 12 suite, zero skip; `backend-tests.log` |
| `npm --prefix services/backend run migrations:verify` | PASS, cinque migrazioni |
| `git diff --check` | PASS |
| Flutter 3.44.2 `flutter test` | PASS, 228 test; `flutter-tests.log` |
| `flutter analyze` | Exit 1: 155 info preesistenti, zero errori/warning; `flutter-analyze.log` |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS con policy README; `flutter-analyze-baseline-policy.log` |
| `flutter build web --release --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8787` | PASS; `flutter-build-api.log` |

Build segnala un riferimento a CupertinoIcons senza font nel manifest corrente;
il dry run Wasm riesce. La baseline non è lint-clean. Non applicare correzioni
indiscriminate ai 155 info nel lavoro preesistente.

## Matrice fase 1 — sorgenti relative al checkout recente

| Sorgente | Destinazione / adattamento | Accettazione |
|---|---|---|
| `lib/features/fantasy/domain/*` | Stessi percorsi; preservare regole v1 | Parità fixture scoring Dart/Node, snapshot storici invariati |
| `lib/features/fantasy/data/*` e `logic/*` | Stessi percorsi; networking e persistenza attuali | API senza fallback, scope, CAS, recupero ricevute |
| `lib/features/fantasy/presentation/*` | Port selettivo e router attuale | Creazione/adesione vere, calendario, lock, legacy preservato |
| `lib/features/game/data/api_game_repository.dart`, `game_mapper.dart` | Stessi percorsi e configurazione esplicita | Repository remoto e mapper compatibili con legacy |
| `lib/app/*`, `core/config/app_config.dart` | Innesti selettivi | Fantasy disattivato di default finché incompleto; profili espliciti |
| `core/preferences/app_prefs.dart`, `core/network/api_client.dart` | Estensione, nessuna sostituzione | Preservare LocalDataStore, revoca, reset barrier, headers e retry proposte |
| `services/backend/src/fantasy/{store,teams,market,results,leagues}.js` | Dominio, application e adapter PostgreSQL separati | Identità/tempo server, transazioni async, idempotenza, lock e ranking |
| DDL `migrateFantasy*` | Migrazioni PostgreSQL additive e manifest | FK/CHECK/unique; nessuna modifica alle cinque migrazioni precedenti |
| `fantasy/transaction.js` | Transazioni PostgreSQL attuali | Rollback, concorrenza, risposta persa e restart |
| Blocchi fantasy `src/server.js`, OpenAPI | Innesti HTTP/application e aggiunte OpenAPI | JSON, await, CORS, errori e DTO allineati |
| `src/identity.js`, `admin_auth.js` | Identità server compatibile con sessioni attuali | Non equiparare cookie e bearer attraverso ID client-controlled |
| `test/fantasy_*.test.js`, test Flutter e fixture scoring | Adattare helper PostgreSQL, conservare asserzioni | Parità fantasy, regressione proposte, concorrenza reale |
| Script pubblicazione/rehearsal sorgenti | Adattare scenari; operatività fase 8 | Nessuna attestazione SQLite trasferita a PostgreSQL |

Rischi: SQLite sorgente è sincrono e intrecciato alle regole; `.prepare`, STRICT,
json_valid, BEGIN IMMEDIATE e PRAGMA richiedono conversione, non sostituzione
testuale del driver. Calendario demo fisso all'8 ottobre, nessun rinnovo implicito.
V2/non determinabile/rettifiche sono stati implementati e verificati in fase5;
link/proprietà in6, cooperazione/inbox/calendario in7. Il registro attesta i gate
locali effettivi; fase8 verificata localmente il 16 ottobre con dump/restore PostgreSQL e
rehearsal identificata; non eredita prove SQLite. Pilot reale NO-GO.
L'identità anonima sorgente e la sessione bearer proposte sono contratti distinti.

## Task envelope fase 1 — FG-10, FG-15

Prerequisito: fase 0 verificata con limiti lint documentati. Porting fantasy e
leghe v1 PostgreSQL, gioco remoto, client e contratti nello stesso incremento.
Un solo autore per file: backend/contratto a un responsabile; Flutter a un altro;
integrazione, registro e review sotto l'orchestratore. Preservare i file locali
inventariati; adattare solo gli innesti necessari. Esclusi account email,
missioni, XP, v2, link guidati e attivazioni esterne fino alle fasi dipendenti.

Verifiche: suite legacy e fantasy, PostgreSQL reale e migrazioni, fixture scoring,
CAS/retry/riavvio, isolamento, creazione/adesione API, render 390/1024/1440 e
tastiera, build profili. Nessuna funzione incompleta attiva per default.
