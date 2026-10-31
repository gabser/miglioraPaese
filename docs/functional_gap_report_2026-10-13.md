# Migliora Paese / Fanta Comune — gap funzionali e proposta Sentinelle

Data: 13 ottobre 2026. Documento di analisi e proposta, non implementazione né modifica delle regole vigenti.

## Risultato dell’analisi

Il prodotto contiene una base di gioco e, nel checkout più recente, leghe private API già implementate. Mancano il ciclo completo delle missioni civiche, gli account recuperabili e il collegamento verificabile fra osservazioni sul territorio ed esiti del gioco. Il modello rappresenta soprattutto un andamento sintetico; interventi, effetti temporanei e prove richiedono entità e flussi dedicati.

La soluzione proposta è **Sentinelle: missioni brevi per conoscere e seguire il proprio territorio**, con riconoscimenti per osservazioni validate, anche quando non emerge un problema o non cambia nulla. La sentinella raccoglie prove; un verificatore distinto decide gli esiti che assegnano punti nel gioco.

## Perimetro e limiti dell’audit

Sono stati letti codice, configurazioni, test e documenti locali in due checkout:

| Checkout | HEAD locale | Uso nell’analisi |
|---|---|---|
| Workspace corrente: `.../Documents/Codex/2026-07-11/github-plugin-github-openai-curated-remote/work/miglioraPaese` | `1fad162218e758efa3a556790e42b335a6196959` | Esperienza legacy e lavoro locale proposte, con numerose modifiche non committed |
| Checkout recente: `/Users/gabrieleserra/miglioraPaese` | `14b0edf18caa070a3d4a28667251a7b175ca0ce6` | Manager civico, API fantasy, identità anonima, pubblicazione esiti e leghe private |

I due checkout non sono equivalenti. La presenza di una funzione nel checkout recente non dimostra che sia disponibile nella demo pubblica o nel workspace corrente. Non è stato verificato lo stato remoto di branch, PR o deploy. Non sono stati eseguiti test o prove browser per questo report: «presente» indica evidenza nel codice; i test citati sono stati ispezionati, non rieseguiti. Le assenze sono limitate ai percorsi esaminati.

Il documento `docs/backend/fantasy_pilot_go_no_go.md` del checkout recente descrive ancora un NO-GO operativo e fonti sintetiche, anche quando etichettate `verified`. Non si può presentare il sistema come verifica già attiva della realtà.

## Benchmark: che cosa riprendere da BeMyEye

