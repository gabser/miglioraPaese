# Sentinelle — registro di esecuzione

Avvio: 13 ottobre 2026. **Orchestrazione avviata; fase 0 verificata.**

Riferimenti: [piano](sentinelle_gap_resolution_plan.md),
[prompt](sentinelle_orchestration_prompts.md),
[report dei gap](functional_gap_report_2026-10-13.md).

## Stati e regole di registrazione

- **da fare:** attività non iniziata.
- **in corso:** lavoro iniziato, risultato ancora incompleto.
- **implementato:** risultato scritto, verifiche obbligatorie non concluse.
- **verificato:** criteri soddisfatti con evidenze sulla revisione indicata.
- **bloccato:** dipendenza concreta impedisce il completamento; registrare causa,
  attività indipendenti completate, input necessario e punto di ripresa.

Non confondere evidenze tecniche con approvazioni operative. Non segnare una fase
verificata sulla base di test storici, sola implementazione o approvazioni
presunte. Non inserire token, credenziali o dati personali nel registro.

## Baseline operativa

Inventario e comandi completi nella [matrice di porting](sentinelle_porting_matrix.md).

| Campo | Valore |
|---|---|
| Destinazione effettiva | Workspace previsto dal piano, nessuna sostituzione |
| HEAD e branch destinazione | `1fad162218e758efa3a556790e42b335a6196959`, `codex/uc-02-postgres-migrations` |
| Stato tracked/untracked e lavoro preesistente | 72 tracked modificati e 68 voci untracked; snapshot di 322 file in /tmp/sentinelle-baseline-20261013 |
| Checkout sorgente, HEAD e branch | `/Users/gabrieleserra/miglioraPaese`, `14b0edf18caa070a3d4a28667251a7b175ca0ce6`, `codex/fantasy-staging-rehearsal` |
| Eventuale checkout isolato e trasferimento della baseline locale | Non usato; lavoro sul workspace completo |
| Toolchain e profili | Node 24.18.0, Flutter 3.44.2/Dart 3.12.2, PostgreSQL 17.10 temporaneo; build web API proposte |
| Controlli iniziali e regressioni preesistenti | Backend 81 PASS senza skip, Flutter 228 PASS, cinque migrazioni valide, build API PASS; analyze 155 info preesistenti, policy README PASS |

## Avanzamento per fase

| Fase | Gap | Stato | Revisione ed evidenze | Residui / ripresa |
|---|---|---|---|---|
| 0 — Baseline | FG-15 | verificato | Snapshot SHA-256 `cf6d31f8ac156ae3739883fa58f5df0fbc78d39165d4b72916197c961c900447`; matrice e log locali | Lint informativi preesistenti documentati |
| 1 — Fantasy e leghe | FG-10, FG-15 | verificato | 14 ottobre: backend 131 PASS, Flutter 349 PASS, sette migrazioni, tre build; digest sotto | Operatività/rehearsal fase 8; gate esterni aperti |
| 2 — Account | FG-08, FG-09 | verificato | 14 ottobre, backend 148 PASS, Flutter 365 PASS, 8 migrazioni, 3 build; digest sotto | Solo email simulate; gate operativi aperti |
| 3 — Missioni e prove | FG-01, FG-02 | in corso | Envelope missioni; baseline fase 2 `27284f…` | Catalogo, prenotazioni, bozze, prove e ricevute |
| 4 — Revisione e XP | FG-03, FG-07 | da fare | Nessuna | Dopo fase 3 |
| 5 — Misurazione ed esiti | FG-04, FG-05, FG-06 | da fare | Nessuna | Dopo fase 4 |
| 6 — Leghe continuative | FG-11 | da fare | Nessuna | Dopo fase 5 |
| 7 — Cooperazione e ritorno | FG-12, FG-13, FG-14 | da fare | Nessuna | Dopo fase 6 |
| 8 — Preparazione operativa | FG-15 | da fare | Nessuna | Dopo fase 7 |

## Scheda di evidenza per incremento

Duplicare e compilare durante l'esecuzione; questa scheda vuota non attesta lavoro.

| Campo | Contenuto da registrare |
|---|---|
| Data, fase e requisiti FG | — |
| Stato e responsabile | — |
| Prerequisiti verificati | — |
| Baseline / revisione / identificazione del diff locale | — |
| File modificati e comportamento ottenuto | — |
| Comandi, ambiente, esiti e artefatti | — |
| Review indipendente e rilievi risolti | — |
| Limiti tecnici e attività residue | — |
| Dipendenza esterna / input necessario | — |
| Ultimo checkpoint e punto di ripresa | — |

## Gate operativi separati

### Incremento fase 1 — avvio

Prerequisiti: fase 0 verificata sulla baseline inventariata. Proprietà file:
`fantasy_backend` scrive solo `services/backend/**`; `fantasy_flutter` scrive
`lib/**`, test Flutter e innesti indispensabili; orchestratore mantiene questi
documenti e integrazione finale. `porting_inventory` revisiona indipendentemente
in sola lettura. Nessuna scrittura contemporanea sugli stessi file.

Decisione identità: riusare il bearer proposal-session esistente; il server
determina l'identità fantasy dalla sessione verificata, mai da userId body/query.
Gli URL/DTO fantasy v1 della sorgente restano compatibili salvo adattamento
esplicito della autenticazione. Pubblicazione amministrativa locale separata,
disabilitata senza configurazione; autenticazione forte operativa resta un gate.
Nessuna funzione incompleta attivata per default.

Verifica indipendente parziale: Node 24 ha eseguito
`/tmp/sentinelle-baseline-20261013/verify-score-parity.mjs` contro
`services/backend/src/domain/fantasy/scoring.js`: tutte le 48 fixture originali
v1 corrispondono. Questo attesta solo lo scorer puro nella revisione corrente,
non la fase 1 intera. La [checklist](sentinelle_acceptance_matrix.md) raccoglie
criteri di verifica, senza attribuire esiti alle fasi ancora da implementare.

### Ripresa 14 ottobre 2026 — fase 1 ancora in corso

Utente: «continua». HEAD e checkout sorgente invariati; nessun file della
baseline è stato rimosso e le cinque migrazioni originali conservano i checksum
del manifest iniziale. Il cluster sintetico PostgreSQL precedente è ancora
attivo; le fixture nuove del gioco remoto e Flutter usano database separati.

L'interruzione precedente dei tre subagenti era dovuta al limite di utilizzo
del servizio; non attesta un fallimento del codice. Gli stessi responsabili
sono stati riattivati, mantenendo le proprietà dei file. Il servizio e repository
`remote-game-*` e `test/remote-game.test.js` restano sotto l'orchestratore.

Nuovo comando effettivo (Node 24, `TEST_DATABASE_URL` del cluster sintetico):
`node --test services/backend/test/remote-game.test.js`: **7 PASS**, zero skip,
anche HTTP, concorrenza, restart, rollback e revoca. Artefatto:
`/tmp/sentinelle-baseline-20261013/remote-game-tests.log`.
Questo comando precede l'aggiunta del test di riservatezza del leaderboard e
va rieseguito dopo la correzione correlata; non è il gate finale fase 1.

