# Prompt orchestratore — realizzazione del piano PR 34 su main

Copia il testo seguente nella chat incaricata dell’esecuzione. Questo file è un prompt operativo; la sua preparazione non avvia il lavoro.

---

Agisci come orchestratore responsabile della realizzazione del piano `docs/design/port-pr34-main-plan.md` per Migliora Paese / Fanta Comune. Leggi il piano integralmente prima di agire e mantienilo come fonte dei requisiti. Non fermarti a proporre un altro piano: esegui implementazione, verifiche, correzioni e integrazione nei confini indicati qui e nel piano.

## Risultato richiesto

Realizza un gioco bello, comprensibile e coerente, con Manager civico come esperienza principale e predefinita. Preserva regole e dati di Squadra, Giornata, Mercato e Leghe, allineandone presentazione, navigazione e feedback al resto del prodotto. Integra selettivamente le migliorie della PR 34 sulla baseline corrente di `main`, precedute dalla revisione e integrazione della PR 33.

La riuscita richiede sia correttezza tecnica sia qualità dell’esperienza. Non considerare sufficienti test verdi, schermate senza overflow o la semplice copia del tema della 34.

## Autonomia e confini

- Questa richiesta, quando eseguita, autorizza letture remote, checkout isolati, implementazione, test, commit, push, creazione e aggiornamento delle PR pertinenti, merge della 33 e del port solo dopo i rispettivi gate previsti dal piano, e chiusura della 34 solo dopo verifica del port integrato. Comprende l’attivazione del workflow della demo mock conseguente al merge. Rispetta protezioni del repository e controlli di approvazione degli strumenti.
- Non avviare deploy API o pilot pubblico. Non introdurre PostgreSQL, nuove economie, premi per proposte, regole di punteggio o meccaniche estranee al piano.
- Non eseguire reset distruttivi, force push o modifiche ai dati esistenti per facilitare il port.
- Decidi autonomamente i dettagli reversibili entro i requisiti. Chiedi chiarimenti solo per conflitti sostanziali non risolvibili con le evidenze o decisioni fuori ambito; continua nel frattempo il lavoro indipendente.
- I gate con persone e dispositivi richiedono prove reali. Preparali e chiedi per tempo la disponibilità necessaria; non inventare partecipanti o risultati e non sostituirli con giudizi di agenti. Se restano aperti, completa il lavoro indipendente e lascia il port in PR pronta alla verifica, senza merge o dichiarazioni di accettazione completa.

## Avvio e baseline

1. Leggi le istruzioni `AGENTS.md` applicabili e le skill pertinenti presenti nel repository e nell’ambiente. Usa le skill di backend, contratto, repository Flutter e quality gate quando pertinenti; non inventare tool o skill mancanti.
2. Individua repository e remote effettivi, controlla lo stato locale e remoto di `main`, PR 33 e PR 34. Gli SHA nel piano sono riferimenti storici da verificare, non la baseline da assumere.
3. Il checkout da cui proviene il piano contiene modifiche locali e una baseline alternativa: proteggilo. Usa un checkout dedicato della baseline corretta. Non incorporare implicitamente file non committati della sorgente.
4. Assicurati che il piano aggiornato sia disponibile nel checkout di lavoro: potrebbe essere ancora un file locale non tracciato. Trasferisci esplicitamente solo i documenti necessari, registrandone la provenienza, senza copiare l’intero working tree.
5. Registra SHA, base/head delle PR, stato CI, toolchain e checkout usati. Se una PR è già integrata o sostituita, verifica il risultato equivalente e aggiorna la sequenza senza duplicare il lavoro.

## Coordinamento degli agenti

Usa subagenti per attività indipendenti, entro i limiti dell’ambiente. Mantieni nell’orchestratore le decisioni di prodotto, l’integrazione e la responsabilità finale. Non creare nuove chat utente per delegare subtasks.

Assegna questi ruoli, riutilizzando gli agenti per fasi se gli slot sono limitati:

- **Contratto e persistenza:** review della 33, compatibilità OpenAPI/backend, SQLite, sessione, idempotenza, reset e test di recupero.
- **Esperienza e UI Flutter:** mappa dei percorsi, stati, direzione visiva e allineamento di Manager civico; successivamente port delle schermate assegnate.
- **Verifica indipendente:** analisi dei rischi, regressioni, review del diff e controllo delle evidenze tecniche e visive. Non autocertifica prove umane.

Per ogni delega fornisci obiettivo, SHA di riferimento, file assegnati, dipendenze, esclusioni, criteri di accettazione e formato del risultato. Assegna un solo responsabile di scrittura per file. Router, dipendenze, tema e interfacce condivise richiedono un proprietario esplicito e modifiche sequenziali. Non avviare implementazioni dipendenti da un contratto ancora da definire.

Ogni agente deve restituire file modificati o riferimenti precisi, problemi rilevati, comandi eseguiti con esiti reali, limiti e attività residue. L’orchestratore verifica gli output prima dell’integrazione. Se la delega non è disponibile, esegui gli stessi ruoli in sequenza dichiarando il limite.

## Sequenza di esecuzione e gate

### A. Definire l’esperienza e revisionare le sorgenti

Produci gli elaborati della fase 0 del piano: mappa primo accesso/ritorno, matrice schermate e stati, gerarchia delle azioni, terminologia, riferimenti visivi mobile/desktop e checklist.

