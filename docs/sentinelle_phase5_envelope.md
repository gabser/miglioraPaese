# Sentinelle — fase 5: misurazione ed esiti

15 ottobre 2026. **Fase 5 verificata localmente; gate operativo separato.** FG-04/05/06.
Baseline codice `dc5c553293304d1b89419e6deedeed18fb6540749d2d2fa83de3c2f6d940cdac`,
397 file, snapshot `/tmp/sentinelle-baseline-20261013/phase4-workspace.tar.gz`.
HEAD invariato più diff protetto; toolchain e autorizzazioni locali invariate.
Contratto fissato sotto prima di avviare gli autori.

## Decisioni da conservare nel contratto

Problema, baseline, protocollo versionato, intervento, missione, osservazione e
valutazione restano entità distinte. Problema/intervento hanno legami molti-a-molti;
intervento può essere temporaneo, e durata attesa non è beneficio osservato.
Protocollo pubblica prima del lock indicatore/unità/soglia/finestre/istruzioni,
baseline ed evidenze comparabili; vietare aggiornamento tardivo. La risposta del
questionario non diventa automaticamente una misura numerica o un esito.

Responsabile `outcomesSupervisor` per Comune dal database, senza auto-promozione;
pubblicazione motivata e fonti/prove autorizzate. Divieto di autovalidazione e
conflitto con carte/snapshot della giornata. Due risposte concordi non bastano:
valutazione umana di qualità, indipendenza, tempi e confrontabilità. Discordanza
richiede nuova verifica o non determinabilità; mai maggioranza automatica.

`improves|stable|worsens` restano direzioni; `undeterminable` è disposizione
distinta, non un alias di stable. Alla deadline pubblicata, evidenza insufficiente
chiude la carta come undeterminable. Rendere la chiusura deterministica/idempotente
su comando server o lettura autorevole, senza richiedere pubblicazione manuale
di tutte le carte scadute. Esporre copertura: numero di carte valutabili/attese,
unità luogo/finestra validate, e motivo di non determinabilità.

Scoring v2 solo per **nuove stagioni**, mai upgrade delle righe v1 già esistenti.
Snapshot mantiene rulesVersion; v1 e 48 fixture originali rimangono invariati.
Wire v1 resta `fantasy-demo-v1`; wire nuove stagioni v2 sarà `fantasy-v2`.
Outcome v2 usa `disposition: determinate|undeterminable`, con observed direzione
nullable (obbligatoria solo per determinate); mai aggiungere undeterminable alle
tre direzioni CivicTrend né confondere outcome assente con outcome chiuso.
Undeterminable dà zero osservazione/previsione anche con previsione stable e
capitano; penalità trasferimenti e riflessione mantengono regole e arrotondamento.
Evitare lo scoring v1 implicito quando manca observed. Tutti i chiamanti di reveal,
summary, riflessione e ranking devono applicare versione e revisione corretta.

Originale, contestazione, rettifica e motivazione persistiti separatamente, con
attore/tempo/revisione. La rettifica ricalcola in transazione una revisione
consultabile di risultati/classifiche, senza sommare nuovi punti ai vecchi;
replay e riavvio non duplicano. Conservare reflection e transferPenalty già
accettati. Non riscrivere la ricevuta di contribuzione né il ledger XP per cambiare
esito fantasy. Controllare anche squadre non ancora rivelate e finalizzazioni.
L'endpoint amministrativo v1 non deve consentire pubblicazioni v2 che aggirano
prove e ruolo outcomesSupervisor. Usare un'unica transazione per pubblicazione,
storico e ricalcolo: evitare chiamate a service che aprono una seconda transazione
mentre la prima mantiene il lock globale. Gli originali reveal restano consultabili;
ranking/summary applicano revisioni correnti soltanto nelle stagioni v2.

