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

## Fantasy v1 PostgreSQL locale (Sentinelle fase 1)

La funzione resta disattivata finché `FANTASY_ENABLED=true` non è esplicito e
`DATA_STORE=postgres`. Le cinque migrazioni precedenti restano immutate;
`20261013100000000_fantasy_v1` aggiunge 17 tabelle con FK, CHECK e unique.
`20261014090000000_fantasy_transfer_order` aggiunge un ordine di inserimento
persistente al ledger, preservando la cronologia dopo riavvii e timestamp uguali.
Non esiste un adapter SQLite o un fallback fantasy in memoria.

Dopo il normale `migrate:up`, un profilo sintetico locale può usare:

```bash
DATA_STORE=postgres DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test \
FANTASY_ENABLED=true FANTASY_DEMO_SEED=true npm run dev
```

L'URL è un esempio per il database temporaneo dei test, non un database operativo.
`FANTASY_DEMO_SEED=true` inserisce una sola volta tre cataloghi dimostrativi e il
calendario fisso dall'8 ottobre 2026. Riavviare non rinnova la stagione; senza
seed esplicito una stagione mancante restituisce 404. È possibile restringere
le route fantasy con `FANTASY_PILOT_MUNICIPALITY=tuglie`. Le API leggono il tempo
del server; il clock iniettabile nei test non proviene da body/query client.

`POST /v1/proposal-session` emette il bearer già usato dalle proposte.
Le route private fantasy e le nuove letture private del gioco lo richiedono in
`Authorization`. L'identità deriva da `submissionScope` sul server; fantasy
rifiuta `userId` nei comandi e nelle query. `sessionScope` del team è SHA-256 di
`[seasonId, identità server]`. `GET team` restituisce `team_not_found` solo quando
manca l'iscrizione nella stagione valida; non iscrive automaticamente.

Formazione e conferma usano CAS `expectedRevision`; le transazioni rivalidano
la sessione con un lock condiviso della riga e serializzano le invarianti fantasy
con un advisory lock PostgreSQL comune. Il lock globale è un limite di throughput
del pilot, da sostituire con lock più granulari prima di scalare. Le query restano
nel catalogo persistence, le regole nei moduli application e lo scoring nel dominio.
La riconciliazione dei lock è un commit separato: un comando tardivo rifiutato
non annulla lo snapshot, che resta chiuso anche se il clock torna indietro.

Conferme di trasferimento memorizzano hash richiesta e risposta originale.
Il replay precede CAS, expiry e lock, anche dopo perdita della risposta e riavvio.
Inviti di lega persistono soltanto l'hash; cinque tentativi falliti consumano
comunque la finestra di un minuto. Classifiche private mostrano soli pseudonimi,
con almeno tre concorrenti e pari merito `1,1,3`; i membri tardivi sono spettatori.

`DELETE /v1/session` cancella atomicamente i dati personali fantasy di tutti i
Comuni/stagioni. Archivia le leghe possedute e revoca gli inviti, preservando
altri membri e pubblicazioni. Lascia attivi sessione e contratti delle proposte;
il client esegue successivamente la revoca e poi il reset locale. La revoca
impedisce nuove transazioni private, senza cancellare le proposte pubbliche.
Le risposte fantasy/private hanno `Cache-Control: no-store`.
`GET /ready` controlla connessione, colonne fantasy attese e FK validate, con
200 pronto o 503 degradato; `GET /health` resta un controllo di raggiungibilità.

La pubblicazione di esiti è una capacità locale separata:
`FANTASY_ADMIN_TOKEN` abilita `X-Admin-Token` sul PUT admin fantasy. Le richieste
con `Origin` sono rifiutate, e il token admin non è un bearer utente. La verifica
source v1 richiede fonte catalogo verificata, finestra osservativa terminata e
immutabilità degli esiti. Nessun v2/non determinabile/rettifica è attivo.

Il gioco remoto PostgreSQL mantiene il legacy senza bearer e usa scoring
10/4/0 per i risultati bearer, con ledger atomico/idempotente e aggregati pubblici
soppressi sotto tre previsioni. Il leaderboard pubblico legacy esclude le
identità `session:`; le leghe fantasy usano un ranking distinto. Le riflessioni
legacy Game non hanno un contratto server completo: il client segnala il limite,
senza fallback a risultati mock.

Verifica tutte le suite PostgreSQL sul database loopback usa e getta:

```bash
TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test npm test
npm run migrations:verify
```

