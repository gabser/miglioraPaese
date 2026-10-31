# Sentinelle — playbook e taccuino di rilascio

Creato il **16 ottobre 2026**. Ultimo aggiornamento operativo: **nessuno; esecuzione non iniziata**.

Guida da eseguire: [guida operativa al rilascio](sentinelle_deploy_guida_operativa.md). Questo taccuino registra il lavoro; comandi, criteri di accettazione e procedure di recupero restano nella guida. Se la guida cambia, confrontare i passi interessati prima di proseguire.

## Punto di ripresa

| Voce | Stato attuale |
|---|---|
| Avanzamento della sequenza | **0/16 passi completati** |
| Passo corrente | Nessuno avviato |
| Prossimo passo | **S0 — fotografare lo stato del repository e verificare gli strumenti** (§12.1 e §3.2 della guida) |
| Blocchi della guida | **12/12 aperti**; nessuno risolto o verificato in questa esecuzione |
| Collaudo cloud | **0/20 PASS; 20 non eseguiti** |
| Decisione di rilascio | **NO-GO pilot**, come nella guida; nessun GO registrato |
| Ultima sessione operativa | Nessuna |
| Riprendere da | Aprire una scheda sessione, leggere S0 nella guida e registrare le verifiche effettive |

Questi numeri misurano i passi chiusi, non una percentuale di lavoro o una stima dei tempi. La creazione del taccuino non completa S0. Le prove locali storiche della guida non sono prove di questa esecuzione.

## Board Trello