La pubblicazione amministrativa del calendario generale è fase 7. Per verificare
v2 in fase 5 usare nuove stagioni sintetiche create esplicitamente nelle fixture
locali, senza rinnovo demo automatico o modifica dello storico. Interfaccia
misurazioni API e v2 opt-in; funzioni incomplete disattivate.

## Gate da tradurre in casi concreti

Problema presente, assente, intervento temporaneo/ricontrollo; legami multi-problema;
protocollo dopo lock rifiutato; prove discordanti e replica della stessa persona
non scambiata per seconda fonte indipendente; deadline chiude senza evidenze;
conflitto operatore, prove di altro Comune e sessione revocata rifiutati;
contestazione/rettifica risposta persa, CAS, ricalcolo ripetuto e storico invariato;
v1 parità e v2 zero con penalità/riflessione/capitano; ranking e copertura coerenti;
test PostgreSQL reale, Flutter, build pertinenti e nuove UI 390/1024/1440.

Prove sintetiche soltanto. Nessun punteggio competitivo reale né fonte ratificata
inventata; provider, referenti e gate operativo finale restano separati.

## Contratto fissato dall’orchestratore — 15 ottobre 2026


1. Guardie e identità
- `MEASUREMENTS_ENABLED=false`, richiede PostgreSQL+ACCOUNT_ENABLED+MISSIONS_ENABLED+REVIEW_ENABLED+FANTASY_ENABLED; nessun fallback.
- Riusa GET `/v1/review/municipalities/{municipalityId}/capabilities`, ruolo `outcomesSupervisor`; nessun nuovo endpoint ruoli.
- Sotto `B=/v1/measurements/municipalities/{municipalityId}`: bearer account, ruolo Comune, self/competitive-conflict anche su snapshot e alias guest, no-store.
- Comandi JSON con idempotencyKey; creazione senza expectedRevision, mutazioni con expectedRevision positivo; hash scope+body, replay snapshot prima CAS.
- Stesso advisory lock76131001 → sessione → entità/carta; tempo/ruoli/revoca dopo attesa, sessione prima commit. Nessuna pubblicazione tramite X-Admin-Token v1.

2. Letture pubbliche (nessun originale privato)
- GET `/v1/municipalities/{municipalityId}/measurements?seasonId=...&matchdayId=...` → MeasurementOverview.
- GET `/v1/municipalities/{municipalityId}/measurements/evaluations/{evaluationId}` → EvaluationPublished corrente.
- GET `.../evaluations/{evaluationId}/history` → `{items:EvaluationPublished[]}` versioni pubblicate immutabili, ordinate.
- Query seasonId/matchdayId facoltative insieme; default stagione attiva esplicita, risposta sempre scope risolto; storico selezionabile anche dopo nuova stagione.
- MeasurementOverview `{municipalityId,seasonId,matchdayId,serverTime,revision,problems:Problem[],protocols:ProtocolVersion[],interventions:Intervention[],evaluations:EvaluationPublished[],coverage}`.
- coverage `{expectedCards,evaluableCards,closedUndeterminableCards,validatedPlaceWindows,expectedPlaceWindows,reasons:[{code,count}]}`; conteggi per scope, non numero di foto né maggioranza voti.
- Solo problemi/protocolli/interventi esplicitamente pubblicati e riassunti evaluation approvati; nessuna bozza, note sentinella, id account, proofId o URL file.

