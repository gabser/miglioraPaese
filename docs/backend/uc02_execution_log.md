# UC-02 execution log

## UC-02.4 - concorrenza, rollback e immutabilita' della storia

- Stato: `complete`.
- Data chiusura: 16 luglio 2026.
- Branch: `codex/uc-02-postgres-migrations`.
- Risultato principale: retry di proposte, voti e previsioni applicati una sola
  volta, gare concorrenti serializzate e storia migration protetta.

### Criterio di accettazione soddisfatto

- Le route di scrittura richiedono `Idempotency-Key`; chiave e fingerprint,
  status e response JSON sono salvati nella stessa transazione della mutazione.
- Un replay uguale restituisce la response originale; riuso con input diverso
  risponde `409 idempotency_key_reused` senza nuova mutazione.
- `ApiNextProblemsRepository` genera una chiave per azione e `ApiClient`
  ritenta una sola volta gli errori di trasporto conservando chiave e body.
- Due voti concorrenti con la stessa chiave producono un solo voto; due choice
  concorrenti conservano una sola previsione e l'altra riceve `409` stabile.
- Fault injection dopo la mutazione del voto verifica rollback sia dei dati sia
  del record idempotente.
- Un advisory lock di coordinamento serializza due migration runner da schema
  vuoto; una migrazione transazionale fallita non lascia schema parziale e il
  retry pulito riesce.
- Manifest a due entry e ledger restano verificati; il gate CI rispetto al ref
  base rifiuta modifica, rimozione o rinomina di migrazioni esistenti.
- La storia corrente non contiene migrazioni `noTransaction()`; il relativo
  test e la procedura retry-safe sono obbligatori prima di autorizzarne una.

### Comandi ed esito

```text
TEST_DATABASE_URL=postgres://... npm test
  PASS - 48 test, 7 suite, 0 failure, PostgreSQL 17 reale

npm run migrations:verify
  PASS - 2 manifest entry verificate

MIGRATION_BASE_REF=main npm run migrations:verify-history
  PASS - storia append-only

fvm flutter test test/core/network/api_client_test.dart \
  test/features/next_problems/data/api_next_problems_repository_test.dart
  PASS - 11 test

fvm dart format --output=none --set-exit-if-changed .
  PASS - 101 file, 0 modifiche

fvm flutter analyze --no-fatal-infos --no-fatal-warnings
  PASS - nessun errore o warning bloccante; info legacy preesistenti

fvm flutter test
  PASS - 35 test

fvm flutter build web --release
  PASS

git diff --check
  PASS
```

### Rischi e lavoro intenzionalmente aperto

- Backup/restore automatizzato, misurazione e prova di persistenza attraverso
  restart appartengono a `UC-02.5`.
- `userId` resta client-controlled fino al cutover atomico di `UC-03`.
- L'idempotenza memory serve contratto e test, ma non sopravvive al riavvio;
  nessun ambiente persistente puo' selezionare implicitamente `MemoryStore`.

## Prossimo incarico esatto

Aprire `UC-02.5 - backup, restore e gate completo`: automatizzare dump e
restore su database disposable, verificare dati e ledger dopo restart,
documentare runbook e chiudere tutti i gate backend/Flutter del work package.

## UC-02.3 - scritture PostgreSQL e transazioni

- Stato: `complete`.
- Data chiusura: 16 luglio 2026.
- Branch: `codex/uc-02-postgres-migrations`.
- Risultato principale: proposte, voti/promozioni e previsioni persistono con
  transazioni PostgreSQL, senza fallback o side effect parziali.

### Criterio di accettazione soddisfatto

- `withTransaction` acquisisce un solo client, esegue BEGIN/COMMIT, tenta
  ROLLBACK su ogni errore e rilascia sempre il client.
- Inserimento proposta normalizza il titolo, persiste autore legacy e traduce
  il vincolo univoco in `409 duplicate_title`.
- Il voto blocca la proposta, applica toggle/cambio scelta, ricalcola conteggi
  e stato, promuove/demove il problema e sincronizza l'attivazione del Comune
  nella stessa transazione.
