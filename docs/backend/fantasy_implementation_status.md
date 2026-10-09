# Fanta Comune — stato di implementazione

Piano di riferimento: `fanta_comune_incremental_pr_plan.md` (8 ottobre 2026).
Baseline: `ec776f782b37b4927141d7af1fa36312e58bde97`.

## Incremento 1 — repository Flutter locale

Implementato su `codex/fantasy-repository`:

- `FantasyRepository`: lettura asincrona, comandi tipizzati, revisione attesa,
  sincronizzazione e cancellazione, con fallimenti distinti.
- `LocalFantasyRepository`: seed sintetici e preferenze isolati; migrazione v2,
  ripristino validato, scritture ordinate e reset che attende le scritture.
- `FantasyManager`: coordinamento UI/lifecycle; pubblica soltanto lo stato
  accettato dopo il salvataggio, segnala errori e permette retry esplicito.
  Doppi trasferimenti/conferme/riflessioni durante un invio sono respinti.
- Regole e DTO separati dai widget. Nessuna API fantasy fittizia, nessuna rete
  aggiunta al percorso demo. Le regole di punteggio della demo restano invariate.

Verifiche locali con Flutter 3.44.2 / Dart 3.12.2:

- `flutter test --no-pub`: 99 test superati, compresi legacy e responsive.
- `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`: riuscito;
  restano segnalazioni informative (incluse quelle preesistenti).
- `flutter build web --release --no-pub`: riuscito.
- `git diff --check`: riuscito.

Queste prove locali non attestano i check GitHub o i gate operativi del pilot.

## Incremento 2 — fondazione backend

Implementato su `codex/fantasy-backend-foundation`, in una serie locale che
include il commit del primo incremento; nessun merge o PR remota eseguito.

- Schema SQLite 2 additivo con stagioni, catalogo e giornate dedicate.
- Quattro route GET fantasy, OpenAPI 0.7.0, serverTime UTC e provenienza demo.
- Calendario fisso e seed idempotente; nessun rinnovo delle stagioni scadute.
- Readiness, verifica dei backup e restore isolato estesi alle tabelle fantasy.
- `npm test` con Node 24.18.0: 35 test superati, inclusi legacy, migrazione
  da schema 1, rollback transazionale, fusi, isolamento pilot e backup reale.
- OpenAPI YAML letto correttamente e quattro route/schema verificati.
- `git diff --check`: riuscito.

## Incremento 3 — squadra, previsioni e lock

Implementato su `codex/fantasy-team-lock`, nella serie locale preparata.

- Schema 3: iscrizioni, bozze per giornata e snapshot univoci con eliminazione
  a cascata dei dati personali. API di iscrizione, lettura, modifica e conferma.
- Sessione firmata e revisione attesa, validazione di rosa/budget/ruoli,
  previsioni e motivazioni. I cambi formazione invalidano la conferma.
- Lock controllato nella transazione, riconciliazione al riavvio e alle
  richieste. Lo storico non viene modificato dalle giornate successive.
- Cancellazione transazionale comune a legacy e fantasy, con rollback anche
  dello stato legacy in memoria in caso di fallimento.
- `npm test` con Node 24.18.0: 46 test superati, inclusi sessioni indipendenti,
  prima/esattamente/dopo lock, processo fermo, concorrenza, clock rollback,
  fallimenti di scrittura/cancellazione e restart.
- OpenAPI 0.8.0 valido; `git diff --check` riuscito.

## Incremento 4 — mercato e ledger

Implementato su `codex/fantasy-market-ledger`, nella serie locale preparata.

- Preventivi legati a giornata, revisione, catalogo e versioni/ruoli/prezzi
  delle carte; scadenza massima di cinque minuti e sempre entro il lock.
- Conferma con idempotency key persistita. Retry di un comando accettato dopo
  risposta persa, riavvio o lock restituisce l'esito originale; payload diverso
  con la stessa chiave viene respinto.