3. Workspace e risorse operatore
- GET `B/workspace?seasonId=...&matchdayId=...` → `{scope,revision,problems,protocols,interventions,evaluationDrafts,appeals,sources,approvedObservations}` privato.
- sources restituisce solo metadati dei record autorizzati del registro; approvedObservations id/scope/authorId/protocol/date/status per selezionare prove, nessun accesso indiscriminato a originali.
- POST `B/problems` crea e pubblica problema con `{idempotencyKey,title,placeId,baseline:{value,unit,measuredAt,sourceId}}` → Problem.
- POST `B/problems/{problemId}/protocol-versions` crea/pubblica versione prelock con `{idempotencyKey,expectedRevision,...ProtocolDefinition}` → ProtocolVersion.
- POST `B/interventions` crea/pubblica `{idempotencyKey,title,problemIds,status,temporary,expectedDurationDays,sourceId,sourceDate}` → Intervention.
- POST `B/interventions/{interventionId}/updates` → stessi dati + expectedRevision; append storico, mai riscrivere stato passato.
- POST `B/evaluations` crea bozza `{idempotencyKey,protocolId,protocolVersion,afterValue,measuredAt,sourceIds,approvedObservationIds,interventionIds,rationale}` → EvaluationDraft.
- POST `B/evaluations/{evaluationId}/draft-updates` → stesso contenuto + expectedRevision, solo prima pubblicazione → EvaluationDraft.
- GET `B/evaluations/{evaluationId}` → EvaluationWorkspace `{draft,currentPublished,history,appeals,evidence}`; controllo scope/caso/conflict.
- GET `B/evaluations/{evaluationId}/proofs/{uploadId}` → MissionProof fase3; solo prove appartenenti a approvedObservationIds o relativi supplementi congelati del caso e retention valida.
- POST `B/evaluations/{evaluationId}/publications` `{expectedRevision,idempotencyKey,disposition,observed,rationale,undeterminableReason}` → EvaluationPublished.
- POST `B/evaluations/{evaluationId}/corrections` stesso contenuto EvidenceDraft + disposition/observed/rationale/undeterminableReason/appealId nullable e CAS → EvaluationPublished nuova versione.

4. DTO pubblici e corrispondenti privati
- Problem `{id,municipalityId,placeId,title,baseline:{value:number finite,unit:string,measuredAt:UTC,source:SourceSummary},revision,publishedAt}`.
- SourceSummary `{id,label,sourceDate}`: testo sicuro approvato dal registro; nessun flag verified controllabile dal client.
- ProtocolDefinition `{problemId,seasonId,matchdayId,cardId,missionIds,indicator,unit,threshold:number finite>=0,lowerIsBetter:boolean,instructions:string[],observationStartsAt,observationEndsAt,declaredDeadline}`.
- ProtocolVersion aggiunge `{id,version,revision,baselineSnapshot,publishedAt}`. Baseline e place snapshot; scope/missioni compatibili con Comune e area.
- starts<=ends<=declaredDeadline; misure baseline precedenti allo start; osservazioni nell'intervallo; deadline coerente con giornata v2; pubblicazione/versionamento strettamente prima locksAt.
- Una versione vincolata a carta/giornata non cambia dopo lock; FK server per stagione/giornata/carta/protocollo e mission_card_links fase4, nessun link client fidato.
- Intervention `{id,municipalityId,title,problemIds:string[],status:proposed|started|completed|suspended,temporary:boolean,expectedDurationDays:number|null,source:SourceSummary,sourceDate,revision,history}`.
- expectedDurationDays non è observedBenefit. Evaluation espone beneficio descrittivo derivato dal confronto e rationale; completed non implica improves.
- EvidenceDraft `{afterValue:number finite|null,measuredAt:UTC|null,sourceIds:string[],approvedObservationIds:uuid[],interventionIds:string[],rationale:string}`.
- EvaluationDraft `{id,municipalityId,protocolId,protocolVersion,seasonId,matchdayId,cardId,revision,status:draft,...EvidenceDraft}`.
- EvaluationPublished `{id,version,revision,seasonId,matchdayId,cardId,protocolId,protocolVersion,disposition:determinate|undeterminable,observed:improves|stable|worsens|null,baselineValue,afterValue,unit,measuredAt,sources:SourceSummary[],interventionIds,rationale,undeterminableReason:null|string,publishedAt,supersedesVersion:null|integer,origin:human|deadline}`.
- Public DTO contiene solo rationale deliberatamente pubblicabile e fonti sanificate; audit privato conserva attore/tempo/revisione e dettagli integrità, senza email/token.