Preparazione del tracciamento: **17 ottobre 2026**. Board privata [Sentinelle — Rilascio](https://trello.com/b/Pqet2WAc/sentinelle-rilascio), nel workspace “gabrser's workspace”. Questa preparazione non avvia S0 e non costituisce una sessione operativa di deploy.

La board contiene cinque colonne: **Da fare → In corso → Bloccato → Da verificare → Completato**. Sono presenti 16 schede passo con checklist, 12 schede blocco aperto, una scheda di istruzioni e un registro T01–T20 con checklist separate per collaudo e verifica pertinente sul target pilot. All'inizializzazione tutte le schede sono in **Da fare** e tutte le checklist sono non spuntate.

Durante il lavoro in chat aggiornare lo stato su Trello e il diario qui, conservando gli stessi ID S/B/T e i riferimenti SES. **Non è configurata una sincronizzazione automatica né un monitoraggio in background.** “Da verificare” indica lavoro svolto in attesa di validazione; “Completato” richiede prova registrata. Le esclusioni restano motivate e approvate nel diario e non diventano PASS.

| Riferimento | Scheda Trello |
|---|---|
| LEGGIMI | [LEGGIMI — Stato, guida e regole della board](https://trello.com/c/ZO57rGzi) |
| S0 | [S0 — Stato iniziale del repository e strumenti](https://trello.com/c/dYVfL4a9) |
| S1 | [S1 — Decisioni del titolare e risorse](https://trello.com/c/V7D9iz7t) |
| S2 | [S2 — Progetto Supabase di collaudo](https://trello.com/c/gONwAssX) |
| S3 | [S3 — P1: fattibilità Edge, transazioni e immagini](https://trello.com/c/ikJMjJat) |
| S4 | [S4 — Schema, migrazioni e policy](https://trello.com/c/EqLPXdvj) |
| S5 | [S5 — Dominio, DNS e SMTP Resend](https://trello.com/c/ZguVyN8J) |
| S6 | [S6 — Auth OTP, sessioni e integrazione Flutter](https://trello.com/c/PyS3rZCI) |
| S7 | [S7 — Storage e fotografie private](https://trello.com/c/2Mrj3oFW) |
| S8 | [S8 — Porting API, job e contenuti operativi](https://trello.com/c/xEk3xv89) |
| S9 | [S9 — Cancellazione account, backup e restore](https://trello.com/c/1UHdW73U) |
| S10 | [S10 — Suite finali e candidato di rilascio](https://trello.com/c/dP4vSBvF) |
| S11 | [S11 — Build e pubblicazione frontend di collaudo](https://trello.com/c/BBEXXSuB) |
| S12 | [S12 — Collaudo cloud end-to-end](https://trello.com/c/9UUlivMr) |
| S13 | [S13 — Preparazione e smoke del pilot](https://trello.com/c/29K3pFTp) |
| S14 | [S14 — Apertura e conduzione del pilot](https://trello.com/c/Dlds3H4W) |
| S15 | [S15 — Chiusura del pilot o gestione incidente](https://trello.com/c/uNU2jTNb) |
| B1 | [B1 — Fattibilità backend Edge/DB/PNG e latenza non provata; blocca architettura eseguibile](https://trello.com/c/rLUSKnmp) |
| B2 | [B2 — Nessun dominio mittente controllato/verificato accertato; OTP esterno a zero non dimostrato](https://trello.com/c/Urmch49B) |
| B3 | [B3 — Auth/JWT, revoca immediata, MFA e migrazione guest/account ancora custom](https://trello.com/c/br7DwpPS) |
| B4 | [B4 — Porting API/schema/policy e chiusura mutazioni legacy mancanti](https://trello.com/c/adspHUth) |
| B5 | [B5 — Storage cloud/normalizzazione/finalizzatore e quote foto non verificati](https://trello.com/c/ebaw2R2V) |
| B6 | [B6 — Backup coordinato Auth/DB/byte foto, custodia/diario indipendente e restore cloud assenti](https://trello.com/c/PdkXPit7) |
| B7 | [B7 — Chiusura account completa assente e policy classi non ratificata](https://trello.com/c/bd7X7Fak) |
| B8 | [B8 — Protocolli/fonti/dataset reale, moderazione proposte e capacità revisione/esiti non nominati](https://trello.com/c/WeF7e4vx) |
| B9 | [B9 — Pages Free condizionato a visibilità/piano, asset e cronologia privata](https://trello.com/c/RsGdL3Tc) |
| B10 | [B10 — Job, monitoraggio/avvisi, incidenti e disponibilità Free senza responsabili](https://trello.com/c/IGJf15GA) |
| B11 | [B11 — Build/workflow cloud e nuovo candidato non esistenti; test storici non bastano](https://trello.com/c/S1jACVnn) |
| B12 | [B12 — Platea, informative, obiettivi, budget effettivo e GO non approvati](https://trello.com/c/UOURj9DW) |
| COLLAUDO | [COLLAUDO — Registro T01–T20 e verifica target pilot](https://trello.com/c/3nOUswHP) |

## Come aggiornare il taccuino

1. All'inizio della sessione, copiare la scheda più sotto e indicare un obiettivo limitato, per esempio «completare S0».
2. Leggere il passo nella guida e verificare i suoi prerequisiti. Eseguire soltanto le attività consentite dai gate; una dipendenza mancante resta visibile.
3. Durante il lavoro, annotare azione, risultato osservato ed evidenza. Se qualcosa fallisce, conservare il tentativo e aprire un problema; non sostituirlo con il solo esito del retry.
4. Alla fine, aggiornare sequenza, blocchi e collaudi interessati. Chiudere un passo solo con risultato atteso verificato e riferimento alla scheda/evidenza.
5. Aggiornare il punto di ripresa con una sola prossima azione concreta, anche quando il lavoro resta a metà.

**Stati dei passi:** `DA FARE`, `IN CORSO`, `BLOCCATO`, `COMPLETATO`. Le dipendenze future non rendono automaticamente un passo «BLOCCATO»: usare quello stato quando un tentativo o una verifica di prerequisiti ne impedisce la prosecuzione. Un passo completato che perde validità torna `DA FARE` o `BLOCCATO`, con motivo nel diario.

**Esiti delle verifiche:** `NON ESEGUITO`, `PASS`, `FAIL`. Un'esclusione richiede una decisione esplicita con motivazione, approvatore, data e impatto su perimetro e dipendenze; non equivale a PASS. Un nuovo candidato o una diversa configurazione richiedono di rivalutare le prove interessate.

Date e ore delle annotazioni: `AAAA-MM-GG HH:MM Europe/Rome`, indicando l'offset se necessario. Salvare qui solo sintesi condivisibili e riferimenti a evidenze private: niente password, token, OTP, email personali, foto, signed URL o copie dei dati. Anche il nome/percorso di un'evidenza deve evitare dati personali e segreti.

## Sequenza operativa S0–S15

Fonte: **§12.1 della guida**. Le azioni e i risultati sotto riportati sono promemoria; leggere anche errori/recuperi e sezioni di dettaglio della guida prima di eseguire. S5 può procedere in parallelo al lavoro tecnico quando i propri prerequisiti sono soddisfatti; S15 vale anche in caso di incidente.

| Passo e prerequisiti | Azione prevista | Risultato da verificare | Stato | Sessione / evidenza |
|---|---|---|---|---|
| S0 — Accesso repo, nessuna mutazione | git status --short; git rev-parse HEAD; versioni §3; rileggere dossier corretto | Inventario diff/file non tracciati; candidate precedente distinto; titolare assegna ruoli | DA FARE | — |
| S1 — S0 | Titolare: registro §15, piano/quote, partner/dominio, custodi e platea; RP per Pages | Decisioni/risorse documentate; nessuna spesa non deliberata | DA FARE | — |
| S2 — S1 e posti Free | Supabase Dashboard: collaudo, regione, password e API exposure §5 | Healthy, Free, schemi chiusi, Connect/TLS provati | DA FARE | — |
| S3 — S2 + tecnico | P1 minimo Edge/SQL/Auth/immagini; implementazione locale e deploy condizionato §5 | Evidenze concorrenza/CPU/latenza/privato; ADR firmato | DA FARE | — |
| S4 — S3 | Nuove migrazioni/grant/RLS e mapping, manifest; migrate:up/verify condizionati §5 | Ledger/schema coerenti; test upgrade/popolato e accesso diretto negato | DA FARE | — |
| S5 — S1 dominio + S2 | Resend Free → Domains; DNS §7; chiave e SMTP Auth | Verified, sender corretto, consegna a collaudatori esterni | DA FARE | — |
| S6 — S4/S5 | Auth template/expiry/URL/registrazioni/CAPTCHA, adapter Flutter e revoca §6 | OTP reale, refresh, logout, ruoli/MFA e intenti ripresi | DA FARE | — |
| S7 — S4/S6 | Bucket privati/policy, adapter/finalizzatore foto §8 | Upload interrotto ripreso, finalizzazione privata e cleanup; B negato | DA FARE | — |
| S8 — S3/S4/S6/S7 | Portare rimanenti route, transazioni, cron, fonti/calendario e ruoli reali §5 | R01–R21 e R24 coperte; nessun ramo legacy scrivibile senza autorità | DA FARE | — |
| S9 — S4/S6/S7/S8 + custodi | Implementare cancellazione e backup cloud; drill §11 | Copie cifrate separate, diario durevole, restore completo misurato e utenti isolati | DA FARE | — |
| S10 — S6–S9 | Test contratto/policy/backend/Flutter, profilazione §10; freeze nuovo candidato | Suite finali senza skip non dichiarati; manifest/artefatti identificati | DA FARE | — |
| S11 — S10 e gate Pages | Build frontend §9; Settings Pages/Actions, deploy collaudo o anteprima isolata | URL effettivo, base corretta, niente segreti, hash route/reload e cache provati | DA FARE | — |
| S12 — S11 + collaudatori/operatori | Checklist §13 su servizi cloud e browser reali, casi guasto/rollback | Verbale con PASS/FAIL e limiti, tutte righe bloccanti chiuse | DA FARE | — |
| S13 — S12 + decisione titolare | Secondo progetto pilot: ripetere configurazione/nuove migrazioni, dataset reale approvato, segreti separati; nuove URL e build | Confronto configurazione collaudo/pilot, smoke minimo sul vero target prima apertura | DA FARE | — |
| S14 — S13 + GO firmato | Apertura limitata, inviti scaglionati e operatori presenti | Rilevare funnel, review, copertura/secondo controllo e quote; assenza incidenti aperti | DA FARE | — |
| S15 — Raccolta terminata o incidente | Chiudere nuove adesioni, gestire pratiche/ricorsi, conservazione/cancellazione e copie secondo policy | Utenti informati, chiavi non necessarie revocate, nessuna risorsa/dato dimenticato | DA FARE | — |

## Blocchi e decisioni B1–B12

Fonte: **§15 della guida**. I responsabili sono ruoli richiesti, non persone già incaricate. Per chiudere un blocco servono la prova prevista nella guida e il riferimento alla decisione o verifica; scrivere «configurato» non basta.

| ID | Blocco / decisione | Ruolo richiesto | Stato | Persona incaricata / decisione / prova di chiusura |
|---|---|---|---|---|
| B1 | Fattibilità backend Edge/DB/PNG e latenza non provata; blocca architettura eseguibile | Tecnico backend + responsabile infrastruttura | APERTO | Da assegnare; nessuna evidenza |
| B2 | Nessun dominio mittente controllato/verificato accertato; OTP esterno a zero non dimostrato | Titolare + amministratore DNS/partner | APERTO | Da assegnare; nessuna evidenza |
| B3 | Auth/JWT, revoca immediata, MFA e migrazione guest/account ancora custom | Tecnico Auth/client + titolare sicurezza | APERTO | Da assegnare; nessuna evidenza |
| B4 | Porting API/schema/policy e chiusura mutazioni legacy mancanti | Tecnico backend/database | APERTO | Da assegnare; nessuna evidenza |
| B5 | Storage cloud/normalizzazione/finalizzatore e quote foto non verificati | Tecnico backend/client + responsabile dati | APERTO | Da assegnare; nessuna evidenza |
| B6 | Backup coordinato Auth/DB/byte foto, custodia/diario indipendente e restore cloud assenti | Titolare + custode infrastruttura e sostituto | APERTO | Da assegnare; nessuna evidenza |
| B7 | Chiusura account completa assente e policy classi non ratificata | Titolare dati/privacy + tecnico | APERTO | Da assegnare; nessuna evidenza |
| B8 | Protocolli/fonti/dataset reale, moderazione proposte e capacità revisione/esiti non nominati | Responsabile pilot, missioni e responsabile esiti | APERTO | Da assegnare; nessuna evidenza |
| B9 | Pages Free condizionato a visibilità/piano, asset e cronologia privata | Titolare repository | APERTO | Da assegnare; nessuna evidenza |
| B10 | Job, monitoraggio/avvisi, incidenti e disponibilità Free senza responsabili | Operatore infrastruttura + titolare | APERTO | Da assegnare; nessuna evidenza |
| B11 | Build/workflow cloud e nuovo candidato non esistenti; test storici non bastano | Tecnico Flutter/CI + revisore release | APERTO | Da assegnare; nessuna evidenza |
| B12 | Platea, informative, obiettivi, budget effettivo e GO non approvati | Titolare + responsabile pilot/privacy | APERTO | Da assegnare; nessuna evidenza |

### Decisioni del titolare da raccogliere in S1

Tutte **DA RACCOGLIERE**. Registrare le risposte nel registro decisioni, senza inserire credenziali.

- [ ] Account/organizzazioni disponibili, piani effettivi, posti Free e quote residue.
- [ ] Piano e visibilità GitHub, diritti su asset/storia e percorso hosting approvato.
- [ ] Dominio o sottodominio mittente, disponibilità del partner e autorizzazione DNS.
- [ ] Responsabili e sostituti per infrastruttura, missioni, verifica, esiti e privacy; assistenza presidiata.
- [ ] Hardware, spazio, due copie private, custodia delle chiavi e diario cancellazioni indipendente.
- [ ] Eventuali utenti/dati reali preesistenti; scelta guest e strategia di migrazione.
- [ ] Comune, platea/età, finestre, fonti, protocollo e capacità di revisione.
- [ ] Budget effettivo, disponibilità richiesta, retention, tempi di cancellazione e obiettivi RPO/RTO.

| Decisione | Data | Tema / blocco | Scelta e motivazione | Approvatore / riferimento privato | Impatto e verifiche richieste |
|---|---|---|---|---|---|
| — | — | Nessuna decisione registrata | — | — | — |

## Inventario dell'ambiente

Da compilare seguendo **§3.3 della guida**, prima su collaudo e poi sul pilot. Non confondere i due ambienti. Inserire solo identificativi condivisibili; per configurazioni riservate usare un riferimento all'inventario privato.

| Voce | Collaudo | Pilot |
|---|---|---|
| Organizzazione / piano verificato / data controllo quote | Da verificare | Da verificare |
| Progetto / regione / versione PostgreSQL | Da registrare | Da registrare |
| URL frontend / base path / origine CORS | Da registrare | Da registrare |
| URL Edge / prefisso API | Da registrare | Da registrare |
| Dominio mittente / stato verifica DNS e SMTP | Da verificare | Da verificare |
| Candidato completo / commit + modifiche incluse / manifest | Da identificare | Da identificare |
| Schema / migrazioni / versione configurazione | Da identificare | Da identificare |
| Responsabile / sostituto / inventario contatti privato | Da assegnare | Da assegnare |
| Inventario backup / diario / custodia chiavi (riferimenti) | Da registrare | Da registrare |
| Ultimo restore provato / RPO / RTO misurati | Non eseguito | Non eseguito |
| Comune / platea / finestra approvati | Da decidere | Da decidere |

Per ciascun servizio, annotare nel diario la data di verifica di piano, quote assegnate, consumi e soglie di arresto. I valori della guida sono riferimenti documentali da ricontrollare sul proprio account.

## Registro del collaudo T01–T20

Fonte: **§13.1–13.2 della guida**. Leggere il caso completo prima di eseguirlo. La tabella registra due esiti distinti: il collaudo e la verifica pertinente sul target pilot; quest'ultima non sostituisce il collaudo completo. Una cella PASS deve rimandare a candidato, configurazione, data e prova nella scheda sessione. Non occorre duplicare una prova se lo stesso riferimento ne documenta chiaramente entrambi gli ambiti.

| Test | Requisiti / oggetto | Collaudo | Target pilot | Sessione / evidenza / anomalie |
|---|---|---|---|---|
| T01 | R06, R25: OTP reale | NON ESEGUITO | NON ESEGUITO | — |
| T02 | R06/R21: codici e abusi | NON ESEGUITO | NON ESEGUITO | — |
| T03 | R07: persistenza sessione | NON ESEGUITO | NON ESEGUITO | — |
| T04 | R08/R17: guest e intenti | NON ESEGUITO | NON ESEGUITO | — |
| T05 | R01/R02/R03: flussi civici | NON ESEGUITO | NON ESEGUITO | — |
| T06 | R09/R10: missione completa | NON ESEGUITO | NON ESEGUITO | — |
| T07 | R09/R13: concorrenza | NON ESEGUITO | NON ESEGUITO | — |
| T08 | R10/R11/R13/R18/R19: risposta persa e duplicati | NON ESEGUITO | NON ESEGUITO | — |
| T09 | R11/R21: foto private | NON ESEGUITO | NON ESEGUITO | — |
| T10 | R12/R13: verifica umana | NON ESEGUITO | NON ESEGUITO | — |
| T11 | R14/R15: misurazioni | NON ESEGUITO | NON ESEGUITO | — |
| T12 | R04/R05: fantasy | NON ESEGUITO | NON ESEGUITO | — |
| T13 | R16/R17: leghe | NON ESEGUITO | NON ESEGUITO | — |
| T14 | R18/R19/R20: cooperazione e continuità | NON ESEGUITO | NON ESEGUITO | — |
| T15 | R21: accessi diretti | NON ESEGUITO | NON ESEGUITO | — |
| T16 | R24/R25: rete, quota e guasto | NON ESEGUITO | NON ESEGUITO | — |
| T17 | R22: chiusura account | NON ESEGUITO | NON ESEGUITO | — |
| T18 | R23: backup e restore | NON ESEGUITO | NON ESEGUITO | — |
| T19 | R29/R24: upgrade e rollback | NON ESEGUITO | NON ESEGUITO | — |
| T20 | R26/R27: persone e dispositivi | NON ESEGUITO | NON ESEGUITO | — |

La copertura **R01–R30** resta nella matrice §4 della guida. Prima del GO collegare ogni requisito pertinente alle prove o alla decisione di esclusione: la sola conta dei T non dimostra copertura completa. R28 resta condizionale e R30 fuori perimetro secondo la guida.

## Diario delle sessioni

**Nessuna sessione operativa registrata.** Il 16 ottobre 2026 è stato preparato questo taccuino su richiesta del titolare, che dichiara di non avere ancora iniziato. Nessun passo operativo o test cloud è attestato da questa preparazione.

Copiare questa scheda a ogni sessione, assegnando ID progressivi `SES-001`, `SES-002`, ecc. Lasciare intatti i tentativi precedenti; aggiungere una rettifica datata quando necessario.

### SES-NNN — [obiettivo della sessione]

- Inizio / fine (Europe/Rome): da compilare.
- Esecutore / ruolo: da compilare.
- Passo S / blocchi B / requisiti R / test T coinvolti: da compilare.
- Ambiente: locale / collaudo / pilot; URL o riferimento all'inventario: da compilare.
- Candidato completo / schema / configurazione: da compilare; HEAD da solo non basta se ci sono modifiche locali.
- Prerequisiti verificati e relativi riferimenti: da compilare.
- Risultato atteso / criterio di arresto dalla guida: da compilare.

| Ora | Azione o comando (senza segreti) | Risultato osservato / misura / exit code | Esito | Evidenza privata |
|---|---|---|---|---|
| — | — | — | NON ESEGUITO | — |

**Chiusura della sessione**

- Risultato raggiunto e lavoro ancora aperto: da compilare.
- Stato dei passi aggiornato / blocchi risolti o emersi: da compilare.
- Test eseguiti e validità delle prove precedenti: da compilare.
- Risorse esterne create/modificate e stato in cui sono lasciate: da compilare.
- Problemi / decisioni da ottenere (riferimenti): da compilare.
- **Prossima azione concreta:** da compilare, con passo e punto della guida.

## Problemi e tentativi di recupero

Nessun problema emerso dall'esecuzione: non è ancora iniziata. I blocchi già noti sono nel registro B sopra.

| ID | Aperto il / sessione | Passo / sintomo e impatto | Stato / responsabile | Tentativo e risultato / evidenza | Prossima azione / chiusura verificata |
|---|---|---|---|---|---|
| — | — | Nessun problema registrato | — | — | — |

Usare ID `PROB-001`, ecc. Per rollback e recupero seguire **§12.2**, distinguendo frontend, Edge, configurazione, schema e dati; annotare versione precedente, compatibilità e prova dopo il recupero. Un rollback frontend non ripristina il database.

## Verbale di apertura o chiusura

**Non compilato; decisione corrente: NO-GO pilot.** Compilare al gate previsto, seguendo §13.3; registrare separatamente demo, collaudo tecnico, pilot e produzione.

- Data / livello richiesto / ambiente: da compilare.
- Candidato / build / schema / configurazione: da compilare.
- Copertura R/T, esclusioni approvate e riferimenti alle evidenze: da compilare.
- Blocchi ancora aperti e loro impatto: da compilare.
- Quote/capacità misurate, responsabili e sostituti: da compilare.
- Backup/restore, RPO/RTO, assistenza e rollback verificati: da compilare.
- Confronto collaudo/pilot e smoke sul target effettivo: da compilare.
- Rischi residui / chi li accetta / riferimento privato: da compilare.
- Decisione GO o NO-GO / titolare / responsabile pilot / data: da compilare.
- Alla chiusura: pratiche/ricorsi, conservazione/cancellazione, copie e risorse residue secondo S15: da compilare.

**Non aprire il pilot contando solo le caselle completate:** valgono i gate e i NO-GO automatici della guida. La firma e i dati riservati del verbale restano nel luogo privato approvato; qui registrarne soltanto il riferimento.
