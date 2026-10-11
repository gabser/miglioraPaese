# Esperienza del port PR 34: riferimento operativo della fase 0

Data: 11 ottobre 2026. Baseline letta: main `6bc103d`, contratto candidato PR 33 `12d972d`, sorgente PR 34 `f3f4d4f`. Questo documento definisce la direzione di esperienza del piano `port-pr34-main-plan.md`; non attesta screenshot realizzati, test eseguiti, revisione backend conclusa o accettazione prodotto. La revisione della 33 precede ogni implementazione dipendente dal suo contratto.

## Regole osservate e confini di prodotto

Manager civico è il default di `AppConfig.fromEnvironment()` (`FANTASY_MODE_ENABLED=true`). `fromValues()` usa invece false: i test e le fixture devono indicare esplicitamente la modalità. Conservare i profili di build e i due router. Le cinque destinazioni principali fantasy restano Squadra, Giornata, Mercato, Leghe, Profilo. Le proposte sono un percorso secondario raggiungibile dal Mercato e dai collegamenti esistenti; nessuna nuova destinazione principale deriva dall'importazione della 34. Il gioco precedente resta disponibile nel profilo legacy, senza introdurre un selettore di modalità o un'economia comune.

Le regole seguenti provengono da `FantasyGame`, `fantasy_models.dart` e `FantasyManager`, e devono restare riconoscibili nella presentazione:

- Rosa di 8 carte, budget di 100 crediti, almeno 2 carte per ruolo; 5 titolari con almeno una carta per ruolo e capitano tra i titolari.
- Formazione valida e confermata al blocco necessaria per punti personali. Scambio titolare/riserva, cambio capitano e trasferimento richiedono nuova conferma. Modificare previsione o motivazione non annulla la conferma.
- Le cinque previsioni non sono requisito di conferma: una previsione assente non produce la componente previsione. La motivazione è facoltativa, senza punti dedicati.
- Lock alla scadenza `locksAt`, snapshot della formazione; da quel momento formazione, previsioni e mercato non sono modificabili. Il tempo server guida il profilo API; il demo usa il tempo locale controllato.
- I primi due trasferimenti della giornata non hanno penalità; ciascuno successivo costa 4 punti. Mostrare costo e crediti prima di confermare; disponibilità della carta, fonte, budget e composizione della rosa restano vincoli.
- Un risultato personale richiede snapshot eleggibile, carta titolare ed esito verificato pubblicato dopo la finestra di osservazione e la data della fonte. Esiti senza queste condizioni non valgono punti personali.
- Osservazione: Migliora 4, Stabile 1, Peggiora 0. Previsione esatta 4; se previsione o osservato è Stabile ma differiscono, 2; altrimenti 0. Il capitano moltiplica per 1,5 con arrotondamento. Una riflessione ammessa vale 1 prima del moltiplicatore; si invia una sola volta per esito personale. Totale giornata = punti congelati + bonus riflessione − penalità trasferimenti, oppure 0 se non eleggibile.
- Le classifiche locali sono visibili solo con il minimo partecipanti previsto; il profilo API ha operazioni remote proprie. Non inventare membri o posizioni per uno stato vuoto.
- `startNextMatchday` è una transizione esplicita del repository/demo host, non una CTA attualmente offerta al giocatore. Dopo il reveal mostrare soltanto azioni disponibili: leggere fonti, riflettere, consultare Leghe; preparare la nuova giornata solo quando i dati effettivi la rendono disponibile.

Il valore cooperativo locale 68 e la stagione/carte demo sono dati dimostrativi esistenti, da etichettare; `communityScore` nel profilo API è null. Il port non usa quel numero come attività reale del Comune. Un risultato zero durante l'attesa deve essere descritto come provvisorio, non come giornata conclusa.

## Primo accesso e ritorno

