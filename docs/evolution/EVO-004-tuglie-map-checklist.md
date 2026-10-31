# EVO-004 — Verifica del campione e del futuro prototipo

30 ottobre 2026. [Dossier e decisioni](EVO-004-tuglie-map-prototype.md).
`[x]` significa eseguito in questa sessione; `[ ]` significa ancora da provare.
La lettura della documentazione non equivale a un test della libreria nell'app.

## Verificato durante lo studio

- [x] Letti catalogo Comuni, modelli, routing, configurazione, manifest SDK e dipendenze.
- [x] Verificato `comune:Tuglie` ↔ `tuglie`, con attivazione attuale `newMunicipality`.
- [x] Confermato che proposte e problemi non hanno coordinate; le missioni hanno placeId ma area testuale e vincolo sintetico.
- [x] Letta la CI web; verificata presenza di `web/` e assenza di `android/` e `ios/`.
- [x] SDK FVM presente: metadata Flutter 3.47.5 / Dart 3.13.4; `flutter` assente dal PATH di questa shell.
- [x] Confrontate soltanto flutter_map e maplibre_gl su documentazione ufficiale, licenze, piattaforme e requisiti.
- [x] Consultate policy OSMF, listino/crediti/termini Geoapify e condizioni OpenFreeMap.
- [x] Recuperati nove luoghi reali e relazione amministrativa di Tuglie via GET pubblici, nessun login.
- [x] Conservati ID/versioni, timestamp della fonte e data di recupero, URL, licenza/attribuzione e note di qualità.
- [x] Verificati offline JSON, hash SHA-256, nomi/versioni rispetto allo snapshot e coordinate nell'ordine lon/lat.
- [x] Verificati centro ufficiale della relazione OSM, chiusura/orientamento del confine, tutti i segmenti originali e assenza di autointersezioni.
- [x] Controllati i nove punti dentro confine e viewport, i quattro nodi invariati e i cinque centroidi dentro le superfici sorgenti.
- [x] Nessun contenuto civico inventato collegato ai luoghi: content_links vuoti.
- [x] Un HEAD OSM ha restituito HTTP 200, CORS `*` e header di cache; nessuna immagine salvata.
- [x] Nessuna modifica al codice dell'app, al manifest, al lockfile o al contratto API; nessun account o abbonamento attivato.

Il controllo dati è ripetibile dalla root del repository, senza rete o Flutter:

```bash
python3 docs/evolution/data/tuglie-2026-10-30/verify_sample.py
```

Il validatore usa solo la libreria standard Python, non modifica file e non
certifica precisione sul posto o disponibilità delle fonti live. Il record
[research-evidence.json](data/tuglie-2026-10-30/research-evidence.json) conserva
metadati della verifica tecnica e header HTTP selezionati; le geometrie sono in
[source-snapshot.json](data/tuglie-2026-10-30/source-snapshot.json).

## Matrice delle piattaforme

| Piattaforma | Supporto documentato delle due librerie | Repository oggi | Test runtime/build mappa svolti |
| --- | --- | --- | --- |
| Web | Sì; raster con immagini Flutter, vettoriale con GL JS/WebGL2 | Configurato, CI analyze/test/build e Pages definite | Nessuno; HEAD HTTP non è un test browser |
| Android | Sì; raster senza SDK mappe nativo, vettoriale con MapLibre Native | Nessuna cartella Android; configurazione da creare | Nessuno; nessuna build APK né emulatore usato |
| iOS | Sì; raster senza SDK mappe nativo, vettoriale con MapLibre Native | Nessuna cartella iOS; configurazione da creare | Nessuno; nessuna build, simulatore o dispositivo usato |

## Dati e integrazione: prima di visualizzare contenuti civici

- [ ] Persona locale conferma municipio/parco/stazione, precisione e accessi necessari; non dedurre ingresso dal centroide.
- [ ] Confrontare manualmente nomi/tag e versioni OSM prima del pilot; gestire elementi rimossi o spostati senza cambiare automaticamente placeId operativi.
- [ ] Scegliere provider per ambiente e ricontrollare termini e quote al momento dell'uso.
- [ ] Creare eventuale account Geoapify soltanto nel lavoro di pilot autorizzato; chiave fuori dal repository, restrizioni e quote verificate.
- [ ] Concordare contratto opzionale geolocation/catalogo luoghi, visibilità pubblica e migrazione prima di inviare nuovi campi alle API esistenti.
- [ ] Record storici e location comunali rimangono validi e consultabili senza pin; non localizzare zone testuali in automatico.
- [ ] placeId applicativo e riferimento OSM distinti, mapping esplicito e controllato.
- [ ] Missioni sintetiche restano in dataset dimostrativo separato; nessun problema inventato attribuito a un POI reale.
- [ ] Coordinate finite e valide, ordine lon/lat corretto nell'API; adapter LatLng lat/lon coperto da una verifica numerica nota.
- [ ] Comune/visibilità/ID controllati dal server; non pubblicare coordinate riservate.

## Web: dopo l'implementazione

