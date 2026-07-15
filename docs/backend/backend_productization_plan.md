# Backend productization plan

## Stato e scopo

Piano operativo registrato il 12 luglio 2026 per guidare l'esecuzione con
Ultracode oltre lo scaffold locale descritto in
`docs/backend/backend_foundation_plan.md`.

Le decisioni di `UC-00` sono state consolidate il 14 luglio 2026 nel
[registro decisioni backend](backend_decision_register.md). `UC-00` e `UC-01`
sono chiusi; `UC-02`--`UC-10` non sono ancora avviati e richiedono un nuovo
comando del proprietario.

L'obiettivo non e' rendere pubblico lo scaffold in-memory esistente, ma
costruire un pilot limitato e realmente utilizzabile da uno o due Comuni:
dati persistenti, identita' anonime emesse dal server, gioco completo via API,
moderazione, gestione operativa, privacy, staging e osservabilita'. Il prodotto
continua a non essere un canale ufficiale di segnalazione comunale.

## Definizione di prodotto funzionante

La milestone `backend-pilot-v1` e' completata soltanto quando un utente puo':

1. aprire l'app e ricevere un'identita' anonima dal server;
2. selezionare un Comune supportato;
3. proporre e votare un tema persistente;
4. vedere una proposta approvata da un moderatore entrare in un turno;
5. inviare una previsione e ritrovarla dopo riavvio o nuovo deploy e, dopo un
   logout reale, tramite un recovery code valido, non consumato e non scaduto;
6. ricevere un esito con reputazione, insight e classifica aggiornati;
7. cancellare la propria identita' e i dati associati secondo la policy;
8. ricevere errori comprensibili mentre gli operatori possono osservare e
   diagnosticare il servizio.

La milestone richiede inoltre backup ripristinabili, audit delle azioni
amministrative, protezioni anti-abuso e test end-to-end Flutter-backend.

## Confini iniziali

- Pilot con uno o due Comuni, non apertura nazionale.
- Identita' anonima; account nominativo e login social restano fuori scope.
- Nessuna posizione precisa, documento o altro dato personale non necessario.
- Le proposte richiedono moderazione prima della pubblicazione o promozione.
- Un operatore autorizzato apre e chiude i turni e registra gli esiti.
- La modalita' mock resta disponibile per test e demo, ma non puo' essere un
  fallback silenzioso dell'ambiente pilot.
- `/v1` e gli enum correnti restano compatibili; i cambi breaking richiedono
  una nuova versione o una migrazione coordinata dei consumer Flutter.

## Direzione architetturale

Il percorso conserva Node.js 24 e OpenAPI come contratto eseguibile. Prima di
aggiungere persistenza o autenticazione, `services/backend/src/server.js` viene
separato in responsabilita' verificabili:

```text
services/backend/src/
  domain/          # entita', invarianti e transizioni di stato
  application/     # casi d'uso
  http/            # routing, parsing e response mapping
  infrastructure/  # adapter memory e integrazioni sostituibili
  persistence/     # future porte e adapter database
  auth/            # sessioni e autorizzazione
  moderation/      # policy e workflow operatore
  observability/   # log, metriche e correlation id
```

Il database target e' PostgreSQL. Libreria di accesso, sistema di migrazioni e
formato del token devono essere fissati in ADR prima dell'introduzione. ADR-0003
fissa invece i confini del prototipo locale e dell'eventuale remoto gratuito,
senza scegliere un provider. La piattaforma persistente di staging/pilot deve
essere fissata in un nuovo ADR accettato prima di `UC-09`, confrontando costi,
portabilita', testabilita' e supporto operativo. Lo store in-memory resta un
adapter per test veloci.

## Modello dati minimo

- `municipalities`
- `anonymous_principals`
- `operator_identities`
- `role_assignments`
- `session_families`
- `session_tokens`
- `recovery_sets`
- `recovery_credentials`
- `turns`
- `problems`
- `suggestions`
- `suggestion_votes`
- `predictions`
- `prediction_results`
- `problem_events`
- `reputation_events`
- `moderation_actions`
- `consents`

Il deletion journal e la relativa chiave HMAC restano esterni al restore
PostgreSQL e non appartengono allo schema applicativo ordinario.