Le suite fantasy riprendono le asserzioni source v1 su calendario, rose, mercato,
esiti e leghe. I casi SQLite di trigger/riavvio sono adattati a PostgreSQL reale;
48 fixture scoring condivise restano immutate. Il rehearsal operativo source
SQLite (backup/restore, smoke/alert/provider) non è un'attestazione PostgreSQL:
il gate operativo resta fase 8, separato da questa verifica funzionale locale.


## Account locali recuperabili (Sentinelle fase 2)

Gli account sono disattivati per default. Per la verifica locale utilizzare
`DATA_STORE=postgres`, `ACCOUNT_ENABLED=true`, `EMAIL_DELIVERY=simulated` e le
otto migrazioni additive del manifest. `/ready` verifica anche le tabelle account
quando la funzionalità è configurata. Non è configurata consegna email reale:
l'adapter in-process accetta solo indirizzi sintetici `example.com`,
`example.invalid` o domini `.test`. La outbox è ispezionabile esclusivamente nella
fixture privata; nessun endpoint HTTP restituisce codici. Nessun provider è scelto.

`POST /v1/auth/code` restituisce challenge, scadenza dopo cinque minuti e attesa
reinvio di 60 secondi; massimo sei richieste per indirizzo/ora. Il reinvio invalida
il challenge precedente. `POST /v1/auth/verify` accetta challenge/code/deviceName,
consuma il codice atomicamente (massimo cinque tentativi) e crea un bearer opaco
per dispositivo con validità di 30 giorni. `GET auth/me`, `GET auth/devices`,
`POST auth/profile`, `POST auth/logout`, `POST auth/devices/{deviceId}/revoke`
sono privati e restituiscono `Cache-Control: no-store`. La revoca propria è
idempotente; un bearer scaduto/revocato non può revocare altri dispositivi.

`POST /v1/auth/guest-link` riceve bearer account, guestToken e idempotencyKey nel
JSON. Trasferisce soltanto stato server in una transazione, senza importare demo
né duplicare ledger o punti. Se entrambi hanno una squadra nella stessa stagione,
risponde `status: conflict` senza mutation. Soltanto la scelta esplicita
`conflictChoice: keepAccount` conserva la squadra account e abbandona il guest;
rinviare conserva entrambi. Il retry dopo risposta persa recupera il risultato.

Ogni token conserva uno `submission_scope` UNIQUE. Il principal account separato
permette recupero da un secondo dispositivo. Le ricevute originali non vengono
riscritte: l'account attivo recupera gli scope associati; chiavi coincidenti
restituiscono `ambiguous_submission_scope`, risolvibile indicando lo scope
originario posseduto. Il guest bearer resta guest anche dopo logout account e può
recuperare soltanto le proprie ricevute, senza assumere identità account per
voti, previsioni o fantasy. Le classifiche pubbliche legacy escludono entrambi i
principal riservati. Nelle leghe il pseudonimo account è pubblico, l'email resta
privata. Token/codici/indirizzi non vengono scritti nei log tecnici.

La verifica locale non autorizza email reali, raccolta di dati personali, servizi
esterni, deploy o un pilot. Questi restano soggetti al gate operativo separato.

## Missioni e prove sintetiche (Sentinelle fase 3)

`MISSIONS_ENABLED` è disattivato per default. Il profilo locale richiede
`DATA_STORE=postgres`, `ACCOUNT_ENABLED=true`, `EMAIL_DELIVERY=simulated`,
`MISSION_STORAGE=local-synthetic`, `MISSION_STORAGE_ROOT` assoluto e privato,
`MISSION_RETENTION_DAYS` esplicito da 1 a 30. Applicare le nove migrazioni del
manifest; le precedenti restano immutabili. `MISSIONS_DEMO_SEED=true` abilita
soltanto un catalogo fittizio di pulizia area pubblica a Tuglie: non indica problemi
reali, ubicazioni ratificate o un pilot. Quattro finestre settimanali sono fisse
(14 ottobre–11 novembre 2026); il riavvio non rinnova calendario/protocolli.

