# Migliora Paese backend

Backend HTTP per il pilot e per la migrazione progressiva dai repository mock
Flutter.

## Requisiti e comandi

Richiede Node.js 24 o superiore e non usa dipendenze npm.

    npm test
    npm run dev

Per la rehearsal locale di Tuglie, con database dedicato e soli seed
sintetici:

    npm run dev:tuglie

Il comando ascolta esclusivamente su loopback e accetta Flutter Web da
`http://localhost:7357`. I segreti di sviluppo incorporati nel launcher non
sono validi per uno staging remoto.

Il server usa HOST (default 127.0.0.1) e PORT (default 8787). Il log di avvio
viene emesso soltanto dopo che la socket è in ascolto.

    HOST=127.0.0.1 PORT=8787 npm run dev
    curl http://127.0.0.1:8787/health

In sviluppo lo store resta in-memory se `DATABASE_PATH` non e' impostato. Per
provare la persistenza SQLite:

    DATABASE_PATH=./data/pilot.sqlite npm run dev

In produzione sono obbligatori `DATABASE_PATH`, `ANON_IDENTITY_SECRET`,
`MODERATION_ADMIN_TOKEN` e `PILOT_MUNICIPALITY_ID`. I due segreti devono essere
indipendenti, contenere almeno 32 byte e arrivare dal secret manager, non dal
repository. In alternativa alle variabili dirette si possono usare
`ANON_IDENTITY_SECRET_FILE` e `MODERATION_ADMIN_TOKEN_FILE`.

    DATABASE_PATH=/data/pilot.sqlite \
    ANON_IDENTITY_SECRET=<secret-di-almeno-32-byte> \
    MODERATION_ADMIN_TOKEN=<token-indipendente-di-almeno-32-byte> \
    PILOT_MUNICIPALITY_ID=tuglie \
    MIN_AGGREGATE_SAMPLE_SIZE=3 \
    CORS_ALLOWED_ORIGINS=https://pilot.example.test \
    npm start

## Identificativi Comune

Gli ID API canonici sono slug, attualmente bologna, castel-bolognese e tuglie.
Per compatibilità sono accettati anche comune:Bologna,
comune:Castel Bolognese e comune:Tuglie. I contenuti seed di Tuglie sono
esplicitamente dimostrativi e non rappresentano condizioni reali.

## CORS locale

Le origin HTTP(S) loopback (localhost, 127.0.0.1, ::1, con qualsiasi porta)
sono abilitate. Origin aggiuntive possono essere elencate esplicitamente in
CORS_ALLOWED_ORIGINS, separate da virgola; il wildcard non è accettato. Le
risposte CORS consentono credenziali perché l'identità anonima usa cookie.

    CORS_ALLOWED_ORIGINS=https://pilot.example npm run dev

## Persistenza e identita' anonima

La versione 0.6 usa `node:sqlite`, disponibile in Node 24, con foreign key,
WAL, timeout sui lock e migrazione iniziale registrata in
`schema_migrations`. Lo stato del pilot e' salvato atomicamente in uno snapshot
JSON versionato; la normalizzazione in tabelle di dominio resta un passo
successivo alla validazione del pilot.

Alla prima richiesta API il server emette `mp_anon`, un identificativo opaco
firmato HMAC con `HttpOnly`, `SameSite=Lax`, `Path=/` e durata annuale. In
produzione viene aggiunto `Secure`. I valori `userId` eventualmente inviati da
client precedenti sono ignorati. Il client Flutter Web abilita le richieste con
credenziali; staging deve servire app e API nello stesso sito per evitare le
limitazioni dei cookie di terze parti.

`DELETE /v1/session` rimuove voti, previsioni ed esiti associati alla sessione,
anonimizza il collegamento delle proposte già pubblicate e scade il cookie. Il
testo civico moderato resta disponibile senza l'identificativo della sessione.
L'operazione è idempotente ed è collegata al controllo dati della build Flutter
in modalità API.

## Moderazione e limiti del pilot

- Il body JSON deve essere un oggetto ed è limitato a 64 KiB.
- Titolo e descrizione sono limitati rispettivamente a 120 e 1000 caratteri.
- Le motivazioni sono enum note, uniche e al massimo due.
- Le proposte con link, email, numeri di telefono, caratteri di controllo o
  termini abusivi noti vengono rifiutate con `content_rejected`.
