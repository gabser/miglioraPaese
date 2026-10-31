# Sentinelle — prompt di orchestrazione

Data iniziale: 13 ottobre 2026. Metodo aggiornato: 15 ottobre 2026.
Preparare questi prompt non avvia l'implementazione.
Il [piano](sentinelle_gap_resolution_plan.md) è la fonte dei requisiti;
il [registro](sentinelle_execution_log.md) conserva stato ed evidenze.

## Prompt principale — pronto da copiare

```text
Agisci come orchestratore della realizzazione di Sentinelle per Migliora Paese /
Fanta Comune. Leggi docs/sentinelle_gap_resolution_plan.md una volta per sessione
e l'ultimo checkpoint di docs/sentinelle_execution_log.md. Consulta soltanto le
sezioni pertinenti di docs/functional_gap_report_2026-10-13.md e della cronologia
quando mancano requisiti o evidenze. Applica il metodo di contenimento del consumo
nel piano; non riaprire le fasi già verificate senza una regressione dimostrata.
Il piano è la fonte dei requisiti; il report descrive evidenze storiche, non
certifica la baseline attuale. Esegui il lavoro locale previsto dal piano,
completando implementazione, verifiche e correzioni senza fermarti a ripianificare.

DESTINAZIONE E BASELINE
Lavora nel repository:
/Users/gabrieleserra/Documents/Codex/2026-07-11/github-plugin-github-openai-curated-remote/work/miglioraPaese
Usa /Users/gabrieleserra/miglioraPaese come sorgente da leggere e adattare.
Verifica istruzioni AGENTS.md applicabili, skill pertinenti, HEAD, branch,
stato tracked/untracked e toolchain di entrambi i checkout. Registra la baseline
effettiva: gli SHA nel piano sono storici e HEAD non include il lavoro locale.
Non dedurre stato remoto, PR o deploy dalle evidenze locali.

Proteggi tutte le modifiche preesistenti. Non sostituire il workspace, non
importare indiscriminatamente il checkout sorgente, non usare reset distruttivi
o force push. Se serve isolamento, assicurati che il checkout di lavoro includa
esplicitamente la baseline locale concordata; un worktree creato dal solo HEAD
non contiene le modifiche non committed. Registra provenienza e destinazione
dei cambiamenti e fermati solo sulle sovrapposizioni non risolvibili in sicurezza.

DECISIONI VINCOLANTI
Mantieni PostgreSQL e la struttura application/domain/http/persistence attuale.
Adatta il dominio fantasy e i repository Flutter del checkout recente, senza
introdurre SQLite come storage operativo o copiare il backend monolitico.
Preserva proposte, bozze, ricevute e contratti legacy compatibili.
Account recuperabili con email verificata e codice monouso precedono le missioni.
Prima categoria: pulizia di aree pubbliche delimitate e ricontrolli settimanali.
10 XP per contributo validato, una sola volta, senza bonus né premi economici;
massimo uno per persona/luogo/finestra salvo repliche richieste.
Separa XP, affidabilità e punti fantasy. Mantieni revisione umana e divieti di
autovalidazione e conflitto di interesse.
Regole fantasy v2 per nuove stagioni: undeterminable è una disposizione distinta,
vale zero punti di osservazione/previsione; conserva penalità e riflessione,
mostra copertura e conserva rettifiche con ricalcolo versionato.
Leghe: inviti guidati, trasferimento accettato della proprietà, late join come
spettatore; senza trasferimento resta l'archiviazione all'uscita del proprietario.

SEQUENZA E CONTRATTI
Segui le fasi 0–8 del piano. Prima di ogni fase leggi il registro, verifica
prerequisiti e baseline, identifica i requisiti FG e prepara il suo task envelope.
Completa e verifica una fase prima di implementare le dipendenti. Puoi anticipare
letture o preparazione indipendenti, senza aggirare i gate.
Prima del codice fissa nell'unico envelope di fase route/DTO con tipi esatti,
stati/errori, autorizzazioni, revisioni/idempotenza e casi critici. Non avviare
autori paralleli su contratti ancora da concordare. Aggiorna insieme OpenAPI,
backend, mapper/repository Flutter e test.
Usa /v1, migrazioni additive, identità e tempo autorevoli sul server,
transazioni, idempotenza e revisioni. Nessun fallback silenzioso API→mock.
Tieni disattivate le funzioni incomplete. Usa email simulate e file sintetici
per le prove locali, con adapter distinti dai servizi operativi.

COORDINAMENTO
Esegui direttamente compiti brevi o sequenziali; usa subagenti per attività
indipendenti sostanziali, massimo due autori contemporanei, senza creare nuove
chat utente. Ogni delega ha un beneficio concreto e un criterio di fine.
Usa fork_turns="none" e un contesto circoscritto con baseline, envelope e file
pertinenti, senza copiare l'intera cronologia. Assegna un solo autore per file;
mantieni contratti condivisi e integrazione sotto un proprietario esplicito.
Ruoli: contratto/persistenza, Flutter/esperienza, verifica indipendente.
Per ogni delega comunica fase, baseline, obiettivo, file assegnati, dipendenze,
esclusioni, criteri di accettazione e formato del risultato.
Richiedi file modificati, comandi ed esiti effettivi, evidenze, rischi e residui.
Un revisore diverso dall'autore controlla il candidato dopo i test mirati,
limitandosi al diff di fase e ai chiamanti interessati. Non mantenerlo attivo
durante tutto lo sviluppo; anticipa solo criticità di autorizzazione/contratto.
Se la delega non è disponibile, svolgi i ruoli in sequenza e registra il limite.
L'orchestratore verifica gli output e mantiene la responsabilità finale.

VERIFICHE E REGISTRO
Esegui i controlli pertinenti del piano con gli script reali della baseline.
Durante lo sviluppo usa test mirati. Alla chiusura esegui una suite completa
backend, una Flutter, analyze, manifest migrazioni e build dei profili coinvolti.
Dopo correzioni ripeti i controlli impattati; amplia per modifiche trasversali,
fallimenti o rischi residui. Verifica tutti i profili nella rehearsal finale.
Verifica PostgreSQL su database locale di test; usa fixture sintetiche e tempi
controllati per account, missioni, revisione, XP, esiti e calendario.
Copri concorrenza, risposta persa, retry, riavvio, isolamento e cancellazione.
Verifica render e percorsi Flutter a 390, 1024 e 1440 px, tastiera, permessi
negati, geolocalizzazione assente e offline. Non equiparare screenshot a prove
umane, né test automatici a certificazioni.
Salva i log completi su disco e mostra solo esiti, conteggi ed errori utili.
Aggiorna docs/sentinelle_execution_log.md con un checkpoint compatto per fase:
stato, baseline/revisione, file o diff, comando/esito, artefatti, limiti e prossima
azione. Note intermedie solo per decisioni di contratto, blocchi o evidenze utili
alla ripresa. Evita riletture integrali, dump ripetuti e report di stato invariato.
Distingui da fare, in corso, implementato, verificato e bloccato.
Non segnare verificato ciò che è solo scritto; non riusare conteggi storici.
Se cambia la revisione, rivaluta i controlli interessati.

AUTORIZZAZIONI E GATE
Il prompt autorizza l'esecuzione locale del piano quando viene invocato.
Non autorizza push, merge, deploy, servizi esterni, spese, raccolta di dati reali,
invio di email reali o creazione di risorse esterne. Non eredita autorizzazioni
dal prompt del port delle PR 33/34 o da altri piani storici.
Rispetta i gate operativi del piano: provider/budget, email/storage,
autenticazione operatori, ruoli, fonti, privacy/retention, backup e incidenti.
Prepara il dossier e le verifiche locali senza scegliere o attivare provider
implicitamente. Nessuna raccolta reale prima della revisione e del gate finale;
nessun punteggio competitivo reale prima della fase 5 e del gate operativo.
Non inventare approvazioni, protocolli ratificati, referenti o risultati umani.

RIPRESA E CONCLUSIONE
Continua fino al completamento locale o a una dipendenza esterna reale.
In caso di blocco completa prima le attività indipendenti, documenta ciò che
serve, il responsabile richiesto e il punto preciso da cui riprendere.
Comunica progressi sintetici durante il lavoro. Alla conclusione riporta
risultati per fase e gap, baseline finale, verifiche effettive, evidenze,
limiti e gate aperti. Non dichiarare operativo il pilot per soli test verdi.
```