`GET /v1/municipalities/{municipalityId}/missions?zoneId` è anonimo; il dettaglio
mostra area delimitata, protocollo versione 1, istruzioni, punto fotografico,
finestra, durata e riconoscimento dichiarato 10 XP **dopo** revisione futura.
Prenotazioni private sotto `missions/{missionId}/bookings` richiedono account
verificato. La scadenza è al massimo 30 minuti dalla conferma e mai oltre fine
finestra. Conteggio slot, scadenza, rinuncia e invio sono transazionali e
serializzati con revoca/linking account; il tempo viene letto dopo i lock.
Stessa chiave booking recupera il risultato anche dopo scadenza/rinuncia; una
chiave nuova con booking già attivo restituisce `booking_exists`, recuperabile
con `GET missions/{missionId}/booking`. Rinuncia senza punti o penalità.

Le bozze offline sono client-only e non assegnano slot. Il questionario distingue
`noIssue`, `visibleWaste`, `nonObservable` e `unsure`. I primi due richiedono il
minimo fotografico del protocollo, gli ultimi consentono zero prove. Invio con
revisione/protocollo corretti crea una sola osservazione e ricevuta immutabile
`pendingReview`, `xpAwarded: 0`; non determina esiti fantasy. La lookup
`GET /v1/bookings/{bookingId}/receipts/{commandKey}` recupera il medesimo snapshot
anche dopo risposta persa, scadenza della prenotazione e riavvio.

Gli upload sono privati e scoped alla prenotazione/account. Create upload con
MIME PNG e byte dichiarati, massimo tre prove per booking e 2 MiB per prova.
`PUT /v1/uploads/{uploadId}/chunks` riceve JSON `{offset,dataBase64}` di massimo
32 KiB decodificati (massimo 128 frammenti per prova): retry stesso offset/bytes è idempotente, contenuto diverso
confligge. Lo status espone `receivedBytes` per ripresa dopo interruzione/riavvio.
`POST .../complete` verifica PNG CRC, chunk structure, header, dimensioni (4096
per lato e 4 milioni di pixel), inflate limitato, byte dei filtri e pixel stream;
ricomprime lo stream eliminando ogni ancillary chunk, EXIF, testo e GPS. Accetta
RGB/RGBA 8 bit non interlacciati; il client normalizza JPEG/PNG della selezione
locale in PNG prima dell'upload. Digest SHA-256 e dimensione del file sanitizzato
sono stabili nel risultato di finalizzazione e nei retry, e copiati nella ricevuta
immutabile. Il file sanitizzato conserva il limite di 2 MiB. I frammenti originali
contenenti metadati vengono rimossi dopo il commit della finalizzazione.

`GET /v1/proofs/{uploadId}` richiede bearer dell'autore attivo, restituisce JSON
con PNG base64 sanitizzato e `Cache-Control: no-store`. Non esiste URL pubblico,
accesso operatore o pubblicazione prima delle fasi successive. Retention limita
l'accesso dal server; `missionService.purgeExpired(token)` elimina i file scaduti
associati all'account locale (nessuna route pubblica di manutenzione).

Storage è un adapter separato: file immutabili con nomi UUID opachi, directory
0700 e file 0600; ACL e stato confermato sono autorevoli in PostgreSQL. Non è
una transazione distribuita: se filesystem write riesce e DB rollback/interruzione
segue, può rimanere un file orfano non referenziato e inaccessibile via API.
La rehearsal di pulizia degli orfani, cancellazione, backup/restore e gestione
retention automatica resta fase 8; non dichiarare lo storage operativo. I test
provano che queste interruzioni non creano proof/receipt accettati. Nessun provider,
servizio esterno, dato reale o punto competitivo viene attivato da questo profilo.

### Local synthetic review and XP (phase 4)

`REVIEW_ENABLED=false` by default. Enabling it requires `ACCOUNT_ENABLED=true`,
`MISSIONS_ENABLED=true`, PostgreSQL, the explicit simulated email adapter and the
existing local synthetic PNG storage/retention configuration. There is no mock
fallback and no public role-grant route. Apply additive migration 10 before use;
the original nine migrations and phase 3 receipts remain unchanged.

Provision only synthetic accounts with the local adapter:

```bash
EMAIL_DELIVERY=simulated DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test \
  node scripts/review-role.js grant ACCOUNT_UUID tuglie moderator
EMAIL_DELIVERY=simulated DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test \
  node scripts/review-role.js revoke ACCOUNT_UUID tuglie moderator
```

Roles are `moderator`, `verifier`, `outcomesSupervisor`. The supervisor is reserved
for phase 5 and cannot review or publish outcomes here. Moderators claim pending
cases and forward or reject with a reason. Forwarding releases assignment;
verifiers claim screened cases, request integration or approve/reject quality.
All private case detail and proof reads require the appropriate municipality role
and current assignment; the queue omits proof metadata for other assignments.
No author reviews their own contribution. Server-owned `mission_card_links`
associate mission, season, matchday and card; the relevant persisted day snapshot
(or current roster before a snapshot exists) checks account principals and linked
guest aliases. Neither headers nor client flags grant roles or replica bonuses.

