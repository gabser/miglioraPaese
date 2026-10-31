# Sentinelle — preparazione fase 4: revisione e XP

14 ottobre 2026: preparazione. **Fase 4 verificata localmente il 15 ottobre 2026**, dopo fase 3
verificata nel registro. Requisiti FG-03, FG-07. Baseline codice
`dad28925382b8edeb6052bd284e0ab20ed2ab4d509da86b0f20a64b15857632e`, snapshot
`/tmp/sentinelle-baseline-20261013/phase3-workspace.tar.gz`. HEAD invariato più
diff locale preservato. Node24/Flutter3.44.2/PostgreSQL17.10; soli test sintetici.

## Risultato e responsabilità

Console locale per operatori assegnati al Comune: coda, assegnazione,
richiesta di integrazione, controllo delle prove private, approvazione o rifiuto
motivato, audit consultabile. La sentinella vede lo stato corrente e gli XP;
la ricevuta originale di accettazione della fase 3 resta immutabile.
Backend/contratto: `review_xp_backend`, unico autore `services/backend/**`.
Flutter/test: `review_xp_flutter`, unico autore `lib/**` e test Dart.
Review indipendente: da attivare sul candidato pronto, sola lettura. Orchestratore: documenti,
checkpoint, decisioni di contratto e verifica dei risultati.

## Vincoli

Identità account e ruolo dal server: sentinella, moderatore, verificatore,
responsabile esiti sono distinti. Assegnazioni locali sintetiche tramite adapter
o comando amministrativo esplicito, senza endpoint pubblico di auto-promozione.
Ruoli per Comune, revocabili; login operatore non equivale a autenticazione forte
operativa. Funzione disattivata per default e richiede account/missioni locali.
Moderazione verifica pertinenza/contenuti; validazione della qualità richiede
verificatore. Responsabile esiti non può trasformare una revisione in esito
competitivo: pubblicazione e regole v2 sono lavoro della fase 5.

PendingReview richiede assegnazione a moderatore; forward produce screened e
libera assegnazione, poi verificatore si assegna e decide. Un account non autore
può avere entrambi i grant: responsabilità/permessi e audit restano distinti;
il piano non richiede due persone diverse per le due fasi. Eventuale separazione
nominativa operativa è da definire nel gate pilot, senza simulare referenti.
Nessuna assegnazione a sé o validazione del proprio contributo; decisioni
competitive vietate sulle carte in cui l'operatore compete. Controllo ownership,
ruolo, Comune, revisioni e stato nella stessa transazione della decisione.
Assegnazione concorrente e decisione obsoleta generano conflitto esplicito.
Motivazioni obbligatorie, audit con attore/tempo/revisione e nessun token/email.

Integrazione: richiesta esplicita, scadenza e revisione; la risposta dell'autore
è aggiunta separata all'originale, recuperabile/idempotente e con prove private
sanitizzate. Una richiesta di replica è server-owned e identifica lo specifico
luogo/finestra; nessun flag del client può aumentare gli XP.

Ledger XP transazionale: **10 XP** dopo validazione, anche per “nessuna criticità”,
una volta per contributo e massimo uno per account/luogo/finestra salvo replica
richiesta. Vincoli SQL devono coprire il caso base (NULL non basta per una UNIQUE
multicolonna). Replay e riavvio non duplicano accrediti; rifiuto non accredita.
XP, affidabilità e punti fantasy restano separati, senza bonus né promozione
automatica ai ruoli. Lo stato corrente non modifica la ricevuta originale XP0.

## Contratto fissato dall'orchestratore il 15 ottobre prima delle deleghe

Risorse `/v1` per operator capabilities, coda/dettaglio privato, assegnazione,
integrazioni, decisioni/audit, stato personale e ledger. Comandi con
expectedRevision e chiave idempotente; risposta persa recupera lo stesso
risultato. Prove accessibili ad autore e soli operatori autorizzati al caso;
nessun URL diretto pubblico. OpenAPI, backend, DTO/repository e client aggiornati
insieme. Nessun fallback a mock.

Percorsi operatore sotto `/v1/review/municipalities/{municipalityId}`:

- `GET /capabilities`: `{roles: string[], synthetic: true}`; ruoli effettivi dal
  database, mai da header/body. Sentinella senza ruolo riceve elenco vuoto.
