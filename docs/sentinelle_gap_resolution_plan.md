# Piano per chiudere i gap di Migliora Paese / Fanta Comune

> Evoluzione successiva alla chiusura locale, 16 ottobre 2026: target cloud
> Supabase con Supabase Auth e Resend Free; architettura/tecnologia backend
> modificabili per rispettare costo zero e tempi di apertura. Il mantenimento
> del backend Node riguarda l'esecuzione locale storica di questo piano, non
> un vincolo del nuovo porting. Dettagli ed evidenze nel
> [runbook cloud](sentinelle_deploy_zero_budget_runbook.md) e nel
> [diagramma prodotti](sentinelle_cloud_architecture.md). Nessuna attestazione
> di implementazione/deploy cloud o modifica retroattiva dei gate locali.

Data iniziale: 13 ottobre 2026. Metodo aggiornato: 15 ottobre 2026. Chiusura locale: 16 ottobre 2026.
Stato: fasi 0–8 verificate localmente; candidato e limiti nel dossier operativo.
Pilot reale NO-GO per gate esterni aperti.

Riferimenti: [report dei gap](functional_gap_report_2026-10-13.md),
[prompt di orchestrazione](sentinelle_orchestration_prompts.md),
[registro di esecuzione](sentinelle_execution_log.md).

## Obiettivo e scelte consolidate

Realizzare Sentinelle nel **workspace corrente**, completando tutti i gap
FG-01–FG-15 attraverso incrementi verificabili. Primo traguardo: missioni di
osservazione della pulizia di aree pubbliche definite, con account recuperabili,
prove, revisione umana e riconoscimenti.

Scelte:

- PostgreSQL e architettura backend attuale; riuso del dominio fantasy dal
  checkout recente, adattando la persistenza.
- Account con email verificata e codice monouso prima di accettare missioni.
- 10 XP per contributo validato, indipendentemente dal problema rilevato;
  nessun bonus o premio economico iniziale.
- Esiti non determinabili a zero punti di osservazione/previsione, con regole
  fantasy versione 2.
- Inviti guidati e trasferimento proprietà delle leghe; ingresso tardivo come
  spettatore.
- Preparazione e verifica locale complete; servizi esterni e pilot reale
  subordinati a un gate operativo separato.

### Baseline e provenienza

Destinazione: `/Users/gabrieleserra/Documents/Codex/2026-07-11/github-plugin-github-openai-curated-remote/work/miglioraPaese`.
Sorgente da adattare: `/Users/gabrieleserra/miglioraPaese`.

Riferimenti storici del report, confermati alla preparazione dei documenti:

| Checkout | HEAD di riferimento |
|---|---|
| Workspace corrente | `1fad162218e758efa3a556790e42b335a6196959` |
| Checkout recente | `14b0edf18caa070a3d4a28667251a7b175ca0ce6` |

Questi SHA non sono una baseline operativa congelata. Il workspace corrente
contiene numerose modifiche locali: HEAD da solo non descrive il materiale da
preservare. All'avvio della fase 0 verificare nuovamente HEAD, branch, stato
tracked/untracked, istruzioni applicabili e toolchain di entrambi i checkout;
registrare la baseline effettiva prima delle modifiche. Non assumere stato
remoto, PR o deploy dai riferimenti locali.

## Sequenza degli incrementi