Review indipendente: letture composte team/classifica corrette tramite
transazione; race GET/reset corretta e testata dall'autore. Restano da chiudere
la race PUT/reset e la pubblicazione dell'identità bearer nel leaderboard legacy.
Render sintetici ispezionati dall'orchestratore: squadra 390 e 1440, tastiera
1024, nessun overflow visibile; PNG in `flutter-visuals/` sotto la directory
artefatti. Non sono prove umane né certificazioni di accessibilità.

Rilievi P1/P2 identificati chiusi dalla review indipendente del 14 ottobre:
leaderboard legacy esclude gli ID server `session:`, test HTTP dedicato;
GET/PUT ritardati non ripopolano la cache né creano nuove sessioni dopo reset;
letture composte team e leghe sono serializzate. Log backend
`/tmp/backend-full-20261014.log`: 129 PASS, 13 suite, zero skip.
Log Flutter `/tmp/sentinelle-flutter-tests-20261014.log`: 348 PASS, zero skip.
Tre build release in `/tmp/sentinelle-phase1-builds/`: default, fantasy-mock,
fantasy-api; log `/tmp/sentinelle-build-*-20261014.log`. Queste evidenze
precedono gli ultimi innesti di readiness, ordine trasferimenti e pin del
Comune API: rivalutare i controlli interessati prima di marcare la fase verificata.

Migrazione fantasy 6 già applicata nelle fixture: checksum immutabile
`98e7084794cb35a6591500c6e638ebc2ffa35ab99f31395a9dcba918ce64e830`.
L'ordine inserimento del ledger richiede una settima migrazione additiva,
senza riscrivere la sesta. Nessun database operativo coinvolto.

### Chiusura fase 1 — 14 ottobre 2026

Baseline codice finale: HEAD sempre `1fad162218e758efa3a556790e42b335a6196959`
più workspace locale completo. Manifest di 344 file codice/configurazione
(esclusi documenti Markdown) `/tmp/sentinelle-baseline-20261013/phase1-code-files.json`,
SHA-256 `f9ce0767e67155259bf2591a970a5cdfd2ad60b78024cedd1439c3cfe3783c0a`.
Snapshot completo `phase1-workspace.tar.gz` nella stessa directory.
Non è stato creato un commit né verificato il remoto.

Implementazione: `services/backend/src/{application/fantasy,domain/fantasy,http/fantasy-handler.js,persistence/postgres/fantasy-*}`,
nuove migrazioni 6 e 7, gioco remoto `remote-game-*`, OpenAPI/HTTP/runtime e test;
`lib/features/fantasy/**`, repository gioco API e mapper, innesti selettivi config,
router, provider, preferenze, networking e test Flutter. Conservate le cinque
migrazioni iniziali e tutti i file del lavoro preesistente.

Comandi finali effettivi con Node 24 e PostgreSQL 17.10 sintetico:

- `TEST_DATABASE_URL=… npm --prefix services/backend test`: **131 PASS**,
  13 suite, zero skip/fail, `/tmp/backend-full-final-20261014.log`.
- `npm --prefix services/backend run migrations:verify`: sette migrazioni PASS.
- `TEST_DATABASE_URL=… FANTASY_TEST_NODE=… flutter test`: **349 PASS**, zero skip,
  `/tmp/sentinelle-flutter-tests-final-20261014.log`.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: PASS, **174 info**,
  zero warning/error, `/tmp/sentinelle-flutter-analyze-final-20261014.log`.
  Non dichiarare lint-clean: info baseline più info del porting sorgente.
- Tre build web release PASS: default legacy, fantasy mock e fantasy API
  (`GAME/NEXT_PROBLEMS/FANTASY_DATA_SOURCE=api`, Comune pilot Tuglie).
  Output `/tmp/sentinelle-phase1-builds`, checksum `main.dart.js` in
  `/tmp/sentinelle-build-digests-20261014.txt`.
- Render 390/1024/1440 e tastiera PASS; sei PNG Roboto/icone in `flutter-visuals`;
  `git diff --check` PASS. Scorer puro verificato sulle 48 fixture originali v1.

Verificati: retry/risposta persa, CAS/concorrenza, riavvio, ledger e rollback,
isolamento, revoca/cancellazione, owner archive, soglia classifica, readiness
schema/colonne/FK e ordine ledger. Review indipendente dei quattro rilievi
identificati chiusa; nessuna approvazione umana o operativa attestata.

Limiti: lock globale fantasy serializza le transazioni; dati/catalogo sintetici
e calendario fisso; warning CupertinoIcons preesistente; funzioni di riflessione
legacy Game senza contratto disabilitate, nessun fallback (quelle fantasy remote
sono verificate). Account, missioni, XP, v2 e continuità estesa restano da fare.
Rehearsal backup/restore/smoke/alert del sorgente SQLite non trasferita come
attestazione PostgreSQL: resta fase 8.

Stato iniziale: aperti, senza approvazioni registrate. Nessun gate è soddisfatto
dalla sola preparazione di questi documenti o dalla CI.

| Gate | Stato | Evidenza / approvazione |
|---|---|---|
| Provider, hosting e budget | Aperto | Da acquisire |
| Consegna email e storage prove | Aperto | Da acquisire |
| Autenticazione forte operatori | Aperto | Da acquisire |
| Responsabili, capacità di revisione e conflitti di interesse | Aperto | Da acquisire |
| Categoria, protocollo e fonti reali approvati | Aperto | Da acquisire |
| Privacy, informativa, retention e cancellazione | Aperto | Da acquisire |
| Backup/restore e gestione delle cancellazioni dopo restore | Aperto | Da acquisire |
| Osservabilità, incidenti e rollback operativo | Aperto | Da acquisire |
| Platea, target del pilot e autorizzazione avvio | Aperto | Da acquisire |

## Handoff corrente

- Prompt principale invocato dall'utente; fase 0 completata e verificata localmente.
- Fasi 1 e 2 verificate sulle baseline locali registrate; attività corrente:
  fase 3, [envelope](sentinelle_phase3_envelope.md), FG-01 e FG-02.
- Nessuna autorizzazione registrata a push, merge, deploy, servizi esterni,
  spese o raccolta di dati reali.

### Avvio fase 2 — FG-08, FG-09

Gate fase 1 superato e review indipendente finale senza P1/P2 identificati.
Backend/contratto/persistenza (inclusi `remote-game-*`, proprietà ora trasferita)
a `fantasy_backend`; Flutter e test client a `fantasy_flutter`; verifica
indipendente a `porting_inventory`; integrazione/envelope/registro orchestratore.
Nessun file con due autori contemporanei. Adapter email esclusivamente locale
simulato, nessun invio reale, provider o risorsa esterna.

Primo incremento backend account: sette test PostgreSQL dedicati PASS, zero skip,
`/tmp/account-tests.log`. Coprono OTP, accesso da altro dispositivo, collegamento
ospite, conflitto esplicito e DTO HTTP; non sono il gate finale fase 2.
Il contratto canonico di richiesta/verifica è ora `auth/code` e `auth/verify`,
condiviso con il client prima di pubblicazione. Scope delle ricevute immutabili,
principal account distinto e recovery multi-scope con conflitti espliciti.
Review in corso su token scaduto/revoca altri dispositivi, token guest dopo logout,
replay di ricevute/trasferimenti dopo linking e risposte asincrone stale.

### Ripresa dopo crediti — fase 2