- `GET /observations?status=...`: `{items: ObservationLive[]}`; stati ammessi
  `pendingReview|screened|needsIntegration|approved|rejected`.
- `GET /observations/{id}`: `ObservationLive` con audit e prove pertinenti.
- `POST /observations/{id}/assignment`: `{expectedRevision,idempotencyKey}`,
  assegnazione all'account operatore corrente, CAS, vietata sul proprio contributo.
- `POST .../screening`: stesso comando più `decision: forward|reject, reason`;
  moderatore assegnato, screening non assegna XP.
- `POST .../integration-requests`: stesso comando più `message`; verificatore
  assegnato, deadline server esplicita, una richiesta aperta per osservazione.
- `POST .../decisions`: stesso comando più `decision: approve|reject, reason`;
  verificatore assegnato, audit e ledger nella stessa transazione.
- `GET .../proofs/{uploadId}`: proof JSON fase 3, solo se pertinente a un caso
  autorizzato nel Comune; stesso no-store/retention, nessun percorso pubblico.
- `POST .../replication-requests`: stesso comando più `reason`; verificatore
  assegnato crea richiesta server per autore/luogo/finestra/protocollo/deadline.

Percorsi autore: `GET /v1/observations/{id}` restituisce stato corrente privato;
`GET /v1/me/xp` restituisce `{balance: integer, items: XpEvent[]}`.
`POST /v1/observations/{id}/uploads` richiede `integrationRequestId` oltre ai
campi upload della fase 3; chunks/status/complete riusano il trasporto esistente,
con autorizzazione richiesta attiva anche dopo scadenza del booking originale.
`POST /v1/observations/{id}/supplements` riceve
`{expectedRevision,idempotencyKey,integrationRequestId,notes,proofIds}`.
La risposta è `ObservationLive`; aggiunge supplemento/audit senza alterare
osservazione e ricevuta originale. `GET /v1/replication-requests/{id}` mostra
scope e deadline all'autore; `POST .../bookings` con idempotencyKey accetta una
richiesta ancora valida creando booking distinto, senza saltare capacità o
controlli temporali. L'eccezione XP proviene solo da questa relazione persistita.

`ObservationLive` contiene id/bookingId/municipalityId/missionId/placeId/windowId,
protocolVersion intero, answer, notes, submittedAt UTC, status, revision intera
positiva, assignedTo nullable (ID opaco), xpAwarded intero 0 o 10, proofs metadata,
integrationRequest nullable, supplements e audit. Niente email o credenziali.
IntegrationRequest contiene id/message/requestedAt/dueAt/status/revision;
Supplement id/notes/proofs/submittedAt; Audit id/action/actorId/reason/at/revision;
XpEvent id/observationId/placeId/windowId/amount10/awardedAt/ruleVersion1 e
replicationRequestId nullable. PlaceId è identificatore server di area delimitata,
non stringa del client. Review non definisce automaticamente affidabilità/esiti.

Tutti i comandi ritornano il risultato originale se stessa chiave/body; body
diverso con stessa chiave è `idempotency_conflict`409. Risultati consultabili
tramite replay e stato/audit; revision conflict409 non cambia nulla. Errori
stabili: account_required/session_expired401, review_forbidden/self_review/
competitive_conflict403, observation_not_found/proof_not_found404,
review_revision_conflict/integration_closed/replication_closed409.
Concorrenza, tempo e revoca controllati dopo lock; ruoli assegnati solo da comando
locale sintetico documentato. Flag `REVIEW_ENABLED` server e
`REVIEW_MODE_ENABLED` client false per default, dipendenti da missioni/account.

Dettagli fissati all'avvio degli autori: ruoli wire `moderator`, `verifier`,
`outcomesSupervisor` (ultimo riservato alla fase 5). Integrazione con deadline
server di 24 ore dalla richiesta; replica non oltre fine finestra. DTO replica:
id/authorId/missionId/municipalityId/placeId/windowId/protocolVersion/dueAt/status.
L'autore continua a leggere i propri upload/proof tramite `/v1/uploads/{id}` e
`/v1/proofs/{id}`, anche per integrazioni; queste letture richiedono ownership e
retention, mentre create/chunk/complete richiedono richiesta attiva. Nessun nuovo
endpoint autore duplicato per la lettura delle prove.

