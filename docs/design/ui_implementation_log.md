# Implementazione del piano UI consolidato

Checkpoint del 10 ottobre 2026. Obiettivo attivo: realizzare **l'intero piano**, incluse le dipendenze API/persistenza necessarie al percorso proposte. Questo registro non dichiara conclusa l'implementazione.

Il piano di riferimento è `piano-ui-consolidato.md`, nella cartella di output della sessione `/Users/gabrieleserra/.codex/visualizations/2026/10/10/01a124f1-7a80-7c50-801a-fca78c7054b7`. Le matrici di quel documento fotografano il checkout prima di queste modifiche; gli avanzamenti sono registrati qui.

## Baseline e lavoro preservato

- Checkout operativo: `/Users/gabrieleserra/Documents/Codex/2026-07-11/github-plugin-github-openai-curated-remote/work/miglioraPaese`.
- Branch: `codex/uc-02-postgres-migrations`; HEAD invariato `1fad162218e758efa3a556790e42b335a6196959`.
- Le 47 modifiche preesistenti UC-02 sono state confrontate con gli SHA-256 di `checkout-baseline.json`: nessuna alterata in questa tranche. Nessuno switch, reset, stash o modifica delle migrazioni.
- Nessuna issue, PR, pubblicazione o deploy. Build web eseguita solo localmente.
- Applicate le skill locali Flutter Quality Gate e i vincoli del repository. Nessuna delega ad agenti.

## Stato delle tranche

| Tranche | Stato attuale | Evidenza / lavoro residuo |
|---|---|---|
| U1 form chiaro | implementata, verificata automaticamente | `SuggestProblemPage`: Form, categoria inizialmente nulla, label persistenti, obbligatorietà, errori per campo, focus al primo errore, Comune visibile, invio disabilitato senza Comune, larghezza massima760, CTA che va a capo. Sei widget test su input/errori/payload e320/390/1440, testo200%, tastiera simulata. Tastiera reale/browser/SR ancora da verificare. Limiti60/140 temporanei come previsto dalla tranche. |
| U2 lista e voto | implementata, verificata automaticamente | `VoteOutcome`, `NextProblemsState.voteError`, successo soltanto su risposta riuscita, card conservate su errore voto. `clearFilters` sincronizza stato e controller ricerca. Vuoto filtrato distinto e reset; esempi nel vuoto reale. Comune/modalità visibili; una superficie scroll con SliverList; stato/categoria/voti vanno a capo. Voti Material48dp e semantica contestuale/selected. Test fallimento/successo/duplicati/reset/retry su320/390 e testo200%. Verifiche browser/SR ancora da svolgere. |
| G-A foreground e heading | parzialmente implementata | Foreground semantici scuri distinti dai tinti in AppTokens e AppTheme; FcStatusChip usa foreground e testo flessibile; FcSectionHeader è heading e dispone azione sotto il testo con spazio ridotto. Contrasto≥4.5 testato su bianco/panel/chip. Restano ispezione renderer e altri piccoli testi delle schermate non ancora riallineate. |
| G-B token/font | implementata, verificata automaticamente | `assets/tokens.json` allineato a palette, semantici, radius, spacing, layout, shadow e tipografia Roboto runtime. Test confronta la scala col tema risolto da Flutter; documentazione aggiornata. Nessun nuovo font o loader. |
| G-C shell/responsive | parzialmente implementata | Wrapper supporta maxWidth parametrico; form760. FcSectionHeader e GameBanner crescono con il contenuto; Home usa vincoli dell'area disponibile. Restano sidebar, profilo/classifica e gate per tutte le route/breakpoint. |
| G-D Home | implementata nella baseline mock, verificata automaticamente | Comune/modalità sempre visibili, hero gioco solo con carte attive, nuova/raccolta segnali distinte. `MockGameRepository.getMunicipalityActivationState` restituisce collectingSignals per proposte non ancora promosse. Soglia del prototipo1; rimosse distribuzioni costruite dallo status e barra livello modulo500. Metriche ad altezza naturale e colonne basate sui vincoli. Sette test Home, più suite repository di attivazione. Browser ancora da verificare. |
| G-E Board | da realizzare | Altezze adattabili, filtri/ordinamento, vuoto con categorie e zone osservabili. |
| G-F Play | parzialmente implementata | FcPredictionBar neutra senza dati, esclude segmenti zero e comunica percentuali con semantica. Restano compattezza, progressione X/Y, disclosure e verifica immutabilità della scelta. |
| G-G profilo/classifica | da realizzare | Larghezze, riepilogo reale, storico disponibile e vuoti operativi. |
| G-H welcome/info/boot | da realizzare | Boot breve, localizzazione italiana Material, percorso Comune e reset coerente. |
| G-I vintage facoltativo | da valutare alla fine | Nessun chiamante applicativo dei sette componenti rilevato nel piano; preservati. Nessuna sostituzione indiscriminata di GameBanner/TicketProgress. |
| C1 luogo/Unicode/schema | da realizzare | Contratto additivo, migrazione nuova append-only, rimozione vincolo titolo e mapper SQL coordinato; preservare migrazioni UC-02. |
| U3 limiti/value object | da realizzare | Dopo C1,120/1000 codepoint e luogo nel dominio/repository/client. |
| U4/U4b bozza/mock persistenti | da realizzare | Scope composto, revisioni/epoch, serializzazione scritture verificate; entità mock stabili dopo refresh e reset completo. |
| U5 scope esplicito | da realizzare | Parametri Comune nelle route/lista/form/detail, scope congelato, protezione risposte stale e ritorno dopo selezione. |
| C2 dettaglio pubblico | da realizzare | GET Comune+ID e DTO pubblico, senza autore interno; policy rejected/own dopo identità autorevole C3. |
| C3 recovery/identità | da realizzare | Sessione server, submissionScope, lookup privato e idempotenza atomica scoped; revoca/reset linearizzati, compatibilità UC-02. |
| U6 luogo/riepilogo | da realizzare | Luogo specifico o diffuso, riferimenti manuali, riepilogo modificabile sulla stessa pagina. |
| U7 coordinator invio | da realizzare | Intento persistito prima di POST, key stabile, resistenza a dispose/refresh, outcomeUnknown, lookup/recupero e reset epoch. |
| U8 conferma/ritrovamento | da realizzare | Receipt persistente con ID reale, link e dettaglio; ritrovamento indipendente dai filtri. |
| U9 similarità | da realizzare | Confronto contestuale consultabile, continuazione distinta; nessun blocco hard per titolo. |
| C4 moderazione/rate | da realizzare | Policy server3/h per sessione×Comune e feedback coerente con400/422/429. |
| U10 accettazione integrata | da realizzare | Scenari AC/D, mock/API-memory/Postgres, browser/reflow/zoom/SR, refresh/restart/reset. Ricerca con persone reali resta un gate da svolgere, non simulabile con test automatici. |

