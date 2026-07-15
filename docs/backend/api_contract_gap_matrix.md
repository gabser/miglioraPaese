# API contract gap matrix

## Stato del documento

- Work package: `UC-00`.
- Micro-sessioni: `UC-00.1 complete`; `UC-00.2 complete`;
  `UC-00.3 complete`; `UC-00.4 complete`; `UC-00.5 complete`;
  `UC-00.6 complete`; `UC-00.7 complete`.
- Data inventario: 13 luglio 2026; ultima revisione: 14 luglio 2026 dopo
  chiusura di `UC-01`.
- Scopo corrente: `UC-00` e `UC-01` chiusi; ADR accettati, backlog consolidato
  e contratto OpenAPI invariato. `UC-02` non e' avviato.
- Classificazione: Next Problems completata in `UC-00.2`; Game completata in
  `UC-00.3`.

Questa baseline non implementa endpoint o dipendenze. Gli ADR accettati rendono
vincolante la direzione architetturale, non avviano l'esecuzione. Le righe sono
state valutate congiuntamente rispetto a schema, comportamento, test e consumer;
non restano elementi `not_assessed`.

## Riepilogo inventario

| Superficie | Elementi |
| --- | ---: |
| Membri pubblici di `GameRepository` | 19 |
| Metodi di `NextProblemsRepository` | 3 |
| Operazioni dichiarate in OpenAPI | 12 |
| Route registrate dal matcher HTTP | 12 |
| Casi di test backend | 19 |
| File di test Flutter direttamente rilevanti per Next Problems | 6 |
| File di test Flutter che esercitano direttamente `GameRepository` | 1 |

| Superficie classificata | `complete` | `partial` | `missing` |
| --- | ---: | ---: | ---: |
| `GameRepository` | 0 | 8 | 11 |
| `NextProblemsRepository` | 0 | 3 | 0 |
| Operazioni HTTP | 0 | 12 | 0 |

Le 12 coppie metodo/path OpenAPI hanno una route corrispondente nel matcher di
`services/backend/src/http/routes.js`. `OPTIONS` e' gestito trasversalmente come
preflight CORS e non e' un'operazione OpenAPI autonoma.

## Fonti della baseline

- `lib/features/game/data/game_repository.dart`
- `lib/features/game/data/mock_game_repository.dart`
- `lib/features/next_problems/data/next_problems_repository.dart`
- `lib/features/next_problems/data/api_next_problems_repository.dart`
- `lib/features/next_problems/data/mock_next_problems_repository.dart`
- `lib/features/next_problems/data/suggested_problem_mapper.dart`
- `lib/features/next_problems/logic/next_problems_cubit.dart`
- `services/backend/openapi.yaml`
- `services/backend/src/application/backend-service.js`
- `services/backend/src/domain/catalog.js`
- `services/backend/src/http/app.js`
- `services/backend/src/http/routes.js`
- `services/backend/src/infrastructure/memory-store.js`
- `services/backend/src/server.js`
- `services/backend/test/config.test.js`
- `services/backend/test/server.test.js`

I riferimenti `file:riga` descrivono la baseline corrente e vanno aggiornati se
una micro-sessione successiva modifica i file sorgente.

## Criteri di classificazione

La classificazione misura la prontezza rispetto al pilot descritto nel
productization plan, non soltanto l'esistenza di uno scaffold nominale.

- `complete`: firma Flutter, trasporto, schema, server, mapper e test sono
  semanticamente allineati e sono presenti le garanzie richieste dal pilot.
- `partial`: il percorso nominale e' utilizzabile, ma restano gap di
  comportamento, affidabilita', sicurezza, persistenza o copertura.
- `missing`: manca almeno uno strato necessario oppure il consumer non puo'
  completare il flusso.
- `not_assessed`: la riga e' inventariata ma la verifica non e' ancora stata
  eseguita.

## Inventario GameRepository