| Fase | Cosa vede il giocatore | Azione principale disponibile | Feedback e prossimo passo |
| --- | --- | --- | --- |
| Primo accesso | Benvenuto Manager civico, Comune e indicazione demo/API; onboarding secondo il router corrente | Entrare nella Squadra, scegliere Comune quando richiesto | Comune mantenuto nel contesto; nessuna attività reale dedotta dai dati demo |
| Squadra aperta | Rosa, 5 titolari, capitano, crediti, validità e ora di blocco | Correggere la formazione se invalida, altrimenti Conferma formazione | Conferma solo dopo successo del repository; spiegare che cambi a rosa/capitano richiedono riconferma |
| Formazione confermata | Stato salvato, scadenza, eventuali previsioni mancanti | Aprire Giornata e scegliere le previsioni ancora disponibili | Selezione visibile e salvataggio/errore riconoscibili; motivazione facoltativa; non imporre tutte le previsioni |
| Mercato aperto | Carta ceduta/acquistata, fonte, crediti e penalità del trasferimento | Confrontare e confermare il trasferimento consentito | Successo e formazione da riconfermare; errore mantiene confronto e spiega vincolo |
| Lock | Formazione congelata, eleggibilità, ora di fine osservazione | Consultare formazione e contesto della giornata | Controlli disabilitati con motivo; attesa esplicita, senza invio o reveal artificiale |
| Reveal disponibile | Fonte, data, osservato, previsione congelata, componenti del punteggio e penalità | Leggere l'esito personale e inviare eventuale riflessione | Riflessione confermata; totale aggiornato; non offrire riflessione a carte non eleggibili |
| Ritorno prima del lock | Stato accettato dal repository e eventuale recupero/errore | Continuare le azioni modificabili | Distinguere formazione confermata, riconferma necessaria e previsioni salvate; nessuna promessa di cloud nel demo |
| Ritorno dopo lock/reveal | Snapshot conservato, risultati effettivamente disponibili e loro stato | Consultare fonti, riflettere se ammesso, aprire Leghe | Dire cosa resta in attesa e quale passo è già disponibile; non presentare ogni risultato come nuovo senza evidenza |
| Nuova giornata effettiva | Numero/scadenze attuali, rosa conservata, conferma/previsioni della nuova giornata | Preparare e confermare la formazione corrente | Risultati storici restano separati; nessuna avanzata automatica inventata dal client |

Il benvenuto attuale può portare direttamente a `/squad`: il port non deve promettere una scelta del Comune obbligatoria se il percorso non la esegue. Comune mancante o non mappato deve essere indicato e risolto attraverso l'onboarding previsto, senza una sostituzione silenziosa con un altro Comune. Il pilot mantiene la sua restrizione.

## Matrice schermate e stati

Ogni riga comprende caricamento, vuoto e errore, oltre allo stato pieno. Un dato assente non equivale a zero. Titoli, stato e azione primaria precedono decorazione e metriche secondarie.

| Schermata / modalità | Stati da rappresentare | Dati e lessico | Componenti / comportamento condiviso |
| --- | --- | --- | --- |
| Benvenuto/onboarding | Primo accesso, ritorno, Comune pilot, Comune senza dati | Comune e natura demo/API | Titolo, breve spiegazione, una CTA; errori di contesto espliciti |
| Squadra / default fantasy | Aperta invalida/valida, confermata, modificata, busy, lock, caricamento/errore senza dati | Rosa, titolari, riserve, capitano, crediti | Carte fantasy + gerarchia `FcPanel`; stato con icona/testo; conferma e feedback persistente |
| Giornata / fantasy | Modificabile, previsioni incomplete, lock, attesa, reveal parziale/definitivo, fonte pending/unavailable | Giorno/scadenze, Migliora/Stabile/Peggiora, punti fantasy | Progressione e carte leggibili; fonte separata dal risultato; dettaglio componenti punteggio |
| Mercato / fantasy | Disponibile, credito insufficiente, composizione invalida, fonte/carta indisponibile, penalità extra, lock, errore quota/risposta | Crediti e penalità punti, distinta da budget | Confronto prima dell'azione, costo leggibile, vincolo vicino al controllo; accesso secondario a proposte |
| Leghe / fantasy | Demo, API, minimo non raggiunto, vuoto, errore, operazione in corso, classifica disponibile | Punti fantasy, partecipanti e posizione reali del repository | Stessa scala dei numeri; badge demo; nessuna posizione fittizia; azioni remote solo se supportate |
| Home / legacy | Turno aperto, risultati disponibili, ritorno, Comune senza problemi, errore | Previsioni, esiti, reputazione legacy | Titolo/Comune/stato/CTA prima dei riepiloghi; conservare accessi esistenti |
| Play / legacy | open/calculating/closed, scelta non ancora inviata/già inviata, risultati, errore | Previsione legacy e reputazione | Carta coerente con fantasy; non importare modificabilità fantasy: una carta già giocata non riceve una seconda scelta |
| Board / legacy | Problemi, lista vuota, fonte/stato, filtri, caricamento/errore | Problemi e andamento del Comune, distinta dalle proposte | Filtri conservati al ritorno; vuoto contestuale; nessuna previsione sintetica |
| Classifica / legacy | Dati demo/API disponibili, vuoto, errore | Reputazione del gioco precedente | Non confrontare il valore con Leghe fantasy; stessa gerarchia visiva |
| Profilo/info/privacy / entrambe | Comune, preferenze, reset busy/errore/successo | Modalità e garanzie di persistenza effettive | Azione reset distinta e feedback visibile; mantenere blocco del Comune pilot |
| Lista proposte / entrambe | Pubbliche/proprie, filtri, vuoto, rejected proprio, capabilities mancanti, errore | Voti, stato moderazione, regola di promozione effettiva | Ricerca/filtri e riepilogo; ricevuta raggiungibile anche quando filtri nascondono la proposta |
| Form proposta / entrambe | Bozza/ripristino, categoria/luogo, invalidità, riepilogo, invio busy, esito incerto, cooldown demo/quota API | Luogo specifico o Intero Comune; titolo/descrizione; nessun premio | Errori campi + focus; riepilogo modificabile; similarità consultiva fino a 3 senza blocco per stesso titolo |
| Ricevuta / entrambe | Ricevuta recuperata, lookup in corso/non trovato, scope cambiato, storage corrotto | Snapshot immutabile dell'invio ricevuto | Conferma dell'invio con Comune/data/id disponibili; aprire dettaglio o tornare alla lista con contesto |
| Dettaglio proposta / entrambe | pending/approved/rejected proprio, aggiornamento, errore/non disponibile | Stato live separato dalla ricevuta; promozione secondo backend | Aggiorna esplicito; motivo/identità interni non pubblicati; prossimo passo solo se noto |