## Verifiche del checkpoint

Flutter3.44.2, SDK fissato dal progetto. Test e build eseguiti con SDK assoluto; nessun aggiornamento di dipendenze o pubspec.lock.

- Suite Flutter completa: **58 test passati**, esito nel log `flutter-test-ui.log` della cartella output della sessione.
- Analyzer: `flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings`, riuscito senza errori, con98 avvisi informativi e1 warning, esito nel log `flutter-analyze-ui.log`. Il warning invalid_null_aware_operator in Home è stato riconosciuto alla successiva ispezione dettagliata e corretto nella tranche C1/U3. Gli avvisi informativi non costituiscono una certificazione di assenza di debito tecnico.
- Build: `flutter build web --release --no-pub`, riuscita in `build/web`; log `flutter-build-ui.log`. Il compilatore segnala un riferimento CupertinoIcons senza font corrispondente: da esaminare durante la verifica delle icone, non attribuito a una nuova dipendenza.
- `git diff --check`: riuscito.
- Preservazione: `verifica-preservazione-implementazione-ui.json` nella cartella output,47 file preesistenti invariati.

Non eseguiti in questa tranche: test Node/PostgreSQL (backend e contratti invariati), browser dell'app, screen reader, tastiera di un dispositivo reale, prove con persone. Nessun requisito dipendente da queste verifiche è dichiarato completato.

## Prossima sequenza

Completare G-C e proseguire G-E/F/G/H con prove mirate. Poi C1→U3→U4/U4b→U5 e C2/C3→U6/U7→U8/U9; C4 e U10 chiudono il percorso proposte. Preservare tutta la matrice del piano, senza ridurre l'obiettivo alle tranche visive già avviate. La necessità futura di sessione autorevole e nuove migrazioni è parte dell'implementazione dell'intero piano richiesta dall'utente; il precedente mandato di sola pianificazione è stato seguito prima di iniziare questa fase.

## Secondo checkpoint UI — 10 ottobre 2026

Questo aggiornamento supera gli stati G-C/E/F/G/H della tabella precedente soltanto per le capacità e le prove elencate qui. Non completa l'intero piano.

- **G-C:** sidebar scorrevole su finestre basse, semantica delle destinazioni; pulsanti e testi flessibili in shell, TicketProgress e onboarding. Sette prove shell sui breakpoint320/390/720/899/900/1120/1440, altezza400 e testo200%. Route reali a320 e1440 con testo200%: Home, Play, Board, profilo, classifica, welcome, onboarding cinico, cambio Comune, boot, spiegazione, privacy, lista e form. Le altre larghezze delle route e i renderer browser restano da verificare.
- **G-E:** Board con ricerca, categoria, stato, ordinamento aggiornamento/titolo/trend, reset del vuoto filtrato, vuoto reale operativo e card ad altezza naturale. Test dei filtri e del layout320/390/1440. `BoardPage._visibleProblems` opera sui dati effettivi del repository.
- **G-F:** Play comunica carte giocate sul totale reale e posizione di ogni problema. Riepilogo e approfondimenti facoltativi usano `FcDisclosure` con identità di storage distinta; scelta, motivazioni e sicurezza restano visibili. Eliminati i fallback percentuali sintetici di `ProblemCard`; la barra resta neutra senza dati. Test del progresso, dei vuoti, dell'immutabilità della previsione e della modifica successiva della sicurezza.
- **G-G:** profilo con punteggio, quantità di previsioni e precisione dal repository, precisione assente senza dati e testo per campioni piccoli. Storico con retry e protezione da risposte tardive dopo cambio Comune. Classifica scoped al Comune con caricamento, errore/retry, vuoto operativo e righe naturali per nomi lunghi. Dodici test dedicati.
- **G-H, parziale:** boot breve e component showcase separato in `/design-preview`; tutorial facoltativo con Indietro/Avanti/Salta; scelta del Comune dal form torna al form. `App` conserva e dispone una sola istanza del router. Localizzazione italiana tramite `flutter_localizations` SDK e intl transitivo: pubspec e lock aggiornati intenzionalmente. Il reset delle bozze e delle entità mock dipende ancora da U4/U4b.

Verifiche effettive: suite completa **95 test passati** (`flutter-test-ui-second.log`); successivo test rafforzato di Play **7 passati** (`play-confidence-second.log`). Analyzer senza errori,88 segnalazioni informative e1 warning (`flutter-analyze-ui-second.log`). `git diff --check` riuscito. Tutti i47 file preesistenti conservano lo SHA-256 iniziale e HEAD è invariato (`verifica-preservazione-ui-second.json`). I log sono nella cartella di output della sessione.

Build web release riuscita (`flutter-build-ui-second.log`), senza pubblicazione. Resta il messaggio del compilatore sul font CupertinoIcons, già presente nel primo checkpoint: la compilazione riuscita non certifica tutte le icone nel browser.

