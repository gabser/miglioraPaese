# EVO-004 — Prima mappa reale di Tuglie: studio per Flutter

Data: 30 ottobre 2026. Stato: materiali pronti per una prova, funzionalità non implementata.
Approfondimento di [EVO-004](EVO-004-mappa-citta-3d.md); sostituisce per questo
incremento la proposta iniziale di partire dal vettoriale web. Nessun account,
abbonamento, SDK o credenziale aggiunto. Responsabile del futuro pilot da assegnare.

## Raccomandazione e perimetro

Partire da **Tuglie (LE), `flutter_map` 8.3.2 e una mappa raster 2D** con nove
luoghi reali e una lista equivalente. Tuglie è già riconosciuto dalle API locali:
non occorre sostituirlo con Esquilino, che richiederebbe anche una distinzione
nuova fra quartiere e Comune. Il campione contiene municipio, due aree verdi,
santuario, teatro, stazione, menhir, centro polivalente e punto d'acqua.

Per una prova locale supervisionata con poche persone è utilizzabile il servizio
raster pubblico OSM, rispettando integralmente la sua policy. Non costituisce
una quota gratuita garantita per il lancio. Per un pilot pubblico raster propongo
Geoapify Free: quota esplicita, ma richiede un account e una chiave che oggi non
abbiamo creato. Il provider deve essere configurabile.

Rinviare vettoriale ed edifici in rilievo: non servono per selezionare nove punti,
aggiungono motori nativi/WebGL e test di integrazione; non abbiamo verificato
altezze degli edifici di Tuglie. Le geometrie e gli ID preparati restano riusabili
con MapLibre. Nessun GPS, tracciamento, avatar, geocoder o download offline nel V1.

Materiali:

- [Luoghi GeoJSON](data/tuglie-2026-10-30/places.geojson).
- [Confine GeoJSON](data/tuglie-2026-10-30/boundary.geojson).
- [Centro e inquadrature](data/tuglie-2026-10-30/viewport.json).
- [Provenienza, licenza e hash](data/tuglie-2026-10-30/provenance.json).
- [Snapshot minimo delle geometrie sorgenti](data/tuglie-2026-10-30/source-snapshot.json).
- [Checklist multipiattaforma](EVO-004-tuglie-map-checklist.md).

## Repository: evidenze e limiti

Ispezionata la checkout di lavoro, inclusi file non ancora tracciati, con HEAD
`1fad162218e758efa3a556790e42b335a6196959`. Molte modifiche erano già presenti:
questo dossier descrive il worktree, non garantisce il contenuto di `main`.
Non sono stati modificati sorgenti, dipendenze, OpenAPI o migrazioni.
Non risultano file `AGENTS.md` nella checkout; applicate anche le istruzioni
fornite in chat sul CLI Postman. Non occorre Postman per questi soli GET pubblici.

