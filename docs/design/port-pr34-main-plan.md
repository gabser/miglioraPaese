# Port della PR 34 su main: un’esperienza di gioco coerente, preceduta dalla PR 33

## Obiettivo e confini

Integrare le migliorie grafiche e il percorso proposte recuperabile della PR 34 nella versione corrente di `main`, preservando Manager civico, gioco API, SQLite e infrastruttura di staging. Il risultato deve essere un gioco bello, comprensibile e coerente: Manager civico resta l’esperienza principale e predefinita; le schermate importate devono inserirsi nella stessa identità visiva e nello stesso percorso di utilizzo. La sola conservazione delle funzionalità non costituisce accettazione del prodotto.

Questo documento pianifica il lavoro: non attesta revisione remota delle PR, test superati o validazione UX completata. L’aggiornamento del piano non avvia implementazione, merge o deploy.

- Portare tema, componenti condivisi, schermate del gioco precedente e percorso completo proposta → ricevuta → dettaglio.
- Preservare regole e dati di Squadra, Giornata, Mercato e Leghe, includendo queste schermate nell’allineamento di gerarchia visiva, navigazione, terminologia, stati e feedback. Non limitare l’intervento alla compatibilità dei componenti condivisi.
- Non introdurre nuove economie, premi per l’invio di proposte, regole di punteggio o meccaniche di gioco. Eventuali lacune che richiedano nuove regole devono essere esplicitate come decisioni separate.
- Conservare configurazioni mock/API, default Manager civico, identità anonima, moderazione e regole di promozione di `main`.
- Escludere PostgreSQL, migrazioni della baseline alternativa, nuova CLI di moderazione e anteprima di design della 34.
- Integrare tramite una nuova PR basata su `main`; la 34 resta sorgente e riferimento della revisione.

## 0. Direzione di prodotto e accettazione dell’esperienza

**Esperienza principale**

- Definire il percorso di primo accesso e ritorno del giocatore con Manager civico come default: capire la giornata, preparare la formazione, confermarla, comprendere il lock, consultare reveal e punteggio, riconoscere la prossima azione disponibile.
- Descrivere per ogni fase che cosa vede il giocatore, che cosa può fare e quale feedback riceve, usando esclusivamente comportamenti supportati dalle regole correnti.
- Chiarire il ruolo delle previsioni del gioco precedente e delle proposte civiche rispetto a Manager civico. L’importazione di schermate non determina automaticamente nuove voci nella navigazione principale.
- Definire accessi e ritorni tra percorsi, mantenendo visibili Comune e contesto. Distinguere punti fantasy, reputazione, voti e classifiche senza presentarli come misure equivalenti.
- Documentare il comportamento per Comune senza dati, giornata non disponibile, attesa del reveal e giocatore di ritorno. Nessuna metrica o attività fittizia per riempire le schermate.

**Direzione visiva comune**

- Usare tema, token e componenti della 34 come materiale di partenza, adattandoli all’esperienza principale su `main`.
- Definire una gerarchia condivisa per titoli, carte, numeri, azioni, spaziature e densità dei contenuti. Colori e badge devono mantenere lo stesso significato nelle diverse schermate.
- Rendere riconoscibile l’azione primaria di ogni stato; dove non è possibile agire, spiegare l’attesa e il prossimo evento disponibile senza creare CTA artificiali.
- Curare caricamento, vuoto, errore, conferma e azioni disabilitate con la stessa attenzione degli stati pieni. Le animazioni, se presenti, devono chiarire il feedback, rispettare la riduzione del movimento e non ostacolare le azioni.
- Preparare riferimenti visivi mobile e desktop con fixture ripetibili: primo accesso, formazione modificabile, lock, reveal, assenza di dati, proposta ricevuta ed errore recuperabile.

**Proposte e significato nel gioco**

- Spiegare la differenza tra invio ricevuto, moderazione, ammissione ed eventuale ingresso nel gioco, rispettando gli stati e le regole effettivi di `main` e della 33.
- La ricevuta conferma l’invio: non promette approvazione, presa in carico ufficiale o ingresso automatico nel gioco.
- Mostrare nel dettaglio lo stato corrente e il passo successivo quando noto; distinguere chiaramente ciò che è in attesa o non ancora disponibile.
- Non attribuire premi o punti all’invio di una proposta come parte di questo port.

**Deliverable della fase 0**

