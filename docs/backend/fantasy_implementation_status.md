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

## Incrementi ancora da completare

6. Repository API Flutter e percorso individuale remoto completo.
7. Leghe private e classifiche backend.
8. Leghe Flutter e percorso multi-sessione.
9. Candidati staging, rehearsal, backup/restore e scheda go/no-go.

Nessun deploy, apertura automatica di PR o dato reale. Le decisioni operative
sul provider, sulla privacy e sulla platea del pilot restano da documentare.