| Membro | Firma sintetica | Contratto | Mock | Domain rilevante | Stato |
| --- | --- | --- | --- | --- | --- |
| `currentUserId` | `String get currentUserId` | `game_repository.dart:20` | `mock_game_repository.dart:135` | `String` | `missing` |
| `getCurrentTurn` | `Future<Turn>(municipalityId)` | `game_repository.dart:23` | `mock_game_repository.dart:776` | `turn.dart:5` | `partial` |
| `getMunicipalityActivationState` | `Future<MunicipalityActivationState>(municipalityId)` | `game_repository.dart:26` | `mock_game_repository.dart:786` | `municipality_catalog.dart:1` | `partial` |
| `getCivicLoopSummary` | `Future<CivicLoopSummary>(municipalityId)` | `game_repository.dart:31` | `mock_game_repository.dart:798` | `civic_loop_summary.dart:3` | `partial` |
| `listProblems` | `Future<List<Problem>>(municipalityId)` | `game_repository.dart:34` | `mock_game_repository.dart:814` | `problem.dart:6` | `partial` |
| `getMyPredictions` | `Future<Map<String, Prediction>>(turnId)` | `game_repository.dart:39` | `mock_game_repository.dart:819` | `prediction.dart:7` | `partial` |
| `upsertPrediction` | `Future<void>({turnId, problemId, choice, motivations, confidence})` | `game_repository.dart:42` | `mock_game_repository.dart:829` | `prediction_choice.dart:2`, `motivation_key.dart:5`, `hypothesis_confidence.dart:2` | `partial` |
| `updatePredictionMotivations` | `Future<void>({turnId, problemId, motivations})` | `game_repository.dart:51` | `mock_game_repository.dart:857` | `motivation_key.dart:5` | `missing` |
| `getReflectionQuestion` | `Future<ReflectionQuestion>(problemId)` | `game_repository.dart:58` | `mock_game_repository.dart:971` | `reflection_question.dart:4` | `missing` |
| `resolvePrediction` | `Future<PredictionResult>({problemId, choice})` | `game_repository.dart:61` | `mock_game_repository.dart:875` | `prediction_result.dart:5` | `partial` |
| `tapSignal` | `Future<void>({problemId, resolved})` | `game_repository.dart:67` | `mock_game_repository.dart:890` | `problem.dart:6`, `problem_status.dart` | `missing` |
| `getAggregatedInsight` | `Future<AggregatedInsight>(problemId)` | `game_repository.dart:70` | `mock_game_repository.dart:904` | `aggregated_insight.dart:6` | `missing` |
| `getProblemById` | `Future<Problem>(problemId)` | `game_repository.dart:73` | `mock_game_repository.dart:916` | `problem.dart:6` | `missing` |
| `getLeaderboard` | `Future<List<LeaderboardEntry>>({municipalityId, leagueId})` | `game_repository.dart:76` | `mock_game_repository.dart:923` | `leaderboard_entry.dart:4` | `partial` |
| `getPredictionResults` | `Future<Map<String, PredictionResult>>(turnId)` | `game_repository.dart:82` | `mock_game_repository.dart:950` | `prediction_result.dart:5` | `missing` |
| `getReputationScore` | `Future<ReputationScore>(turnId)` | `game_repository.dart:85` | `mock_game_repository.dart:957` | `reputation_score.dart:4` | `missing` |
| `getInsightHistory` | `Future<InsightHistory>(problemId)` | `game_repository.dart:88` | `mock_game_repository.dart:1005` | `insight_history.dart:5` | `missing` |
| `getReputationHistory` | `Future<List<ReputationScore>>({municipalityId})` | `game_repository.dart:91` | `mock_game_repository.dart:1017` | `reputation_score.dart:4` | `missing` |
| `getCriticalInsights` | `Future<List<CriticalInsight>>({problemId, userChoice, userConfidence, userReflectionIndex})` | `game_repository.dart:96` | `mock_game_repository.dart:983` | `critical_insight.dart:4` | `missing` |

I nomi file abbreviati nelle colonne `Contratto`, `Mock` e `Domain` sono
relativi rispettivamente a `lib/features/game/data/`,
`lib/features/game/data/` e alle directory domain o core indicate dal tipo.

### Valutazione UC-00.3

`AppDependencies` registra sempre `MockGameRepository` in
`lib/app/app_dependencies.dart:36`. Non esistono ancora `ApiGameRepository`,
mapper Game o test repository API; per questo nessun membro e' `complete` per
il pilot anche quando una route backend e' gia' disponibile.