5. Fiducia nelle fonti e validità del verdetto
- Registro fonti solo CLI/fixture privata sintetica, loopback esplicito; record immutabile `{id,municipalityId,placeId,indicator,unit,value,measuredAt,label,provenance,registeredBy}`.
- sourceIds esistenti/scoped; baseline e misure documentali devono corrispondere ai record persistiti. Payload non accetta sourceStatus/verified/independent.
- Per determinate: fonte documentale autorizzata pertinente OPPURE almeno due account indipendenti con misure quantitative approved, stesso protocollo/place/intervallo. Non imporre documento E due osservazioni. Repliche stesso account non aumentano indipendenza.
- Mai produrre numeri da answer: usare misura quantitativa esplicita del protocollo (estensione descritta sotto) o valore del documento autorizzato.
- Convergenza di risposte da sola insufficiente: supervisor dichiara rationale per qualità, indipendenza, comparabilità e tempi; self/conflict verificati sulla carta e su tutti gli autori citati.
- Evidenze contraddittorie pertinenti richiedono nuova verifica o undeterminable; non selezionare solo le due concordi ignorando le altre disponibili del medesimo scope.
- Solo nonObservable/unsure non autorizzano determinate. osservazioni/versioni/retention scadute non possono attestare una prova oggi accessibile; pubblicazione congela metadati autorizzati e digest.
- Direction proposta umana deve coincidere col confronto numerico protocollo: signedDelta=(after-baseline)*(lowerIsBetter?-1:1); abs(delta)<=threshold→stable, delta>threshold→improves, altrimenti worsens.
- Undeterminable richiede observed=null e motivo enum insufficientEvidence|contradictoryEvidence|incomparableEvidence|missingBaseline|deadlineExpired; non è stable.

6. Deadline, ricorsi, storico e scoring v2
- Su qualsiasi read autorevole public measurements/detail/history e fantasy v2/read/ranking o comando: dentro stessa TX riconcilia tutte le carte scadute dello scope con outcome assente.
- Riconciliazione crea pubblicazione system undeterminable/observed null, reason deadlineExpired, chiave SQL unica stagione/giornata/carta/versione; audit actorId null+actorKind systemDeadline, mai finto operatore.
- Se protocollo assente a deadline, calendario v2 deve avere comunque closeAt persistito per carta, pubblicato prelock in fixture; niente carte senza deadline conoscibile.
- POST `/v1/measurements/municipalities/{municipalityId}/evaluations/{evaluationId}/appeals` bearer account senza ruolo, `{expectedRevision,idempotencyKey,publishedVersion,reason}` → Appeal; lettura autore GET `.../appeals/{appealId}` privata.
- Appeal `{id,evaluationId,publishedVersion,reason,submittedAt,status:open|accepted|rejected,revision}`; un open per account/versione, nessun esito automatico.
- Supervisor POST `B/evaluations/{evaluationId}/appeals/{appealId}/resolutions` `{expectedRevision,idempotencyKey,decision:reject,reason}` chiude motivatamente; accoglimento solo via correzione collegata atomica.
- Correzione di chiusura deadline è una nuova versione umana con evidenze, mai riscrittura; revisioni risultato/ranking nella stessa TX, replay stesso snapshot; XP e receipt invariati.
- Wire nuove stagioni `fantasy-v2`; v1 `fantasy-demo-v1` e fixture48 invariati. Selezione esplicita seasonId richiesta per storico, non teams.seasonFor(mid) implicito.
- GET `/v1/municipalities/{municipalityId}/fantasy/seasons/{seasonId}/matchdays/{matchdayId}/results/history` bearer sessione fantasy guest/account own principal → `{seasonId,matchdayId,original,items:[{resultRevision,evaluationVersions,results,summary,at}],currentRevision}`.
- Nessun playerId nella route: proprietario dalla sessione. Summary/reveal v2 esistenti aggiungono resultRevision/currentRevision; originale v1 rimane intatto, rettifiche v2 appendono nuovi payload.
- v2 undeterminable: observationPoints=predictionPoints=frozenTotal=0, capitano non li crea; reflectionBonus con formula arrotondamento esistente, transferPenalty conservata e applicata una volta.
- Pubblicazione/correzione materializza revisione per tutti snapshot eligible della giornata, inclusi non rivelati/finalizzati; mantiene reflection e penalty, ranking usa corrente; originali consultabili separatamente.