Nessuna modifica a backend o contratti in questa tranche. Nessuna verifica nuova PostgreSQL, browser, dispositivo, screen reader o ricerca con persone. Prossima tranche funzionale: **C1**, contratto luogo e limiti Unicode con migrazione append-only, seguita da U3 e persistenza bozza. Conservare il lavoro UC-02 e verificare la compatibilità dei dati precedenti.

## Terzo checkpoint — C1 e U3

**Implementate e verificate le basi del contratto luogo, della persistenza e dei limiti client.** I campi luogo nella UI, il capability gate API, la bozza e l'invio recuperabile restano da realizzare nelle rispettive tranche.

- `proposal-location.js`: normalizzazione manuale `specific`/`municipality`, label120, civico20, riferimento200, titolo120 e descrizione1000 code point dopo trim. Nessun troncamento; Unicode malformato e NUL rifiutati prima della scrittura, coerentemente con PostgreSQL. Campi luogo sconosciuti o malformati rifiutati; assenza/null legacy distinta da Intero Comune.
- `http/app.js` e OpenAPI aggiornati insieme. MemoryStore conserva luogo su creazione/lista/voto e luogo leggibile sulla carta promossa; rimosso il blocco per titolo uguale.
- Migrazione **nuova** `20261010110000000_proposal_location.js`: colonna JSONB nullable con constraint strutturale, rimozione della UNIQUE titolo; normalized_title diventa text ed è calcolato da SQL per evitare differenze Unicode di case folding. Le due migrazioni UC-02 originarie restano byte-identiche. Manifest esteso con un solo nuovo checksum. Query e mapper strict aggiornati insieme. Il rollback con duplicati fallisce atomicamente e conserva tutti i record; un rollback riuscito rimuove il luogo, come documentato nel README.
- Compatibilità verificata da schema precedente: ID, data, stato e voto conservati, location null. I record idempotenti legacy conservano fingerprint e risposta originaria: l'assenza di luogo non aggiunge una proprietà null al digest.
- `ProposalLocation` e `ProposalLimits` nel dominio Flutter; mapper distingue legacy da oggetto malformato. Repository API e mock trasportano/conservano il luogo. `CivicLoopStore` ammette titoli identici e mantiene il luogo nel voto e nella carta promossa. `SuggestProblemPage` usa120/1000, contatori dopo trim e nessun hard truncation; il testo oltre limite resta correggibile nel campo.

**Evidenze effettive nella cartella output:**

- `backend-c1-postgres.log`: **58 test passati, zero skip**, comando `npm test`, Node24.18.0 con PostgreSQL17.10 reale. Comprende upgrade legacy, constraint luogo e boundary emoji, rollback, concorrenza/idempotenza UC-02, POST/list/voto/promozione e HTTP persistente.
- `flutter-c1-u3-full.log`: **104 test passati**; `flutter-c1-u3-target.log`:41 prove mirate. Il test della promozione mock è stato ulteriormente rafforzato in `flutter-c1-u3-promotion.log`.
- `flutter-c1-u3-analyze.log`: analyzer riuscito,90 segnalazioni informative, nessun errore/warning. Il warning Home riconosciuto nei checkpoint precedenti è corretto.
- `flutter-c1-u3-build.log`: build web release riuscita sullo stato finale; nessuna pubblicazione. Resta il messaggio già noto sul font CupertinoIcons, da verificare nel renderer.
- `verifica-c1-restart.mjs`, fixture e log `c1-restart-prepare.log`/`c1-restart-verify.log`: PostgreSQL realmente fermato e riavviato con pg_ctl; ID, luogo, voti/stato e carta promossa riletti invariati; replay restituisce la risposta iniziale senza duplicare l'entità.
- Test svolti esclusivamente nel cluster `/private/tmp/migliorapaese-ui-c1-pg`, loopback55473, database `migliorapaese_ui_c1_test`. Il cluster è stato fermato dopo le verifiche; nessun database esistente utilizzato. La suite resetta solo tale database usa e getta.
- OpenAPI YAML parsato e tutti gli88 riferimenti locali risolti. Questo controllo non è una validazione integrale dello standard OpenAPI.
- `verifica-preservazione-c1-u3.json`:33 dei47 file iniziali byte-identici;14 overlay intenzionali e necessari al contratto, esplicitamente registrati con hash iniziale/corrente. Il lavoro UC-02 su pool, migrazione/ledger, transazioni e chiavi idempotenti è mantenuto. Nessuna modifica inattesa; HEAD invariato.

Nessuna issue, PR, deploy o verifica browser/SR svolta. Prossimo incremento **U4/U4b**: persistenza locale versionata di bozze e mock, scope composto e barriera di reset. Seguono U5, C2/C3, luogo/riepilogo U6 e coordinator U7; le verifiche integrated U10 rimangono necessarie.

## Quarto checkpoint — U4/U4b: bozze e persistenza mock

**Implementate le bozze locali e la persistenza delle proposte/voti mock.** Il recupero affidabile delle richieste API e la conferma persistente restano U7/U8; questo checkpoint non completa il piano.