Utente ha nuovamente autorizzato la continuazione il 14 ottobre. I precedenti
subagenti non erano più attivi; responsabilità riattribuite ad `account_backend`
(`services/backend/**`), `account_flutter` (`lib/**` e test Flutter),
`account_review` (sola lettura), orchestratore (documenti/integrazione).
HEAD invariato e modifiche locali preservate; `git diff --check` PASS all'avvio.
Migrazione 8 account già applicata alle fixture: checksum immutabile
`d57920cde07b036306b0c79a3c6f884f65b5faa9be881d63602125cadc4c7ac0`.

Ultimo log account dedicato prima della ripresa: 11 test PASS, zero skip;
questa evidenza non chiude la fase. Review in corso ha individuato grant account
attraverso token guest per i voti, spoof anonimo di ID account e letture
personalizzate fuori dalla transazione autorizzata; autori al lavoro su fix e
regressioni. Pseudonimo pubblico deve comparire anche nelle leghe account.
Restano gate finali backend/Flutter e le prove di recovery sul client reale.

### Chiusura fase 2 — 14 ottobre 2026

Checkpoint: HEAD invariato `1fad162218e758efa3a556790e42b335a6196959` più
diff locale completo. Manifest codice di 362 file (esclusi Markdown/documenti)
`/tmp/sentinelle-baseline-20261013/phase2-code-files.json`, SHA-256
`27284f29703acf5607435e8682e6c7369d701f228aba7ee12c42e2c064f91f19`;
snapshot `phase2-workspace.tar.gz` nella stessa directory.
Nessun file baseline rimosso; cinque migrazioni iniziali e migrazioni 6–8
preservate. Nessun commit o operazione remota effettuati.

File principali: backend account-service, account-repository/statements,
simulated-email, migrazione 8, guardie principal/sessioni nei repository e HTTP,
OpenAPI, README e test account; Flutter feature `account/**`, lease source comune,
gateway account/guest, recovery comandi fantasy, config/provider/router/profile
e test unit/widget/fixture PostgreSQL. Nessun import demo né somma di punti.

Verifiche effettive sulla revisione finale:

- Node 24, PostgreSQL 17.10, `TEST_DATABASE_URL=… npm --prefix services/backend test`:
  **148 PASS**, 13 suite, zero skip/fail; `/tmp/account-backend-full-final.log`.
- Manifest **8 migrazioni PASS**, OpenAPI YAML e otto route account verificati;
  `git diff --check` PASS. Checksum migrazione 8 invariato come sopra.
- Flutter 3.44.2, `TEST_DATABASE_URL=… FANTASY_TEST_NODE=… flutter test`:
  **365 PASS**, 349 regressioni e 16 nuovi test account (14 unit/widget, 2 flussi
  PostgreSQL reali), `/tmp/sentinelle-phase2-flutter-tests.log` e
  `/tmp/sentinelle-account-tests.log`.
- Analyze con policy README: PASS, **218 info**, zero warning/error;
  `/tmp/sentinelle-phase2-analyze.log`. Non lint-clean.
- Tre build release PASS: default, fantasy mock, account API con
  `ACCOUNT_MODE_ENABLED=true`; `/tmp/sentinelle-phase2-builds` e log
  `/tmp/sentinelle-phase2-build-{default,mock,account-api}.log`.
- Nove render AppTheme a 390/1024/1440: errori/tastiera, conflitto, offline;
  PNG `/tmp/sentinelle-account-visuals`. Orchestratore ha ispezionato errore390,
  conflitto1024 e offline1440; nessun overflow visibile. Nessuna certificazione.

Review finale indipendente `account_review`: nessun P1/P2 identificato residuo.
Corrette revoca da token scaduto, grant account tramite guest, spoof di principal
anonimi e letture fuori transazione; pseudonimo pubblico nelle leghe senza email.
Verificati OTP monouso/rate, recovery su altro dispositivo, revoca concorrente,
linking idempotente/risposta persa, conflitti espliciti, recovery trasferimento
PRE-login e ricevuta originale POST-link, scope legacy e barrier client.

Limiti: solo email sintetiche/outbox privata in-process, nessuna consegna reale;
flag account disattivato per default; guest mantenuto per ricevute, senza grant
account dopo logout; lock transazionale globale dichiarato. Nessun gate operativo
chiuso. Fase 3 ora autorizzata, envelope `sentinelle_phase3_envelope.md`.

### Avvio fase 3 — FG-01, FG-02

Prerequisiti fase 2 verificati. Proprietà: `account_backend` servizi backend e
contratto, `account_flutter` client/test Flutter, `account_review` sola lettura;
orchestratore documenti/integration. Nessun autore concorrente per file.

### Checkpoint di ripresa e revisione del metodo — 15 ottobre 2026

Su richiesta utente, persistito metodo a minor consumo nel piano e nel prompt
orchestratore. Requisiti/gate invariati; deleghe con contesto circoscritto,
contratto prima del codice, review sul candidato pronto, test mirati durante
sviluppo e gate completo alla chiusura. Nessuna implementazione riavviata con
questa revisione documentale; nessun collaboratore attivo al controllo del 15.

Stato: fasi 0–2 verificate; **fase 3 in corso, non verificata**; fase 4 solo
preparazione in `sentinelle_phase4_envelope.md`; fasi 4–8 non implementate.
Backend fase 3: ultimo log `/tmp/sentinelle-mission-backend-full-final.log`,
**163 PASS**, 13 suite, zero fail/skip. Ricevuta aggiunge metadata immutabili delle
prove; corrette finestra settimanale, probe readiness e parser PNG.
Questo esito è riferito al candidato del 14 ottobre, non certifica modifiche
successive. Il log Flutter `/tmp/sentinelle-mission-tests.log` mostra errore di
compilazione su `municipalityChanges`; non considerarlo PASS.

Prossima azione: verificare sul diff corrente e chiudere i residui Flutter della
fase 3: binding/guardie cambio Comune durante richieste e scritture pendenti,
riepilogo con conferma prima invio, esenzione foto per nonObservable/unsure,
receipt completa, recupero/rimozione esplicita delle bozze sicuramente rifiutate.
Alcune correzioni sono già scritte: ispezionarle prima di rifarle. Eseguire test
mirati con PostgreSQL, poi gate Flutter/analyze/build pertinente/layout e review
finale. Congelare checkpoint fase 3 soltanto dopo esiti effettivi. Non rifare
baseline o porting delle fasi 0–2 senza cambi rilevanti. Nessun consumo per fase
misurato: nessuna promessa quantitativa di risparmio.

### Chiusura fase 3 — 15 ottobre 2026

FG-01/FG-02 **verificati localmente**. HEAD invariato più diff protetto;
checkpoint 382 file codice/config, `phase3-code-files.json` SHA-256
`dad28925382b8edeb6052bd284e0ab20ed2ab4d509da86b0f20a64b15857632e`,
snapshot `phase3-workspace.tar.gz` in `/tmp/sentinelle-baseline-20261013`.
Migrazione 9 `20261014160000000_missions.js` immutabile, SHA-256
`9f357748bafd39a09b13b3dcc20b13fcbdbd5a6d47942a269ef98f5e8b1d58fd`.