- Ogni identità anonima può inviare al massimo tre proposte in un'ora.
- In produzione i voti non approvano una proposta: un moderatore deve inviare
  una decisione `approved` o `rejected` all'endpoint amministrativo protetto.
- La coda operativa è l'elenco `status=pending`; responsabilità, escalation e
  ricorsi devono essere assegnati prima del go-live.

L'identità anonima non sostituisce autenticazione forte o protezioni anti-abuso
distribuite. Prima di esposizione pubblica servono proxy trusted, rate limiting
condiviso, retention/privacy policy e una prova operativa di backup/restore.

Il contratto eseguibile è descritto in openapi.yaml.

## Staging e osservabilità

`Dockerfile` e `compose.staging.yaml` preparano un container non-root, con
filesystem read-only e volumi separati per dati e backup. Il compose collega la
porta a loopback: TLS e accesso pubblico devono passare da un reverse proxy.

    docker compose --env-file staging.env -f compose.staging.yaml up -d --build

Gli endpoint operativi sono:

- `GET /health` per liveness;
- `GET /ready` per readiness dello store;
- `GET /metrics` per metriche Prometheus a cardinalità controllata.

Ogni risposta espone `X-Request-Id`. I log JSON registrano metodo, nome route,
status e durata, ma non path grezzi, query, cookie, token, body o identità. Le
metriche devono restare accessibili solo alla rete di monitoraggio.

Gli script `npm run backup`, `npm run verify-database`,
`npm run rehearse-restore` e `npm run smoke` supportano il runbook operativo.
La prova di restore copia un backup in una directory temporanea, lo apre con lo
store applicativo corrente e rimuove la copia al termine; non sostituisce il
database attivo. Procedura completa, gate e rollback sono in
[`docs/pilot_runbook.md`](../../docs/pilot_runbook.md).

## Contratto di gioco

La versione 0.3 ha aggiunto letture coerenti con `GameRepository` per:

- esiti salvati del turno (`/v1/turns/{turnId}/prediction-results`);
- reputazione corrente e storico comunale;
- insight aggregato, storico e critico per problema.

La risoluzione accetta soltanto la scelta già salvata per lo stesso utente e
salva un esito `correct`, `partial` o `wrong` per la coppia turno/utente.
Reputazione e riepilogo civico sono calcolati dagli esiti salvati. Gli insight
aggregano le previsioni di tutti gli utenti del turno. In produzione conteggio,
distribuzioni e timestamp restano oscurati finché non viene raggiunta
`MIN_AGGREGATE_SAMPLE_SIZE`, pari a 3 per default.

## Fantasy foundation (OpenAPI 0.7.0)

Additive read-only routes under `/v1/fantasy/municipalities/{municipalityId}`:
`/season`, `/cards`, `/matchday`, `/matchdays/{matchdayId}`. Each response
includes UTC `serverTime` and `isDemo`. Catalog cards also carry demo
provenance, price, role, availability and source status. No real source is
certified by these fixtures, including cards marked `verified`.

SQLite schema 2 adds `fantasy_seasons`, `fantasy_cards` and
`fantasy_matchdays` without changing the legacy `app_state` JSON. The calendar
starts on 8 October 2026 UTC and lasts eight weeks. It is seeded once per
municipality; restarting or reaching the end never creates another season.
The single-instance SQLite scope follows the incremental fantasy plan.

`verify-database` accepts legacy schema 1 backups and validates fantasy schema
2 tables and foreign keys. `rehearse-restore` upgrades an isolated copy and
reports the counts of fantasy seasons, cards and matchdays. Readiness includes
the fantasy schema. No personal fantasy data or player writes are introduced
in this increment. Squad commands, scoring and leagues remain subsequent work.

## Fantasy team and authoritative lock (OpenAPI 0.8.0)

The same municipality prefix adds `POST /enrollment`, `GET /team`,
`PUT /team` and `POST /team/confirmation`. Commands take `expectedRevision`
and `matchdayId`. The team update takes starters, captain, predictions and
optional text values in the motivations map; it cannot upload points or change
the roster outside the market. The initial eight-card roster can be chosen
with enrollment and is validated by the server.