Transactions and local role grants acquire advisory lock `76131001` before
session/account, case, request and window locks, matching account revocation,
linking, fantasy and mission transactions. Role revocation is a barrier after it
completes. Time and session expiry are checked after waits and before commit.
This pilot intentionally serializes writes across processes.

The OpenAPI contract documents `/v1/review/municipalities/{municipalityId}` and
author `/v1/observations/{id}`, `/v1/me/xp`, integration uploads/supplements and
replication requests. Commands store a hash of scope/body and their original
response, replay before revision CAS, and reject changed bodies with
`idempotency_conflict`. Receipt XP0 is immutable; live state and the XP ledger are
separate. Approval credits 10 once per observation, and once per account/place/
UTC start/end interval even across different mission/window IDs. SQL partial
uniqueness covers the base NULL replica case. Requested replicas have a persisted
server relation, separate booking, capacity/window controls and one additional
award per request. `mission_places` stores the shared area identity; its initial
synthetic municipality/area hash is persisted and never regenerated after edits.
An operator provisioning a second mission on that area must reuse that place ID.

Integration requests expire 24 hours after issuance. Author uploads use the
existing chunk/status/complete transport and require an active request for
writes even after the original booking expires. Supplements append frozen notes
and sanitized proof metadata and do not rewrite the original observation.
Proof reads retain author ownership/operator assignment, retention and no-store;
proofs have no public URLs. No XP is reliability or fantasy points; no role or
competitive outcome is inferred from approval. Operational authentication and
privacy gates remain open for the later rehearsal.

A synthetic account may hold both moderator and verifier grants and carry out
both stages with a separate audited command for each. Named-person separation
and strong operational authentication remain an operational gate; dual grants
never permit self-review or bypass the linked-card conflict check.

Migration 11 preserves the already attested migration 10 checksum and repairs its
schema rollback index ordering with a compatibility shim. The base partial
unique index becomes `mission_base_account_window_idx`; the historical name
`mission_active_account_window_idx` is a nonunique, replica-column-independent
index. Down 11 intentionally retains both indexes until down 10 auto-removes the
partial index, drops the shim and restores the phase 3 index. Reapplying 11 is
idempotent with the retained shim. Tests exercise down11/up11 and down11/down10/
up10/up11 on a disposable database. This supports schema rollback; replica data
cannot be downgraded to phase 3 uniqueness without a reviewed restore strategy.

A booked replication request includes nullable `bookingId`, derived from its
persisted booking relation. The author can GET that request with another device
of the same account and recover the booking through GET `/v1/bookings/{id}`
without the original device's idempotency key or consuming another slot.

### Measurement and outcomes pilot (phase 5, local synthetic only)

`MEASUREMENTS_ENABLED=false` by default. Enabling it requires PostgreSQL,
`ACCOUNT_ENABLED=true`, `MISSIONS_ENABLED=true`, `REVIEW_ENABLED=true`, and
`FANTASY_ENABLED=true` with their existing explicit simulated email/storage
configuration. Persisted v2 deadlines reconcile internally even with the optional measurement
HTTP surface disabled, without requiring proof storage. No automatic season
upgrade or calendar renewal occurs. Existing
`fantasy-demo-v1` seasons and 48 scoring fixtures retain their rules. Explicit
new synthetic seasons use `fantasy-v2` and predeclare a `closeAt` for every card,
including cards without a protocol. General calendar administration is separate.

The public `/v1/municipalities/{municipalityId}/measurements` overview accepts
`seasonId` and `matchdayId` together; it shows only published problems, baseline,
protocols, intervention history, evaluated outcomes and coverage. All fantasy
routes accept optional `seasonId` query (legacy bodies stay unchanged). Default
scope is active season at server time, otherwise next future, otherwise latest
past. League IDs resolve their own season and reject a contradictory hint.
Private history derives the owner from the bearer session, including guests:
`/v1/municipalities/{municipalityId}/fantasy/seasons/{seasonId}/matchdays/{matchdayId}/results/history`.