Backend: service/repository/statements mission, storage privato, sanitizer PNG,
HTTP/OpenAPI/config e test. Client: mission models/repository/draft/controller,
picker web, UI/provider/router/intent e guard opzionale LocalDataStore.
Verifiche: backend **163 PASS**, 13 suite zero fail/skip nel log finale del 14
ottobre (nessun file backend cambiato dopo quel log); manifest **9 PASS**,
OpenAPI YAML **13 route missioni PASS**, `git diff --check` PASS.
Flutter **384 PASS**, zero fail/skip: `/tmp/sentinelle-phase3-flutter-tests.log`;
mirato missioni/persistenza **24 PASS**, compresi tre flussi PostgreSQL reali.
Analyze policy README PASS, **282 info**, zero warning/error, log
`/tmp/sentinelle-phase3-analyze.log`. Build release mission API con account e
fantasy API, pilot sintetico Tuglie, PASS con wasm dry-run:
`/tmp/sentinelle-phase3-build-mission-api.log`. Profili invariati non ricostruiti;
rehearsal finale li ricontrolla tutti.

Tre test widget PASS; 18 render AppTheme 390/1024/1440 con GPS assente, tastiera,
conferma, permesso negato, errore salvataggio e ricevuta in
`/tmp/sentinelle-mission-visuals`. Root ha ispezionato conferma390, tastiera1024
e ricevuta1440; overlay/dialog ora incluso e font caricati per la verifica
visiva, senza prerequisiti temporanei per la suite ordinaria.
Ultimo delta solo fixture widget (errore offline HTTP coerente, debug banner off)
ricontrollato con tre widget PASS e render rigenerati; suite384/build/analyze
rimangono valide per codice produzione invariato. Checkpoint include questo delta.
Review indipendente bounded: due P2 corretti e ricontrollati (rollback disco
false/throw blocca store; generazione Comune invalida anche A→B→A durante
richieste e scritture). Nessun P1/P2 residuo individuato nel controllo circoscritto.

Concorrenza ultimo slot/rinuncia, upload risposta persa/ripresa/riavvio,
isolamento prove, PNG avversari, expiry/revoca dopo lock, rollback/orfani non
accessibili, receipt immutabile e recovery, invio senza foto nei casi ammessi,
bozza offline/scaduta e rimozione esplicita verificati. Picker solo web;
nessuna certificazione nativa. Nessun dato reale, XP o esito competitivo.
Orfani/retention operativa restano rehearsal fase 8; gate operativi aperti.

Prossima azione: fase 4 FG-03/FG-07, contratto fissato nell'envelope 4 prima
delle deleghe. Ruoli sintetici per Comune, revisione umana, ledger10XP e
integrazioni/repliche; ricevuta originale fase 3 preservata.

### Fase 4 — decisione di compatibilità migrazioni, 15 ottobre

Primo gate backend: 174 test, 171 PASS e tre failure nei test migrazioni;
servizi/route verdi, fase non ancora verificata. Due aspettative storiche da
aggiornare; down della migrazione 10 tenta DROP INDEX dopo che DROP COLUMN ha
già eliminato l'indice dipendente. Migrazione 10 già applicata: checksum e file
restano immutabili, come richiesto dal prompt.
Correzione autorizzata locale: migrazione additiva 11 con nome proprio per
l'indice unique replica e indice di compatibilità indipendente dalla colonna.
Down11 conserva intenzionalmente questa compatibilità fino al down10; up11
deve tollerare shim già presente. Test down11→down10→up10→up11 e replay11 su
database usa e getta. Non promettere downgrade con dati replica incompatibili
con vincoli vecchi: rollback operativo tramite restore nella fase 8.

### Chiusura fase 4 — 15 ottobre 2026

FG-03/FG-07 **verificati localmente**. HEAD invariato più diff; checkpoint 397
file codice/config `phase4-code-files.json`, SHA-256
`dc5c553293304d1b89419e6deedeed18fb6540749d2d2fa83de3c2f6d940cdac`,
snapshot `phase4-workspace.tar.gz` in `/tmp/sentinelle-baseline-20261013`.
Migrazione10 `20261015100000000_observation_review.js` SHA
`55c3a78c791f60c64e77842f410c5daffad0792bc16128516a0bd0a86933ce26`;
11 `20261015110000000_review_downgrade_index_compat.js` SHA
`f6f8dca20d5df88da6cc3913ea973f8b3081870aac4677e1620da44d0b4884c3`.
Nove migrazioni precedenti preservate, 10 immutata dopo applicazione.

Backend: review service/repository/HTTP, grant CLI locale, integrazioni/prove,
repliche, ledger, schema/contratto/config e test; **176 PASS**, 13 suite, zero
fail/skip `/tmp/sentinelle-phase4-backend-full.log`. Mirato schema/mission/review
34 PASS; ultimo delta recovery replica/newdevice 12 PASS, log
`/tmp/sentinelle-phase4-backend-replica-recovery-targeted.log`. Manifest **11 PASS**,
OpenAPI **15 route fase4 PASS**, diff-check PASS. Report/delta file in
`/tmp/sentinelle-phase4-backend-summary.md` e `...-backend-delta.json`.

Flutter: feature review, intent account-stable, repository/controller/UI,
router/config/profile, estensioni missioni per replica e fixture/test. **403 PASS**,
zero fail/skip `/tmp/sentinelle-phase4-flutter-full.log`; analyze policy README
PASS **339 info**, zero warning/error `...-flutter-analyze.log`. Build release
review/mission/account/fantasy API PASS, wasm dry-run PASS, log
`/tmp/sentinelle-phase4-review-build.log`. Warning font Cupertino preesistente;
nessuna dichiarazione lint-clean. Tre widget PASS con 18 PNG finali a
390/1024/1440 `/tmp/sentinelle-review-visuals`, log `...-flutter-widgets-final.log`.
Root ha ispezionato tastiera390/integrazione1024 e finali answered-recovery390,
current-XP1440; note readonly mostrano il body effettivo da recuperare.

Un flusso Dart PostgreSQL reale PASS `...-flutter-pg.log`: ruoli/stage/prove,
integrazione dopo booking expiry, risposte perse/replay, approvazione10 una volta,
replica richiesta fino a saldo20, ricevuta originale XP0 invariata. Nuovo
dispositivo recupera booking replica owned da GET richiesta, senza altro slot/XP.
Guardie account/Comune e intent restano valide dopo nuovo login stesso account;
fresh403 può correggersi, replay403 dopo timeout conserva body/chiave.

Review indipendente: P2 supplemento bloccato da CAS obsoleto corretto e ricontrollato;
nessun altro P1/P2 individuato nel perimetro. Root ha verificato gli ultimi delta
fresh403, accountID stabile, recovery nuovo dispositivo e shim migrazione11;
regressioni mirate e gate finali acquisiti. Nessun ruolo reale, email/storage
esterni, XP reale, esito competitivo o certificazione nativa introdotti.

Prossima fase 5 FG-04/05/06: preparazione e proposta contratto in
`sentinelle_phase5_envelope.md`; fissare i confini restanti prima di scrivere.

### Avvio fase 5 — 15 ottobre 2026