| Tema | Evidenza locale | Conseguenza |
| --- | --- | --- |
| SDK | `.fvmrc`: Flutter 3.47.5; `pubspec.yaml`: Flutter >=3.47.5, Dart >=3.12 <4; SDK FVM presente, metadata cache Flutter 3.47.5 / Dart 3.13.4 | Versione dichiarata e SDK installato distinti; `flutter` non presente sul PATH di questa shell. Nessuna risoluzione di nuove dipendenze eseguita |
| Piattaforme | `.metadata` registra root e web; presente `web/`, assenti `android/` e `ios/` | Web configurato; Android/iOS compatibili in teoria, ancora da generare/configurare e compilare |
| CI | `.github/workflows/flutter.yml`: format, analyze, test, build web release con 3.47.5; `pages.yml`: demo mock con base `/miglioraPaese/` | Pipeline definita, non prova di un'esecuzione riuscita in questa sessione. Nessuna pipeline nativa |
| Dipendenze dirette | `flutter`, `flutter_localizations`, bloc ^8.1.4, flutter_bloc ^8.1.6, equatable ^2.0.5, shared_preferences ^2.2.3, go_router ^14.2.8, http ^1.6.0, provider ^6.1.2, flutter_svg ^2.3.0; dev: flutter_test, flutter_lints ^3.0.0 | Nessuna libreria cartografica o geolocalizzazione dichiarata; `pubspec.lock` già presente. Questi sono vincoli del manifest, non tutte le versioni risolte |
| Comune | `lib/core/models/municipality_catalog.dart`: `comune:Tuglie` ↔ `tuglie`; riconosciuti dalle API anche Bologna e Castel Bolognese | Usare `tuglie` nelle API. Il codice ISTAT `075089` proviene dalla relazione OSM, non dal catalogo applicativo |
| Attivazione | Tuglie assente da `activeCities` e classificato `newMunicipality`, pur supportando API | Non subordinare l'accesso alla futura mappa alla sola home dei Comuni attivi |
| Selezione | `lib/core/preferences/app_prefs.dart`: Comune selezionato; `AppConfig` può fissare `pilotMunicipalityId` | Rispettare il Comune della sessione e l'eventuale pilot, senza forzare Tuglie su tutte le sessioni |
| Problemi | `lib/features/game/domain/problem.dart`: id, key, title, zoneName, status, trendPercent, updatedAt | `zoneName` è testo; nessuna coordinata o confine ricavabile automaticamente |
| Proposte | `SuggestedProblem.location` opzionale; `ProposalLocation`: `municipality` oppure `specific` con label/civic/reference | Nessun campo geografico. Parser Dart e `services/backend/src/domain/proposal-location.js` rifiutano chiavi sconosciute: aggiungere coordinate direttamente romperebbe il contratto |
| Missioni | `lib/features/missions/domain/mission_models.dart`: id, municipalityId, zoneId, placeId opzionale, area testuale, protocollo, finestra; parser richiede `synthetic == true` | `placeId` è identità applicativa, non un ID OSM né una posizione; non dichiarare pronte missioni operative reali |
| Fixture | `services/backend/src/persistence/postgres/mission-repository.js`: `synthetic-cleanliness-tuglie`, area esplicitamente senza ubicazione reale | Non associarla al municipio, al parco o ad altri POI reali |
| Identità dei luoghi | Cooperazione e misurazioni usano già placeId; OpenAPI include luoghi seguiti e identità condivise di osservazioni | Mantenere tali ID; eventuale mapping OSM esplicito e revisionabile, nessuna sostituzione automatica |
| Portabilità del flusso completo | `mission_photo_picker.dart` usa implementazione web; stub nativo genera UnsupportedError | Una mappa nativa funzionante non certifica foto/prenotazione/consegna missione su Android/iOS |

La ricerca di latitude/longitude/coordinates/geometry nei modelli Dart, sorgenti
backend e OpenAPI non ha individuato coordinate geografiche già utilizzabili.
Il dossier EVO-004 esistente contiene una proposta, non un dataset geografico.

### Schermata e navigazione

`BoardPage` su `/board` è già una bacheca filtrabile per categoria, stato e testo;
la home la collega. Introdurre in seguito un ingresso **Mappa / Elenco** dalla
bacheca e da `/next-problems`, con pagina candidata `/map?municipality=tuglie`
(non esiste oggi). Mantenere la bacheca e le tab attuali. Offrire l'ingresso
anche nella dashboard di attivazione di Tuglie; la modalità fantasy usa
`FantasyShellPage` e non la home civica: prevedere un collegamento anche lì.

Il dettaglio luogo mostra soltanto contenuti esplicitamente collegati. Per le
proposte riusare `ProposalRouteContext.detailLocation(id, municipalityId)` e
`/next-problems/:problemId?municipality=tuglie`, senza confonderle con ricevute.
Per missioni usare `/missions/:missionId`, solo con Comune coerente con la
sessione e flag `missionsModeEnabled` attivo; altrimenti spiegare l'indisponibilità.
La rotta missioni attuale non risolve il Comune da query come le proposte.
Per `Problem` non esiste una rotta di dettaglio per ID: nel primo incremento
aprire la bacheca e definire successivamente un filtro/selezione per ID.

## Le due soluzioni Flutter confrontate

Tre livelli indipendenti: **OSM è la banca dati geografica**; OSMF, Geoapify e
OpenFreeMap sono **servizi di distribuzione**; `flutter_map` e `maplibre_gl` sono
**librerie di visualizzazione**. Nessuna libreria include per diritto una fornitura
illimitata di mappe, POI o geocodifica.

