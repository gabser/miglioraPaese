# Contratto invio proposte — pilot V1

Implementazione locale aggiornata il 31 ottobre 2026; nessun deploy remoto verificato.
La nuova UI richiede la capability `proposalSubmission: 1` e il round trip del
luogo. Un vecchio backend che risponde 201 ignorando campi nuovi non è compatibile.

## Dati e compatibilità

Le route usano `/v1/municipalities/{municipalityId}`, con slug canonico e alias
legacy già supportati. Titolo 1–120 e descrizione 1–1000 sono richiesti e contati
su code point Unicode dopo trim (`Array.from` JS / runes Dart). Nessun taglio,
normalizzazione di casing o indirizzo inferito.

`location`:

- `{kind: "specific", label: "Via Milano", civic?: "12/A", reference?: "Vicino al parco"}`.
  Label 1–120, civic ≤20, reference ≤200; facoltativi vuoti/null omessi.
- `specific` accetta anche `coordinates: {latitude, longitude}` senza label.
  Serve almeno nome o coordinate; la coppia è completa, numerica, finita,
  con latitudine −90…90 e longitudine −180…180. Coordinate parziali,
  stringhe, null, proprietà estranee o valori fuori intervallo danno 400.
  Nessun controllo di appartenenza al poligono comunale.
  Il client mostra «Punto sulla mappa» se manca il nome.
- `{kind: "municipality"}` contiene soltanto `kind`.
- Assente/null resta compatibile con client e dati legacy; il DTO restituisce null.
  La nuova UI richiede sempre una scelta esplicita.

Moderazione controlla titolo, descrizione e campi luogo. Numeri nei diversi campi
non si concatenano in un falso telefono; Via 8 Marzo e civico 12/A sono validi.
Link, email, contatti telefonici, controlli e termini abusivi noti danno 422
`content_rejected` con messaggio pubblico, senza ragione interna.

## HTTP

| Operazione | Risposta |
|---|---|
| GET `next-problems?own=true` | 200 `{items, submissionScope, capabilities: {proposalSubmission: 1}}`; solo proposte della sessione, tutti gli stati salvo filtro esplicito. |
| GET `next-problems` | Stesso envelope, pending/approved pubbliche. |
| GET `next-problems/{id}` | 200 DTO sanificato nello stato attuale; rejected soltanto owner. 404 uniforme per ID assente, Comune diverso o non accessibile. |
| POST `next-problems` | 201 oggetto-proposta originario; replay 200 identico. Include municipalityId/location/isMine/submissionScope. |
| GET `next-problem-submissions/{key}` | 200 `{submissionScope, receipt: oggetto-proposta-originario}`; oppure 404 `{error: "submission_not_found", message, submissionScope}`. |
| POST `next-problems/{id}/votes` | 200 DTO sanificato; rejected altrui dà 404. Voti non approvano nel pilot moderato. |
| DELETE `/v1/session` | 200 `{status: "deleted"}`, revoca persistita, erase e cookie scaduto; ripetizione con lo stesso token già revocato resta idempotente. |

Il DTO utente mantiene contenuti, stato, voti, myVote, displayName, date e regola
di promozione pubblica; aggiunge Comune canonico, luogo e isMine. Esclude
submittedByUserId/moderationReason. L’endpoint admin mantiene DTO separato.
La receipt resta immutabile anche dopo moderazione o voto: il dettaglio descrive
lo stato corrente. Titoli uguali sono consentiti, anche nello stesso luogo.

## Identità, scope e precondizione

L’identità autorevole resta il cookie firmato HttpOnly `mp_anon`. userId o scope
client non conferiscono alcuna autorità. `submissionScope` è HMAC-SHA256 con
separazione di dominio dalla firma cookie e non espone l’identificativo autore.
GET con cookie revocato emette nuova sessione/scope; mutazioni con cookie revocato
danno 401 `session_revoked` (DELETE ripetuto escluso).

La nuova UI congela `expectedSubmissionScope` nel tentativo e lo invia a ogni
POST/replay. Il server confronta la precondizione con l’HMAC dell’identità
risolta, prima di replay/commit. Un cookie sostituito tra bootstrap e POST dà
409 `submission_scope_changed`, zero mutazioni/quota. La precondizione non
entra nel digest e non autentica il client; omissione/null è ammessa per rollout legacy.

