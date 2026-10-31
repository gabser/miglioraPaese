# Fantasy v1: port PostgreSQL locale

Fonte: `/Users/gabrieleserra/miglioraPaese`, HEAD `14b0edf18caa070a3d4a28667251a7b175ca0ce6`.
Destinazione: baseline HEAD `1fad162218e758efa3a556790e42b335a6196959`,
con modifiche locali preservate. Lavoro fase 1 del 13–14 ottobre 2026;
nessuna attestazione remota, deploy o dato operativo.

## Decisioni del port

- Regola scoring v1 pura, fixture carte e DTO source preservati; SQL separato
  in `src/persistence/postgres/fantasy-statements.js`, casi d'uso async in
  `src/application/fantasy`, HTTP nel relativo handler.
- Cinque migrazioni baseline immutate; la sesta aggiunge le 17 tabelle fantasy,
  la settima un ordine persistente di inserimento dei trasferimenti. Il backfill
  ordina gli eventuali record preesistenti per data/ID, non ricostruisce un rowid
  SQLite che PostgreSQL non possiede. Le nuove write conservano l'ordine naturale.
- Payload JSON testuali con CHECK PostgreSQL su `jsonb_typeof(payload::jsonb)`;
  timestamp ISO UTC prodotti dal server e confrontati nello stesso formato.
  Non sono stati trasportati STRICT, PRAGMA, `DatabaseSync` o transazioni sincrone.
- Identità fantasy dal bearer proposte e `sessionIdentity`, senza ID client.
  Scope team SHA-256 di `[seasonId, identità server]`; erasure globale fantasy
  precede la revoca del bearer e il reset locale. I contratti legacy rimangono.
- Transazioni PostgreSQL async e contesto del client condiviso nelle chiamate
  annidate; advisory lock globale per invarianti roster, CAS, mercato, inviti e
  leghe. Letture team/leghe risultano coerenti con le mutate. Il lock globale e
  la riconciliazione di tutti i player sono limiti di throughput del pilot.
- Il lock di riconciliazione è un commit distinto dal comando fallibile.
  La risposta di trasferimento viene recuperata sotto lock prima di CAS/expiry.
  Ogni write privata rivalida la riga sessione con lock condiviso, coordinato
  con la revoca. Tentativi invito falliti consumano la propria transazione.
- Fantasy disattivato senza configurazione PostgreSQL esplicita. Seed sintetico
  separato, calendario fisso non rinnovato al restart. Pubblicazione locale con
  `X-Admin-Token`, rifiutata quando è presente `Origin`.

## Corrispondenza test source

Il numero dei test non prova da solo la parità. Sono state conservate le
asserzioni dei casi core source nei cinque file `test/fantasy-*.test.js`,
convertendo l'harness e le chiamate sincrone a PostgreSQL/bearer. Il loop dei
lock verifica ancora -1, 0 e +1 ms. Scoring mantiene le 48 fixture condivise.
I casi seguenti richiedevano un adapter/lifecycle SQLite e hanno una verifica
PostgreSQL diversa o un differimento esplicito:

| Source test (titolo) | Verifica nella destinazione |
|---|---|
| foundation: migrates a version 1 fixture additively, preserves exact legacy payload, and never reseeds on restart | `migrations.test.js`: upgrade da prime due migrazioni preserva ID/status/voti/location; `fantasy-postgres.test.js`: restart conserva calendario e seed anche con data nuova configurata. Nessun `app_state` SQLite copiato. |
| foundation: rolls back all fantasy schema changes on failure and detects missing tables in readiness | Runner PostgreSQL transazionale e test migration failure recovery; test fantasy readiness verifica colonne/tabelle/FK mancanti e recupero, con `/ready` 200/503. |
| foundation: backup and isolated restore preserve the full fantasy catalog and calendar | Differito al gate operativo fase 8. Restart e persistenza sono verificati ora; non costituiscono prova backup/restore. |
| teams: recovers a lock missed while the process was stopped and erases all personal fantasy data on restart | Test PG recovery/restart/erasure: eleggibilità, altra squadra preservata, conteggi e calendario invariati. |
| teams: session erasure rolls back both SQLite stores and in-memory legacy state when a delete fails | Trigger PostgreSQL di errore: erasure fantasy rollback atomico di player, archiviazione lega e revoca inviti. Legacy proposte non fanno parte della DELETE fantasy e sono preservate. |
| teams: signed-session HTTP deletion isolates the other team and expires the cookie | Test HTTP bearer erasure su più Comuni: altra squadra isolata, proposal token ancora valido fino alla revoca esplicita; il cookie source non è il meccanismo d'identità destinazione. |
| teams: failed team writes roll back the draft and revision together | Trigger PostgreSQL UPDATE draft: snapshot DTO e revision identici dopo fallimento; successivo retry accettato. |
| market: retry after a lost reply and a restart returns the original command outcome even after lock | Test PG stessa risposta originale, concurrent duplicate, restart dopo lock, un solo ledger entry. |
| market: rechecks catalog version, availability, price, budget and role and rolls back a failed ledger commit | Test PG update catalogo/version/prezzo/availability/role + trigger INSERT transfer_commands: nessun credito/allowance/revision o ledger consumato. |
| results: persists results and reflections through restart and erases personal rows without erasing publications | Test PG persistenza reveal/reflection/finalization e cancellazione personale; cinque esiti pubblicati preservati. |
| results: HTTP publication requires the administrator token; players can only reveal and reflect on their own results | Test HTTP admin separato X-Admin-Token, origine rifiutata, reveal e reflection con bearer. Isolamento sessioni è verificato negli altri test HTTP/PG. |
| results: administrator publication tool uses an authorized isolated fixture and prints no token or source text | CLI source non portata: tooling pubblicazione e privacy log operativa restano gate fase 8. La route locale e i controlli della pubblicazione sono eseguibili e testati in fase 1. |
| results: a failed reflection insert leaves its bonus and team revision unchanged | Trigger PG INSERT reflection: DTO/revision/bonus invariati, successivo inserimento valido e restart persistente. |
| leagues: hash-only invites and rate limit survive restart; failed deletion rolls all league state back | Test PG hash-only invita e cinque guess fallite persistenti dopo restart; rollback erasure/archivio/inviti verificato separatamente. |

La suite `fantasy_rehearsal.test.js` source include cinque casi operativi:
backup/restore SQLite, smoke GET/profili, degraded readiness smoke, manifest
candidate/HTTPS e valutatore alert. Sono differiti alla fase 8; `/ready` degradato
è verificato funzionalmente ora. Nessun esito SQLite è presentato come
attestazione PostgreSQL. V2, non determinabile, rettifiche, proprietà/link,
account/provider, XP e missioni rimangono fuori da questo incremento.

## Controlli ulteriori PostgreSQL

Le suite aggiungono concorrenza reale per enrollment, CAS, replay trasferimento
identico e limite tre leghe, ordine storico trasferimenti a timestamp uguale,
constraint JSON/ruolo/revision e FK composite, barriera di revoca prima/dopo il
lock sessione, readiness con colonne e FK effettive. Gli adapter del gioco
legacy remote hanno una suite distinta e ledger/scoring distinti dal fantasy:
10/4/0 bearer, aggregati pubblici con soglia tre, nessuna identità `session:`
pubblicata nel leaderboard legacy. Non assegnano XP civico.