| Membro | Stato | Base disponibile | Gap che impediscono `complete` | Destinazione iniziale |
| --- | --- | --- | --- | --- |
| `currentUserId` | `missing` | Getter mock e consumer home/leaderboard. | Nessuna identita' server; `userId` e' falsificabile e la leaderboard usa `demo-user`. | `UC-03`, `UC-06` |
| `getCurrentTurn` | `partial` | `GET .../turn`, schema `Turn` e handler. | Nessun adapter/mapper; lifecycle e caso no-turn non definiti; mock e backend divergono per Comuni nuovi/in raccolta. | `UC-05`, `UC-06` |
| `getMunicipalityActivationState` | `partial` | `GET .../activation`, enum e test alias/promozione. | `newMunicipality` non e' raggiungibile dal server corrente; Comune sconosciuto e' `404`; adapter assente. | `UC-05`, `UC-06` |
| `getCivicLoopSummary` | `partial` | `GET .../summary`, schema con tutti i campi e handler. | `cardsInTurn` ha semantica diversa dal mock; predictions usa `demo-user`; outcomes e reputazione sono sempre zero; mapper assente. | `UC-03`, `UC-05`, `UC-06` |
| `listProblems` | `partial` | `GET .../problems`, schema `Problem` e handler. | Adapter/mapper assenti; persistenza e appartenenza al turno non formalizzate; test shape/empty/error mancanti. | `UC-02`, `UC-05`, `UC-06` |
| `getMyPredictions` | `partial` | `GET .../predictions`, schema `Prediction` e filtro per utente. | Adapter/mapper assenti; lista HTTP da convertire in mappa; identita' client-controlled; store volatile; happy path non testato. | `UC-01`, `UC-02`, `UC-03`, `UC-06` |
| `upsertPrediction` | `partial` | `PUT .../predictions/{problemId}`, enum, lock e validazione. | Adapter assente; identita' e persistenza mancanti; test Flutter API/end-to-end assenti. | `UC-01`, `UC-02`, `UC-03`, `UC-06` |
| `updatePredictionMotivations` | `missing` | Il PUT esistente puo' aggiornare metadati solo reinviando `choice`. | La firma Flutter non passa `choice` o `confidence`; una traduzione via cache/lettura puo' perdere metadati e non esiste operazione merge dedicata. | `UC-05`, `UC-06` |
| `getReflectionQuestion` | `missing` | Dominio e generatore mock. | Nessuno schema/endpoint; ownership e versionamento domanda/risposta non decisi; il caricamento gioco la richiede. | `UC-05`, `UC-06` |
| `resolvePrediction` | `partial` | `POST .../resolve`, schema e happy-path backend. | Risposta backend booleana contro enum Flutter a quattro stati; nessun risultato persistito; comando client non legato a chiusura turno o ruolo. | `UC-02`, `UC-05`, `UC-06`, `UC-07` |
| `tapSignal` | `missing` | Mutazione solo mock, senza consumer attuale. | Un booleano client non puo' cambiare lo stato canonico nel pilot; va rimosso dallo scope utente o ridefinito come segnale/evento operatore. | `UC-05`, `UC-07` |
| `getAggregatedInsight` | `missing` | Dominio e aggregazione sintetica mock. | Nessuno schema/endpoint; manca scope di turno, persistenza, algoritmo e soglia privacy per piccoli gruppi. | `UC-05`, `UC-06`, `UC-08` |
| `getProblemById` | `missing` | Schema `Problem` e lookup interna server. | Nessuna route pubblica; `listProblems` richiede municipality mentre la firma riceve solo problemId. | `UC-05`, `UC-06` |
| `getLeaderboard` | `partial` | `GET .../leaderboard`, schema compatibile e handler. | Risposta statica, nessun test diretto, identita' demo e parametro Flutter `leagueId` ignorato. | `UC-03`, `UC-05`, `UC-06` |
| `getPredictionResults` | `missing` | Enum e storage solo mock. | Nessun endpoint, schema o ledger; `resolvePrediction` restituisce un esito effimero. | `UC-02`, `UC-05`, `UC-06` |
| `getReputationScore` | `missing` | Dominio e calcolo mock. | Nessun endpoint o ledger; formule mock e server divergono; summary restituisce sempre zero. | `UC-02`, `UC-05`, `UC-06` |
| `getInsightHistory` | `missing` | Dominio e snapshot sintetici mock. | Nessun endpoint/persistenza; scope, ordinamento e paginazione non definiti. | `UC-02`, `UC-05`, `UC-06` |
| `getReputationHistory` | `missing` | Lista sintetica mock consumata dal profilo. | `ReputationScore` non ha timestamp/turno/Comune; cache mock globale; nessun ledger o endpoint. | `UC-02`, `UC-03`, `UC-05`, `UC-06` |
| `getCriticalInsights` | `missing` | Dominio e composizione mock. | Nessun endpoint/schema; input non autorevoli, cache mock incompleta e nessuna versione/provenienza o soglia privacy. | `UC-05`, `UC-06`, `UC-08` |

### Backlog derivato da Game

1. `UC-01`: caratterizzare le route esistenti, in particolare predictions
   happy path/isolamento/schema, payload completi e leaderboard.
2. `UC-02`: persistere turni, problemi, predictions, risultati e ledger di
   reputazione con vincoli, transazioni e prova di riavvio.
3. `UC-03`: sostituire ogni `userId` arbitrario con l'identita' di sessione e
   fornire a Flutter un current user stabile.
4. `UC-05`: fissare lifecycle di Comune e turno, semantica no-turn, metriche del
   summary, `leagueId` e appartenenza dei problemi.
5. `UC-05`: introdurre risultati persistiti a quattro stati e formula di
   reputazione deterministica/versionata; la risoluzione deve essere legata a
   un turno chiuso e a un ruolo autorizzato.
6. `UC-05`: scegliere un contratto merge-safe per i metadati prediction e
   definire endpoint/schema per problema singolo, reflection, aggregati,
   storici e critical insights, oppure rimuoverli esplicitamente dallo scope
   v1.
7. `UC-05` e `UC-07`: rimuovere `tapSignal` dal contratto utente o trasformarlo
   in evento non autoritativo; gli esiti canonici sono comandi operatore
   auditati.
