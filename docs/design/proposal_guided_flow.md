# Proponi un problema: scelte guidate e pin

La route `/suggest-problem` e lo scope nel parametro `municipality` restano gli
stessi. Il flusso salva subito le risposte sul dispositivo tramite
`ProposalDraftController`, separandole per installazione, ambiente e Comune.

1. **Problema.** Tredici categorie con icona e testo, tre casistiche per categoria
   e «Il mio caso è diverso». Il caso personalizzato richiede una descrizione.
   I soli dettagli contestuali sono numero di lampioni per lampione spento,
   carreggiata/marciapiede/pista ciclabile per buche e giorno/sera/notte per rumore.
2. **Luogo.** Luogo specifico oppure Intero Comune. Il primo consente pin o
   nome testuale; con pin nome, civico e riferimento sono facoltativi. Il secondo
   invia solo `kind` e rimuove il pin, senza cancellare i riferimenti testuali
   della bozza. Il Comune demo e i Comuni senza vista configurata usano il testo.
3. **Riepilogo.** Titolo e descrizione deterministici e modificabili, anteprima
   del punto, confronto con proposte simili e invio esplicito. Le modifiche
   manuali sono conservate separatamente per titolo e descrizione anche tornando
   indietro. «Rigenera testo dalle scelte» sostituisce esplicitamente entrambi.
   Dopo una modifica, «Controlla la proposta» ripete il confronto prima dell’invio.

I testi usano soltanto scelte e dati effettivamente inseriti, senza cause,
durata o gravità presunte. Restano i limiti Unicode, l’avviso non ufficiale,
la conferma delle proposte simili, cooldown, gestione dell’esito incerto e
protezione contro invii duplicati.

## Mappa

`ProposalPointMap` usa `flutter_map`, tile e attribuzione di `AppConfig`,
con attribuzione OpenStreetMap sempre visibile e attribuzione provider quando
configurata. Centri e zoom distinti coprono Tuglie, Bologna, Castel Bolognese,
Milano, Roma, Torino, Napoli, Palermo, Firenze e Genova. Sono inquadrature,
non verifiche di appartenenza amministrativa.

Nessun punto viene preselezionato. Un tocco seleziona o sposta un candidato;
«Usa questo punto» lo conferma nella bozza. Pulsanti con etichette accessibili
spostano la mappa nelle quattro direzioni e cambiano zoom; «Seleziona il centro»
permette la scelta anche con tastiera o screen reader. «Rimuovi pin» rende di
nuovo necessario il nome del luogo, se non si sceglie Intero Comune.

La selezione è ammessa solo sulla tile caricata del punto scelto. La disponibilità
segue l’istanza corrente della tile: rimuoverla blocca nuove selezioni, anche
quando la stessa zona era stata caricata in precedenza. Durante la ricarica
restano bloccati sia il posizionamento sia la conferma del pin; la disponibilità
si ripristina al completamento della nuova immagine. Un test di regressione
copre allontanamento, rimozione delle tile, ritorno con caricamento sospeso e
successivo completamento. Un errore tile
blocca tutte le nuove selezioni e mostra alternativa testuale e ricarica, senza
cancellare le risposte o il pin confermato. Riepilogo, ricevuta e dettaglio mostrano
una mappa non interattiva del punto e le coordinate come testo; senza rete il
testo e il punto già salvato restano leggibili. Non si usano GPS, geocoding,
foto, telemetria aggiuntiva o una mappa aggregata delle proposte.

## Bozze e compatibilità

La bozza v2 include passaggio corrente, categoria, indice della casistica
(−1 per caso personalizzato), dettaglio, descrizione personalizzata, pin
confermato e due flag per le modifiche manuali. Le bozze v1 sono ripristinate
al primo passaggio come caso personalizzato, conservando titolo, descrizione,
luogo e revisione originali. La prima modifica salva il formato v2.

`ProposalLocation` conserva lettura dei record precedenti con luogo testuale
o assente. Le coordinate fanno parte di serializzazione, uguaglianza, payload,
fingerprint, receipt e digest backend; il medesimo intento conserva quindi il
punto anche durante retry, ricostruzione dell’app e recupero tramite lookup.

Distribuzione: prima backend compatibile, poi frontend. Nessuna pubblicazione
è compresa in questo refactor; vedere il
[contratto di invio](../backend/proposal_submission_contract.md).


## Verifiche locali del 31 ottobre 2026

- `flutter test`: **374 test superati**, inclusi backend API reale su SQLite
  temporaneo con Node 24, migrazione v1/v2, ripristino pin, isolamento Comune,
  ledger mock, Unicode, retry, errore tile e comandi tastiera.
- `npm test` in `services/backend`: **92 test superati**.
- `flutter analyze`: **nessun errore o warning**, 142 segnalazioni di livello
  info nel repository; il comando standard termina con codice 1 per tali info.
- `flutter build web --release --no-web-resources-cdn`: compilazione riuscita.
- Chrome headless: **8 percorsi completi** a 390 e 1440 px con API reale e
  SQLite temporaneo. Per ogni larghezza: successo senza tastiera con solo pin,
  risposta persa, 201 malformata e tile in errore con alternativa testuale.
  Nei casi incerti, riapertura della pagina e lookup recuperano il medesimo ID
  e le stesse coordinate senza un secondo POST.

[Evidenze browser e risultati JSON](evidence/guided-proposal/results.json),
[riepilogo mobile](evidence/guided-proposal/summary-390.png) e
[riepilogo desktop](evidence/guided-proposal/summary-1440.png).

Per ripetere il browser usare `tools/verify_guided_proposal_browser.mjs` con
`APP_URL`, `EVIDENCE_DIR` e, se necessario, `PLAYWRIGHT_MODULE` (entrypoint ESM
assoluto di Playwright). Il frontend deve essere compilato con
`NEXT_PROBLEMS_DATA_SOURCE=api`, `API_BASE_URL` del backend isolato e
`MAP_TILE_URL=http://HOST:PORT/tiles/{z}/{x}/{y}.png`: lo script intercetta
`/tiles/` e usa PNG simulate, senza contattare un provider cartografico.
Usare un backend locale con database temporaneo, CORS per l’origine frontend
e cookies non secure solo su loopback. Il test non modifica servizi remoti.

Limiti: browser desktop headless con viewport mobile, tile simulate e controlli
semantici/tastiera automatici; nessuna verifica su dispositivo fisico o con
un lettore di schermo umano. Le viste dei dieci Comuni sono configurate e
testate localmente; il perimetro dei Comuni attivati nel backend resta quello
esistente, con eventuale restrizione al Comune pilot di configurazione.
