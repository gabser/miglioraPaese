# Piano di test dei flussi in app — esecuzione Luna

Preparato il 18 ottobre 2026 sul working tree locale. Stato: **piano da eseguire**.
Non contiene risultati di una nuova esecuzione. Il repository contiene modifiche
locali, anche non tracciate: il solo commit HEAD non identifica l'app da provare.

## Obiettivo e modalità di lavoro

Verificare che una persona riesca a completare i flussi di Fanta Comune, capisca
gli stati mostrati e ritrovi i propri dati dopo navigazione, refresh e interruzioni.
Luna deve eseguire i percorsi nell'interfaccia e raccogliere evidenze. Le suite
automatiche sono prove complementari, da registrare separatamente.

Eseguire in ordine: preparazione → smoke per profilo → percorsi principali →
errori e recupero → responsive/accessibilità → reset → rapporto.
Non modificare codice applicativo per far passare le prove. Eventuali difetti
vanno riprodotti e documentati. Usare solo account, luoghi, testi e file sintetici
nel laboratorio locale previsto dal progetto.

Priorità: **P0** integrità/identità o flusso principale; **P1** recupero e percorsi
secondari; **P2** verifiche accessorie. Completare i casi indipendenti anche se
un altro caso è bloccato.

## 1. Preparazione riproducibile

1. Leggere le istruzioni applicabili e registrare percorso checkout, HEAD,
   branch, elenco delle modifiche tracciate e dei file non tracciati. Includere
   un digest dei contenuti sorgente effettivamente provati, comprese le sorgenti
   non tracciate; escludere dipendenze, build, credenziali e output del test.
2. Verificare `.fvmrc` e usare il relativo SDK: attualmente Flutter **3.47.5**.
   Per il backend occorrono Node **24+**, dipendenze installate e PostgreSQL
   locale di test. Registrare versioni effettive e comandi eseguiti.
3. Verificare la disponibilità di uno strumento per guidare il browser e
   acquisire screenshot. Aprire un tab non equivale a poterlo automatizzare.
   Se manca, registrare il blocco UI e proseguire con le prove automatiche
   disponibili, senza dichiarare percorsi browser eseguiti.
4. Separare dati dei profili A/B/C con profili browser o origin locali diverse.
   Usare una porta frontend stabile durante le prove di persistenza dello
   stesso profilo. Per due dispositivi usare due profili isolati, non due tab
   che condividono lo stesso local storage.
5. Registrare URL e configurazione di avvio, poi aprire `/diagnostics` e
   confrontare flag, sorgenti e identificativo candidato. La diagnostica mostra
   la configurazione: **non verifica la disponibilità del backend**.
6. Salvare evidenze in `docs/testing/runs/<data-ora>-luna/`, con sottocartelle
   per profilo. Non sovrascrivere precedenti esecuzioni. Rimuovere token,
   codici di accesso e URL di invito completi da screenshot/log condivisi.

### Profili da provare

| Profilo | Configurazione | Comune/dati | Copertura |
|---|---|---|---|
| A — demo civica | Default: tutte le funzioni opzionali disattivate, sorgenti mock | Bologna; Pincara come Comune senza dati | Accesso, gioco, tabellone, proposte, profilo, privacy |
| B — fantasy locale | `FANTASY_MODE_ENABLED=true`, `FANTASY_DATA_SOURCE=mock`; altre opzioni default | Catalogo e calendario demo locali | Squadra, giornata, mercato, leghe demo, reset |
| C — laboratorio API | Tutti i flag sotto indicati, backend fixture PostgreSQL isolato | Tuglie; account sintetici distinti | Fantasy server, account, missioni, revisione, misurazioni, inviti, cooperazione |
| D — pilot civico API | `NEXT_PROBLEMS_DATA_SOURCE=api`, `GAME_DATA_SOURCE=api`; fantasy e account disattivati | Bologna; Milano come Comune non supportato dalle API | Gioco/proposte API nella shell civica |

