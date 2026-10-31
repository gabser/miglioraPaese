# Integrazione civica e Giornata — 31 ottobre 2026

Base: `origin/main` 71bd072. Giornata: fc0bd27. Cartelli e mappa: port selettivo da 89ebff4; la PR #41 non è stata incorporata integralmente.

## Comportamento

- Cartelli comunali in onboarding, home, profilo e squadra.
- Mappa di Tuglie con nove luoghi OpenStreetMap, ricerca, filtri, elenco, dettaglio, confine e attribuzione. I luoghi non diventano problemi o missioni inventati.
- Home di Tuglie in attivazione; accessi a tabellone e mappa. Mappa accessibile anche dal tabellone, dalle proposte e dalla squadra.
- Conservati `restartDemo`, `canRestartDemo`, `hasPreviousDemo`, recupero della partita precedente, testi italiani di main e test del blocco formazione dopo rollback dell’orologio.
- Giornata mantiene i riepiloghi e le spiegazioni del branch fc0bd27.
- Il backend resta quello di main. Account, missioni, misurazioni, cooperazione e ulteriori riscritture della PR #41 sono fuori da questo port. Un eventuale collegamento a missione mostra che la funzione non è disponibile.

## Configurazione

Flutter 3.47.5 per qualità, staging e Pages. Pubblicazione da main con:

```sh
flutter build web --release --base-href /miglioraPaese/ \
  --dart-define=FANTASY_MODE_ENABLED=false \
  --dart-define=TUGLIE_MAP_ENABLED=true \
  --dart-define=PILOT_MUNICIPALITY_ID=tuglie
```

Mappa disabilitata per default. `MAP_TILE_URL`, `MAP_PROVIDER_ATTRIBUTION` e `MAP_PROVIDER_ATTRIBUTION_URL` permettono un provider alternativo. Fonte e licenza del campione sono in `data/tuglie-2026-10-30/provenance.json`.

## Verifica

Suite Flutter completa, analisi, formato, 90 test backend e build release con configurazione Pages. I test mappa verificano anche flag spento, Comune diverso, query duplicate, errori delle tessere e navigazione. Le suite responsive conservate verificano testo fino al 400%. Questa base backend non usa PostgreSQL e non richiede `TEST_DATABASE_URL`.