- Rosa, bozza, revisione, conferma e ledger aggiornati nella stessa transazione.
  Due trasferimenti gratuiti, poi −4 ciascuno; i fallimenti non consumano nulla.
- Schema 4, cancellazione a cascata, readiness e restore estesi al mercato.
- `npm test` con Node 24.18.0: 53 test superati, inclusi retry, concorrenza,
  disponibilità/fonti, budget/ruoli, catalogo cambiato, scadenze e rollback.
- OpenAPI 0.9.0 valido; `git diff --check` riuscito.

## Incremento 5 — esiti, reveal, punteggi e riflessioni

Implementato su `codex/fantasy-reveal-scoring`, nella serie locale preparata.

- Pubblicazione con autorizzazione amministrativa esistente, validazione di
  fonte/finestra/versione e record immutabile con provenienza demo e audit.
- Reveal da snapshot e ledger server; punti della carta congelati al reveal,
  riepilogo provvisorio/definitivo persistito, cooperativo non disponibile.
- Riflessione strutturata unica dopo il reveal, idempotente, con revisioni e
  bonus coerente con capitano e arrotondamento. Totali negativi consentiti.
- Schema 5 con cancellazione a cascata dei dati personali; pubblicazioni
  autorizzate preservate. Strumento admin testato su server fixture isolato.
- 48 fixture condivise verificano tutte le combinazioni delle vere regole Dart
  e Node. `flutter test --no-pub`: 147 test superati; `npm test`: 62 superati.
- Test di autorizzazione, pending, storico, immutabilità, duplicati, restart,
  cancellazione, rollback riflessione e assenza di token/fonti nei log.
- OpenAPI 0.10.0 valido; `git diff --check` riuscito.

## Incremento 6 — Flutter su API fantasy

Implementato su `codex/fantasy-api-client`, nella serie locale preparata.

- Selettore indipendente `FANTASY_DATA_SOURCE=mock|api`, default mock.
  Mapper espliciti, nessuna importazione demo né fallback in caso di errore.
- Stato accettato, revisione server, clock monotono sincronizzato, polling
  limitato con backoff e riconciliazione a resume. Errori e retry visibili;
  nessuna coda di scritture offline. Motivazioni remote con salvataggio esplicito.
- Preventivi server mostrati prima della conferma; ricevuta del comando
  persistita per ambiente/sessione/Comune/stagione prima del trasferimento.
  Retry con la stessa chiave anche dopo riavvio o risposta persa.
- Riepiloghi e punteggi server, cooperativo indisponibile e leghe remote
  esplicitamente non disponibili fino all'incremento 8. Reset remoto prima
  delle preferenze locali; nessuna iscrizione automatica durante il reset.
- 153 test Flutter e 62 backend superati. Percorso contro Node/SQLite isolato:
  revisione obsoleta, clock client errato, lock, perdita risposta, restart,
  storico, riflessione, isolamento e cancellazione fallita/riuscita.
- UI API verificata a 390, 1024 e 1440 px. Analisi con opzioni CI riuscita;
  build release fantasy mock, fantasy API e legacy API riuscite localmente.
- OpenAPI aggiornato per la cache scope opaca; nessuna esecuzione GitHub CI
  o validazione su provider live dichiarata.

## Incremento 7 — leghe private backend

Implementato su codex/fantasy-private-leagues (ecd950e), nella serie locale.

- Schema 6 additivo, OpenAPI 0.11.0 e route per creazione idempotente, elenco,
  classifica privata, rotazione/revoca inviti, adesione e uscita idempotenti.
- Membership per stagione/Comune, pseudonimi generati, nessuna identità,
  rosa o previsione esposta. Prima scadenza della stagione come termine
  competitivo; ingressi successivi spettatori, anche dopo clock rollback.