Non omettere D: la shell fantasy di C non espone `/play` e `/leaderboard`.
In A/B le funzionalità disattivate sono da verificare come tali; la loro
assenza non prova il corrispondente flusso API.

Comandi frontend dalla radice; usare terminali separati per i processi persistenti:

```bash
# A
fvm flutter run -d chrome --web-port=8080

# B
fvm flutter run -d chrome --web-port=8081 \
  --dart-define=FANTASY_MODE_ENABLED=true \
  --dart-define=FANTASY_DATA_SOURCE=mock

# D: avviare prima il backend locale in memoria, da services/backend
DATA_STORE=memory npm run dev
```

```bash
# D: frontend dalla radice
fvm flutter run -d chrome --web-port=8083 \
  --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
  --dart-define=GAME_DATA_SOURCE=api \
  --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

Per C riutilizzare `test/support/fantasy_backend_fixture.mjs`. La fixture crea
un database casuale dedicato, applica migrazioni, prepara dati sintetici e stampa
l'URL HTTP con porta dinamica. Richiede `TEST_DATABASE_URL` già configurato verso
un database loopback con nome terminante in `_test` e un ruolo capace di creare
database temporanei. Non inventare credenziali o riutilizzare database operativi.

```bash
# C: dalla radice, in un processo mantenuto aperto con stdin disponibile
node test/support/fantasy_backend_fixture.mjs
```

Impostare `LUNA_API_URL` nel terminale frontend all'URL restituito dalla fixture:

```bash
fvm flutter run -d chrome --web-port=8082 \
  --dart-define=API_BASE_URL="$LUNA_API_URL" \
  --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
  --dart-define=GAME_DATA_SOURCE=api \
  --dart-define=FANTASY_MODE_ENABLED=true \
  --dart-define=FANTASY_DATA_SOURCE=api \
  --dart-define=ACCOUNT_MODE_ENABLED=true \
  --dart-define=MISSIONS_MODE_ENABLED=true \
  --dart-define=REVIEW_MODE_ENABLED=true \
  --dart-define=MEASUREMENTS_MODE_ENABLED=true \
  --dart-define=LEAGUE_CONTINUITY_MODE_ENABLED=true \
  --dart-define=COOPERATION_MODE_ENABLED=true