- `LocalDataStore` conserva un envelope JSON versionato, serializza le scritture, pubblica il nuovo stato solo dopo il successo del backend e distingue dati corrotti da dati assenti. La chiave browser comprende origine e base path. Il reset invalida subito l'epoch, aspetta le scritture già iniziate e impedisce che risposte o operazioni precedenti ripopolino lo storage. Un reset fallito blocca nuove scritture fino al retry.
- `ProposalScope`, `ProposalDraft`, `ProposalDraftStore` e `ProposalDraftController` separano installazione, fonte, origine/path API e Comune canonico. Conservano testo originale, campi incompleti o oltre limite, categoria e struttura luogo. Revisione condivisa tra controller, flush esplicito e cancellazione della sola revisione accettata proteggono le modifiche successive all'invio. I campi luogo sono predisposti nel modello; la relativa UI è ancora U6.
- `SuggestProblemPage` ripristina i valori, mostra lo stato effettivo del salvataggio e offre retry. Blocca invio/uscita controllata se la bozza non è salvata; i salvataggi già accodati continuano dopo dispose. L'invio cattura Comune e revisione prima dell'attesa e impedisce tap ripetuti. Non sposta il nuovo form se cambia Comune durante una richiesta precedente. Corretto anche l'hint residuo di140 caratteri, incoerente con il limite1000.
- `CivicLoopStore` salva proposte, ID casuali stabili, date, luogo e voti in un snapshot versionato. Gli ID seed e l'indice voto sono scoped al Comune; fallimenti di scrittura non creano proposte o voti fantasma. Il mock rimane una demo locale. Previsioni e reputazione del gioco non sono rese persistenti da questa tranche.
- `AppDependencies` usa lo stesso store locale nei provider reali. `MockGameRepository` cancella tutte le cache durante il reset e rifiuta operazioni tardive. `PrivacyPage` attende il reset, mantiene la pagina in caso di errore e comunica correttamente che i dati API remoti non vengono cancellati. La nuova identità API autorevole e la revoca remota dipendono ancora da C3.

Evidenze nella cartella output della sessione:

- `flutter-u4-full.log`: **127 test passati**. `flutter-u4-target.log`:28 mirati; `flutter-u4-flow.log`:7 prove dei percorsi attraverso i provider reali. Copertura: refresh mediante ricreazione dello store, scope, revisioni concorrenti, errori di salvataggio/reset, corruzione, operazioni tardive e voto/promozione mock persistente.
- `flutter-u4-analyze.log`: nessun errore o warning,107 segnalazioni informative. `flutter-u4-build.log`: build web release riuscita con risorse renderer locali. Dopo la sola correzione dell'hint, `flutter-u4-copy.log`:15 prove form/percorso passate; `flutter-u4-build-final.log`: build finale riuscita, prova Chromium ripetuta su questa build con esito positivo. Il messaggio noto CupertinoIcons rimane da valutare nella verifica completa delle icone.
- `u4-browser-check.mjs` e `u4-browser-result.json`: Chromium headless già installato, profilo isolato, server esclusivamente loopback8871. Refresh reale della bozza con spazi originali/categoria, invio mock, nuovo refresh con stessa entità/ID/data e reset attraverso Privacy riusciti, zero pageerror. Screenshot form390/1440 e proposta ripristinata ispezionati. Questa prova non copre il voto via browser, le richieste API, uno screen reader o un dispositivo reale. Il testo helper dei limiti appare ellissato a390: controllo finale U10 ancora aperto.
- `verifica-preservazione-u4.json`: tutti i47 file iniziali conservano esattamente lo stato del checkpoint C1;33 byte-identici alla baseline iniziale e14 overlay C1 già documentati, nessuna nuova alterazione. HEAD invariato. Nessuna modifica backend in U4/U4b, nessun nuovo test PostgreSQL necessario per questa tranche. `git diff --check` riuscito.

Prossima sequenza: **U5**, scope esplicito delle route; **C2/C3**, dettaglio e sessione autorevole/capability gate; **U6/U7**, luogo e invio recuperabile; **U8/U9**, ricevuta e similarità; **C4/U10**, policy server e accettazione integrata. Nessuna issue, PR o deploy.

## Quinto checkpoint — U5: Comune esplicito in lista e form

**Il Comune della pagina è ora risolto dall'URL e mantenuto tra lista, form e invio.** La preferenza globale non viene modificata dai deep link. L'applicazione dello stesso scope alla futura pagina dettaglio resta da collegare in C2/U8; U7 deve ancora recuperare gli invii dopo dispose o esito incerto.

- `ProposalRouteContext.resolve/validate/location` centralizza il parametro `municipality`. Alias noti diventano ID canonici; nomi di Comuni custom mantengono il prefisso `comune:` e il proprio scope. Query vuote, ripetute, sconosciute senza prefisso o malformate sono invalide: non ereditano il Comune delle preferenze. Nessun fallback implicito demo.
- `buildRouter` rende esplicito il Comune quando si entra da un vecchio collegamento senza query e una preferenza valida è disponibile. Una query valida prevale anche con preferenze discordanti o mancanti. La scelta intenzionale nell'onboarding conserva la destinazione e costruisce il nuovo URL; `/change-municipality` supporta il ritorno al percorso proposte. Gli ingressi esistenti da Home/Play/Board passano per questa risoluzione.
- `NextProblemsPage` e `SuggestProblemPage` ricevono il contesto di route; header, bozza, repository e navigazione interna usano lo stesso ID. Un cambio di parametro crea provider/controller distinti; le bozze dei due Comuni non vengono copiate. `ProposalScopeNotice` offre una scelta esplicita sui collegamenti invalidi e sulla lista priva di Comune.
- `NextProblemsCubit/State` conserva il Comune iniziale invece di rileggere le preferenze durante load/vote/submit. Cambio scope, chiusura e reset invalidano le risposte vecchie; il voto tardivo non aggiorna o sblocca una nuova operazione con lo stesso ID in un altro Comune. Lo stato di ricerca/filtri e gli elementi precedenti vengono svuotati quando cambia lo scope.
- Correzione emersa dalla prova browser: `_recordDraft` confronta testo/categoria prima di salvare. Focus e selezione del cursore non creano bozze vuote né avanzano la revisione; modifiche reali continuano a essere salvate.

Verifiche effettive nella cartella output:

