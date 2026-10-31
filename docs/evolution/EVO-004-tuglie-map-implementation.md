# EVO-004 — prova Flutter della mappa di Tuglie

## Avvio locale

Con Flutter 3.47.5 del progetto:

```bash
/Users/gabrieleserra/fvm/versions/3.47.5/bin/flutter pub get
/Users/gabrieleserra/fvm/versions/3.47.5/bin/flutter run -d chrome \
  --dart-define=TUGLIE_MAP_ENABLED=true \
  --dart-define=PILOT_MUNICIPALITY_ID=tuglie
```

Aprire `/map?municipality=tuglie`. Il flag `TUGLIE_MAP_ENABLED` è `false` per default;
ometterlo o impostarlo a `false` disattiva la rotta e gli ingressi. Il pilot
fissa Tuglie senza cambiare gli altri flag. Senza pilot, scegliere Tuglie
nell'onboarding: Tuglie è un Comune nuovo, quindi l'ingresso si trova anche
nella dashboard di attivazione. In modalità fantasy è disponibile nella
pagina Squadra e nella barra laterale desktop.

`MAP_TILE_URL` sostituisce il template delle tessere, per esempio durante
prove locali controllate. Per un provider diverso impostare anche
`MAP_PROVIDER_ATTRIBUTION` e `MAP_PROVIDER_ATTRIBUTION_URL` secondo i suoi
termini. Il default usa
`https://tile.openstreetmap.org/{z}/{x}/{y}.png` **soltanto per la prova locale**.
Il servizio pubblico OSM non offre SLA o quota garantita; la sua
[policy](https://operations.osmfoundation.org/policies/tiles/) richiede
attribuzione, identificazione, Referer web e cache. La pagina non esegue
prefetch né download offline. Sul web il browser gestisce cache e User-Agent;
su Android/iOS `flutter_map` usa la propria cache nativa basata sugli header
HTTP e invia `MiglioraPaeseFantaComune/0.1` come User-Agent. Il comportamento
nativo è ancora da verificare su dispositivo.

I file GeoJSON in `assets/map/tuglie/` sono una copia di runtime del
campione verificato in `docs/evolution/data/tuglie-2026-10-30/`. Il repository
`MapPlacesRepository` è il punto di sostituzione per una fonte HTTP. Lo stato
caricamento/errore/assenza dati, i filtri e la selezione vivono nel controller.
Gli ID `sample:tuglie:*` sono ID applicativi locali e non sostituiscono gli ID
OSM. I nove luoghi non hanno contenuti associati; nessuna missione sintetica
è stata collegata.

## Prossimo incremento backend

Definire un catalogo di luoghi applicativi con coordinate opzionali validate,
mapping OSM esplicito e associazioni tipizzate a missioni, proposte e problemi.
Il server dovrà verificare Comune, visibilità e permessi. Le location comunali
e i contenuti solo testuali resteranno senza pin. Serve una modifica di
contratto e migrazione dedicata: questa prova non cambia `ProposalLocation`,
OpenAPI o database.

## Verifiche e limiti

Comandi di verifica: `python3 docs/evolution/data/tuglie-2026-10-30/verify_sample.py`,
`flutter test test/features/map`, `flutter analyze`, `flutter build web --release`
con il flag e il pilot sopra. Android e iOS non hanno cartelle di progetto:
servono generazione e configurazione, permesso INTERNET Android release e
prove di cache, identificazione, gesti, accessibilità e link. Il photo picker
delle missioni native resta uno stub: la mappa nativa da sola non abilita il
flusso missioni. La qualità delle coordinate e gli accessi ai luoghi richiedono
verifica sul posto.

### Esito della prova del 30 ottobre 2026

- `python3 docs/evolution/data/tuglie-2026-10-30/verify_sample.py`: PASS,
  nove POI, geometrie e hash coerenti. Le copie in `assets/map/tuglie/` hanno
  lo stesso SHA-256 dei due GeoJSON sorgenti.
- `flutter pub get` con Flutter 3.47.5 / Dart 3.13.4: dipendenze risolte,
  `flutter_map` 8.3.2 nel lockfile.
- `flutter analyze --no-fatal-infos`: exit 0, nessun error o warning; 462
  segnalazioni `info` nel worktree già ampiamente modificato. Analisi mirata
  di `lib/features/map` e `test/features/map`: nessuna segnalazione.
- `flutter test test/features/map test/features/game/presentation/board_page_test.dart
  test/features/next_problems/presentation/next_problems_page_test.dart
  test/features/fantasy/presentation/fantasy_flow_test.dart`: 35 test passati,
  inclusa la ricerca senza risultati.
- `flutter build web --release --dart-define=TUGLIE_MAP_ENABLED=true
  --dart-define=PILOT_MUNICIPALITY_ID=tuglie`: build riuscita.
- Chrome 156.0.8078.74 locale sulla build release, 1280×800 e 375×812, con
  `MAP_TILE_URL` puntato a una tessera PNG servita da localhost: verificati
  apertura `/map?municipality=tuglie`, ingresso dalla dashboard, nove marker
  e nove righe, click sulla riga e scheda, attribuzioni con scheda aperta,
  rotella e pan mouse, layout mobile. Una tessera locale non decodificabile
  ha mostrato l'errore tessere lasciando la lista utilizzabile.

Non eseguiti: verifica visuale con tessere OSM live, browser Safari/Edge,
touch e pinch reali, screen reader, build o runtime Android/iOS e flusso
missioni nativo. La prova browser usa risposte cartografiche locali controllate,
senza richieste automatiche al server pubblico OSM.