```

Selezionare Tuglie nell'app. Per provare il Comune bloccato, ripetere soltanto
il caso C02 con `--dart-define=PILOT_MUNICIPALITY_ID=tuglie`.

Controlli fixture tramite righe JSON nello **stdin del processo**, mai via HTTP:

```json
{"action":"clock","value":"2026-10-08T00:00:00Z"}
{"action":"accountCode","value":"luna-a@example.invalid"}
{"action":"clock","value":"2026-10-14T10:00:00Z"}
{"action":"missionCapacity","value":"1"}
{"action":"missionCounts"}
{"action":"measurementSeed","value":{"seasonId":"luna-measurements-v2"}}
{"action":"stop"}
```

Il codice account è privato e serve solo a completare il login sintetico.
Per ruoli usare `reviewRole` con accountId ottenuto dalla sessione di test,
municipalityId `tuglie` e ruolo `moderator`, `verifier` o `outcomesSupervisor`,
come nei test di revisione. Non modificare i ruoli attraverso l'interfaccia.
Per misurazioni usare gli ID e i tempi restituiti da `measurementSeed`, seguendo
`measurement_postgres_test.dart`; non supporre che il seed v1 includa i dati v2.

La fixture parte dall'8 ottobre 2026; la prima finestra missioni si prova il
14 ottobre alle 10:00 UTC. Terminare le prove fantasy precedenti al lock prima
di avanzare il clock. Se serve tornare indietro, creare una nuova fixture:
il rollback dell'orologio non deve riaprire snapshot già chiusi.
Il calendario fisso del seed può risultare scaduto alla data reale di esecuzione:
registrarlo e usare il clock della fixture per le prove temporali. In B usare i
test con clock iniettato per i rami non raggiungibili dal calendario corrente.

## 2. Casi da eseguire

Ogni ID è un caso da registrare separatamente. Una variante non eseguita rimane
esplicitamente aperta. Nelle tabelle, eseguire i passi nell'ordine indicato.

### Accesso, Comune e navigazione

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| N01 / P0 / A | Storage pulito → aprire app → ingresso diretto → refresh | Welcome con ingresso/tutorial/profilo; accesso alla Home senza tutorial o Comune obbligatori; nessun crash al reload. Registrare la destinazione effettiva al riavvio. |
| N02 / P1 / A | Tutorial → avanti → indietro → salta; nuova sessione pulita → completarlo | Step coerenti, uscita funzionante e preferenza salvata; nessuna navigazione bloccata. |
| N03 / P0 / A,D | Scegliere Bologna → aprire profilo → Cambia Comune → selezionare altro Comune → tornare alle sezioni | Comune e dati coerenti nelle pagine; nessuna risposta tardiva del vecchio Comune mostrata nel nuovo. In D scegliere anche Castel Bolognese. |
| N04 / P1 / A | Scegliere Pincara → Home → Gioca → classifica → Proponi il primo tema | Stato senza dati e CTA utili; nessun progresso/punteggio/carta inventati; proposta associata a Pincara. |
| N05 / P0 / A,D | Senza Comune aprire `/suggest-problem` → Scegli il Comune → Bologna | Ritorno al form della proposta col Comune corretto; parametri di contesto conservati. |
| N06 / P1 / A,B,C,D | Usare tutte le tab, poi indietro/avanti browser, deep link e refresh di un dettaglio valido | Percorsi recuperabili senza loop, shell corretta e nessuna schermata vuota. In B/C verificare Squadra, Giornata, Mercato, Leghe, Profilo. |
| N07 / P1 / A | Aprire `/account`, `/missions`, `/review`, `/measurements`, `/league-invite`, `/cooperation`, `/inbox`, `/followed-places` | Funzioni disattivate: redirect a `/profile`, senza accesso a servizi mancanti. Gli ID necessari si ricavano dalle route reali. |

### Gioco civico e profilo

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| G01 / P0 / A,D | Bologna → Gioca il turno → scegliere Migliora su una carta → tentare Stabile sulla stessa → confidence e motivazione → uscire/rientrare → refresh | Progressione aumenta una sola volta; previsione già salvata immutabile; metadati modificabili secondo capability e ripristinati dopo ricarica. In API verificare anche il dato riletto dal server. |
| G02 / P1 / A,D | Giocare le altre carte disponibili → tabellone → dettaglio risultati/insight → profilo → classifica | Conteggi concordi sulle stesse risorse; distinguere attesa, previsione ed esito; nessun risultato personale assegnato senza esito disponibile. Non fissare il numero di carte a quello delle fixture widget. |
| G03 / P1 / A | Profilo → cambiare lente/punto di vista → navigare → refresh → Come funziona e Privacy | Preferenza conservata; identità e Comune stabili; informazioni accessibili e ritorno funzionante. |
| G04 / P0 / D | Salvare una previsione → interrompere rete → provare un'altra azione → ripristinare → ricaricare | Errore leggibile, nessun falso salvataggio o fallback mock; stato finale uguale al dato server, senza duplicazioni. |

### Proposte, voto, bozza e ricevuta

Usare titoli identificabili, ad esempio `LUNA <run-id> — illuminazione percorso
sintetico`, descrizione fittizia e categoria selezionata. Per i limiti dei campi
ricavare i valori dalla validazione corrente, poi provare limite e limite+1.

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| P01 / P0 / A,D | Lista → ricerca esistente/inesistente → filtro stato → combinazione → azzera | Lista coerente, stato vuoto distinto da errore, filtri azzerabili; digitazione rapida conserva l'ultima ricerca. |
| P02 / P1 / A,D | Form vuoto → invio; solo spazi; campi ai limiti e oltre; categoria assente | Errori locali comprensibili; invio non valido non produce proposte o ricevute; focus e scroll permettono correzione. |
| P03 / P0 / A,D | Compilare → alternare Luogo specifico e intero Comune → riepilogo → modifica luogo → annulla → conferma | Nessuna mutazione prima della conferma; luogo specifico accetta etichetta senza civico; proposta comunale non eredita riferimenti nascosti del luogo; una sola ricevuta dopo invio valido. |
| P04 / P0 / A,D | Compilare metà form → cambiare pagina → tornare → refresh; cambiare Comune e poi tornare al primo | Bozza recuperata nel proprio contesto; nessuna bozza di altro Comune/ambiente/identità; nessun invio automatico. |
| P05 / P0 / A,D | Inviare → ricevuta → dettaglio → lista/Ultimo invio → refresh; aprire lo stesso link con Comune diverso, ID inesistente e identità estranea | Ricevuta originale stabile e distinta dallo stato corrente; dettaglio coerente col contesto e con la visibilità prevista; assenze/accessi negati controllati senza esposizione di dati privati. |
| P06 / P1 / A,D | Inserire testo simile a proposta esistente → leggere suggerimenti → aprire candidato → riprendere bozza; cambiare rapidamente testo | Somiglianze dell'ultima ricerca; accesso al candidato non perde la bozza; eventuale duplicato server comunicato con azione utile. |
| P07 / P0 / A,D | Votare a favore → ripetere click → cambiare voto → ricaricare → cambiare Comune | Un solo voto per identità/proposta, contatori coerenti; nessun doppio conteggio o voto applicato alla nuova lista da risposta tardiva. Verificare la policy di cambio voto effettiva. |
| P08 / P0 / D | Interrompere rete prima dell'invio; separatamente perdere la risposta dopo commit → retry → refresh | Bozza preservata; esito incerto distinto da rifiuto; recupero della stessa mutazione con stessa chiave e nessun duplicato. Per la perdita dopo commit usare la suite di fault injection indicata sotto se il browser non consente il controllo. |
| P09 / P1 / D | Aprire form con verifica capability indisponibile → compilare bozza → ripristinare backend → Riprova la verifica; scegliere Milano | Capability gate impedisce invio prematuro senza perdere testo; Comune non supportato produce errore controllato, senza dati di Bologna o mock. |
| P10 / P0 / D | URL proposta con Comune esplicito diverso dalla preferenza; valore Comune invalido; caratteri speciali; cambiare contesto durante richiesta | URL valido governa il contesto; valore esplicito invalido non ricade sulla preferenza; parametri codificati correttamente e risposte obsolete ignorate. |

### Fantasy: squadra, giornata, mercato e leghe

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| F01 / P0 / B,C | Welcome → Crea la tua rosa → esplorare squadra → modificare titolari/panchina/capitano → confermare → refresh | Rosa di 8 carte, 5 titolari, almeno 2 per ruolo nella rosa e un titolare per ruolo; capitano titolare e budget valido; stato confermato recuperabile. C: nessuna iscrizione silenziosa causata dalla sola lettura. |
| F02 / P0 / B,C | Giornata → previsioni e motivazione → aprire dialog prima del lock → confermare oltre lock; riprendere tab dopo lock | Controlli diventano in sola lettura; conferma tardiva rifiutata; snapshot conservato anche dopo restart. Provare lock−1ms/lock/lock+1ms con clock dei test, separando l'evidenza dalla UI reale. |
| F03 / P0 / B,C | Mercato → preventivo → annulla → nuovo preventivo → conferma; completare terzo e quarto trasferimento; ripetere con budget/ruoli non validi | Annulla non spende; costo e penalità espliciti; oltre i trasferimenti gratuiti applicare la regola corrente (4 punti per trasferimento extra nel modello v1); operazioni invalide non mutano rosa o saldo. |
| F04 / P0 / C | Due dispositivi sullo stesso account modificano stessa squadra; risposta persa su trasferimento; ripetere dopo riavvio | Conflitto di revisione recuperabile; stessa operazione non genera doppia spesa; nessun fallback locale. Eseguire race e perdita dopo commit nelle suite PostgreSQL. |
| F05 / P1 / B,C | Aprire risultati prima e dopo pubblicazione sintetica → consultare fonte/punteggio → inviare riflessione → ripetere e refresh | Pending/provisional/final distinguibili; punteggio solo per snapshot eleggibile; capitano/arrotondamento coerenti con regole versionate; bonus riflessione una sola volta. B e C hanno dati distinti. |
| F06 / P0 / C | Creare lega → ripetere conferma/retry → invitare B/C → adesione → classifica; provare limite leghe, invito scaduto/revocato | Creazione/adesione senza duplicati; massimo 3 secondo contratto v1; classifica con minimo 3 competitori e pari merito 1/1/3 nella fixture dedicata; adesione tardiva mostra ruolo spettatore. |
| F07 / P0 / C | Aprire link invito da browser pulito → riepilogo → login → riprendere → conferma esplicita; ruotare/revocare invito | Aprire link non iscrive; intento sopravvive al login; invito non valido non consente adesione e non espone informazioni private. |
| F08 / P1 / C | Owner avvia trasferimento → destinatario accetta; variante owner esce senza trasferimento completato | Proprietario cambia solo dopo accettazione; altrimenti uscita archivia secondo policy; nessun owner inesistente o doppio. |

### Account e dispositivi

Predisporre A=`luna-a@example.invalid`, B=`luna-b@example.invalid`, e operatori
distinti. Conservare due profili browser separati per lo stesso account A.

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| A01 / P0 / C | Profilo → Account e dispositivi → email non sintetica; poi A → codice errato → valido; provare riuso, scadenza e reinvio | Validazione chiara; login solo con codice valido; vecchio codice invalidato dal reinvio; limiti rispettati e nessun codice nei log condivisi. Usare clock fixture per scadenza. |
| A02 / P0 / C | Account A su dispositivo 1 → login A su 2 → verificare squadra/leghe → revocare 2 da 1 → azione privata su 2 → logout | Stesso stato account recuperato, dispositivo revocato perde accesso; logout non lascia dati account visibili al guest. |
| A03 / P0 / C | Guest con squadra → login account vuoto → collegamento; ripetere con account già dotato di squadra → rinviare → scegliere esplicitamente account | Trasferimento server una volta, nessun import demo; conflitto non distruttivo finché non viene scelta la risoluzione; retry non duplica membership/XP. |
| A04 / P0 / C | Aprire missione/invito da guest → login → riprendere; poi alternare A/B durante caricamenti | Ritorno al flusso previsto con conferma ancora richiesta; nessuna risposta, bozza, ricevuta o squadra privata di A mostrata a B. |

### Missioni, prove e revisione

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| M01 / P1 / C | Guest → missioni → filtro zona → dettaglio → tentativo prenotazione | Catalogo pubblico; area, protocollo, durata, finestra, prove richieste e 10 XP dopo validazione; prenotazione richiede account verificato. |
| M02 / P0 / C | Impostare finestra attiva/capacità 1 → A e B prenotano → reload vincitore → rinuncia → altro account prenota; variante scadenza | Un solo ultimo slot assegnato; retry recupera prenotazione; rinuncia/scadenza liberano capacità senza punti/penalità; tempi server. |
| M03 / P0 / C | Questionario: nessuna criticità, criticità visibile, non osservabile, non so; note → offline → reload/ripresa | Opzioni distinguibili; bozza locale recuperabile nel corretto account/Comune/prenotazione; nessun invio automatico o slot assegnato dalla bozza. |
| M04 / P0 / C | Caricare PNG sintetico valido → interrompere/riprendere upload; provare tipo errato, contenuto invalido, oltre 2 MiB, quarta prova, permesso fotocamera negato | Massimo 3 prove private; upload riprendibile senza duplicati, file invalidi rifiutati e bozza conservata; autore estraneo non legge le prove. La simulazione di permessi va marcata come tale. |
| M05 / P0 / C | Invio → riepilogo → annulla → conferma → doppio click; perdita risposta dopo commit → ripresa → ricevuta | Invio solo dopo conferma; una osservazione/ricevuta immutabile `pendingReview`, XP iniziali 0; requisiti fotografici rispettati per le risposte che li richiedono. |
| R01 / P0 / C | Moderatore prende caso → inoltra con motivo → verificatore prende → chiede integrazione → autore risponde → decisione motivata | Stati/assegnazioni coerenti, motivazione richiesta e audit; lettura dettagli/prove solo ai soggetti autorizzati; ricevuta originale distinta dallo stato aggiornato. |
| R02 / P0 / C | Autore tenta propria revisione; utente senza ruolo apre dettaglio; operatore coinvolto competitivamente prova decisione; due operatori decidono insieme | Operazioni vietate respinte anche via ID diretto; conflitto concorrente controllato; nessuna modifica di esito o XP. |
| R03 / P0 / C | Approvare contributo valido → XP → reload/retry; contributo nessuna criticità; replica richiesta e non richiesta | 10 XP una volta dopo validazione anche senza criticità; unità persona/luogo/finestra non duplicata salvo replica ammessa; nessun esito fantasy derivato automaticamente dalla sola osservazione. |

### Misurazioni, cooperazione e ritorno

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| V01 / P1 / C | Preparare seed v2 → `/measurements` → dettaglio valutazione → fonti/protocollo/interventi | Baseline, indicatore, soglia, finestra e versione visibili; interventi distinti dagli esiti, senza attribuzione automatica di beneficio. |
| V02 / P0 / C | Supervisore pubblica esito con motivazione; variante prove insufficienti a deadline; tentare modifica protocollo oltre lock | Presente/assente/temporaneo distinti; non determinabile distinto da stabile; nessun punto osservazione/previsione per esito v2 non determinabile; protocollo chiuso non modificabile. |
| V03 / P0 / C | Autore contesta → operatore rettifica → ricalcolo → replay e refresh storico | Originale e ragioni conservati, nuova versione consultabile; recupero pubblicazione incerta senza duplicazione; bonus/penalità coerenti con regole della stagione, storico v1 preservato. |
| C01 / P0 / C | Obiettivo Comune/lega → invio missione → revisione positiva → seconda osservazione equivalente/replica | Copertura cresce solo con contributo validato e una volta per luogo/finestra; separata da XP/fantasy; denominatore zero mostra indisponibilità, non percentuale inventata. |
| C02 / P1 / C | Cambiare Comune/stagione/giornata → aprire lega estranea; ripetere variante pilot Tuglie fissato → `/change-municipality` | Scope coerente, lega estranea non leggibile; col pilot fisso cambio Comune disabilitato e route ricondotta al profilo. |
| C03 / P1 / C | Seguire luogo → evento sintetico → inbox → aprire target → segna letto → altro dispositivo → smettere di seguire → nuovo evento | Follow esplicito, messaggi del solo account, nessun doppio evento; letto condiviso; unfollow ferma nuovi avvisi da follow e conserva storico; integrazione/ricontrollo porta al contributo corretto. Nessun canale esterno attivato. |

### Responsive, accessibilità, errori e reset

| ID / priorità / profilo | Passi | Risultato atteso |
|---|---|---|
| X01 / P1 / A,B,C,D | Percorsi principali a 390×844 e 1440×900; pagine critiche a 320, 720, 899, 900, 1024 px; testo 200%; form con tastiera aperta | CTA, campi e dialog raggiungibili con scroll, nessun overflow o sovrapposizione della shell. 400% a 320 px come stress aggiuntivo. Separare zoom browser da text scaling Flutter. |
| X02 / P1 / A,B,C | Navigazione con Tab/Shift+Tab, Enter/Spazio, Escape nei dialog dismissibili; lettore schermo dove disponibile | Focus visibile e ordine coerente, etichette comprensibili, errori annunciati, nessun blocco tastiera; controlli in italiano. Non dichiarare screen reader verificato se non usato. |
| X03 / P0 / C,D | Rete lenta → navigare/cambiare identità → errore/offline → Riprova; URL di dettaglio assente o contesto invalido | Caricamento finito o errore azionabile; nessun crash, falso successo o dati fuori contesto; API indisponibile non attiva mock. |
| X04 / P0 / A,B | Creare bozza/previsione/squadra → Privacy → reset → riaprire app e tutte le sezioni | Stato locale e memoria ripuliti, percorso iniziale coerente; nessuna ricomparsa della vecchia squadra o bozza. Eseguire alla fine. |
| X05 / P0 / C,D | Reset con backend indisponibile → riprova online → cancellazione account da UI se prevista; verificare anche sessione locale irrecuperabile | Errore remoto non viene presentato come cancellazione riuscita; cancellazione locale alternativa richiede scelta esplicita e spiega il limite; dopo successo dati privati rimossi secondo contratto, pubblicazioni e dati degli altri preservati. Distinguere reset dispositivo, revoca sessione e cancellazione account. |

## 3. Prove automatiche di supporto

Eseguire una volta per candidato, mantenendo separati exit code, conteggi,
eventuali skip e prerequisiti mancanti. Non riportare come attuali i conteggi
storici dei dossier. Le suite PostgreSQL richiedono la configurazione descritta
sopra: un errore di avvio del DB è un blocco ambiente, non un PASS.

```bash
# Dalla radice: analisi e suite completa (comprende i test PostgreSQL)
fvm flutter analyze --no-fatal-infos --no-fatal-warnings
fvm flutter test
```

Se PostgreSQL manca, eseguire almeno il sottoinsieme UI senza DB e lasciare
esplicitamente aperta la suite completa:

```bash
fvm flutter test test/app_smoke_test.dart test/welcome_flow_test.dart \
  test/ui_routes_test.dart test/features/home/presentation \
  test/features/game/presentation test/features/next_problems/presentation \
  test/features/fantasy/presentation test/features/missions/mission_widget_test.dart \
  test/features/review/review_widget_test.dart \
  test/features/measurements/measurement_widget_test.dart \
  test/features/cooperation/cooperation_widget_test.dart