Measurement commands under `/v1/measurements/municipalities/{municipalityId}`
require the database municipality `outcomesSupervisor` role. Existing review role
CLI grants this role in local synthetic tests; there is no role grant endpoint.
Account authors may appeal published versions without an operator role. Case
access, proof retention, self evaluation and competitive conflicts include linked
guest aliases and frozen squads. Public records omit observation/account/proof
IDs, sentinel notes and private appeal reasons. All responses are `no-store`.

A protocol is published strictly before lock and binds a preexisting baseline,
place, indicator, unit, measurement window, deadline and optional quantitative
mission definition. Baseline, documentary measurements and source dates match
immutable registry values. `threshold` is absolute tolerance: equality is stable
(including decimal boundaries); with zero tolerance every nonzero change counts.
A numeric mission accepts `measurement:{value}` for observable answers, validates
range/integer constraints and freezes the server binding in the receipt. Unknown
or nonobservable is absent, never zero. Legacy bodies retain their exact original
six-value fingerprint and receipts without a new null field.

Human determinate publication requires a relevant authorized document **or** two
independent approved quantitative accounts, plus a quality/comparability rationale.
All pertinent contradictory evidence blocks a determinate verdict; no majority
vote or automatic publication exists. Temporary/completed intervention status
never proves improvement. At the predeclared deadline, missing outcomes close
idempotently as `undeterminable` with `observed:null` and a system audit actor.
Missing protocol/baseline/unit remains null in that public deadline record.

V2 unknown outcomes score zero observation/prediction points. Captain reflection
rounding and accepted transfer penalties are preserved. Publication and correction
append immutable evaluation/result revisions for every eligible snapshot in one
shared PostgreSQL unit of work; this supports pool size one. Original reveals,
contribution receipts and XP remain separate. Current summaries and league ranks
use current revisions. Guest linking atomically migrates result revision ownership;
`keepAccount` exclusions preserve abandoned guest history without adding points.
The old local admin publication route rejects v2 even with a valid admin token.

Sources have no client `verified` flag. For synthetic loopback `*_test` databases
only, register a fixture record from a local JSON file:

```bash
DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test \
node scripts/register-measurement-source.js --local-synthetic /tmp/source.json
```

Fields: `id,municipalityId,placeId,indicator,unit,value,measuredAt,label,provenance,registeredBy`.
The immutable adapter rejects replacement. The private fixture export
`seedSyntheticMeasurementSeason` in `measurement-synthetic-fixture.js` explicitly
creates new season/card/day/mission IDs, card deadlines and two documentary test
sources; callers must pass `loopbackSynthetic:true`. These are synthetic records,
not operational ratification. No HTTP source registration or real provider exists.

Migrations 1–11 remain unchanged (including the documented persistent down11 shim).
12 adds measurement entities and result revisions; 13 makes the new snapshot FK
deferrable for the existing atomic guest ownership transaction. Manifest checksums
freeze each applied artifact. Schema down/up tests use disposable PostgreSQL data.

### Guided league invites and ownership (phase 6)

`LEAGUE_CONTINUITY_ENABLED=false` by default. Enabling it requires
`DATA_STORE=postgres` and `FANTASY_ENABLED=true`. The public JSON-body
`POST /v1/fantasy/league-invites/preview` resolves municipality, authoritative
league season, expiry, league revision and server-calculated role without
creating a player or membership. Thirty attempts per peer/minute are persisted
using hashed peer buckets. Responses and errors use `Cache-Control: no-store`.
Token values remain hash-only at rest and never participate in paths or logs.
The client captures `#league-invite=...` locally and removes it before navigation.

Join preserves `{token}` compatibility; guided clients supply
`expectedLeagueRevision` and `expectedRole` together. Stale league/role returns
`league_revision_conflict`; the first lock and frozen snapshots determine late
spectator entry. A successful join retry does not duplicate membership.

`GET .../leagues/{leagueId}/ownership` returns the league revision, candidates
only for its owner and a pending offer only for owner/target. Candidates use
opaque membership IDs and pseudonyms even below the public ranking threshold.
Owner offers to an existing member, who explicitly accepts; revoke requires the
current owner. All three commands require `expectedRevision` and an 8–128
character `idempotencyKey`, and persist exact successful response snapshots for
recovery before CAS. Offers expire at min(7 days, season end); acceptance checks
the target's current membership and three-owned-leagues limit. Transactions
serialize with membership changes, guest linking and session revocation.
Organizational revisions/audits never rewrite points. Owner exit/erasure archives
offers and invites; accepted transfer leaves the old owner an ordinary member.