7. Boundary necessarie prima del codice
- `createFantasyResults.freeze/view/reflect/publish` oggi invocano solo scorer v1 e outcomes.observed; introdurre dispatch esplicito per snapshot.rulesVersion, mai fallback observed null→v1.
- `teams.seasonFor` e `store.season/cards/matchday` selezionano stagione per solo Comune: occorre resolver scope esplicito e isolamento v1/v2 prima di nuove stagioni.
- `leagues.read` somma results.read per membro: collegare revisione corrente e seasonId corretti senza TX nuova; correggere tutti player snapshot, non solo richiedente.
- Measurements TX raw pg e fantasy repository AsyncLocalStorage sono oggi distinti: estrarre unit-of-work condivisa/client-bound; non chiamare results.read/teams.reconcile mentre prima TX tiene advisorylock.
- `results.publish` v1 PUT locale deve rifiutare season/day rulesVersion fantasy-v2 anche se token admin e body sembrano validi; solo percorso supervisor/evidenze per v2.
- Migrazioni nuove12+ additive, checksum1–11 immutabili, nessun cambio posizione INSERT sulle tabelle esistenti; fixture v2 privata crea solo nuovi row/id, nessun upgrade seed v1.
- Decisioni di root fissate nel paragrafo seguente; nessun punto lasciato ai due autori come contratto implicito.

## Confini fissati prima del codice