8. `UC-06`: implementare mapper e `ApiGameRepository`, switch runtime senza
   fallback, error mapping e test per tutti i membri mantenuti nello scope.
9. `UC-08`: applicare soglie anti-inferenza e minimizzazione dati agli insight.
10. `UC-09`: coprire end-to-end salvataggio, reload, chiusura turno, risultato,
    reputazione e isolamento tra due sessioni.

## Inventario NextProblemsRepository

| Metodo | Firma sintetica | Contratto | API | Mock | Consumer e mapper | Stato |
| --- | --- | --- | --- | --- | --- | --- |
| `listNextProblems` | `Future<List<SuggestedProblem>>({municipalityId, query, status})` | `next_problems_repository.dart:7` | `api_next_problems_repository.dart:20` | `mock_next_problems_repository.dart:17` | `next_problems_cubit.dart:32`, `suggested_problem_mapper.dart:11` | `partial` |
| `submitSuggestedProblem` | `Future<SuggestedProblem>({municipalityId, title, description, category})` | `next_problems_repository.dart:13` | `api_next_problems_repository.dart:37` | `mock_next_problems_repository.dart:30` | `next_problems_cubit.dart:115`, `suggested_problem_mapper.dart:24` | `partial` |
| `voteSuggestedProblem` | `Future<SuggestedProblem>({municipalityId, problemId, vote})` | `next_problems_repository.dart:20` | `api_next_problems_repository.dart:56` | `mock_next_problems_repository.dart:45` | `next_problems_cubit.dart:81`, `suggested_problem_mapper.dart:24` | `partial` |

I tre metodi API condividono `_collectionPath` in
`api_next_problems_repository.dart:74`; la selezione tra adapter mock e API e'
in `lib/app/app_dependencies.dart:69`. Il mock delega a
`lib/features/civic_loop/data/civic_loop_store.dart:22`, `:54` e `:93`.

### Valutazione UC-00.2

| Metodo | Evidenza positiva | Gap che impediscono `complete` | Destinazione iniziale |
| --- | --- | --- | --- |
| `listNextProblems` | Adapter, canonicalizzazione Comune, query/status, schema lista, mapper stretto e handler sono presenti. I test Dart verificano path e query; i test Node verificano `myVote`, stato invalido e Comune assente. | `userId` controllato dal client; store volatile; capability API limitata a due Comuni mentre il catalogo UI ne espone altri; nessun test backend positivo di query/status; limite query non gestito dal consumer; nessun end-to-end Dart-Node. | `UC-02`, `UC-03`, `UC-04` |
| `submitSuggestedProblem` | `POST`, request/response OpenAPI, validazione, mapper, codice `duplicate_title` e consumer sono presenti. | Store volatile; autore controllato dal body; controllo duplicati non transazionale e retry ambiguo; nessun test focalizzato sulla response `201` completa; limiti UI 60/140 diversi dai limiti API 120/1000. | `UC-01`, `UC-02`, `UC-03`, `UC-04` |
| `voteSuggestedProblem` | Path, request `up/down`, risposta aggiornata, conteggi per utente, mapper e happy path sono implementati. | La firma Flutter accetta anche `VoteChoice.none`, che l'adapter API rifiuta; la semantica toggle non idempotente non e' descritta in OpenAPI; retry dopo timeout puo' annullare un voto; mancano test per `down`, toggle, cambio scelta ed errori; la soglia demo promuove senza moderazione. | `UC-01`, `UC-03`, `UC-04`, `UC-07` |

### Backlog derivato da Next Problems

1. `UC-01`: aggiungere test di caratterizzazione per filtri positivi, response
   `201`, validazioni submit, transizioni di voto ed errori della route.
2. `UC-02`: persistere proposte e voti con vincolo di unicita' normalizzato per
   Comune, transazioni, concorrenza, rollback e prova di riavvio.
3. `UC-03`: derivare identita' e autore dalla sessione server-side ed eliminare
   `userId` arbitrario da query e body del pilot.
4. `UC-04`: decidere e contrattualizzare una semantica di voto retry-safe,
   allineare mock/API e il ruolo di `VoteChoice.none`, aggiungere idempotenza e
   un end-to-end reale Flutter-backend.
5. `UC-04`: rendere esplicite le capability per Comune, allineare i limiti di
   ricerca e submit e definire ordinamento/paginazione prima della crescita dei
   dati.
6. `UC-04` e `UC-07`: mantenere lo stato di moderazione esplicito e impedire
   l'autopromozione nel pilot; gli endpoint operatore arrivano in `UC-07`.

## Inventario operazioni HTTP