| Fase | Lavoro e risultato verificabile | Gap |
|---|---|---|
| **0 — Consolidare la baseline** | Inventariare e consolidare le modifiche locali senza perderle; eseguire i controlli iniziali e registrare commit, profili e regressioni. Preparare una matrice di porting dal checkout recente. | FG-15 |
| **1 — Recuperare fantasy e leghe** | Portare repository Flutter, gioco remoto, calendario, esiti e leghe nella struttura attuale. Adattare SQLite a PostgreSQL; conservare regole, idempotenza e test esistenti. Il profilo API deve mostrare creazione e adesione reali. | FG-10, FG-15 |
| **2 — Account e continuità** | Implementare codice email, login, logout, recupero e revoca dispositivi. Collegare atomicamente la sessione ospite; riprendere missione o invito dopo l'accesso. | FG-08, FG-09 |
| **3 — Missioni e prove** | Catalogo per Comune/zona, dettaglio, prenotazione, rinuncia, questionario, bozza recuperabile, foto, invio e ricevuta. Slot e scadenze autorevoli sul server. | FG-01, FG-02 |
| **4 — Revisione e XP** | Console operatori con assegnazione, integrazioni, approvazione e rifiuto motivato. Ledger XP transazionale e controlli sui conflitti di interesse. Questa fase precede qualsiasi raccolta reale. | FG-03, FG-07 |
| **5 — Misurazione ed esiti** | Problemi, baseline, protocolli, interventi, ricontrolli e valutazioni. Pubblicazione motivata, non determinabile, contestazioni e rettifiche con ricalcolo. Questa fase precede i punti competitivi derivati da prove reali. | FG-04, FG-05, FG-06 |
| **6 — Leghe continuative** | Invito tramite link, riepilogo prima dell'adesione e trasferimento proprietà. Conservare scadenza, revoca, rotazione e ruolo spettatore dopo il primo lock. | FG-11 |
| **7 — Cooperazione e ritorno** | Obiettivi di copertura, inbox per integrazioni/esiti/ricontrolli, follow facoltativo dei luoghi e rinnovo del calendario tramite pubblicazione amministrativa. | FG-12, FG-13, FG-14 |
| **8 — Preparazione operativa** | Candidato identificabile per commit/profilo, rehearsal completa, backup/restore, cancellazione, osservabilità e dossier go/no-go. | FG-15 |

Ogni fase comprende backend, contratto, client e verifiche necessari al proprio
risultato. Le funzionalità incomplete restano disattivate tramite configurazione
esplicita.

### Dipendenze e avanzamento

La sequenza predefinita è 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8. Completare e
verificare una fase prima di avanzare con implementazioni dipendenti. Letture e
preparazione indipendenti possono procedere in parallelo, senza aggirare i gate.
Account recuperabili precedono l'accettazione delle missioni. Nessuna raccolta
reale prima della revisione operativa e del gate finale; nessun punteggio reale
prima del completamento della fase 5 e dello stesso gate operativo.

### Metodo di esecuzione e contenimento del consumo

Questa revisione modifica il metodo, mantenendo requisiti FG-01–FG-15,
sequenza, verifiche di sicurezza e gate operativi. Non riavvia l'implementazione.

1. **Ripresa mirata.** Leggere il piano una volta per sessione e l'ultimo
   checkpoint del registro. Consultare report, log storici e checkout sorgente
   soltanto per requisiti o evidenze mancanti; non ripetere l'inventario delle
   fasi concluse se HEAD, file interessati e toolchain non sono cambiati.
   Salvare nuovi checkpoint/log/database sintetici in `.sentinelle-local/`,
   esclusa da Git; `/tmp` è effimero e non garantisce ripresa dopo riavvio.
   Il registro conserva digest ed esiti; se gli originali mancano dichiararlo
   e salvare lo stato corrente senza ricreare attestazioni storiche.
2. **Contratto prima del codice.** Usare un solo envelope per fase, con scope,
   owner, route/DTO e tipi esatti, stati/errori, autorizzazioni, idempotenza,
   revisioni e casi critici. L'orchestratore lo fissa prima di avviare backend e
   Flutter. Le decisioni già concordate non richiedono nuova conferma utente.
   Cambi di contratto necessari si aggiornano una volta e si comunicano agli
   autori prima di modificare i chiamanti.
3. **Deleghe limitate.** L'orchestratore esegue direttamente i compiti brevi o
   sequenziali. Usare subagenti solo per lavoro indipendente sostanziale:
   massimo due autori contemporanei, ciascuno con file esclusivi. Fornire un
   contesto nuovo e circoscritto (`fork_turns="none"`), con envelope, baseline e
   riferimenti ai soli file necessari; evitare di ereditare l'intera cronologia.
   Non tenere un revisore attivo per tutta l'implementazione. Avviarlo quando il
   candidato ha superato i test mirati, limitando la review al diff di fase e ai
   suoi chiamanti; anticipare solo questioni critiche di autorizzazione/contratto.