Nel profilo API la preparazione del form richiede capabilities e scope della 33. Esito incerto → lookup esplicito con chiave originale; 404 o cambio scope non autorizzano reinvio automatico. Invio ricevuto, moderazione, approvazione ed eventuale ingresso nei problemi del gioco precedente sono passaggi distinti. `syncPromotion` della baseline backend aggiunge problemi legacy, non carte Manager civico: il port non promette ingresso nelle rose fantasy.

## Gerarchia e terminologia comuni

1. Intestazione: Comune e modalità dati, titolo della schermata, fase corrente con scadenza pertinente.
2. Un'azione primaria per lo stato: Conferma formazione, scelta previsione, conferma trasferimento, riflessione o invio. I link a fonti, dettaglio e ritorno restano secondari. Se nessuna azione è disponibile, un testo descrive attesa e prossimo evento noto.
3. Stato dell'operazione vicino al controllo e nel contesto persistente: busy, accettata, errore recuperabile. Una snackbar da sola non spiega al ritorno che cosa è salvato.
4. Dati principali prima dei riepiloghi: carte/titolari, fonte/esito, contenuto proposta; numeri grandi solo con unità e contesto. Sezioni complementari possono andare in colonne su desktop preservando l'ordine di lettura mobile.

| Termine | Significato | Presentazione vietata |
| --- | --- | --- |
| Punti fantasy | Punteggio personale giornata/stagione secondo regole fantasy e penalità | Equivalenza con reputazione legacy o voti delle proposte |
| Crediti | Budget della rosa e prezzi carte | Premio per invio proposta o denaro reale |
| Reputazione | Punteggio/accuratezza/previsioni concluse del gioco precedente; mock corretto 10, parziale 4, altro 0 | Applicare la formula fantasy alla classifica legacy |
| Voti | Sostegno/opposizione alla proposta e ordinamento; promozione secondo regola restituita | Punti personali, approvazione ufficiale, ingresso automatico nel Manager |
| Fonte verificata / in attesa / non disponibile | Qualità/disponibilità dell'evidenza | Usare il verde della fonte come attestazione che la previsione è corretta |
| Invio ricevuto | Backend ha accettato l'invio; ricevuta snapshot | Approvata, presa in carico dal Comune, premiata |
| Approvata | Stato live di moderazione/promozione del backend | Prova di intervento civico compiuto o promessa di carta fantasy |

Base visiva trasferibile della 34: palette navy/blu, superfici chiare, scala di spaziatura 4/8/12/16/20/24/32, raggi 12/18/24, larghezza massima 1180, contenuto stretto 760, sidebar 244, breakpoint 900 e 1120. `foregroundFor` e foreground semantici sono utili per testo piccolo sulle superfici, ma contrasto e uso dei colori vanno verificati nel port. Verde = operazione riuscita o stato positivo esplicitamente nominato; ambra = attesa/vincolo; rosso = errore; blu = azione o informazione neutra. Ogni badge usa anche testo/icona. Non affidare il significato solo al colore.

