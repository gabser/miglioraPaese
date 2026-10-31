# EVO-004 — Segnalazioni su mappa e città 3D

- Creazione e aggiornamento: 17 ottobre 2026
- Stato: discovery; implementazione da avviare
- Priorità: richiesta esplicita dell'utente, da ordinare con EVO-001
- Responsabile: da assegnare
- Destinazione: main, per incrementi
- Issue/PR: non create
- Ambito corrente: piano e presentazione. Nessun servizio esterno attivato.

## Obiettivo e comportamento atteso

Le segnalazioni devono essere consultabili e inseribili su una mappa del Comune.
Selezionando un punto si apre il dettaglio con stato, osservazioni e missioni
collegate. Mappa e lista condividono ricerca, filtri e selezione. Il 3D aggiunge
contesto agli stessi luoghi, senza cambiare il significato di una segnalazione.

La richiesta include la ricostruzione delle città oppure il riuso di una mappa
3D già disponibile gratuitamente. Proposta: partire dal riuso, misurare le lacune
del Comune pilota e ricostruire soltanto le aree per cui servono dati migliori.
Il lavoro cartografico non dipende dal lancio del token proprio di
[EVO-001](EVO-001-crypto.md).

## Baseline verificata nel codice locale

`lib/features/next_problems/domain/proposal_location.dart` e
`services/backend/src/domain/proposal-location.js` rappresentano il luogo con
tipo, etichetta, civico e riferimento testuale. Il contratto attuale esaminato
non accetta coordinate. Aggiungere soltanto un widget mappa non rende quindi
georeferenziate le proposte esistenti: servono un'estensione del contratto,
persistenza e gestione dei dati storici.

La mappa delle segnalazioni e la vista 3D qui descritte sono sviluppi previsti,
non funzioni attestate dalla demo o dal candidato Sentinelle verificato.

## Soluzione candidata e alternative

Ricerca su fonti ufficiali del 17 ottobre 2026. Le scelte seguenti sono proposte,
non un benchmark già eseguito sul progetto.

| Opzione | Utilizzo proposto | Condizioni e limiti |
| --- | --- | --- |
| MapLibre GL JS + OpenFreeMap | Prima scelta per mappa web e volumi degli edifici | OpenFreeMap dichiara servizio pubblico gratuito, anche commerciale, senza chiave API. Attribuzioni richieste; nessuno SLA. Verificare copertura locale |
| Dati Overture Buildings | Integrazione dove i dati di base non bastano | Dati scaricabili liberamente, edifici e parti adatti a estrusione. Tema Buildings sotto ODbL; altezze e precisione da controllare sul Comune |
| CesiumJS con dati propri/aperti | Alternativa per modelli geospaziali più dettagliati e 3D Tiles | Motore Apache 2.0 gratuito. Dati, preparazione e hosting restano una scelta distinta |
| Cesium ion e contenuti gestiti | Confronto per un'eventuale fase successiva | Il piano gratuito ha quote e condizioni di utilizzo; non assumere che copra il futuro servizio commerciale o un progetto pubblico |
| Ricostruzione dedicata | Solo per lacune che impediscono un caso d'uso prioritario | Richiede dati aperti locali o rilievi autorizzati, lavoro e aggiornamenti; gratuità del software non significa gratuità dell'acquisizione |

L'estrusione delle sagome con altezze produce volumi 2.5D/3D cartografici.
Facciate e tetti fotorealistici richiedono modelli o immagini ulteriori. Non
promettere un gemello digitale accurato di ogni città con i soli dati di base.

## Esperienza della mappa

- Vista iniziale sul Comune scelto, senza richiedere la posizione del dispositivo.
- Filtri per categoria, stato e finestra temporale. Raggruppamento dei punti
  vicini e lista sincronizzata, utilizzabile con tastiera e lettore di schermo.
- Inserimento con punto selezionato o spostato sulla mappa e conferma del luogo.
  L'eventuale ricerca indirizzi dipende da un servizio di geocodifica da scegliere
  separatamente: OpenFreeMap non va considerato un geocoder incluso.
