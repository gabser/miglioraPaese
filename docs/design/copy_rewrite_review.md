# Revisione dei testi di Fanta Comune

Base verificata: `origin/main`, commit `804fbedb6a4dde20e97107d5f755efa6322a3d03` (PR 39, inclusa nuova demo e recupero). Checkout isolato: `/Users/gabrieleserra/.codex/worktrees/riscrittura-testi/miglioraPaese`. Il checkout originale, con le sue modifiche locali, è rimasto intatto. La verifica descritta qui precede la PR. Apertura, review e merge sono gestiti separatamente su GitHub.

## Testi revisionati

| Area | Revisione |
| --- | --- |
| Avvio, benvenuto, introduzione e Comune | Azioni dirette, italiano parlato, eliminati bootstrap, mock, gergo e rassicurazioni ripetute. |
| Inizio, gioco individuale e tabellone | Distinte previsione e voto; caricamenti, stati vuoti, andamento, esiti e riepiloghi più concreti. |
| Squadra, formazione e capitano | Spiegati 8 carte, 5 titolari, 3 riserve, conferma prima del blocco e capitano ×1,5 sui punti base. Stato salvato distinto dal comando di conferma. |
| Giornata, mercato e risultati | Conservati scadenze, osservazione, previsioni facoltative, penalità, bonus e requisiti per i punti. Salvataggio incerto distinto da blocco per scadenza. |
| Nuova demo e recupero | Spiegati squadra iniziale, scelte aperte, archivio sul dispositivo e dati conservati: squadra, formazione, previsioni, motivazioni, trasferimenti, esiti e punti. Il recupero conserva orari e blocchi; conserva anche la partita che si lascia. Comune e proposte restano. |
| Leghe e classifiche | Eliminati lock, rehearsal e server dal copy introduttivo. Conservati soglia di 3 competitori online, spettatori dopo il primo blocco, inviti entro 24 ore, effetti di uscita e revoca. |
| Proposte, bozza e invio | Conservati limiti 120/1000/120/20/200 caratteri, cinque minuti in demo per Comune, salvataggio locale e verifica dell’invio incerto. Invio, voto e conferma della formazione restano azioni diverse. |
| Stati della proposta | `pending`: «Raccolta voti»; `approved`: «Nel gioco»; `rejected`: «Non accolta». Nessun rinvio o approvazione umana suggerita dalle etichette. Le regole effettive restituite dal servizio restano disponibili. |
| Ricevuta e dettaglio | Ricevuta locale leggibile offline: fotografa l’invio. Il dettaglio rilegge lo stato dalla demo o dal servizio e può essere aggiornato. Non si promette il recupero su un altro dispositivo. |
| Profilo e privacy | Italiano semplice; corretto il vecchio testo che prometteva l’azzeramento al riavvio. Specificati dati locali e online eliminati, proposte pubblicate conservate senza collegamento alla sessione, archiviazione delle leghe create e revoca degli inviti. |
| Dati di esempio e accessibilità | Riscritti descrizioni e fonti demo, tooltip, annunci e descrizioni per lettori di schermo. Nomi del catalogo, contenuti degli utenti e payload esistenti non riscritti. |
| Come funziona | Spiegati carte, tabellone, turno, formazione, capitano, punti e classifica; distinti gioco con squadra, previsioni individuali e voti alle proposte. |

Il [registro dei testi](copy_rewrite_changes.json) inventaria i letterali nel codice, compresi catalogo e diagnostica, con file, riga e indicazione di conservazione o riscrittura. Le espressioni interpolate complesse possono essere rappresentate per segmenti. Etichette già semplici e precise sono conservate.

Le etichette ricorrenti condividono le costanti già esistenti in `VenialCopy`: annullamento, conferma della formazione, blocco, salvataggio, nuova demo, recupero e stati delle proposte. Nessun nuovo sistema di traduzione. Le modifiche a repository e dominio riguardano messaggi ed etichette; API, enum serializzati, regole, punteggi e persistenza restano invariati. Le fixture nuove hanno il copy aggiornato; contenuti già salvati o ricevuti dal servizio non vengono migrati né riscritti.

## Controlli eseguiti

- Base: **317 test passati**; `flutter analyze`: **153 segnalazioni preesistenti**, tutte di livello info.
- Finale: **331 test passati**. Conservate le verifiche di comportamento originali; aggiornate aspettative, scorrimento verso i controlli e attesa della scomparsa degli avvisi temporanei.
- `dart format --set-exit-if-changed .`: 177 file controllati, nessuna modifica richiesta; `git diff --check` senza problemi.
- Build web release riuscito anche dopo le correzioni della review.
- `flutter analyze`: **153 info**, stesso insieme di messaggi, file e quantità della base (le righe si spostano). Nessuna nuova segnalazione.
- Schermate verificate a **320, 390, 720 e 1440 px al 200%**; mobile **320 e 390 px al 400%**. Conservati anche i controlli esistenti a 899, 900 e 1120 px.
- Matrice di percorsi: avvio, introduzione, scelta iniziale, inizio, previsioni, tabellone, classifica, profilo, squadra, giornata, mercato, leghe, proposte, modulo, ricevuta senza dati, privacy e regole. Controllati inizio e fondo delle pagine, entrambe le modalità.
- Conferma, formazione bloccata, risultati, nuova demo, recupero con previsioni e punti conservati e cancellazione locale esercitati nella matrice responsiva. I test esistenti verificano inoltre errori di salvataggio, controlli disabilitati, invio incerto, ricevuta non salvata, perdita della sessione, dettaglio aggiornato, bozze e cancellazione online fallita senza perdita delle preferenze.
- **138 schermate di percorsi e 24 di stati** acquisite con Roboto e icone Material reali; campioni conservati in [copy-review-screens](copy-review-screens). Controllo visivo dei campioni e controllo automatico degli overflow di tutta la matrice.
- Correzioni di impaginazione limitate ai testi: etichette delle carte a capo, titoli non troncati, ruoli e fonti leggibili, righe della classifica verticali con testo oltre il 200%. Nessun ridisegno delle schermate.

Evidenze in [copy-review-checks](copy-review-checks). Le prove online usano repository e trasporti simulati: nessun invio a un servizio reale, nessuna cancellazione di dati reali. Il controllo dei layout non sostituisce una sessione con un lettore di schermo reale.

Riproduzione:

```bash
flutter analyze
flutter test
# Facoltativo: screenshot con i font presenti nell’SDK Flutter.
COPY_FONT_DIR="$FLUTTER_SDK/bin/cache/artifacts/material_fonts" \
COPY_SCREENSHOT_DIR=/tmp/fanta-comune-copy-screens \
flutter test test/copy_responsive_test.dart
```

## Review prima della PR

La review del diff ha verificato che logica di gioco, payload e persistenza restino invariati. Corrette le etichette dell’avvio: il comando va alla pagina iniziale e il reset elimina i dati locali. Le risposte del turno mantenute soltanto in memoria sono ora indicate come scelte, senza promettere un salvataggio persistente. Nessun altro problema bloccante rilevato.