4. **Verifiche progressive.** Durante lo sviluppo eseguire test del componente
   e dei confini modificati, inclusi PostgreSQL reale e casi critici pertinenti.
   Alla chiusura eseguire una suite completa backend, una Flutter, analyze,
   manifest migrazioni e build dei profili interessati. Non ricostruire tutti i
   profili a ogni correzione: motivare quelli coinvolti; verificare tutti i
   profili supportati nella rehearsal finale. Render 390/1024/1440 per nuove UI
   o cambi layout; riusare evidenze per schermate invariate. Dopo una correzione
   ripetere i controlli impattati; ampliare solo per cambi trasversali, fallimenti
   o rischi residui. Registrare quali evidenze restano valide e perché.
   Se i test Flutter PostgreSQL importano il backend dallo stesso checkout,
   attendere sorgenti ferme di entrambi gli autori prima dei full integrati;
   stabilità del solo client non basta. Test locali indipendenti e analyze
   possono precedere il freeze condiviso, senza attestare il gate integrato.
5. **Output e registro compatti.** Salvare log completi su disco; riportare in
   chat esito, conteggi e soli errori utili. Cercare con `rg` e leggere sezioni
   pertinenti, evitando dump integrali ripetuti. Le deleghe restituiscono file,
   contratto cambiato, comandi/esiti, log e residui. Un checkpoint di fase include
   baseline/digest, verifiche, limiti e prossima azione; aggiungere note intermedie
   solo per decisioni di contratto, blocchi o evidenze che servono alla ripresa.
6. **Controllo del costo.** Prima di ogni delega indicare il beneficio concreto
   e il criterio di fine. Evitare agenti in attesa e scambi di stato invariato.
   Se si ripete lo stesso ciclo senza progresso, consolidare problemi e risolverli
   in sequenza. Registrare consumo solo se misurabile, senza inventare budget,
   percentuali di risparmio o equivalenze tra token e crediti. Non cambiare
   modello o livello di ragionamento senza indicazione dell'utente.

Alla ripresa usare il checkpoint finale fase8 e il dossier operativo: tutte le
fasi 0–8 sono concluse per l'ambiente sintetico locale. Non rilanciare suite o
orchestrazione senza modifiche/regressioni nuove. Il prossimo ambito è la
raccolta delle approvazioni esterne elencate nel dossier, prima di qualsiasi
attivazione reale; non è autorizzata implicitamente dal completamento tecnico.

## Comportamenti e contratti da implementare

### Backend e persistenza

- Conservare `/v1` e aggiungere risorse per account/sessioni,
  missioni/prenotazioni, osservazioni/prove, revisione, XP,
  protocolli/interventi/valutazioni e inbox. Aggiornare OpenAPI insieme alle
  implementazioni.
- Usare migrazioni PostgreSQL additive senza modificare quelle già applicate.
  Identità, ownership, tempo, autorizzazioni e punti vengono determinati dal
  server.
- Riutilizzare idempotenza, ricevute e controllo delle revisioni esistenti;
  nessun fallback silenzioso tra API e mock.
- Separare gli adapter per consegna email e storage delle immagini. Le prove
  locali usano email simulate e file sintetici; gli adapter operativi richiedono
  il gate finale.

### Account e missioni

- Consentire esplorazione senza account; richiedere email verificata
  all'accettazione. Pseudonimo pubblico, sessioni revocabili e codici monouso con
  scadenza e limiti ai tentativi.
- Non importare automaticamente punti o snapshot dalla demo. Se ospite e account
  hanno squadre concorrenti, conservare quella dell'account e richiedere una
  scelta esplicita prima di abbandonare lo stato ospite.
- Prima missione: osservazione di rifiuti visibili in un'area delimitata, con
  punti fotografici ripetibili e ricontrollo settimanale. Protocollo versionato
  con indicatore, soglia, finestra e istruzioni pubblicati prima del lock.
- Supportare “nessuna criticità”, “non osservabile” e “non so”. Rinuncia senza
  penalità; scadenza e rinuncia liberano gli slot.
- Consentire salvataggio della bozza offline; prenotazione e invio richiedono
  conferma server. Upload recuperabile e ricevuta interrogabile dopo una risposta
  persa.
- Prove accessibili ad autore e operatori autorizzati; al pubblico solo sintesi
  approvate. Rimuovere metadati superflui, impedire upload pubblici diretti e
  applicare retention configurabile.

### Revisione, XP ed esiti

- Distinguere sentinella, moderatore, verificatore e responsabile esiti. Vietare
  autovalidazione e decisioni competitive su carte in cui l'operatore compete.
