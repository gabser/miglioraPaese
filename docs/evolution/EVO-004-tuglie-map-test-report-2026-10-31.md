# EVO-004 — verifica web locale del 31 ottobre 2026

## Esito

**PASS per il perimetro web locale controllato.** I casi P0 M01–M08 del
[piano di test](EVO-004-tuglie-map-test-plan-luna.md) sono coperti dalle prove
indicate sotto. Il difetto responsive M11 del report del 30 ottobre è risolto e
verificato. Questo esito non comprende OSM pubblico, browser secondari,
dispositivi touch, lettore di schermo o runtime nativi.

HEAD `1fad162218e758efa3a556790e42b335a6196959`; worktree già modificato
all'avvio e preservato. Flutter 3.47.5 / Dart 3.13.4; Chrome headless locale.
Nessun deploy e nessuna richiesta a OSM pubblico nei test automatizzati.

## Gate

| Verifica | Esito |
| --- | --- |
| `verify_sample.py` | PASS: hash, nove POI, coordinate, centroidi, confine e viewport |
| `flutter pub get --enforce-lockfile` | exit 0 |
| Test pertinenti mappa, bacheca, proposte e fantasy | **48 PASS**, exit 0 |
| `flutter analyze --no-fatal-infos` | exit 0; 462 `info`, nessun errore o warning; feature mappa senza issue |
| Build web release con mappa e pilot Tuglie | exit 0 |
| Build web release con mappa senza pilot | exit 0 |
| Build web release con `--base-href=/miglioraPaese/` | exit 0 |
| `git diff --check` | exit 0 |

I test non accedono a OSM: i widget usano un provider locale, il browser usa
build e tessere controllate su localhost oppure una porta tessere chiusa.

## Casi P0

| ID | Esito | Evidenza |
| --- | --- | --- |
| M01 | PASS | Flag assente: rotta `/map` reindirizzata; ingressi mappa assenti da home, bacheca, proposte e fantasy a 390 e 1280 px. Test router. |
| M02 | PASS | In Chrome, con pilot e senza pilot dopo ricerca e scelta di Tuglie nell'onboarding: deep link `/#/map?municipality=tuglie`, refresh stabile e pulsante Indietro verso `/#/home`. [Pilot dopo refresh](evidence/evo004-2026-10-31/EVO004-deeplink-after-refresh.png), [senza pilot dopo refresh](evidence/evo004-2026-10-31/EVO004-no-pilot-map-refreshed-cdp.png). |
| M03 | PASS | Mismatch Bologna, query duplicata e Comune invalido non mostrano luoghi; cambio Comune a pagina aperta rimuove mappa e dettaglio. Test router e widget. |
| M04 | PASS | Validatore indipendente del campione; nove marker e nove dati; fit iniziale contiene i nove punti; “Intero Comune” contiene il confine e “Ripristina vista” torna al fit iniziale; confine attivabile e disattivabile. [Vista mobile con tessere locali HTTP 200](evidence/evo004-2026-10-31/EVO004-mobile-375-fixed-final.png). La precisione sul posto resta fuori dal campione. |
| M05 | PASS | Riga e marker aprono stesso ID applicativo e fonte OSM; categoria, metodo delle coordinate, nota qualità e messaggio sui contenuti collegati verificati. Test widget. |
| M06 | PASS | Ricerca senza risultati, cancellazione, selezione reale “Parco” dal menu e ritorno a tutte le categorie aggiornano marker ed elenco. Test widget e controller. |
| M07 | PASS | Dati vuoti, errore e retry distinti nei widget test. Con porta tessere chiusa Chrome mostra il messaggio, i nove luoghi e le attribuzioni: [offline](evidence/evo004-2026-10-31/EVO004-tiles-offline-after-fix.png). I casi [403](evidence/evo004-2026-10-31/EVO004-tiles-403.png) e [429](evidence/evo004-2026-10-31/EVO004-tiles-429.png) sono evidenze del 30 ottobre, conservate qui; non sono stati rieseguiti in questa sessione. |
| M08 | PASS | Il controller ignora la risposta ritardata di Tuglie dopo il cambio Comune e cancella la selezione. Test controller. |

## Casi P1, responsive e limiti

M11 **PASS**: attribuzioni visibili e attivabili nei widget test a 375×812 e
812×375, con testo normale e al 200%. Il filtro categoria non esce dalla
larghezza disponibile. Chrome conferma le [viste verticale](evidence/evo004-2026-10-31/EVO004-mobile-375-fixed-final.png)
e [orizzontale](evidence/evo004-2026-10-31/EVO004-landscape-812-fixed-final.png).

| ID | Esito | Evidenza e limite |
| --- | --- | --- |
| M09 | PASS | Test widget: dashboard di attivazione, bacheca, proposte, Squadra mobile e sidebar desktop aprono `/map?municipality=tuglie`; gate fantasy esistente passa. |
| M10 | PARZIALE | Zoom +/−, drag mouse, rotella, “Intero Comune” e ripristino cambiano la camera nei widget test; rotazione resta zero. Pinch e doppio tap su touch reale non eseguiti. |
| M12 | PARZIALE | Tab e Invio aprono il dettaglio dalla lista; nome semantico del marker verificato nei widget test. Focus visivo e lettore di schermo reale non eseguiti. |
| M13 | PARZIALE | DevTools Chrome sulla build locale: 26 richieste, di cui 13 a `/tiles/{z}/{x}/{y}.png`, senza query o dati utente; nessuna richiesta a GPS, geocoding, Overpass o editing. CanvasKit e Roboto richiedono tre risorse `gstatic.com` del runtime Flutter. Sessione OSM pubblica, Referer e cache non verificati. |
| M14 | NON ESEGUITO | Il campione non contiene associazioni di contenuto e non è disponibile una fixture non sintetica. |
| M15 | PARZIALE | Build con base path `/miglioraPaese/`: Chrome conserva deep link e Comune dopo refresh, Indietro arriva a `/#/home`; [schermata dopo refresh](evidence/evo004-2026-10-31/EVO004-basepath-refreshed.png). Safari e altri browser non eseguiti. |

La validazione su dispositivi touch, con lettore di schermo, con provider OSM
pubblico e su browser secondari resta aperta. L'assenza di cartelle Android/iOS
impedisce una conclusione sui runtime nativi. I casi parziali non sono contati
come PASS integrale.
