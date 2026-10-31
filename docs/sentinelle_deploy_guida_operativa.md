# MiglioraPaese / Sentinelle — guida operativa al rilascio

Verifica del repository e delle fonti ufficiali: **16 ottobre 2026**. Lingua dei pannelli: prevalentemente inglese. I nomi delle schermate possono cambiare: usare il nome della funzione indicata e la fonte collegata se il menu differisce.

**Stato: guida preparata; pilot reale NO-GO.** Il frontend iniziale scelto per questa guida è GitHub Pages; Cloudflare Pages è l'alternativa. Supabase ospiterà PostgreSQL, Auth, Storage privato e, dopo una prova tecnica, il backend adattato a Edge Functions. Resend Free consegnerà i codici email tramite SMTP. Nessun servizio è stato attivato, nessuna email inviata, nessun dominio acquistato e nessun deployment eseguito durante la preparazione di questo documento.

Il percorso contiene porte di arresto esplicite: il codice cloud mancante deve essere implementato prima dei relativi comandi di pubblicazione. Il budget zero è una condizione da controllare, non una garanzia di disponibilità o di costo futuro. Non c'è oggi evidenza di un dominio gratuito disponibile e accettato per questo account Resend.

## Come usare la guida

1. Leggere stato reale (§1), architettura (§2) e quote (§3).
2. Eseguire in ordine la sequenza §12, usando i dettagli dei §§4–11. Registrare un esito per ogni passaggio; un requisito bloccante non verificato ferma il pilot. Per seguire l’esecuzione usare il [playbook e taccuino di avanzamento](sentinelle_deploy_taccuino.md), inizializzato con tutti i passi da fare.
3. Completare il collaudo §13 e il verbale GO/NO-GO. Le decisioni riservate al titolare sono raccolte in §15.

I blocchi di comandi indicano la directory di esecuzione. I valori tra parentesi angolari, per esempio <PROJECT_REF>, sono **segnaposto da sostituire**, mai credenziali reali. Le variabili segrete devono essere caricate da un gestore sicuro o da file privati esclusi da Git; non incollarle in issue, terminali condivisi o log CI. Una API è un'interfaccia usata dai programmi; HTTPS è il trasporto cifrato; OTP significa codice monouso; SMTP è il protocollo di consegna email; DNS associa nomi a risorse e attestazioni; JWT è il token firmato della sessione; RLS è il controllo PostgreSQL dell'accesso alle singole righe. La CI esegue controlli automatici sul codice.

Altri termini usati: SQL è il linguaggio delle interrogazioni e operazioni sul database; DDL ne definisce la struttura; FK sono i vincoli che collegano tabelle. UTC è il riferimento orario universale; le finestre sono salvate in UTC e mostrate nel fuso dell'utente. CPU è il tempo di calcolo e RAM la memoria disponibile. MFA significa autenticazione con più fattori; TOTP è il codice temporale dell'app autenticatore. SDK è la libreria con cui Flutter usa un servizio; ADR è il documento che registra una decisione tecnica; DTO è la forma dei dati scambiati dall'API. Gli XP sono punti esperienza civici, separati dal punteggio fantasy. SHA256 identifica contenuti tramite un'impronta; HMAC firma un messaggio con chiave segreta. PNG/JPEG sono formati di immagini, EXIF i metadati della fotografia e GPS la posizione eventualmente incorporata.

## 1. Stato reale e perimetro

### 1.1 Baseline e attendibilità delle evidenze

Esaminati README radice/backend, codice Flutter e Node, manifest e migrazioni, OpenAPI, test, workflow e documenti Sentinelle: [runbook precedente](sentinelle_deploy_zero_budget_runbook.md), [architettura](sentinelle_cloud_architecture.md) e [sorgente Mermaid](sentinelle_cloud_architecture.mmd), [dossier](sentinelle_operational_dossier.md), [piano](sentinelle_gap_resolution_plan.md), [registro](sentinelle_execution_log.md), [accettazione](sentinelle_acceptance_matrix.md), [porting](sentinelle_porting_matrix.md), envelope delle fasi e [report funzionale storico](functional_gap_report_2026-10-13.md). Consultati anche [rilascio pubblico](public_release_plan.md), documenti backend/ADR e [evoluzioni](evolution/README.md).

Le istruzioni AGENTS.md fornite nella sessione indicano Postman CLI in /Users/gabrieleserra/.local/bin/postman. Non è stato trovato un ulteriore AGENTS.md nel checkout o negli antenati controllati. Postman è facoltativo per il futuro collaudo: nessuna collection di deployment cloud è attestata.

HEAD esaminato: 1fad162218e758efa3a556790e42b335a6196959, **con numerose modifiche locali e file non tracciati**. HEAD da solo non riproduce questo stato. Non sovrascrivere tali modifiche, non fare reset/clean e non attribuire al commit i file non ancora inclusi. Questa attività modifica soltanto questa guida e aggiunge il suo collegamento al README.

