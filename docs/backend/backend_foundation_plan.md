# Backend foundation plan

## Stato aggiornato (21 agosto 2026)

La fase 1 locale è completata come scaffold contrattuale: avvio reale,
validazione, CORS loopback, OpenAPI 0.6.0 e test di contratto.
`ApiNextProblemsRepository` e `ApiGameRepository` sono consumer HTTP opt-in
attivabili separatamente tramite configurazione ambiente. Il repository di
gioco copre progressivamente attivazione, turno, problemi, previsioni, esiti,
reputazione, insight e classifica; reflection resta locale e la mutazione del
segnale è rifiutata finché manca il relativo endpoint.

Il pilot dispone ora di persistenza SQLite con migrazione, identità anonima
firmata server-side, moderazione automatica e umana, limite locale degli invii,
container di staging, cancellazione della sessione, backup verificabile,
rehearsal di restore isolato, readiness, metriche e log strutturati. Non è
ancora un servizio pubblico: mancano provider e Comune approvati, rate limiting
distribuito, policy privacy completa e prova operativa del runbook sul provider.

## Decisione

Il backend nasce nello stesso repository del client Flutter, dentro `services/backend`.
In questa PR non spostiamo ancora il progetto Flutter sotto `apps/flutter_app`: il beneficio del move e' reale, ma il rischio di churn su asset, CI e tooling e' piu' alto del valore immediato. La prima priorita' e' fissare contratti API stabili e un servizio eseguibile.

## Obiettivo

Sostituire progressivamente i repository mock Flutter con repository HTTP senza cambiare UX, routing o flussi gia' validati.

## Scope fase 1

- Creare un backend HTTP zero-dependency per sviluppo locale e test.
- Versionare un contratto OpenAPI iniziale.
- Coprire il primo dominio reale:
  - stato attivazione Comune
  - turno corrente
  - problemi del turno
  - previsioni utente
  - prossimi problemi proposti
  - voti sulle proposte
  - riepilogo loop civico
- Aggiungere CI dedicata al backend.

## Scope escluso dalla fase 1

- Autenticazione reale.
- Database persistente.
- Migrazione Flutter a `apps/flutter_app`.
- Deploy cloud.
- Pannello admin Comune.

## Architettura prevista

```text
services/backend/
  src/server.js        # HTTP API e store di dominio
  src/persistence.js   # SQLite e migrazioni
  src/identity.js      # sessione anonima firmata
  src/moderation.js    # policy automatica iniziale
  src/observability.js # request ID, metriche e log strutturati
  scripts/             # backup, verifica SQLite e smoke staging
  test/                # contratto e riavvio persistente
  openapi.yaml         # contratto iniziale
  package.json
```

Il servizio espone JSON versionato sotto `/v1`. In sviluppo può restare
in-memory; con `DATABASE_PATH` salva atomicamente uno snapshot versionato su
SQLite mantenendo gli stessi endpoint.

## Contratti frontend da rispettare

I primi client HTTP dovranno implementare:

- `GameRepository`
- `NextProblemsRepository`

I nomi enum restano allineati al Flutter:

- `PredictionChoice`: `improve`, `stable`, `worsen`
- `HypothesisConfidence`: `gutFeeling`, `considered`, `convinced`
- `VoteChoice`: `none`, `up`, `down`
- `ProblemKey`: `lighting`, `potholes`, `waste`, `cleanliness`, `green`, `signage`, `transport`, `parking`, `decor`, `noise`, `safety`, `construction`, `queues`

## Roadmap

1. Completato: fondazione backend in-memory e contratto OpenAPI.
2. Completato: repository HTTP Flutter dietro configurazione ambiente.
3. Completato per il pilot: persistenza SQLite con migrazione iniziale.
4. Completato per il pilot: identita' anonima server-side, filtro contenuti e
   limite locale degli invii; auth opzionale resta successiva.
5. Completato nel repository: candidato staging, backup, smoke e osservabilità;
   deploy e pilot reale richiedono provider e Comune approvati.
6. Move Flutter sotto `apps/flutter_app` quando CI backend e client sono gia' separati.

## Criteri di uscita fase 1

- `npm test` passa in `services/backend`.
- `/health` risponde `ok` e `/ready` verifica lo store.
- Gli endpoint principali restituiscono JSON compatibile con i repository Flutter.
- Il piano e il contratto API sono versionati nel repo.

## Criteri per iniziare la fase pubblica del backend

- completato: identità anonima emessa e verificata dal server;
- parziale: persistenza con migrazioni, backup verificabile, cancellazione della
  sessione e rehearsal isolato; la prova di ripristino sul provider resta aperta;
- parziale: filtro testi, revisione umana e limite locale; servono protezioni
  anti-abuso distribuite;
- contratto remoto per reflection e mutazione del segnale;
- completato: soglia minima configurabile per gli insight aggregati; restano le
  regole privacy complessive;
- deploy staging, alert e smoke end-to-end remoto;
- privacy policy coerente con i dati remoti.