Migration 14 adds league revisions, deferred offer/command principal FKs,
organizational audit and bounded preview buckets. Phase-2 linking moves both
from/to principals and command ownership atomically while keeping historic
response snapshots; `keepAccount` cancels excluded guest offers and grants no
account authority through guest aliases. Apply only locally before pilot gate.

Migration 15 separates historical creator identity from mutable owner identity;
`creation_key` remains stable across transfers. Replaying creation while still a
member returns current privileges, and a departed creator cannot read or recreate
that league through the old key. Guest linking moves creator identity only for
nonexcluded seasons. If account/guest already have teams, the existing explicit
`keepAccount` exclusion preserves account commands. If an erased account team
left the same historical creation key, that account command wins: the guest
creator snapshot is retained while its current league/membership still move.
This prevents a uniqueness failure or replaying two different creations through
one ambiguous key. Old guest credentials gain no account access. Down migration
retains the prior owner uniqueness guard and can reject states made possible by
transfers; its transaction rolls back rather than discarding league history.

Rollback policy for phase 6 is **restore**, with writers quiesced, after feature
writes. SQL down15 is suitable only before feature use: two different creators
may use the same creation key and later transfer both leagues to one owner,
which the previous owner-scoped uniqueness cannot represent. Down15 deliberately
rejects that state with `23505`; transaction rollback preserves the new schema,
creator keys, leagues and command snapshots. Do not rewrite keys to force a
downgrade. The local populated DDL round-trip proves pre-write schema reversal;
it does not claim general reversal of all phase-6 domain states.

### Fase 7 — cooperazione, inbox e ritorno sintetico

`COOPERATION_ENABLED=false` è il default. Per abilitarlo servono PostgreSQL e
`ACCOUNT_ENABLED`, `MISSIONS_ENABLED`, `REVIEW_ENABLED`, `MEASUREMENTS_ENABLED`,
`FANTASY_ENABLED` tutti `true`, oltre alla configurazione sintetica già richiesta.
La migrazione 16 è additiva; le migrazioni 1–15 rimangono immutate.

- `GET /v1/municipalities/{municipalityId}/cooperation?seasonId=&matchdayId=`
  restituisce obiettivo pubblicato e copertura anonima su unità luogo/intervallo UTC.
  Selezionare entrambi gli scope oppure nessuno; il default conserva stagione
  attiva/prossima/ultima. Un obiettivo assente o con zero target ha ratio `null`.
- `GET /v1/fantasy/municipalities/{municipalityId}/leagues/{leagueId}/cooperation?matchdayId=`
  richiede account membro e usa la stagione della lega. Distingue progresso della
  lega e del Comune. Competitori e spettatori contribuiscono se già membri
  all'invio e ancora membri alla validazione; adesioni successive non importano
  contributi. Uscita/trasferimento non cancellano il ledger anonimo; archivio
  impedisce nuovi accrediti. Repliche, XP e missioni equivalenti non moltiplicano
  la stessa unità. Non esistono ranking individuali di cooperazione.
- `GET /v1/me/inbox?municipalityId=&limit=&cursor=` accetta limit 1–50, default 20.
  `PUT /v1/me/inbox/{messageId}/read` con body vuoto persiste idempotentemente
  lo stato letto per account, condiviso fra dispositivi; record altrui/assenti 404.
- `GET /v1/me/followed-places?municipalityId=` legge solo la lista privata.
  `PUT`/`DELETE /v1/me/followed-places/{placeId}?municipalityId=` con body vuoto
  seguono/smettono di seguire un luogo del catalogo pubblico, senza effetti dal GET.
  `Mission.placeId` e `MeasurementEvaluationPublished.placeId` sono identità
  pubbliche nullable; il client non deriva ID dai titoli o dalle coordinate.

Gli eventi sono salvati nella stessa transazione di revisione/pubblicazione,
prima del checkpoint di fault injection; il drain inbox transazionale è ripetibile
anche dopo riavvio. Le sovrapposizioni autore/giocatore con snapshot frozen/follower
producono un messaggio per evento/versione/account. I titoli sono statici; non si
copiano ragioni private, note, foto o token. Le repliche umane notificano solo
il destinatario con target `recheck` owned; i follower ricevono target pubblico
`mission`, senza creazione di richieste o bonus XP. Unfollow interrompe solo i
nuovi eventi da follow, conservando storico e proprie integrazioni. Le FK recipient
eliminano inbox/outbox/follow alla cancellazione account senza toccare altri account.
Gli eventi creati con feature spenta non sono recuperati retroattivamente. Il
reconciler delle deadline riceve l'hook prima della creazione store, quindi anche
le nuove pubblicazioni durante startup sono atomiche e idempotenti.