- Una breve mappa dei percorsi e delle azioni principali per stato.
- Una matrice schermate/stati che includa Manager civico, gioco precedente e proposte, con dati, terminologia e componenti condivisi.
- Riferimenti visivi confrontabili e checklist di accettazione. Le decisioni devono essere concrete e verificabili prima di estendere il port a tutte le schermate.

## 1. Preparazione e revisione delle due PR

**Isolamento e provenienza**

- Usare un checkout dedicato: quello attuale contiene numerose modifiche locali che devono restare intatte.
- Verificare nuovamente lo stato remoto di `main`, delle PR e dei controlli; registrare SHA base/head, file modificati e risultati.
- Riferimenti iniziali: `main` a `6bc103d`, PR 33 a `12d972d`, PR 34 a `f3f4d4f`. Ogni cambiamento successivo richiede aggiornamento della revisione.

**PR 33: primo incremento backend**

- Revisionare luogo e limiti Unicode, DTO pubblici, proprietà delle proposte, ricevute immutabili e continuità della sessione.
- Verificare atomicità SQLite, rollback, replay dopo restart e quota raggiunta, conflitto della chiave con contenuto diverso e reset concorrente.
- Confrontare implementazione, OpenAPI e test; verificare compatibilità con client esistenti, gioco e fantasy.
- Correggere eventuali blocker sulla 33 e integrarla prima del port, dopo test e CI verdi.

**PR 34: revisione della sorgente**

- Classificare le modifiche in: trasferibili, da adattare, escluse.
- Revisionare logica di bozza, invio, recupero, reset, ricevuta, dettaglio e similarità oltre alla UI.
- Usare le prove dichiarate nella PR come riferimenti; rieseguire i controlli sul port effettivo.
- Non effettuare merge tra storie senza antenato comune né retarget diretto della 34 su `main`.

## 2. Port del contratto e della persistenza

**Adapter Flutter sul contratto della 33**

- Conservare il client HTTP con cookie `HttpOnly`; nessun bearer dedicato né identità autore inviata dal client.
- Preparare il form tramite la lista proposte, verificando `capabilities.proposalSubmission == 1` e acquisendo `submissionScope`.
- Inviare `location`, `idempotencyKey` ed `expectedSubmissionScope` nel body del POST.
- Recuperare la ricevuta tramite `next-problem-submissions/{key}`; usare il dettaglio della 33 e `own=true` per le letture proprie.
- Trattare lo scope come stringa opaca, senza imporre il formato UUID della 34.
- Conservare nell’intento Comune, ambiente, scope, chiave e contenuto originali. Un cambio scope blocca il replay del vecchio intento; un lookup 404 non autorizza reinvii automatici.

**Interfacce e backend**

- Estendere i repository Flutter con luogo, dettaglio, letture proprie e operazioni di invio/lookup recuperabile, mantenendo implementazioni API e mock.
- Adattare mapper e gestione errori alle risposte della 33: successo iniziale 201, replay 200, conflitti 409, moderazione 422 e quota 429.
- Portare eventuali integrazioni mancanti necessarie alla UI: errori strutturati sui campi, ricerca per luogo/civico/riferimento e gestione `Retry-After`. Aggiornare OpenAPI e test insieme.
- Preservare gli endpoint admin e la moderazione di `main`, compresa la promozione subordinata a moderazione quando configurata.

**Persistenza locale e reset**

- Portare bozza, intento e ricevuta con namespace per ambiente, modalità e Comune; gli invii API restano legati allo scope originale.
- Preservare chiavi e formati esistenti di preferenze, stato fantasy e ricevute fantasy.
- Salvare l’intento prima del POST; se il salvataggio fallisce, non inviare.
- Conservare la ricevuta come snapshot immutabile e il dettaglio come stato live separato.
- Integrare il reset con la cancellazione della sessione già presente in `main`; invalidare risposte e scritture tardive tramite epoch. Un fallimento del reset deve restare visibile e impedire nuove operazioni incoerenti.

## 3. Port della UI e navigazione