Vincoli, idempotenza e transazioni devono impedire almeno doppio voto, doppia
risoluzione, riferimenti tra Comuni diversi e aggiornamenti concorrenti che
perdono dati.

## Work package Ultracode

### UC-00 - Baseline, gap matrix e ADR

**Dipendenze:** nessuna.

- Inventariare ogni metodo di `GameRepository` e `NextProblemsRepository`.
- Mappare endpoint, schema OpenAPI, implementazione, test e consumer esistenti.
- Classificare ogni metodo come `complete`, `partial` o `missing`.
- Registrare ADR per database access, migrazioni, sessioni e confini del
  prototipo locale/remoto; rinviare la scelta hosting pilot al gate pre-UC-09.
- Definire ruoli `anonymous`, `moderator`, `admin` e transizioni di stato.

**Uscita:** matrice contrattuale approvata, ADR senza decisioni implicite e
backlog aggiornato. Nessun deploy e nessuna dipendenza di produzione in questa
fase.

### UC-01 - Modularizzazione senza cambio di comportamento

**Dipendenze:** UC-00.

- Estrarre dominio, casi d'uso, HTTP e `MemoryStore` dal file unico.
- Introdurre configurazione ambiente validata all'avvio.
- Conservare response, error code, `/v1` ed enum esistenti.
- Mantenere tutti i test di contratto verdi e aggiungere test di regressione
  prima di spostare comportamento complesso.

**Uscita:** diff principalmente strutturale, OpenAPI invariata e 12 test
backend esistenti ancora passanti.

### UC-02 - PostgreSQL, migrazioni e repository

**Dipendenze:** UC-01 e ADR dati approvata.

- Introdurre schema iniziale, migrazioni forward e seed separati.
- Implementare adapter PostgreSQL dietro le stesse porte dello store memory.
- Coprire vincoli, transazioni, concorrenza e rollback nei test.
- Documentare setup locale, reset sicuro, backup e restore.

**Uscita:** riavviare il backend non perde dati; una migrazione parte da
database vuoto e un restore e' verificato automaticamente.

### UC-03 - Identita' anonima server-side

**Dipendenze:** UC-02 e ADR sessioni approvata.

- Creare e ruotare sessioni anonime.
- Derivare l'utente dal token, mai da `userId` arbitrario nel client.
- Aggiungere revoca, scadenza e cancellazione dell'identita'.
- Migrare voti e previsioni preservando una finestra compatibile solo in locale.

**Uscita:** due sessioni vedono correttamente il proprio stato e non possono
leggere o modificare quello dell'altra.

### UC-04 - Proposte e voti persistenti

**Dipendenze:** UC-02 e UC-03.

- Portare `ApiNextProblemsRepository` sul nuovo modello di sessione.
- Persistenza transazionale di proposte e voti.
- Stato di moderazione esplicito e nessuna autopromozione in produzione.
- Idempotenza e protezione da duplicati.

**Uscita:** il primo vertical slice Flutter-backend e' persistente, isolato per
utente e coperto da test repository ed end-to-end.

### UC-05 - Contratto completo del gioco

**Dipendenze:** UC-02 e matrice UC-00.

- Completare risultati, reputazione, insight, storico, segnali e riflessioni.
- Definire calcolo deterministico e ledger degli eventi di reputazione.
- Aggiornare insieme OpenAPI, server e test per ogni endpoint.
- Rendere espliciti i flussi di apertura, chiusura e risoluzione del turno.

**Uscita:** ogni metodo di `GameRepository` e' `complete` nella matrice oppure
e' rimosso esplicitamente dallo scope v1 con decisione documentata.

### UC-06 - ApiGameRepository e switch runtime

**Dipendenze:** UC-03 e UC-05.

- Implementare mapper e repository HTTP senza trasporto nei widget o Cubit.
- Collegare prima letture, poi scritture, risultati, insight e classifica.
- Mantenere mock e API dietro configurazione esplicita.
- Vietare fallback silenzioso ai mock in modalita' API e negli ambienti futuri
  di staging/pilot.

**Uscita:** l'intero percorso di gioco Flutter usa il backend nella baseline
locale API e i test coprono enum sconosciuti, campi mancanti, timeout ed errori
strutturati. La ripetizione in staging appartiene a `UC-09`.

### UC-07 - Moderazione e operazioni amministrative

**Dipendenze:** UC-03, UC-04 e UC-05.