- Segnalazioni relative all'intero Comune e luoghi senza coordinate restano
  riconoscibili nella lista. Nessun pin arbitrario assegnato ai dati storici.
- Colori accompagnati da testo o simboli. Stati distinti per proposta,
  osservazione ricevuta ed esito validato; una posizione non certifica il fatto.
- Vista 2D sempre disponibile. Il 3D è facoltativo, con caricamento su richiesta,
  riduzione dei movimenti e ritorno alla lista quando WebGL o rete non bastano.

Per il piano di interazione è stata consultata la skill locale ui-ux-pro-max:
la ricerca mirata sulla navigazione da tastiera conferma focus visibile e azioni
raggiungibili senza puntatore. La lista equivalente è una scelta progettuale
per rendere i contenuti geografici utilizzabili anche senza esplorazione visuale.

## Dati, API e integrazione

Specificare una posizione WGS84 opzionale con precisione e origine: punto
confermato dalla persona, dato importato oppure risultato da verificare.
Per GeoJSON usare l'ordine `[longitudine, latitudine]`. Definire limiti numerici,
perimetro comunale e casi ai confini prima di modificare OpenAPI. Conservare il
luogo testuale e la distinzione `specific` / `municipality`.

Progettare query per riquadro visibile, filtri e paginazione con limiti di carico.
Il server applica autorizzazioni e visibilità: il client riceve soltanto i punti
pubblicabili. Non distribuire al browser tutte le coordinate riservate per poi
nasconderle graficamente. Separare posizione operativa e precisione pubblica,
con regole per luoghi sensibili e senza tracciare gli spostamenti delle persone.

Riusare ID di proposte, missioni e luoghi per le viste 2D e 3D. Non creare un
secondo archivio di segnalazioni nel renderer. L'associazione a un edificio è
opzionale e correggibile; il punto a terra resta valido anche senza modello 3D.

Per il web Flutter valutare un adapter MapLibre GL JS e la relativa integrazione
con navigazione, focus e ciclo di vita. La scelta del package/interop richiede
una prova sulla versione Flutter effettiva. Il supporto nativo va verificato
separatamente; non aggiungere ora SDK, dipendenze o flag senza implementazione.

## Piano incrementale

Tutte le attività sono da fare. Le fasi indicano dipendenze, non date promesse.

| ID | Attività | Dipende da | Ambiente | Criterio di accettazione | Stato |
| --- | --- | --- | --- | --- | --- |
| GEO-01 | Scelta Comune e censimento dati | — | documentazione | Area pilota definita; fonti, licenze, aggiornamenti e campione di copertura registrati; altezze mancanti quantificate | da fare |
| GEO-02 | Contratto geospaziale e visibilità | GEO-01 | progetto API | ADR, proposta OpenAPI e migrazione retrocompatibile; luoghi testuali e dati riservati gestiti | da fare |
| GEO-03 | Mappa 2D e lista con fixture | GEO-02 | demo locale | Filtri e selezione coerenti; tastiera, permessi negati, rete assente e invio del punto verificati | da fare |
| GEO-04 | Persistenza e query geografiche | GEO-02, GEO-03 | backend locale | Validazione coordinate, autorizzazioni, query limitate, retry e recupero dopo restart verificati | da fare |
| GEO-05 | Prova 3D su dati esistenti | GEO-01, GEO-03 | prototipo locale | Edifici estrusi e punti collegati sul Comune pilota; misure su mobile, altezze sconosciute esplicite e fallback 2D | da fare |
| GEO-06 | Confronto riuso/ricostruzione | GEO-05 | documentazione e campione locale | Lacune concrete elencate; confronto OpenFreeMap, Overture e dati locali; decisione su qualità e costo totale | da fare |
| GEO-07 | Integrazione missioni e segnalazioni | GEO-04, GEO-06 | laboratorio | Stessi dettagli e permessi in 2D/3D; marker selezionabili, bozze e cambio Comune coerenti | da fare |
| GEO-08 | Pilot e verifica costi | GEO-07 | pilot da predisporre | Budget, utenti, durata e soglie definiti; attribuzioni, accessibilità, disponibilità e consumo rilevati | da fare |