| Metodo | Path | `operationId` | OpenAPI | Matcher / handler | Test diretti o di flusso | Stato |
| --- | --- | --- | --- | --- | --- | --- |
| `GET` | `/health` | `getHealth` | `openapi.yaml:11` | `server.js:718` / `:95` | `server.test.js:9` | `partial` |
| `GET` | `/v1/municipalities/{municipalityId}/activation` | `getMunicipalityActivation` | `openapi.yaml:21` | `server.js:723` / `:99` | `server.test.js:27`, `:57` | `partial` |
| `GET` | `/v1/municipalities/{municipalityId}/summary` | `getCivicLoopSummary` | `openapi.yaml:35` | `server.js:724` / `:112` | `server.test.js:57` | `partial` |
| `GET` | `/v1/municipalities/{municipalityId}/turn` | `getCurrentTurn` | `openapi.yaml:49` | `server.js:725` / `:121` | `server.test.js:47` | `partial` |
| `GET` | `/v1/municipalities/{municipalityId}/problems` | `listProblems` | `openapi.yaml:63` | `server.js:726` / `:130` | `server.test.js:57` | `partial` |
| `GET` | `/v1/municipalities/{municipalityId}/leaderboard` | `getLeaderboard` | `openapi.yaml:83` | `server.js:727` / `:141` | Nessuna invocazione diretta | `partial` |
| `GET` | `/v1/municipalities/{municipalityId}/next-problems` | `listNextProblems` | `openapi.yaml:103` | `server.js:728` / `:152` | `server.test.js:108`, `:149`, `:215`, `:306` | `partial` |
| `POST` | `/v1/municipalities/{municipalityId}/next-problems` | `submitSuggestedProblem` | `openapi.yaml:141` | `server.js:729` / `:181` | `server.test.js:57`, `:190`, `:215`, `:306` | `partial` |
| `POST` | `/v1/municipalities/{municipalityId}/next-problems/{problemId}/votes` | `voteSuggestedProblem` | `openapi.yaml:170` | `server.js:730` / `:202` | `server.test.js:57`, `:108` | `partial` |
| `GET` | `/v1/turns/{turnId}/predictions` | `listPredictions` | `openapi.yaml:199` | `server.js:735` / `:218` | `server.test.js:254` | `partial` |
| `PUT` | `/v1/turns/{turnId}/predictions/{problemId}` | `upsertPrediction` | `openapi.yaml:225` | `server.js:736` / `:237` | `server.test.js:215`, `:254`, `:275` | `partial` |
| `POST` | `/v1/problems/{problemId}/resolve` | `resolvePrediction` | `openapi.yaml:252` | `server.js:737` / `:260` | `server.test.js:343` | `partial` |

`GET /health` e' sufficiente come liveness dello scaffold ed e' testato, ma
non verifica dipendenze, migrazioni o readiness; la separazione health/readiness
e' destinata a `UC-09`.

## Inventario test Flutter per Next Problems

| File | Copertura rilevante |
| --- | --- |
| `test/features/next_problems/data/api_next_problems_repository_test.dart` | Serializzazione list/submit/vote, canonicalizzazione, `userId`, Comune non supportato e rifiuto di `VoteChoice.none` |
| `test/features/next_problems/data/suggested_problem_mapper_test.dart` | Payload nominale, lista immutabile, campi mancanti, enum, timestamp e numeri invalidi |
| `test/features/next_problems/logic/next_problems_cubit_test.dart` | Filtri, risposte stale, errore voto e feedback `duplicate_title` |
| `test/features/next_problems/presentation/next_problems_page_test.dart` | Errore umano e retry UI |
| `test/municipality_activation_repository_test.dart` | Flusso mock lista, submit, voto e promozione |
| `test/app/app_dependencies_test.dart` | Opt-in esplicito all'adapter API e requisiti di configurazione |

## Inventario test Flutter per Game

`test/municipality_activation_repository_test.dart` esercita direttamente il
mock per stato Comune, turno, problemi, predictions, leaderboard, summary,
promozione e lock della choice. Non esistono test di `ApiGameRepository`,
mapper Game o integrazione Flutter-backend perche' l'adapter non esiste ancora.

## Inventario test backend

| Caso | Riferimento | Superficie esercitata |
| --- | --- | --- |
| Avvio server e health | `server.test.js:9` | `/health`, risposta JSON |
| Slug canonici e alias Flutter | `server.test.js:27` | activation e normalizzazione Comune |
| Campi del turno compatibili con Flutter | `server.test.js:47` | current turn |
| Promozione proposta e attivazione Comune | `server.test.js:57` | submit, vote, activation, problems, summary |
| `myVote` separato per identificativo client | `server.test.js:108` | submit, vote, list Next Problems |
| CORS loopback, configurato e rifiutato | `server.test.js:149` | preflight e policy trasversale |
| Limite body e JSON non oggetto | `server.test.js:190` | parsing body su submit |
| Validazione titolo, stato e motivazioni | `server.test.js:215` | submit, list Next Problems, upsert prediction |
| Esistenza turno/problema e coerenza | `server.test.js:254` | list e upsert prediction |
| Choice bloccata e metadati aggiornabili | `server.test.js:275` | upsert prediction |
| Errori JSON stabili, duplicati e dati mancanti | `server.test.js:306` | submit e list Next Problems |
| Risoluzione previsione | `server.test.js:343` | resolve prediction |