Contratto verificato contro le risorse della fase 3. Ogni variazione necessaria si registra
qui prima di cambiare i chiamanti. La review indipendente parte sul candidato
pronto, secondo il metodo aggiornato; le responsabilità nominali sopra indicano
aree di ownership, non collaboratori da tenere permanentemente attivi.

Dettagli di persistenza vincolanti: nuova migrazione additiva, nessuna modifica
alle nove già applicate; usare liste esplicite di colonne negli INSERT esistenti
se si estendono booking/upload/observation. Le repliche richieste hanno scope
persistito distinto: il vincolo del booking base resta valido e non deve bloccare
la replica autorizzata. Il luogo è identità server comune anche a missioni diverse
sulla stessa area. Collegamenti carte/missioni server-owned permettono il controllo
di conflitto su squadre/snapshot della giornata pertinente, mai un flag client.
Grant/revoche ruoli locali usano lo stesso ordine di lock della revisione/sessione.
Nessuna promozione o ruolo derivato dagli XP. Nessuna pubblicazione esito in fase4.
Per missioni diverse sulla stessa area, `windowId` resta quello originale nel DTO;
il ledger usa `window_scope` server immutabile da startsAt/endsAt UTC, comune agli
intervalli equivalenti. Vincolo base account/place/window_scope, senza aggiungere
protocolVersion come modo di moltiplicare XP. Place è mapping persistito comune;
default deterministico Comune/area sintetica solo all'inserimento, non ricalcolato
quando cambia una label. Test cross-missione con ID finestra distinti obbligatorio.
Booking aggiunge `replicationRequestId` nullable; `GET .../missions/{id}/booking`
resta riferito alla prenotazione base, mentre GET booking per ID distingue la
replica. La route client può selezionare `?bookingId=<UUID>` validato anche nella
whitelist di ritorno login, ma lo scope deriva sempre dal booking autenticato.
Bozza base conserva sette componenti fase 3; solo la replica aggiunge l'ID richiesta
server come ottavo componente. Non riusare/sovrascrivere la bozza base. Ricevute
nuove di replica includono replicationRequestId, senza alterare ricevute storiche.
GET richiesta replica aggiunge `bookingId` nullable derivato dal booking owned:
una replica già prenotata può essere recuperata su un altro dispositivo senza
conoscere la chiave del primo comando. La UI apre questo booking senza occupare
un secondo slot. Intent durabili di revisione scoped all'account ID verificato,
non al submissionScope del singolo token, per riprenderli dopo un nuovo login.
Rifiuto 403 al primo tentativo con chiave nuova non prova un invio incerto: può
liberare l'intent e consentire correzione dopo refresh. Un 403 sul replay dopo
risposta ambigua conserva invece chiave/body (autorizzazione può precedere la
lookup del risultato). Timeout/401 e risposta malformata restano conservativi;
rifiuti definitivi CAS/integrazione chiusa liberano soltanto il body obsoleto,
conservando note/foto, e richiedono nuova revisione prima di un nuovo comando.

## Gate locale

- Due operatori sull'ultima assegnazione: uno solo vince; revoca o cambio ruolo
  durante attesa lock impedisce accesso/decisione.
- Autore, operatore di altro Comune e ruolo insufficiente sono rifiutati;
  operatore competitivo non decide una propria carta.
- Approva/replay/riavvio accreditano 10 una volta; validazione successiva nello
  stesso luogo/finestra non duplica; replica richiesta resta distinta.
- Integrazione scaduta/obsoleta e prove di altro autore non alterano originale;
  richiesta e risposta perse sono recuperabili.
- Receipt fase 3 identica prima/dopo revisione; stato corrente e ledger
  restituiscono la nuova decisione senza riscrivere lo storico.
- Suite PostgreSQL e Flutter, build profili interessati, UI tastiera e
  390/1024/1440. Dati/file sintetici soltanto; nessuna raccolta reale.

Nessun push, merge, deploy, provider o email reale. Il gate operativo finale,
compresa autenticazione forte/ruoli nominativi/privacy, resta aperto.