- `flutter-u5-target.log`:48 prove mirate passate prima dell'ultima correzione; `flutter-u5-regression.log`:28 prove passate dopo la correzione, compresa selezione senza nuova scrittura e notice su viewport320×350 con testo200%.
- `flutter-u5-full-final.log`: **147 test passati** sullo stato finale. `flutter-u5-analyze-final.log`: nessun errore/warning,107 segnalazioni informative. `flutter-u5-build-final.log`: build web release riuscita con risorse renderer locali. Resta il messaggio noto CupertinoIcons, da verificare integralmente in U10.
- `u5-browser-check.mjs`, `u5-browser-result.json` e screenshot: Chromium isolato, loopback8871, URL Castel Bolognese con preferenza Pincara; refresh reale dopo fixture di preferenza Bologna recupera ancora la bozza Castel. Invio persistito nel Comune Castel, ritorno lista/form con stessa query, query vuota/duplicata senza fallback o mutazioni storage, vecchio URL senza query canonizzato a Bologna. Zero pageerror. Questa prova usa il mock: non certifica una richiesta API o una sessione server. Gli screenshot a390 sono ispezionati; helper dei limiti ancora ellissati, da trattare in U10.
- `verifica-preservazione-u5.json`: tutti i47 file iniziali conservano lo stato C1, nessuna nuova alterazione;33 byte-identici alla baseline e14 overlay C1 già registrati. Branch e HEAD invariati. `git diff --check` riuscito. Nessuna modifica backend, migration, dipendenze o contratto in U5.

**Prossimo incremento C2:** GET dettaglio Comune+ID e DTO pubblico sanificato per lista/creazione/voto/dettaglio. Nel codice attuale `readSuggestion` è un helper privato PostgreSQL e non una route GET; la serializzazione delle proposte include ancora `submittedByUserId`. La visibilità dei rejected propri e il recovery privato richiedono C3, senza fidarsi del `userId` scelto dal client. Seguono luogo/riepilogo U6, coordinator U7, ricevuta/dettaglio U8, similarità U9 e C4/U10. L'intero obiettivo resta attivo. Nessuna issue, PR o deploy.


## Sesto checkpoint — C2: dettaglio pubblico e DTO

**Implementati il contratto GET pubblico Comune+ID e i repository Flutter corrispondenti.** La pagina dettaglio è ancora U8; i rejected propri e il recupero privato richiedono l'identità autorevole C3. Il piano complessivo resta incompleto.

- `http/routes.js` e `http/app.js`: `GET /v1/municipalities/{municipalityId}/next-problems/{problemId}` con ID opaco codificato. Comune errato, Comune assente, ID mancante o proposta rejected restituiscono lo stesso404 `suggested_problem_not_found`. Parametri UTF-8 malformati restituiscono400; `userId` influisce solo sul voto visualizzato, senza conferire accesso privato.
- `backend-service.js:getPublicNextProblem` delimita la visibilità. `public-suggestion.js:publicSuggestion` serializza una whitelist di13 campi pubblici, compresa location e promotionRule a sua volta delimitata. Lista, creazione, voto, dettaglio e replay HTTP non espongono `submittedByUserId` o futuri campi interni. Gli adapter continuano a conservare l'autore interno e i record idempotenti originali. OpenAPI e README documentano la rimozione coordinata del campo pubblico; il mapper Flutter non lo utilizzava.
- `memory-store.js:getNextProblem` e `postgres-store.js:getNextProblem` rileggono esattamente Comune+ID e voto corrente. I rejected sono esclusi dalla lista pubblica; il voto è impedito anche dopo cambiamento di stato e per replay di una precedente chiave HTTP. Il test PostgreSQL modifica lo stato tramite fixture SQL: questo non implementa un percorso di moderazione, che resta C4.
- `NextProblemsRepository.getSuggestedProblem`, implementazioni API e mock: GET con Comune canonico e ID codificato, rifiuto di ID restituito discordante o stato non pubblico, errori404 tipizzati. Il mock conserva ID, luogo, data e voto dopo ricreazione dello storage. Il test confronta le date come istanti UTC; nessuna modifica della logica produttiva della data è stata necessaria.

Verifiche effettive nella cartella output:

- `backend-c2-postgres.log`: **64 test passati, zero skip**, suite completa Node24 con PostgreSQL17.10 reale; comprende contratto pubblico, visibilità, voto/replay e invariabilità delle risposte/fingerprint legacy salvate. `backend-c2-memory.log`:31 prove passate prima della chiusura Flutter. Nessuna nuova prova di riavvio del dettaglio C2: la precedente prova C1 rimane limitata alle capacità allora esercitate.
- `flutter-c2-full.log`: **153 test passati** sullo stato finale. Le13 prove dei repository API/mock sono passate anche isolatamente; il vecchio `flutter-c2-target.log` conserva un tentativo fallito precedente e non è prova del risultato finale.
- `flutter-c2-analyze.log`: nessun errore/warning,107 segnalazioni informative. `flutter-c2-build.log`: build web release riuscita con risorse renderer locali. Resta il messaggio CupertinoIcons, ancora aperto per U10. Nessuna nuova prova browser, screen reader, dispositivo o ricerca con persone in C2.
- OpenAPI YAML parsato con Ruby/Psych: **95 riferimenti locali risolti**; controllo strutturale locale, non validazione integrale dello standard. `verifica-openapi-c2.json` registra il perimetro.
- `verifica-preservazione-c2.json`:32 dei47 file iniziali byte-identici,15 overlay intenzionali con hash iniziale/C1/corrente. Nove file della baseline sono stati aggiornati rispetto a C1, senza cambiamenti inattesi. Le due migrazioni UC-02 originarie, il manifest corrente, pool, ledger, transazioni e infrastruttura delle chiavi restano invariati rispetto a C1. Branch e HEAD invariati; `git diff --check` riuscito. Nessuna nuova migrazione o dipendenza in C2.
- Il solo cluster usa e getta `/private/tmp/migliorapaese-ui-c1-pg`, loopback55473, è stato fermato dopo le prove. Nessuna issue, PR o deploy.

### Audit del lavoro residuo