| Categoria | Cosa risulta | Evidenza e limite |
|---|---|---|
| Esiste, verificato localmente in precedenza | PostgreSQL, gioco/fantasy, account simulati, missioni/foto locali, revisione/XP, misurazioni, leghe, cooperazione e strumenti operativi sintetici | Dossier e log privati .sentinelle-local/phase8: backend 217 PASS, Flutter 466 PASS, cinque build e rehearsal sintetica. Sono risultati storici, non suite rieseguite per questa guida e non test Supabase |
| Correzione successiva | Avvio home quando la stagione API è ancora assente | Dossier: 467 test Flutter dopo la correzione, build/browser locale. Il digest storico e75f7744a9d55c620fb7c08388761d98b911a850d0f29eeeb6588faa9c7b1fad non attesta questa modifica successiva |
| Esiste, da adattare | Server Node 24, pg 8.22.0, unità transazionale, 16 migrazioni, repository API Flutter | server.js, persistence/postgres, package.json, lib/features/*/data e OpenAPI. Runtime, identità e trasporto non sono ancora Supabase |
| Da implementare | Edge entrypoint, verifica JWT, identità Auth, RLS/grant, Storage, scheduler cloud, revoca, chiusura account completa e backup cloud | Non esiste un progetto supabase/ distribuibile nel checkout; pubspec.yaml non contiene supabase_flutter |
| Da configurare sui provider | Account, regione, dominio/DNS, SMTP, Auth/CAPTCHA, bucket, segreti, hosting, cron e monitoraggio | Nessuna configurazione account verificata tramite accesso ai pannelli in questa attività |
| Decisioni aperte | Fattibilità Edge, dominio, custodia backup/diario, operatori e sostituti, fonti reali, retention, platea e capacità | Registro §15; bloccano il pilot secondo il caso |

Il server attuale impone EMAIL_DELIVERY=simulated per gli account; le missioni richiedono MISSION_STORAGE=local-synthetic e retention esplicita. Il servizio upload richiede anche synthetic=true. Rimuovere soltanto questi controlli **non** realizza Auth, Storage o un percorso per dati reali.

La cancellazione DELETE /v1/session elimina il solo namespace fantasy: conserva account/sessioni, osservazioni, foto, XP e parte dello storico/audit. Non equivale a cancellare l'account. Gli script operations.js accettano solo loopback e database di test; non vanno sbloccati per usarli sul cloud.

### 1.2 Risolvere le divergenze documentali

Il README contiene ancora descrizioni iniziali («nessuna autenticazione», ApiGameRepository assente) superate dalle implementazioni locali; rimangono vere per il rilascio operativo le lacune cloud. Il report del 13 ottobre descrive gap poi affrontati nelle fasi 0–8. Le sezioni iniziali del README backend (esiti solo v1, revisione futura, UC-02.5 aperta) sono integrate dalle sezioni successive; non dedurre lo stato corrente leggendo solo l'introduzione.

I diagrammi/runbook precedenti propongono Cloudflare come frontend. Qui prevale la decisione richiesta: GitHub Pages principale, Cloudflare alternativo. Sono conservati come documentazione storica; non sono configurazioni applicate. Render Free resta escluso e Firebase non è il sistema Auth scelto. Un nuovo ADR dovrà fissare il contratto cloud effettivo dopo la prova Edge.

Il prodotto di questo rilascio non comprende token crypto, pagamenti, premi monetari, premium o sponsor: le schede EVO sono discovery, non funzionalità distribuite. Mappa, notifiche push/email applicative, nomi leghe personalizzati ed espulsione membri restano fuori dalla prima versione, secondo il piano. Le email qui previste servono all'autenticazione; l'inbox applicativa rimane interna.

## 2. Architettura di destinazione e confini

### 2.1 Dove gira ogni componente

| Componente | Prodotto e responsabilità | Comunicazioni e stato |
|---|---|---|
| Flutter web | GitHub Pages: file statici pubblici; Cloudflare Pages alternativo | Browser → Auth, Edge, Storage via HTTPS. Nessuna regola privilegiata sul sito statico |
| Autenticazione | Supabase Auth: OTP email, access/refresh token, MFA | Flutter usa Auth; Auth invia a Resend tramite SMTP cifrato |
| Backend applicativo | Supabase Edge Functions, runtime Deno compatibile con parte delle API Node | Nuovi handler HTTP; verificano JWT, account attivo, Comune, ruoli, conflitti e revisioni; chiamano PostgreSQL/Storage |
| Invarianti e dati | PostgreSQL del progetto Supabase | Una transazione per comando e ricevuta; funzioni SQL privilegiate ristrette oppure singolo client transazionale compatibile |
| Fotografie | Supabase Storage, bucket privati separati per quarantena e prove validate | Upload autorizzato in quarantena; finalizzazione server; download autenticato/proxy o URL firmato breve |
| Email | Resend Free, dominio mittente verificato | SMTP da Auth; consegna al provider del destinatario. Non genera il codice |
| Processi pianificati | Supabase Cron (pg_cron), SQL e invocazioni Edge limitate | Scadenze, outbox, retention; stato persistito, ripresa dopo interruzione. Da configurare e testare sul Free |
| Log | Log Supabase e Resend più audit applicativo in PostgreSQL | Eventi tecnici minimizzati; consultazione quotidiana e avvisi esterni/manuali assegnati |
| Backup | Computer già disponibile con disco cifrato + seconda copia privata separata già disponibile | Esportazione DB e oggetti, cifratura locale, manifest; nessuna copia su Pages o artefatti pubblici |
| Diario cancellazioni | Registro durevole indipendente dal DB ripristinato e dai suoi backup | Scrittura prima della conferma cancellazione, replay obbligatorio prima di riaprire; custodia da implementare/assegnare |

Questa è l'architettura candidata finale, **condizionata a P1 (§5)**. Non esiste un processo Node persistente su Pages. Il Node attuale usa node:http, filesystem, zlib, crypto, AsyncLocalStorage, pg e child_process per le operazioni: nessuna compatibilità automatica con Edge. Le regole pure si possono riusare; composizione, persistenza, file, normalizzazione immagini e strumenti operativi vanno adattati. Se P1 fallisce, fermare il porting e aprire una decisione sul runtime: non sostituirlo implicitamente con Render o un piano a pagamento.

### 2.2 Diagramma Mermaid

~~~mermaid
flowchart LR
    B["Browser: Flutter web"]
    P["GitHub Pages; alternativa Cloudflare Pages"]
    A["Supabase Auth: OTP e MFA"]
    E["Supabase Edge Functions: API e autorizzazione"]
    D[("Supabase PostgreSQL: dominio e audit")]
    S["Supabase Storage: bucket privati"]
    C["Supabase Cron: job recuperabili"]
    R["Resend SMTP: dominio verificato"]
    U["Casella del partecipante"]
    L["Log provider e controlli operativi"]
    X["Operatore: backup e restore in quarantena"]
    K[("Copie cifrate DB e oggetti, custodia separata")]
    J[("Diario cancellazioni indipendente")]
    B -->|"carica file statici"| P
    B -->|"richiede e verifica codice"| A
    A -->|"SMTP TLS"| R
    R -->|"consegna email"| U
    B -->|"HTTPS con JWT"| E
    B -->|"upload autorizzato; lettura privata"| S
    E -->|"transazioni"| D
    E -->|"validazione e accesso prove"| S
    A -->|"schema Auth gestito"| D
    C -->|"SQL di scadenza"| D
    C -->|"job autenticati"| E
    E -->|"eventi senza segreti"| L
    E -->|"richiesta chiusura assistita"| X
    X -->|"registra e replica prima della conferma"| J
    X -->|"esporta DB e oggetti"| D
    X -->|"copia oggetti via API"| S
    X -->|"salva e verifica"| K
    X -->|"replay prima della riapertura"| J
~~~

Auth gestisce il proprio schema: le associazioni con i profili di dominio sono esplicite. Il diagramma rappresenta anche attività umane non ancora automatizzate. Il diario non è un file temporaneo dentro la funzione Edge.

## 3. Account, costi, strumenti e quote

### 3.1 Quote verificate e comportamento atteso

Tutte le fonti della tabella sono state consultate il 16 ottobre 2026; verificare nuovamente il pannello prima di attivare. Le unità GB/MB sono quelle dichiarate dal provider, MiB nei limiti foto significa 1.048.576 byte. Non confondere dimensione del database, spazio disco, egress (dati trasferiti in uscita) e spazio oggetti.

| Servizio | Piano, limiti e carta | Costi, sospensione e superamenti |
|---|---|---|
| Supabase | Free: 2 progetti attivi; DB 500 MB/progetto, Storage 1 GB, 50.000 utenti attivi mensili, 5 GB egress e 5 GB cached egress, Edge 500.000 invocazioni. SMTP custom e MFA base inclusi; backup automatici e SLA non inclusi. [Prezzi](https://supabase.com/pricing) | Quote condivise/attribuite secondo la voce del pannello organizzazione: registrare entrambi i progetti. Free soggetto a restrizioni; DB può diventare sola lettura. Non approvare add-on IPv4, dominio API, branching o upgrade. [Billing](https://supabase.com/docs/guides/platform/billing-on-supabase), [dimensione DB](https://supabase.com/docs/guides/platform/database-size) |
| Supabase account/inattività | Percorso Free senza carta pubblicizzato dal provider; verificare che l'organizzazione sia effettivamente Free. [Fonte ufficiale](https://supabase.com/blog/observability-for-every-supabase-project-with-grafana-cloud) | Pausa con bassa attività su 7 giorni; non basta avere un sito visitato. Ripristino manuale dal pannello e nuovo smoke. Dopo la finestra di ripristino indicata dal provider può servire recupero da esportazioni. [Pausa](https://supabase.com/docs/guides/platform/free-project-pausing) |
| Supabase Edge | 256 MB RAM, 2 s CPU per richiesta, durata worker Free 150 s; timeout inattività richiesta 150 s. [Limiti](https://supabase.com/docs/guides/functions/limits) | Nessun tempo di risposta garantito. Elaborazione PNG e transazioni da misurare; memoria/filesystem del worker non sono persistenza |
| Resend | Free transazionale: 3.000 email/mese, 100/giorno, attualmente 3 domini; ritenzione dati servizio 30 giorni. [Prezzi](https://resend.com/pricing) | Senza overage abilitato, superamento impedisce ulteriori invii secondo la quota; niente coda OTP applicativa che invii codici ormai scaduti. Non scegliere Pro/Scale o pay-as-you-go |
| Resend registrazione | I termini Free dicono che non servono pagamento o dati di fatturazione; il trial ha condizioni diverse. Registrazione di questo account non eseguita. [Termini §6](https://resend.com/legal/terms-of-service) | Gli stessi termini riservano modifiche/discontinuità e conversione in abbonamento al superamento. Non promettere costo zero incondizionato: mantenere margine, ricontrollare termini e bloccare nuovi invii prima delle quote |
| Supabase email | SMTP predefinito: destinatari del team, circa 2/ora; non adatto al pilot. SMTP custom: limite iniziale 30 messaggi/ora da controllare/regolare. [SMTP](https://supabase.com/docs/guides/auth/auth-smtp) | Il limite reale è il minimo tra Auth, Resend, reinvio, antiabuso e restrizioni account. I 50.000 MAU non danno 50.000 email |
| GitHub Pages | GitHub Free per repository pubblici; privati richiedono un piano idoneo. Dominio github.io incluso. [Disponibilità](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages) | Pubblicato ≤1 GB, bandwidth soft 100 GB/mese, deploy entro 10 min; limite soft 10 build/ora con eccezione workflow custom. Restrizioni d'uso Pages da valutare prima di servizi commerciali. [Limiti](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits) |
| GitHub Actions | Runner standard pubblici e Pages gratuiti; per privati GitHub Free include 2.000 min/mese e 500 MB artefatti; cache separata. [Billing Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions) | Niente larger runner; limitare conservazione artefatti. Titolare controlla budget/blocco spesa e altri consumi dell'account. Quota finita può fermare CI/deploy, non risolve il backend |
| Cloudflare Pages | Free: 500 build/mese, 1 concorrente, timeout 20 min, 20.000 file, 25 MiB/file; hosting statico. [Limiti](https://developers.cloudflare.com/pages/platform/limits/) | Free pubblicizzato senza carta; verificare selezione del prodotto. Non aggiungere Workers/R2 a pagamento per aggirare un limite. [Piani](https://www.cloudflare.com/plans/) |
| DNS/dominio | DNS Free non include registrazione di un dominio. github.io/pages.dev non danno controllo dei record mittente | Partner con DNS esistente: nessun costo aggiuntivo possibile, disponibilità da ottenere. Dominio acquistato: costo iniziale/rinnovo fuori budget. Opzioni gratuite condizionate in §7 |
| Backup e reperibilità | Nessun prodotto esterno aggiuntivo attivato; hardware/copie già posseduti da confermare | Se mancano seconda copia, custodia indipendente, spazio o persona disponibile, budget zero non copre il requisito: blocco B6 |

Supabase applica una politica di uso equo con avvisi e possibili restrizioni, non un extra gratuito garantito; verificare i dettagli del proprio avviso, senza contare sul periodo di grazia. [FAQ](https://supabase.com/docs/guides/platform/billing-faq). Restare sotto le quote è necessario anche quando non è associata una carta.

### 3.2 Strumenti e autorizzazioni

1. Tecnico con accesso in lettura/scrittura al repository e revisione delle modifiche locali; amministratore per Pages/environment e segreti CI quando necessario. Non rendere pubblico il repository solo per ottenere hosting: prima gate cronologia e diritti asset del piano pubblico.
2. Titolare crea/approva account Supabase, Resend, eventuale Cloudflare, accetta condizioni, conferma piano e custodia; usa autenticazione a più fattori sui pannelli e nomina sostituto. Il tecnico può configurare tramite invito al team con privilegio minimo disponibile. Non condividere account/password personali.
3. Flutter **3.47.5** da .fvmrc, Dart **3.13.4** incluso; FVM opzionale. Node **24** come CI, npm e lockfile del backend; PostgreSQL **17** per le prove locali (CI usa 17.10-alpine). Il Node trovato sul PATH durante questa analisi è **22.23.2**: va selezionato Node 24 prima delle suite, senza considerare valide prove lanciate con versione errata.
4. Git, browser Chrome/Firefox/Safari desktop e mobile, strumenti sviluppatore, curl, dig, client psql/pg_dump compatibili con la versione server effettiva, strumenti di cifratura già disponibili. Per Supabase locale: Docker e Supabase CLI da installare e fissare a una versione verificata nella fase implementativa; non esiste un pin CLI nel repo oggi. [CLI e sviluppo locale](https://supabase.com/docs/guides/local-development).
5. Gestore segreti privato e spazio backup esterno al repository; account email di test reali del titolare e di collaudatori consenzienti su provider diversi. La scelta del dominio richiede il suo amministratore DNS.

Prima di qualsiasi comando di test annotare versioni con node --version, npm --version, fvm flutter --version, psql --version e, dopo installazione, supabase --version. Non cambiare la toolchain del repository solo perché esiste una versione più recente.

### 3.3 Foglio ambiente privato da compilare

Registrare: titolare e sostituto, organizzazione/piano, PROJECT_REF e regione, URL frontend, origine CORS, URL Edge e prefisso, schema/versione PostgreSQL, digest candidato, dominio mittente, mittente/reply-to, stato DNS, limiti effettivi, finestre pilot, Comune, destinatari ammessi, responsabili revisione/esiti/privacy, contatti incidenti, posizione copie e diario, data ultimo restore. I valori segreti restano nel gestore, indicare soltanto il riferimento.

## 4. Matrice di copertura dei requisiti

Legenda: **L** = implementazione ed evidenza locale storica, da ricollaudare sul cloud; **A** = esiste ma va adattata; **I** = da implementare; **C** = da configurare/ratificare. Tutte le righe sono bloccanti per il pilot completo salvo «condizionale» o «fuori perimetro». L non significa rilascio autorizzato. Fonti: P = piano gap §§comportamenti/gate, AC = matrice accettazione, O = OpenAPI/backend README, D = dossier, RP = piano rilascio pubblico; i collegamenti sono in §1.

| ID: requisito e fonte | Componente | Stato ed evidenza locale | Mancante: implementazione/configurazione | Prova di accettazione cloud | Blocco |
|---|---|---|---|---|---|
| R01 Comune, cataloghi e scoperta anonima senza geolocalizzazione; P, AC3, O | Flutter/API/DB | L: catalog.js, missions.test.js, municipality_catalog.dart | A/C: catalogo reale, mapping canonico e restrizione server del pilot | Lista funzionante con posizione negata; Comune diverso non concede dati privati | Sì |
| R02 Proposte, luogo, ricerca/similarità, voti, bozza/ricevuta e moderazione; O C2–C4 | NextProblems/API/DB | L: proposal-*.test.js e test/features/next_problems | A: identità JWT, rate limit persistito, recovery; C: moderatore reale; decidere promozione a voto netto 1 | Rifiuto 422, quarto invio orario 429, retry stessa ricevuta; rejected solo owner; contenuti privati esclusi | Sì; gate policy B8 |
| R03 Turno/previsioni, risultati, reputazione/insight e soglie aggregati; O, AC1 | Game/API/DB | L/A: remote-game-service.js, ApiGameRepository; riflessione legacy non interamente contrattualizzata | A/I: eliminare mutazioni legacy con userId client e completare/disabilitare esplicitamente riflessione legacy incompleta | Token assente/falso non scrive; aggregati sotto soglia nascosti; nessun API→mock | Sì per flussi esposti |
| R04 Fantasy: calendario UTC, squadra/budget/ruoli, conferma e lock; AC1 | Fantasy/API/DB | L: teams/leagues/foundation test, 48 fixture condivise | A: unità transazionale Edge e revisioni; C: stagione reale | Due conferme concorrenti, ±1 ms al lock, snapshot resta chiuso anche con orologio test arretrato | Sì |
| R05 Mercato, quote/revisione/scadenza, penalità, capitano/riflessione e classifiche; AC1/5 | Fantasy/DB | L: market/results/scoring tests | A: replay prima di CAS, lock e scadenza; preservare scoring v1/v2 | Risposta persa/restart non duplica spesa/bonus; parità 1/1/3; originali invariati | Sì |
| R06 OTP email recuperabile; P FG08, AC2 | Auth/Resend/Flutter | A: account-service.js e account.test.js con adapter simulato | I/C: Supabase SDK, template/SMTP/CAPTCHA, allowlist pilot server | Codice reale valido, errato/scaduto/riusato; stessa persona su due dispositivi | Sì |
| R07 Sessioni, refresh, logout, revoca altri dispositivi e pseudonimo; AC2, O | Auth/API/client | L/A: account_session_store.dart e authenticated_session_source.dart; bearer custom | I: JWT/refresh, registro sessioni revocabili immediatamente e UI equivalente | Access token già emesso negato dopo revoca; nuovo login distinto consentito | Sì |
| R08 Guest linking e ripresa intenti senza importare demo; P FG09, AC2/6 | Auth bridge/DB/Flutter | L: guest-link transazionale e keepAccount, account/fantasy tests | A: mappa UUID Auth, prova possesso guest, namespace/reset barrier | Retry non duplica team/XP; conflitto conserva account; invito ripreso senza adesione automatica | Sì se guest supportati; decisione B3 |
| R09 Missione: istruzioni, area, protocollo, durata/prove/XP e prenotazione; P FG01, AC3 | Missions/API/DB | L: mission-service.js, missions.test.js | A/C: contenuti reali e slot server; nessun synthetic flag come autorizzazione | Ultimo slot: 1 successo; scadenza/rinuncia liberano; prenotazione max 30 min e limite finestra | Sì |
| R10 Questionario, bozza offline, riepilogo/invio/ricevuta; AC3 | Flutter/Missions | L: noIssue/visibleWaste/nonObservable/unsure, mission_widget_test.dart | A: scope Auth, recovery oltre pagina, comportamento offline | Nessun invio automatico; doppio POST unico; account B non legge bozza/ricevuta A | Sì |
| R11 Foto private, upload riprendibile, normalizzazione, retention/orfani; P FG02, AC3/8 | Edge/Storage/DB | L solo file: local-proof-storage.js, sanitizePng, mission tests | I/C: adapter Storage, quarantena, policy, job e quote (§8) | Anonimo/B/altri Comuni negati; URL pubblico inutilizzabile; file invalidi/metadati rimossi | Sì |
| R12 Ruoli distinti, assegnazione, integrazione, rifiuto/approvazione e audit; P FG03, AC4 | Review/API/DB | L: review-service/repository e review tests | A/C: ruoli account reali/Comune, MFA e procedura nomina/revoca | Nessuna autovalidazione o giudizio su propria carta competitiva; CAS stale 409; audit attribuito | Sì |
| R13 10 XP dopo validazione, una volta per persona/luogo/finestra salvo replica richiesta; P FG07, AC4 | DB/review | L: xp_ledger, UNIQUE e review-postgres tests | A: vincoli nel porting e transazione review+XP+eventi | Nessuna criticità vale 10 come criticità; due revisori/retry sempre un accredito | Sì |
| R14 Baseline/protocolli/fonti e interventi molti-a-molti/temporanei; P FG04/05, AC5 | Measurements/DB/operatori | L sintetico: measurements.js e measurement tests | A/I/C: registro fonti reali, publisher operativo; blocco cambi dopo lock | Protocollo prima lock, unknown diverso da zero; intervento completato non implica miglioramento | Sì |
| R15 Esiti motivati/discordanti, deadline non determinabile, ricorsi/rettifiche e ricalcolo; P FG06, AC5 | Measurements/Fantasy/cron | L: publication/result revisions e test | A/I: job deadline, autorizzazioni e fonti reali | Discordanze impediscono verdetto; undeterminable ≠ stable, 0 osservazione/previsione; storico e penalità preservati | Sì |
| R16 Leghe private: max3 possedute, invito hash/scadenza/revoca e membership; P FG10, AC1 | Fantasy/API | L: leagues/continuity tests | A: JWT/antiabuso e ranking riservato | ≥3 competitori, spettatori esclusi; late join esplicito; tentativi falliti consumano quota | Sì |
| R17 Link guidato e trasferimento proprietà accettato; P FG11, AC6 | Continuity/client/DB | L: fragment capture, CAS e migrazioni 14/15 | A: URL pubblico/hash routing e sessioni Auth | Token rimosso dall'URL, fuori log; owner→membro consenziente; uscita senza trasferimento archivia | Sì |
| R18 Cooperazione deduplicata per luogo/finestra, distinta da punti fantasy; P FG12, AC7 | Cooperation/DB | L: migrazione16, cooperation tests | A: transazione e policy membership | Due osservazioni stessa unità =1; adesione tardiva non importa contributi; archivio ferma accrediti | Sì |
| R19 Inbox/follow facoltativo e secondo controllo; P FG13, AC7 | DB/Flutter/outbox | L: cooperation-events.js, read persistito multi-device | A/I: drain job recuperabile e contenuti reali | Un evento/versione/account; unfollow ferma nuovi follow; niente bonus o replica automatica | Sì |
| R20 Stagioni/giornate pubblicate esplicitamente e idempotenti; P FG14, AC7 | Publisher privilegiato/DB | L solo CLI --local-synthetic, calendar tests | I/C: canale operativo autenticato, dataset approvato | Stessa chiave replay; nuovo contenuto 409; lock ricontrollato precommit; nessun rinnovo al boot | Sì |
| R21 Minimo privilegio, RLS, isolamento Comuni, antiabuso e CORS; P/D/O | Edge/DB/Auth | A: controlli locali e bearer; migrazioni non costituiscono policy Supabase | I/C: schema privato/grant/RLS per ogni tabella/RPC e Storage; chiudere legacy/admin token | Attacchi via REST/RPC diretti falliscono anche saltando Flutter e Edge | Sì |
| R22 Cancellazione completa/retention per classi e diario; D, P FG15 | Auth/DB/Storage/ops | I: solo erasure fantasy e cleanup locali oggi | I/C: workflow §11, policy motivata, registro indipendente durevole | Account inaccessibile; oggetti e dati personali eliminati/anonimizzati secondo policy; replay su backup antecedente | Sì |
| R23 Backup/restore coerente e rollback; D, AC8 | Ops/custodi | L locale sintetico con marker/HMAC, operations.test.js | I/C: export Auth/DB/oggetti, cifratura, destinazioni e restore cloud | Nuovo ambiente non esposto; checksum, dati B intatti, A cancellato non risorge; RPO/RTO misurati | Sì |
| R24 Logging, readiness, identificativo candidato, allarmi/incidenti; D, AC8 | Edge/provider/operatori | L: diagnostics.js, test/app/diagnostics_test.dart; /diagnostics non verifica backend | A/I/C: health/readiness cloud, contatori, avvisi e reperibilità | Browser/client/API stesso nuovo digest; guasto dipendenza =non pronto, nessun segreto nei log | Sì |
| R25 Latenza, email, quote e disponibilità; P/D | Tutti | I/C: nessuna misura cloud | P1 e §10; soglie/capacità e comportamento degrado | p50/p95/freddo e consegna misurati; limiti gestiti senza perdita bozza | Sì |
| R26 Accessibilità, compatibilità, sicurezza sul luogo e comprensione; P/AC/D | Flutter/contenuti/operatori | L: layout/widget e smoke diagnostica, non certificazione umana | A/C: prove browser/mobile/tastiera/lettore schermo/testo 2x e utenti | Nessun overflow/blocco tastiera; lista senza GPS; rinuncia senza penalità; niente missioni pericolose | Sì |
| R27 Privacy, minimizzazione, responsabili, platea/fonti e capacità revisione; D/gate P | Titolare/pilot/privacy | C: approvazioni mancanti, copy demo | C/I: informativa reale, trattamento/fornitori, retention e procedure richieste | Referenti e sostituti firmati, dati reali ammessi solo dopo collaudo e decisione | Sì |
| R28 Pubblicazione sorgenti/assets/storia, licenza e dipendenze; RP/SECURITY | Titolare/GitHub | C: GPL-3.0-only e gate storico | C: diritti asset, bonifica metadati/secret scan e strategia snapshot; controlli branch | Repository pubblico senza segreti/metadati non autorizzati, licenze/attribuzioni corrette | Condizionale: blocca Pages Free se serve rendere pubblico |
| R29 Build, cache, routing, upgrade e rollback frontend; workflow/AC8 | Flutter/Pages/CI | L demo mock; workflow senza gate cloud | A/I/C: profilo cloud, test richiesti, versione/artefatto e origine (§9) | Reload URL interno e invito, client vecchio/nuovo, rollback verificato | Sì |
| R30 Evoluzioni crypto/premium/sponsor, push/mappa/premi; EVO/P | Prodotto | Solo proposte/discovery | Nessuna attivazione implicita; nuovo perimetro con requisiti/test propri | Funzioni non promesse nell'interfaccia di questo pilot | Fuori perimetro; blocca se reintrodotte senza analisi |

Ogni riga deve ottenere evidenza cloud o una decisione esplicita di esclusione coerente con UI e dipendenze. Non spegnere revisione o cancellazione per dichiarare pronto un pilot che raccoglie foto reali. La matrice copre il perimetro letto; non attesta requisiti futuri o funzionalità non analizzate.

## 5. Backend e database: lavoro tecnico prima della pubblicazione

### 5.1 P1 — prova di fattibilità obbligatoria

Prima di portare tutti gli endpoint, il tecnico realizza in locale e poi nel progetto di collaudo una funzione minima con **lo stesso percorso di produzione** per identità, transazioni e immagini. La prova deve:

1. Validare un access token Supabase reale e respingere token assente, scaduto, di altro progetto e claim alterati. Il gateway non basta: verificare il JWT con il metodo supportato dalle signing keys del progetto; controllare issuer, audience, scadenza, subject e account/sessione ammessi. La chiave pubblicabile non è una sessione utente. [Auth Edge](https://supabase.com/docs/guides/functions/auth).
2. Eseguire una lettura, due prenotazioni sull'ultimo slot, revisione con 10 XP e ricevuta nella stessa transazione; riaprire una nuova istanza e recuperare il replay. Registrare attesa lock e consumo connessioni.
3. Validare PNG fino ai limiti attuali, eliminare metadati e scrivere/leggere un oggetto privato; verificare 256 MB/2 s CPU anche per file malformati e massima espansione ammessa. Non invocare processi esterni o usare filesystem come storage. Se la normalizzazione non rientra, il target non è approvato per le foto: proporre un componente adeguato con costi e test, senza pubblicare originali.
4. Misurare latenza dopo inattività e a caldo (§10), errori/retry e costo in quota. P1 passa solo su Supabase reale, non per compatibilità teorica Deno/Node.
5. Scrivere ADR con runtime, versione CLI/librerie, modalità connessione, autenticazione, prefisso HTTP, limiti misurati e scelta RPC SQL oppure client transazionale. Se fallisce: B1 aperto, niente porting massivo/deploy operativo.

### 5.2 Componenti da creare e criteri di completamento

I nomi seguenti sono **proposti, oggi assenti**; non sono comandi/package già disponibili.

| File/componente proposto | Contenuto da realizzare | Finito quando |
|---|---|---|
| supabase/config.toml e funzioni sentinelle-api/index.ts | Entry point Edge, router /v1, OPTIONS/CORS, errori e limiti body | Contratto e test negativi di ogni route esposta; nessun import di server.js |
| supabase/functions/_shared/auth.ts | Verifica JWT e mappa auth.uid → accounts, controllo sessione/ruolo/Comune/MFA | Token body/userId/admin token non conferiscono autorità; revoca già attiva verificata |
| supabase/functions/_shared/unit_of_work.ts o funzioni SQL versionate | Singola transazione, ricevute/idempotenza/CAS e lock coerenti | Concorrenza/restart/fault senza stato parziale; pool limitato |
| supabase/functions/_shared/proof_storage.ts e proof_validation.ts | Storage privato, quarantena e sanitizzazione server, finalizzazione recuperabile | Test file/metadati/policy/CPU e orphan cleanup superati |
| Nuove migrazioni additive dopo le 16 esistenti | Mapping Auth, grant/RLS, permessi RPC, sessioni, cancellazioni e job | Manifest/ledger aggiornati, vecchie migrazioni immutate, upgrade su copia popolata |
| lib/features/account/data/supabase_account_repository.dart e session source | signInWithOtp/verifyOTP, refresh, logout/revoca, MFA e guest bridge | Sostituisce contratto simulated, conserva intenti e reset barrier |
| lib/core/config/app_config.dart e app_dependencies.dart | Nuova configurazione Auth e fonte sessione, iniezione repository | URL API con prefisso Edge, chiave pubblica esplicita, errore se cloud incompleto |
| Comandi privilegiati fonti/calendario/ruoli | Sostituiscono CLI sintetiche solo per ambienti nominati | Operatore autenticato, audit, dry-run e dataset approvato; nessun seed demo |
| Job cron e registro esecuzioni/outbox | Deadline, scadenze, retry limitato e cleanup | Doppia esecuzione non duplica punti/eventi e riprende dopo downtime |
| scripts/cloud/backup, restore, erase-account e relativi test | Nuovi strumenti con target allowlist, diario indipendente e quarantena | Ripristino completo §11; non rimozione dei guardrail degli script locali |
| CI cloud e prove contratto | Test policy/RPC/Auth/Storage, build e smoke identificati | Suite eseguite su candidato finale; nessun test distruttivo su pilot |

### 5.3 Creare i progetti Supabase e isolare gli ambienti

1. Il titolare apre [Supabase Dashboard](https://supabase.com/dashboard), crea organizzazione **Free** e progetto di **collaudo**. Usa un nome riconoscibile, password database generata nel gestore, regione UE disponibile vicina al pilot (registrare quella scelta, non assumere una regione). Attende stato Healthy; apre Billing/Usage e salva piano/quote in registro privato.
2. Dopo P1, riserva il secondo progetto attivo al **pilot/produzione**. Il limite di due include progetti eventualmente già posseduti; se occupati non crearne altri aggirando le quote. Sviluppo ordinario su Supabase locale/Docker e PostgreSQL loopback; cloud collaudo con dati sintetici; pilot con credenziali, bucket e dominio/chiavi separati. Preview frontend usa solo collaudo.
3. Registrare versione effettiva PostgreSQL; le prove locali su 17 non certificano qualsiasi versione gestita. Non cambiare regione dopo raccolta come se fosse un'impostazione innocua: può richiedere migrazione e nuovo collaudo.
4. **Prima di applicare lo schema applicativo**, in Project Settings → Data API verificare gli schemi esposti: disabilitare la Data API se il percorso scelto non la usa, oppure rimuovere l'esposizione delle tabelle applicative e revocare grant anon/authenticated prima della creazione. La configurazione deve consentire soltanto le viste/RPC deliberate; non aprire public in attesa di scrivere RLS.
5. Per connessioni aprire **Connect**. Migrazioni/backup: connessione diretta (tipicamente IPv6); se la rete è solo IPv4, session pooler supportato, da provare con dump e lock. Copiare host/porta/username reali: non comporli dalla regione. Credenziali con caratteri riservati devono essere codificate nell'URL. TLS con certificato/hostname verificati; non usare rejectUnauthorized=false. [Connessioni](https://supabase.com/docs/guides/database/connecting-to-postgres).

### 5.4 Schema e migrazioni

Le 16 migrazioni sono file JavaScript node-pg-migrate, non file SQL da incollare in SQL Editor né migrazioni native Supabase. Il manifest immutabile è services/backend/migrations/manifest.json. Famiglie: schema civico e idempotenza (1–2), luogo/sessioni/review proposte (3–5), fantasy/trasferimenti (6–7), account (8), missioni (9), review/compatibilità indici (10–11), misurazioni e proprietà risultati (12–13), continuità/creator leghe (14–15), cooperazione (16).

1. Provare prima un database locale vuoto e poi una copia popolata del candidato. Verificare sintassi/estensioni/ruoli consentiti dal servizio gestito, schema di attestazione e privilegi append-only; Supabase non concede automaticamente tutti i privilegi del superuser locale.
2. Conservare la storia e usare il migratore Node esistente per le 16 più nuove migrazioni se la prova lo conferma. Non mantenere due migratori che amministrano le stesse tabelle. Se si sceglie conversione a migrazioni SQL, serve baseline esplicita con equivalenza/ledger provata; nessun supabase db push diretto sugli attuali file JS.
3. Prima delle nuove funzionalità aggiungere mapping univoco tra auth.users.id e accounts.id applicativo, senza rimpiazzare alla cieca FK, principal testuali, ricevute o creation_key storiche. Riutilizzare UUID applicativi tramite tabella ponte; niente merge per sola email fornita dal client.
4. Nuove migrazioni creano anche ruoli runtime/DDL/attestazione, RLS/grant/RPC e tabelle operative; confrontare schema, FK validate, indici, quantità e ledger dopo upgrade. Down10/11/15 possono rifiutare stati validi popolati: prevedere restore (§12).
5. Popolare solo cataloghi, protocolli/fonti reali, missioni/finestre, nuove stagioni/giornate v2 e obiettivi approvati. Creare amministratori attraverso Auth e poi assegnare ruoli applicativi server-side con audit. Non usare seed:local, *_DEMO_SEED o fixture synthetic per il pilot. Oggi publish-calendar.js e register-measurement-source.js rifiutano legittimamente target operativi: manca il percorso reale.

Comandi **già esistenti**, dalla radice, per verifica locale. Installare Node24 prima. Non sostituiscono la prova cloud:

~~~bash
npm --prefix services/backend ci
npm --prefix services/backend run migrations:verify
~~~

Dopo aver caricato TEST_DATABASE_URL dal gestore per un database **usa e getta loopback con nome terminante _test**, la suite seguente può azzerarne lo schema:

~~~bash
npm --prefix services/backend test
~~~

Comandi esistenti ma **condizionati** per la migrazione cloud: eseguire solo dopo prova di compatibilità su collaudo, schema non esposto, ruoli/TLS preparati, backup e revisione del target. Caricare MIGRATION_DATABASE_URL e ATTESTATION_DATABASE_URL (ruolo dedicato fuori dal locale) senza stamparli; poi, dalla radice:

~~~bash
npm --prefix services/backend run migrate:up
npm --prefix services/backend run migrate:verify
~~~

Errore ledger/digest/permessi: fermare, confrontare manifest e connessione, non modificare migrazioni applicate o fare fake/no-lock. La disponibilità dei comandi nel repo non prova che i ruoli cloud siano già predisposti.

### 5.5 Transazioni, RLS e connessioni

La Unit of Work attuale usa AsyncLocalStorage, un solo client PostgreSQL e advisory lock transazionale comune 76131001. Questo serializza molto lavoro: è accettabile solo per volumi misurati. Le migrazioni usano anche lock di sessione; la connessione di attestazione deve restare stabile. Per Edge scegliere dopo P1:

- **RPC (procedura SQL invocata via API)**: spostare l'intera mutazione atomica in una sola funzione SQL; più chiamate HTTP non sono una transazione. Definire search_path fisso, input validati, privilegi EXECUTE revocati a PUBLIC e concedere solo al ruolo previsto. SECURITY DEFINER aggira parte dei controlli del chiamante: convalidare identità/Comune/ruolo anche lì.
- **Driver transazionale**: singola connessione per BEGIN…COMMIT/ROLLBACK; shared transaction pooler per richieste brevi, niente prepared statements nominati o stato di sessione persistente. Iniziare pool per worker ≤1–2, non copiare automaticamente max5 del server Node. Misurare somma di worker, job e migrazioni contro i limiti del progetto; timeout/lock brevi e rollback garantito.

Per ogni comando preservare chiave idempotente scoped a principal/operazione/Comune, hash input, risposta originale, controllo revisione (CAS: confronto con la revisione attesa) e vincoli UNIQUE. Il replay autorizzato precede CAS/scadenza dove previsto dal contratto. Evento outbox, mutazione e ricevuta devono committare insieme. Dopo timeout consultare la ricevuta con stessa chiave; non inventarne una nuova. Retry di serializzazione/deadlock solo in numero limitato con identico comando; 409 applicativo richiede riconciliazione utente. Il tempo autorevole UTC viene letto dopo lock e ricontrollato precommit per le scadenze.

RLS non è presente come protezione cloud nelle migrazioni attuali. Inventariare **tutte** le tabelle, viste e RPC, comprese received responses, ruoli, account_email_codes, audit e outbox. Tabelle interne fuori dagli schemi esposti, grant minimi; per quelle deliberatamente esposte abilitare RLS e policy SELECT/INSERT/UPDATE/DELETE esplicite. Un authenticated non deve leggere ogni account per il solo fatto di avere un JWT. Il ruolo applicativo va letto da tabella amministrata, mai user_metadata modificabile dall'utente. Separare proiezioni pubbliche da note, email, motivazioni private e fotografie.

Le chiavi secret/service_role bypassano RLS: restano esclusivamente server, con autorizzazioni applicative anche nel percorso privilegiato. Preferire contesto utente per le operazioni cui si applicano le policy. Testare direttamente Data API e RPC con chiave pubblica, JWT A, JWT B e operatore di altro Comune; controllare anche view/SECURITY DEFINER. Non basta che Flutter nasconda un pulsante. [Controlli database](https://supabase.com/docs/guides/database/postgres/row-level-security).

### 5.6 Segreti, CORS, job e deploy Edge

Inventario separato per ambiente:

| Valore | Dove | Chi può leggerlo |
|---|---|---|
| URL Supabase, chiave publishable/anon, URL API e flag/digest | Config build Flutter, visibili nel bundle | Pubblici; la sicurezza dipende da JWT/policy |
| Secret/service_role, eventuale URL DB runtime | Segreti Edge | Solo funzioni/amministratori; niente prefisso riservato inventato |
| Chiave API Resend | Impostazioni SMTP Auth | Amministratori; non serve alle API di gioco |
| Password migrazioni/attestazione e token CLI | Gestore segreti, job privato limitato | Tecnico autorizzato; non bundle o log CI |
| Chiavi backup/diario e destinazioni | Custodia indipendente | Custode e sostituto, separate dalle copie dati |
| Secret CAPTCHA | Dashboard Auth; site key nel client | Secret soltanto server; site key pubblica |

CORS (autorizzazione browser delle richieste tra origini): consentire l'origine esatta https://gabser.github.io, **senza /miglioraPaese/**; per Cloudflare l'origine di produzione esatta. OPTIONS deve funzionare senza login per gli header Authorization, apikey, Content-Type, Idempotency-Key e metodi realmente usati; esporre Retry-After e request ID. Vary: Origin e niente wildcard con credenziali. Origin assente non concede un ruolo; CORS non ferma curl né sostituisce Auth. Rivedere transport.js e gli handler Edge insieme. Non autorizzare tutte le preview su dati pilot.

Configurare **Integrations → Cron**, abilitare pg_cron/estensioni richieste, poi creare i job da migrazioni o SQL revisionato. Cron può invocare SQL o HTTP Edge; segreti di invocazione nel Vault, non nel testo SQL pubblico. [Cron](https://supabase.com/docs/guides/cron). Piano proposto da validare sul progetto Free:

| Job | Frequenza proposta | Recupero e prova |
|---|---|---|
| Scadenze prenotazioni/lock/deadline esiti | Ogni minuto, elaborazione a lotti | Calcolare arretrati dal tempo DB; due esecuzioni non duplicano; accesso controlla scadenza anche se job tarda |
| Drain outbox/inbox e lavoro foto pendente | Ogni 5 minuti, batch limitato | Lease/claim atomico, tentativi 1/5/15/60 min, max5 poi coda errori operatore; niente retry infinito |
| Retention prove, quarantena/chunk/orfani | Ogni ora, con periodo di sicurezza per upload in corso | Negare accesso già a scadenza; cancellazione byte e metadati recuperabile; fault/retry |
| Apertura calendario | Azione umana anticipata, promemoria settimanale | Stagione nuova esplicita; nessun rinnovo automatico del seed |
| Backup | Ogni giorno sul dispositivo del custode (§11) | Cron cloud non può copiare da solo sul disco locale; controllo umano dell'esito e recupero esecuzioni saltate |

Ogni job registra ultimo successo, durata, cursor e numero tentativi senza payload sensibili. Pausa progetto ferma anche job/DB: alla riattivazione elaborare arretrati prima di riaprire prenotazioni. Non usare timer del browser, setInterval nel worker o attività in background come garanzia di esecuzione. Scadenze/esiti hanno attore sistema autorizzato; non token operatore riutilizzato.

**Pubblicazione Edge futura, non eseguibile utilmente sul checkout attuale.** Prerequisiti: P1 superata, file proposti implementati, test verdi, CLI fissata, progetto collaudo corretto, schema applicato e secrets inseriti da Dashboard → Edge Functions → Secrets. Da root con progetto Supabase preparato, il tecnico potrà usare i comandi standard seguenti sostituendo il riferimento; i nomi definitivi devono essere confermati dall'implementazione:

~~~bash
supabase login
supabase link --project-ref <PROJECT_REF_COLLAUDO>
supabase functions deploy sentinelle-api --project-ref <PROJECT_REF_COLLAUDO>
~~~

Non distribuire un hello-world e considerare portato il backend. Verificare la modalità JWT del gateway con le signing keys effettive; non copiare --no-verify-jwt come soluzione a un 401. Se un endpoint pubblico lo richiede, renderlo deliberato e applicare tutti i controlli nelle route private. Fonte: [deploy funzioni](https://supabase.com/docs/guides/functions/deploy), [segreti](https://supabase.com/docs/guides/functions/secrets). L'URL futuro sarà quello restituito dal pannello; per un'unica funzione/router è tipicamente https://<PROJECT_REF>.supabase.co/functions/v1/sentinelle-api, seguito dal percorso /v1 implementato. ApiClient preserva il prefisso del base URL: testarlo, senza duplicare /v1 o rimuovere /functions/v1.

## 6. Autenticazione OTP e sessioni

### 6.1 Configurare Auth nel progetto di collaudo, poi replicare sul pilot

1. Dashboard Supabase → **Authentication → Sign In / Providers → Email**: abilitare accesso email; non attivare password/social/telefono se non servono. L'accesso passwordless usa lo stesso meccanismo dei Magic Link: il template determina se l'email presenta un link o un codice. Impostare **Email OTP expiration = 600 secondi**, proposta di progetto; reinvio non prima di **60 secondi**. La scadenza email è condivisa anche con altri flussi, comprese conferme e inviti: provarli se utilizzati. Il default documentato è un'ora, non i cinque minuti del backend locale. [Passwordless ufficiale](https://supabase.com/docs/guides/auth/auth-email-passwordless).
2. **Authentication → Email / Templates → Magic Link**: sostituire il corpo con un messaggio breve in italiano che mostri il token. Verificare anche il template effettivamente usato per il primo accesso di un account appena creato. Non pubblicare link di conferma se l'esperienza richiede il codice. Esempio di corpo, da salvare nel pannello:

   ~~~html
   <h2>Accedi a Migliora Paese</h2>
   <p>Inserisci nell'app questo codice: <strong>{{ .Token }}</strong></p>
   <p>Il codice scade tra 10 minuti. Non condividerlo.</p>
   <p>Se non hai richiesto l'accesso, ignora questa email.</p>
   ~~~

3. Collegare SMTP Resend dopo verifica dominio (§7); il provider email incluso serve solo al test del team. Non usare template o log per estrarre OTP in produzione.
4. **Authentication → URL Configuration**: Site URL del progetto pilot = URL completo frontend, per esempio https://gabser.github.io/miglioraPaese/ se confermato dal titolare. Redirect allowlist solo per callback concretamente implementati, per esempio la stessa root che carica Flutter; collaudo usa URL separati. OTP digitato non richiede un redirect per completarsi, ma link amministrativi/conferme usano ancora questa configurazione. Non inventare /auth/callback se non è gestito. Su Pages la callback deve essere una risorsa realmente servita, non un path che dà 404. Niente wildcard di preview o redirect esterno da returnTo non validato.
5. Pilot su invito: **disabilitare nuove registrazioni pubbliche sul provider**; il tecnico autorizzato precrea gli account ammessi tramite Auth Admin in un percorso privato e registra l'abilitazione al pilot. Il client usa shouldCreateUser=false. Questa opzione nel solo client non impedisce ad altri di chiamare direttamente Auth: provare la negazione su /auth/v1/signup e OTP per utente sconosciuto. Se si apre la registrazione, sostituire con controllo server/hook e allowlist verificati, non un pulsante nascosto.
6. **Authentication → Rate Limits**: fotografare valori effettivi nel registro; regolare il limite email in accordo con il piano pilot e tenere margine sotto Resend. Il limite documentato OTP è 60 s/utente; verifica e signup/signin hanno attualmente default 30 richieste/5 min per IP, refresh 150/5 min. Non sono il vecchio limite locale di 5 errori per challenge e 6 richieste email/ora: riprodurlo con controlli appropriati oppure ratificare il nuovo comportamento. Provare una rete condivisa senza bloccare tutti i collaudatori. [Rate limits](https://supabase.com/docs/guides/auth/rate-limits).
7. **Authentication → Bot and Abuse Protection / CAPTCHA**: attivare un provider supportato, per esempio Cloudflare Turnstile, creare widget per hostname frontend di collaudo/pilot, inserire secret nel pannello Auth e site key nel client. Passare il captchaToken nelle richieste SDK e testare token mancante/scaduto/falso. Seguire il [percorso CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha). CAPTCHA non limita da solo email/giorno né autorizza l'account al pilot. Disabilitare metodi Auth inutilizzati che consumerebbero quota o aggirerebbero il percorso.

### 6.2 Integrazione Flutter da implementare

Aggiungere supabase_flutter con versione scelta e lockfile aggiornato, inizializzare il client prima dei repository e introdurre configurazione URL/chiave pubblica in AppConfig. Nomi proposti SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY **oggi non letti dal codice**: passarli al build prima dell'implementazione non ha effetto. Supabase sostituisce /v1/auth/code e /verify simulati; AccountRepository oggi rifiuta delivery diverso da simulated.

Schema di chiamate Dart per l'adapter futuro, **non un file già esistente**; email, codice e captchaToken provengono dalla UI e non sono costanti:

~~~dart
await supabase.auth.signInWithOtp(
  email: email,
  shouldCreateUser: false,
  captchaToken: captchaToken,
);
final response = await supabase.auth.verifyOTP(
  email: email,
  token: codice,
  type: OtpType.email,
);
~~~

Fonti: [SDK Dart richiesta](https://supabase.com/docs/reference/dart/auth-signinwithotp), [verifica](https://supabase.com/docs/reference/dart/auth-verifyotp). L'SDK e la versione scelta vanno provati nel repository; la risposta alla richiesta del codice non è ancora una sessione. UI: campo numerico con incolla e zeri iniziali, conto alla rovescia coerente col server, correzione email, feedback generico che non enumera account, conservazione di missione/invito e nessun invio automatico dopo login. Non memorizzare OTP; nessun analytics sul campo.

Il JWT di accesso autentica le API. Il refresh token permette all'SDK di rinnovarlo; ascoltare gli eventi di sessione e invalidare dati/cache/repository quando cambia identità. Un 401 tenta il rinnovo in modo coordinato una sola volta, poi richiede nuovo accesso; non ritentare una mutazione con nuova chiave. Sessione in browser è esposta al rischio di script malevoli: vietare HTML arbitrario nei contenuti, ridurre script terzi, testare protezione da inserimento di codice e svuotare dati privati al logout. Nessun refresh token nel build o nei log.

### 6.3 Logout e revoca: requisito da mantenere

Supabase usa access token a breve durata e refresh token. Revocare refresh/logout non annulla magicamente ogni JWT già emesso fino alla scadenza. Le opzioni gestite di timeout/singola sessione non sono tutte Free. [Sessioni](https://supabase.com/docs/guides/auth/sessions), [signout](https://supabase.com/docs/guides/auth/signout).

Per mantenere la revoca immediata verificata nel backend locale serve un registro applicativo di sessioni autorizzate, legato al session_id verificato del JWT, con stato attivo/revocato, e controllo su **ogni** percorso privato, comprese RPC/RLS e firma URL Storage. Non creare automaticamente di nuovo una sessione già revocata al primo uso del vecchio token. La UI «dispositivi» attuale non è fornita automaticamente dal nuovo SDK: adapter/backend devono consentire elenco e revoca soltanto delle proprie sessioni. Scegliere e documentare durata token e frequenza di rilettura ruolo, poi testare token copiato prima della revoca, anche con chiamata diretta alla Data API.

Al logout: bloccare nuove mutazioni, registrare revoca applicativa, invocare signOut con ambito deciso (locale, altri, globale), quindi cancellare sessione e dati privati locali; distinguere «non posso contattare il server, logout locale eseguito» da «revoca remota confermata». Le bozze da preservare richiedono scope/consenso e protezione, non restano accessibili ad altro account. Una sessione scaduta non deve far perdere la ricevuta ancora recuperabile dopo nuovo accesso.

### 6.4 Ospiti e account preesistenti

Il guest attuale è un bearer custom di proposal-session, non un utente anonimo Supabase. Per il pilot proporre esplorazione pubblica senza creare account anonimi; se vengono mantenute scritture guest, definirne le sole capability consentite e la prova server di possesso al collegamento. Se i dati sono soltanto sintetici, partire da account pilot nuovi senza migrare demo, dichiarandolo prima agli utenti. Se si promette continuità degli ospiti, R08 è obbligatorio: mappa transazionale, conflitto esplicito keepAccount e test di non duplicazione, alias/revoche/storico compresi.

Per eventuali account reali preesistenti: censire provenienza/consenso, verificare titolarità tramite nuovo OTP, collegare a principal interno con operazione auditata; non caricare codici simulati o credenziali vecchie in Auth e non fondere due persone per email client. Non importare snapshot browser, punteggi mock o fonti sintetiche. La decisione sulla migrazione è B3.

### 6.5 Operatori e MFA

I ruoli applicativi nel codice comprendono moderazione/verifica e outcomesSupervisor, assegnati per Comune tramite tabelle e CLI locale. Il tecnico deve portare la nomina/revoca in un canale amministrativo autenticato e auditato; nessuna autoattribuzione dal profilo o dal JWT user_metadata. L'organizzatore di lega non è un verificatore.

Attivare per gli operatori MFA con codice temporale da app autenticatore (TOTP) e richiedere livello aal2 sulle operazioni privilegiate, verificato anche dal server/policy. Implementare enrollment, challenge e verifica nell'interfaccia; il solo interruttore del pannello non protegge le route. Provare OTP email senza TOTP → negato, TOTP verificato → ruolo/Comune corretti, ruolo rimosso → subito negato. Piano di recupero fattore perso con verifica umana e audit; custodia di recupero affidata a titolare/sostituto, senza backdoor permanente. [MFA](https://supabase.com/docs/guides/auth/auth-mfa). La MFA del pannello Supabase/GitHub/Resend è distinta da quella degli operatori nell'app.

## 7. Resend, dominio mittente e DNS

### 7.1 Percorso senza dominio acquistato

Resend richiede dominio controllato e verificato, supporta sottodomini e non offre gratuitamente un dominio proprietario. I sottodomini di hosting github.io/pages.dev non consentono i record DNS di verifica. Non usare Gmail/Outlook come From sperando che la password SMTP Resend li autorizzi. [Domini Resend](https://resend.com/docs/dashboard/domains/introduction).

| Opzione | Azione concreta | Evidenza attuale e decisione |
|---|---|---|
| Sottodominio di un'associazione/partner che possiede un dominio | Titolare ottiene autorizzazione per auth.<DOMINIO_PARTNER>; amministratore pubblica i record Resend nel proprio DNS oppure delega una zona a un DNS idoneo | Percorso tecnicamente praticabile a costo aggiuntivo zero **se un partner lo concede**; nessun partner o nome disponibile è stato accertato. Verifica Resend e consegna restano obbligatorie |
| EU.org | Consultare nic.eu.org, creare account/richiesta seguendo requisiti e DNS indicati dal servizio; attendere approvazione, poi provare verifica Resend | Il [sito ufficiale](https://nic.eu.org/) offre domini gratuiti. Non verificati disponibilità del nome, tempi di approvazione, controllo operativo né accettazione Resend; non dipendenza affidabile con data di lancio fissata |
| deSEC/dedyn.io | Esaminare signup e condizioni prima di richiedere un nome | [Signup ufficiale](https://desec.io/signup?domainType=dynDNS): un nome/account, uso dynDNS residenziale, aggiornamenti IP regolari, delega NS non consentita. DNS gratuito non implica adeguatezza per email di questo prodotto. Disponibilità/registrazione e Resend non provate: non scelto per il pilot |
| DuckDNS | Verificare API DNS richieste da Resend | La [specifica ufficiale](https://www.duckdns.org/spec.jsp) applica lo stesso TXT ai sotto-sottodomini: non è gestione indipendente generale dei record DKIM/SPF/DMARC e MX. Non adottato come soluzione garantita |
| Dominio proprio acquistato | Solo il titolare può approvare costo iniziale, rinnovo, intestazione e DNS | Alternativa concreta ma fuori dal vincolo zero; nessun prezzo promozionale assunto |

**Esito attuale: inviare OTP a utenti reali a costo zero non è ancora dimostrato.** Prima scelta operativa: ottenere dal partner controllo del sottodominio e verificare realmente Resend. Se manca, la demo mock resta pubblicabile dopo i gate relativi; il test Resend rimane sul proprio indirizzo; il pilot OTP resta bloccato. Un cambio a OAuth o altro SMTP sarebbe una nuova decisione di prodotto, non soddisfa da solo il requisito «codice email via Resend».

Cloudflare DNS Free può gestire record dentro una **zona già posseduta**. Non presumere di poter aggiungere qualunque sottodominio delegato come zona indipendente Free: il prodotto Cloudflare «Subdomain setup» è Enterprise. Nel caso partner, usare i record nella zona che il partner già gestisce o un DNS con delega compatibile, senza migrare i suoi nameserver soltanto per questa guida. [Disponibilità subdomain setup](https://developers.cloudflare.com/dns/zone-setups/subdomain-setup/).

### 7.2 Creare account e aggiungere il dominio

1. Titolare apre [Resend](https://resend.com), registra account, verifica la propria email, seleziona **Free transazionale**. In Billing controlla quota effettiva, eventuali restrizioni e assenza di trial/piano a pagamento/overage. I termini consultati permettono Free senza dati di fatturazione; se il percorso reale chiede carta o differisce, fermare e registrare la condizione, non accettare un trial per proseguire.
2. Abilitare MFA account quando disponibile, invitare il tecnico, nominare il custode delle chiavi; registrare il limite effettivo dei domini. Non presumere il vecchio limite storico di un solo dominio: la pagina prezzi ora ne indica tre; usare comunque quanto assegnato al proprio account.
3. **Domains → Add Domain**: inserire esclusivamente il dominio/sottodominio autorizzato; scegliere regione di invio fra quelle disponibili e annotarla. Per separare reputazione e posta esistente è preferibile un sottodominio dedicato. Lasciare tracking apertura/click disattivato per OTP. Non attivare ricezione email se non progettata.
4. Salvare l'elenco dei record mostrati dal pannello: tipo, nome completo, valore, priorità e TTL (tempo di cache DNS). Sono specifici di dominio/account/regione. **Nessun valore DKIM/MX/SPF specifico viene inventato in questa guida**.

### 7.3 Pubblicare DNS senza danneggiare la posta esistente

SPF dichiara gli invii autorizzati per il dominio di envelope/Return-Path; DKIM firma il messaggio; DMARC indica trattamento degli invii non allineati e rapporti. Usare il dominio verificato nel campo From; Reply-To è il destinatario delle eventuali risposte, distinto dal Return-Path tecnico.

| Record | Necessità e funzione | Azione/verifica |
|---|---|---|
| DKIM: TXT o tipo esatto mostrato da Resend, selector sotto _domainkey | Obbligatorio per verifica/firma secondo pannello | Copiare senza cambiare chiave; usare selector e nome completi effettivi |
| SPF: TXT sul dominio Return-Path indicato | Obbligatorio nel percorso di invio richiesto | Se esiste già SPF allo **stesso nome**, non creare un secondo v=spf1: far revisionare una policy unica all'amministratore. Non aggiungere include al root se Resend chiede un sottodominio diverso |
| MX sul Return-Path indicato | Richiesto per feedback/bounce nel percorso mostrato | Non sostituire gli MX della posta del partner. MX per bounce non crea una casella utenti |
| DMARC: TXT sotto _dmarc del dominio pertinente | Raccomandato per autenticazione/reputazione, distinto dai record obbligatori di verifica | Esaminare policy ereditata e allineamento; iniziare in monitoraggio se approvato, poi quarantine/reject dopo prove. Niente report rua verso casella inesistente o di terzi non autorizzata |
| MX ricezione, eventuali record tracking | Opzionali, solo se quei servizi sono deliberatamente attivati | Non aggiungerli per il semplice invio OTP; possono deviare la posta o introdurre tracciamento |

Procedura Cloudflare per zona esistente (con altro DNS usare funzioni equivalenti):

1. Esportare/inventariare i record esistenti del nome interessato; il titolare DNS verifica che non si tocchino posta e servizi del dominio padre.
2. Cloudflare Dashboard → dominio → **DNS → Records → Add record**. Selezionare tipo copiato da Resend, nome relativo alla zona corretta, Content/Target e Priority esatti, TTL Auto salvo diversa indicazione. Evitare suffisso duplicato: auth.partner.example.partner.example è errato.
3. Record mail non devono essere proxati; eventuali CNAME richiesti in **DNS only**. Non sostituire record di altri selector o dell'apice. Non aggiungere CNAME su un nome che ha già TXT/MX incompatibili.
4. Ripetere per ogni record richiesto e confrontare nome completo risolto con quello del pannello Resend. Interrogare DNS autoritativo e poi un resolver pubblico. I seguenti sono comandi di sola verifica, da compilare con i **nomi effettivi**, eseguibili su macchina con dig:

   ~~~bash
   dig +short TXT <NOME_FQDN_DKIM_DAL_PANNELLO>
   dig +short TXT <NOME_FQDN_SPF_DAL_PANNELLO>
   dig +short MX <NOME_FQDN_RETURN_PATH_DAL_PANNELLO>
   dig +short TXT <NOME_FQDN_DMARC_SE_CONFIGURATO>
   ~~~

5. Resend → dominio → **Verify DNS Records**. Attendere propagazione e stato Verified per invio; controllare ogni record, non soltanto che il nome risolva A/AAAA. Fonte [guida DNS Cloudflare di Resend](https://resend.com/docs/guides/dns/cloudflare), [DMARC](https://resend.com/docs/dashboard/domains/dmarc).
6. Pending/failed: verificare zona autoritativa/NS, nome relativo, TXT completo, selector, priorità e propagazione; non cambiare a caso tutti i DNS. Se già registrato o dominio condiviso rifiutato, il titolare risolve proprietà/supporto o sceglie altro dominio. Questo esito mantiene B2 aperto.

Nessun esempio DMARC pronto da copiare: policy e indirizzo rapporti richiedono scelta del titolare. Non indebolire una policy esistente a p=none senza valutarne effetto sugli altri invii.

### 7.4 Chiave e SMTP Supabase

1. Resend → **API Keys → Create API Key**: nome che identifica ambiente/uso, permesso di solo invio e dominio ristretto quando disponibile; scadenza/rotazione documentate. Salvare subito il valore nel gestore segreti (potrebbe essere mostrato una sola volta). Non usare chiave Full Access nel browser. [Permessi chiavi](https://resend.com/docs/api-reference/api-keys/create-api-key).
2. Supabase progetto giusto → **Authentication → Email, sezione Notifications → SMTP Settings** → abilitare SMTP personalizzato. Inserire:

   | Campo | Valore |
   |---|---|
   | Host | smtp.resend.com |
   | Port | 465 con TLS |
   | Username | resend |
   | Password | Chiave API di invio Resend del gestore segreti |
   | Sender email | <MITTENTE_NEL_DOMINIO_VERIFICATO> |
   | Sender name | Migliora Paese — Sentinelle, oppure nome approvato |

3. Salvare, controllare limite Auth email e template §6, poi provare tramite il vero flusso signInWithOtp. La [procedura ufficiale SMTP](https://resend.com/docs/send-with-supabase-smtp) conferma questi parametri. Non è un comando SMTP da eseguire nella funzione Edge: Auth esegue l'invio.
4. Scegliere un indirizzo di risposte realmente presidiato. Il From può essere un indirizzo sul dominio verificato senza mailbox corrispondente: questo abilita l'invio, **non prova ricezione delle risposte**. La configurazione SMTP documentata espone mittente e nome, non garantisce un campo Reply-To. Se il pannello/versione non lo supporta, il requisito Reply-To personalizzato necessita hook di invio Auth oppure una mailbox funzionante al From; verificarlo sulle intestazioni reali. Un link di assistenza nel corpo aiuta ma non cambia l'header Reply-To.
5. Resend dispone anche di ricezione/inbox, ma l'abilitazione richiede DNS e gestione separati, e gli invii/ricezioni possono consumare quota transazionale; non è automaticamente una casella umana IMAP. Per il pilot è preferibile un contatto già presidiato e approvato, senza attivare ricezione durante il setup SMTP. [Ricezione Resend](https://resend.com/docs/dashboard/receiving/introduction).

### 7.5 Test email e controllo abusi

Il dominio di test resend.dev invia solo all'indirizzo del proprio account, secondo la [restrizione ufficiale](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain). Il suo successo non prova invio a partecipanti esterni, controllo DNS, reputazione o SMTP del dominio finale.

Dopo dominio Verified, con autorizzazione al collaudo inviare OTP reali a pochi indirizzi controllati Gmail/Outlook e un altro provider, rispettando quota e reinvio. Registrare richiesta, accettazione Auth/SMTP, evento Resend e ricezione osservata; controllare spam, DKIM/SPF/DMARC nelle intestazioni e corretto mittente/reply-to. Provare risposta verso l'indirizzo assistenza presidiato. «Delivered» significa accettazione da parte del server destinatario, non visualizzazione in posta in arrivo.

Provare anche indirizzo errato, destinatario con soppressione/bounce, errore SMTP/chiave revocata e quota simulata nel collaudo. Non generare spam o centinaia di invii per esaurire realmente il piano. Il tecnico controlla **Resend → Emails / Logs e Suppressions** e Auth logs; non rimuove soppressioni senza correggere causa/indirizzo e verificare liceità dell'invio. UI offre assistenza e nuovo tentativo dopo il tempo consentito; non espone l'esistenza di un account né reinvia in loop. Per osservare bounce via webhook serve endpoint verificato con firma, idempotenza e segreto server: non è implementato oggi; in pilot minimo è richiesto almeno controllo quotidiano umano degli eventi.

Capacità proposta: **20 partecipanti iniziali**, accessi scaglionati, budget operativo 60 email/giorno e 1.800/mese per lasciare margine a reinvii/errori/test e altri flussi; non è una quota provider aggiuntiva. Con limite Auth iniziale 30/ora non programmare 50 primi accessi nello stesso minuto. Un limite orario da solo non assicura quello giornaliero: implementare un contatore/blocco globale verificato sul percorso Auth, compresi endpoint diretti, oppure mantenere una platea capace di stare nel peggiore caso e sorveglianza prima della soglia. Il contatore nel solo client non è difesa da abusi.

## 8. Fotografie e Storage privato

### 8.1 Creare bucket e policy

1. Dopo migrazioni e identità, Supabase → **Storage → New bucket**: creare, come nomi proposti da confermare nel codice, sentinelle-proof-staging e sentinelle-proofs. Lasciare **Public disattivato** per entrambi. Registrare ID, ambiente, limite file e MIME. Non creare un bucket pubblico per semplificare visualizzazione o CORS.
2. Limite applicativo attuale: **3 prove per prenotazione, 2 MiB/prova**, PNG finale RGB/RGBA 8 bit non interlacciato, lato ≤4096, ≤4 milioni di pixel; il picker accetta JPEG/PNG ma il client normalizza prima dell'upload. Il limite provider di upload più alto non modifica queste regole. La normalizzazione client è utile ma server deve rifare controlli contenuto/dimensione/espansione e rimuovere metadati. Non promettere supporto HEIC automatico: verificare fotocamera mobile reale e dare errore/conversione chiari.
3. Storage → Policies: nessuna SELECT/list globale per anon o authenticated, nessun UPDATE/upsert libero di oggetti finalizzati, nessun DELETE diretto client. Staging upload solo al percorso assegnato dal server dopo prenotazione attiva, possesso account, quota/numero prove e scadenza. I percorsi usano UUID opachi, non email, note o nome file originale.
4. L'autore attivo può leggere solo le proprie prove ammesse; verificatori solo osservazioni/Comuni e assegnazioni previsti; responsabile esiti con ambito necessario. Pubblico: solo sintesi approvate senza oggetti privati. Se si espongono policy dirette, collegarle al registro di dominio e sessioni, non al solo prefisso scelto dal client. [Controllo accessi Storage](https://supabase.com/docs/guides/storage/security/access-control).

### 8.2 Ciclo upload e finalizzazione da implementare

Oggi upload custom a chunk JSON/base64, stato receivedBytes e lettura base64 passano dal Node/filesystem; non diventano TUS copiando l'URL. Dopo P1 scegliere e documentare una delle modalità coerenti col contratto: adapter equivalente del protocollo attuale oppure upload recuperabile Supabase **TUS** con nuove dipendenze/mapping e test. TUS è un protocollo di ripresa upload supportato dal provider, non una funzione già presente nei repository Dart. [Upload recuperabili](https://supabase.com/docs/guides/storage/uploads/resumable-uploads).

Ciclo richiesto, in entrambi i casi:

1. Backend prenota una proof con ID/scadenza, limite dichiarato e percorso staging; autorizza solo quell'upload. Nessuna elevazione di ruolo tramite nome del file.
2. Client carica, salva intento scoped e riprende dallo stato server dopo interruzione; stessa chiave/offset/contenuto non duplica, contenuto differente confligge. Staging non è consultabile da pubblico o altro utente.
3. Finalizzatore autenticato legge l'oggetto, verifica PNG completo/CRC/pixel stream/limiti, ricomprime e scarta EXIF/GPS/testo/altri chunk accessori; salva nuovo oggetto finale immutabile con digest SHA256, dimensioni/dimensione e versione protocollo. Vietare SVG, HTML, file con falso MIME e immagini che eccedono memoria/CPU.
4. Solo dopo verifica il DB marca finalized; invio osservazione ammette esclusivamente prove finalizzate di quella prenotazione/account e ancora entro retention. Esito DB e Storage non sono una singola transazione: usare stati persistiti e compensazione/riconciliazione. Se l'oggetto è salvato ma DB fallisce, il job elimina l'orfano; se il DB è pronto ma manca il file, readiness/consultazione segnala errore e l'operatore indaga.
5. Dopo commit cancellare staging e chunk grezzi con retry; questi possono contenere metadati sensibili. Mai restituirli al pubblico né sostituirli alle immagini sanificate in caso di errore.
6. Ricevuta conserva digest/metadati minimi, non URL pubblico permanente. I contenuti fotografici possono contenere volti/targhe anche senza EXIF: servono istruzioni, revisione umana e oscuramento/rifiuto appropriato prima di qualsiasi sintesi pubblica.

### 8.3 Download, retention e quote

Preferire download autenticato/proxy con controllo sessione e Cache-Control: no-store per prove private. URL firmato è una capability trasferibile: chi lo possiede lo usa fino a scadenza anche dopo logout. Se necessario, TTL proposto **60 secondi**, firma solo dopo controllo autorizzazioni/retention, non salvare token in log o DB pubblico, rimuovere referer e non includere URL in analytics. Se serve revoca immediata anche dei byte già autorizzati, usare proxy autenticato e non URL firmati; nessuna soluzione impedisce a chi ha già visto una foto di conservarne copia.

Retention proposta da ratificare: quarantena/pezzi non completati 24 ore; prove finali 14 giorni salvo pratica di revisione/ricorso con conservazione motivata e approvata. Il locale ammette 1–30 giorni: i valori definitivi vanno allineati a policy e capacità di revisione, non copiati come obblighi legali. Alla scadenza negare lettura/firma anche se il job non è ancora passato; eliminare byte, versioni/chunk/staging e infine riferimenti, con job ripetibile. Non eliminare prove di pratica aperta per recuperare spazio senza una regola approvata.

Ogni ora confrontare catalogo oggetti paginato con riferimenti DB e stati upload; segnare orfani, rispettare una finestra che non colpisca upload in corso, eliminare via **Storage API**, non con DELETE su storage.objects che lascerebbe i byte. Conservare metadati audit ammessi e il registro di cancellazione. Il recupero dopo fault deve mantenere isolamento e riconciliare i casi parziali.

Dimensionamento prudente: 100 osservazioni ×3 foto ×2 MiB =600 MiB, **più** staging/chunk/duplicati temporanei: vicino a 1 GB. Proposta avviso al 70%, blocco nuove prenotazioni con foto al 90% proiettato, margine per completare quelle già accettate; limite per account e per giornata anche sul server. Download di revisori e backup consumano egress; 100 foto rilette più volte non sono traffico gratuito illimitato. Non usare bucket pubblici/caching aggressivo per ridurre quote di prove private.

Test obbligatorio: con browser senza sessione, account B e operatore di altro Comune provare lista, download, URL /object/public, firma, update/delete e percorso contraffatto. Tutti negati o senza dati; autore e operatore autorizzato leggono soltanto le prove ammesse. Verificare Public=false anche dopo restore e ricreazione bucket.

## 9. Flutter web e pubblicazione

### 9.1 Stato dei profili e gate di build

Il default AppConfig è gioco/proposte mock e feature Sentinelle spente. .github/workflows/pages.yml costruisce **solo quella demo**, con base /miglioraPaese/: pubblicare il workflow invariato non abilita il pilot. I repository API già esistono per Game, NextProblems, Fantasy, Account, Missions, Review, Measurements, Continuity e Cooperation, ma gli ultimi usano identità/trasporti del backend locale. Nessun fallback API→mock è accettato.

Le flag client attuali sono GAME_DATA_SOURCE, NEXT_PROBLEMS_DATA_SOURCE e FANTASY_DATA_SOURCE (mock/api); FANTASY_MODE_ENABLED, ACCOUNT_MODE_ENABLED, MISSIONS_MODE_ENABLED, REVIEW_MODE_ENABLED, MEASUREMENTS_MODE_ENABLED, LEAGUE_CONTINUITY_MODE_ENABLED e COOPERATION_MODE_ENABLED; API_BASE_URL, PILOT_MUNICIPALITY_ID, CANDIDATE_ID. Non sono le stesse dei flag server *_ENABLED. AppConfig controlla dipendenze: cooperazione richiede account/missioni/review/misurazioni e fantasy API, misurazioni richiedono review/missioni/account e fantasy API, continuità richiede fantasy API. Il Comune del client non sostituisce il vincolo server.

Dalla radice, con Flutter selezionato e lockfile coerente, questi sono comandi **esistenti** di verifica. flutter test include prove PostgreSQL quando predisposte: usare solo TEST_DATABASE_URL loopback usa e getta, Node24 e root Storage private richieste dai test; non la connessione Supabase.

~~~bash
fvm flutter pub get --enforce-lockfile
fvm dart format --output=none --set-exit-if-changed .
fvm flutter analyze --no-fatal-infos --no-fatal-warnings
fvm flutter test
~~~

Senza FVM usare flutter/dart dell'installazione 3.47.5. La CI corrente Flutter non ha il servizio PostgreSQL configurato nel workflow backend separato: verificare se le suite di integrazione vengono saltate e aggiungere job dedicato con PostgreSQL/Node24 prima di dichiarare gate cloud completo. I risultati locali storici non colmano questo eventuale salto in CI.

Costruzione già disponibile della **demo mock**, da radice:

~~~bash
fvm flutter build web --release --base-href /miglioraPaese/
~~~

Per il profilo Sentinelle cloud, dopo il porting, il comando dovrà includere tutte le flag necessarie sopra, URL API finale, Comune approvato, nuovo CANDIDATE_ID e i nuovi parametri Auth implementati. Non forniamo un comando apparentemente pronto che usa SUPABASE_URL prima che AppConfig lo legga. Il tecnico deve salvare comando completo effettivo in un manifest di build e nel nuovo workflow; i criteri sono assenza di adapter simulated/local-synthetic, repository reali e test di accesso al cloud con quel binario.

### 9.2 GitHub Pages — percorso principale

1. Titolare: verificare piano e visibilità repository. Pages Free richiede repository pubblico; la cronologia corrente contiene metadati privati secondo RP. Risolvere gate storia/assets senza cambiare visibilità in automatico. Se non si vuole/può pubblicare il sorgente e non c'è un piano idoneo, **B9** blocca Pages a costo zero: usare l'alternativa Cloudflare con artefatto locale.
2. Nel repository GitHub → **Settings → Pages → Build and deployment → Source: GitHub Actions**. Annotare URL effettivo del sito; per owner/repo attuali è previsto https://gabser.github.io/miglioraPaese/. Non assumere l'URL se cambia repository/owner. Abilitare HTTPS quando disponibile.
3. Preparare una modifica revisionata a .github/workflows/pages.yml: mantenere Flutter 3.47.5 e lockfile, ma rinominare chiaramente il profilo se diventa pilot; build con flag effettive e dati Auth pubblici, nuovo identificativo, controlli prima dell'upload. Il workflow attuale su push main può pubblicare anche senza dipendere dai job Flutter/backend: aggiungere dipendenze/check obbligatori o trigger dopo verifica candidato, evitando di rilasciare mentre i test falliscono.
4. Permessi necessari già presenti: contents:read, pages:write, id-token:write. Environment github-pages con restrizione al ramo/revisione autorizzati. La pubblicazione standard usa GITHUB_TOKEN/OIDC (identità temporanea del job), non un Personal Access Token personale nel bundle. Le chiavi Supabase pubbliche possono essere repository/environment variables; i veri segreti cloud non servono al build. Per un futuro job backend usare environment separato e token limitati, niente segreti alle pull request non fidate.
5. Mantenere upload-pages-artifact su build/web e deploy-pages; eseguire workflow autorizzato sul nuovo commit che include **tutti** i file del candidato, non solo HEAD storico. Annotare run URL, commit/digest, flag, hash artefatto e URL finale. Conservare una copia privata riproducibile dell'artefatto precedente per rollback senza dipendere dalla retention CI.
6. Aprire root e /#/diagnostics dal browser, controllare identità build e API/readiness separatamente. Verificare login, missione/invito, ricaricamento e cache. Non consegnare un sito che funziona solo nella sessione del tecnico.

### 9.3 Base path, routing, inviti, Auth e CORS

Flutter usa per default hash routing; nel codice letto non viene selezionata una strategia path. Tenere URL come **/miglioraPaese/#/missions** su Pages: il frammento non viene richiesto al server e il refresh carica index.html. **/miglioraPaese/missions** può dare 404. Per supportare path puliti serve rewrite hosting o una soluzione 404 esplicitamente progettata/testata, non il semplice uso di go_router. [Strategie URL Flutter](https://docs.flutter.dev/ui/navigation/url-strategies).