| Aspetto | Raster: flutter_map 8.3.2, scelta V1 | Vettoriale: maplibre_gl 0.27.1, evoluzione |
| --- | --- | --- |
| Supporto dichiarato | Web, Android, iOS e desktop | Web, Android, iOS; usare questo package, non confonderlo con l'altro package `maplibre` |
| Licenza | BSD-3-Clause, uso commerciale consentito | BSD-3-Clause; motori e dipendenze conservano le proprie notice |
| Manutenzione | Progetto comunitario Fleaflet; changelog 8.3.2 del 27 agosto 2026, correzioni di gesti/camera | Publisher MapLibre; 0.27.1 pubblicata circa 50 giorni prima della verifica; changelog con fix Kotlin/AGP e crash iOS. Manutenzione visibile, non garanzia di assenza di bug |
| SDK | Dart >=3.6, Flutter >=3.27: vincoli nominalmente compatibili con il progetto | Documentazione corrente: Flutter >=3.29, Dart >=3.7; risoluzione nel progetto ancora da fare |
| Gesti | Drag mouse/touch, rotella, pinch, doppio tap; KeyboardOptions e pulsanti aggiuntivi | Camera e gesture sui tre target, zoom/spostamento mouse e touch; integrazione focus e overlay da collaudare |
| Dipendenze native | Renderer Flutter, senza SDK cartografico nativo o platform view; cache usa anche `path_provider`, quindi esistono componenti di piattaforma transitivi | MapLibre Native su Android/iOS e GL JS sul web, con platform view/HTML; JDK 21, Android API 21+, iOS 13+, browser WebGL2/Safari 15+ secondo README corrente. SPM o CocoaPods su iOS |
| Setup | Internet permission in manifest Android release; HTTPS, CORS web; nessun permesso GPS | Setup/toolchain nativi più ampi; JS/CSS web caricati dal plugin corrente, CSP/CDN da verificare. Non copiare vecchie guide che richiedono sempre modifiche a index.html |
| Aspetto | Immagini già renderizzate: non si possono cambiare singole strade/etichette; marker e confine restano personalizzabili | Stili, layer e feature personalizzabili; GeoJSON separato; estrusione edifici possibile se i dati lo consentono |
| Attribuzione | Widget di attribuzione visibile con link a OSM e al provider richiesto | Conservare attribution delle sorgenti dello stile e del provider, oltre ai POI importati |
| 3D | Non disponibile nel motore raster | Possibile rilievo cartografico, non ricostruzione fotorealistica; altezze e copertura locale non verificate |