- Revisionare ogni contributo. Accreditare **10 XP una sola volta** dopo
  validazione; massimo un contributo premiato per persona/luogo/finestra, salvo
  repliche richieste. Affidabilità e punti fantasy restano separati.
- Modellare separatamente problema, intervento, missione, osservazione e
  valutazione; supportare collegamenti molti-a-molti fra problemi e interventi.
- Mantenere `improves`, `stable`, `worsens`; aggiungere una disposizione distinta
  `undeterminable`, senza convertirla in `stable`.
- Alla scadenza di pubblicazione dichiarata, chiudere le carte prive di evidenza
  sufficiente come non determinabili. Zero punti di osservazione/previsione;
  conservare regole di penalità e riflessione, mostrando la copertura.
- Applicare la versione 2 solo alle nuove stagioni. Conservare originale,
  rettifica e motivazione; ricalcolare risultati e classifiche interessati in
  una nuova revisione consultabile.

### Leghe e continuità

- Usare link con token esclusi da log e analytics; conservare l'invito durante il
  login e confermare l'adesione dopo il riepilogo.
- Trasferire la proprietà a un membro che accetta; in assenza di trasferimento,
  mantenere l'archiviazione all'uscita del proprietario.
- Misurare cooperazione tramite luoghi e finestre coperti da contributi validati,
  contando ogni unità una sola volta.
- Pubblicare stagioni e giornate mediante comando amministrativo idempotente;
  nessun rinnovo implicito del seed demo e nessuna modifica allo storico.

## Verifiche e criteri di chiusura

- **Regressione:** backend e Flutter esistenti verdi; flussi locali di proposte,
  bozze e ricevute preservati; parità delle fixture fantasy dopo il porting
  PostgreSQL.
- **Concorrenza e recupero:** ultimo slot richiesto da due utenti, prenotazione
  scaduta, doppio invio, risposta persa, riavvio, revisione obsoleta e upload
  interrotto.
- **Identità:** codice scaduto/riutilizzato, accesso da altro dispositivo,
  revoca, collegamento ospite ripetuto e conflitto tra squadre senza duplicazione
  dei punti.
- **Autorizzazioni:** isolamento tra utenti e Comuni, accesso alle prove,
  divieto di autovalidazione e doppio accredito XP.
- **Esiti:** problema presente, assente e intervento temporaneo; prove
  discordanti, carta non determinabile, rettifica e ricalcolo ripetuto senza
  duplicazioni.
- **Esperienza:** permessi negati, assenza di geolocalizzazione, offline,
  accessibilità da tastiera e layout a 390, 1024 e 1440 px.
- **Operatività:** migrazioni su PostgreSQL reale, backup/restore,
  cancellazione e retention, assenza di token nei log e identificazione esplicita
  del profilo distribuito.

Comandi base: `npm --prefix services/backend test`, verifica delle migrazioni,
`flutter analyze`, `flutter test` e build web dei profili interessati. Verificare
gli script effettivi e la toolchain alla baseline; non eseguire migrazioni su
database operativi durante i controlli locali.

I test citati nel report non vengono considerati rieseguiti: la fase 0 deve
produrre una nuova baseline di evidenze. Un'attività implementata non è ancora
verificata; i gate operativi restano distinti dai risultati tecnici.

## Gate del pilot reale

Il codice può essere completato e verificato localmente prima della scelta dei
servizi esterni. L'avvio reale richiede evidenze approvate su provider e budget,
consegna email, storage, autenticazione forte degli operatori, referenti, fonti,
retention, informativa, backup e gestione incidenti.

Misurare funnel missione→invio→validazione, tempi e carico di revisione, motivi di
rifiuto, copertura e ritorno al secondo controllo. Fissare i target nel dossier
prima dell'avvio; il volume delle segnalazioni, da solo, non costituisce successo.

Nomi personalizzati, espulsione membri, mappa, notifiche esterne e premi economici
restano fuori dalla prima versione. La gestione operativa di provider e dati
reali richiede un'approvazione separata; questo piano non autorizza push, merge,
deploy, spese o creazione di risorse esterne.

Le scelte di account e persistenza differiscono da alcuni documenti storici:
aggiornare gli ADR pertinenti durante le fasi applicative senza presumere
autorizzazioni esterne e senza trasferire i vincoli SQLite del precedente port.