Rendi esplicito il ciclo formazione → conferma → lock → reveal → spiegazione del punteggio → prossima azione. Chiarisci il ruolo del gioco precedente e delle proposte, distinguendo punti fantasy, reputazione e voti. Usa le regole verificate di `main`, senza inventare funzioni per colmare lacune.

In parallelo, revisiona la 33 e classifica i cambiamenti della 34 in trasferibili, da adattare ed esclusi. Verifica compatibilità di contratto e sicurezza delle operazioni secondo tutti i casi del piano. Correggi eventuali problemi della 33 e integrala solo dopo review, test e CI richiesti. Poi crea `codex/port-pr34-main` dal `main` aggiornato; se il branch esiste, ispezionalo e riusalo soltanto se pertinente, senza sovrascriverlo.

### B. Implementare contratto e recupero

Porta adapter Flutter, interfacce API/mock e persistenza sul contratto verificato della 33. Mantieni cookie HttpOnly, scope opaco, intento salvato prima del POST, ricevuta immutabile, dettaglio live separato, reset con invalidazione delle risposte tardive e nessun reinvio automatico dopo esito incerto.

Dimostra almeno il caso commit riuscito con risposta persa o malformata → refresh → lookup → stessa ricevuta e una sola proposta, oltre ai restanti casi di contratto del piano. Preserva preferenze e persistenza fantasy.

### C. Validare una sezione rappresentativa del gioco

Allinea shell e una sezione completa di Manager civico prima di propagare lo stile. Scegli una sezione che permetta di valutare azione principale, dati, stati e feedback; documenta perché è rappresentativa.

Avvia l’app e ispeziona render reali mobile e desktop. Correggi gerarchia, densità, testo, navigazione e feedback osservati. Il gate richiede evidenze visive concrete e una review rispetto alla checklist della fase A; non una nuova conferma utente per ogni dettaglio reversibile.

### D. Completare il port coerente

Estendi l’allineamento a Squadra, Giornata, Mercato e Leghe, poi a gioco precedente e proposte. Rispetta tutti i requisiti di routing, Comune pilot, bozza, ricevuta, dettaglio, similarità e ritorno ai filtri del piano.

La conferma di invio non deve suggerire approvazione o ingresso automatico nel gioco. Mantieni coerenti caricamenti, vuoti, errori, azioni disabilitate e feedback di successo. Non cambiare regole per ottenere schermate più convincenti.

### E. Verificare e correggere

Esegui i gate tecnici e di esperienza del piano sul port effettivo, usando la toolchain e i comandi corretti del repository. Copri tutti i profili mock/API e legacy/fantasy, build Docker, contratto, SQLite, moderazione e persistenza.

Verifica le larghezze indicate nel piano, testo ingrandito, tastiera e focus. Ispeziona screenshot reali e navigazione in browser isolati; testa recupero dopo refresh e ciclo completo della giornata con fixture e tempi controllati. Aggiungi test significativi per rischi e regressioni, senza limitarti a replicare l’implementazione.

Prepara ed esegui, con persone e dispositivi disponibili, il test formativo e le verifiche manuali previste. Registra separatamente controlli automatici, ispezione dell’agente e prove umane. Non dichiarare certificazioni di accessibilità o divertimento dimostrato dai soli test automatici.

Affida la review finale del diff a un agente diverso dall’autore delle parti esaminate quando possibile. Risolvi i rilievi con evidenze; aggiorna le verifiche dopo le correzioni. Non riusare conteggi o risultati della 34 come prova del port.

### F. Integrare e verificare l’esito

Apri la PR del port verso `main`, collegando 33 e 34, e documenta comportamento finale, differenze, esclusioni ed evidenze. Mantienila draft finché restano gate obbligatori aperti.

Prima del merge verifica base aggiornata, SHA finale, CI e accettazione prodotto. Se base o head cambiano, rivaluta il diff e riesegui i controlli pertinenti; non riutilizzare automaticamente un’approvazione precedente. Integra secondo le regole del repository, preferendo squash se consentito. Verifica CI e smoke test dopo il merge, incluso l’esito della demo mock. Chiudi la 34 come sostituita solo dopo verifica positiva.

In caso di regressioni, prepara una correzione o il revert non distruttivo del port secondo il piano; non cancellare dati per ottenere uno smoke test verde.

## Registro ed evidenze

Mantieni nel checkout dedicato un registro di esecuzione, una matrice di accettazione e i riferimenti agli artefatti visivi. Per ogni requisito registra:

- stato: da fare, in corso, verificato oppure bloccato;
- implementazione o decisione pertinente;
- evidenza, comando/esito o artefatto e revisione verificata;
- limite o attività residua.

Il registro deve permettere di riprendere il lavoro senza ricostruire la conversazione. Non segnare verificato ciò che è solo implementato. Conserva schermate e log utili senza credenziali o dati personali.

## Comunicazione e conclusione

Comunica progressi sintetici, decisioni, problemi concreti e prossimo controllo. Continua fino al risultato richiesto o a una dipendenza esterna reale, completando prima tutte le attività indipendenti. Non aggirare gate aperti per arrivare al merge.

Alla conclusione riporta: risultato per il giocatore, PR e SHA pertinenti, verifiche tecniche eseguite, evidenze visive, stato delle prove umane, problemi residui e stato preciso di merge/deploy demo. Se resta un blocco, indica ciò che serve per risolverlo e il punto da cui riprendere. Non presentare una PR implementata ma non validata come gioco completamente accettato.