Fonti ufficiali, consultate il 30 ottobre 2026:
[package raster](https://pub.dev/packages/flutter_map/versions/8.3.2),
[manifest pubblicato](https://pub.dev/api/packages/flutter_map),
[changelog raster](https://pub.dev/packages/flutter_map/changelog),
[installazione](https://docs.fleaflet.dev/getting-started/installation),
[opzioni gesti](https://pub.dev/documentation/flutter_map/latest/flutter_map/InteractionOptions-class.html),
[flag gesti](https://pub.dev/documentation/flutter_map/latest/flutter_map/InteractiveFlag-class.html),
[cache](https://docs.fleaflet.dev/layers/raster-tile-layer/caching.md),
[package vettoriale](https://pub.dev/packages/maplibre_gl),
[changelog vettoriale](https://pub.dev/packages/maplibre_gl/changelog),
[setup mantenuto dal progetto MapLibre](https://github.com/maplibre/flutter-maplibre-gl/blob/main/website/docs/getting-started.md).
I requisiti pubblicati non sostituiscono build e prove hardware. Nessuna delle
due librerie è stata installata o eseguita nel progetto in questa fase.

## Servizi, condizioni correnti e costo

| Servizio | Uso proposto e condizioni verificate | Limiti e accesso |
| --- | --- | --- |
| OSMF raster, `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Solo prima prova interattiva locale a basso traffico; nessun account/chiave o corrispettivo. Uso commerciale non vietato in sé, soggetto a policy e possibile revoca | Nessuna quota numerica garantita, nessuno SLA. User-Agent identificabile nell'app nativa, Referer valido nel browser, attribuzione visibile, cache secondo header (almeno 7 giorni se non interpretabili), niente prefetch/offline, scraping, no-cache o subdomain sharding. Servizio sostituibile; in caso di blocco mostrare lista, senza aggirarlo |
| Geoapify Free, raster per pilot pubblico | $0, 3.000 crediti/giorno, fino a 5 richieste/s, niente carta; FAQ ammette commerciale e produzione entro limiti/attribuzioni | Account e API key obbligatori. Una tessera = 0,25 crediti, quindi tetto teorico 12.000 tessere/giorno se non si consumano altri servizi. Non equivale a 12.000 sessioni. `Powered by Geoapify` e attribuzione OSM; osservare anche i termini. Nessuna iscrizione fatta |
| OpenFreeMap pubblico, per futura MapLibre | Gratuito anche commerciale, senza account/chiave; sito dichiara nessun limite di visualizzazioni/richieste online | Fornitura as-is, senza SLA, revocabile. Attribuzioni OpenFreeMap, OpenMapTiles, OSM. URL stile `https://tiles.openfreemap.org/styles/liberty` è JSON vettoriale, **non** un URL PNG per TileLayer. Termini del 14 ottobre 2026 vietano raccolta automatizzata salvo offline alle condizioni specifiche; offline escluso dal nostro prototipo |

Per Geoapify: con ipotesi progettuale di 50 tessere non in cache per sessione,
3.000 / (50 × 0,25) = circa **240 sessioni/giorno**; è una stima, non una quota
contrattuale né una misura su Flutter. Pan, zoom, retina e altre API cambiano
il consumo. All'esaurimento non attivare upgrade automatici: mostrare errore/lista
e verificare il comportamento reale dell'account prima di pubblicare.
Il listino API 10 indica $59/mese, 10.000 crediti/giorno; non necessario per V1.
La FAQ corrente è più esplicita sul commerciale dei termini v5 del 2024, che
parlano di limitazioni in produzione: ricontrollare entrambi al lancio.

Fonti:
[policy raster OSMF](https://operations.osmfoundation.org/policies/tiles/),
[termini OSMF](https://osmfoundation.org/wiki/Terms_of_Use),
[prezzi Geoapify](https://www.geoapify.com/pricing/),
[costo crediti](https://www.geoapify.com/pricing-details/),
[API tessere e attribuzioni](https://apidocs.geoapify.com/docs/maps/map-tiles/),
[termini Geoapify](https://www.geoapify.com/terms-and-conditions/),
[OpenFreeMap](https://openfreemap.org/),
[termini OpenFreeMap](https://openfreemap.org/tos/),
[integrazione OpenFreeMap](https://openfreemap.org/quick_start/).

Un solo HEAD alla tessera OSM `15/18031/12397.png` ha risposto HTTP 200 con
`Access-Control-Allow-Origin: *` e header di cache il 30 ottobre. Non è stata
salvata alcuna tessera; questo controllo di rete non dimostra il rendering web.
La prova resta dipendente da Internet. Niente proxy cartografico proprio nel V1.
Un'eventuale chiave client futura è osservabile nel bundle: limitarla secondo
le funzioni del provider, tenerla fuori dal repository e non usarla come segreto
o come controllo delle autorizzazioni ai contenuti applicativi.

## Campione reale e qualità

Centro OSM del Comune: **[18.098125, 40.073821]**, nodo `68530020`, membro
`admin_centre` della relazione `40254`; non è la posizione del municipio.
Confine OSM: bbox **[18.0707304, 40.0616618, 18.1154809, 40.09806]**,
quattro way esterni ricomposti in un Polygon di 322 posizioni inclusa chiusura,
senza semplificazione. È un confine comunitario, non un atto amministrativo.

Inquadratura iniziale proposta del centro/Montegrappa:
**[18.085, 40.065, 18.11, 40.09]**, padding 32 pixel logici, `fitBounds`
dopo il layout; zoom 15 come fallback sul centro. È un riquadro editoriale,
non una nuova geometria comunale. Un comando «Intero Comune» usa il bbox del
confine; zoom inizialmente limitato a 12–19, da regolare con i test.

| Nome esattamente in OSM | Categoria nel campione | ID OSM | Longitudine | Latitudine |
| --- | --- | --- | --- | --- |
| Municipio di Tuglie | municipio | way/381917183 | 18.1017857 | 40.0728851 |
| Parco di Montegrappa | parco | way/320163049 | 18.0954104 | 40.0794993 |
| Piazzale Montegrappa | parco secondo tag OSM | way/741835763 | 18.0930864 | 40.0787013 |
| Santuario della Madonna del Montegrappa | luogo di culto | way/403157109 | 18.0928025 | 40.0784685 |
| Teatro Comunale di Tuglie | teatro | way/616896483 | 18.0914987 | 40.0813249 |
| Tuglie | stazione ferroviaria | node/1765980022 | 18.1045325 | 40.0701288 |
| Menhir di Monteprino | sito archeologico | node/6944584113 | 18.0953782 | 40.0775806 |
| Centro Polivalente San Matteo | struttura sociale | node/11402806155 | 18.0950997 | 40.0725610 |
| Vivi L'Acqua | acqua potabile secondo tag OSM | node/4805885721 | 18.1041614 | 40.0701981 |

Ogni feature conserva nome, tag, ID e versione OSM, aggiornamento della fonte,
URL live e URL della versione, categoria, recupero, licenza, attribuzione e
metodo della coordinata. I quattro nodi mantengono la posizione sorgente;
i cinque way hanno un centroide areale derivato, controllato interno alla
superficie originale. Non sono ingressi, rilievi o coordinate inventate.
Tutti i nove punti risultano dentro il confine ricomposto.

Nessuna visita sul posto o verifica completa presso il Comune: precisione in
metri sconosciuta, accessi/orari/agibilità e permanenza da verificare. Il nome
Piazzale Montegrappa non giustifica da solo una categoria piazza: OSM lo mappa
come parco. Non è stata ricostruita una piazza mancante da un indirizzo; il
campione non pretende completezza. La presenza di un luogo di culto non prova
che sia sempre aperto né autorizza una missione al suo interno.

Fonti dati effettivamente recuperate:
[relazione amministrativa](https://www.openstreetmap.org/relation/40254),
[centro](https://www.openstreetmap.org/node/68530020),
[GET del riquadro locale](https://www.openstreetmap.org/api/0.6/map?bbox=18.085,40.065,18.11,40.09),
[GET del confine completo](https://www.openstreetmap.org/api/0.6/relation/40254/full).
I link dei singoli POI sono nel GeoJSON. Solo OSM è usato come fonte delle
geometrie; nessuna copia da mappe proprietarie.

Lo snapshot conserva solo oggetti selezionati e nodi necessari, senza account
dei contributori, contatti o strade/edifici non pertinenti. Un primo riquadro
esplorativo è stato scartato perché riguardava Seclì; non è incluso nei dati.
Overpass primario ha restituito relazione e bbox; il fallback Kumi è andato in
timeout. Alcuni URL della documentazione non erano accessibili dal lettore web:
usati package/pub.dev, pagine ufficiali accessibili e README upstream, senza
interpretare l'errore del lettore come indisponibilità del servizio cartografico.

## Licenze e separazione dei dati

Campione e confine derivano da OSM e sono distribuiti sotto **ODbL-1.0**, con
`© OpenStreetMap contributors`, link a copyright e licenza nei metadati.
Le condizioni del repository per il codice non sostituiscono questa licenza.
Conservare snapshot e provenienza per rendere disponibile il dato derivato;
prima di combinare e redistribuire banche dati più ampie verificare gli obblighi
di condivisione ODbL, senza assumere che tutto il backend diventi automaticamente
OSM o che ogni combinazione sia esente.
Fonti: [copyright OSM](https://www.openstreetmap.org/copyright) e
[testo ODbL](https://opendatacommons.org/licenses/odbl/1-0/).

| Durante l'uso: dal provider cartografico | Nel nostro backend / campione versionato |
| --- | --- |
| Immagini delle sole tessere necessarie alla vista; nel futuro vettoriale anche stile, tile vettoriali, font/glyph e sprite | Centro e bbox del Comune, eventuale confine leggero, soli luoghi curati con ID, posizione, categoria, fonte, licenza, data e stato di verifica |
| Strade, sagome e nomi già disegnati nella mappa di base; cache client conforme agli header | Missioni, proposte, problemi, finestre, stato, permessi e relazioni per ID; eventuale precisione pubblica distinta dalla posizione operativa |
| Il provider vede richieste, IP e riquadri visitati; non riceve i testi delle proposte o ID utente dal nostro layer | Associazioni esplicite fra placeId applicativo e sourceRef OSM, con revisione e correzioni; nessun tracking GPS |

Non duplicare rete stradale o edifici. Le etichette raster non sono POI
selezionabili automaticamente: i nove marker provengono dal campione separato.
Overpass e OSM Editing API servono all'acquisizione occasionale, **non** a ogni
apertura dell'app. API propria pubblica solo i dati autorizzati: nessuna coordinata
riservata inviata al browser per poi nasconderla con un filtro grafico.

## Minimo modello e contratto da implementare in seguito

Proposta progettuale, non schema già accettato dall'API:

- `GeoPlace`: `id` interno stabile, `municipalityId`, `name` nullable,
  `category`, `geometry: Point` WGS84, `sourceRef` (tipo/ID/versione/URL),
  `retrievedAt`, `license`, `attribution`, `coordinateMethod`, `verificationStatus`.
  Gli ID `osm:way/...` del file sono riferimenti d'importazione, non rimpiazzi
  degli attuali `placeId` operativi.
- `ContentLocation`: `contentType` (mission/proposal/problem), `contentId`,
  `municipalityId`, `placeId` nullable, `geometry` nullable, `origin`,
  `verificationStatus`, `precisionMetres` nullable, `synthetic` esplicito.
  Una posizione può provenire da un luogo curato o da un punto confermato dalla
  persona; evitare due coordinate divergenti senza una fonte di verità.
- Proposta comunale: conservare `location.kind == municipality`, senza pin.
  Proposta specifica testuale o record storico: lista «Posizione non disponibile»
  finché una persona non conferma una georeferenziazione. Non geocodificare
  implicitamente `zoneName`, civico, riferimento o titolo.
- Estendere il contratto con un campo separato opzionale `geolocation` nella
  futura rappresentazione pubblica, aggiornando server, OpenAPI, mapper,
  persistenza e fixture insieme. Non aggiungere nuove chiavi a `location`
  finché entrambi i parser continuano a rifiutarle. Per missioni riusare prima
  `placeId` e un catalogo di luoghi, senza introdurre coordinate nel protocollo.
- Numeri finiti, longitude [-180,180], latitude [-90,90], esattamente due valori;
  GeoJSON `[lon,lat]`, adapter `LatLng(lat,lon)`. Controllo di Comune e confine
  sul server; definire tolleranza e revisione per punti di bordo, senza spostarli
  arbitrariamente. Non usare il confine OSM come certificazione amministrativa.
- Relazioni e visibilità validate lato server; query per Comune con limite e
  filtri. Nove POI si possono restituire in un singolo documento; query per bbox,
  indice geografico/PostGIS e clustering si aggiungono solo se il volume lo richiede.

`content_links` è vuoto in tutte le feature. Per una dimostrazione di selezione
basta aprire la scheda luogo; eventuali scenari di missione simulati devono
vivere in una fixture distinta, con badge «Dimostrazione» e associazioni
esplicitamente dimostrative. Questo campione non attribuisce criticità reali.

## Comportamento verificabile del prototipo

Aprire sul Comune selezionato e rifiutare selezioni incongruenti; solo per Tuglie
è disponibile il campione. Per altri Comuni spiegare l'assenza di dati, senza
mostrare Tuglie sotto un titolo diverso. Reset vista al cambio Comune, eliminare
selezione precedente e ignorare risposte asincrone del Comune precedente.

Trascinamento mouse/touch, zoom rotella/pinch/doppio tap, pulsanti +/− e «Mostra
Comune». Rotazione disattivata nel V1. Pulsanti di spostamento e lista offrono
un'alternativa al trascinamento; non intrappolare lo scroll della pagina.
Click/tap/Invio sul marker o sulla riga selezionano lo stesso ID e aprono una
scheda con nome, categoria, fonte, qualità e soli collegamenti esistenti.
Mobile: scheda inferiore con safe area; desktop: pannello laterale; focus
restituito alla riga/marker alla chiusura. Usare token, AppIcons e componenti
locali; target touch almeno 48 pixel logici, testo ridimensionabile, contrasto
misurato, etichette oltre al colore.

La lista è consultabile anche senza tessere, con lo stesso dataset e filtri,
ordine stabile e nome accessibile «Tuglie, stazione ferroviaria» senza alterare
il nome sorgente. Non limitare per default la lista ai soli punti nello schermo:
una persona deve poter trovare tutti i luoghi senza esplorazione visuale.
Attribuzione OSM e dell'eventuale provider sempre visibile, cliccabile e non
coperta dalla scheda; anche la lista rende accessibili fonti/licenze.

| Stato | Risultato atteso |
| --- | --- |
| POI in caricamento | Indicatore e testo; controlli coerenti; nessun pin fittizio |
| Tessere in caricamento, POI già pronti | Lista e dettagli già utilizzabili |
| Errore tessere / rete / 403 / 429 | Messaggio specifico, retry manuale limitato e lista; nessun loop di richieste o cambio provider occulto |
| Errore API luoghi | Stato distinto dal basemap; retry; eventuale snapshot precedente solo se marcato con data |
| Nessun luogo o nessun risultato dei filtri | Messaggi diversi e azione per azzerare filtri |
| Luoghi reali, nessuna missione/proposta | «Nessun contenuto collegato», conservando la scheda luogo |
| Contenuto senza coordinate | Presente nell'elenco dei contenuti, escluso dai pin senza usare il centro Comune come posizione |
| Deep link non valido / flag disattivo | Dettaglio non disponibile esplicito, senza creare o sostituire contenuti |

## Piano minimo e criteri di passaggio

| Passo | Lavoro futuro | Evidenza richiesta |
| --- | --- | --- |
| 1 | Revisionare campione con una persona locale; confermare provider per ambiente e responsabile | Verifica di municipio, parco e stazione; ingressi se necessari; condizioni ricontrollate; nessun piano attivato implicitamente |
| 2 | Spike separato Flutter raster su web con fixture reale; aggiungere dipendenze solo allora | Risoluzione lockfile, attribuzione, 9 marker e lista, gesti e rete misurati. Spike iniziale può precedere l'estensione delle API |
| 3 | Implementare pagina/ingressi e gestione stato dietro configurazione esplicita | Cambio Comune, focus, mobile/desktop, loading/errore/vuoto, routing e flag coperti dalla checklist |
| 4 | Contratto opzionale, migrazione e repository dei luoghi/associazioni | Dati storici ancora validi, nessuna associazione sintetica implicita, test server e mapper. Solo dopo questo passaggio pin di contenuti realmente georeferenziati |
| 5 | Configurare Android/iOS in una modifica dedicata e completare smoke test | Build release/debug, rete e touch; differenziare mappa e flussi missione con foto ancora da portare |
| 6 | Pilot limitato; valutare vettoriale solo su bisogno concreto | Misure e costi osservati, fonte locale confermata, provider idoneo al pubblico; nessun 3D richiesto per accettare V1 |

Obiettivi iniziali da misurare, **non risultati ottenuti**: nove marker/lista e
prima tessera entro 3 s su rete di prova documentata, selezione/dettaglio entro
200 ms dopo caricamento; nessuna perdita di contenuti durante guasto basemap;
nessun overflow a 375 px e testo 200%. Registrare device, browser, rete, cache
calda/fredda e conteggio richieste in una sessione di 5 minuti; interrompere
la prova in caso di blocco/rate limit del provider. Non eseguire stress test
su infrastruttura pubblica. Eseguire poi analyze/test/build secondo la CI,
oltre ai controlli backend solo quando cambiano contratti o persistenza.

**Pronto:** scelta di Tuglie, nove POI tracciabili, centro/confine, provenienza,
verifica strutturale dei dati e piano. **Manca:** implementazione, conferma sul
posto, risoluzione delle nuove dipendenze, prove browser reali e configurazione
mobile. **Si può avviare senza nuovi costi cartografici o credenziali:** sì per
la piccola prova locale OSM conforme alla policy; il pilot pubblico raster con
Geoapify richiede invece un account/chiave, pur potendo restare nella quota
gratuita. Compatibilità mobile e costo totale del prodotto non sono ancora
certificati; nessun acquisto è necessario per completare questo studio.