- L'upsert previsione verifica turno, problema e Comune, conserva la choice
  immutabile e aggiorna soltanto motivations/confidence.
- SQLSTATE attesi diventano error code applicativi stabili; query, parametri e
  dettagli PostgreSQL non entrano nelle response.
- Rollback reale verificato sia dopo una promozione senza turno corrente sia
  quando la demozione tenta di eliminare un problema gia' referenziato.
- Le tre route di scrittura mantengono status e response shape OpenAPI; la
  risposta temporanea 501 di `UC-02.2` e' stata rimossa.

### Comandi ed esito

```text
TEST_DATABASE_URL=postgres://... npm test
  PASS - 40 test, 7 suite, 0 failure, PostgreSQL 17 reale

npm run migrations:verify
  PASS - 1 manifest entry verificata

git diff --check
  PASS
```

### Rischi e lavoro intenzionalmente aperto

- Retry-safe, idempotency key e gare estreme tra richieste appartengono a
  `UC-02.4`; il lock riga proposta serializza gia' i voti ordinari.
- La demozione di un problema gia' referenziato fallisce con
  `409 promotion_in_use` e conserva lo stato precedente; il lifecycle definitivo
  dei problemi promossi resta da consolidare con il gioco completo.
- Backup/restore e prova di persistenza attraverso restart appartengono a
  `UC-02.5`.

## UC-02.2 - letture PostgreSQL

- Stato: `complete`.
- Data chiusura: 16 luglio 2026.
- Branch: `codex/uc-02-postgres-migrations`.
- Risultato principale: runtime locale collegabile esplicitamente a
  PostgreSQL per tutte le letture autorizzate, senza fallback a `MemoryStore`.

### Criterio di accettazione soddisfatto

- Application service e HTTP attendono porte store asincrone senza importare
  `pg`; `createApp` richiede sempre una composizione esplicita.
- `DATA_STORE=memory|postgres` e' obbligatorio nello startup. PostgreSQL
  richiede DATABASE_URL o PGHOST/PGPORT/PGDATABASE/PGUSER; pool e sei timeout
  sono numerici, limitati e validati prima dell'ascolto.
- Un solo pool e' creato dal composition root e viene chiuso nello shutdown.
- Seed `local` e `test` sono idempotenti per le fixture note, transazionali e
  separati dai file migration.
- Query parametrizzate leggono Comuni, turno corrente, problemi, proposte con
  conteggi/myVote per utente e previsioni isolate per utente.
- Mapper fail-closed verificano shape esatta, enum, null, array, interi e
  `TIMESTAMPTZ`, serializzato sempre ISO 8601 UTC.
- Le response GET restano compatibili. In modalita' PostgreSQL le scritture
  rispondono esplicitamente `501 postgres_writes_not_available`, documentato
  in OpenAPI, fino a `UC-02.3`.

### Comandi ed esito

```text
TEST_DATABASE_URL=postgres://... npm test
  PASS - 33 test, 6 suite, 0 failure, PostgreSQL 17 reale

git diff --check
  PASS
```

### Rischi e lavoro intenzionalmente aperto

- Proposte, voti e previsioni non vengono ancora scritti su PostgreSQL: la
  chiusura esplicita impedisce una falsa persistenza parziale.
- Transazioni applicative, traduzione SQLSTATE, idempotenza e doppio voto
  appartengono a `UC-02.3` e `UC-02.4`.
- Backup/restore e prova di persistenza attraverso restart appartengono a
  `UC-02.5`.

## UC-02.1 - schema e migrazione

- Stato: `complete`.
- Data chiusura: 15 luglio 2026.
- Branch: `codex/uc-02-postgres-migrations`.
- Risultato principale: schema iniziale e migrazione reversibile verificati su
  PostgreSQL reale, con manifest SHA-256 e ledger append-only.

## Criterio di accettazione soddisfatto

- `pg` 8.22.0 e `node-pg-migrate` 8.0.4 sono fissati senza range nel manifest
  npm e nel lockfile.