## Handoff UC-00.1

### Risultato

- Inventariati tutti i 19 membri pubblici di `GameRepository`.
- Inventariati tutti i 3 metodi di `NextProblemsRepository`, i due adapter, i
  consumer principali e il mapper API.
- Inventariate tutte le 12 operazioni OpenAPI, le 12 route del matcher e i 12
  casi di test backend.
- Verificata la corrispondenza numerica e nominale tra OpenAPI e matcher HTTP.

### Decisioni

Nessuna decisione architetturale e nessuna classificazione contrattuale sono
state prese. La mancanza di un'invocazione diretta della leaderboard nei test
e' registrata come evidenza di inventario, non ancora come gap classificato.

### Verifiche

- `git diff --check`: superato.
- Controllo whitespace sui nuovi documenti: superato.
- Conteggio righe `not_assessed`: 34, coerente con 19 membri Game, 3 metodi
  Next Problems e 12 operazioni HTTP.
- Test backend con Node.js 24.14.0: 12 su 12 superati. Il comando `npm test`
  eredita Node.js 10.16.3 dalla shell locale e non supporta `node --test`; il
  runtime Node 24 fornito dal workspace e' stato usato direttamente. Il test
  health richiede una socket loopback ed e' stato rieseguito fuori dal sandbox.

### Prossimo incarico

Avviare `UC-00.2`: confrontare esclusivamente i tre metodi di
`NextProblemsRepository` con API adapter, mapper, OpenAPI, server e test;
assegnare `complete`, `partial` o `missing` con evidenza e backlog iniziale.

## Handoff UC-00.2

### Risultato

- Classificati `listNextProblems`, `submitSuggestedProblem` e
  `voteSuggestedProblem` come `partial` rispetto ai requisiti del pilot.
- Registrate evidenze per contratto Flutter, adapter, mapper, OpenAPI, server,
  consumer e test.
- Derivato il backlog iniziale per `UC-01`, `UC-02`, `UC-03`, `UC-04` e
  `UC-07`.

### Decisioni

La classificazione `partial` distingue una catena nominale gia' funzionante
dalle garanzie mancanti per il pilot. Non e' ancora stata scelta la nuova
semantica del voto: restano da decidere idempotenza, rimozione esplicita e ruolo
di `VoteChoice.none`. La scelta e' un prerequisito di implementazione per
`UC-04`, non una modifica autorizzata da `UC-00.2`.

### Verifiche

- Tre metodi Next Problems e tre operazioni HTTP associate risultano
  classificati `partial`.
- La tabella HTTP contiene ancora tutte le 12 operazioni inventariate.
- Tutti i sei file di test Flutter referenziati esistono.
- `git diff --check` e controllo whitespace: superati.
- Baseline backend invariata: 12 test su 12 passano con Node.js 24.14.0.
- Test Flutter non rieseguiti: la sessione modifica solo documentazione e il
  comando `flutter` non e' disponibile nella shell corrente.

### Prossimo incarico

Avviare `UC-00.3`: classificare i 19 membri di `GameRepository` confrontando
mock, domain, OpenAPI, server e test, senza implementare gli endpoint mancanti.

## Handoff UC-00.3

### Risultato

- Classificati tutti i 19 membri Game: 8 `partial` e 11 `missing`.
- Classificate tutte le 12 operazioni HTTP come `partial` rispetto al pilot;
  nessuna riga resta `not_assessed`.
- Registrati gap di lifecycle, identita', mapper/adapter, results ledger,
  reputazione, insight e autorizzazione degli esiti.
- Derivato il backlog iniziale per `UC-01`, `UC-02`, `UC-03`, `UC-05`,
  `UC-06`, `UC-07`, `UC-08` e `UC-09`.

### Decisioni

`tapSignal` non puo' diventare un comando utente che muta lo stato canonico:
va rimosso dallo scope v1 o ridefinito come segnale non autoritativo; la
registrazione degli esiti appartiene al flusso operatore. Restano inoltre da
decidere lifecycle no-turn, semantica `leagueId`, ownership delle reflection e
shape versionata di risultati, reputazione e insight.

### Verifiche

- Conteggio Game: 8 `partial`, 11 `missing`, totale 19.
- Conteggio HTTP: 12 route, tutte classificate `partial`.
- Nessuna riga inventariata resta `not_assessed`.
- `git diff --check` e controllo whitespace: superati.
- Baseline backend invariata: 12 test su 12 passano con Node.js 24.14.0.
- Test Flutter non rieseguiti per il diff solo documentale e l'assenza del
  comando `flutter` nella shell corrente.

### Prossimo incarico