Base href deve iniziare e finire con slash e corrispondere al percorso del sito. Se il sito diventa root o cambia nome repository, ricostruire con base corretta: non correggere a mano un singolo asset del build. Su Pages non c'è un web server configurabile per ogni rewrite/header; non contare su _redirects di Cloudflare.

Gli inviti catturano il frammento speciale #league-invite=... e lo rimuovono prima della navigazione; non è equivalente a #/league-invite. Testare il link prodotto da invite_link_web.dart sul percorso reale Pages, con login richiesto, refresh e perdita rete. Dopo bootstrap nessun token resta in URL/log e la pagina mostra un riepilogo prima del join. Non introdurre query token che finiscano in log server, referer o screenshot.

Mappa ambiente:

| Campo | GitHub Pages | Cloudflare alternativo |
|---|---|---|
| Base Flutter | /miglioraPaese/ se repo invariato | / |
| Site URL Auth | https://gabser.github.io/miglioraPaese/ se confermato | https://<NOME_EFFETTIVO>.pages.dev/ |
| Origine CORS | https://gabser.github.io | https://<NOME_EFFETTIVO>.pages.dev |
| Redirect Auth | Root/callback effettivamente servita e approvata | Root/callback effettivamente servita e approvata |
| Backend | URL Edge completo con prefisso, HTTPS | Stesso contratto, ambiente scelto esplicitamente |