- Endpoint protetti per approvare/rifiutare proposte, gestire problemi e turni.
- Audit append-only delle azioni e motivazione obbligatoria per rimozioni.
- Pannello minimo o interfaccia operativa equivalente per il pilot.
- Separazione netta tra autorizzazione utente, moderatore e amministratore.

**Uscita:** il ciclo proposta -> moderazione -> turno -> esito puo' essere
gestito senza modificare database o fixture a mano.

### UC-08 - Privacy, sicurezza e anti-abuso

**Dipendenze:** UC-03 e UC-07.

- Rate limit per sessione e IP, quote e protezione spam/duplicati.
- Moderazione automatica preliminare senza sostituire la decisione umana.
- CORS per origin esplicite, headers di sicurezza e secret management.
- Export/cancellazione, retention, consensi e privacy policy coerenti.
- Threat model e test degli abusi principali.

**Uscita:** checklist sicurezza e privacy chiusa per il pilot; nessun testo
utente viene pubblicato senza la policy prevista.

### UC-09 - Staging, CI e osservabilita'

**Dipendenze:** UC-02, UC-06 e UC-08; nuovo ADR hosting persistente di
staging/pilot accettato dal proprietario. ADR-0003 non soddisfa questo gate.

- Ambiente staging riproducibile con migrazioni automatiche controllate.
- Log JSON, correlation id, error tracking, metriche e alert minimi.
- Health, readiness, smoke post-deploy e rollback documentato.
- Pipeline per unit, database, contratto, Flutter ed end-to-end.
- Backup pianificato e restore periodicamente verificato.

**Uscita:** un deploy fallito non rende il servizio irrecuperabile e un errore
utente puo' essere ricostruito senza registrare contenuti sensibili nei log.

### UC-10 - Pilot controllato

**Dipendenze:** UC-07, UC-08 e UC-09.

- Abilitare un Comune e un gruppo limitato di utenti.
- Definire metriche di salute, qualita' contenuti e abbandono.
- Eseguire test di carico proporzionati e una prova operativa completa.
- Stabilire criteri di stop, rollback e apertura del secondo Comune.

**Uscita:** almeno un ciclo civico completo avviene in produzione controllata,
con dati recuperabili, moderazione e incident response attivi.

## Ordine delle PR

1. `backend/contract-gap-matrix-and-adrs`
2. `backend/modular-server`
3. `backend/postgres-migrations`
4. `backend/anonymous-sessions`
5. `backend/persistent-next-problems`
6. `backend/complete-game-contract`
7. `flutter/api-game-repository`
8. `backend/moderation-operations`
9. `backend/privacy-abuse-controls`
10. `ops/staging-pilot-hosting-adr`
11. `ops/staging-observability-e2e`
12. `release/pilot-v1`

Ogni PR deve essere verticale o strutturale, piccola abbastanza da essere
revisionata e reversibile senza includere refactor non correlati.

## Esecuzione in micro-sessioni

Una PR resta l'unita' di review e un work package resta l'unita' di uscita, ma
nessuno dei due deve essere completato in una sola sessione Ultracode. Ogni
work package viene quindi diviso in micro-sessioni autonome, normalmente da
circa 8--15k token, con un solo risultato principale verificabile.

- Non avviare una nuova micro-sessione quando e' gia' stato consumato circa il
  70% del budget disponibile; riservare il resto a verifica e handoff.
- Dichiarare all'inizio unita', obiettivo, file ammessi, output, non-obiettivi e
  gate applicabile.
- Non affidare alla memoria della chat lo stato del lavoro: aggiornare la
  matrice, l'ADR, il backlog o la descrizione della PR prima di terminare.
- Tenere al massimo una micro-sessione `in_progress`; un blocco non autorizza
  ad aprire in parallelo un work package dipendente.
- Non unire due famiglie decisionali, per esempio sessioni e hosting, soltanto
  perche' resta budget disponibile.

L'handoff di ogni micro-sessione deve registrare:

1. risultato ottenuto e criterio di accettazione soddisfatto;
2. file e contratti modificati;
3. decisioni prese e decisioni ancora aperte;
4. comandi eseguiti con relativo esito;
5. rischi, test mancanti e diff intenzionalmente lasciato aperto;
6. prossimo incarico esatto, eseguibile senza ricostruire la chat precedente.