| Incremento | Stato e dipendenze | Primo risultato verificabile |
|---|---|---|
| C3 identità/recovery | da realizzare; segue C1/C2 | Sessione anonima autorevole, submissionScope, lookup privato, idempotenza scoped persistente, revoca/reset e capability gate; nessun accesso privato autorizzato dal userId client. |
| U6 luogo/riepilogo | da realizzare; dominio e bozza predisposti, capacità API da verificare tramite C3 | Scelta luogo specifico/intero Comune, campi manuali120/20/200 e riepilogo modificabile; legacy null distinto da Comune intero. |
| U7 invio recuperabile | da realizzare; dipende da C3 | Intento immutabile e chiave persistiti prima del POST, coordinator fuori dal ciclo vita della pagina, esito incerto e riconciliazione senza reinvio automatico. |
| U8 ricevuta/dettaglio | da realizzare; C2 predisposto, ownership/recovery dopo C3/U7 | Ricevuta con ID reale persistente, route dettaglio scoped, stato corrente e ritrovamento indipendente dai filtri. |
| U9 similarità | da realizzare | Confronto consultabile per Comune/categoria/titolo/luogo, continuazione esplicita e nessun blocco per titoli duplicati. |
| C4 policy server | da realizzare; identità C3 necessaria | Moderazione e limite3/h sessione×Comune, risposta429 e Retry-After autorevoli, feedback coerente con400/422. |
| U10 e gate UI generale | da realizzare/parziali | Prove integrate mock/API-memory/Postgres, refresh/restart/reset/esiti incerti, tutti i breakpoint e zoom, helper ellissati, font/icone, tastiera/SR/dispositivi e studio con persone reali. Gli automatismi non sostituiscono queste ultime prove. |

Il prossimo intervento operativo è **C3**. Il sistema ha riportato l'obiettivo in stato `usageLimited`; questo checkpoint conserva il lavoro e non marca l'obiettivo completo né bloccato. La richiesta dell'utente rimane l'intero piano, senza riduzione al dettaglio pubblico già verificato.


## Settimo checkpoint — C3: sessione autorevole, recovery privato e revoca

**Implementate e verificate le basi server e client C3.** Il coordinator app-scoped che conserva l'intento prima del POST, il recupero della UI dopo dispose/refresh e la ricevuta persistente restano U7/U8. Il capability gate è effettivo prima delle scritture API; la nuova UI luogo U6 deve ancora usare queste capacità. Non è completato l'intero piano.

- `domain/proposal-session.js`: token opaco32 byte, SHA-256 salvato sul server, scope UUID generato dal server e identità derivata dallo scope. `proposal_sessions` è introdotta dalla sola nuova migrazione `20261010150000000_proposal_sessions.js`; le tre precedenti rimangono intatte. Manifest aggiornato append-only, nessuna dipendenza nuova.
- `http/routes.js/app.js`: bootstrap e verifica `/v1/proposal-session`, revoca POST `/v1/proposal-session/revoke`, lookup GET Comune+chiave e GET detail `/own`. Letture private obbligatoriamente bearer e no-store. Scope/chiavi sono separati per sessione, Comune canonico e operazione; il bearer prevale sul userId client per scritture e personalizzazione delle letture pubbliche. Le chiamate legacy scaffold senza bearer conservano il comportamento precedente e non offrono recovery privato. L'app API reale ora invia il bearer; il gioco legacy è preservato.
- `PostgresStore.lockSession` usa il lock della riga sessione nella medesima transazione di proposta/voto e risposta idempotente UC-02. Revoca attende i commit in corso e impedisce invii, replay e letture private successive. I digest e i cache record legacy non vengono riscritti. `lookupSubmission` restituisce lo snapshot originario; `getOwnNextProblem` lo stato corrente, anche rejected, solo al proprietario autorevole. La moderazione effettiva è ancora C4.
- `ProposalSessionStore` salva token+scope nella persistenza locale scoped all'ambiente API prima di concedere una lease; verifica tutte le capability richieste. Una sessione scaduta o uno scope atteso mancante/diverso non avvia un bootstrap sostitutivo. Bootstrap concorrenti convergono; risposta di bootstrap tardiva dopo reset viene scartata e il token ricevuto revocato. Un errore di salvataggio non consente invio.
- `ApiClient.getJson` trasporta header di lettura. `ApiNextProblemsRepository` usa lease/capability e protegge le risposte tardive. I metodi `prepareSubmissionScope`, `submitWithIdempotencyKey`, `lookupSubmission` e `getOwnSuggestedProblem` consentono al futuro coordinator di conservare chiave e scope. Il semplice submit della pagina conserva ancora il ciclo vita precedente: questa capacità da sola non realizza U7.
- `AppDependencies` collega il nuovo store al repository API reale e registra la revoca su `AppPrefs.beforeClearAll`; il mock non ha un hook remoto. `clearAll` attende revoca prima del reset locale. Se il server non conferma, conserva token/preferenze e blocca nuovi invii fino a retry e reset riusciti; le risposte precedenti non possono diventare successo dopo reset. `PrivacyPage` spiega il requisito di connessione solo in modalità API. Un client HTTP opzionale iniettato permette di verificare i provider reali senza rete esterna; l'istanza iniettata resta di proprietà del chiamante.

Evidenze effettive nella cartella output:

- `backend-c3-postgres-final.log`: **73 test passati, zero skip**, suite Node24/PostgreSQL17 reale. Scope indipendenti, alias canonici, stessa chiave/same payload,409 per payload diverso, isolamento own/lookup, rejected solo owner, identità/voto autorevoli, revoca/replay e rollback mutazione+cache. Il test di gara osserva la revoca in attesa di un lock tramite `pg_stat_activity`, poi libera il commit e verifica il rifiuto dei successivi invii.
- `verifica-c3-restart.mjs` e `c3-restart-result.json`: PostgreSQL davvero fermato/riavviato; stesso scope, ricevuta e replay originali, una sola proposta, dettaglio/voto corrente conservato e revoca ancora efficace. La fixture privata con token è stata eliminata dopo la verifica; nessun token stampato nei log. Il test non sostituisce un esercizio backup/restore.
- `flutter-c3-full-final.log`: **163 test passati** sullo stato finale. `flutter-c3-session-target.log`:13 prove store/client; `flutter-c3-recovery-target.log`:3 prove repository/provider API reali; `flutter-c3-privacy-regression.log`:8 prove mock del reset passate dopo aver reso il testo API condizionale. La fixture iniziale di provider usava uno store memory distinto da SharedPreferences: corretta per esercitare il backend locale effettivo.
- `flutter-c3-analyze-final.log`: nessun errore/warning,112 info. `flutter-c3-build-final.log`: build web release riuscita. Resta il messaggio noto CupertinoIcons; nessuna nuova prova browser/SR/dispositivo o studio con persone in C3.
- `verifica-openapi-c3.json`: YAML parsato e109 riferimenti locali risolti, risposta bootstrap presente; non validazione integrale OpenAPI. Contratto aggiornato con401, bearer opzionale sulle superfici legacy/pubbliche e obbligatorio sulle private.
- `verifica-preservazione-c3.json`:30 dei47 file iniziali byte-identici,17 overlay intenzionali con hash iniziale/C2/corrente;11 aggiornati rispetto a C2, nessuna modifica inattesa. Pool, ledger, runner, infrastruttura transazioni/idempotenza e migrazioni pregresse preservati; manifest esteso di un solo elemento. Branch/HEAD invariati. `git diff --check` riuscito. Il cluster temporaneo è fermato; nessuna issue, PR o deploy.

### Audit e prossimo incremento

**Prossimo U6:** campi luogo specifico/intero Comune, label120/civico20/riferimento200, riepilogo modificabile e display dei dati legacy. Poi **U7**: intento immutabile persistito prima della rete, coordinator indipendente dalla pagina, esiti incerti, riconciliazione senza reinvio automatico, cooldown scoped e abbandono esplicito quando lo scope non è più provabile. Reset con token/storage non recuperabile e bootstrap con risposta malformata richiedono ancora la gestione UX esplicita di scope perso, senza promettere revoca di un token sconosciuto. **U8/U9/C4/U10** rimangono integralmente nello scope; ricevuta/dettaglio UI, similarità, moderazione/rate server e tutte le verifiche manuali/integrate non sono completati. L'obiettivo «continua e completa il piano» è attivo; il vecchio limite di sessione non è più il blocco corrente.

## Ottavo checkpoint — U6/U7 riconciliati, U8/U9 implementati, C4 e U10 verificati

11 ottobre 2026. L'autorizzazione esplicita dell'utente «Sì, implementa il piano senza issue, PR o deploy» supera il precedente vincolo di sola pianificazione. Le sezioni storiche sopra non descrivono più lo stato finale. Branch e HEAD invariati; lavoro nel working tree, modifiche preesistenti preservate. Nessuna issue, PR, commit o deploy.

U6/U7 sono presenti nel sorgente e ricontrollati nella suite corrente: luogo manuale/Comune intero, riepilogo, bozza per scope/revisione, intento persistito prima POST, coordinator fuori dal ciclo vita della pagina, outcomeUnknown, same-key lookup/retry e reset/epoch. I precedenti checkpoint documentali non costituiscono la prova di questo stato: valgono i file correnti e le nuove esecuzioni.

### U8a conferma persistente e U8b dettaglio

- Nuove route `/proposal-receipt/:problemId` e `/next-problems/:problemId` con Comune esplicito e ID opaco URI-safe. `ProposalDocumentScaffold`/`ProposalDocument` condividono layout bounded/scroll, distinguendo snapshot locale da stato aggiornato.
- `ProposalSubmissionCoordinator.savedReceipt` cerca lo storico succeeded anche dopo tentativi rifiutati/abbandonati, senza bootstrap o POST. Pagina receipt offline con ID, data, Comune, categoria, luogo/riferimento e stato all'invio; missing/corrupt non presenta un'altra receipt come se fosse quella richiesta.
- Lista con link ultimo invio indipendente dai filtri e azioni dettaglio. Push/pop mantiene lo stesso Cubit e testo ricerca. Il successo naviga alla ricevuta reale, senza semplice SnackBar effimera.
- `ProposalDetailCubit` legge GET pubblica oppure own con scope originale. Gestisce 401/404/retry, rejected proprio, epoch/dispose/request order; ID restituito diverso e rejected pubblico falliscono in modo controllato. Interface additiva `OwnProposalDetails`; mock ledger prova ownership e rilegge stato corrente persistito.

### U9 similarità advisory

`ProposalSimilarityController` legge dati pubblici nello stesso Comune/categoria e seleziona fino a tre candidati per titolo e contesto luogo/riferimento; non considera stesso luogo una prova di equivalenza, non cancella o fonde proposte, esclude rejected. Il panel mostra candidato/Comune/luogo/stato e apre il dettaglio conservando bozza/riepilogo. Proposta distinta, errore o attesa possono essere superati con azione esplicita; edit/reset invalidano confronto e risposte tardive. La similarità non modifica idempotenza o vincoli geografici.

### C4 policy e revisione locale