Il cambio di hosting cambia origine browser e spazio di preferenze/sessioni: nuovo login e possibile perdita delle sole bozze locali non sincronizzate. Le prove non sono copiate su Pages. Non autorizzare automaticamente entrambe le origini se una è stata ritirata; mantenere solo quelle deliberatamente supportate.

### 9.4 Cloudflare Pages — alternativa separata

1. Titolare crea account Free senza selezionare add-on. Tecnico prepara un **nuovo build** Flutter con base / e le stesse configurazioni cloud già implementate/testate; non riciclare il build Pages con /miglioraPaese/.
2. Dashboard Cloudflare → **Workers & Pages → Create application → Pages → Direct Upload / Drag and drop**; dare nome, caricare contenuto della directory build/web o zip il cui index.html sia in root, confermare deployment. Il menu può mostrare prima Get started. Non selezionare un Worker backend pensando che esegua Node.
3. Verificare limiti: drag-and-drop massimo **1.000 file**, Wrangler 20.000 e 25 MiB per file; contare e controllare tutti gli asset. Direct Upload non si converte direttamente in integrazione Git: per quella scelta servirebbe nuovo progetto. [Procedura ufficiale](https://developers.cloudflare.com/pages/get-started/direct-upload/).
4. Se servono più file, usare una versione Wrangler fissata e revisionata per caricare la cartella, oppure integrazione Git con build Flutter predisposta; non cancellare file Flutter necessari per entrare nel limite. Il repository oggi non ha workflow Cloudflare né pin Wrangler.
5. Annotare hostname **assegnato**, che può differire dal nome desiderato; aggiornare Site URL, redirect, CAPTCHA e CORS. Preview deve usare collaudo e non cookie/dati pilot.
6. Con hash routing basta servire index e asset; se si passa a path routing, progettare fallback SPA (app a pagina singola), verificando comportamento 404 e ogni link diretto. Qualsiasi _redirects/_headers deve essere incluso esplicitamente nell'artefatto e provato; il build corrente non lo garantisce.
7. Conservare deployment precedente e prova di rollback dalla lista Deployments, tornando a un deployment compatibile con API/schema. I log e la riuscita upload non sono collaudo Auth/foto.

### 9.5 Cache, aggiornamenti e segreti

Il build Flutter può includere service worker e cache. Non assumere che un refresh leggero aggiorni il codice; provare prima accesso pulito e poi un browser che ha installato la versione precedente. Se resta vecchia, usare gli strumenti browser per ispezionare service worker/cache, correggere la strategia di aggiornamento e offrire ricaricamento esplicito dopo salvataggio bozze. Non suggerire come unica procedura «cancella tutti i dati»: può distruggere intenti e recovery guest. Non cambiare il comportamento PWA senza test su aggiornamento/rollback.

Distribuire index/bootstrap e asset come un unico artefatto, senza mischiare versioni. Nessuna risposta API privata/foto/sessione in cache offline. Ogni build deve mostrare digest e profilo in /diagnostics; confrontare anche identità API/readiness, perché la pagina diagnostica attuale espone solo config locale.

Prima dell'upload ispezionare configurazioni e bundle per service_role/secret, database URL, SMTP/Resend key, OTP e credenziali. L'assenza di stringhe note non sostituisce revisione della pipeline. Chiave publishable e URL progetto sono pubblici; considerare abusabili tutti gli endpoint raggiungibili con essi. Non inserire file .env o backup nell'artefatto.

## 10. Requisiti non funzionali ed esercizio

### 10.1 Misure di prestazione e disponibilità

Obiettivi **proposti**, da ratificare prima del pilot: prima operazione applicativa dopo inattività ≤3 s, richieste successive p95 ≤1 s su rete/regione dichiarate; consegna OTP p95 ≤60 s e assenza di perdite nelle prove campionate. Non sono SLA (impegni contrattuali di servizio) dei piani Free. Il progetto può essere sospeso anche se le funzioni hanno tempi buoni: un cold start Edge e Resume dell'intero progetto sono misure diverse.

Protocollo di misura da eseguire nel collaudo cloud con dataset/concorrenti simili al pilot:

1. Registrare candidato, regione DB/funzione, ora UTC, browser/dispositivo, rete, dimensione dati, operazione e stato iniziale. Sincronizzare orologi; nessun clock artificiale nel pilot.
2. A caldo: dopo riscaldamento dichiarato raccogliere almeno 30 campioni per lettura catalogo, prenotazione, invio e revisione/XP, includendo tempo client totale e tempo server, p50/p95/massimo e numero errori. Separare upload foto da transazione; testare carico simultaneo del pilot entro quote.
3. Dopo inattività: ripetere almeno 5 prime richieste a intervalli dichiarati (per esempio 30 min e una notte), senza ping di warm-up. Chiamarle «prime richieste dopo inattività», non cold start certo se il provider non espone nuova istanza. Rilevare eventuale worker nuovo e cache separatamente.
4. Pausa progetto: prova dedicata sul collaudo con backup, non sul pilot in raccolta; registrare durata di Resume e primo flusso completo. Se non si può forzare/riprodurre, marcare scenario non provato e mantenere procedura manuale/gate disponibilità.
5. Email: timestamp click richiesta, risposta Auth, evento Resend accettato/consegnato e ricezione effettiva nella casella; almeno 10 campioni scaglionati su più provider, senza superare quote. Misurare p50/p95 e casi spam/bounce; consegna via SMTP non significa arrivo immediato.
6. Se obiettivi falliscono, identificare rete, connessioni/lock globale, CPU foto o consegna. Ottimizzare e ricollaudare; se il limite del Free resta incompatibile, dichiarare NO-GO per quel requisito o far ratificare un perimetro/obiettivo diverso, senza reinserire l'attesa di un minuto già rifiutata.

### 10.2 Sicurezza, privacy e accessibilità

- Tutte le comunicazioni remote HTTPS; niente mixed content con API localhost nel build pubblico. API limita body, metodi, campi e paginazione; header privati no-store, errori senza SQL/path/stack. Le route legacy senza bearer o con userId client e X-Admin-Token locale devono essere escluse o protette con identità autorevole nel contratto cloud.
- Segreti separati fra ambienti, rotazione/revoca provate; MFA pannelli e operatori; dipendenze con lockfile e revisione aggiornamenti. Provare escalation di ruolo, accesso per ID, invito copiato/revocato e richieste fuori origine. Non usare CORS come barriera di autenticazione.
- Il titolare/privacy approva finalità, platea/età, basi del trattamento, fornitori/trasferimenti e informativa effettiva prima della raccolta. La regione UE del database non certifica automaticamente tutta la filiera email/log/hosting. Evitare volti/targhe, coordinate continue, note con contatti; incaricare revisori e limitare chi vede prove. Nessuna affermazione di conformità generale deriva dal provider.
- Aggiornare privacy_page/privacy_copy per descrivere Auth, email, storage, durata, diritti e contatto reale; distinguere reset locale da cancellazione remota. Niente foto reali, token, email o dati di utenti negli screenshot dei test, nelle issue o nel repository.
- Collaudare a 390/1024/1440 px, schermo stretto e testo 2x; tastiera con focus visibile e ordine logico, lettore schermo su OTP/errori/ricevute/dialoghi, contrasto, azioni senza solo colore e movimento ridotto. Prove su desktop Chrome/Firefox/Safari e mobile Chrome Android/Safari iOS, fotocamera/rifiuto permessi/rete lenta. Test widget e screenshot storici non attestano da soli accessibilità umana o compatibilità mobile.
- Missioni curate: istruzioni per non accedere ad aree vietate, non contattare persone, non rischiare per una foto; rinuncia senza penalità e lista funzionante senza GPS. Il responsabile missioni risponde della concreta eseguibilità sul luogo.

### 10.3 Log, monitoraggio, avvisi e responsabilità

Il codice locale genera request ID server, nomi route statici/status/durata e candidate ID, senza URL grezzi o corpi. Portare la stessa minimizzazione su Edge: non loggare Authorization/apikey, JWT/OTP, email, parametri, token invito, signed URL, note/prove, IP grezzi come label. Anche exception e log dei provider vanno controllati; accesso ristretto e retention separata dai log pubblici. L'audit di dominio contiene attore/azione/revisione/motivazione dove necessario e resta privato; non sostituirlo con log tecnici effimeri.

Supabase Free ha log API/DB di un giorno e Auth audit di un'ora secondo la pagina prezzi consultata; non c'è log drain incluso. Conservare indicatori operativi minimizzati e audit necessari secondo policy, con capacità nel DB e senza copiarvi indiscriminatamente tutti i log. I 30 giorni dati Resend non sono un archivio operativo completo del progetto.

| Frequenza | Responsabile da nominare | Controllo e azione |
|---|---|---|
| Prima di ogni sessione pubblica | Operatore infrastruttura | Dashboard progetto Healthy, readiness applicativa, OTP reale su account test se quota consente, Storage privato, backup recente e operatori disponibili |
| Ogni giorno di raccolta | Operatore e sostituto | Errori API/SMTP, bounce, coda/outbox, job ultimo successo, backup/diario, pratiche review; registrare esito e anomalie |
| Due volte a settimana e prima di aumentare platea | Titolare budget + tecnico | Usage Supabase organizzazione/progetti e Resend, billing/condizioni e proiezione consumi; non fidarsi di soli valori del mese precedente |
| Settimanale | Responsabile missioni/esiti | Finestre future, protocolli/fonti, carico verificatori, conflitti, ritorno al secondo controllo; chiudere nuove prenotazioni se manca capacità |
| Mensile e prima di modifica strutturale | Custode backup + sostituto | Restore isolato completo e drill incidente; controllo copie/chiavi, retention e cancellazioni |

Soglie proposte: avviso al 70% di ciascuna quota o proiezione di esaurimento entro 7 giorni; al 90% bloccare nuove adesioni/upload prima di saturare, preservare margine per prenotazioni in corso, cancellazione, backup e gestione incidente. Job fallito >2 intervalli, outbox più vecchia di 15 min, backup >24 h, readiness KO o aumento errori → incidente da valutare. Il monitoraggio automatico esterno e i relativi canali non esistono: minimo pilot con controllo umano nelle finestre e avvisi provider al titolare/sostituto; se serve sorveglianza continua, scegliere/implementare un servizio con quote e canale e provarne la consegna. Niente uptime garantito 24/7 da un foglio di controlli manuali.

### 10.4 Guasti e recupero

| Evento | Comportamento per utente e operatore | Recupero verificabile |
|---|---|---|
| Supabase pausa/indisponibile | Letture/mutazioni cloud non promesse; conserva bozze, nessun fallback mock o invio automatico | Titolare Dashboard → Resume project; attendere Healthy, job arretrati e readiness; login/foto/review smoke prima della riapertura. La fonte corrente indica finestra Resume fino a un anno: ricontrollare nel momento dell'evento |
| DB sola lettura/restrizione quota | Nuove mutazioni rifiutate chiaramente, stato incerto recuperato tramite ricevute; non generare nuovi ID | Usage/Billing e avviso provider; ridurre carico, eliminare solo dati già scaduti secondo policy, attendere rientro/sblocco. Nessun upgrade tacito |
| SMTP/bounce/quota Resend | Messaggio generico, reinvio limitato, assistenza; nessun codice considerato consegnato solo perché richiesto | Controllare Auth+Resend, DNS, soppressioni e chiave; prova controllata dopo risoluzione. Una nuova email non rende validi codici scaduti |
| Upload fallito/riposta persa | Bozza e ID upload persistono, ricevuta/status consultati prima di ripetere | Ripresa autorizzata, finalize idempotente, sweep orfani; non cancellare una prova già referenziata |
| Chiave compromessa/accesso anomalo | Bloccare capacità compromessa lato backend/policy e preservare evidenze minimizzate | Revocare/ruotare segreto, invalidare sessioni necessarie, rivedere audit e impatto; titolare/privacy decide comunicazioni applicabili, senza promessa legale precompilata |
| Errore release/diario/backup | Attivare modalità manutenzione lato API e policy, non solo frontend | Sospendere writer/job/admin, conservare evidenze, scegliere rollback §12; copia sospetta mai esposta |

L'incidente ha un referente reperibile e sostituto, ora inizio/fine, impatto, ID candidato, azioni, dati potenzialmente coinvolti e prova di recupero. Le comunicazioni agli utenti le decide il responsabile autorizzato: nessuna email automatica è attivata da questa guida. Un sito statico online non indica backend disponibile.

## 11. Backup, ripristino e cancellazione completa

### 11.1 Politica proposta e risorse da confermare

Free non include backup automatici recuperabili dal cliente. Il backup del database contiene **metadati Storage, non i byte delle foto**. Eliminare un progetto può eliminare anche i backup del provider. [Backup ufficiali](https://supabase.com/docs/guides/platform/backups). Servono copie indipendenti prima della prima osservazione reale.

Proposta operativa compatibile con zero **solo se esistono già dispositivi/spazio adeguati**:

- Custode infrastruttura e sostituto nominati; esecuzione ogni giorno entro le 20:30 Europe/Rome e prima di migrazioni/rilasci importanti. RPO proposto **24 ore** (massima perdita di dati accettabile); se un backup salta, avviso e intervento prima che l'età superi 24 h.
- Prima copia su computer già disponibile con disco cifrato; seconda copia cifrata su supporto/dispositivo separato conservato in altro luogo sotto altro custode. Stesso disco o directory dentro .sentinelle-local non sono due copie indipendenti. Eventuale cloud privato già posseduto richiede valutazione accessi/quota/fornitore prima di usarlo.
- Retention proposta **7 backup giornalieri e 4 settimanali**, da approvare insieme alla retention delle prove: una copia settimanale può conservare foto già scadute per più tempo. I backup sono isolati, non consultabili come archivio, e subiscono scadenza/cancellazione pianificata; il diario impedisce la reintroduzione dei dati cancellati. Non mantenere copie indefinite per comodità.
- RTO proposto **1 giorno dalla dichiarazione incidente** (tempo per servizio verificato ripristinato), dipende dalla reperibilità, rete, spazio e disponibilità del progetto target; non è impegno del Free. Collaudo misura anche tempo di creare ambiente, copiare oggetti, ripristinare Auth e rifare login.
- Chiavi/passphrase in gestore separato dai backup con accesso del sostituto; il diario cancellazioni e la sua chiave hanno seconda copia indipendente e **non sono inclusi nello snapshot che potrebbe precedere la cancellazione**.

Capacità: misurare dump compresso e foto prima di approvare la frequenza. Esempio: 600 MiB di foto riscaricati integralmente ogni giorno ≈18 GiB/mese, incompatibili con 5 GB di egress ordinario. Per il pilot serve copia oggetti incrementale per ID/hash immutabili (solo nuovi/modificati, ma inventario completo a ogni backup), e budget egress per restore/test. Conservare manifest di ciascuno snapshot per ricostruire quali byte servono; garbage collection delle copie soltanto dopo scadenza di tutti i manifest che li referenziano e policy cancellazioni. Se non si dispone del componente incrementale o dello spazio, ridurre platea/carico o tenere B6 aperto, non dichiarare il backup completo.

### 11.2 Eseguire un backup coerente

Il nuovo strumento cloud proposto in §5 deve attuare i passi seguenti; **gli script locali presenti non sono riutilizzabili cambiando URL**.

1. Selezionare progetto e candidato dal registro, controllare spazio/quote e chiavi. Attivare modalità manutenzione lato API/RPC/policy, fermare cron/writer/admin e impedire nuovi upload/token firmati; non basta chiudere una pagina. Gestire anche richieste in volo e accessi diretti. Auth login/refresh e aggiornamenti utenti sono writer separati: per una copia coerente Auth applicare la procedura di manutenzione prevista e collaudata, mantenendo il servizio fermo durante export o usando snapshot coordinato. Annotare ora iniziale e transazioni ancora attive.
2. Leggere watermark (numero sequenziale) del diario e salvarlo nel manifest. Verificare che non ci siano cancellazioni pendenti non riconciliate; non confermare un backup se il registro indipendente non è leggibile.
3. Eseguire esportazione PostgreSQL con schema applicativo, dati, ledger migrazioni/attestazioni, account/mapping e dati Auth necessari, policy/RPC, ruoli e personalizzazioni Storage. Non fare un dump del solo public e definirlo backup di Auth. Identificare schema gestito, estensioni e versione effettiva; non tentare di sovrascrivere indiscriminatamente oggetti gestiti in un progetto nuovo.
4. Inventariare oggetti in entrambi i bucket con paginazione, path, stato, byte, hash; scaricare via API autenticata gli oggetti necessari incluse prove finali e, se promessi recuperabili, upload in corso. Salvarli nella copia privata con ID immutabili. Per un upload non copiato dichiarare esplicitamente che dopo restore dovrà essere ripreso/ricaricato dall'utente.
5. Verificare conteggi e hash, integrità archive e presenza di tutti i file referenziati. Manifest firmato: candidato, schema/manifest migrazioni, orario/snapshot, bucket, lista/hash dump+oggetti, watermark diario e versione degli strumenti; niente URL DB/password/token.
6. Cifrare prima di trasferire al secondo supporto, verificare decifratura e checksum con il sostituto; cancellare temporanei in chiaro secondo procedura del disco cifrato, senza lasciare copie in download, repository o CI. Non pubblicare dump o manifest con identificativi personali.
7. Registrare esito/fine/dimensione/custodia, poi riabilitare job e writer solo dopo readiness e smoke. Se fallisce, conservare ultimo backup valido e segnalare incidente; un file dump presente non è esito positivo.

Comandi standard **di esportazione DB parziale nella procedura complessiva**, dopo installazione CLI/Docker e predisposizione dei segreti, in una directory privata cifrata del custode. La CLI Supabase documenta tre file (ruoli/schema/dati); il tecnico deve provare contenuto effettivo e personalizzazioni Auth/Storage nella versione fissata. La variabile SENTINELLE_BACKUP_DB_URL è caricata privatamente con TLS da Connect, non va stampata; disabilitare tracing shell e usare macchina dedicata perché gli argomenti di processo possono essere visibili agli altri utenti del sistema:

~~~bash
umask 077
supabase db dump --db-url "$SENTINELLE_BACKUP_DB_URL" -f roles.sql --role-only
supabase db dump --db-url "$SENTINELLE_BACKUP_DB_URL" -f schema.sql
supabase db dump --db-url "$SENTINELLE_BACKUP_DB_URL" -f data.sql --use-copy --data-only
~~~

Fonte per flags e limiti del restore gestito: [backup/restore CLI ufficiale](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Se il progetto usa oggetti vector o altre estensioni che richiedono esclusioni/chiavi particolari, adeguare il piano con la documentazione effettiva. Queste tre invocazioni producono snapshot separati: sono coerenti fra loro e con le fotografie **solo se i writer sono davvero fermi**. Controllare exit code ed errori per ciascuno; non concatenare e ignorare i precedenti fallimenti. Verificare nel data export la presenza degli utenti Auth richiesti tramite test su ambiente isolato, senza aprire/stampare righe personali nei log. Schemi gestiti e chiavi crittografiche richiedono un inventario separato: il dump da solo non riproduce configurazione Auth/SMTP/JWT/Vault/segreti/MFA.

I nomi oggetti/schema definitivi dipenderanno dal porting: in questo checkout non è disponibile un singolo comando cloud «backup tutto» verificato. B6 resta bloccante finché lo strumento include foto, cifratura, custodia e prova di restore. Per le operazioni locali già verificate, seguire soltanto l'ambito sintetico del README backend.

Per rendere concreta la cifratura manuale: usare **age**, strumento gratuito installabile dai pacchetti ufficiali (su macOS con Homebrew già disponibile: brew install age), registrando age --version. [Installazione e sintassi ufficiali](https://github.com/FiloSottile/age). Dopo che il nuovo strumento ha predisposto e verificato roles.sql, schema.sql, data.sql, directory objects e manifest.json nella directory privata dello snapshot, eseguire **un comando alla volta**, interrompendo al primo errore:

~~~bash
tar -cf snapshot.tar roles.sql schema.sql data.sql objects manifest.json
age -p -o snapshot.tar.age snapshot.tar
shasum -a 256 snapshot.tar.age
age --decrypt -o snapshot-check.tar snapshot.tar.age
cmp snapshot.tar snapshot-check.tar
~~~

age chiede la passphrase interattivamente: generarne una lunga, custodirla nel gestore separato e non metterla nella riga di comando. La decifratura deve essere provata anche dal sostituto; cmp senza differenze ed exit0 verifica il giro completo. Trasferire soltanto snapshot.tar.age al secondo supporto privato, confrontare SHA256 anche là e registrare ricevuta. Le copie in chiaro restano solo sul volume cifrato durante la lavorazione e vanno rimosse secondo procedura di custodia dopo verifica; né passphrase né chiave del diario entrano nell'archivio. Per copia incrementale, la directory objects deve contenere i byte richiesti dal manifest dello snapshot oppure riferimenti a un deposito cifrato già verificato: non cifrare un insieme incompleto e considerarlo ripristinabile.

### 11.3 Prova di ripristino prima del pilot

1. Custode dichiara incidente/esercitazione, ferma accessi e writer della copia, registra ora iniziale e sceglie snapshot. Verifica firma/hash, completezza oggetti, diario originale aggiornato e chiave; se manca o è corrotto **non apre** l'ambiente restaurato.
2. Usare ambiente isolato nuovo compatibile: Supabase locale per preparazione e progetto cloud di collaudo riservato per prova finale con SMTP limitato. Con due progetti Free già occupati non è disponibile automaticamente un terzo target: programmare la ricostruzione del solo collaudo dopo averne salvato quanto serve, con approvazione del suo responsabile. Non sovrascrivere il pilot per fare una prova e non eliminare progetti senza piano.
3. Disabilitare invii email, cron, endpoint pubblici e accesso utenti; configurare regione/versione/estensioni e schemi gestiti compatibili. Applicare restore secondo runbook cloud implementato e revisionato, con gestione esplicita ruoli/ownership/trigger e transazione dove supportata. Non incollare restore SQL del database locale sopra auth/storage gestiti. Le istruzioni ufficiali evidenziano personalizzazioni schemi e materiale crittografico: se Auth/Vault/MFA non sono riproducibili con le chiavi disponibili, fermare B6 e definire recupero verificato, non ignorare errori.
4. Ripristinare byte delle fotografie via Storage API nei bucket **privati**, verificare hash/conteggi e ricostruire metadati mediante percorso supportato; la sola tabella storage.objects non ricarica gli oggetti. Nessun bucket pubblico temporaneo. Verificare anche ricevute che referenziano prove ormai scadute: restano ricevute storiche, non diritto a ripubblicare byte.
5. Il diario indipendente viene riletto fino alla sua sequenza corrente; riapplicare cancellazioni **successive al watermark** e retention prima di qualsiasi apertura, incluse Auth/Storage e nuovi backup di lavoro. Mantenere un marker persistente «restore non verificato» controllato da tutte le route/policy finché replay e controlli non sono completi. Un crash a metà deve restare chiuso dopo restart.
6. Ripristinare configurazione Auth/SMTP/CAPTCHA/ruoli/operatori, funzione/digest, cron e CORS da inventario revisionato. Progetto nuovo cambia endpoint/chiavi: aggiornare segreti e build; non riusare refresh token o sessioni a fiducia. Obiettivo minimo: identità/principal/diritti recuperati e nuovo login OTP; pianificare nuova iscrizione MFA se il recupero fattori non è dimostrato, con procedura amministrativa sicura.
7. Verificare utente B integro, utente A cancellato dopo lo snapshot ancora assente/inaccessibile, nessun XP duplicato, storico originale/rettifiche, ricevute recuperabili, leghe/membership/ownership, inbox/follow, foto autorizzate/negate e job arretrati. Testare anche nuovo backup dopo cancellazione e reiscrizione lecita: non riapplicare indiscriminatamente tombstone vecchi che cancellerebbero il nuovo principal.
8. Ripetere fault con dump corrotto/foto mancante/diario mancante/errore replay e restart: tutti NO-GO. Solo dopo esito positivo il responsabile dichiara copia pronta, sceglie cutover URL/credenziali e avvisa utenti tramite canale approvato.

Misura RPO = differenza tra ultimo dato riconciliato recuperabile e istante del guasto; misura RTO = tempo dall'apertura incidente al completamento di prove e riapertura, non durata del solo SQL. Salvare verbale con tempi reali, gap di dati e risultato login/foto; se superano 24 h/1 giorno, obiettivi non soddisfatti. Prova sintetica locale non sostituisce la prova con servizi e custodi scelti.

### 11.4 Cancellazione account: cosa realizzare

Prima del pilot il titolare approva, per ogni classe, cancellazione, anonimizzazione o conservazione motivata con durata e accessi; il tecnico implementa un workflow idempotente e testabile. La matrice minima comprende:

| Classe | Oggi | Target da implementare e verificare |
|---|---|---|
| Auth, email, mapping e sessioni/refresh | Account locale conservato da erasure fantasy | Bloccare subject e tutte le sessioni, eliminare dati Auth con API Admin quando dipendenze pronte, cancellare mapping/dati identificativi non da conservare |
| Guest token/link/alias e cache client | Scope e reset separati | Revocare credenziali collegate, distinguere device condiviso, non cancellare l'altro account; reset privato dopo conferma |
| Squadre, risultati personali, membership/inviti/proprietà | Erasure fantasy esistente, alcuni audit/creator storici conservati | Archiviazione/trasferimento coerenti; rimuovere o pseudonimizzare riferimenti identificativi secondo policy, preservare diritti di altri membri |
| Prenotazioni, note, foto, chunk, ricevute e integrazioni | Restano; cleanup solo byte per TTL | Eliminare oggetti via API, cancellare/anonimizzare note e identificativi, ricevute e scadenzari secondo policy; non lasciare copie in outbox |
| XP, review/misurazioni, ricorsi e audit operatore | Restano | Politica esplicita per storico/decisioni e integrità; pseudonimizzazione reale, non semplice nascondimento in UI |
| Proposte, voti/previsioni, profili/aggregati | Contratti separati | Rimuovere collegamenti/testo personale dove necessario; aggregati conservabili soltanto dopo analisi della reidentificazione e soglie |
| Inbox/follow/notifiche e log | Non sono chiusura account | Cancellare destinatari/contenuti privati, applicare scadenza log e audit motivati; includere log provider in informativa/policy |
| Backup | Foto e dati possono riapparire se restore vecchio | Scadenza/custodia e diario esterno; replay completo prima accesso, nuova copia coerente dopo cancellazione |

La chiamata Admin delete user non copre automaticamente tutti i dati: possono esistere vincoli/oggetti Storage e JWT ancora validi. Verificare ordine e stato terminale, senza cancellare auth.users per primo lasciando oggetti inaccessibili da gestire. [Gestione utenti](https://supabase.com/docs/guides/auth/managing-user-data).

Percorso operativo minimo proposto per budget zero: **richiesta in app, elaborazione assistita da operatore**; non promettere cancellazione istantanea automatica se manca un diario remoto indipendente. Al ricevimento bloccare nuove mutazioni del subject; il custode scrive e replica il record firmato nel diario esterno prima delle rimozioni, esegue il nuovo comando cloud per classi, verifica stato finale e solo allora conferma completamento. Termine di risposta, conservazioni/eccezioni e contatto sono approvati dal titolare/privacy e mostrati nella UI. Il comando cloud e la UI di richiesta sono oggi mancanti.

Se si sceglie cancellazione automatica online, serve un archivio durevole esterno al dominio di restore, raggiungibile dalle funzioni, con quote/costo/controlli e allarmi verificati: non è stato scelto. Il filesystem Edge o un'altra tabella del DB che si ripristina non soddisfano indipendenza. Non presumere un terzo progetto Free disponibile. Modificare architettura/quote dopo decisione del titolare; fino ad allora B6/B7 restano aperti.

Durante errore parziale: account resta bloccato, operazione pendente e recuperabile, nessuna conferma di completamento; retry riprende dallo stato confermato, altri utenti restano intatti. Diario contiene riferimenti opachi e sequenza/versione; anche questi sono da proteggere come dati potenzialmente personali. Perdita/alterazione del diario o chiave richiede ripristino del materiale originale e fermo, non inizializzazione di un registro vuoto.

## 12. Sequenza di rilascio e rollback

### 12.1 Ordine delle attività e recuperi

Eseguire prima tutto su **collaudo** con dati sintetici. Il tecnico compila per ciascun passo: data, ambiente, candidato, esecutore, evidenza privata, esito PASS/FAIL/BLOCCATO; i passi successivi non sanano quelli precedenti. Le azioni nei pannelli e i deploy qui descritti sono istruzioni per una futura esecuzione autorizzata, non azioni svolte creando questa guida.

| Passo e prerequisiti | Azione: schermata/comando | Risultato atteso e verifica | Errore frequente → soluzione / recupero |
|---|---|---|---|
| S0 — Accesso repo, nessuna mutazione | git status --short; git rev-parse HEAD; versioni §3; rileggere dossier corretto | Inventario diff/file non tracciati; candidate precedente distinto; titolare assegna ruoli | Usare solo HEAD perde lavoro locale → preparare snapshot/commit revisionato completo senza reset |
| S1 — S0 | Titolare: registro §15, piano/quote, partner/dominio, custodi e platea; RP per Pages | Decisioni/risorse documentate; nessuna spesa non deliberata | Dominio/diritti asset/copie assenti → NO-GO relativo, proseguire solo analisi locale indipendente |
| S2 — S1 e posti Free | Supabase Dashboard: collaudo, regione, password e API exposure §5 | Healthy, Free, schemi chiusi, Connect/TLS provati | Rete IPv4 vs endpoint IPv6 → session pooler testato; non acquistare add-on tacitamente |
| S3 — S2 + tecnico | P1 minimo Edge/SQL/Auth/immagini; implementazione locale e deploy condizionato §5 | Evidenze concorrenza/CPU/latenza/privato; ADR firmato | Node server non esegue o PNG supera CPU → blocco B1; niente porting massivo |
| S4 — S3 | Nuove migrazioni/grant/RLS e mapping, manifest; migrate:up/verify condizionati §5 | Ledger/schema coerenti; test upgrade/popolato e accesso diretto negato | Permessi/lock/checksum → fermare e correggere nuove migrazioni; mai alterare storia o down forzato |
| S5 — S1 dominio + S2 | Resend Free → Domains; DNS §7; chiave e SMTP Auth | Verified, sender corretto, consegna a collaudatori esterni | resend.dev funziona ma altri destinatari falliscono → serve dominio; record sbagliato → correggere solo quel record e riverificare |
| S6 — S4/S5 | Auth template/expiry/URL/registrazioni/CAPTCHA, adapter Flutter e revoca §6 | OTP reale, refresh, logout, ruoli/MFA e intenti ripresi | Default magic link o delivery simulated → correggere template/adapter, non aggirare validazione payload |
| S7 — S4/S6 | Bucket privati/policy, adapter/finalizzatore foto §8 | Upload interrotto ripreso, finalizzazione privata e cleanup; B negato | URL pubblico o policy troppo ampia → bloccare esposizione, correggere policy e verificare tutti gli oggetti coinvolti |
| S8 — S3/S4/S6/S7 | Portare rimanenti route, transazioni, cron, fonti/calendario e ruoli reali §5 | R01–R21 e R24 coperte; nessun ramo legacy scrivibile senza autorità | Prova synthetic usata come dato reale → eliminare solo fixture del collaudo e preparare canale operativo approvato |
| S9 — S4/S6/S7/S8 + custodi | Implementare cancellazione e backup cloud; drill §11 | Copie cifrate separate, diario durevole, restore completo misurato e utenti isolati | Mancano byte foto/Auth/chiave → copia non valida; restare chiusi e recuperare ultimo set completo |
| S10 — S6–S9 | Test contratto/policy/backend/Flutter, profilazione §10; freeze nuovo candidato | Suite finali senza skip non dichiarati; manifest/artefatti identificati | Usare digest fase8 dopo porting → rifare digest e prove interessate; non ribattezzare vecchi log |
| S11 — S10 e gate Pages | Build frontend §9; Settings Pages/Actions, deploy collaudo o anteprima isolata | URL effettivo, base corretta, niente segreti, hash route/reload e cache provati | 404 asset/pagina bianca → base/inizializzazione/fallback; ripristinare artefatto precedente compatibile |
| S12 — S11 + collaudatori/operatori | Checklist §13 su servizi cloud e browser reali, casi guasto/rollback | Verbale con PASS/FAIL e limiti, tutte righe bloccanti chiuse | Locale verde ma OTP/foto reali non provati → NO-GO, non marcare PASS |
| S13 — S12 + decisione titolare | Secondo progetto pilot: ripetere configurazione/nuove migrazioni, dataset reale approvato, segreti separati; nuove URL e build | Confronto configurazione collaudo/pilot, smoke minimo sul vero target prima apertura | Config copiata con chiavi/URL di collaudo → fermare apertura, correggere e ripetere smoke |
| S14 — S13 + GO firmato | Apertura limitata, inviti scaglionati e operatori presenti | Rilevare funnel, review, copertura/secondo controllo e quote; assenza incidenti aperti | Capacità review o quota insufficiente → fermare nuove prenotazioni/adesioni, non cambiare punteggio/retention tacitamente |
| S15 — Raccolta terminata o incidente | Chiudere nuove adesioni, gestire pratiche/ricorsi, conservazione/cancellazione e copie secondo policy | Utenti informati, chiavi non necessarie revocate, nessuna risorsa/dato dimenticato | Eliminare progetto prima del salvataggio → rischio irreversibile; verificare inventario e copie prima di qualsiasi teardown |

La sequenza può svolgere DNS e implementazione locale in parallelo di attività umane, ma nessun passaggio dipendente riceve PASS senza prerequisiti. Non servono modifiche ai servizi esterni per scrivere e verificare questa guida.

### 12.2 Rollback distinto per componente

**Preparazione comune:** registro release con commit/digest, build/hash, funzioni versionate, manifest schema, policy e configurazioni non segrete, backup verificato e watermark. Modalità manutenzione deve impedire writer via Edge, RPC, REST diretto, Storage, cron e CLI. Conservare richieste già committate e consentire recovery controllato; non riavviare mutazioni a caso con nuove chiavi.

| Componente | Procedura | Verifica prima riapertura e limite |
|---|---|---|
| Frontend GitHub Pages | Tornare a revisione/artefatto noto tramite workflow di rollback predisposto o ridistribuire la build conservata. Il workflow corrente checkout+build non offre selezione automatica di un vecchio artifact: prepararla prima | Base/flag/URL e candidate visibili, login e ricevute, browser con cache vecchia e nuova. Il rollback non annulla scritture DB avvenute |
| Frontend Cloudflare | Lista Deployments → rollback al deployment di produzione scelto, oppure caricare il set precedente conservato | Verificare URL/versione/cache e compatibilità API. Non serve cambiare DNS a caso |
| Edge Functions | Redeploy del sorgente/artefatto precedente identificato e relativo config, solo se schema e token supportati | Nessun ritorno a endpoint insicuri o simulated, smoke autorizzazioni/XP/idempotenza; segreti compromessi non vengono ripristinati |
| Policy/Auth/SMTP | Applicare configurazione precedente revisionata solo se sicura; ruotare chiavi ove necessario | JWT vecchi/revoche/MFA/redirect e OTP reale; non riaprire tabelle o bucket come ripiego |
| Migrazioni dati | Preferire fix additivo con compatibilità oppure restore isolato coerente e cutover controllato §11 | Mai migrate:down alla cieca. Down10/11/15 possono fallire atomicamente su dati popolati; vecchia versione può non rappresentare nuovi dati |
| Fotografie e cancellazione | Restore oggetti solo insieme al DB e replay diario/retention | Nessuna foto privata pubblicata o dato cancellato reintrodotto. Eliminazione byte/account può essere irreversibile senza copia lecita disponibile |

Strategia migrazioni: espandere schema prima del codice che lo usa, preservare temporaneamente compatibilità col client precedente, rimuovere campi solo dopo finestra dichiarata e verifica di assenza chiamanti. Il restore a uno snapshot vecchio può perdere dati successivi: il responsabile approva perdita/ripresa e riconcilia ricevute prima dell'apertura. Non riscrivere creation_key, punteggi o storico per forzare un downgrade.

Operazioni irreversibili: cancellazione progetto/bucket senza copia valida, revoca di segreti non recuperabili, eliminazione Auth/foto e scadenza backup. Il verbale deve indicare recuperabilità reale; un rollback frontend non è un piano di ripristino dati.

## 13. Collaudo end-to-end e decisione di rilascio

### 13.1 Preparazione ed evidenze

Usare progetto collaudo, dataset sintetico coerente, nuova stagione con finestre utili, account A/B, almeno tre concorrenti per ranking, verificatore e responsabile esiti distinti e secondo Comune negativo. Per test reali email i destinatari sono controllati/autorizzati; fotografie sintetiche anche sul cloud finché il gate raccolta reale non è approvato. I clock controllati valgono nei test locali; per scadenze cloud usare finestre brevi deliberate, non cambiare l'ora del servizio.

Ogni test registra ID, requisito R, candidato/schema, URL/ambiente, data/ora, attori pseudonimi, passi, atteso/osservato, PASS/FAIL/NON ESEGUITO, riferimento privato all'evidenza e responsabile. Rimuovere token, OTP, indirizzi, foto personali e signed URL dalle prove condivise. Un test saltato non è PASS. Ripetere smoke sul target pilot dopo aver copiato configurazione e build: il collaudo su altro progetto non prova che SMTP/CORS/chiavi pilot siano corretti.

### 13.2 Checklist con risultati attesi

- [ ] **T01 — R06, R25: OTP reale**. Utente ammesso richiede codice da build pubblicata; email sul dominio verificato arriva alla casella; codice digitato crea sessione e permette una chiamata privata. Annotare tempi/Auth/Resend/ricezione/spam, mittente e autenticazione DNS.
- [ ] **T02 — R06/R21: codici e abusi**. Codice errato, scaduto, già usato e precedente dopo reinvio sono respinti secondo comportamento verificato; non si crea sessione extra. Attesa reinvio/CAPTCHA/token falso/limiti agiscono server-side. Se il provider non invalida il precedente come richiesto localmente, decidere e testare la semantica prima del GO. Utente sconosciuto non si autoregistra nel pilot.
- [ ] **T03 — R07: persistenza sessione**. Ricarica browser, attesa scadenza access token e refresh, perdita rete e secondo dispositivo; nuovo login recupera profilo, squadra e ricevute. Logout locale/globale e revoca di altro device negano anche token copiato prima; nessuna ricreazione automatica di sessione revocata.
- [ ] **T04 — R08/R17: guest e intenti**. Missione/invito sopravvivono al login senza invio/join automatici; possesso guest dimostrato; retry linking restituisce stesso risultato; conflitto conserva account dopo scelta esplicita, nessun punto o team mock importato. Se ospiti esclusi, percorso disabilitato e limite comunicato.
- [ ] **T05 — R01/R02/R03: flussi civici**. Lista/ricerca/dettaglio/Comune corretto, proposta con luogo, filtro 422, quarto invio 429 con Retry-After, voto/promozione secondo policy ratificata, ricevuta/rejected propri e isolamento. Previsioni/risultati/aggregati e capacità legacy esposte complete; nessun fallback a mock o scrittura con userId falsificato.
- [ ] **T06 — R09/R10: missione completa**. Esplora senza account/GPS, leggi istruzioni/durata/prove/XP, accedi, prenota, salva bozza, seleziona foto, rivedi e invia; ricevuta pendingReview con XP0. Rinuncia senza penalità; prenotazione scaduta libera slot; nonObservable/unsure ammessi senza inventare zero o criticità.
- [ ] **T07 — R09/R13: concorrenza**. Due utenti sull'ultimo slot: uno solo lo acquisisce. Due revisioni simultanee: un esito coerente e un conflitto/ripresa. Validazione stessa persona/luogo/finestra accredita una volta, salvo replica umana richiesta; provare tempi al confine lock e quota inviti persistente.
- [ ] **T08 — R10/R11/R13/R18/R19: risposta persa e duplicati**. Interrompere risposta dopo commit, ritentare stessa chiave e body; stessa ricevuta e un solo invio/XP/evento/copertura, anche nuova istanza. Body diverso con stessa chiave confligge. Dopo timeout non creare nuovo intento prima di lookup/recovery.
- [ ] **T09 — R11/R21: foto private**. Upload interrotto ripreso, MIME falso/oversize/pixel espansi/metadata respinti o sanificati, max3 prove/2MiB rispettati. Anonimo/B/operatore altro Comune non leggono, listano, sovrascrivono, firmano o eliminano. URL pubblico non funziona; URL firmato scade; accesso negato dopo retention/revoca secondo percorso scelto.
- [ ] **T10 — R12/R13: verifica umana**. Assegnazione, richiesta integrazione, risposta autore, approvazione/rifiuto motivato e audit; A non valida il proprio contributo, né operatore concorrente decide propria carta. MFA obbligatoria su route privilegiate. NoIssue approvato e visibleWaste approvato danno entrambi 10XP una volta.
- [ ] **T11 — R14/R15: misurazioni**. Protocollo/baseline/fonti versionati prima lock, modifiche tardive respinte, intervento temporaneo separato dal beneficio. Prove contraddittorie bloccano determinabile; assenza/unknown non diventano stable. Deadline produce undeterminable idempotente e 0 punti osservazione/previsione, preservando riflessione/penalità. Pubblicazione umana motivata, ricorso e rettifica appendono revisioni e ricalcolo unico.
- [ ] **T12 — R04/R05: fantasy**. Budget/formazione/quote e revisione, conferma/lock, mercato/penalità/bonus/capitano e 48 fixture equivalenti; risultati provvisori/finali, storia rettifiche e ranking 1/1/3. Nuova stagione v2 non riscrive risultati v1.
- [ ] **T13 — R16/R17: leghe**. Creazione max3 e idempotenza, invito hash/rotazione/scadenza/revoca, preview prima join, token rimosso dall'URL. Ranking solo membri/≥3 concorrenti, late join spettatore; trasferimento a membro che accetta, uscita owner senza trasferimento archivia; creator key storica stabile.
- [ ] **T14 — R18/R19/R20: cooperazione e continuità**. Luogo/finestra contato una volta, esclusione contributi non validati e membership tardive; inbox letto condiviso tra dispositivi, unfollow ferma solo nuovi eventi. Secondo controllo settimanale e calendario nuovo da pubblicazione amministrativa idempotente, nessun rinnovo al boot/bonus follower automatico.
- [ ] **T15 — R21: accessi diretti**. Saltare UI e chiamare Edge, REST/RPC e Storage con public key, JWT A/B, token falso/altro progetto e MFA aal1; nessuna escalation, note/email/audit privati o controllo tramite body. Prove di Origin/preflight e route legacy/admin disabilitate.
- [ ] **T16 — R24/R25: rete, quota e guasto**. Simulare timeout/502/503/429/402 e quota upload/email senza esaurire il piano reale; bozze conservate, errore chiaro, nessun loop/retry duplicante. Cron perso e ripetuto recupera arretrati; readiness distingue guasto DB/Storage/diario; latenza freddo/caldo misurata §10.
- [ ] **T17 — R22: chiusura account**. A chiede cancellazione, sessioni bloccate, operatore/workflow completa classi approvate e Storage; residui motivati inventariati, B e pubblicazioni lecite integri. Retry/fault a ogni confine conserva operazione pendente e non conferma successo falso. Verificare anche log/cache/outbox e nuova iscrizione consentita dalla policy.
- [ ] **T18 — R23: backup e restore**. Backup completo → cancellazione A successiva → restore isolato e replay → A non risorge, B/XP/ricevute/leghe/inbox/foto integri. Foto mancanti/dump corrotto/diario o chiave mancanti/replay parziale restano chiusi anche dopo restart. Misurare RPO/RTO, provare OTP e operatori sul target; copie cifrate lette dal sostituto.
- [ ] **T19 — R29/R24: upgrade e rollback**. Build precedente presente in cache, nuova release identificata e poi ritorno a versione compatibile; refresh/deep link/invito/account/bozza funzionano senza perdita; API/schema/policy corrispondono al manifest, nessun segreto nel bundle. Provare rollback Edge e restore schema separati.
- [ ] **T20 — R26/R27: persone e dispositivi**. Desktop/mobile reali, permesso foto/GPS negato, tastiera/lettore schermo/testo2x, rete lenta; i partecipanti distinguono ricevuta da approvazione, XP da punti fantasy, effetto temporaneo da soluzione. Referenti capaci di revisionare prima di scadenza delle prove e di gestire incidenti.

### 13.3 Demo, pilot e produzione

| Livello | Cosa può dichiarare | GO richiesto |
|---|---|---|
| Demo mock | UI con dati sintetici e persistenza browser; non invia contributi o email reali | Test/build/routing e segreti/assets/hosting verificati; limiti della demo visibili. Non richiede fingere un backend Supabase |
| Collaudo cloud tecnico | Integrazione con provider su account autorizzati/dataset sintetico | P1 e test tecnici registrati, quote sotto controllo; non è apertura a partecipanti reali |
| Pilot con utenti reali | Platea/Comune/finestra limitati, operatori e assistenza presenti | Tutte le righe bloccanti della matrice e T01–T20 pertinenti PASS sul nuovo candidato, smoke sul target pilot, B chiusi o esclusioni esplicite compatibili; dati/fonti/privacy/capacità/backup approvati e GO firmato |
| Produzione continuativa | Servizio con disponibilità/capacità e responsabilità dichiarate | Oltre al pilot: carico/crescita/abusi misurati, sorveglianza e ripristino ripetuti, sostenibilità quote/inattività e obiettivi di disponibilità ratificati. Free non offre SLA e può non soddisfare continuità richiesta |

**NO-GO automatico** per dominio/email reali non funzionanti, P1 fallita, Auth/ruoli/RLS incompleti, foto pubbliche o non validate, doppio XP/slot, chiusura account promessa ma non realizzata, backup senza byte/diario/restore, segreti nel bundle, operatore assente, dati/protocolli non ratificati, guasti critici aperti o candidato non identificabile. Il completamento della documentazione non cambia questo stato.

Verbale da compilare privatamente: livello richiesto; candidato/build/schema/config; data e ambiente di ogni test; copertura R/T ed esclusioni; quote/capacità misurate; responsabili e sostituti; piano assistenza/incidenti; RPO/RTO provati; rischi residui e chi li accetta; decisione GO/NO-GO con firma del titolare e del responsabile pilot. Nessun test locale o sintetico vale come attestazione del servizio cloud.

## 14. Controllo finale di coerenza e fonti

La guida conserva la documentazione storica: non è stato riscritto il dossier per far apparire verificato il cloud. I collegamenti ai file sono relativi alla posizione in docs e le fonti provider sono dirette. Tutte le condizioni provider riportate sono una verifica documentale del **16 ottobre 2026**, non registrazione/contratto individuale; i pannelli dell'account e i limiti assegnati vanno ricontrollati. I numeri del repository sono evidenze storiche dichiarate come tali.

| Incrocio | Risultato dell'analisi per questa guida |
|---|---|
| Codice vs runtime | Node HTTP e adapter simulated/local-synthetic presenti; assenza di pacchetto Supabase e supabase_flutter. Nessun comando inventato di deploy Node su Edge |
| Migrazioni vs comandi | 16 file JS con manifest, script npm realmente presenti; supabase db push non applica questi file; nuovi strumenti cloud marcati mancanti |
| Auth vs account locale | Bearer/challenge custom e cinque minuti locali distinti da JWT/OTP Supabase e durata proposta 600s; revoca/device/guest richiedono adattamento |
| Storage vs foto | Limiti e PNG server derivati dal codice; TUS/policy/URL firmati/cleanup cloud da implementare; file locali non backup Supabase |
| Workflow vs hosting | Pages attuale solo mock e senza dipendenza dai gate cloud; base /miglioraPaese/; Cloudflare descritto come alternativa; GitHub Free/visibilità non presunti |
| Dossier vs cancellazione/restore | Erasure fantasy separata dalla chiusura account; ops test loopback, nessuna equivalenza automatica col restore gestito |
| Dossier vs candidato | Digest fase8 storico distinto dalla correzione browser successiva e dal futuro porting; suite citate non dichiarate rieseguite |
| Roadmap vs rilascio | EVO in discovery non promesso nel pilot; eventuale inclusione richiede nuova analisi di requisiti e costi |

Le fonti sono collocate accanto alle istruzioni che sostengono. Non verificati: disponibilità di nomi/domini richiesti, consenso di un partner, registrazione degli account e limiti effettivi, regione assegnata, deliverability verso la platea, prestazioni sul target, capacità custodi e requisiti privacy effettivi. Questi punti non diventano garanzie attraverso la citazione di una pagina generale. Non è attestata completezza operativa finché restano le lacune sotto.

Controlli documentali eseguiti alla consegna: collegamenti locali risolti, 30 ID requisito e 20 ID di collaudo presenti, 12 blocchi censiti, delimitatori dei blocchi codice bilanciati e nessuno spazio finale. Ricontrollate le impronte dei 16 file migrazione contro il manifest, tutte corrispondenti. Il diagramma è stato controllato nella struttura e nei riferimenti ai nodi; non è attestato un rendering con un motore Mermaid in questa attività. Non sono state rieseguite suite applicative o build per una modifica soltanto documentale, né eseguiti i comandi cloud descritti.

## 15. Registro finale: decisioni aperte, blocchi e input del titolare

Stato iniziale di **tutte** le righe: APERTO, al 16 ottobre 2026. La colonna responsabile indica il ruolo richiesto, non una persona già incaricata. Chiudere con data, risultato e riferimento privato all'evidenza; «configurato» senza prova non chiude una riga.

| ID | Blocco/decisione e impatto | Responsabile richiesto | Azione per risolvere e prova di chiusura |
|---|---|---|---|
| B1 | Fattibilità backend Edge/DB/PNG e latenza non provata; blocca architettura eseguibile | Tecnico backend + responsabile infrastruttura | P1 su collaudo, scelta transazioni/driver/RPC, misure e ADR; alternativa esplicita se fallisce |
| B2 | Nessun dominio mittente controllato/verificato accertato; OTP esterno a zero non dimostrato | Titolare + amministratore DNS/partner | Confermare dominio/sottodominio e autorizzazione; DNS Verified e OTP ricevuto da destinatari esterni; se manca, tenere demo o approvare costo/nuova scelta |
| B3 | Auth/JWT, revoca immediata, MFA e migrazione guest/account ancora custom | Tecnico Auth/client + titolare sicurezza | Implementare e testare R06–R08/R12/R21; decidere guest e dati preesistenti; nominare operatori e procedura recupero |
| B4 | Porting API/schema/policy e chiusura mutazioni legacy mancanti | Tecnico backend/database | Nuove migrazioni immutabili, mapping, policy per tutte le risorse, test diretti e concorrenti; contratto OpenAPI aggiornato |
| B5 | Storage cloud/normalizzazione/finalizzatore e quote foto non verificati | Tecnico backend/client + responsabile dati | Bucket privati, isolamento, sanitizzazione/CPU, ripresa/retention/orfani e dimensionamento realistico, T09 PASS |
| B6 | Backup coordinato Auth/DB/byte foto, custodia/diario indipendente e restore cloud assenti | Titolare + custode infrastruttura e sostituto | Confermare hardware/spazio/chiavi/seconda copia e finestra manutenzione; implementare export incrementale/restore/quarantena; T18 e RPO/RTO misurati |
| B7 | Chiusura account completa assente e policy classi non ratificata | Titolare dati/privacy + tecnico | Approvare tempi/classi/residui, decidere assistita vs automatica e registro esterno; implementare workflow e T17 più replay su restore |
| B8 | Protocolli/fonti/dataset reale, moderazione proposte e capacità revisione/esiti non nominati | Responsabile pilot, missioni e responsabile esiti | Ratificare primo Comune/categoria, baseline/fonti, regola promozione proposte, conflitti, sostituti e capacità/tempi; pubblicazione operativa non sintetica |
| B9 | Pages Free condizionato a visibilità/piano, asset e cronologia privata | Titolare repository | Confermare piano/strategia snapshot e diritti, bonifica e gate RP; altrimenti scegliere Cloudflare mantenendo sorgenti privati e ricollegare Auth/CORS |
| B10 | Job, monitoraggio/avvisi, incidenti e disponibilità Free senza responsabili | Operatore infrastruttura + titolare | Configurare Cron/retry, provare arresto/ripresa, nominare reperibili e canali, soglie quota e procedura Resume; accettare finestra disponibilità o cambiare piano/perimetro |
| B11 | Build/workflow cloud e nuovo candidato non esistenti; test storici non bastano | Tecnico Flutter/CI + revisore release | Pin strumenti, gate con integrazioni non saltate, manifest nuovo e build privo segreti, deep link/cache/rollback su entrambi i profili supportati |
| B12 | Platea, informative, obiettivi, budget effettivo e GO non approvati | Titolare + responsabile pilot/privacy | Confermare 20 iniziali o altro numero misurato, finestre/carico/reperibilità, condizioni Free e pause, RPO/RTO, feedback/metriche e autorizzazione prima di dati reali |

Informazioni che **solo il titolare o chi delega può fornire**: account/organizzazioni già disponibili e posti Free residui; piano/visibilità GitHub e autorizzazione sulla storia/assets; contatto partner e diritto al sottodominio/DNS; indirizzo assistenza realmente presidiato; persone e sostituti per infrastruttura/missioni/verifica/esiti/privacy; dispositivi/custodia copie/chiavi già disponibili; esistenza di utenti o dati reali da migrare; Comune, platea/età, finestre, fonti e protocollo approvati; eventuale costo massimo autorizzabile se il dominio zero non è ottenibile; requisiti di disponibilità e tempi di cancellazione accettati. Nessuna credenziale va inserita in questo file.

**Decisione alla consegna: documento operativo disponibile; demo e pilot restano livelli distinti. Pilot completo e produzione non autorizzabili come funzionanti finché i blocchi pertinenti non sono risolti e provati sul nuovo target.**