Tema e `FcPanel`/componenti della 34 si adattano ai chiamanti fantasy già esistenti, non sostituiscono carte, dati e regole fantasy. Gli spostamenti di layout legacy/proposte sono riferimento, da adattare al router e alla shell di main. Escludere la pagina design preview e i dati/infrastruttura PostgreSQL alternativi. Correggere nel port il titolo corrente `Reveal e fonti · demo` che è condiviso anche dal profilo remoto; conservare l'indicazione dati sintetici dove il backend la richiede. Animazioni limitate al feedback, con riduzione movimento e controlli utilizzabili.

## Fixture e riferimenti confrontabili

I seguenti sono requisiti di acquisizione, non screenshot già realizzati. Le fixture riusano `test/features/fantasy/fantasy_test_support.dart`: epoch `2026-10-08T00:00:00Z`, matchday-2, lock +1 giorno, fine osservazione +2 giorni, `buche-centro` e fonte demo. Registrare SHA, profilo, Comune, dataset/seed, UTC del clock, viewport CSS, DPR, browser/versione, scala testo e percorso per ogni cattura. Nessun clock di sistema non controllato per confrontare lock/reveal.

| ID | Preparazione ripetibile | Riferimento richiesto e asserzione |
| --- | --- | --- |
| F01 | Preferenze vuote, fantasy mock esplicito, clock epoch | Benvenuto e Squadra mobile/desktop; prima azione identificabile e dati demo nominati |
| F02 | Clock epoch, rosa iniziale valida; capitano cambiato e poi riconfermato | Squadra prima/dopo conferma, Giornata con previsione salvata; feedback e modifica fino al lock |
| F03 | Stessi dati F02, clock esattamente `day.locksAt` | Squadra e Giornata bloccate; motivazione/mercato disabilitati e tempo attesa leggibile |
| F04 | Formazione confermata prima del lock; clock `observationEndsAt`; esito stable verificato | Reveal, componenti punteggio e riflessione prima/dopo; fonte, previsione congelata ed eleggibilità chiare |
| F05 | Identica giornata ma non confermata; esito pending o unavailable in variante separata | Nessun punto personale falso; non dedurre definitivo da zero; nessuna CTA riflessione non ammessa |
| F06 | Repository controllato: caricamento, lista vuota o errore senza dati | Comune senza dati/giornata non disponibile; nessuna card inventata, azione di riprova solo quando supportata |
| P01 | Invio controllato sul contratto 33, chiave e scope opachi stabili; receipt pending | Form/riepilogo/ricevuta mobile/desktop, poi dettaglio approved via stato live; ricevuta invariata |
| P02 | Intento salvato; POST ha commit ma risposta persa; refresh e lookup | Errore recuperabile → stessa ricevuta; filtro attivo non impedisce accesso; niente secondo invio |
| L01 | Profilo legacy-mock esplicito, stessi Comune e viewport | Home/Play/Board/classifica/profilo e proposte: confronto di titoli, numeri, badge e azioni con F02/F04 |

F01–F06: 390×844 e 1440×900 come confronto principale; verifiche aggiuntive larghezze 320/720/899/900/1120 e testo ingrandito. Il profilo API usa fixture backend controllate (`test/support/fantasy_backend_fixture.mjs` e contratto 33), non il seed locale come prova di dati server. Acquisire P01/P02 in browser isolato con SQLite e cookie reali oltre alle fixture widget. Non trasferire immagini o numeri di test della 34 come evidenza del nuovo port.

Checklist di accettazione per ogni coppia mobile/desktop:

- Comune, giornata, modalità dati e stato sono leggibili senza aprire sezioni secondarie.
- Azione primaria identificabile; conferma e salvataggio non si confondono con lock; vincoli spiegati vicino al controllo.
- Attesa, vuoto, errore e fonte non disponibile hanno testo utile; nessuna metrica segnaposto.
- Punteggio spiegato con eleggibilità, fonte, capitano, bonus e penalità; reputazione e voti restano separati.
- Ordine, tipo dei titoli, spaziature e significati colore coerenti tra fantasy, legacy e proposte.
- Tastiera, focus su errore, nomi accessibili, testo ingrandito, movimento ridotto e assenza overflow verificati; nessuna certificazione dedotta da queste prove.
- Navigazione/ritorno mantiene contesto e filtri, e recupero dopo refresh conserva identità dell'invio.