Avviare `UC-00.4`: proporre l'ADR per accesso PostgreSQL e migrazioni,
confrontando alternative, reversibilita' e strategia di test senza installare
dipendenze o creare database.

## Handoff UC-00.4

### Risultato

- Creato `docs/backend/adr/0001-postgresql-access-and-migrations.md` in stato
  `proposed`.
- Proposti `pg` 8.x con release esatta senza range e `node-pg-migrate` 8.0.4
  fissato, con accesso dietro porte, transazioni esplicite e adapter memory.
- Definiti migrazioni append-only, manifest SHA-256, ledger dei checksum
  applicati nel database, job separato, expand/backfill/contract e quality gate
  PostgreSQL reale.
- Aggiunti budget connessioni massimo al 70% del limite verificato, timeout
  numerici e divieto di contract distruttivo prima di un restore drill riuscito.
- Confrontati Prisma, Drizzle, Postgres.js e runner SQL custom.

### Decisioni

La decisione accettata non installa dipendenze e non crea database. Il proprietario ha
approvato il 14 luglio 2026 pin/version policy, ledger fail-closed, privilegi
separati, valori misurabili di pool/timeout e rollback forward-only subordinato
al restore drill.

### Verifiche

- Fonti ufficiali e sorgenti della release stabile 8.0.4 verificate.
- Sezioni ADR, file e riferimenti locali: presenti.
- `git diff --check` e controllo whitespace: superati.
- Nessun test applicativo richiesto per il diff documentale.

### Prossimo incarico

Avviare `UC-00.5`: proporre l'ADR per identita' e sessioni anonime, includendo
ruoli, autorizzazioni, revoca, scadenza, cancellazione e transizioni di stato.

## Handoff UC-00.5

### Risultato

- Creato
  `docs/backend/adr/0002-anonymous-identity-sessions-and-authorization.md`
  in stato `proposed`.
- Proposti principal anonimi server-side, access/refresh token opachi e
  revocabili, set di otto recovery code indipendenti e monouso e trasporti
  distinti web/native.
- Definiti cookie web persistenti, slot di credenziale per route, refresh replay
  fail-closed e rotazione recovery `prepare/confirm`, preservando i codici
  residui se una risposta recover viene persa.
- Definiti warning e rinnovo esplicito prima delle scadenze 90/180 giorni e la
  promessa UX limitata a un codice valido, non consumato e non scaduto.
- Chiariti non-consumo dei codici in `prepare`/`confirm`, bootstrap recovery di
  15 minuti e impossibilita' di ricreare un set scaduto con la sola sessione.
- Reso coordinato il cutover degli input `userId` tra OpenAPI, backend, Flutter
  e test, con artefatto combinato o rollout compatibile in tre fasi; i test
  refresh/CSRF richiedono un browser reale e una origin ostile.
- Definite matrice `anonymous`/`moderator`/`admin`, autorizzazione
  deny-by-default, lifecycle di identita', sessioni, moderazione e turni.
- Definiti bootstrap operatori provider-neutral, cancellazione idempotente con
  journal esterno source of truth e reconciler fail-toward-deletion, audit,
  error code e quality gate per `UC-03`, `UC-07` e `UC-08`.
- Definiti bootstrap one-shot del primo e secondo admin, chiusura irreversibile
  dopo due attivazioni e workflow dual-control, senza rallentare la revoca
  globale emergenziale.
- Definiti `operator_quorum_lost` e recovery offline a doppia custodia se gli
  admin attivi scendono sotto due dopo la chiusura del bootstrap.
- Chiuso il pilot finche' autenticatore AAL2, dual-control, due admin distinti e
  verifica privacy/legale non sono dimostrati; il prototipo remoto segue i
  confini access-controlled/read-only di ADR-0003.

### Decisioni

Il riavvio usa il refresh token; dopo un logout reale il recupero richiede un
recovery code valido, non consumato e non scaduto, mostrato una volta. Una
risposta recover persa consuma un solo codice e non invalida gli altri; la
rigenerazione sostituisce il set soltanto dopo conferma. Il proprietario ha
approvato il 14 luglio 2026 questo confine di recupero, durate, replay policy,
cookie/CSRF, set e rotazione recovery, matrice ruoli, dual-control admin, AAL2
operatori, deletion journal e gate di cancellazione/anonimizzazione/retention.

### Verifiche

- Sezioni ADR, tabelle di ruolo/stato, condizioni di accettazione e riferimenti:
  presenti.
- `git diff --check` e controllo whitespace sul nuovo documento: superati.
- Nessuna dipendenza, risorsa, credenziale o modifica applicativa introdotta.
- Nessun test applicativo richiesto per il diff documentale.

### Prossimo incarico

Avviare `UC-00.6`: definire l'ambiente locale e i confini di un eventuale
prototipo remoto gratuito, lasciando provider e hosting persistente del pilot a
una decisione proprietaria successiva e senza creare risorse esterne.

