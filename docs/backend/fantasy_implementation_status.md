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

## Incrementi ancora da completare

2. Fondazione persistente fantasy, catalogo, stagioni e calendario API.
3. Squadra, previsioni e snapshot al lock autorevoli.
4. Preventivi, trasferimenti transazionali e ledger delle penalità.
5. Pubblicazione esiti, reveal, punteggi e riflessione server.
6. Repository API Flutter e percorso individuale remoto completo.
7. Leghe private e classifiche backend.
8. Leghe Flutter e percorso multi-sessione.
9. Candidati staging, rehearsal, backup/restore e scheda go/no-go.

Nessun deploy, apertura automatica di PR o dato reale. Le decisioni operative
sul provider, sulla privacy e sulla platea del pilot restano da documentare.