Pubblicazione amministrativa esplicita, nessuna nuova route HTTP e nessun rinnovo
al boot:

```bash
DATABASE_URL=postgres://postgres@127.0.0.1:55432/migliorapaese_test \
  node services/backend/scripts/publish-calendar.js --local-synthetic \
  services/backend/scripts/examples/calendar-synthetic.json
```

Il file di esempio contiene due controlli settimanali su uno stesso luogo sintetico.
Il comando accetta solo database loopback `*_test`, JSON locale massimo 256 KiB e
`season.synthetic=true`. Restituisce ricevuta persistita con digest JSON canonico,
ID e versioni. Stessa chiave/contenuto torna la stessa ricevuta anche dopo lock o
riavvio; chiave riusata con contenuto diverso e ID già pubblicati restituiscono
conflitto 409, mai modifiche allo storico. Tutte le risorse sono pubblicate nella
stessa UoW, senza importare squadre, membership o punti. La costruzione v2 è
condivisa con la fixture misurazioni della fase 5.

Il formato contiene `idempotencyKey`, `municipalityId`, `season`, `cards`,
`matchdays`, `missions`, `coverageGoals`. Massimi: 200 carte, 52 giornate,
500 missioni, 52 obiettivi e 1000 target per obiettivo. Gli identificatori nuovi
sono opachi, massimo 128 caratteri: colon, spazi e Unicode ammessi; controlli,
slash/backslash, delimitatori `? # %` e segmenti esatti `.`/`..` vietati. Il lock
è ricontrollato immediatamente prima del commit; se scade tutto il comando
è annullato. Una giornata dichiara
`startsAt`, `locksAt`, `observationEndsAt`, `closeAt`; tutte le pubblicazioni
avvengono prima del lock. Ogni missione dichiara card/giornata, luogo, protocollo
quantitativo versionato, unità, range, istruzioni, baseline sintetica precedente
all'osservazione e finestre con capacità. Missioni equivalenti della stessa carta
condividono baseline/protocollo. Gli obiettivi esplicitano i target unici
`{placeId,startsAt,endsAt}` riferiti alle missioni del calendario. Le carte locali
ammettono `sourceStatus=pending|unavailable`; `verified` non è un'attestazione
accettabile dal file. Non sono autorizzati dati reali o provider operativi.

## Phase 8 — synthetic local operations (no operational approval)

`CANDIDATE_ID` is an optional lowercase 64-hex code-manifest digest. `/health`
returns the effective persistence, profile, version and feature booleans; `/ready`
also checks each required dependency and reports static dependency booleans.
Neither creates sessions or exposes connection strings, private IDs or paths.
The server creates a fresh UUID request ID, ignoring incoming IDs. Request events
and in-process metrics contain only static route name, status, integer duration,
request ID and candidate digest. A failing log sink degrades readiness; there is
no collector, external provider or operational alerting. `requestLogger` can
supply a local structured sink; the default is the configured server logger.

Operations are opt-in with `OPS_LOCAL_ENABLED=true`, a loopback host, explicit
loopback PostgreSQL database ending `_test`, fantasy enabled and
`OPS_JOURNAL_ROOT`. Without this flag existing erasure semantics remain, but
there is **no external erasure replay/restore guarantee**. Do not expose a
restored database without running the guarded restore and checking its result.

| Operation | Removed/revoked | Explicitly retained / limitation |
|---|---|---|
| Fantasy erasure (`DELETE /v1/session`) | Fantasy player/team/result rows via existing cascades, memberships and invite attempts; owned leagues archived | Account, email, account sessions, mission notes/photos/receipts, review/XP, measurement and cooperation audit/history remain; some archived league/ownership audit references persist. This is not full account closure. |
| Logout/device revocation | Access through the selected account session/device | Account and domain data remain; separate from fantasy erasure. |
| Proof retention cleanup | Expired complete and incomplete proof bytes, chunks and unreferenced UUID files; expired DB file pointers cleared | Observation notes/receipts, proof metadata/hash, reviews, XP and aggregates remain. Expired proofs already fail policy reads before cleanup. |
| Full account closure | Not implemented | Needs a separately approved policy and explicit class-by-class implementation. No privacy/GDPR compliance claim. |