- Ownership: `measurements_backend` services/backend/**; `measurements_flutter`
  lib/** e test Dart; root documenti/contratto. Review sul candidato con mirati PASS.
- Query `seasonId` facoltativa per tutte le API fantasy, letture e comandi; niente
  nuovo campo nei body legacy. Resolver verifica Comune/season. Default: stagione
  attiva al tempo server, altrimenti prossima futura, altrimenti ultima passata.
  Risposte sempre con seasonId. Lega identificata per ID usa la propria stagione;
  hint discordante è rifiutato. Date confrontate come timestamp, non stringhe.
  Client congela lo scope risolto dalla prima risposta e lo passa alle richieste
  successive; cambi manuali Comune/stagione/giornata invalidano una generazione
  monotona, compresi A→B→A. Cache/bozze e intent mutanti includono seasonId/dayId
  dove pertinenti; una conferma mercato pendente resta nella stagione originale.
- `closeAt` di ogni carta/giornata v2 persistito prima lock dalle fixture nuove,
  default observationEndsAt+24h; declaredDeadline protocollo deve corrispondere.
  Carte senza protocollo chiudono comunque. Coverage pubblica conta tutte carte
  del calendario pubblicato; summary personale i propri starter eleggibili.
- Threshold è tolleranza: differenza assoluta <=threshold è stable, >threshold
  segue signedDelta. Threshold0 permette ogni cambiamento non nullo. Documentare
  e testare l'uguaglianza. Numeri finiti assoluti <=1e9, threshold0..1e9;
  stringhe brevi <=128, titoli <=200, rationale/reason <=2000, unit<=64.
  Liste IDs distinte max20, istruzioni1..20 da <=1000 caratteri; body64KiB;
  immagini restano sul trasporto bounded della fase3, mai nei comandi dominio.
  Confronto tolleranza include uguaglianza decimale senza errori di floating point.
- Appeal richiede account ma nessun ruolo; riguarda versione pubblicata, reason
  obbligatorio, uno open/account/versione. Solo supervisore non in conflitto decide;
  propria contestazione non auto-risolta. Reject motivato o correzione atomica con
  appealId. Non pubblicare motivo/identità privata dell'appello come riepilogo.
- Nessun originale privato o ID autore/prova nel pubblico, anche nello storico.
  Workspace/proof solo per supervisor Comune e caso pertinente, con self/conflict
  e retention; audit attore privato. Fonti registrate solo da adapter/CLI sintetico
  locale documentato, nessuna verifica o ratifica reale inventata.
- Per il percorso quantitativo osservazioni, ProtocolDefinition aggiunge
  `measurementDefinition:{minValue,maxValue,integerOnly}` quando missionIds non
  vuoto. Solo missioni compatibili, finestra non iniziata e senza booking possono
  ricevere la nuova versione prelock. Mission.protocol.measurementDefinition
  pubblica binding `protocolId,protocolVersion,indicator,unit,minValue,maxValue,
  integerOnly`; mission.protocol.version resta versione distinta del protocollo
  missione. Conservare storia dei protocolli, senza mutare quelli già accettati.
- Invio osservazione aggiunge opzionalmente `measurement:{value}`. Per protocollo
  quantitativo è richiesto su noIssue/visibleWaste e assente/null su nonObservable/
  unsure, senza trasformarli in zero. Server valida range/unità derivate e data
  server; receipt nuova congela `measurement:{value,unit,indicator,protocolId,
  protocolVersion,recordedAt}`. Legacy senza questo campo mantiene esattamente
  fingerprint/receipt originale (non aggiungere null all'hash vecchio).
- Bozza offline e UI missioni supportano il campo quantitativo solo se richiesto
  dal protocollo: controlli min/max/intero, recovery stesso body e valore readonly
  corretto quando invio incerto. DTO legacy senza misura resta compatibile.
- Evaluation dopo misura osservativa usa almeno due account e valori concordanti
  approvati con binding protocollo corretto, date/luogo/unità comparabili; afterValue
  deve coincidere con tali misure. Doc autorizzato pertinente può bastare da solo.
  Considerare tutte le evidenze pertinenti disponibili: contraddizioni richiedono
  nuova verifica/undeterminable, nessuna selezione di due concordi contro un terzo.
  La concordanza non pubblica nulla: qualità/comparabilità e rationale richiedono
  decisione umana autorizzata, distinta dal numero di account e dai voti.
- Fonte baseline prima dello start. Registro documentale immutabile con valore,
  data/unità/indicatore/place verificati in adapter sintetico; SourceSummary.sourceDate
  corrisponde alla measuredAt persistita. Interventi many-to-many e fonte coerente;
  temporary/expectedDuration non provano beneficio permanente.
- Scoring/revisioni dispatch da rulesVersion, mai fallback v2→v1 anche se console
  disabilitata. Condividere client/UoW per deadline, pubblicazione e ricalcolo;
  nessuna nuova connessione/transaction nested che attenda il lock già posseduto.
  Fixture pool1 verifica il percorso; v1 deve restare indipendente dalle nuove UI.
  Outcome v2 è EvaluationPublished più rulesVersion/publicationId, senza campi
  sourceStatus/sourceLabel legacy inventati. In chiusura senza protocollo,
  protocolId/protocolVersion/baselineValue/unit sono null. Niente observationId,
  proofId o accountId nei SourceSummary pubblici del percorso quantitativo.
- Fixture v2 esplicita crea nuovi season/card/day/deadline/mission ID, senza
  aggiornare stagioni esistenti. Calendario amministrativo generale resta fase7.
  Client `MEASUREMENTS_MODE_ENABLED=false` richiede review/mission/account/fantasy
  API quando abilitato; tutte funzioni incomplete disattivate.

History risultati usa identità server della sessione fantasy anche guest, senza
nuova barriera login; missioni/operatori/appelli restano account verificato. Nuove
tabelle revisioni per user_id partecipano al linking atomico guest→account e ai
conflitti esclusi della fase2; test dopo correzione v2 richiesto, nessun doppio
punteggio e nessun grant account dal vecchio guest token.