- Soglia tre competitori, pareggi con posizione condivisa e ordine stabile.
  Totali dal server, compresi riflessioni e ledger penalità.
- Token casuali 256 bit, solo hash a riposo, scadenza/revoca e cinque tentativi
  al minuto per sessione. Nessun token o ID lega nei log.
- Cancellazione proprietario archivia, rimuove il legame e revoca gli inviti,
  preservando gli altri. Rollback transazionale verificato.
- 70 test backend superati: A/B/C, estraneo, soglia, pareggi, penalità,
  riflessione, inviti, isolamento, restart e cancellazione.

## Incremento 8 — leghe Flutter e percorso condiviso

Implementato su codex/fantasy-leagues-client (a06f242), nella serie locale.

- UI remota per crea/entra/esci, rotazione e revoca inviti, conferme esplicite,
  errori/retry e aggiornamento classifiche. Nessuna lega mock in modalità API.
- Pseudonimi server, spettatore e archiviazione visibili; minimo tre competitori,
  cooperativo indisponibile e limite della sessione legata al browser dichiarato.
- Creazione con ricevuta idempotente persistita e scope completo: risposta
  persa e nuova istanza repository non duplicano la lega.
- Test reale con tre manager: mercato, penalità −8, lock, esiti, bonus,
  classifica 29/28/20, estraneo respinto, cancellazione proprietario e restart
  con storico degli altri invariato.
- 154 test Flutter superati; creazione/conferma UI a 390/1024/1440 px.
  Analisi CI riuscita e build release fantasy API, mock e legacy API riuscite.

## Incremento 9 — candidati, rehearsal e gate operativi

Implementato su codex/fantasy-staging-rehearsal, nella serie locale.

- Workflow manuale con profili legacy-api/fantasy-api, input HTTPS verificati,
  manifest e artefatti per profilo/Comune/commit. Nessun deploy nel candidato.
  GitHub Pages imposta esplicitamente tutte le sorgenti mock.
- Smoke solo GET per readiness, catalogo e calendario, con supporto prefisso
  API e prova che nessuna tabella fantasy cambia. Legacy compatibile.
- Rehearsal senza target configurabile: server loopback e SQLite temporaneo,
  tre sessioni, backup/restore di tutte le righe fantasy e leghe, cancellazione
  isolata, rollback, fault injection readiness/5xx e log senza dati personali.
- Segnali locali per readiness ripetutamente fallita, crescita 5xx, disco basso,
  backup vecchio e scraping assente. Nessun alert provider installato o attestato.
- Review finale: tempo dal reveal server più recente; errore di Comune visibile
  senza crash; dati UI rimossi anche se il reset locale fallisce dopo DELETE;
  replay della creazione di una lega archiviata non crea una seconda lega.
- Verifica finale: 155 test Flutter e 75 backend superati, formato pulito,
  analisi con opzioni CI riuscita (111 info, zero errori/warning), tre build
  release riuscite. Le 48 fixture Dart/Node e la rehearsal completa sono verdi.
- Docker non trovato localmente: build immagine demandata ai workflow, che non
  sono stati avviati. Nessun risultato GitHub CI o prova su provider dichiarato.
- Scheda go/no-go compilata con tutte le evidenze mancanti marcate aperte:
  [decisione pilot](fantasy_pilot_go_no_go.md) e [registro](fantasy_local_evidence.json).

## Esito e serie locale

Tutti i nove incrementi tecnici sono implementati. I branch sono preparati in
serie locale; prima di PR/merge dovranno essere riallineati alle dipendenze
effettivamente integrate e sottoposti ai check GitHub e alla review.

Nessuna PR aperta automaticamente, nessun push/deploy, nessun dato reale.
La chiusura tecnica non chiude i gate operativi del runbook: provider, accordi,
privacy/retention, ruoli, platea, TLS, backup provider, alert, moderatori e rollback
restano da documentare e approvare. La decisione operativa corrente è NO-GO.