- Importare selettivamente tema, token e componenti della 34, verificando tutti i chiamanti esistenti.
- Allineare prima shell e una sezione completa di Manager civico, scelta per rappresentare gerarchia, azione e feedback; confrontare il risultato mobile e desktop con i riferimenti della fase 0 prima di estendere lo stile.
- Allineare Squadra, Giornata, Mercato e Leghe preservandone regole, dati e vincoli. Rendere comprensibili salvataggio della formazione, capitano, mercato, lock, reveal e spiegazione dei punteggi.
- Completare poi gioco precedente e proposte con lo stesso linguaggio visivo e la navigazione definita nella fase 0.
- Adattare Home, Play, Board, classifica, profilo e onboarding preservando dati API, azioni e vincoli pilot.
- Integrare le route di proposta, ricevuta e dettaglio in entrambe le modalità di routing. Conservare le route fantasy e il ritorno alla pagina di provenienza.
- Mantenere la restrizione del Comune pilot; parametri di route invalidi non devono cambiare silenziosamente Comune.
- Portare categoria esplicita, luogo specifico/Intero Comune, limiti Unicode, errori e focus, riepilogo modificabile e ripristino della bozza.
- Portare il coordinatore sopra le route: doppio clic, uscita e refresh non devono perdere l’esito dell’invio.
- Portare ricevuta accessibile anche con filtri attivi, dettaglio aggiornabile e confronto consultivo con massimo tre proposte simili.
- Mantenere separati cooldown demo e quota API; nessun retry automatico.
- Documentare le differenze rispetto alla 34 e mantenere i default e i profili di build di `main`.

## 4. Verifiche e criteri di accettazione

**Contratto e recupero**

- Luogo completo e legacy senza luogo; Unicode ai limiti; errori associati ai campi.
- Risposta persa o 201 malformata dopo commit → refresh → lookup → stessa ricevuta e una sola proposta.
- Replay dopo restart e quota; chiave riutilizzata con altro contenuto; cambio cookie tra preparazione e POST.
- Reset durante POST/lookup, risposta tardiva, storage corrotto o indisponibile e scope perso.
- DTO senza identità e motivi interni; rejected accessibile solo al proprietario; ricevuta invariata dopo modifica dello stato live.

**Regressioni e UI**

- Suite completa Flutter e backend, comprese fantasy, gioco API, moderazione, persistenza e restore SQLite.
- Manager civico: rosa, formazione, capitano, mercato, lock, reveal, punteggi e leghe.
- Bozza dopo uscita/refresh, filtri conservati al ritorno, ricevuta reperibile, similarità senza blocco per titolo uguale.
- Larghezze 320/390/720/899/900/1120/1440, testo ingrandito, tastiera, focus e assenza di overflow.
- Browser isolato per mock e API SQLite; verificare anche cookie e recupero effettivo dopo refresh.

**Qualità del gioco e coerenza visiva**

- Verificare il percorso continuo primo accesso → comprensione della giornata → formazione → conferma → lock → reveal → spiegazione del punteggio → prossima azione, usando fixture e tempi controllati coerenti con le regole esistenti.
- Verificare il ritorno del giocatore, distinguendo azioni già salvate, azioni ancora modificabili e risultati nuovi. Controllare feedback e persistenza effettiva secondo il profilo mock/API, senza promettere garanzie non implementate.
- Confrontare schermate reali mobile e desktop con dati rappresentativi equivalenti: Manager civico e gioco precedente devono condividere gerarchia, tipografia, spaziature, significati degli stati e qualità del feedback.
- Verificare che l’azione primaria sia riconoscibile, il risultato delle azioni sia spiegato e punti/reputazione/voti non siano confusi. Un layout senza overflow non basta a soddisfare questi criteri.
- Verificare che proposte, ricevute e dettagli distinguano invio, moderazione ed eventuale ingresso nel gioco; nessuna promessa non supportata.
- Eseguire un piccolo test formativo con persone nuove al prodotto: osservare senza guidarle se individuano l’azione iniziale, completano il percorso, comprendono lock e punteggio e sanno cosa fare al ritorno. Registrare esiti, difficoltà e correzioni, senza dedurre il divertimento dai soli test automatici.
- Verificare fluidità e feedback su un dispositivo rappresentativo, oltre ai controlli responsive e di accessibilità. Registrare ambiente e limiti delle prove.
- Per ogni criterio registrare esito, evidenza ed eventuale problema aperto. I problemi che impediscono di capire o completare il ciclo principale bloccano l’accettazione del port. Se mancano persone o dispositivi, il gate resta aperto e l’accettazione prodotto non è completa.

**Gate tecnici**

- Formattazione, analisi Flutter con zero errori/warning, `flutter test`, `npm test`, validazione OpenAPI e `git diff --check`.
- Build dei profili legacy-mock, fantasy-mock, legacy-api e fantasy-api; build Docker.
- CI verde sul commit finale del port. Nessun numero di test della 34 viene riutilizzato come prova del port.
- Registrare separatamente verifiche manuali disponibili e gate con persone/dispositivi ancora aperti, senza dichiarare certificazioni di accessibilità.

## 5. Integrazione e gestione delle PR

