# ADR-0001: accesso PostgreSQL e migrazioni

- Stato: `accepted`.
- Data: 13 luglio 2026.
- Accettato dal decision owner: 14 luglio 2026.
- Work package: `UC-00.4`.
- Decision owner: proprietario del prodotto/repository.
- Esecuzione: `UC-02` avviato dal proprietario il 15 luglio 2026;
  `UC-02.1` completato il 15 luglio; `UC-02.2` e `UC-02.3` completati il 16
  luglio 2026.

## Contesto

Il backend corrente usa Node.js 24, JavaScript ESM e uno store in-memory.
`UC-02` deve introdurre PostgreSQL senza accoppiare HTTP o dominio a un ORM e
senza perdere l'adapter memory usato dai test veloci. Servono inoltre
migrazioni riproducibili, serializzate e verificabili da database vuoto.

La portabilita' richiesta e' tra provider PostgreSQL. Il passaggio futuro a un
motore SQL differente non e' un obiettivo del pilot e non giustifica oggi un
livello ORM aggiuntivo.

## Decisione

Adottare:

1. `pg` 8.22.0 come unico driver PostgreSQL runtime, selezionato all'apertura
   di `UC-02` e registrato senza range nel manifest e nel lockfile;
2. `node-pg-migrate` 8.0.4 come tool di migrazione fissato senza range nel
   manifest e nel lockfile;
3. SQL parametrizzato e mapper espliciti dietro porte repository applicative;
4. migrazioni JavaScript ESM append-only in `services/backend/migrations/`;
5. un job di migrazione separato dal processo applicativo e dal rollout;
6. strategia production forward-only con expand/backfill/contract e restore
   verificato per cambi distruttivi.

L'accettazione iniziale di questa decisione non autorizzava l'installazione dei
pacchetti, la creazione di un database o l'introduzione di risorse cloud. Il
comando proprietario del 15 luglio 2026 ha aperto `UC-02`: `pg` 8.22.0 e'
quindi installato con manifest e lockfile coerenti e il gate usa PostgreSQL
17.10 reale ed effimero. Usare una versione diversa di
`node-pg-migrate`, una nuova major di `pg`, un altro driver o un altro migration
tool richiede prima un emendamento proprietario o un ADR sostitutivo. Gli
aggiornamenti minor/patch di `pg` restano normali PR di dipendenza, ma fissano
la nuova versione senza range e rieseguono l'intero gate PostgreSQL.

## Confini dell'accesso dati

- Un solo `Pool` `pg` viene creato per processo e chiuso nello shutdown
  ordinato.
- `pg` puo' essere importato soltanto nell'adapter `persistence/postgres` e nel
  bootstrap dell'infrastruttura.
- HTTP, application use case e dominio dipendono da porte repository, non da
  `Pool`, `Client`, SQLSTATE o row PostgreSQL.
- Lo store memory implementa le stesse porte ed e' mantenuto per unit test e
  demo locali.
- Le query usano sempre placeholder `$1...$n`; nomi di tabelle e colonne non
  derivano da input utente.
- Un helper `withTransaction(callback)` acquisisce un client, usa lo stesso
  client per `BEGIN`/query/`COMMIT`, esegue `ROLLBACK` in errore e rilascia il
  client in `finally`.
- I mapper traducono righe `snake_case` in oggetti domain e validano enum,
  nullability e invarianti prima del ritorno.
- Gli istanti sono memorizzati come `TIMESTAMPTZ` e serializzati in ISO 8601
  UTC. ID, `BIGINT`, `NUMERIC` e tipi custom hanno parser o conversioni
  esplicite; nessuna coercizione implicita entra nel dominio.
- SQLSTATE e nomi di vincolo vengono tradotti in error code applicativi stabili;
  messaggi e parametri PostgreSQL non vengono esposti al client o ai log.

## Configurazione e operativita'

- La connessione arriva da `DATABASE_URL` o da variabili `PG*`; nessuna
  credenziale e' versionata.
- Pool size, connection timeout, statement timeout, query timeout, lock timeout
  e idle-in-transaction timeout sono espliciti e validati all'avvio.
- Il pool parte con un massimo conservativo, da dimensionare sul totale delle
  repliche e sul limite del provider dopo l'ADR hosting.
- Prima del primo deploy esterno, anche gratuito, un file o record di runbook
  versionato nel repository registra per ambiente pool massimo, budget
  connessioni e valori numerici di tutti i timeout. Valori assenti, illimitati
  o incompatibili col budget del provider fanno fallire l'avvio o il deploy.
- Pool applicativi, job di migrazione e riserva amministrativa non impegnano
  complessivamente piu' del 70% del limite connessioni verificato. Se un piano
  gratuito non pubblica il limite, questo viene misurato in un test di
  saturazione; se non e' misurabile, l'ambiente non e' idoneo al pilot.
- Sono registrati errori pool, durata query, rollback e saturazione senza
  parametri SQL o contenuti utente.
- Il processo applicativo non esegue migrazioni automaticamente all'avvio.
- Il ruolo runtime non possiede privilegi DDL; il ruolo migration e' usato solo
  dal job di rilascio.