BeMyEye descrive un percorso con missioni su lista/mappa, istruzioni, durata e ricompensa visibili prima della prenotazione, questionario e fotografie. Un team valida il report prima di riconoscere il compenso. Prevede inoltre XP e livelli. Fonte ufficiale consultata il 13 ottobre 2026: [Come funziona BeMyEye](https://content.bemyeye.com/earn-money/).

Per Fanta Comune proponiamo di adottare la struttura delle missioni e il riconoscimento dopo validazione. La componente economica richiede una decisione distinta su finanziamento e gestione: non è inclusa nella prima versione proposta. Senza compensi monetari, la capacità di attrarre partecipanti resta un’ipotesi da misurare nel pilot.

## Proposta di prodotto: Sentinelle

### Due modi per contribuire

1. **Esplora una zona:** missione di scoperta, ad esempio «Osserva questo tratto di marciapiede». Si può rispondere «nessuna criticità osservata», indicare un problema già presente o proporne uno nuovo. La missione non presuppone un difetto e non invita a inventarlo.
2. **Torna a controllare:** missione collegata a un problema o intervento già registrato, con domande e punti di osservazione confrontabili nel tempo.

Le missioni iniziali sono curate dai responsabili del pilot. Le proposte dei cittadini possono generare missioni dopo moderazione, deduplicazione e valutazione della possibilità di osservarle. Una proposta non entra automaticamente nel catalogo delle carte fantasy.

### Percorso della persona

| Passaggio | Esperienza proposta | Condizione di completamento |
|---|---|---|
| Scopri | Lista per Comune/zona, mappa opzionale, filtri accessibili | La lista funziona anche senza permesso di geolocalizzazione |
| Scegli | Luogo, domanda, durata stimata, scadenza, prove richieste e riconoscimento | La persona sa cosa osservare prima di accettare |
| Accetta | Prenotazione breve; possibilità di rinunciare | Scadenza e slot gestiti dal server; nessuna occupazione indefinita |
| Osserva | Questionario breve con avanzamento e foto dove pertinenti | Disponibili anche «non osservabile» e «non so» |
| Invia | Riepilogo, bozza recuperabile e ricevuta | Un retry non duplica il contributo; offline o esito incerto sono espliciti |
| Attendi | Stato della verifica, integrazioni richieste, motivo della decisione | Nessuna promessa di approvazione alla sola ricezione |
| Ricevi | XP civici e feedback dopo validazione | Accredito una sola volta, indipendente dalla risposta positiva/negativa |
| Segui | Cronologia del luogo e prossimo controllo | La persona vede a che cosa è servito il contributo |

Se il luogo non è raggiungibile o l’osservazione non è sicura, si può rinunciare senza penalità. Le missioni non devono richiedere ingresso in aree vietate, contatti con persone o fotografie di soggetti identificabili. La raccolta di posizione va limitata alla singola osservazione; non serve un tracciamento continuo. La posizione è un indizio, non una prova sufficiente di autenticità.

### Perché tornare a fare la sentinella

- Missioni di pochi minuti, compatibili con luoghi che la persona frequenta già.
- Riconoscimento chiaro: «Hai contribuito a verificare questo luogo», con feedback sull’utilità delle prove.
- XP civici, badge tematici e progressi personali, separati dai punti fantasy.
- Obiettivi cooperativi nelle leghe: coprire luoghi e controlli utili, senza premiare la quantità grezza di segnalazioni.
- Possibilità di seguire un luogo e ricevere un invito facoltativo al controllo successivo.
- Eventuali premi di partner in una fase successiva, soltanto dopo avere definito copertura economica e regole.

Le regole XP vanno versionate: un riconoscimento di base per un contributo valido; eventuali bonus dichiarati per zone poco osservate o controlli successivi. Niente moltiplicatori perché il problema è grave o perché l’esito è «migliora». Limitare i contributi ripetitivi sullo stesso luogo/finestra e riconoscere soltanto le repliche richieste per verifiche indipendenti. L’affidabilità della sentinella va distinta dagli XP e non dipende dall’accordo con la maggioranza.

Una sentinella esperta può accedere a missioni più complesse dopo formazione e revisione della qualità. Un livello alto non attribuisce automaticamente il diritto di certificare esiti.

### Chi verifica e chi pubblica

| Ruolo proposto | Responsabilità | Confine |
|---|---|---|
| Sentinella | Raccoglie osservazioni secondo istruzioni | Non certifica da sola il proprio contributo |
| Moderatore | Controlla pertinenza, duplicati, contenuti e dati personali | Non decide l’efficacia di un intervento sulla base dei voti |
| Verificatore | Valuta qualità, confrontabilità e contraddizioni delle prove | Non valida osservazioni proprie né esiti di carte su cui compete nella giornata |
| Responsabile esiti | Pubblica il risultato motivato e gestisce contestazioni | Decisione tracciata e distinta dall’organizzazione di una lega privata |
| Responsabile pilot | Definisce protocolli, persone e tempi di revisione | Garantisce capacità operativa prima di pubblicare nuove missioni |

Per la prima versione: controlli automatici su completezza e duplicati, più revisione umana di tutti i contributi. Per gli esiti che producono punti, richiedere una fonte documentale pertinente oppure osservazioni indipendenti confrontabili secondo il protocollo della carta. Due risposte concordi non sono, da sole, una certificazione. Nei casi discordanti: nuova verifica o esito non determinabile, mai semplice voto a maggioranza.

L’organizzatore di una lega non può assegnare liberamente l’esito delle carte dei propri membri. Le leghe condividono gli esiti pubblicati per Comune/giornata; gli obiettivi cooperativi possono essere diversi.

## Come rappresentare problemi, interventi ed effetti

Separare almeno cinque concetti:

| Oggetto | Informazioni necessarie |
|---|---|
| Problema | Luogo, categoria, descrizione, baseline datata, criterio di osservazione |
| Intervento | Collegamento ai problemi, tipo, fonte, stato proposto/avviato/completato/sospeso, durata prevista |
| Missione | Domande versionate, finestra, istruzioni, prove, slot e riconoscimento |
| Osservazione | Autore, data, risposte, prove, condizioni, stato di validazione |
| Valutazione | Indicatore prima/dopo, soglia, periodo, fonti, decisione motivata, responsabile e versione |

Un intervento può essere provvisorio; la durata prevista dell’intervento è distinta dalla durata osservata del beneficio. Un intervento può interessare più problemi e un problema ricevere più interventi. «Non osservabile», «in attesa» e «contestato» sono stati della valutazione, non direzioni dell’andamento.

Esempio: una protezione provvisoria su un attraversamento è un intervento realizzato. Può migliorare un indicatore definito dal protocollo durante una settimana, senza dimostrare una soluzione permanente. Si registra quindi l’effetto osservato nella finestra, il carattere provvisorio e un controllo successivo. Non si attribuisce automaticamente il cambiamento all’intervento: traffico, meteo e altri fattori possono incidere.

I criteri devono essere pubblicati prima del lock: indicatore, baseline, soglia e finestra. Se il tema non è misurabile in modo credibile nella durata della giornata, resta monitorabile ma non diventa una carta con esito competitivo.

### Dati insufficienti e punteggio

Il contratto attuale ammette soltanto `improves`, `stable`, `worsens`. Nel backend recente una giornata eleggibile resta provvisoria se mancano risultati per i titolari. Occorre decidere come chiudere la giornata senza inventare un andamento.

Proposta da validare prima dell’implementazione: introdurre una disposizione separata «non determinabile» a una scadenza dichiarata; nessun punto di osservazione/previsione per quella carta, nessuna conversione in «stabile». Mostrare il numero di carte valutabili e la regola applicata. Valutare su fixture l’effetto della diversa copertura sulle classifiche prima di scegliere questa regola o una normalizzazione. Non cambiare unilateralmente il punteggio corrente.

Gli esiti pubblicati oggi sono immutabili. Per rettifiche e ricorsi serve un processo esplicito: conservare originale, rettifica e motivazione; definire se e quando ricalcolare risultati e classifiche. Nessuna sovrascrittura silenziosa.

## Matrice dei gap

Priorità: **P0** necessaria per un pilot con missioni ed esiti reali; **P1** necessaria per un’esperienza continuativa e recuperabile; **P2** evoluzione successiva. Stati riferiti al checkout recente, salvo indicazione diversa.

| ID | Area | Stato osservato | Gap / risultato richiesto | Priorità |
|---|---|---|---|---|
| FG-01 | Missioni sentinella | Spunti statici nel legacy; nessun ciclo di missione individuato | Catalogo, accettazione, questionario, scadenza, rinuncia e ricevuta | P0 |
| FG-02 | Prove fotografiche | Non individuato un flusso di acquisizione/upload missioni | Foto, metadati minimi, permessi, upload recuperabile, conservazione e accessi | P0 |
| FG-03 | Verifica contributi | Pubblicazione esiti autorizzata presente; manca il percorso delle osservazioni | Coda, assegnazione, integrazioni, validazione/rifiuto motivato e tracciamento | P0 |
| FG-04 | Misurazione | Tre andamenti; fonte/data/spiegazione presenti | Baseline, indicatori e soglie versionati prima del lock | P0 |
| FG-05 | Interventi | Non individuata un’entità dedicata | Distinguere intenzione, avanzamento, effetto e temporaneità | P0 |
| FG-06 | Esiti incerti e ricorsi | Risultati provvisori presenti; pubblicazioni immutabili | Termine di chiusura, non determinabile, contestazione e rettifica tracciata | P0 |
| FG-07 | Incentivi sentinelle | Punti fantasy e riflessione presenti; nessun ledger XP missioni | Accrediti idempotenti dopo validazione, regole anti-spam e separazione dal fantasy | P0 |
| FG-08 | Registrazione / accesso | Cookie anonimo firmato; identità legata al browser | Account recuperabile, login, logout, sessioni multiple e recupero | P1; P0 se il pilot richiede continuità tra dispositivi |
| FG-09 | Migrazione ospite → account | Non individuata | Conservare squadra, membership e contributi senza duplicare XP o identità | Insieme a FG-08 |
| FG-10 | Creazione e adesione leghe | UI, repository API e backend presenti | Rendere il percorso disponibile e comprensibile nel profilo scelto; non rifarlo da zero | P1 |
| FG-11 | Inviti e gestione leghe | Codice, scadenza, rotazione, revoca, uscita/archiviazione presenti | Link di adesione sicuro, ingresso guidato, trasferimento proprietà e gestione membri se richiesti | P1 per invito guidato; P2 per gestione estesa |
| FG-12 | Leghe cooperative | Backend restituisce `cooperativeScore: null`; demo mostra dati sintetici | Obiettivi di copertura e contributi validati, metriche e regole proprie | P1 |
| FG-13 | Ritorno e notifiche | Non individuato un flusso notifiche missioni | Inbox, integrazioni richieste, esito e ricontrolli; canali esterni facoltativi | P1 |
| FG-14 | Continuità del calendario | Calendario demo persistito, senza rinnovo automatico documentato | Apertura nuova stagione, nuove giornate e chiusura della precedente | P1 |
| FG-15 | Reale vs demo e pubblicazione | Profili diversi, fonti sintetiche e gate operativi aperti | Fonti reali approvate, ruoli nominati e verifica del profilo distribuito | P0 |

## Leghe private: che cosa c’è davvero

Nel profilo API recente il percorso include:

- Creazione con uno dei nomi/tipi `Amici`, `Quartiere`, `Comune`; fino a tre leghe attive possedute per stagione.
- Creazione idempotente, invito casuale, copia del codice, adesione e pseudonimi automatici.
- Scadenza degli inviti, rotazione che revoca i precedenti e revoca esplicita.
- Classifica riservata ai membri e visibile da tre competitori.
- Ingresso competitivo prima del primo lock della stagione; successivamente ingresso come spettatore.
- Uscita; se esce il proprietario, la lega viene archiviata.

La UI remota è selezionata da `manager.isRemote`. La UI mock presenta classifiche predisposte: non contiene lo stesso flusso di creazione/adesione. Questo può spiegare perché il percorso sembra mancante nella demo.

Non risultano nel flusso esaminato nome personalizzato, passaggio di proprietà, espulsione membri o adesione tramite link. Sono estensioni da decidere, non tutte requisiti della prima versione. Il tipo «Comune» è comunque un template di lega privata: non equivale a una classifica comunale pubblica.

Flusso proposto da completare: **Leghe → Crea → tipo, Comune, stagione e regole → conferma → lega creata → genera invito → condividi → adesione con riepilogo → ruolo competitivo/spettatore → classifica**. L’adesione da invito deve sopravvivere al login senza esporre il token a log o analytics. Dopo il primo lock va mostrata la limitazione prima della conferma; per consentire nuovi gruppi competitivi a stagione avviata serve una decisione sulle regole, non una semplice modifica del pulsante.

## Registrazione: proposta minima

Consentire l’esplorazione senza account. Chiedere di rendere recuperabile il profilo quando si vuole accettare una missione o conservare una partecipazione continuativa a una lega.

Proposta: account con email verificata e accesso tramite codice monouso, mantenendo un pseudonimo pubblico. Il metodo è una scelta progettuale, non una funzione già presente; provider e dettagli di sicurezza vanno definiti nell’implementazione. Non introdurre identificazione forte per la sola osservazione civica senza un requisito esplicito.

Percorso: **Continua → email → codice → account verificato → collega la sessione ospite → riprendi missione/invito**. Prevedere codice scaduto, reinvio limitato, indirizzo errato, account già esistente, sessione scaduta, revoca dei dispositivi e cancellazione.

Il collegamento dell’ospite deve essere verificato dal server e atomico. In presenza di un account con una squadra già esistente, non sommare punteggi o importare snapshot bloccati: proporre una riconciliazione esplicita e compatibile con le regole. Non unire automaticamente utenti solo perché condividono un dispositivo.

Per il pilot ristretto l’identità anonima può restare, purché la perdita di accesso dopo cancellazione del cookie sia chiara. Non è sufficiente per promettere recupero, premi di valore o resistenza alle identità multiple. Un’email verificata migliora la continuità ma non dimostra «una persona, un account».

## Incrementi implementabili e accettazione

| Incremento | Contenuto | Criteri minimi di accettazione |
|---|---|---|
| I0 — Congelare la baseline | Scegliere checkout/profilo, confermare riuso delle leghe e scrivere protocolli/ruoli | Nessun gap classificato sul codice sbagliato; una categoria con criterio misurabile e responsabile |
| I1 — Missione completa | Lista, istruzioni, slot, risposte, bozza, upload, invio e ricevuta | Rinuncia e scadenza liberano slot; retry e risposta persa non duplicano invii; permessi negati e offline gestiti |
| I2 — Verifica e riconoscimento | Console revisore, richieste integrazione, decisione e ledger XP | Nessuna autovalidazione; contributo valido «nessun problema» riconosciuto; nessun doppio accredito |
| I3 — Problema/intervento/esito | Baseline, interventi temporanei, ricontrolli, pubblicazione e non determinabile | Criteri congelati prima del lock; fonte/prove e motivazione consultabili; contestazioni tracciate; regole punteggio versionate |
| I4 — Account e leghe continuative | Accesso, recupero, collegamento ospite e invito guidato | Squadra e lega recuperate da altro dispositivo; tentativo di importare punti duplicati rifiutato; token invito non nei log |
| I5 — Cooperazione e ritorno | Obiettivi delle leghe, inbox e ricontrolli | Lo stesso contributo non incrementa più volte un obiettivo; notifiche opzionali; progressi distinti dai risultati fantasy |

I4 può precedere I1 se il pilot deve partire con account recuperabili. I2 deve essere operativo prima di raccogliere contributi reali; I3 prima di usarli per assegnare esiti competitivi. Riutilizzare le infrastrutture di ricevuta, retry e idempotenza dove compatibili, senza condividere automaticamente identità o storage fra il ramo legacy e quello fantasy.

## Verifica dell’interesse nel pilot

Misurare scoperta→accettazione→invio→validazione, tempo medio, abbandono per passo, rifiuti e motivi, tempo di revisione, ritorno al secondo controllo e copertura di luoghi distinti. Distinguere persone nuove da persone che contribuiscono ripetutamente.

Il pilot deve provare tre casi: problema presente, problema assente, intervento temporaneo con ricontrollo. Verificare che le persone capiscano chi decide, quando ricevono XP e perché un effetto temporaneo non equivale a una risoluzione definitiva.

Le metriche e i target vanno fissati prima dell’avvio. Evitare di chiamare successo un aumento di segnalazioni senza qualità, copertura o capacità di revisione. Gli incentivi non monetari proposti devono essere confrontati con il tasso di ritorno e con feedback delle persone.

## Decisioni da chiudere

1. Modalità iniziale: pilot anonimo ristretto oppure account recuperabile dall’inizio.
2. Responsabili di missioni, verifica e pubblicazione; gestione dei conflitti di interesse.
3. Prima categoria e relativo protocollo; tempi di osservazione e revisione.
4. Regole XP, tetti per finestra e assenza di collegamento diretto ai punti fantasy.
5. Chiusura degli esiti non determinabili, parità competitiva e rettifiche.
6. Regole per gruppi creati dopo il primo lock e necessità di proprietà trasferibile.
7. Conservazione e visibilità delle prove; canali di ritorno; eventuali premi economici successivi.

## Evidenze locali

Percorsi seguenti relativi al checkout recente `/Users/gabrieleserra/miglioraPaese`, salvo il riferimento esplicito al workspace corrente.

| Evidenza | File e punto di lettura |
|---|---|
| Leghe remote: creazione, codice e gestione | `lib/features/fantasy/presentation/pages/remote_leagues_page.dart`, metodo `build` |
| Distinzione mock/API nella pagina leghe | `lib/features/fantasy/presentation/pages/fantasy_pages.dart`, `_LeaguesPageState.build` |
| Contratto client leghe | `lib/features/fantasy/data/fantasy_league_repository.dart`; `api_fantasy_repository.dart`, `createLeague`, `joinLeague`, `rotateInvite` |
| Regole server leghe | `services/backend/src/fantasy/leagues.js`, `create`, `addMember`, `invite`, `read`, `leave` |
| Cookie anonimo firmato | `services/backend/src/identity.js`, `createAnonymousIdentity` e funzioni di firma/verifica |
| Esiti autorizzati, sinteticità, immutabilità e punteggio | `services/backend/src/fantasy/results.js`, `publish`, `view`, `scoreFantasyCard`; `services/backend/src/server.js`, dispatch fantasy |
| Modello andamento e assenza di interventi dedicati nel modello esaminato | `lib/features/fantasy/domain/fantasy_models.dart`, `CivicTrend`, `FantasyCard`, `CardOutcome` |
| Test presenti su leghe, pubblicazione e UI/API | `services/backend/test/fantasy_leagues.test.js`, `fantasy_results.test.js`; `test/features/fantasy/logic/fantasy_remote_leagues_test.dart`; `test/features/fantasy/data/api_fantasy_repository_test.dart` |
| Calendario, limiti account e gate del pilot | `docs/backend/fantasy_pilot_go_no_go.md`, «Perimetro implementato» e scheda go/no-go |
| Spunti statici di osservazione | `lib/features/home/presentation/home_page.dart`, `_ActivationMissionsPanel`; `lib/features/game/presentation/play/play_page.dart`, lista `_missions` |
| Nome SentiNel | `lib/core/copy/venial_copy.dart`, `bootStickerLabel`: nome nell’interfaccia, non ruolo operativo implementato |
| Proposte legacy e revisione locale | Workspace corrente: `services/backend/README.md`, «Policy proposte e revisione locale — C4» |

Le indicazioni sul percorso guidato adottano le raccomandazioni UX locali per avanzamento dei processi, feedback di invio e label dei campi (`ui-ux-pro-max`, ricerca `form multi step`). Non è stata progettata o verificata una nuova schermata in questo audit.