Si puo' continuare con l'unita' successiva soltanto quando il diff e'
circoscritto, il gate pertinente e' verde e non restano decisioni del
proprietario aperte. Ci si ferma invece davanti a un cambio breaking, una
baseline rossa non spiegata, una migrazione non reversibile, credenziali o
risorse esterne, costi ricorrenti, trattamento aggiuntivo di dati personali o
budget residuo insufficiente per verifica e handoff.

### Mappa indicativa delle micro-sessioni

La suddivisione viene rivalutata alla chiusura di ogni work package. Se una
micro-sessione supera il proprio risultato principale, va spezzata senza
spostare il criterio di uscita del work package.

| Work package | Micro-sessioni previste |
| --- | --- |
| `UC-00` | inventario e scheletro matrice; mappatura Next Problems; mappatura Game; ADR dati e migrazioni; ADR sessioni, ruoli e stati; ADR locale/prototipo gratuito; backlog e review finale |
| `UC-01` | test di caratterizzazione; estrazione dominio e `MemoryStore`; estrazione application/HTTP; configurazione e gate completo |
| `UC-02` | schema e migrazione; letture PostgreSQL; scritture e transazioni; concorrenza e rollback; backup/restore e gate |
| `UC-03` | contratto sessioni; emissione e rotazione; middleware e isolamento; revoca, scadenza e cancellazione |
| `UC-04` | proposte e moderazione; voti e idempotenza; repository Flutter ed end-to-end |
| `UC-05` | turni e problemi; previsioni e risultati; reputazione e classifica; insight e storico; chiusura matrice |
| `UC-06` | mapper e configurazione; letture; scritture e risultati; errori, fallback ed end-to-end |
| `UC-07` | ruoli e audit; moderazione proposte; gestione turni ed esiti; interfaccia operativa |
| `UC-08` | threat model; rate limit e anti-spam; CORS e secret; retention, export e cancellazione; test di abuso |
| `UC-09` | staging; log, metriche e alert; deploy e rollback; CI ed end-to-end; backup/restore e smoke test |
| `UC-10` | runbook e soglie; carico e prova operativa; primo Comune; ciclo completo e decisione sul secondo Comune |

Tra `UC-08` e `UC-09` esiste un gate proprietario separato: la PR
`ops/staging-pilot-hosting-adr` deve scegliere l'hosting persistente ed essere
`accepted` prima di aprire qualsiasi micro-sessione di `UC-09`. Non e' lavoro
interno a `UC-09` e ADR-0003 non lo soddisfa.

### Sequenza eseguibile di UC-00

| Unita' | Risultato principale | Gate di uscita | Stato |
| --- | --- | --- | --- |
| `UC-00.1` | Inventario dei metodi di `GameRepository` e `NextProblemsRepository`, delle route e dei test; creazione dello scheletro di `docs/backend/api_contract_gap_matrix.md` | Ogni metodo e route ha una riga e un riferimento sorgente, senza ancora forzare una classificazione | `complete` |
| `UC-00.2` | Mappatura completa di `NextProblemsRepository`, `ApiNextProblemsRepository`, OpenAPI, server e test | I tre metodi sono classificati `complete`, `partial` o `missing` con evidenze | `complete` |
| `UC-00.3` | Mappatura completa di `GameRepository`, mock, OpenAPI, server e test | Ogni metodo e' classificato con gap di schema, comportamento e test espliciti | `complete` |
| `UC-00.4` | ADR proposto per accesso PostgreSQL e migrazioni | Alternative, trade-off, reversibilita' e raccomandazione sono espliciti; nessuna dipendenza e' installata | `complete` |
| `UC-00.5` | ADR proposto per identita' e sessioni, con ruoli e transizioni di stato | Confini di `anonymous`, `moderator` e `admin`, revoca, scadenza e isolamento sono verificabili | `complete` |
| `UC-00.6` | ADR proposto per runtime locale e prototipo remoto opzionale gratuito | Locale autorevole, hard gate costo zero, soli dati sintetici, provider aperto e nuovo ADR pilot pre-UC-09 sono espliciti; nessuna risorsa e' creata | `complete` |
| `UC-00.7` | Backlog UC-01--UC-10 derivato dalla matrice e review documentale finale | ADR-0001, ADR-0002 e ADR-0003 accettati dal proprietario, nessun gap senza destinazione, link validi e `git diff --check` verde | `complete` |

