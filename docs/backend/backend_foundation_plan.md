# Backend foundation plan

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
  src/server.js        # HTTP API e store in-memory
  test/server.test.js  # test di contratto minimo
  openapi.yaml         # contratto iniziale
  package.json
```

Il servizio espone JSON versionato sotto `/v1`. Lo store in-memory serve solo a bloccare shape, stati e comportamento dei primi endpoint. La fase successiva sostituira' lo store con persistenza reale mantenendo gli stessi endpoint.

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
2. `ApiGameRepository` e `ApiNextProblemsRepository` nel client Flutter, dietro feature flag o configurazione ambiente.
3. Persistenza reale con migrazioni.
4. Identita' utente anonima stabile e poi auth opzionale.
5. Deploy preview e ambiente staging.
6. Move Flutter sotto `apps/flutter_app` quando CI backend e client sono gia' separati.

## Criteri di uscita fase 1

- `npm test` passa in `services/backend`.
- `/health` risponde `ok`.
- Gli endpoint principali restituiscono JSON compatibile con i repository Flutter.
- Il piano e il contratto API sono versionati nel repo.