Contratto fissato nell'envelope5 sul checkpoint4, owner `measurements_backend`
(`services/backend/**`), `measurements_flutter` (`lib/**`, `test/**`), root docs.
Prima delle deleghe risolti: fonte documentale OPPURE osservazioni quantitative
indipendenti (non requisito AND), misura opzionale su nuovi protocolli missione,
fingerprint legacy invariato, stagione esplicita/clock server, deadline di tutte
carte v2, equality threshold stable, shared UoW e pubblico privo di originali.
Scoring v1 intatto, nuove stagioni `fantasy-v2`, revisioni risultati atomiche e
consultabili. Review da attivare dopo candidato con test mirati PASS; gate 5 aperto.

### Verifica candidata fase 5 — ripresa 15 ottobre 2026

Backend candidato: misurazioni 12 PASS, regressioni fantasy/missioni 39 PASS;
Flutter mirati 12 PASS (8 unit, 3 widget, 1 PostgreSQL reale), suite completa
415 PASS. Gate finali backend, analyze e build in acquisizione: fase non chiusa.
Report e log compatti `/tmp/sentinelle-phase5-backend-summary.md`,
`/tmp/sentinelle-phase5-client-targeted.log`, `...-client-full.log`.
Root ha ispezionato correction-keyboard390 e coverage-undeterminable1440 dei
12 render sintetici `/tmp/sentinelle-measurement-visuals`.

Migrazioni applicate immutabili:12 SHA256
`2f9cb1888d28031e60b3bd9b756a1ef1ed39fd4a70cad0acc675c3d9b0f4ebaf`;
13 SHA256 `a06a353900e2f03f158d05f5a105ea22eebd30744e278266f524c15bc884716c`.
La13 rende differibile la FK dei nuovi risultati, necessaria per il linking
atomico guest→account; test v2 storico/conflitto keepAccount inclusi.

Review indipendente bounded `measurements_review`: un P2 nel confronto numerico
della soglia. L'epsilon proporzionale alla baseline classificava stable un delta1
con soglia0.9999999 e baseline999999999; riproduzione Node confermata. Correzione
assegnata all'autore backend con regressioni di uguaglianza decimale e soglia zero.
Nessun altro P1/P2 concreto individuato nel perimetro; non equivale a certificazione.
Proposta route/DTO fase6 preparata nell'envelope6, attivazione subordinata al gate5.

### Chiusura verificata fase 5 e avvio fase 6 — 15 ottobre 2026

Checkpoint5: **417 file**, digest codice/config
`e75a4a6ff9e411ed649a89f3dadfc6928d13d6090ef288f634df459e301b90e0`, manifest
`/tmp/sentinelle-baseline-20261013/phase5-code-files.json`, snapshot
`phase5-workspace.tar.gz`. HEAD invariato; modifiche preesistenti preservate.

Backend finale **189 PASS**,13 suite, zero fail/skip, parità48 v1 inclusa:
`/tmp/sentinelle-phase5-backend-full-final.log`. Ultime tre guardie UUID route
corrette dopo il full: mirati **13 PASS** incluse HTTP400, log
`...-backend-uuid-targeted.log`. Manifest13 PASS, migrazioni1–11 immutate,
OpenAPI97paths/17measurementpaths+history/161refs e queryseason PASS, diff-check
PASS. Report/delta32file `...-backend-summary.md`, `...-backend-delta.json`.

Flutter **415 PASS**, poi mirati **38 PASS** su recovery readonly/versione v2/
prove/editor e **17 PASS** su ultimo delta allowlist/login; nessun fail/skip.
Analyze finale **396 info**, zero warning/error. Build release API measurements/
review/mission/account/fantasy e wasm dry-run PASS prima degli ultimi piccoli
delta coperti dai mirati/analyze. Dettaglio temporale e delta29file in
`/tmp/sentinelle-phase5-client-summary.md`.12render390/1024/1440; root ha visto
anche offline-uncertain1024 finale. Nessuna attestazione nativa o umana.

Review indipendente: P2 numerico chiuso con confronto decimale BigInt e7assert
indipendenti; nessun nuovo P1/P2 nei recheck. Reconciler interno mantiene deadline
v2 anche con console off, stessa UoW/pool1, nessun seed o storage prove richiesto;
13mirati e full189 lo coprono. Originali ricevute/XP e scoring v1 conservati;
rettifiche, storico/ranking, linking guest e scope multistagione verificati.