La colonna `Stato` usa soltanto `pending`, `in_progress`, `blocked` e
`complete` e viene aggiornata all'apertura e alla chiusura di ogni unita'.
Il completamento di `UC-00.7` ha chiuso il work package `UC-00` il 14 luglio
2026.

### Sequenza eseguita di UC-01

| Unita' | Risultato principale | Gate di uscita | Stato |
| --- | --- | --- | --- |
| `UC-01.1` | Test di caratterizzazione per filtri, ciclo voto/promozione e isolamento previsioni | I 12 test preesistenti e i 3 nuovi test di regressione sono verdi prima dell'estrazione | `complete` |
| `UC-01.2` | Estrazione di dominio e `MemoryStore` dal file unico | Store isolato in `infrastructure/`, factory e invarianti in `domain/`, nessun cambio di response o error code | `complete` |
| `UC-01.3` | Estrazione di application service e livello HTTP | Routing, parsing, validazione, CORS e casi d'uso separati; gli export pubblici di `server.js` restano compatibili | `complete` |
| `UC-01.4` | Configurazione ambiente validata e gate completo | OpenAPI invariata, 19 test backend verdi, gate Flutter completo e nessuna nuova dipendenza | `complete` |

`UC-01` e' stato chiuso il 14 luglio 2026. Il file `src/server.js` e' ora un
composition root; il contratto `/v1`, gli enum e gli error code sono rimasti
invariati. `UC-02` resta fuori dall'autorizzazione corrente.

Gli ADR nascono in stato `proposed`. La scelta raccomandata non diventa
`accepted` senza approvazione del proprietario, in particolare quando implica
provider, costi, trattamento dati o vincoli operativi. ADR-0001, ADR-0002 e
ADR-0003 sono stati accettati il 14 luglio 2026; scelte rinviate e confine
dell'autorizzazione sono registrati nel decision register.

## Quality gate comune

```bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release
cd services/backend
npm test
```

Le fasi con database aggiungono test di migrazione e integrazione. Le fasi con
frontend e backend aggiungono almeno uno scenario end-to-end senza dipendere da
fixture condivise mutabili.

Il gate completo si applica alla chiusura della PR. Una micro-sessione esegue
il sottoinsieme pertinente e lascia evidenza del risultato; per modifiche solo
documentali sono sufficienti controllo di link e file referenziati e
`git diff --check`. Una micro-sessione che modifica codice esegue sempre i test
direttamente interessati, senza rimandarli alla chiusura del work package.

## Regole di esecuzione Ultracode

- Procedere un work package alla volta rispettando le dipendenze.
- Leggere OpenAPI, repository Flutter, implementazione mock e test prima di
  modificare un contratto.
- Aggiornare contratto, server, mapper e test nella stessa PR quando necessario.
- Preferire aggiunte compatibili; non rinominare enum o campi senza migrazione.
- Non introdurre database o auth prima dell'ADR corrispondente. ADR-0003 non
  autorizza un provider remoto: PoC, risorsa gratuita e futuro hosting
  staging/pilot richiedono i rispettivi gate e approvazioni esplicite.
- Non dichiarare completata una fase se il suo criterio di uscita non e'
  riproducibile in CI.
- Fermarsi e richiedere decisione del proprietario per costi ricorrenti,
  trattamento di dati personali, provider esterni o cambi breaking.

## Deliverable iniziali di UC-00

Ultracode esegue **UC-00** producendo:

1. `docs/backend/api_contract_gap_matrix.md`;
2. `docs/backend/adr/0001-postgresql-access-and-migrations.md`;
3. `docs/backend/adr/0002-anonymous-identity-sessions-and-authorization.md`;
4. `docs/backend/adr/0003-local-and-zero-cost-remote-prototype.md`, senza
   selezionare provider o creare risorse esterne;
5. backlog consolidato con endpoint, decisioni e test richiesti per
   UC-01--UC-10;
6. `docs/backend/backend_decision_register.md` con decisioni accettate,
   rinvii e confine dell'autorizzazione.

UC-00 e' solo analisi e documentazione: non autorizza deploy, creazione di
account cloud, migrazioni distruttive o introduzione di dati reali.