```

Backend, da `services/backend`:

```bash
npm test
```

Per prove dopo commit con risposta persa, race o confini temporali usare in
particolare le suite esistenti seguenti. Non sostituire una prova UI mancante
con un PASS di repository: aggiungere l'evidenza come **automatica**.

| Area | Riferimenti locali |
|---|---|
| Rotte/viewport | `test/ui_routes_test.dart`, `test/welcome_flow_test.dart` |
| Bozze, URL, ricevute e idempotenza | `test/features/next_problems/presentation/proposal_*_flow_test.dart`, `test/features/next_problems/data/api_proposal_recovery_test.dart` |
| Lock/mercato/risultati | `test/features/fantasy/logic/fantasy_manager_test.dart`, `test/features/fantasy/data/fantasy_repository_test.dart`, `test/features/fantasy/presentation/fantasy_flow_test.dart` |
| Account/identità | `test/features/account/account_postgres_test.dart`, `test/features/fantasy/data/fantasy_session_reset_test.dart` |
| Missioni/prove | `test/features/missions/mission_postgres_test.dart`, `test/features/missions/mission_widget_test.dart` |
| Ruoli/XP | `test/features/review/review_postgres_test.dart`, `test/features/review/review_widget_test.dart` |
| Esiti/rettifiche | `test/features/measurements/measurement_postgres_test.dart`, `test/features/measurements/measurement_widget_test.dart` |
| Inviti/proprietà | `test/features/fantasy/continuity/continuity_postgres_test.dart`, `test/features/fantasy/continuity/continuity_widget_test.dart` |
| Cooperazione/inbox | `test/features/cooperation/cooperation_postgres_test.dart`, `test/features/cooperation/cooperation_widget_test.dart` |
| Diagnostica | `test/app/diagnostics_test.dart` |

Al termine dello smoke, compilare anche `fvm flutter build web --release` per
il profilo A e ripetere N01, G01, P03 e X04 sulla build servita localmente;
registrare l'effettiva origin. Le altre build release, se eseguite, richiedono
gli stessi `--dart-define` del rispettivo profilo. Nessuna pubblicazione è parte
del piano. Non usare formattazione automatica sull'intero working tree.

## 4. Evidenze e rapporto richiesto

Per ciascun ID e variante registrare:

```text
ID e variante:
Profilo / candidato / URL / clock fixture:
Tipo prova: UI browser | widget | repository/integration | backend
Browser, viewport e scala testo:
Prerequisiti e dati sintetici:
Passi realmente eseguiti:
Risultato atteso:
Risultato osservato:
Esito: PASS | FAIL | BLOCKED | NOT RUN | N/A
Evidenza: screenshot/log/test e posizione nel file
Difetto o causa blocco:
```

PASS richiede tutti gli assert del caso/variante effettivamente osservati.
BLOCKED significa prerequisito mancante, con causa e passo necessario per
sbloccarlo; NOT RUN indica una prova non tentata. N/A richiede una motivazione
di configurazione, non sostituisce un blocco. Una suite superata copre solo ciò
che asserisce: non implica che l'intero corrispondente percorso UI sia PASS.

Per ogni difetto: titolo, gravità, ID caso, prerequisiti, riproduzione minima,
atteso/osservato, frequenza, evidenze e file sospetti solo se supportati dalla
lettura del codice. Non correggere durante questa campagna.

Il rapporto finale deve includere:

1. Candidato e profili effettivamente testati, strumenti e limiti.
2. Totali per esito delle varianti pianificate, risultati automatici separati.
3. Difetti ordinati per gravità: identità/dati/doppie mutazioni prima dei difetti
   cosmetici; distinguere problema applicativo da ambiente non preparato.
4. Percorsi principali completati e relativo screenshot finale.
5. Elenco esplicito di BLOCKED/NOT RUN e prossimo passo concreto per ciascuno.
6. Valutazione **pronto per ulteriore collaudo locale** soltanto se tutte le
   varianti P0 richieste sono PASS, non ci sono P1 funzionali aperti e la UI è
   stata realmente provata almeno a 390 e 1440 px. Altrimenti: **collaudo locale
   incompleto** oppure **difetti bloccanti**, con motivazione.

Questa valutazione riguarda il laboratorio. Non sostituisce i gate operativi
già documentati nel progetto.

## Fonti e precedenza

Mappa ricavata da `lib/app/router.dart`, `lib/core/config/app_config.dart`,
`lib/app/app_dependencies.dart`, `lib/core/models/municipality_catalog.dart`,
dalle pagine e dai test delle feature. Prerequisiti e invarianti derivano anche
da `services/backend/README.md` e `docs/sentinelle_acceptance_matrix.md`.
L'introduzione del README principale descrive uno stato più ristretto rispetto
al codice corrente: non usarla da sola per escludere funzionalità.
Se piano, contratto e comportamento divergono, registrare la divergenza con
file/riga ed evidenza; non cambiare gli assert per ottenere un PASS.