## Modello di prompt — singola fase

Compilare tutti i campi tra parentesi angolari prima dell'uso. Le decisioni già
concordate nel piano non sono parametri da ridefinire. La matrice delle fasi nel
piano fornisce dipendenze e gap; il registro fornisce lo stato effettivo.

```text
Esegui soltanto la fase <numero e titolo> di docs/sentinelle_gap_resolution_plan.md.
Leggi il piano una volta per sessione, le sole sezioni pertinenti del report e
l'ultimo checkpoint di docs/sentinelle_execution_log.md prima di modificare file.
Applica il metodo di contenimento del consumo del piano.
Applica i confini, le decisioni e le autorizzazioni del prompt principale
in docs/sentinelle_orchestration_prompts.md.

OBIETTIVO
<Risultato osservabile della fase e comportamento atteso per utente/operatore.>
REQUISITI
<ID FG coinvolti e criteri del piano da soddisfare.>
PREREQUISITI
<Fasi richieste, stato verificato e riferimenti alle relative evidenze.>
BASELINE
<Percorso destinazione, HEAD, branch, modifiche locali incluse/escluse,
checkout sorgente e revisione, toolchain, data della verifica.>
Prima di agire verifica questi dati. Se sono cambiati, aggiorna il registro e
rivaluta i prerequisiti; non assumere valido un controllo su un altro diff.

RESPONSABILITÀ
<Orchestratore, responsabile contratto, proprietari dei file, revisore.>
<Elenco file/subsistemi assegnati e ordine delle modifiche condivise.>
Delega solo attività indipendenti; un solo autore per file alla volta.
Mantieni integrazione e decisioni vincolanti sotto l'orchestratore.

ESCLUSIONI
<Funzioni rinviate e parti che la fase non deve modificare.>
Nessun push, merge, deploy, servizio esterno, spesa o dato reale è autorizzato.
Proteggi il lavoro preesistente; nessun reset distruttivo o import indiscriminato.

IMPLEMENTAZIONE E VERIFICHE
<Contratti e comportamento da realizzare, migrazioni additive se necessarie.>
<Casi di accettazione, comandi effettivi e profili da verificare.>
Fissa il contratto prima del codice; durante lo sviluppo usa test mirati,
alla chiusura le suite complete e le build pertinenti. Delega con contesto
circoscritto; richiedi review indipendente sul candidato pronto.
Aggiorna contratto, backend e client nello stesso incremento quando necessario.
Correggi i difetti rilevati e ripeti i soli controlli interessati.
Non avanzare alla fase successiva; prepara un handoff con i prerequisiti ottenuti.

RISULTATO E RIPRESA
Aggiorna il registro con baseline, diff/file, comandi, risultati, artefatti,
stato dei requisiti e gate aperti. Se manca un prerequisito, completa le attività
indipendenti e indica la dipendenza senza dichiarare la fase verificata.
<Indicare ultimo checkpoint valido, attività residue e punto di ripresa.>
Concludi con risultato ottenuto, evidenze effettive, limiti e prossimo passo
autorizzato. Non presentare un'implementazione non verificata come completata.
```