- Il ledger di attestazione e' posseduto da un ruolo separato. Il normale
  flusso ha soltanto `SELECT`/`INSERT`: non aggiorna o elimina attestazioni e
  registra ogni riconciliazione come una nuova entry riferita alla precedente.

## Convenzioni di migrazione

- Directory: `services/backend/migrations/`.
- Formato filename: prefisso UTC e nome descrittivo.
- Linguaggio: JavaScript ESM, con SQL raw quando rende vincoli o indici piu'
  leggibili della DSL.
- Tabella di tracking: `public.pgmigrations`.
- `checkOrder`, single transaction e advisory lock restano abilitati.
- `--no-lock` e `fake` sono vietati nei flussi normali.
- Seed demo/test e migrazioni schema sono separati.
- Una migrazione gia' unita non viene rinominata, modificata o eliminata; ogni
  correzione e' una nuova migrazione.
- Ogni migrazione strutturalmente reversibile contiene un `down` esplicito.
  Una migrazione distruttiva usa `down = false` anziche' simulare una
  reversibilita' che non recupera i dati.
- `noTransaction()` e DDL concorrente richiedono motivazione, procedura
  retry-safe e verifica post-esecuzione.

La release stabile 8.0.4 di `node-pg-migrate` registra ID, nome e data di
esecuzione, ma non il checksum del contenuto. `UC-02` deve quindi aggiungere:

1. un manifest SHA-256 versionato per tutti i file migration;
2. un ledger append-only nel database, separato da `pgmigrations`, che registri
   almeno ID, nome, SHA-256 applicato, commit sorgente, digest artefatto e
   versioni esatte di driver e runner; per ogni migrazione gia' presente in
   `pgmigrations`, un'entry assente o diversa fallisce chiusa prima di applicare
   nuove migrazioni, mentre una migrazione pending deve essere nel manifest ma
   non ancora nel ledger;
3. una verifica locale/deploy tra file, manifest, `pgmigrations` e ledger;
4. un gate PR che consenta soltanto l'aggiunta di nuove migrazioni e rifiuti
   modifica, rinomina o rimozione di quelle gia' presenti nel branch base.

Il bootstrap e la riconciliazione iniziale del ledger sono reviewati e
testati. Un crash dopo l'applicazione ma prima della registrazione non viene
corretto con `fake`: blocca il rollout e richiede una procedura operativa
auditata che dimostri schema e checksum prima di completare il ledger.

## Strategia di deploy e rollback

1. Costruire un artefatto legato a un commit e a una storia migrazioni.
2. Eseguire backup o creare un restore point quando il change plan lo richiede.
3. Eseguire una sola istanza del job `migrate up`; il lock advisory resta una
   seconda protezione, non il meccanismo di scheduling principale.
4. Verificare schema, readiness e smoke test prima del rollout applicativo.
5. Distribuire codice compatibile sia con lo schema precedente sia con quello
   espanso quando il cambiamento attraversa piu' deploy.
6. Eseguire backfill separati, osservabili, idempotenti e riprendibili.
7. Rimuovere colonne o vincoli vecchi solo in una release successiva.

La fase `contract` che elimina o rende irrecuperabili dati non puo' partire
finche' un restore drill della baseline precedente non e' riuscito e non ha
registrato RPO, durata e verifica applicativa. Un ambiente prototipo
disposable non costituisce prova sufficiente per autorizzare un contract del
pilot.

I `down` dichiarati reversibili sono esercitati in locale e CI per verificare
la qualita' della migrazione; non costituiscono il rollback automatico di
produzione.

Un errore applicativo dopo una migrazione riuscita non avvia automaticamente
`down`. Si preferiscono rollback del codice, forward-fix e restore verificato;
`down` automatico puo' distruggere dati creati dopo l'upgrade.

## Quality gate di UC-02

Su PostgreSQL reale ed effimero, Node.js 24 e versioni fissate:

1. applicare tutta la storia a database vuoto;
2. rieseguire `up` e verificare che non vi siano pending migrations;
3. eseguire test repository, vincoli, transazioni e rollback;
4. verificare doppio voto, idempotenza, riferimenti cross-Comune e concorrenza;
5. verificare mapping di null, enum, UUID, numeri e `TIMESTAMPTZ`;
6. eseguire `down`/`up` per le migrazioni dichiarate reversibili;
7. provare upgrade dalla baseline di release precedente;
8. simulare una migrazione transazionale fallita e verificare assenza di schema
   parziale;
9. simulare il fallimento di una migrazione approvata `noTransaction()` e
   verificare rilevazione dello stato parziale, recovery retry-safe e controllo
   post-esecuzione;
10. eseguire due runner concorrenti e verificare che uno solo proceda;
11. verificare manifest e immutabilita' della storia;
12. verificare il ledger applicato e il fail-closed su checksum mancante o
    diverso;
13. verificare versioni risolte, lockfile e configurazione numerica di pool e
    timeout;
14. eseguire backup/restore automatizzato prima dell'uscita del work package.