Fase6 FG-11 avviata sul contratto `sentinelle_phase6_envelope.md`: preview pubblica
senza token URL/log, summary/confirm espliciti, offerte di proprietà accettate,
CAS/replay, archivio owner exit e linking atomico. Due autori a ownership disgiunta;
nessuna implementazione fase7/8 o autorizzazione al pilot reale.
Owner fase6: `continuity_backend` services/backend/**, `continuity_flutter`
lib/** e test/**; root documenti. DTO preview e ownership fissati prima delle
deleghe; intent account usa accountID stabile, guest usa submissionScope.

### Ripresa dopo limite crediti e reset runtime — 15 ottobre 2026

Codice e documenti persistiti presenti, HEAD invariato. Gli artefatti storici
`/tmp/sentinelle*` (inclusi manifest5, snapshot e log) non sono più disponibili;
PostgreSQL55432 spento. I risultati fase5 sopra sono il registro storico, non
nuove verifiche effettuate su questa ripresa. Non ricostruire il digest5 usando
i partial6 né dichiarare recuperati gli originali mancanti.

Nuovo checkpoint **resume6partial**,426 file, SHA256
`3a3d18d4eef57b769c4152b8d39c270a5cd090c21078aec83a7594871c3da938`, in
`.sentinelle-local/checkpoints/resume6partial-code-files.json` e
`resume6partial-workspace.tar.gz`. Cartella locale privata esclusa da Git;
nuovi log in `.sentinelle-local/phase6/{backend,client}`. Il checkpoint fotografa
codice parziale non verificato, distinto dalla baseline storica5.

Owner ripresa: `continuity_backend_resume` services/backend/**, ricrea anche
PostgreSQL sintetico in `.sentinelle-local/pgdata`; `continuity_flutter_resume`
lib/** e test/**. Nessun vecchio autore attivo. Nuovi gate locali da eseguire;
migrazioni1–13 immutabili,14 da verificare senza assumere stato applicato passato.
Postman CLI disponibile su indicazione utente `/Users/gabrieleserra/.local/bin/postman`;
nessun requisito di invocazione né credenziali aggiunti.

Ripresa6: PG17 locale ricreato e attivo55432; primi24test legacy account/leghe
PASS, candidato backend42PASS (10continuity+24legacy+8migration), log
`.sentinelle-local/phase6/backend/targeted-candidate2.log`. Client10unit+1PG reale
PASS preliminari, widget e gate finali in corso; nessuna chiusura fase6 attestata.
Review bounded `continuity_review` avviata. Regressione create dopo trasferimento
confermata prima del full: partial cambiava creation_key per liberare il vincolo
owner e il replay dell'ex owner poteva creare un'altra lega. Fix autorizzato:
creator distinto da owner, creationkey immutabile e migrazione15 additiva;
test linking/collisioni e nessun recupero di privilegi dopo uscita. Dettaglio
contratto nell'envelope6, autori ancora attivi.

Gate client6 finale acquisito: **434 PASS** suite completa,29mirati incluse
11unit/7widget/1PG reale/10regressioni, analyze **420 info,0warning/error**,
build release web profilo API+account+missioni+review+misurazioni+continuity e
wasm dry-run PASS. Log persistenti `phase6/client/{full-test,analyze,build-web}.log`.
Sei PNG invite/ownership390/1024/1440; tastiera Tab e testo2x375PASS, root ha
ispezionato invite390 e ownership1440. Delta ripresa4aggiunti10modificati rispetto
checkpointresume6partial, non ricostruzione baseline5. Review client nessunP1/P2.

Backend creator15 candidato **45 PASS** (13continuity/24legacy/8migration), log
`phase6/backend/targeted-creator15-pass.log`. DDL draft15 su fixture popolata ha
rilevato ALTER dopo UPDATE con FK differite: riordinata prima freeze, nuova
prova down/up/down/up rollbackPASS; 1–14immutate. Erasure preserva creation_key,
creator storico e account-key-wins coperti. Recheck indipendente15 avviato,
full backend e chiusura fase6 ancora da acquisire.

Recheck finale15: runtime create/transfer/linking coerente; limite downgrade
post-transfer preservato e documentato. Test14continuityPASS include down23505
in TX annullata con dati/schema/ricevute intatti. SHA15 congelata
`09bd835671ed767a462a75a24ca02b93ba591d0a5ecba2868ccdee7ff8f88557`;
nessun DB non usa-e-getta ha ricevuto la draft15. SQL1–14 invariati.

Test client grafo reale AppDependencies ha trovato alias Provider semplice su
ChangeNotifier: sostituito con InheritedProvider non-owned, fonte originale
ChangeNotifierProvider conserva ownership/notifiche. Regressione8widgetPASS,
full post-fix **435 PASS**, analyze420info0warning/error; buildfinaleinacquisizione.
Primo full backend ha invece trovato regressione quota join legacy: token
malformato respinto prima rateLimit non consumava tentativi. Fix assegnato,
mirati e fullpostfix necessari; quel full non è PASS. Fase6 resta aperta.

### Chiusura verificata fase 6 e avvio fase 7 — 15 ottobre 2026

Checkpoint6 **432file**, SHA256
`ca3db6836dffd75f7acf9dc65220ec55d606d8347b4b8354c3892c01593f273b`, in
`.sentinelle-local/checkpoints/phase6-code-files.json` e snapshotworkspace6.
HEAD invariato. Nuovo helper persistente `.sentinelle-local/save_checkpoint.py`;
cartella700 e checkpoint600, esclusi da Git. Nessuna baseline5 mancante ricreata.

Backend finale **204PASS**, zero fail/skip, `phase6/backend/full-postfix.log`;
mirati29PASS dopo fix quota join legacy (precedente full203/204 nonPASS).
Manifest15PASS, OpenAPIparse+576refs PASS, diff-checkPASS; SQL1–14immutati e15
SHA congelata invariata. Nuovi inviti/ownership/creator/linking verificati.
Review finale nessun P1/P2 runtime residuo; down15 post-transfer resta limite
esplicito e testato con23505/rollback intatto. Rollback operativo è restore
con scritture sospese da provare in8, non downgrade forzato con riscrittura key.

Flutter finale **435PASS**, analyze420info0warning/error, releaseweb/wasmdryrun
PASS dopo fix alias InheritedProvider. Log `phase6/client/{full-test-final,
analyze-final,build-web-final}.log`;11unit recovery con store/repository davvero
ricostruiti e8widget con grafo AppDependencies reale. Handoff e manifest19file
`phase6/client/handoff.md` e `client-candidate-files.json`, SHA256
`38274baf62b9ebeb94e75e3373b56bdaa17c68d27661dcf5955d7c55ca382641`.
Sei render390/1024/1440, tastiera e testo2x375PASS, root viste invite390 e
ownership1440. Nessuna attestazione nativa/umana.

Smoke root IAB su build release servita localhost8765: apertura con frammento
invito sintetico, URL osservato dopo bootstrap `/#/league-invite` privo del token;
landing esplicita senza iscrizione automatica. API server non avviato in questo
smoke, errore preview coerente; non è E2E adesione (coperta dal PG client).
Scheda temporanea e server statico chiusi. Nessuna risorsa esterna attivata.

Fase7 FG-12/13/14 avviata su envelope7 fissato: copertura Comune/leghe dedup,
eventi/inbox transazionali account-only, follow luoghi, calendario locale
idempotente e ritorno al secondo controllo. Fase8 solo preparata, pilot NO-GO.
Owner7: `cooperation_backend` services/backend/** e `cooperation_flutter`
lib/** e test/**; root documenti. Nuovi log `.sentinelle-local/phase7/`.

Chiarimento contratto7 durante implementazione: ricontrollo ai follower punta
al dettaglio pubblico missione, nuovo target `{kind:mission,missionId}`; non
genera richieste replica individuali, obblighi o scope XP aggiuntivi. Target
recheck con replicationRequestId resta solo al destinatario umano originale.
Root ha respinto l'ipotesi di creare una replica per follower prima del gate;
backend e Flutter informati, nessuna nuova policy bonus autorizzata.

### Ripresa fase7 e finding routing — 15 ottobre 2026

Artefatti `.sentinelle-local` conservati; alla ripresa nessun vecchio subagente
attivo. Owner correnti `cooperation_backend_resume` e `cooperation_flutter_resume`.
Backend45miratiPASS in `phase7/backend/targeted.log`; migrazione16 congelata dopo
DDL up/down/up con tabelle popolate e rollback. Full7 non ancora attestata.
Client6unit/4widget/PG realePASS preliminari: pubblicazione2calendari con writerCLI
condiviso, approvazione vera, copertura e inbox2device/read retry/followserver.
Root viste inbox2x390 e lega2x1440; render non sostituiscono il gate routing.

Review indipendente `cooperation_review` aveva individuato **P1 client** prima
dell'interruzione: /cooperation,/inbox,/followed-places duplicate come prime route
in ogni StatefulShellBranch, cambiando defaultLocation dei tab. Correzione
assegnata al nuovo owner: sole route top-level, regressione routing reale su tab
legacy/fantasy e grafo AppDependencies. Review/backend/full finali ancora aperti;
nessuna chiusura fase7 da inferire dai test preliminari.

Ripresa7 verifiche: backend47/47miratiPASS `targeted-resume.log` più7/7
`cooperation-final.log` dopo rafforzamento caso archivio con contributore membro
spettatore e unità distinta. PG era invisibile al sandbox, ma già attivo: nessun
riavvio/reset del cluster. Migrazione16 SHA congelata
`9827c4d191898cdd07725067bafce5baa7ee548fdf29228bac2c298093720f36`.
Reviewer corrente `cooperation_review_resume`, sorgenti backend ferme in review.

Client rimosse27route duplicate da9branch; restano3top-level. Nuovo test router
reale verifica selezione/reselect tab legacy/fantasy con/senza Comune; ha trovato
anche2constText con lettura context non costante, corretti prima dei gate.
I test con sole pagine/provider fixture non attestavano la composizione routing
reale: gate specifico e full/build necessari prima chiusura7.

Nuova review7: P1 routing chiuso con32miratiPASS incl6routerreali; OpenAPIsecurity
`proposalSession` inesistente sostituito con `proposalBearer`, parse108paths e
589refs/securityPASS. Ipotesi race drain outbox esclusa: tutti i writer/drain
supportati condividono advisory76131001 nella UoW, nessuna modifica inutile.

Due P2 confermati prima full: parser inbox ASCII-only rifiutava ID validi con
colon (riproduzione calendario mission:weekly); publisher controllava lock solo
prima degli INSERT e poteva committare oltre lock. Fix assegnati: IDopachi bounded
coerenti, URI-safe e allowlist; recheck clock dopo checkpoint precommit con
rollback integrale. Contratto precisato envelope7, migrazione16 immutata.
Autori ancora attivi su soli fix; gate7 resta aperto.

### Chiusura verificata fase7 e avvio fase8 — 15 ottobre 2026

Checkpoint7 **449file**, SHA256
`e5666957872d81e44ffd287632b1e423345d6c9120523bb9d6f25cf581bfa237`, in
`.sentinelle-local/checkpoints/phase7-code-files.json` e snapshotworkspace7.
HEAD invariato, sorgenti autori ferme prima snapshot, modifiche preesistenti
preservate. Artifact persistenti `.sentinelle-local/phase7/{backend,client}`.

Backend **212/212PASS**,13suite, zero fail/skip, `backend/full.log`;48fixturev1
e righe v1 preservate incluse. Manifest16PASS,1–15immutati, SHA16frozen invariata,
OpenAPI108paths/589refs/security e diff-checkPASS. Delta22file/handoff inbackend.
Obiettivi Comune/leghe, inbox/outbox/follow e calendario sintetico condiviso
verificati con ricontrollo settimanale, restart, rollback e nuovo device.

Flutter **455/455PASS**, PG incluso, `client/full-final.log` dopo fix locale
AppConfig nullable nelle missioni (primo full452/455 nonPASS). Analyze finale
**462info,0warning/error**, policy PASS (exit1 per info, non lint-clean),
`client/analyze-final.log`. ReleasewebfullAPI cooperazione+continuità ewasmdryrun
PASS `client/build-full.log`; nessuna modifica codice dopo full/build, manifest
19file in `client/candidate-sha256.json`, delta/handoff persistenti.
12PNG390/1024/1440+2xtesto/tastiera; root viste inbox390 e lega1440.

Review indipendente conclusa: P1route duplicate chiuso con router vero legacy/
fantasy/tutti tab; P2 IDopachi e lockprecommit chiusi con20testclient e8PG
discriminanti. Nessun P1/P2 residuo nel perimetro. Screenshot non certificazione.

Fase8 avviata su envelope8 fissato: solo strumenti ops sintetici loopback,
backup/restore isolato e diario cancellazioni, retention/prove/orfani, osservabilità,
identitàcode/profile e cinquebuild finali dopo freezeID. Nessun nuovo provider,
email reale, push/merge/deploy. Dossier operativo ancora **NO-GO** con gate umani
aperti; cancellazione fantasy/retention distinte da chiusura completa account.
Owner8 `operations_backend` services/backend/**, `operations_flutter` lib/** e
test/**; root browser/documenti e freeze CANDIDATE_ID dopo suite complete.
Diagnostica Flutter locale/config senza chiamata health o lease automatica:
backend dichiarato non verificato; root incrocerà i metadati server nello smoke.
Erasure fantasy preserva account/sessioni per missioni/proposte; revoca sessione
è operazione distinta. Il diario protegge quel namespace, non simula chiusura
integrale account. Precisazione comunicata all'autore prima implementazione ops.

Candidato client8 cinquefile: root review bounded diretta senza P1/P2,21mirati
PASS. Diagnostica ha9widget render layout a3larghezze/2xtesto, **non PNG**;
visivo browser previsto dopo build. Analyze462info0warning/error PASS. Full
anticipato contro backend ancora WIP:466totali/464PASS/2FAIL PostgreSQL mission/
review, non gate verde. Nessuna aspettativa test ammorbidita; ripetizioni ferme
fino a sourcefreeze di entrambi gli autori. Metodo aggiornato nel piano per
aspettare stabilità trasversale prima dei full che importano servizi backend.
Backend in corso su journal/backup/restore/retention; nessun build5 o ID finale
congelato prima dei gate integrati.

Causa2fail FlutterPG: hardening path prove rifiutava alias macOS di sistema
`/var`→`/private/var` e `/tmp`→`/private/tmp`. Canonicalizzati soltanto alias
fidati, restano rifiutati symlink privati. Mirati mission/review Flutter **4/4PASS**
`phase8/client/postgres-regression-fixed.log`, nessuna modifica aspettative/client.

Backend ops **4/4PGPASS** `phase8/backend/ops-targeted-3.log`: dump/restduecopie,
backup1→erase HTTPaccount+guest→restore senza resurrezione, reenroll→backup2 con
watermark→restore preserva nuovi dati, dump corrotto rifiutato, revoca separata,
cleanup fault/retry/altro utente/symlink. Altri55mirati mission/review/server/config
PASS. Reviewer `operations_review` attivo su ops/replay/prove/metadata/logging;
rehearsal coesa e fullbackend ancora da acquisire. Nessuna migrazione nuova.
Client5file sourcefermi; fullintegrato definitivo e5build dopo candidato comune
stabile/ID reale. Diagrammi/screenshot non sono attestazioni privacy operative.

Reviewops8 indipendente ha trovato3problemi prima full: **P1** copia restore già
valida prima replay senza quarantena persistente runtime (fault poteva lasciare
readinessverde con cancellazioni non riapplicate); **P2** subdirectory backup/proofs
symlink non verificata, malgrado controllo filefinale; **P2** keyjournal cached,
perdita/corruzione sul filesystem non degrada istanza già attiva. Fix assegnati
all'autore con test fault+readyruntime, symlinksubdir ekeymissing/currentinstance.
Nessuna nuova migrazione al momento;1–16 e manifest identici alla baseline7.
Gate8 ancora aperto, nessun CANDIDATE_ID né cinque build congelati.

Rehearsal8 sviluppo coesa HTTP+PG PASS: `phase8/backend/rehearsal-development-3.log`,
72richieste con eventi statici, **IDplaceholder c×64, non candidato finale**.
Account recuperato,2calendari, invito/trasferimento/creatorcollision+down15rifiutato
atomicamente,4PNG e integrazione, criticità/nessunacriticità10XP, retry/restart,
intervento temporaneo, pubblicazione/ricorso/rettifica non determinabile,
copertura/inbox e secondo controllo settimanale20XP. Dump/restore PG reale:
fantasy cancellato non riappare, altro utente/ricevute/XP/pubblicazioni/membership/
inbox verificati. Non attribuire questa prova al futuro ID reale senza rerun.
I3fix review sono implementati ma fault mirati/recheck ancora in corso; marker
restore firmato persistente con runtimeguard anche OPSfalse, altreprotezione
key corrente eproofssubdir. Nessun full finale verde ancora attestato8.

Fixreviewops mirati **4/4PASS**, `phase8/backend/ops-review-fixes.log`: fault
fra replay mantiene markerpending persistente; runtime conOPSfalse dà /ready503
ePOSTsession503. Proofssubdirsymlink rifiutata; keyrimossa su istanza già attiva
degrada journalready. Markerready firmato HMAC candidateId/journalId/appliedSequence,
controllo runtime anche keyalterata/mancante, IDdiverso e diarioavanzato.
Nessuna migrazione17. Recheck bounded `operations_review` avviato sui tre delta;
rehearsaldevelopmentultima e fullbackend ancora in acquisizione.

### Stato verificato dai log alla ripresa — 16 ottobre 2026

Recheck indipendente3fix ops concluso PASS, nessun finding residuo nei tre delta.
Ultime suite su sorgenti ferme sono terminate anche dopo interruzione crediti:
backend **217/217PASS**,13suite, zero fail/skip,48.5s
`phase8/backend/full-final.log`; Flutter **466/466PASS**,34s
`phase8/client/full-final.log`. Analyze precedente462info0warning/error.
Rehearsaldevelopment5 PASS con77eventi statici, restoredHTTPready e4prove;
usa ancora **placeholder c×64**, non ID definitivo.

Fase8 resta aperta: da congelare manifesto/CANDIDATE_ID reale, eseguire cinque
build separate, ripetere rehearsal identificata e smoke browser, consolidare
dossier/matrici/checkpoint finale. Nessun build5 o checkpoint8 finale presente
negli artefatti controllati. Nessuna attivazione reale; pilot NO-GO invariato.

### Freeze candidato8 reale — 16 ottobre 2026

Confrontati manifesti source-freeze backend129file e client5file: nessuna
variazione dopo i gate217/466PASS. Checkpoint **phase8-candidate,462file**,
digest/CANDIDATE_ID
`e75f7744a9d55c620fb7c08388761d98b911a850d0f29eeeb6588faa9c7b1fad`, in
`.sentinelle-local/checkpoints/phase8-candidate-code-files.json` e snapshot.
HEAD invariato. Build5 e rehearsal con IDreale avviati; non ancora attestati.
Helper build locale corretto prima avvio: fullSentinelle pilotTuglie, fantasyAPI
pilotBologna, coerenti con i rispettivi profili sintetici. Solo helper ignorato,
nessuna modifica al codice congelato. Log nuovi build-all.log e rehearsal-final.log.


### Chiusura locale fasi0–8 — 16 ottobre 2026

**Fase8 verificata localmente; pilot reale NO-GO.** Candidato immutato dopo
freeze: **462file**, CANDIDATE_ID
`e75f7744a9d55c620fb7c08388761d98b911a850d0f29eeeb6588faa9c7b1fad`.
HEAD di base `1fad162218e758efa3a556790e42b335a6196959` più modifiche locali,
nessun nuovo commit/push/merge/deploy. Documenti Markdown esclusi dal digest.

Riscontri finali sui log reali: backend217PASS/13suite/0fail/0skip;
Flutter466PASS. Analyze462info/0warning/0error, non lint privo di segnalazioni.
Manifest migrazioni16PASS; OpenAPI108path/591ref risolti; `git diff --check` PASS.
Cinque build web release PASS con IDreale: legacy-mock, legacy-api,
fantasy-mock, fantasy-api e sentinelle-api. Output separati e manifest in
`.sentinelle-local/phase8/client/build-*.manifest.json`;104artefatti per profilo,
hash fileclient e tutti gli artefatti ricontrollati PASS dopo i build.

Rehearsal finale PASS, `phase8/backend/rehearsal-final.log`, artefatto
`rehearsal-6b4285cc-b546-4c1c-ae38-a3cd4f6ae116`, **IDreale sopra**.
Profilo synthetic-local, clock2027-01-01..2027-01-09UTC controllato.
HTTP/PG, recupero account, calendario, invito/trasferimento, down15rifiutato
atomicamente, osservazioni con/senza criticità, integrazione, retry/ricevuta/
restart, intervento temporaneo, ricorso/rettifica non determinabile, copertura/
inbox e secondo controllo PASS. Backup/restore nuovoDB ready, quattro prove,
una cancellazione replay dopo backup, altro utente e storico preservati;
readiness HTTP restaurata identificata.77eventi statici. Nessun risultato della
rehearsal placeholder è stato attribuito al candidato reale.

Smoke CUA su `/diagnostics` nei cinque binari alle porte9101–9105 PASS:
IDcompleto verificato visivamente su ciascuno; flag e demo/API/laboratorio
coerenti, avviso backend non verificato e NO-GO visibile, nessun overflow desktop.
Sommario osservazioni `phase8/client/browser-smoke-summary.json`; screenshot
ispezionati nella sessione, nessun PNG esportato dichiarato. I test widget di
layout/scala testo restano evidenza distinta dallo smoke dei binari. Questa
visita diagnostica non è una prova browser completa di ogni flusso applicativo.
Tab temporanea chiusa e cinque server statici di verifica terminati; clusterPG
locale e artefatti sintetici conservati, senza cancellazioni ulteriori.

Aggiornati piano, envelope8, matrici porting/accettazione e dossier operativo.
Checkpoint finale `phase8-final-code-files.json`/`phase8-final-workspace.tar.gz`
in `.sentinelle-local/checkpoints/`: codice identico al candidato testato, include
la documentazione finale nello snapshot. Gli snapshot0–5 persi restano evidenza
storica registrata, non recuperata. Checkout sorgente non modificato.

Limiti: erasure **solo fantasy**, account/sessioni/missioni/audit conservati;
revoca e retention sono operazioni distinte. Nessuna attestazione di chiusura
account completa, conformità privacy, accessibilità umana o prove con utenti.
Downgrade10/15 potenzialmente rifiutati dopo uso: sospendere scritture/accessi
e ripristinare una copia coerente, senza forzare migrazioni storiche.
Restano da approvare provider/budget/email/storage, autenticazione forte,
responsabili/capacità, protocollo/fonti reali, privacy/retention, backup e incidenti
operativi e platea/target/avvio. Prossimo ambito: gate esterni del dossier;
nessuna nuova implementazione o riesecuzione completa necessaria senza delta.


### Decisione cloud Supabase e Resend — 16 ottobre 2026

L’utente accetta cambi ad architettura e tecnologia backend e sceglie Supabase,
Supabase Auth e Resend Free. Cloudflare Pages resta proposta frontend. Render
Free superato per il risveglio di circa un minuto; Firebase Auth non scelto.
Aggiornati runbook, piano, dossier e indice README; aggiunti diagramma prodotti
Mermaid e sorgente `.mmd`. Evidenze provider e quote ricontrollate su fonti
ufficiali e collegate nel runbook. Dominio/DNS, verifica percorso Resend senza
carta, prova Edge/transazioni/foto, porting e gate operativi restano aperti.
FigJam richiesto tramite skill: tool in attesa selezione team/organizzazione,
nessun URL finale disponibile; diagramma Mermaid già salvato nel repository.
Solo documentazione, nessuna implementazione, migrazione, creazione risorse o
deploy. Le attestazioni del candidato locale non si estendono al target cloud.

### Correzione diagramma FigJam — 16 ottobre 2026

Rimosso il collegamento external→external Resend/casella email, rifiutato
dal validatore architetturale. La consegna OTP è descritta sulla relazione
Supabase Auth→Resend. Sorgenti Markdown/Mermaid riallineati; controllati nodi,
subgraph, endpoint e assenza di cicli core. Nuovo tentativo: tool in attesa
selezione team/organizzazione; nessun render FigJam finale attestato.
