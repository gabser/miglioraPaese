# Rapporto collaudo locale Luna — 18 ottobre 2026 12:10 CEST

## Esito sintetico

**Collaudo locale incompleto.** Nessun flusso UI è stato eseguito: il runner browser controllabile e capace di acquisire screenshot non è disponibile nella sessione. Chrome è installato, ma senza automazione non si dichiara alcun PASS browser. I test Flutter non sono partiti perché FVM non può aggiornare la cache del SDK; il backend richiede Node ≥24 (presente 22.23.2) e PostgreSQL di test non è configurato/disponibile.

## Candidato e ambiente

- Checkout: `/Users/gabrieleserra/Documents/Codex/2026-07-11/github-plugin-github-openai-curated-remote/work/miglioraPaese`
- HEAD: `1fad162218e758efa3a556790e42b335a6196959`; branch `codex/uc-02-postgres-migrations`.
- Working tree conservato: 227 voci modificate/non tracciate (`git status --short`), 84 file tracked modificati e 289 non tracciati. Sono incluse le sorgenti non tracciate.
- Digest SHA-256 aggregato dei file `lib/`, `test/`, `services/backend/src/`, `services/backend/test/`, `services/backend/migrations/` presenti nel working tree: `badbd7ee0fd472d3946d198031a52c9797bd19b2fe5ea7e0da80bd49cbea0edf`.
- `.fvmrc` richiede Flutter 3.47.5; `fvm --version` 3.2.1. Il tentativo Flutter ha fallito con `Operation not permitted` scrivendo `.../fvm/versions/3.47.5/bin/cache/engine.stamp.tmp` e `engine.realm`; versione SDK effettivamente avviabile non verificata.
- Node `v22.23.2` (richiesto dal package backend: `>=24`); npm `10.9.8`; dipendenze backend assenti. PostgreSQL client 17.10 disponibile, ma `pg_isready` ha restituito `/tmp:5432 - no response`; `TEST_DATABASE_URL` non configurata.
- Chrome presente in `/Applications/Google Chrome.app`; nessuno strumento browser controllabile con acquisizione screenshot esposto nella sessione. Nessun URL o profilo avviato.
- Nessun profilo A/B/C/D avviato; fixture C non avviata; nessun dato reale o segreto usato. Nessuno screenshot prodotto.

## Comandi e risultati automatici

| Comando | Exit code / esito | Risultato |
|---|---:|---|
| `fvm flutter analyze --no-fatal-infos --no-fatal-warnings` | 1 | Bloccato prima dell’analisi: scrittura cache Flutter negata dal sandbox. |
| `fvm flutter test` | 1 | Bloccato prima dei test per lo stesso errore cache SDK. |
| `fvm flutter build web --release` | 1 | Build A non avviata: scrittura cache Flutter negata dal sandbox. Smoke sulla build locale quindi non eseguito. |
| `cd services/backend && npm test` | 1 | 182 test, 56 pass, 3 fail, 123 skip. I test server su loopback falliscono `listen EPERM`; gli skip riportano `TEST_DATABASE_URL is not configured`. Node 22 è sotto il requisito 24. |
| `pg_isready` | 2 | Nessun PostgreSQL in ascolto su `/tmp:5432`. |

I risultati automatici sono evidenze separate e non attestano i percorsi UI. Per la suite Flutter il risultato è **BLOCKED**, non PASS/FAIL di comportamento. La suite backend è partita sotto una versione Node non supportata; i 3 fail sono impedimenti di bind loopback nell’ambiente e non sono stati investigati come difetti applicativi.

## Matrice casi / varianti UI

Tutti i casi sotto sono **BLOCKED, non eseguiti**, perché manca l’automazione browser richiesta. Le varianti con profilo C hanno inoltre il blocco PostgreSQL (`TEST_DATABASE_URL`, servizio locale e fixture); i profili API D richiedono anche il backend locale. Non sono state raccolte evidenze screenshot. Totale varianti elencate: 79.

| ID | Priorità | Profilo/variante | Esito | Causa / prossimo passo |
|---|---|---|---|---|
| A01 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| A02 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| A03 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| A04 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| C01 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| C02 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| C03 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F01 | P0 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| F01 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F02 | P0 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| F02 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F03 | P0 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| F03 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F04 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F05 | P1 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| F05 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F06 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F07 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| F08 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| G01 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| G01 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| G02 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| G02 | P1 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| G03 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| G04 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| M01 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| M02 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| M03 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| M04 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| M05 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| N01 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N02 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N03 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N03 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| N04 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N05 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N05 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| N06 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N06 | P1 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| N06 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| N06 | P1 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| N07 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P01 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P01 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P02 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P02 | P1 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P03 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P03 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P04 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P04 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P05 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P05 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P06 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P06 | P1 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P07 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| P07 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P08 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P09 | P1 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| P10 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| R01 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| R02 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| R03 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| V01 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| V02 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| V03 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| X01 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| X01 | P1 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| X01 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| X01 | P1 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| X02 | P1 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| X02 | P1 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| X02 | P1 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| X03 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| X03 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| X04 | P0 | A | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| X04 | P0 | B | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati. |
| X05 | P0 | C | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |
| X05 | P0 | D | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per D rendere avviabile il backend memory locale. |
| C02 | P1 | C / PILOT_MUNICIPALITY_ID=tuglie | BLOCKED | Runner browser e screenshot non disponibili; usare browser automation controllabile e profili isolati; per C predisporre PostgreSQL loopback test con ruolo autorizzato e Node 24+, poi avviare la fixture. |

## Difetti riproducibili

Nessun difetto applicativo riprodotto nell’interfaccia. L’unico fallimento osservato in suite è `listen EPERM` nei test backend che aprono loopback; classificato come blocco di ambiente, senza attribuzione al candidato.

## Casi non eseguiti e sblocco

- Tutte le varianti N01–X05 elencate nella matrice: installare/abilitare un browser automation runner con screenshot nella sessione e ripetere i flussi a 390×844 e 1440×900; fare le prove responsive e tastiera previste.
- Prove Flutter automatiche e build web A: usare SDK Flutter 3.47.5 con cache scrivibile o già pronta, quindi ripetere `analyze`, `test`, `build web --release` e smoke sulla build locale.
- C/API e suite PostgreSQL: Node 24+, configurare `TEST_DATABASE_URL` verso database loopback il cui nome termina con `_test`, avviare PostgreSQL e usare `test/support/fantasy_backend_fixture.mjs`.
- D/API: avviare il profilo memory locale e poi eseguire lo smoke UI e i percorsi D. Nessuna build o servizio è stato avviato in questa campagna.
- Reset X04/X05 non eseguiti poiché non sono stati creati dati di test.

## Valutazione

**Collaudo locale incompleto.** Le varianti P0 non sono state provate nell’interfaccia; nessuna evidenza UI è stata acquisita e non è possibile valutare readiness del candidato. Questa valutazione riguarda solo il laboratorio locale.