Al termine di `UC-02.4`, i gate 1--13 applicabili alla storia corrente sono
verificati su PostgreSQL reale. Non esistono migrazioni approvate che usino
`noTransaction()`: il relativo gate resta obbligatorio prima di introdurne una
e non viene marcato artificialmente come superato. Backup/restore e prova
attraverso restart chiudono `UC-02.5` e l'intero work package.

I test unitari continuano a usare adapter memory. Constraint, query,
concorrenza e migrazioni non vengono validati con un database simulato.

## Alternative considerate

### Prisma ORM e Prisma Migrate

Offre schema dichiarativo, SQL di migrazione versionato, drift detection e
workflow distinti dev/deploy. E' respinto per il pilot iniziale perche'
introduce schema Prisma, client generato e shadow database oltre alle porte
domain e all'OpenAPI esistenti. In JavaScript puro il progetto sfrutterebbe
meno la type safety che giustifica questo costo.

### Drizzle ORM e Drizzle Kit

Offre schema code-first e migrazioni SQL ispezionabili, con supporto sia a
`node-postgres` sia a Postgres.js. E' un'alternativa credibile se il backend
passera' a TypeScript, ma oggi aggiunge un secondo modello di schema e una
toolchain non necessaria per il piccolo adapter SQL previsto.

### Postgres.js

Ha tagged template, pool e transazioni ergonomiche. E' respinto per evitare due
driver, dato che `node-pg-migrate` usa `pg`, e per mantenere query/transaction
semantics il piu' esplicite possibile. Puo' essere rivalutato solo insieme a un
cambio del sistema di migrazione.

### Runner SQL custom

Riduce le dipendenze ma obbliga il progetto a mantenere ordinamento, tracking,
lock, atomicita', checksum, status, recovery e DDL non transazionale. Replica
infrastruttura critica gia' fornita da un tool specializzato ed e' respinto.

## Conseguenze

### Positive

- Driver unico e SQL PostgreSQL esplicito.
- Porte e mapper proteggono dominio e HTTP dal dettaglio di persistenza.
- Transazioni, vincoli e locking restano verificabili in modo diretto.
- Migrazioni leggibili, serializzate e riproducibili in CI.
- Nessun vincolo verso uno specifico provider PostgreSQL.

### Negative

- Query e mapper sono codice manuale e richiedono test rigorosi.
- `pg` non fornisce una unit of work high-level; errori di release client o
  uso del pool dentro una transazione possono causare blocchi.
- `node-pg-migrate` 8.0.4 non rileva da solo la modifica del contenuto di una
  migrazione applicata.
- La soluzione e' PostgreSQL-specifica e non offre drift detection equivalente
  a Prisma.
- Expand/contract, backup e restore restano responsabilita' operative del
  progetto.

## Condizioni di accettazione

L'accettazione del proprietario del 14 luglio 2026 copre:

- uso di `pg` senza ORM;
- major `8` di `pg` con versione esatta nel lockfile e gate completo sugli
  upgrade;
- `node-pg-migrate` 8.0.4 fissato esattamente e aggiornamento formale dell'ADR
  prima di usare una versione diversa;
- guardrail checksum/append-only gestito dal progetto, incluso ledger dei
  checksum applicati nel database, ruolo di attestazione separato, nessun
  `UPDATE`/`DELETE` nel flusso normale e fail-closed sulle divergenze;
- migrazioni fuori dall'avvio applicativo;
- pool e timeout numerici registrati prima di ogni deploy esterno, con budget
  connessioni complessivo non superiore al 70% del limite verificato;
- rollback production forward-only con restore per cambi distruttivi;
- divieto di `contract` distruttivo prima di un restore drill riuscito e
  misurato.

## Riferimenti

- [pg 8.22.0 su npm](https://www.npmjs.com/package/pg/v/8.22.0)
- [node-postgres: pool](https://node-postgres.com/apis/pool)
- [node-postgres: query parametrizzate](https://node-postgres.com/features/queries)
- [node-postgres: transazioni](https://node-postgres.com/features/transactions)
- [node-postgres: tipi](https://node-postgres.com/features/types)
- [node-postgres: struttura del progetto](https://node-postgres.com/guides/project-structure)
- [node-pg-migrate 8.0.4: CLI](https://raw.githubusercontent.com/salsita/node-pg-migrate/v8.0.4/docs/src/cli.md)
- [node-pg-migrate 8.0.4: migrazioni e locking](https://raw.githubusercontent.com/salsita/node-pg-migrate/v8.0.4/docs/src/migrations/index.md)
- [node-pg-migrate 8.0.4: runner](https://raw.githubusercontent.com/salsita/node-pg-migrate/v8.0.4/src/runner.ts)
- [PostgreSQL: advisory lock](https://www.postgresql.org/docs/current/explicit-locking.html#ADVISORY-LOCKS)
- [Prisma Migrate](https://docs.prisma.io/docs/orm/prisma-migrate)
- [Drizzle migrations](https://orm.drizzle.team/docs/migrations)
- [Postgres.js](https://github.com/porsager/postgres)