## Test formativo e dispositivo: gate aperti

Stato iniziale: **non eseguito**. Persone nuove al prodotto e dispositivo rappresentativo non sono stati osservati in questa fase. Test automatici e screenshots non sostituiscono queste prove; l'accettazione prodotto resta aperta finché sono mancanti.

Protocollo proposto: 3–5 persone nuove, sessione individuale di 20–30 minuti, un browser/dispositivo mobile reale e uno desktop, fixture identiche F01–F04. Annotare data, consenso alla raccolta di note, ambiente/versioni e limiti. Il moderatore legge i compiti senza indicare pulsanti o spiegare regole durante il tentativo:

1. «Entra nel gioco del tuo Comune e prepara la squadra per la giornata.» Osservare azione iniziale, differenza rosa/titolari e capitano.
2. «Ora fai una previsione e assicurati che la formazione partecipi.» Osservare conferma, feedback di salvataggio e comprensione delle previsioni facoltative.
3. Portare il clock al lock: «Che cosa puoi fare ora? Quando ti aspetti un risultato?» Osservare differenza conferma/blocco/fine osservazione.
4. Portare il clock al reveal: «Spiega il punteggio di questa carta e il totale. Che cosa puoi fare dopo?» Osservare fonte, moltiplicatore, penalità, riflessione e nessuna promessa di nuova giornata.
5. Riaprire la sessione: «Che cosa è rimasto salvato? C'è qualcosa da completare?» Poi P01: «Questa ricevuta che cosa garantisce? La proposta è già nel Manager?»

Per compito registrare esito autonomo/con aiuto/non completato, tempo osservato, primo tentativo, errore/aspettativa, citazione breve, problema e correzione da verificare. Un blocco che impedisce comprendere o completare il ciclo principale va risolto e ritestato; non usare una media dei tempi per nasconderlo. Raccogliere comprensione/interesse dichiarati senza affermare che il gioco è divertente sulla base di test tecnici.

Sul dispositivo annotare modello, OS, browser, rete e profilo mock/API; provare tap e doppio tap, scroll di carte lunghe, tastiera e focus form, apertura/ritorno, feedback busy, refresh con cookie, lock e reveal. Registrare osservazioni sulla fluidità e limiti; non simulare una prova su hardware reale con un viewport desktop.

Registro da compilare sul commit finale:

| Gate | Esito attuale | Evidenza richiesta | Problema aperto |
| --- | --- | --- | --- |
| Regole/percorso fase 0 | Definiti da lettura codice | Questo documento e riferimenti sotto | Verificare contro eventuali correzioni della 33 e nuovo SHA main |
| Sezione rappresentativa shell + Squadra/Giornata | Da implementare e confrontare | F02/F03/F04 mobile e desktop sul port | Non propagare stile prima del confronto |
| Catture e responsive | Non eseguiti qui | Manifest e catture F/P/L, checklist con esiti | Nessuna evidenza visuale acquisita |
| Persone nuove | Non eseguito | Note dei compiti, difficoltà e correzioni | Gate prodotto aperto |
| Dispositivo reale | Non eseguito | Ambiente e osservazioni della prova | Gate prodotto aperto |
| Tecnica | Non eseguita qui | analyze/test/backend/OpenAPI/build/CI sul port finale | Una lettura del codice non è prova di successo |

## Evidenze di lettura e questioni da mantenere esplicite

Letti integralmente il piano fase 0 e la skill `migliorapaese-flutter-quality-gate`; ispezionati router/config, regole fantasy, manager, pagine/widget, harness/test fantasy, PlayCubit/reputazione mock, stato/regola proposte e submit/promozione della 33. Sorgente 34 ispezionata con `git show f3f4d4f:lib/core/theme/app_tokens.dart` e `git show --stat --oneline f3f4d4f`. Comandi di lettura: `cat`, `sed`, `rg --files`, `rg -n`, `git show`; nessun test dichiarato eseguito per questa attività documentale.

Questioni aperte: la 33 deve superare la revisione prima di fissare definitivamente stati/errori della UI; catture, persone e dispositivo devono essere forniti/osservati. L'approvazione della proposta oggi alimenta i problemi legacy, e un collegamento ai dati fantasy richiederebbe una decisione distinta fuori dal port. La rotazione reale delle giornate dipende dal repository/backend: l'assenza di una nuova giornata non giustifica una CTA client inventata.
