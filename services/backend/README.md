# Migliora Paese backend

Backend HTTP locale per il pilot e per la migrazione progressiva dai repository
mock Flutter.

## Contratto proposte — aggiornamento UI del 10 ottobre 2026

Titolo e descrizione sono limitati a120 e1000 code point Unicode dopo trim,
senza troncamento. `location` è additiva: `{ "kind": "municipality" }` oppure
`{ "kind": "specific", "label": "Via Milano", "civic": "12/A", "reference": "Ingresso nord" }`.
Label richiesta1–120; civico facoltativo≤20 e riferimento facoltativo≤200.
Il luogo non specificato dai client precedenti resta `null`, distinto da Intero Comune.
Campi geografici sconosciuti o malformati vengono rifiutati. Le proposte con lo
stesso titolo sono ammesse; la similarità non è un vincolo di unicità.

La nuova migrazione `20261010110000000_proposal_location` aggiunge il luogo e
rimuove il vincolo sul titolo. Applicarla prima di avviare il nuovo adapter
PostgreSQL; le migrazioni UC-02 precedenti non sono cambiate. Il rollback fallisce
atomicamente se esistono titoli duplicati: non elimina proposte per ripristinare
l'unicità. Se il rollback riesce, la colonna luogo viene rimossa; conservarne i dati
nel backup previsto dal workflow di migrazione. I replay legacy mantengono il
fingerprint e la risposta originari. Identità autorevole e recovery lookup sono disponibili in C3; le policy C4 sono descritte nella sezione aggiornata sotto.

### Dettaglio e DTO pubblico (C2)

`GET /v1/municipalities/{municipalityId}/next-problems/{problemId}` legge lo
stato corrente della proposta pending/approved nel Comune esatto. ID mancante,
Comune errato o stato rejected restituiscono lo stesso404 `suggested_problem_not_found`.
Il catalogo pubblico esclude rejected, anche con `status=rejected`; `userId`
personalizza soltanto myVote e non concede accesso privato. La lettura delle proprie proposte rejected usa la sessione autorevole C3, descritta sotto.

Lista, creazione, voto, dettaglio e replay HTTP applicano una proiezione pubblica
esplicita: `submittedByUserId` e altri campi interni non vengono serializzati.
È una rimozione intenzionale dal contratto, coordinata col consumer Flutter che
non usa quel campo. Risultati/fingerprint legacy nello store non sono riscritti;
la risposta HTTP viene proiettata sul DTO pubblico corrente, con location null
quando assente. La GET restituisce lo stato aggiornato; il replay di creazione
mantiene lo snapshot dell'accettazione. Nessuna nuova migrazione richiesta.

## Requisiti e comandi

Richiede Node.js 24 o superiore. Le dipendenze sono fissate esattamente in
`package-lock.json`.

    npm ci
    npm test
    DATA_STORE=memory npm run dev

Il server usa HOST (default 127.0.0.1) e PORT (default 8787). Il log di avvio
viene emesso soltanto dopo che la socket è in ascolto.
DATA_STORE e' obbligatorio e accetta soltanto `memory` o `postgres`: il runtime
non effettua fallback tra i due adapter. PORT, HOST e CORS_ALLOWED_ORIGINS
vengono normalizzati e validati prima del tentativo di ascolto; una
configurazione non valida interrompe l'avvio.

    DATA_STORE=memory HOST=127.0.0.1 PORT=8787 npm run dev
    curl http://127.0.0.1:8787/health

## PostgreSQL e migrazioni

`UC-02.1` ha introdotto `pg` 8.22.0, `node-pg-migrate` 8.0.4 e una migrazione
iniziale verificata su PostgreSQL 17.10. `UC-02.2` collega esplicitamente le
letture; `UC-02.3` persiste proposte, voti/promozioni e previsioni in
transazioni; `UC-02.4` rende le scritture retry-safe e verifica concorrenza,
rollback e storia append-only. Il processo HTTP non esegue migrazioni o seed
all'avvio.

