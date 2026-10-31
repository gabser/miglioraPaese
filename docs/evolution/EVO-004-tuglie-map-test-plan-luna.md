# EVO-004 — piano di test per Luna

## Obiettivo e perimetro

Validare la mappa di Tuglie **integrata nell'app Flutter web**, con `flutter_map`
8.3.2, nove luoghi GeoJSON e lista equivalente. Questa è una campagna di test:
Luna registra difetti riproducibili e non modifica codice, dati, lockfile o
contratti backend durante l'esecuzione del piano.

Usare [l'implementazione](EVO-004-tuglie-map-implementation.md) come baseline.
La [checklist di ricerca](EVO-004-tuglie-map-checklist.md) conserva anche voci
scritte prima dell'implementazione: non trattarle come risultati aggiornati.
Il worktree contiene molte modifiche preesistenti. Registrare HEAD, `git status
--short`, Flutter/Dart, browser, sistema operativo e ora prima di iniziare;
preservare tutti i file esistenti.

## Ambienti e dati controllati

1. **Automazione e browser principale:** Flutter 3.47.5 della cartella FVM,
   Chrome desktop, viewport 1280×800 e 375×812. Eseguire i casi cartografici
   ripetibili con tessere PNG fornite da un server **localhost**, dalla stessa
   origine della build web. Preparare risposte locali 200, 403 e 429 e un caso
   di connessione assente. Non usare la rete OSM pubblica nei test automatici.
2. **Controllo manuale OSM, solo dopo i casi locali:** una breve sessione umana
   interattiva con il provider predefinito, se la rete lo permette. Verificare
   Referer, cache e attribuzione con DevTools. Non usare script che spostano o
   zoomano la mappa pubblica, prefetch, download offline o test di carico.
3. **Browser secondari:** Safari desktop e, se disponibili, Chrome/Safari mobile
   su dispositivo reale. Registrare ciò che è stato davvero eseguito. Il solo
   viewport emulato non prova pinch, touch o lettore di schermo.
4. **Native:** Android/iOS fuori dalla campagna eseguibile corrente: mancano le
   cartelle di progetto. Registrare i prerequisiti, senza generarle in questo
   test e senza dichiarare funzionante il flusso missioni con photo picker stub.

Per i test locali usare `TUGLIE_MAP_ENABLED=true` e
`PILOT_MUNICIPALITY_ID=tuglie`. Per la campagna senza pilot scegliere Tuglie
in onboarding. Nel browser l'URL Flutter usa normalmente il frammento
`/#/map?municipality=tuglie`; usare la rotta applicativa `/map` nei test
`GoRouter`. Il template `MAP_TILE_URL` può puntare a
`http://127.0.0.1:8765/tiles/{z}/{x}/{y}.png` se la build web e il server
di tessere usano la porta 8765; impostare anche le variabili di attribuzione
del provider locale. Non salvare credenziali, non creare account.

## Gate automatico iniziale

Eseguire dalla root, salvando comando, exit code e output essenziale:

```bash
python3 docs/evolution/data/tuglie-2026-10-30/verify_sample.py
/Users/gabrieleserra/fvm/versions/3.47.5/bin/flutter pub get --enforce-lockfile
/Users/gabrieleserra/fvm/versions/3.47.5/bin/flutter test test/features/map \
  test/features/game/presentation/board_page_test.dart \
  test/features/next_problems/presentation/next_problems_page_test.dart \
  test/features/fantasy/presentation/fantasy_flow_test.dart
/Users/gabrieleserra/fvm/versions/3.47.5/bin/flutter analyze --no-fatal-infos
/Users/gabrieleserra/fvm/versions/3.47.5/bin/flutter build web --release \
  --dart-define=TUGLIE_MAP_ENABLED=true \
  --dart-define=PILOT_MUNICIPALITY_ID=tuglie
git diff --check
```

Baseline nota del 30 ottobre 2026: validatore PASS, 35 test pertinenti PASS,
build web PASS; `flutter analyze --no-fatal-infos` exit 0 con 462 messaggi
`info`, senza errori o warning. Luna deve registrare i risultati nuovi, non
copiarli come se fossero stati appena eseguiti. Se il gate fallisce, distinguere
una regressione della mappa da modifiche preesistenti prima di attribuire il
difetto.

## Casi funzionali

| ID | Priorità | Azione | Esito atteso |
| --- | --- | --- | --- |
| M01 | P0 | Avviare senza `TUGLIE_MAP_ENABLED`, aprire `/map?municipality=tuglie` e controllare home, bacheca, proposte e fantasy. | Rotta non accessibile; ingressi mappa assenti; altri flag invariati. |
| M02 | P0 | Attivare il flag con pilot Tuglie; aprire deep link, ricaricare, usare Indietro. Ripetere senza pilot scegliendo `comune:Tuglie`. | URL e titolo indicano Tuglie; rotta funziona in entrambi i profili; Indietro torna al contesto corretto. |
| M03 | P0 | Selezionare Bologna o un Comune senza campione e tentare `/map?municipality=tuglie`; provare query malformata e cambio Comune a pagina aperta. | Nessun luogo di Tuglie sotto un altro Comune; selezione e dati precedenti spariscono. |
| M04 | P0 | Con tessere locali 200, confrontare dati e campione. | Nove marker e nove righe; centro/fit iniziale corretto; confine opzionale e comando “Intero Comune”; ordine lon/lat corretto. |
| M05 | P0 | Selezionare lo stesso luogo da riga e marker, chiudere e riaprire la scheda. | Stesso luogo e ID applicativo; nome, categoria, fonte OSM, metodo e nota qualità; “Nessun contenuto collegato”. |
| M06 | P0 | Cercare una stringa assente, poi cancellarla; scegliere una categoria. | Stato “Nessun luogo corrisponde al filtro”, distinto da assenza dati; marker e righe tornano al reset. |
| M07 | P0 | Simulare errore e risposta vuota con un repository iniettato nei widget test; simulare tessere 403/429 e offline con il server locale nel browser. | Messaggi distinti; retry dati esplicito; con tessere guaste la lista, il dettaglio e le attribuzioni restano utilizzabili; nessun polling. |
| M08 | P0 | Cambiare Comune mentre un repository fittizio ritarda la risposta di Tuglie. | Risposta vecchia ignorata; nessun marker, riga o dettaglio di Tuglie nel nuovo Comune. |
| M09 | P1 | Aprire da dashboard di attivazione, bacheca e proposte; in fantasy da Squadra mobile e sidebar desktop. | Ogni ingresso raggiunge la mappa con Comune coerente; le tab esistenti restano raggiungibili. |
| M10 | P1 | Usare drag mouse, rotella, pulsanti +/−, ripristino e “Intero Comune”; provare pinch e doppio tap soltanto su dispositivo touch reale. | Camera risponde, zoom resta 12–19, reset ripristina il riquadro iniziale, rotazione assente. |
| M11 | P1 | Aprire dettaglio su desktop e mobile; ridimensionare a 375 px, orizzontale e testo 200%. | Nessun overflow; link copyright OSM e attribuzione provider sempre visibili e attivabili. |
| M12 | P1 | Navigare solo da tastiera con Tab/Invio, provare lettore di schermo se disponibile. | Elenco e comandi hanno nomi comprensibili, focus visibile; il dettaglio è raggiungibile senza marker o tessere. Registrare separatamente il risultato del lettore di schermo. |
| M13 | P1 | Ispezionare richieste DevTools durante la prova locale e nella breve sessione OSM manuale. | Nessuna richiesta GPS, geocoding, Overpass o Editing API; nessun ID utente/proposta/segreto nell'URL tessere; per OSM Referer valido e nessun header no-cache forzato. |
| M14 | P2 | Rivedere l'instradamento delle associazioni tipizzate e, se è disponibile un harness temporaneo, provarle con fixture non sintetiche. | Proposta usa ID e Comune nella rotta esistente; missione rispetta flag e Comune; problema apre la bacheca. Il campione reale resta senza associazioni. Senza fixture segnare `NON ESEGUITO`. |
| M15 | P2 | Provare refresh e deep link sotto base path `/miglioraPaese/`, Safari/Edge disponibili. | Nessun 404 o perdita del contesto; annotare browser e versione effettivi. |

## Criteri di chiusura e report di Luna

La campagna web è **passata** quando M01–M08 sono verdi, nessun P1 eseguito
presenta un difetto bloccante, il gate automatico passa e ogni limite è
esplicitato. Un test non eseguito è `NON ESEGUITO`, mai `PASS`.

Consegnare un report con: ambiente e HEAD; tabella `ID | PASS/FAIL/NON
ESEGUITO | evidenza | difetto`; comandi ed exit code; screenshot desktop e
375 px; log del server locale per 200/403/429; eventuale HAR **redatto** della
sessione OSM manuale; elenco dei bug con passi, risultato atteso/reale e
severità. Concludere con rischi residui e decisione motivata sul prossimo
passo. Nessun deploy o pubblicazione remota.