The signed anonymous cookie determines ownership; body-supplied identities
are rejected. The session is browser-bound, with no account recovery promise.
Changes to starters or captain invalidate confirmation. Pre-lock prediction
edits remain permitted. Commands fail with `stale_revision`, `matchday_locked`
or `matchday_not_open` (409), invalid fields (400), or absent resources (404).

Schema 3 adds players, per-matchday drafts and unique immutable lock snapshots.
A stopped process reconciles missed locks at restart and on requests. A team
not confirmed before the lock is ineligible for personal points. Reading a new
day never changes old snapshots. `DELETE /v1/session` removes fantasy personal
data and legacy links in one SQLite transaction; failures restore the legacy
in-memory state as well. Roster transfers and scoring are subsequent increments.

## Transactional fantasy market (OpenAPI 0.9.0)

`POST /transfers/quote` takes matchday, revision and outgoing/incoming card IDs.
`POST /transfers/confirmation` takes the quote ID, expected revision and an
idempotency key. Store and reuse the key after a timeout; do not create another
key while the result of the original confirmation is unknown.

The quote lasts five minutes at most and expires at lock. Confirmation checks
card versions, catalog, prices, roles, availability, source, budget and server
time again. Pending sources may be bought; unavailable cards or sources may
not. A successful command changes roster, draft, confirmation, revision and
ledger atomically. The third and each following transfer charges four points.
Retry of an accepted command returns its original response after restart or
lock. Another payload with that key returns `idempotency_conflict`.

Schema 4 adds quotes, transfer receipts and the penalty ledger. Session erasure
removes these personal rows with the player. Backups and readiness include all
market tables. The server team view now includes transfers and day allowances.

## Fantasy reveal, scoring and reflection (OpenAPI 0.10.0)

An authorized pilot moderator publishes an outcome with
`PUT /v1/fantasy/admin/municipalities/{municipalityId}/matchdays/{matchdayId}/outcomes/{cardId}`
and the existing moderation bearer token. The source must match a verified
catalog source, its date must be inside the observation window and publication
waits until that window ends. The version-1 outcome records publication ID,
server time, publisher role and demo provenance. Retries keep the original
record; changes conflict. Extraordinary corrections require a separate procedure.

Player `GET /matchdays/{matchdayId}/reveal` and `/summary` calculate personal
results from the frozen snapshot and transfer ledger. The summary stays
provisional while eligible starter outcomes are pending. Once final, only
reflection can increase its total. Each card result is frozen at its first
reveal; future predictions or formations never change it. Negative totals are
allowed. `cooperativeScore: null` explicitly means unavailable.

`POST /matchdays/{matchdayId}/cards/{cardId}/reflection` takes the expected
revision and one of three structured answers. It requires a previously revealed
eligible starter. The first answer grants one base point using the demo's
captain multiplier and rounding; an identical retry is idempotent. A different
answer conflicts. Shared Dart/Node scoring fixtures cover all 48 combinations.

Schema 5 adds publications, personal reveals, finalizations and reflections.
Session deletion removes personal rows and preserves authorized publications.
No real data is imported by these endpoints or their tests.

For an authorized fixture environment, `npm run publish-fantasy-outcome` reads
`FANTASY_OUTCOME_FILE` (`municipalityId`, `matchdayId`, `cardId`, `outcome`),
`API_BASE_URL` and `MODERATION_ADMIN_TOKEN_FILE`. It prints only publication
metadata, never the bearer token or source content. Do not run it against a
live pilot without the operational authorization required by the runbook.

### Client Flutter fantasy API

Usare `FANTASY_MODE_ENABLED=true`, `FANTASY_DATA_SOURCE=api`,
`PILOT_MUNICIPALITY_ID=tuglie` e `API_BASE_URL` esplicito. Il default resta mock.
Il browser invia cookie con credenziali: il pilot richiede HTTPS same-site
secondo il runbook. Nessun account recuperabile o importazione demo.
Il test Flutter avvia esclusivamente `test/support/fantasy_backend_fixture.mjs`
su loopback e database temporaneo; richiede Node 24 nel PATH.