- [ ] Aggiunta/rilascio dipendenze risolti con SDK FVM del progetto e lockfile revisionato; niente override Git non necessario.
- [ ] Analyze, test pertinenti e build web release secondo CI; registrare comando, SDK, esito e commit.
- [ ] Chrome/Edge e Safari desktop, più Safari/Chrome mobile web: registrare versioni e device effettivi.
- [ ] Avvio con Tuglie selezionato: fitBounds corretto con pannello aperto/chiuso, nove marker distinti e nove righe.
- [ ] Comuni senza campione: messaggio corretto; nessuna vista di Tuglie sotto altro titolo.
- [ ] Riapertura deep link `/map?municipality=tuglie` e path sotto base Pages `/miglioraPaese/`; refresh e Indietro mantengono contesto.
- [ ] Drag, rotella, trackpad, doppio tap e touch pinch; pulsanti +/−, spostamento e reset; rotazione disabilitata e scroll pagina non bloccato involontariamente.
- [ ] Click/tap/Invio su riga e marker aprono lo stesso ID, scheda con fonte e qualità; chiusura ripristina focus.
- [ ] Link proposta conserva municipality e ID tramite helper esistente; missione rispetta flag e Comune della sessione.
- [ ] Lista disponibile da tastiera e lettore di schermo anche senza tessere; nessun dato accessibile soltanto con hover o colore.
- [ ] Viewport 375 px, desktop e orientamento orizzontale, testo 200%, contrasto e focus visibile; attribuzioni sempre visibili sopra safe area e pannelli.
- [ ] Loading dati e loading tessere distinti; guasto API, guasto provider, assenza dati e filtri vuoti distinti.
- [ ] Simulare offline/403/429 con strumenti locali, senza caricare il servizio pubblico: lista funzionante, retry limitato, nessun polling o fallback occulto.
- [ ] Cambio Comune mentre la risposta precedente è in volo: nessuna contaminazione di punti o selezione.
- [ ] Verificare CORS nel browser, HTTPS, Referer effettivo, cache browser e assenza di header no-cache forzati.
- [ ] Attribuzione OSM con link copyright; eventuale Geoapify e altre fonti non coperte dalla scheda.
- [ ] Nessuna richiesta GPS o geocoding; richieste al provider senza dati di proposte, ID utente o segreti.
- [ ] Sessione umana di 5 minuti: annotare rete/device, richieste, tempi, byte ed errori; nessun test di carico automatico su OSM.

## Android: prerequisiti e prove future

- [ ] Generare/configurare il progetto Android in una modifica dedicata, applicationId corretto e toolchain compatibile con Flutter 3.47.5.
- [ ] Configurare INTERNET nel manifest principale per release; nessun permesso posizione/fotocamera necessario per la sola mappa.
- [ ] Verificare path_provider e cache raster sulla versione risolta: header HTTP, scadenze, invalidazione e directory cache; non trasformare cache in download offline.
- [ ] User-Agent stabile dell'app reale, non generico della libreria; non usare dominio/contatto fittizio.
- [ ] Build debug ed APK release, installazione su emulatore e almeno un dispositivo; registrare versioni Android/ABI/toolchain.
- [ ] Nove punti, touch pan/pinch/tap, pulsanti alternativi, orientamento, safe area, Indietro e ripresa da background.
- [ ] TalkBack, testo grande, lista e focus; attribuzioni visibili anche con scheda aperta.
- [ ] Rete mobile/Wi-Fi e assenza rete: stessi stati e fallback della checklist web.
- [ ] Deep link contenuti rispetta Comune/flag; non dichiarare testato l'intero flusso missione finché il photo picker nativo è ancora stub.

## iOS: prerequisiti e prove future

- [ ] Generare/configurare iOS separatamente, bundle ID e deployment target compatibili con Flutter e dipendenze risolte; verificare Xcode e gestione plugin SPM/CocoaPods.
- [ ] Usare HTTPS senza eccezioni ATS arbitrarie; nessuna richiesta localizzazione per la sola mappa.
- [ ] Compilare per simulatore; build dispositivo e firma richiedono ambiente/provisioning adeguati, non verificati qui. Pubblicazione store fuori perimetro.
- [ ] Verificare cache raster e identificazione HTTP reali anche su iOS, senza presumere equivalenza con il browser.
- [ ] Provare su simulatore e almeno un iPhone: pan/pinch/tap, ruota/orientamento, safe area, ritorno e ciclo background/foreground.
- [ ] VoiceOver, Dynamic Type/testo grande, lista, focus e attribuzioni; nessuna dipendenza esclusiva dai gesti.
- [ ] Errori rete/API/provider distinti e stessi criteri dati/navigazione del web.
- [ ] Flusso missioni con foto dichiarato non portato finché usa lo stub nativo.

Se in futuro si sceglie MapLibre, aggiungere prove specifiche per JDK/AGP,
versioni native iOS, composizione platform view, caricamento JS/CSS/CSP,
WebGL2 disabilitato, consumo GPU/memoria e parità dei layer. La lista deve
restare disponibile quando il motore vettoriale non è utilizzabile.

## Esito corrente

**Dati e piano verificati; mappa non implementata.** La prova raster locale
può partire senza nuove credenziali e senza costo cartografico, alle condizioni
OSMF. Un pilot pubblico raster su Geoapify richiede account/chiave e controllo
della quota, anche restando Free. Nessun test applicativo o mobile è stato
spacciato per eseguito; Flutter analyze/test/build non sono stati lanciati per
questa modifica esclusivamente documentale e di dati.