Se il riuso soddisfa il pilot, GEO-06 esclude la ricostruzione dedicata dal primo
rilascio. Se mancano altezze, utilizzare sagome 2D oppure volumi dichiaratamente
indicativi; non presentarli come misure. Una futura ricostruzione fotogrammetrica
richiede un sotto-piano con acquisizione, diritti, generazione mesh, riduzione
dei dettagli, pubblicazione in tile e manutenzione.

## Costi e decisione sul servizio gratuito

Obiettivo proposto: nessun abbonamento cartografico nel prototipo e nessuna
attivazione automatica di un piano a pagamento. Questo vincolo non garantisce
costo totale zero: sviluppo, geocodifica eventuale, hosting di dati propri,
banda, storage e manutenzione vanno conteggiati.

OpenFreeMap è il candidato gratuito da provare. Non dipendere da disponibilità
garantita del servizio pubblico: provider sostituibile e lista utilizzabile
durante un guasto. Per un servizio proprio, valutare un estratto comunale e
tile statiche/PMTiles solo dopo aver misurato volume, CORS e richieste parziali.
Non scaricare l'intero pianeta per un pilot e non assumere hosting gratuito
illimitato. Rispettare le condizioni vigenti per uso e download offline.

## Misure e rilascio

Rilevare tempo al primo contenuto, fluidità, memoria, errori GPU/rete, consumo
di dati e corrispondenza fra punti e luoghi, oltre alla riuscita dei task nella
lista accessibile. Dispositivi, campione, soglie e tetto di costo sono da definire
in GEO-01 prima delle verifiche; nessuna misura è stata ancora raccolta.

Rilascio graduale, con configurazione provider esplicita, compatibilità delle
coordinate opzionali e ritorno alla mappa 2D/lista. Le segnalazioni già inviate
restano disponibili se si disattiva il 3D. Conservare versione/provenienza dei
dati cartografici importati e rendere reversibile il loro aggiornamento.

## Decisioni e prossimo risultato

| Data | Tema | Stato |
| --- | --- | --- |
| 2026-10-17 | Segnalazioni su mappa | Requisito esplicito utente |
| 2026-10-17 | Aggiungere città 3D tra gli sviluppi | Richiesta esplicita utente |
| 2026-10-17 | Riusare una soluzione gratuita quando adeguata | Preferenza esplicita utente |
| 2026-10-17 | MapLibre + OpenFreeMap come prima prova | Proposta motivata, da verificare su Comune e Flutter |
| 2026-10-17 | Comune iniziale, responsabile, tempi e budget | Aperti |

Prossimo risultato: scheda GEO-01 su un Comune candidato, con copertura reale
dei dati e configurazione riproducibile del prototipo. Tuglie è un candidato
coerente con il laboratorio Sentinelle; Bologna può servire da confronto. La
copertura 3D di entrambi resta da misurare.

## Fonti ufficiali

- [OpenFreeMap: servizio, uso commerciale, attribuzioni e assenza di SLA](https://openfreemap.org/)
- [Condizioni del servizio OpenFreeMap](https://openfreemap.org/tos/)
- [Integrazione OpenFreeMap](https://openfreemap.org/quick_start/)
- [Esempio MapLibre: edifici in 3D con OpenFreeMap](https://maplibre.org/maplibre-gl-js/docs/examples/display-buildings-in-3d/)
- [Licenza MapLibre GL JS](https://github.com/maplibre/maplibre-gl-js/blob/main/LICENSE.txt)
- [Overture Buildings: contenuti, qualità e licenza](https://docs.overturemaps.org/guides/buildings/)
- [CesiumJS e distinzione dai servizi ion](https://cesium.com/platform/)
- [Cesium ion: piani e condizioni](https://cesium.com/platform/cesium-ion/pricing/)