- La migrazione parte da database vuoto, crea le tabelle di dominio autorizzate
  da `UC-02` e una seconda `up` non trova migrazioni pending.
- Il ledger registra migration id, id `pgmigrations`, nome, checksum, commit,
  digest artefatto e versioni esatte; `UPDATE` e `DELETE` falliscono chiusi.
- Vincoli testati: titolo normalizzato univoco per Comune, riferimenti
  cross-Comune, scelta prediction immutabile e aggiornamento metadati ammesso.
- Il ciclo `down/up` della migrazione reversibile e' verde.
- I 19 test backend preesistenti restano verdi e OpenAPI non cambia.

## File e contratti modificati

- `services/backend/migrations/`: schema iniziale e manifest checksum.
- `services/backend/src/persistence/postgres/`: verifica manifest, ledger e
  runner separato dallo startup HTTP.
- `services/backend/scripts/`: comandi espliciti `up`, `down` e `verify`.
- `services/backend/test/migrations.test.js`: gate statico e PostgreSQL reale.
- `services/backend/package.json` e `package-lock.json`: versioni esatte.
- `.github/workflows/backend.yml`: `npm ci` e PostgreSQL 17 effimero.
- README, ADR-0001, decision register e piano: stato e comandi aggiornati.

Il contratto `services/backend/openapi.yaml`, `/v1`, response shape ed error code
HTTP restano invariati. Il runtime usa ancora `MemoryStore` per scelta
esplicita: collegare PostgreSQL prima dei mapper di lettura/scrittura sarebbe un
fallback incompleto.

## Decisioni e confini

- Selezionata `pg` 8.22.0, release 8.x corrente all'apertura di `UC-02`.
- Il gate locale usa PostgreSQL 17.10; la CI usa l'immagine esatta
  `postgres:17.10-alpine`.
- Sessioni, principal, operatori, ruoli e moderazione restano fuori da
  `UC-02.1` e appartengono ai work package gia' pianificati.
- Le colonne `user_id` attuali sono marcate come legacy e client-controlled;
  il cutover a foreign key del principal resta atomico in `UC-03`.
- Il test locale usa la stessa credenziale per DDL e attestazione. Ogni ambiente
  non locale deve usare il ruolo di attestazione separato previsto da ADR-0001.

## Comandi ed esito

```text
npm run migrations:verify
  PASS - 1 manifest entry verificata

TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test npm test
  PASS - 23 test, 4 suite, 0 failure, PostgreSQL 17.10 reale

git diff --check
  PASS
```

L'installazione di `node-pg-migrate` 8.0.4 segnala la deprecazione della propria
dipendenza transitiva `glob` 11.1.0; `npm audit` non segnala vulnerabilita'. La
versione del runner non viene cambiata senza emendamento di ADR-0001.

## Rischi e lavoro intenzionalmente aperto

- Nessun adapter PostgreSQL e' ancora collegato all'application service;
  persistenza attraverso restart non e' quindi ancora un criterio soddisfatto
  del work package complessivo.
- Seed demo/test separati, pool runtime, timeout numerici e shutdown ordinato
  appartengono alle prossime micro-sessioni.
- Concorrenza tra runner, failure injection di migrazioni e gate di storia
  rispetto al branch base appartengono a `UC-02.4`.
- Backup/restore automatizzato e restart persistente appartengono a `UC-02.5`.

## Prossimo incarico esatto

Aprire `UC-02.4 - concorrenza, rollback e immutabilita' della storia` con un
solo risultato principale:

1. esercitare richieste concorrenti su voto e previsione, inclusi retry e
   conflitti di choice;
2. introdurre la semantica idempotente necessaria per evitare che un retry
   dopo timeout inverta nuovamente un voto;
3. simulare failure injection nei punti transazionali e confermare assenza di
   side effect parziali;
4. verificare due migration runner concorrenti e recovery degli stati falliti;
5. aggiungere il gate append-only della storia rispetto al branch base.