## Idempotenza e persistenza

`idempotencyKey` della nuova UI è casuale e immutabile, charset
`[A-Za-z0-9_-]{8,128}`. Omissione/null resta legacy senza garanzia di replay.
Indice comando: identità firmata × Comune canonico × key. Digest server SHA-256
della tuple normalizzata `[title, description, category, location]`, incluse entrambe
le coordinate. Cambiare il pin con la stessa key dà conflitto; retry e lookup
conservano il pin originario nella receipt immutabile.

Stessa key/digest restituisce receipt originale prima di quota e moderazione;
contenuto diverso dà 409 `idempotency_conflict`. Due richieste concorrenti dello
stesso comando convergono nello stesso ID; key diverse sono intenti distinti.
Tre nuovi invii accettati per ora mobile per identità × Comune, confine inclusivo;
rejected conta, errori di validazione/moderazione e replay non contano.

Proposta e record `{key,digest,userId,municipalityId,proposalId,acceptedAt,receipt}`
sono salvati nello stesso snapshot. In caso di errore write SQLite, memoria,
contatore e comandi vengono ripristinati. Snapshot app_state schemaVersion 1 e
schema SQL 6 rimangono invariati; nuove collezioni submissionCommands e
revokedSessions sono additive e i vecchi snapshot le interpretano come vuote.
Restore valida forma, associazione proposta/sessione/Comune, digest/key, date,
assenza di identificativi o ragioni interni nella receipt e luogo.

Nessun TTL automatico dei comandi nel pilot V1; reset li elimina. Revoca ed erase
sono nella stessa transazione persistita. Commit proposte è sincrono dalla
verifica della revoca al write: un POST già autenticato fermo su `await readJson`
fallisce se DELETE precede il commit; se POST precede DELETE, la proposta viene
anonimizzata e la receipt cancellata. Revoca sopravvive al riavvio: il token
vecchio non può ricreare dati. Testi civici restano anonimizzati secondo la
politica esistente. Retention e pulizia tombstone per un lancio pubblico restano
una decisione successiva, senza trasformare key scadute in comandi nuovi.

## Errori e recupero

400 `invalid_field` aggiunge `fieldErrors` mappa percorso → codice pubblico
`required`, `invalid`, `too_long`, `invalid_location` (per coordinate non valide; esempio `{"location.label":"required"}`).
413 oltre 64 KiB; 422 moderazione; 429 quota senza countdown inventato.
401 revoca e 409 cambio scope richiedono gestione del contesto di sessione.

Timeout, rete, 5xx o risposta illeggibile restano esito incerto per il client.
Lookup con scope coerente può confermare; 404 non prova l’assenza di un POST in
transito. Retry usa esclusivamente comando/key/scope congelati. Scope cambiato
impedisce retry sicuro; un nuovo intento richiede scelta esplicita dopo aver
riconosciuto l’incertezza del precedente. Nessuna garanzia dopo perdita cookie,
reset o cambio dispositivo.

## Evidenze locali

`services/backend/test/proposal_submission.test.js` verifica HTTP reale loopback,
round trip/replay SQLite dopo riavvio, concorrenza e perdita della sola risposta,
privacy own/detail/vote/lookup, reset con stream body sospeso e revoca dopo
restart, commit prima del reset, fault SQLite via trigger e rollback di memoria/DB
incluso reset fallito, snapshot/client legacy, boundary Unicode e moderazione
luogo, quota/orologio, precondizione cookie cambiato. Gli altri test backend
restano regressioni dell’intero servizio; queste prove non attestano un deploy remoto.


## Rilascio del luogo con coordinate

Distribuire prima il backend con questa estensione additiva e verificarne POST,
replay e lookup con un pin senza label, poi distribuire il frontend guidato.
I client precedenti continuano a inviare il luogo testuale; record e invii
pendenti privi di coordinate restano validi. Non serve una migrazione SQLite:
il campo è contenuto negli snapshot JSON e viene validato anche al ripristino.
La capability `proposalSubmission: 1` continua a verificare la continuità della
sessione, non attesta da sola che il backend supporti le coordinate: il rilascio
frontend richiede il backend aggiornato. Questa attività non pubblica servizi.

Il flusso e la migrazione bozze sono descritti in
[proposal_guided_flow.md](../design/proposal_guided_flow.md).
