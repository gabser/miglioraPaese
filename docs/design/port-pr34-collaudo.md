# Collaudo della demo pubblicata —12 ottobre2026

Demo https://gabser.github.io/miglioraPaese/, port PR35 integrato619e833. Pubblicazione e merge prima del collaudo autorizzati esplicitamente dall’utente. Nessun deploy API; profilo mock.

Partecipante: utente di questa chat. Familiarità precedente col progetto non valutata: non classificare questa prova come test con persone nuove. Osservazioni auto-riferite via chat, non registrazione video o osservazione diretta del telefono. Modello/dispositivo usato non ancora comunicato.

Compito iniziale, senza suggerire pulsanti: individuare che cosa fare per iniziare e indicare il dispositivo. Risposta: «ho scelto crea la tua ros». Prima scelta riferita: Crea la tua rosa. Non dedurre tempi, comprensione delle regole o completamento della squadra dalla sola risposta.

Secondo compito richiesto: prepararsi a partecipare alla giornata dalla schermata Squadra, riferire azioni e quando si ritiene conclusa la preparazione, eventuali controlli bloccati e dispositivo. Risposta in attesa.

Prove ancora da completare: distinzione conferma/salvataggio/lock; comprensione di previsioni e punteggio; ritorno e prossima azione; fluidità, scroll/tastiera/tap su telefono reale se effettivamente usato. Nessuna accettazione prodotto completa dichiarata.

Riscontri successivi dell’utente:
- «i titoli mi sembrano sproporzionati».
- «mi sembra poco gioco».
- «non si capisce cosa posso fare».
- «ho poca evidenza della giornata inizio e fine».
- Dopo il salvataggio percepisce solo «un piccolo toast», senza uno stacco evidente.

Lo screenshot allegato mostra il layout desktop di Squadra e il Comune scelto; il dispositivo fisico resta non dichiarato. Non dedurre un test su telefono da questo screenshot.

Correzioni candidate: titoli operativi24px; pannello compatto e formazione al centro; comandi Scegli capitano/Sostituisci nella parte alta dei titolari; riserve separate e comprensibili; date locali di inizio/blocco/fine osservazione in Squadra/Giornata; stato persistente Squadra salvata con icona/colore, disabilitazione della conferma ridondante e richiesta di riconferma dopo modifiche; distinzione fra errore API e lock temporale. Regole, punteggi e persistenza invariati.


## Verifica delle correzioni candidate

Codice applicativo b4bc3f18f9877fa326add4822e2de0535f8af1c4. Titoli operativi24px, formazione numerata con capitano evidenziato e comandi nella parte alta delle carte. Le date sono una fascia compatta a tre colonne nel layout normale, una colonna col testo ingrandito; orari del dispositivo. Stato Squadra salvata persistente, distinto dalla conferma da fare; modificare capitano o scambiare una riserva richiede nuova conferma. Errore remoto distinto da blocco temporale, senza sbloccare controlli prudenziali.

Suite completa310/310 sul codice538ade2 prima della sola compattazione del calendario;10/10 test mirati sul candidato b4bc3f1 comprendono calendario, salvataggio dopo ricostruzione manager, cambio capitano, scambio incompatibile col ruolo e APIerrore prima del lock in Squadra/Giornata. Responsive sette larghezze320/390/720/899/900/1120/1440 con testo200%. Quattro build release finali riuscite, manifest collaudo-builds.json. CI completa sullo SHA PR conclusivo sarà registrata nel corpo PR37.

Catture reali Chrome390×844 e1440×900, prima e dopo conferma; la cattura salvata segue un reload ed è priva del toast. I primi comandi della carta sono visibili sopra la navigazione mobile. La soglia pixel nel widget test non rappresentava il render web, poiché flutter test forza il font Ahem; la posizione è stata verificata nel browser con i font reali, mentre restano i test funzionali e di overflow. Il browser ha anche verificato cambio capitano e invalidazione dello stato salvato; Enter apre Sostituisci e Enter sull’elemento Attraversamenti scolastici esegue lo scambio, riportando lo stato da confermare. Nessun reset dei dati dell’utente.

Review indipendente codice: nessun rilievo residuo; correttoP2 relativo all’errore API presentato come lock. Review visiva separata: gerarchia, stato salvato e controlli visibili, nessun problema bloccante nelle quattro catture. Osservazioni non bloccanti da riprendere nel collaudo: su mobile la formazione richiede comunque scroll e Forma/frecce può richiedere una legenda del significato storico. Non dedurre comprensione o divertimento da questi controlli.

Il collaudo dell’utente sulla versione corretta resta da ripetere dopo la pubblicazione. Hardware non dichiarato, nessuna prova con3–5 persone nuove attestata. Preservati regole, dati, punteggi, sessioni e profiliAPI; pubblicazione solo mock.


### Ripetizione del collaudo — 12 ottobre 2026

L’utente segnala che la partita mock salvata ha raggiunto il blocco e chiede «inizia una nuova partita demo». Ricaricare preserva correttamente il calendario precedente ma impedisce di ripetere conferma e modifiche. Squadra espone ora Nuova partita demo soltanto per il repository locale: crea una formazione non confermata e una nuova finestra di scelte, archiviando prima lo stato precedente. Riprendi partita precedente recupera l’ultimo stato archiviato; anche la partita lasciata viene archiviata. Comune, preferenze, proposte e ricevute non vengono azzerati. L’archivio è locale e viene cancellato dal reset generale già disponibile. API e regole temporali restano invariati.

Verifiche specifiche: ripartenza da snapshot congelato, persistenza dopo ricostruzione del manager, recupero della formazione precedente, mancata sostituzione dello stato accettato quando fallisce la scrittura, isolamento dei profili API e azionabilità responsive. Questo è un comando per ripetere la demo, non una certificazione di intuibilità o una prova su telefono fisico.