The external HMAC journal records fantasy-scoped opaque references and a signed
sequence. Keys and journal stay outside every backup, with private directory700
and file600 permissions. HTTP erasure writes pending before its DB transaction,
then complete after DB commit; interrupted operations block readiness and data
exposure. Retry the same fantasy erasure after inspecting the failure to
reconcile it. A crashed process may leave `journal.lock`; while writers are
stopped, an operator must inspect pending state and remove the stale lock before
retry. Never recreate a missing journal/key: recover the original external
material. Initialization rejects a half-missing pair. Journal loss, tampering,
or any unresolved pending operation fails closed. The signed backup watermark
ensures replay includes **only erasures after that snapshot**, preserving
legitimate later re-enrollment already included in a newer snapshot.

Commands use the installed Node24 and local PostgreSQL17 binaries, without
contacting providers. Set explicit env without printing secrets:

```sh
# All commands additionally require OPS_LOCAL_ENABLED=true OPS_SYNTHETIC_ACK=true.
# DATABASE_URL is the explicit loopback *_test source.
node scripts/operations.js journal-init
# Set CANDIDATE_ID, MISSION_STORAGE_ROOT, OPS_BACKUP_ROOT (new empty private dir),
# OPS_JOURNAL_ROOT (separate external dir), OPS_WRITERS_SUSPENDED=true.
node scripts/operations.js backup
# Set OPS_RESTORE_DATABASE_URL to a NEW sentinelle_restore_<suffix>_test DB,
# and OPS_RESTORE_PROOF_ROOT to a new empty private dir.
node scripts/operations.js restore
# Stop writers, retain the original journal/key, then sweep private proof storage.
node scripts/operations.js cleanup
```

Backup requires a declared suspension of **all writers**, including legacy
writers. The upload advisory lock is additional coordination, not a claim of
universal quiescence. `pg_dump` uses an exported repeatable-read PostgreSQL
snapshot; referenced finalized proofs or active chunks are copied and hashed.
A signed manifest binds dump/proof SHA256, schema/migration manifest, candidate
identity and external-journal watermark. It never contains database URLs or
credentials. Output/input sizes are bounded. No SQLite backup is treated as
PostgreSQL evidence.

Restore validates all hashes and the external journal first, then creates a new
allowlisted database (existing databases rejected), restores one transaction and
replays later fantasy erasures before declaring readiness. Failures leave only
a disposable unexposed copy for inspection; they never reset/drop the source or
attempt a downgrade. Preserve backups and suspend access/writes for rollback;
rehearse on another new copy. Historic migrations1–16 remain immutable; down10/
11/15 can reject populated states atomically, so rollback uses controlled restore.

Cleanup uses `lstat`, strict UUID filenames and no symlink following; unexpected
entries fail closed. It deletes bytes before clearing pointers, so interruption
leaves retryable metadata; orphans from failed DB writes are swept. Root and
ancestors must be real private directories (macOS system `/var` and `/tmp`
aliases are normalized by the proof adapter only). Directory700/file600,
restricted ownership/access, journal custody, suspension of writers, real policy,
provider procedures and human approvals remain operational responsibilities.

Restored copies carry a persistent database comment marker, installed while the
new database has connections disabled. Pending/faulted copies return503 from
readiness and data routes even with operations disabled and after restart.
A verified marker is HMAC-signed and bound to candidate identity, original
external journal and applied sequence. Starting a restored copy therefore also
requires matching `CANDIDATE_ID` and `OPS_JOURNAL_ROOT`; a missing/changed key or
any later external erasure blocks exposure until another controlled restore.
This deliberately fails closed: a restored copy is not silently promoted into
an independent live service. Preserve the external journal/key alongside, never
inside, backups. Do not remove markers or recreate journal material to force
readiness.

`TEST_DATABASE_URL=<loopback *_test reference> CANDIDATE_ID=<digest> node
scripts/rehearse-operations.js` creates a **new** synthetic rehearsal database;
it does not reset the reference DB. It publishes the checked-in two-week
calendar, runs actual HTTP account recovery, proof upload, integration,10XP
review, intervention/measurement/appeal/correction, invites/ownership, coverage,
inbox, retry/restart and second weekly check, then performs PostgreSQL
backup/restore with later fantasy erasure and checks restored HTTP readiness.
Private artifacts and bounded results remain in `.sentinelle-local/phase8/backend`.
Run this after freezing the real candidate digest; placeholder development runs
are not final-candidate evidence.