Il manifest SHA-256 deve corrispondere esattamente ai file append-only:

    npm run migrations:verify

In pull request, la storia rispetto al ref base deve contenere soltanto nuove
migrazioni; modifica, rinomina e rimozione di file esistenti falliscono:

    MIGRATION_BASE_REF=<git-ref-base> npm run migrations:verify-history

Il job di migrazione richiede una connessione DDL separata. In locale la stessa
connessione puo' attestare il ledger; fuori dal locale
`ATTESTATION_DATABASE_URL` deve usare il ruolo append-only dedicato.

    MIGRATION_DATABASE_URL=postgres://... \
      ATTESTATION_DATABASE_URL=postgres://... npm run migrate:up
    ATTESTATION_DATABASE_URL=postgres://... npm run migrate:verify

I seed locali sono separati dalla storia schema, idempotenti per le fixture
note e devono essere richiesti esplicitamente:

    DATABASE_URL=postgres://... npm run seed:local

Avvio del runtime in lettura PostgreSQL:

    DATA_STORE=postgres DATABASE_URL=postgres://... npm run dev

In alternativa a DATABASE_URL sono obbligatori PGHOST, PGPORT, PGDATABASE e
PGUSER; PGPASSWORD e' opzionale. Il pool usa default locali numerici e
limitati, sovrascrivibili con:

- `PG_POOL_MAX` (5) e `PG_POOL_IDLE_TIMEOUT_MS` (10000);
- `PG_CONNECTION_TIMEOUT_MS` (3000);
- `PG_STATEMENT_TIMEOUT_MS` (5000) e `PG_QUERY_TIMEOUT_MS` (6000);
- `PG_LOCK_TIMEOUT_MS` (1000);
- `PG_IDLE_IN_TRANSACTION_TIMEOUT_MS` (5000).

Valori zero, non numerici o fuori dai limiti documentati bloccano l'avvio.
Con DATA_STORE=postgres, proposta, voto con promozione/demozione e previsione
usano ciascuno un solo client e una transazione. Duplicati, choice bloccata,
riferimenti incoerenti e conflitti vengono tradotti in error code HTTP stabili;
SQL e parametri non sono esposti.

Le tre route di scrittura richiedono `Idempotency-Key` (8--160 caratteri ASCII
sicuri). La stessa chiave con lo stesso input restituisce la risposta originale
senza ripetere la mutazione; un input diverso risponde
`409 idempotency_key_reused`. Il client Flutter ritenta una sola volta dopo un
errore di trasporto e conserva la stessa chiave.

`npm run migrate:down` esercita una sola migrazione reversibile nei test; non e'
un rollback automatico di produzione. I flussi normali non espongono `fake` o
`--no-lock`.

I test di integrazione azzerano lo schema `public` e accettano soltanto un
database loopback il cui nome termina con `_test`:

    TEST_DATABASE_URL=postgres://postgres@127.0.0.1:5432/migliorapaese_test \
      npm test

## Identificativi Comune

Gli ID API canonici sono slug, attualmente bologna e castel-bolognese. Per
compatibilità sono accettati anche comune:Bologna e
comune:Castel Bolognese.

## CORS locale

Le origin HTTP(S) loopback (localhost, 127.0.0.1, ::1, con qualsiasi porta)
sono abilitate. Origin aggiuntive possono essere elencate esplicitamente in
CORS_ALLOWED_ORIGINS, separate da virgola; il wildcard non è accettato.

    DATA_STORE=memory CORS_ALLOWED_ORIGINS=https://pilot.example npm run dev

## Architettura

`src/server.js` e' il composition root e conserva gli export pubblici
`createApp`, `createMemoryStore` e `startServer`. Le responsabilita' sono
separate per rendere sostituibile lo store senza cambiare il contratto HTTP:

```text
src/
  application/     # casi d'uso e response shape applicative
  config/          # configurazione ambiente validata
  domain/          # enum, limiti, factory ed errori condivisi
  http/            # routing, CORS, parsing, validazione e JSON
  infrastructure/  # adapter MemoryStore
  persistence/     # migrazioni, seed, pool, mapper e adapter PostgreSQL
  server.js        # composizione e avvio del processo
```

