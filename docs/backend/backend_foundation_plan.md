# Backend foundation plan

## Stato aggiornato (16 luglio 2026)

La fase 1 locale è completata come scaffold contrattuale: avvio reale,
validazione, CORS loopback, OpenAPI 0.2.0 e test di contratto. `UC-02.2`--
`UC-02.4` hanno aggiunto letture e scritture PostgreSQL opt-in con pool, seed,
mapper, transazioni e retry idempotenti verificati anche in concorrenza; lo
store memory resta un adapter esplicito per test e demo. Il primo consumer HTTP è
`ApiNextProblemsRepository`; `GameRepository` resta mock finché risultati,
reputazione e insight non avranno contratti server completi.

Lo scaffold non è un servizio pubblico: `userId` è controllato dal client e
mancano autenticazione, moderazione, rate limiting e cancellazione remota.

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

## Architettura corrente

```text
services/backend/
  src/application/     # casi d'uso
  src/config/          # configurazione ambiente validata
  src/domain/          # enum, factory ed errori condivisi
  src/http/            # routing e trasporto JSON
  src/infrastructure/  # adapter MemoryStore esplicito
  src/persistence/     # migrazioni, seed, pool, mapper e adapter PostgreSQL
  src/server.js        # composition root e avvio
  test/                # test di contratto, regressione e integrazione reale
  openapi.yaml         # contratto HTTP eseguibile
  package.json
```

Il servizio espone JSON versionato sotto `/v1`. `DATA_STORE=memory` e
`DATA_STORE=postgres` selezionano esplicitamente l'adapter; una configurazione
PostgreSQL assente o invalida blocca l'avvio. Letture e scritture persistenti
mantengono gli stessi endpoint e response shape senza fallback in-memory.

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

1. Fondazione backend in-memory e contratto OpenAPI.
2. `ApiNextProblemsRepository` nel client Flutter dietro configurazione ambiente; `ApiGameRepository` solo dopo il completamento del contratto di gioco.
3. Persistenza reale con migrazioni.
4. Identita' utente anonima stabile e poi auth opzionale.
5. Deploy preview e ambiente staging.
6. Move Flutter sotto `apps/flutter_app` quando CI backend e client sono gia' separati.

L'esecuzione dettagliata delle fasi successive allo scaffold e' registrata nel
[backend productization plan](backend_productization_plan.md), organizzato in
work package avviabili con Ultracode.
Le scelte accettate, i rinvii e il confine prima dell'avvio sono riassunti nel
[registro decisioni backend](backend_decision_register.md).

## Criteri di uscita fase 1

- `npm test` passa in `services/backend`.
- `/health` risponde `ok`.
- Gli endpoint principali restituiscono JSON compatibile con i repository Flutter.
- Il piano e il contratto API sono versionati nel repo.

## Criteri per iniziare la fase pubblica del backend

- identità anonima emessa e verificata dal server;
- persistenza con migrazioni, vincoli, backup e cancellazione;
- moderazione dei testi e protezioni anti-abuso;
- contratto completo per risultati, reputazione e insight;
- staging, osservabilità e test end-to-end;
- privacy policy coerente con i dati remoti.