## Handoff UC-00.6

### Risultato

- Creato `docs/backend/adr/0003-local-and-zero-cost-remote-prototype.md` in
  stato `proposed`, sostituendo la bozza hosting a pagamento non approvata.
- Confermato l'ambiente locale come baseline autorevole per `UC-01`--`UC-08`.
- Definito un `remote-prototype` opzionale, provider-neutral e ammissibile solo
  con costo ricorrente zero, hard stop sugli addebiti e PoC approvato.
- Limitato qualunque remoto a dati applicativi sintetici e sacrificabili:
  pubblico in sola lettura oppure fixture-only dietro accesso ristretto, con
  metadati di connessione minimizzati.
- Conservati packaging riproducibile, configurazione standard, stessa origin,
  migrazioni separate, health/readiness, smoke e teardown.
- Rinviati provider, regioni, budget, HA, RPO/RTO, backup, deletion journal e
  osservabilita' del pilot a un nuovo ADR obbligatorio prima di `UC-09`.

### Decisioni

La decisione accettata non seleziona un provider e non introduce dipendenze, account,
registry, database, dominio, secret, metodo di pagamento o risorsa esterna.
L'accettazione del 14 luglio 2026 consolida:

- locale come baseline sufficiente e indipendente dal cloud;
- remoto gratuito come opzione e non come dipendenza del piano;
- costo ricorrente zero, nessun trial a conversione automatica e nessun
  rischio di addebito senza una nuova approvazione;
- dati applicativi esclusivamente sintetici e sacrificabili, remoto pubblico
  in sola lettura oppure fixture-only con accesso ristretto;
- metadati di connessione reali minimizzati e coperti dalla verifica
  DPA/retention;
- accettazione di sleep, reset e perdita totale senza SLA, HA, RPO, RTO,
  backup o retention garantiti;
- packaging provider-neutral, same-origin e migrazioni separate;
- PoC e creazione di ogni risorsa subordinati all'approvazione del candidato
  esatto;
- evidenza costo zero riconfermata prima di ogni deploy e teardown entro 30
  giorni senza nuova verifica/approvazione;
- divieto di promuovere il prototipo a staging o pilot;
- nuovo ADR hosting persistente accettato prima di `UC-09`.

ADR-0001, ADR-0002 e ADR-0003 sono `accepted`. Il decision register conserva
scelte rinviate e confine dell'autorizzazione.

### Verifiche

- Rimossa la bozza a pagamento prima dell'accettazione; nessun provider, prezzo
  o regione viene presentato come gia' scelto.
- Sezioni ADR, file, path e riferimenti locali: presenti.
- `git diff --check` e controllo whitespace: superati sul diff documentale.
- Baseline backend: 12 test su 12 passano con Node.js 24.14.0; la prima
  invocazione col Node predefinito era incompatibile con `node --test` e il test
  server ha richiesto il permesso loopback della sandbox.
- Flutter non e' disponibile nella shell corrente e non e' stato rieseguito;
  nessun test applicativo aggiuntivo e' richiesto dal diff solo documentale.
- Nessun account, secret, dipendenza o risorsa cloud creati.

## Handoff UC-00.7

### Risultato

- ADR-0001, ADR-0002 e ADR-0003 consolidati in stato `accepted` il 14 luglio
  2026.
- Creato `docs/backend/backend_decision_register.md` con scelte accettate,
  decisioni rinviate, criteri di riapertura e confine dell'autorizzazione.
- Confermate destinazioni `UC-01`--`UC-10` per ogni gap inventariato; nessuna
  riga resta `not_assessed` o senza work package.
- Sincronizzati piano, matrice, README e path del nuovo ADR-0003.

### Decisioni

- La direzione architetturale e' vincolante per la futura esecuzione.
- L'esecuzione resta `not_started`: nessuna micro-sessione di `UC-01` e' stata
  aperta.
- Nessun provider gratuito e' stato scelto; PoC e risorsa richiedono una nuova
  approvazione specifica.
- Il futuro ADR hosting persistente resta gate separato tra `UC-08` e `UC-09`.

### Verifiche

- ADR e registro decisionale: sezioni, stati e riferimenti locali presenti.
- Nessuna occorrenza del vecchio pathname o della bozza hosting a pagamento.
- `git diff --check`, controllo whitespace e verifica dei nuovi file: verdi.
- Baseline backend gia' verificata: 12 test su 12 con Node.js 24.14.0; nessun
  nuovo test applicativo richiesto dal diff solo documentale.
- Nessuna dipendenza, risorsa esterna, credenziale, dato reale o spesa
  introdotta.

### Prossimo incarico

Attendere il comando esplicito del proprietario. Quando arrivera', aprire
`UC-01` dalla prima micro-sessione di caratterizzazione/modularizzazione; non
saltare direttamente a database, autenticazione o hosting.