## Limiti e sicurezza dello scaffold

- Il body JSON deve essere un oggetto ed è limitato a 64 KiB.
- Titolo e descrizione sono limitati rispettivamente a 120 e 1000 caratteri.
- Le motivazioni sono enum note, uniche e al massimo due.
- userId è fornito e controllato dal client. Serve soltanto a separare viste e
  voti nel pilot locale: non è autenticazione e può essere falsificato.
- DATA_STORE=memory perde i dati a ogni riavvio.
- DATA_STORE=postgres legge e scrive i flussi coperti da UC-02.4, chiude il
  pool nello shutdown e non perde l'idempotenza nei retry concorrenti.
- Backup/restore automatizzato e prova attraverso restart sono il gate ancora
  aperto di `UC-02.5`.

Questo backend non è deployabile in pubblico così com'è: mancano autenticazione,
adapter PostgreSQL completi, moderazione, rate limiting e garanzie operative.
HOST=0.0.0.0 è configurabile per test in container, ma non rende lo scaffold
production-ready.

Il contratto eseguibile è descritto in openapi.yaml.


### Sessione proposte e recupero privato (C3 server)

`POST /v1/proposal-session` crea un token bearer opaco e uno `submissionScope`
server. `GET /v1/proposal-session` verifica lo scope e restituisce le capability;
non restituisce nuovamente il token. Queste risposte e tutte le letture private
usano `Cache-Control: no-store`. Il server conserva solo SHA-256 del token.
Il client deve salvare token e scope prima di inviare e verificare le capability;
non deve creare automaticamente una sessione nuova per recuperare un vecchio intento.

Con `Authorization: Bearer <token>`, POST proposta e voto ignorano il `userId`
client e usano l'identità dello scope. `Idempotency-Key` è scoped a sessione,
Comune canonico e operazione. Le chiavi UC-02 legacy e i relativi fingerprint
non vengono riscritti: le chiamate scaffold senza bearer conservano il contratto
precedente e **non** offrono ownership o recovery privato. Il client applicativo usa ora il protocollo C3 per le scritture API,
verifica le capability e salva il token prima dell’invio. Il coordinator U7
deve ancora conservare l’intento e recuperarlo oltre il ciclo vita della pagina.

`GET /v1/municipalities/{municipalityId}/submissions/{idempotencyKey}` richiede
il bearer e restituisce la risposta originale dell'invio completato; un404 non
prova che un POST in corso sia cessato. Non equivale ad autorizzare un reinvio.
`GET /v1/municipalities/{municipalityId}/next-problems/{problemId}/own` restituisce
lo stato corrente anche rejected solo al reale owner di sessione. Entrambi
restituiscono il DTO sanificato, senza identificativi interni o motivi di moderazione.

`POST /v1/proposal-session/revoke` è idempotente, invalida lookup/own/nuovi invii
anche per replay e non cancella le proposte pubbliche. In PostgreSQL il lock
sulla riga sessione è mantenuto nella stessa transazione di mutazione e risposta
idempotente: invio→revoca conserva l'invio già committed, revoca→invio nega
l'invio. La revoca persiste dopo restart. Il reset client dovrà attendere questa
revoca prima di cancellare il token locale e impedire nuove operazioni durante
l'attesa. MemoryStore è una demo volatile: un restart perde sessioni e dati.

Migrazione append-only `20261010150000000_proposal_sessions.js`: aggiunge la
tabella senza alterare le tre migrazioni precedenti o i record idempotenti legacy.
Il rollback elimina le sessioni e quindi l'accesso privato, ma lascia proposte,
voti e risposta idempotente; non eseguirlo su un servizio attivo senza considerare
questa perdita di accesso.

## Policy proposte e revisione locale — C4, 11 ottobre 2026