- Dopo il merge della 33, creare un branch `codex/port-pr34-main` dal `main` aggiornato.
- Organizzare il port in commit reviewabili secondo questa sequenza: adapter e persistenza; shell e sezione rappresentativa di Manager civico; allineamento delle restanti schermate Manager; gioco precedente e percorso proposte; verifiche e documentazione.
- Verificare la direzione visiva sulla sezione rappresentativa prima di propagare i componenti a tutto il prodotto.
- Completare gate tecnici e di esperienza prima dell’integrazione; distinguere sempre stato tecnico e accettazione prodotto.
- Aprire una nuova PR verso `main`, collegando 33 e 34 e indicando funzionalità preservate, modifiche trasferite ed esclusioni.
- Prima del merge, aggiornare rispetto a `main` e rieseguire i controlli sulle parti interessate.
- Integrare con squash se consentito dalle regole del repository; verificare CI e smoke test dopo il merge.
- Chiudere la 34 come sostituita solo quando il port è integrato e verificato.
- Per rollback usare il revert del commit del port; nessun ripristino distruttivo dei dati.
- Il merge su `main` attiverà il workflow GitHub Pages della demo mock. Non avviare deploy API o pilot pubblico.

**Assunzioni confermate:** port su `main`, SQLite mantenuto, PR 33 prima, Manager civico principale e predefinito, regole e dati preservati con allineamento completo di presentazione e interazione, PostgreSQL rinviato a un intervento separato.

## Aggiornamento di esecuzione — 11 ottobre 2026

L'utente conferma destinazioni mobile e web e rimanda il test con persone, esprimendo dubbi sull'intuibilità del gioco. Il test formativo resta un gate di accettazione prodotto aperto: procedere con lavoro indipendente, controlli tecnici e visivi, e PR draft; non sostituire le prove umane con giudizi dell'agente. Dare priorità a prima azione, salvataggio/conferma/lock, punteggio e prossima azione. Distinguere responsive browser mobile da prova su dispositivo reale.


### Aggiornamento operativo: prove umane rinviate, destinazioni mobile e web

Il lavoro prosegue sui controlli indipendenti. Il test con persone che non hanno mai usato il gioco è rinviato su indicazione dell’utente. La comprensione del ciclo e del punteggio resta una domanda aperta; il report tecnico non costituisce risposta a questa domanda. Per mobile si verifica ora il sito responsive; il collaudo su telefono fisico e gli eventuali target nativi richiedono evidenze separate.

Priorità aggiunte: preservare origine e filtri tornando da bozza/ricevuta; distinguere una lista di proposte vuota dallo stato di attivazione del Comune; verificare dalla UI reale il recupero dopo una risposta persa o malformata, anche dopo refresh, senza duplicare l’invio. La PR resta draft con i gate di prodotto annotati, secondo l’indicazione dell’utente di continuare il piano.


### Rinvio esplicito anche del collaudo sul telefono

L’utente ha scelto «Rimandiamo anche la prova sul telefono». È stato rilevato un iPhone wireless, ma nessuna sessione Safari è stata avviata e nessun risultato hardware viene dichiarato. Il gate dispositivo è rinviato insieme al test formativo. Il port resta pronto tecnicamente nella PR35 draft; merge, verifica demo del port e chiusura34 attendono i gate previsti. Non interpretare il rinvio come autorizzazione a eliminarli.


### Autorizzazione e pubblicazione per il collaudo —12 ottobre2026

L’utente autorizza esplicitamente «Sì, integra e pubblica la demo». Questa decisione cambia l’ordine di merge/pubblicazione/collaudo del prompt originale. Non dichiara svolte le prove umane o sul telefono: la demo pubblicata serve al collaudo successivo.

PR35 integrata squash619e833c1b3f1168744a4475cd0aa70c25848f34, albero identico allo SHA approvato56aa0c6. Backend, Flutter e deploy Pages post-merge verdi. Demo mock: https://gabser.github.io/miglioraPaese/. Il JavaScript pubblico corrisponde all’artefatto del deploy38294881640 (SHA-256113e09e00c72d6fc465a1d676343ab2440836144a76acf1d0d1d80250030752f).

Una verifica online individua un testo residuo del Mercato che prometteva eventuali carte da proposte approvate. Correzione solo testuale: proposte civiche consultabili, nessuna carta Manager per invio/voti; regole immutate. Verificare la nuova pubblicazione dopo l’integrazione della correzione. Test formativo e prova hardware restano da documentare con risultati reali.