- Filtro conservativo 422 su contatti/link/controlli/elenco limitato di offese, incluso luogo/riferimento; civico non interpretato come telefono. Non promette rilevazione completa di dati personali.
- Limite tre proposte salvate per autore e Comune in un'ora mobile inclusiva. Rejected contano, errori/replay non contano. PostgreSQL usa advisory lock e conteggio nella stessa transazione di proposta+ricevuta; cinque tentativi concorrenti producono tre creazioni. HTTP429 con body/header Retry-After autorevoli e CORS exposed; Flutter conserva bozza e spiega422/429 senza motivi interni o auto retry.
- Demo Flutter mantiene cinque minuti per scope, visibili prima del submit; timer si cancella a dispose/reset e sblocca l'invio alla scadenza. API separata dalla policy locale.
- Prefisso autore `session:` riservato al bearer, rifiutato per legacy submit. Gli altri ID legacy restano client-controlled: non è una barriera antiabuso per un lancio pubblico.
- Nuova migrazione append-only `20261011100000000_proposal_reviews`, quattro migrazioni precedenti immutate. `reviewSuggestion` reject/reopen con stato atteso, rollback e motivo privato; CLI locale da stdin autorizzata dalle credenziali DB, stampa solo ID/stato. Non esiste route admin pubblica né identità operatore autenticata.
- Test down/up della quinta migrazione ha evidenziato un difetto reale del ledger: ORDER BY sull'alias testuale id faceva risultare7 successivo a10. Corretto l'ordinamento sulla colonna numerica originale. Il runner e le migrazioni storiche non sono riscritti.
- La revisione locale non approva temi già promossi; autopromozione al voto netto1 resta prototipo. Workflow umano obbligatorio prima dell'ammissione/account operatore restano decisioni UC-03/UC-04, non dichiarati completati.

### Verifiche correnti e limiti

Output: `/Users/gabrieleserra/.codex/visualizations/2026/10/10/01a124f1-7a80-7c50-801a-fca78c7054b7`.

- `flutter-u10-full-final.log`:225 pass. `flutter-u10-target.log`:28 pass incluse route320/390/720/899/900/1120/1440, testo200% e400% su320, policy e cooldown. `flutter-u10-analyze-final.log`:zero errori/warning,151 info, exit1 per info.
- `flutter-u10-api-build-final.log` con `NEXT_PROBLEMS_DATA_SOURCE=api` e `flutter-u10-mock-build-final.log`:release riuscite. La prima build con define errato non è prova API; resta il font warning CupertinoIcons, distinto dai rilievi analyzer.
- `backend-c4-verified.log`:80 pass, zero fail/skip, con PostgreSQL17.10 reale. Manifest5 e history rispetto a HEAD verificati; `git diff --check` passa.
- `u10-memory-browser-result.json`, `u10-postgres-browser-result.json`:Chromium isolato, build API finale e HTTP reale. POST committato con201 malformata, refresh senza POST/bootstrap aggiuntivi, lookup stessa chiave/ID, una entità, receipt deep-link refresh, dettaglio live, voto aggiorna stato e snapshot immutato, ultimo invio e ricerca conservati. Conteggi1POST/1bootstrap/1lookup; nessun pageerror. Tab effettivo osservato sul ramo PostgreSQL.
- `u10-mock-browser-result.json`:build demo verificata separatamente, receipt/refresh/own detail/cooldown visibile, zero API requests. Screenshot PostgreSQL390/1440 ispezionati.
- `c4-restart-result.json`:cluster PostgreSQL realmente fermato/riavviato; scope/revoca/ricevuta/quota/audit privato persistono. `c4-cli-result.json`:CLI locale reale, reject/reopen e stale conflict senza motivo stampato.
- Solo cluster usa e getta `/private/tmp/migliorapaese-ui-c1-pg`, loopback55473, database `migliorapaese_ui_c1_test`. Nessun database esistente usato. Fixture privata di restart cancellata, token non stampati. Copie `/private/tmp` mai considerate prova di implementazione; provenienza è checkout corrente e confronto Git/hash.

Il piano unico aggiornato è `piano-ui-consolidato.md` nell'output; `checkout-before-u8.json` censisce302 file della fotografia prima di questa continuazione e `verifica-preservazione-u10.json` ne registra delta/hashes. I47 file della baseline originaria rimangono censiti separatamente.

U10 percettivo e ricerca formativa restano aperti: screen reader reale, tastiera mobile/dispositivi, browser zoom400% (diverso da textScale4), misure prestazioni e studio con circa5 persone. Non sono simulati o dichiarati conclusi. Backup/restore operativo UC-02.5 e lancio pubblico non sono attestati. Primo intervento U8a raccomandato dal piano è realizzato; successivo incremento circoscritto è validazione SR di receipt/detail/lista, con sole correzioni osservate. Nessuna nuova autorizzazione richiesta per attività già autorizzate.

### Allineamento finale C5 — errori di campo e ricerca per luogo

La rilettura di `api-data-contract-plan.md` e `ux-redesign-spec.md` ha richiesto due ultimi allineamenti verificati: `fieldErrors` additivo nel400 e ricerca luogo quando il round trip è abilitato. `fieldError` espone percorso e codice pubblico stabile; ApiClient accetta solo codici noti, coordinator li trasporta e il form li associa al campo in italiano, focalizzando il primo errore. Edit elimina il feedback stale, conserva la bozza grezza e invalida riepilogo/comparison; nessun retry automatico. Un widget con provider API reale simula rifiuto su titolo valido localmente, prova focus/valori grezzi, correzione e nuovo invio esplicito.

La ricerca comprende luogo/civico/riferimento, nel Comune esatto, nei tre adapter Flutter mock/backend memory/PostgreSQL. Null legacy non diventa un luogo inventato. Verifiche reali di ricerca Via Milano/12-A/Ingresso nord, Intero Comune in SQL e isolamento del Comune; nessuna nuova migrazione o dipendenza.

Prove autorevoli finali aggiornate: `flutter-u10-complete.log`228 pass, `flutter-u10-complete-analyze.log`zero errori/warning e155 info; build API e mock in `flutter-u10-complete-{api,mock}-build.log`; `backend-u10-field-search-final.log`81 pass senza skip. Target `flutter-u10-field-search-target-final.log`25 pass; `c4-openapi-validation.json` conferma YAML/riferimenti e fieldErrors/422/429. I log225/80 e le build precedenti sopra restano checkpoint storici. Browser finali ripetuti sui due adapter reali e sul mock nel medesimo dossier U10; distinguere tab osservato da screen reader realmente usato. Gate umani e workflow preventivo già elencati restano aperti.