I nuovi invii attraversano un filtro conservativo per contatti, URL, caratteri di
controllo e un elenco limitato di espressioni offensive. Il controllo comprende
luogo e riferimento; il civico non viene interpretato come numero telefonico.
Un rifiuto restituisce 422 `content_rejected`, senza creare proposta o ricevuta e
senza divulgare motivi interni. Il filtro non certifica l'assenza di dati personali.

Ogni autore può salvare tre proposte per Comune in una finestra mobile di un'ora,
con limite inferiore inclusivo. Contano anche quelle successivamente rifiutate;
errori e replay idempotenti non consumano quota. Il quarto invio restituisce 429
`submission_rate_limited`, `retryAfterSeconds` e header `Retry-After` positivo,
leggibile via CORS. Memory applica la stessa policy; PostgreSQL serializza il
conteggio per autore e Comune in transazione con entità e ricevuta. Nessuna
cancellazione di proposte per liberare quota. Il cooldown locale demo Flutter
resta cinque minuti, separato dal ramo API. La UI conserva la bozza e non pianifica
un reinvio automatico. Un rifiuto 422/429 consente un nuovo tentativo manuale.

Il bearer determina l'autore; i client legacy non possono usare il prefisso
riservato `session:`. Gli ID legacy rimangono client-controlled e non forniscono
una barriera antiabuso contro chi cambia identità. Non presentare questo scaffold
come servizio pubblico autenticato: UC-03 e le protezioni di esercizio restano
necessari per un lancio pubblico.

Applicare la nuova migrazione append-only
`20261011100000000_proposal_reviews` prima di usare la revisione PostgreSQL.
La CLI locale `node scripts/review-proposal.js` legge JSON da stdin con
`municipalityId`, `problemId`, `decision` (`reject`/`reopen`), `expectedStatus`
(`pending`/`rejected`), `operatorLabel` e `reason`. Le credenziali PostgreSQL
abilitano l'operazione; `operatorLabel` è metadato di audit, non un account
operatore autenticato. Non esiste una route amministrativa pubblica.
La transazione verifica lo stato atteso, cambia lo stato e salva la motivazione
privata; una revisione concorrente o stale restituisce `review_conflict`.
La CLI stampa solo ID/stato, senza motivo privato. Il DTO pubblico e il replay
rimangono sanificati; la ricevuta conserva lo snapshot originale. Memory mantiene
le revisioni solo per la vita del processo.

Questa CLI gestisce rifiuto e riapertura dei pending: non approva temi né altera
carte già promosse. La promozione al voto netto 1 resta la regola esplicita del
prototipo; un processo umano obbligatorio prima dell'ammissione richiede un
ulteriore contratto e il relativo workflow, senza promettere moderazione ufficiale.

Verifica locale: `TEST_DATABASE_URL` deve indicare un database usa e getta su
loopback con nome terminante in `_test`; le suite PostgreSQL ne resettano lo
schema. Le migrazioni UC-02 precedenti non sono state riscritte. Il ledger ordina
numericamente gli ID di attestazione anche oltre 9; i test verificano rollback,
upgrade da schema precedente e reapply della quinta migrazione.

### Errori di campo e ricerca luogo — allineamento finale UX

Le validazioni della proposta restituiscono400 `invalid_field` con proprietà
additiva `fieldErrors`: mappa dal percorso pubblico (`title`, `description`,
`category`, `location`, `location.label`, `location.civic`, `location.reference`)
a codice stabile (`invalid_text`, `too_long`, `invalid_choice`,
`invalid_location`). Nessun motivo interno di moderazione in questa mappa.
Flutter traduce i codici in feedback italiano associato al campo, focalizza il
primo campo e conserva bozza/revisione; edit elimina il feedback stale e un
nuovo invio richiede azione manuale. I client precedenti possono ignorare la
proprietà additiva; `error` e `message` conservano la forma precedente.

La query della lista comprende titolo, descrizione, luogo, civico e riferimento
nel Comune richiesto; Intero Comune è ricercabile. Il pregresso `location:null`
non diventa un luogo inventato. Round trip e ricerca sono verificati separatamente
nel mock Flutter, nell'adapter memory e su PostgreSQL reale.
