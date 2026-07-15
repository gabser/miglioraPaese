# ADR-0002: identita' anonime, sessioni e autorizzazione

- Stato: `accepted`.
- Data: 13 luglio 2026.
- Accettato dal decision owner: 14 luglio 2026.
- Work package: `UC-00.5`.
- Decision owner: proprietario del prodotto/repository.
- Esecuzione: non avviata; richiede un comando separato del proprietario.

## Contesto

Il pilot deve riconoscere un utente senza account nominativo, derivare sempre
l'ownership lato server e rendere persistenti voti, previsioni, risultati e
sole preferenze civiche necessarie. Preferenze puramente UI, come motion,
onboarding e stato temporaneo delle schermate, restano locali. Oggi Flutter
genera un identificativo locale, lo conserva in
`SharedPreferences` e lo invia in query o body: il client puo' quindi scegliere
l'identita' e il backend non puo' garantire isolamento, revoca o cancellazione.

La definizione di prodotto richiede inoltre di ritrovare una previsione dopo
riavvio, nuovo deploy e logout. Questi eventi non sono equivalenti:

- il riavvio dell'app o del backend non deve terminare una sessione valida;
- il logout deve revocare la sessione, non cancellare l'identita';
- dopo un logout reale, un'identita' anonima senza email, telefono o provider
  puo' essere recuperata soltanto mediante una credenziale segreta separata;
- la cancellazione dell'identita' e' un'operazione distinta e irreversibile.

L'identificativo stabile e' pseudonimo, non anonimo in senso privacy. Dati,
retention, export, cancellazione e backup restano quindi nel perimetro della
policy privacy del pilot.

## Decisione

Adottare:

1. principal anonimi emessi dal server, senza dati identificativi obbligatori;
2. access token e refresh token opachi, casuali, revocabili e privi di claim;
3. un set anonimo di otto recovery code indipendenti e monouso, mostrato una
   sola volta, per recuperare l'identita' dopo logout o reinstallazione;
4. ruoli server-side distinti `anonymous`, `moderator` e `admin`;
5. identita' operatore separate dalle identita' civiche anonime;
6. autorizzazione deny-by-default basata su ruolo, scope territoriale,
   ownership e stato della risorsa;
7. cookie sicuri per Flutter web e secure storage di piattaforma per i client
   native;
8. autenticazione forte degli operatori dietro una porta provider-neutral,
   rinviando la scelta del provider a una decisione separata.

Questa decisione non autorizza dipendenze, provider di identita', account,
segreti o risorse cloud. Le durate indicate sono default accettati e devono
restare configurabili entro limiti validati; cambiarne sostanzialmente il
modello richiede un emendamento dell'ADR.

## Modello di identita'

### Principal anonimo

Il backend crea un UUID non derivabile dal device, dall'orario, dall'IP o da
input del client. Il principal contiene almeno stato, data di creazione e
versione della policy accettata; non contiene nome, email o telefono.

Ogni richiesta autenticata risolve il principal dalla sessione. `userId`,
`authorId`, ruolo e scope ricevuti dal client non sono mai autorevoli. Nel
contratto pilot vengono rimossi o rifiutati; un'eventuale finestra di
compatibilita' e' limitata allo sviluppo locale, esplicita e non attivabile in
staging o produzione.

Il cutover degli input `userId` autoritativi e' una release coordinata prima di
qualsiasi staging o pilot: OpenAPI, backend, adapter Flutter e test Node, Dart e
browser appartengono allo stesso change plan. L'artefatto combinato applica la
modifica in un solo rollout. Se un futuro hosting separa frontend e backend, il
cutover usa tre fasi compatibili: il server prima accetta ma ignora il campo
legacy e deriva sempre il principal dalla sessione; poi Flutter smette di
inviarlo; infine OpenAPI e server lo rifiutano. Non esiste mai una fase in cui
`userId` del client torna autorevole e il pilot apre soltanto dopo la rimozione
finale. `GameRepository.currentUserId` viene derivato da `GET /v1/me` oppure
rimosso nello stesso change plan. I campi identificativi nelle risposte
pubbliche richiedono invece mapper e decisione privacy espliciti. Il mock locale
puo' mantenere ID sintetici.

### Identita' operatore

Moderator e admin usano record operatore distinti e non sono promozioni di un
principal anonimo. Un operatore che partecipa al gioco usa una seconda
identita' civica anonima. Ruoli e scope comunali sono risolti dal database a
ogni richiesta sensibile; non sono incorporati nei token.

## Credenziali e persistenza server

### Token opachi

- Access e refresh token sono generati con CSPRNG, 32 byte casuali e codifica
  Base64URL, con prefisso di tipo/versione ma senza dati utente.
- Il database conserva soltanto un verifier HMAC-SHA-256 e il relativo key id,
  mai il bearer token raw.
- Il confronto del verifier evita differenze temporali osservabili.
- Token, cookie, recovery code e header di autorizzazione non entrano in
  URL, log, analytics, errori o trace.
- TLS e' obbligatorio fuori dal loopback locale.

Le entita' minime sono:

```text
anonymous_principals
operator_identities
role_assignments
session_families
session_tokens
recovery_sets
recovery_credentials
```

Una famiglia lega principal, scadenza assoluta e stato di revoca. Ogni token
registra tipo, verifier, creazione, scadenza, ultimo uso, consumo, revoca e
riferimento al record/verifier sostitutivo, mai il token raw. Ogni recovery set
ha stato `pending|active|expired|revoked`;
ciascuno dei suoi otto codici ha verifier, scadenza e stato di consumo. Nessun
valore raw e' recuperabile.

### Durate accettate per il pilot

| Credenziale/sessione | Idle | Assoluta | Note |
| --- | ---: | ---: | --- |
| Access anonimo | Non applicabile | 15 minuti | Rinnovato solo tramite refresh valido |
| Refresh anonimo | 30 giorni | 90 giorni | Ruotato a ogni uso |
| Recovery set anonimo | Non applicabile | 180 giorni | Otto codici monouso; rotazione in due fasi |
| Sessione moderator | 30 minuti | 12 ore | Access token massimo 10 minuti |
| Sessione admin | 15 minuti | 8 ore | Access token massimo 5 minuti |
| Step-up moderator | Non applicabile | 10 minuti | Solo azioni dichiarate sensibili |
| Step-up admin | Non applicabile | 5 minuti | Ruoli, revoche globali, export e recovery |

Per rendere azionabili le scadenze, `GET /v1/me` espone la scadenza assoluta
della famiglia, la scadenza del recovery set e il numero di codici residui,
mai i codici stessi. Con 14 giorni o meno alla scadenza dei 90 giorni, Flutter
propone il rinnovo esplicito della famiglia mediante un recovery code valido;
con 30 giorni o meno alla scadenza dei 180 giorni, propone la rigenerazione
`prepare`/`confirm` del set. Gli avvisi restano visibili fino all'azione o alla
scadenza. Il refresh ordinario non estende silenziosamente le scadenze
assolute. Boundary, warning, rinnovo e stato scaduto usano un clock
controllabile nei test.

Il rinnovo mostrato dalla UI usa `POST /v1/sessions/recover`, valido anche
quando esiste una sessione attiva: consuma un recovery code, revoca tutte le
famiglie precedenti e crea una nuova famiglia con scadenza assoluta di 90
giorni. Non esiste un'estensione silenziosa della famiglia corrente.

Scadenza idle e assoluta sono applicate dal server. IP e User-Agent non sono
binding rigidi: cambiano sulle reti mobili e aumentano i dati personali
trattati. Possono diventare segnali temporanei anti-abuso soltanto con retention
esplicita in `UC-08`.

### Rotazione, replay e concorrenza

Il refresh token ruota in una transazione: il token precedente viene marcato
consumato, il sostitutivo viene creato e soltanto allora e' emessa la risposta.
Il server non puo' ricostruire o riemettere il sostitutivo, perche' ne conserva
soltanto il verifier. Qualunque secondo uso di un refresh gia' consumato
restituisce `401 refresh_reused` e revoca l'intera famiglia: non esiste una
finestra temporale che presume legittima una race indistinguibile da un replay.

I client native serializzano il refresh nel processo. Flutter web deve
serializzarlo anche tra tab della stessa origin con un lock cross-tab e
propagare l'esito alle altre tab. I test browser verificano il meccanismo e il
fallback fail-closed. Se la risposta che contiene il sostitutivo viene persa,
la famiglia non e' recuperabile mediante il vecchio refresh: l'utente usa uno
dei recovery code residui. Questa scelta privilegia revoca e replay detection
rispetto a una riemissione non dimostrabile in sicurezza.

Logout corrente revoca la famiglia corrente ed e' idempotente. Logout globale,
sospensione, cambio ruolo, compromissione e cancellazione revocano tutte le
famiglie interessate. Gli endpoint logout cancellano sempre i cookie e
restituiscono `204` anche per credenziale assente, scaduta o gia' revocata;
soltanto una prima richiesta autenticata puo' eseguire la revoca globale. Una
sessione revocata non viene riattivata.

## Recovery dopo logout

Alla creazione del principal viene preparato un set di otto codici casuali e
indipendenti. Ogni codice ha almeno 128 bit di entropia, e' mostrato una sola
volta con istruzioni per conservarlo fuori dall'app e viene salvato dal server
soltanto come verifier. La UI deve distinguere:

- `Riavvia`: usa il refresh token gia' conservato;
- `Esci`: revoca la sessione e avverte se l'utente non ha dichiarato nella UI
  di avere salvato il set;
- `Recupera identita'`: consuma un solo codice, revoca le vecchie sessioni ed
  emette una nuova famiglia; gli altri codici del set restano validi;
- `Rigenera codici`: crea e conferma un nuovo set con protocollo in due fasi;
- `Azzera preferenze locali`: non e' logout e non cancella dati server;
- `Cancella identita'`: revoca sessioni e tutti i recovery set e avvia il
  purge.

Le risposte recover non rivelano se un'identita' esiste e applicano rate limit.
Non esiste recupero manuale basato su IP, fingerprint, contenuti inviati o
domande di sicurezza. Se tutti i codici vengono persi o consumati dopo logout o
reinstallazione, l'identita' non e' recuperabile.

La dichiarazione di salvataggio e' soltanto un acknowledgement UX, non una
prova server-side. La rotazione del set evita di invalidare l'unico recupero se
una risposta si perde:

1. `prepare` richiede sessione attiva e, se esiste gia' un set attivo, un suo
   codice non consumato; crea un set `pending`, restituisce otto nuovi codici e
   non modifica il set attivo;
2. `confirm` richiede sessione attiva, rotation id e uno dei nuovi codici;
   soltanto allora attiva il nuovo set e revoca il precedente;
3. un set pending non confermato scade rapidamente e il vecchio resta valido;
4. durante il solo bootstrap iniziale, se il principal non ha mai avuto un set
   attivo e la famiglia iniziale ha meno di 15 minuti, `prepare` puo' essere
   ripetuto con la sessione appena creata;
5. tutte le risposte che mostrano codici usano `Cache-Control: no-store`.

I codici presentati a `prepare` e `confirm` sono prove di possesso legate alla
sessione e al rotation id, ma non vengono consumati. `Monouso` significa che un
codice puo' autorizzare al massimo un `recover`; tentativi o conferme di
rotazione non riducono il conteggio. Dopo `confirm` il nuovo set parte con otto
codici non consumati e il set precedente viene interamente revocato. Tutti i
tentativi restano rate-limited e non enumeranti.

L'eccezione bootstrap non torna disponibile dopo scadenza o revoca. Se un
principal ha gia' avuto un set attivo, ogni nuovo `prepare` richiede un codice
valido di quel set ancora attivo. Dopo la scadenza dei 180 giorni non si puo'
rigenerare il set con la sola sessione: la sessione corrente resta utilizzabile
fino alla propria scadenza, ma il recupero futuro dell'identita' non puo' piu'
essere ripristinato. La UI avvisa prima della scadenza e offre export,
cancellazione o creazione consapevole di una nuova identita'; il server non
trasferisce automaticamente ownership o dati tra principal.

Una recovery riuscita consuma un solo codice e non ruota automaticamente il
set. Se la risposta con la nuova sessione si perde, un codice residuo permette
di ripetere il recupero. La UI mostra il numero residuo e richiede rigenerazione
prima dell'ultimo codice.

La promessa verificabile usata in prodotto, onboarding, UI e assistenza e':
"Dopo logout o reinstallazione puoi recuperare l'identita' soltanto con un
recovery code ancora valido, non consumato e non scaduto". Non viene promesso
un recupero manuale o garantito. Se il proprietario rifiuta questo meccanismo,
il requisito deve limitarsi al recupero dopo riavvio o deploy e non puo'
includere il logout reale.

## Trasporto e storage client

### Flutter web

Access e refresh token sono inviati soltanto come cookie host-only:

```text
__Host-mp_access=<opaque>; Max-Age=900; Secure; HttpOnly; SameSite=Lax; Path=/
__Host-mp_refresh=<opaque>; Max-Age=<min(30 giorni, residuo assoluto)>;
  Secure; HttpOnly; SameSite=Lax; Path=/
```

Il server rinnova `Max-Age` soltanto dopo un refresh riuscito. Logout e revoca
inviano entrambi i cookie con gli stessi attributi e `Max-Age=0`.

Non sono salvati in `SharedPreferences`, `localStorage` o `sessionStorage` e
non sono leggibili da Dart/JavaScript. Frontend e API devono essere same-site;
l'ADR hosting deve assicurare domini compatibili. Se sono origin distinti,
Flutter abilita le richieste credentialed e il backend usa una allowlist CORS
esatta, mai `*`.

La protezione CSRF dipende dalla classe di endpoint:

| Classe | Credenziale accettata | Controlli web obbligatori |
| --- | --- | --- |
| API ordinaria in lettura | Solo access cookie | Origin consentita quando presente; nessuna mutazione in `GET` |
| API ordinaria mutante | Solo access cookie | Origin esatta, Fetch Metadata e `X-MP-CSRF` legato alla sessione |
| Create, refresh, recover | Nessuna, solo refresh, solo recovery code | Origin esatta, Fetch Metadata, JSON + header `X-MP-Client` che forza preflight, rate limit; niente CSRF session-bound |
| Prepare/confirm recovery set | Access cookie + codice richiesto dalla fase | Controlli mutazione completi e doppia prova |
| Native | Bearer del tipo previsto dalla route | Cookie rifiutati; CSRF non applicabile |

Il token CSRF e' restituito da `GET /v1/me`, ruota con la famiglia, resta in
memoria ed e' distinto dai bearer. La policy CORS usa origin esatte,
`Access-Control-Allow-Credentials: true`, metodi inclusivo di `DELETE` e soli
header `Authorization`, `Content-Type`, `X-MP-CSRF`, `X-MP-Client` e
correlation id; `Idempotency-Key` e' consentito solo sulle operazioni che lo
definiscono. `SameSite` e cookie `HttpOnly` non sostituiscono questi controlli.

Access cookie autentica soltanto API ordinarie; refresh cookie soltanto
`/v1/sessions/refresh`; recovery code soltanto recover e gestione recovery set.
Un tipo diverso non e' un fallback. La coppia access/refresh della stessa
famiglia puo' essere presente nel browser, ma ogni route legge un solo slot.
Qualunque header `Authorization` insieme a cookie di sessione produce
`400 ambiguous_credentials`, anche quando risolverebbe lo stesso principal.

Lo sviluppo browser integrato usa un proxy HTTPS same-origin su un unico
hostname loopback e verifica gli stessi cookie. Un profilo non sicuro con nomi
cookie distinti e' ammesso soltanto con ambiente `local`, bind loopback e test
esplicito; non puo' essere avviato in staging/pilot e non soddisfa il gate web.
La configurazione README oggi mista `localhost`/`127.0.0.1` va allineata in
`UC-03`.

### Flutter native

- L'access token resta soltanto in memoria.
- Il refresh token e' conservato in Keychain su Apple o cifrato con una chiave
  protetta da Android Keystore.
- Token e chiavi sono esclusi da backup, migrazioni device e log diagnostici.
- Nelle route ordinarie `Authorization: Bearer` contiene soltanto l'access
  token. Su `/v1/sessions/refresh` contiene invece soltanto il refresh token e
  nessun access token viene inviato.
- Logout tenta prima la revoca idempotente e rimuove comunque le credenziali
  locali. In errore di rete la UI distingue "sessione rimossa dal dispositivo"
  da "revoca server confermata"; non conserva un token utilizzabile soltanto
  per mostrare un falso successo.

I recovery code non vengono inviati automaticamente e non sostituiscono il
secure storage: sono segreti di recupero che l'utente conserva fuori dall'app.
Il repository corrente pubblica Flutter web; secure storage e relativi test
diventano gate soltanto quando viene abilitato un target native.

## Contratto HTTP iniziale

| Metodo e path | Esito | Responsabilita' |
| --- | ---: | --- |
| `POST /v1/sessions/anonymous` | `201` | Crea principal e famiglia; abilita bootstrap recovery |
| `GET /v1/me` | `200` | Restituisce stato, capability, scadenze, numero di recovery code residui e token CSRF; mai bearer, refresh token o recovery code |
| `POST /v1/sessions/refresh` | `200` | Ruota refresh e access in modo atomico |
| `POST /v1/sessions/recover` | `200` | Con o senza sessione attiva, consuma un recovery code, revoca le famiglie precedenti e crea una nuova famiglia |
| `POST /v1/recovery-sets/prepare` | `201` | Crea set pending senza revocare quello attivo |
| `POST /v1/recovery-sets/{rotationId}/confirm` | `204` | Attiva set pending e revoca quello precedente |
| `DELETE /v1/sessions/current` | `204` | Logout della famiglia corrente |
| `DELETE /v1/sessions` | `204` | Logout globale del principal corrente |
| `GET /v1/me/export` | `200` | Esporta i dati riferibili al principal |
| `DELETE /v1/me` | `202` | Revoca immediata e avvia purge idempotente |

Sul web create/refresh/recover impostano cookie e non restituiscono bearer nel
body. Su native create e refresh restituiscono access e refresh nel body
protetto da TLS; recover accetta un solo recovery code nel body, revoca le
famiglie precedenti e restituisce la nuova famiglia. Prepare restituisce il set
pending soltanto nel body. Tutte le risposte che contengono segreti usano
`Cache-Control: no-store` e tutti questi campi sono esclusi dal logging.

Error code minimi e stabili:

| HTTP | `error` | Semantica |
| ---: | --- | --- |
| `400` | `invalid_request` | Payload o shape non validi |
| `400` | `ambiguous_credentials` | Piu' meccanismi di credenziale presentati |
| `401` | `missing_session` | Credenziale assente |
| `401` | `invalid_session` | Token ignoto; non enumera identita' cancellate |
| `401` | `session_expired` | Timeout idle o assoluto |
| `401` | `session_revoked` | Logout, rotazione o revoca |
| `401` | `refresh_reused` | Refresh consumato; famiglia revocata |
| `401` | `invalid_recovery_code` | Codice errato, scaduto o usato |
| `403` | `csrf_failed` | Controllo web fallito |
| `403` | `role_forbidden` | Ruolo o scope insufficienti |
| `403` | `identity_suspended` | Principal non abilitato a scrivere |
| `409` | `deletion_in_progress` | Cancellazione gia' avviata |
| `429` | `recovery_rate_limited` | Limite recovery; include `Retry-After` |
| `503` | `session_store_unavailable` | Validazione non disponibile; fail closed |

## Ruoli e autorizzazione

Ogni decisione applica:

```text
identity.active
AND session.active
AND role permits action
AND actor scope contains resource scope
AND ownership passes, quando richiesta
AND resource state permits transition
AND step-up is fresh, quando richiesta
```

Una condizione mancante nega l'azione. Sessione invalida produce `401`,
permesso insufficiente `403`, risorsa fuori scope puo' produrre `404` per non
rivelarne l'esistenza e transizione incompatibile produce `409`.

| Capacita' | `anonymous` | `moderator` | `admin` |
| --- | :---: | :---: | :---: |
| Leggere dati civici pubblici | Si | Si | Si |
| Gestire sessione e dati propri | Si | Si | Si |
| Proporre, votare e prevedere | Si | No | No |
| Leggere/decidere coda di moderazione | No | Nel proprio scope | No |
| Override moderazione | No | No | Con step-up e audit |
| Gestire problemi, turni ed esiti | No | No | Nel proprio scope |
| Invitare/sospendere moderator | No | No | Con step-up e audit |
| Gestire admin | No | No | Dual-control e step-up |
| Revoca globale emergenza | No | No | Step-up e audit immediato |
| Leggere audit | No | No | Accesso tracciato |
| Modificare audit o leggere token | No | No | No |

Admin non e' automaticamente un superset di moderator: la decisione ordinaria
su una proposta appartiene al moderator; l'admin interviene soltanto tramite
override motivato e auditato.

## Transizioni di stato

### Principal anonimo

```text
active -> suspended -> active
active|suspended -> deletion_pending -> deleted
```

`suspended` mantiene le sole letture pubbliche e revoca le sessioni;
`deletion_pending` impedisce nuove sessioni; `deleted` e' terminale.

### Identita' operatore

```text
invited -> active -> suspended -> active
invited -> invitation_expired
active|suspended -> disabled
```

L'attivazione richiede autenticazione forte. Dopo la chiusura del bootstrap,
una modifica pianificata non puo' ridurre gli admin attivi sotto due. Una
sospensione emergenziale per compromissione puo' farlo, ma attiva subito
`operator_quorum_lost`. Cambio ruolo o scope revoca le sessioni.

### Sessione

```text
active -> rotated|expired|logged_out|revoked
```

Gli stati finali non tornano attivi; una nuova autenticazione crea una nuova
famiglia.

### Moderazione

```text
pending -> approved|rejected|withdrawn
approved|rejected -> pending  # solo override admin prima del turno
```

Approvazione e voto non inseriscono automaticamente una proposta in un turno.
Ogni decisione ha actor, scope, reason, timestamp e versione attesa. Dopo
l'inclusione in un turno si crea un nuovo evento di correzione, non si riscrive
la decisione storica.

### Turno

```text
draft -> open -> calculating -> closed
draft -> cancelled
calculating -> failed -> calculating
```

Solo `draft` e' modificabile strutturalmente; solo `open` accetta previsioni;
`calculating` blocca nuove scritture; chiusura richiede esiti e ledger
coerenti; `closed` e' terminale. Gli enum aggiuntivi sono backlog `UC-05` e
non vengono introdotti da questo ADR.

## Bootstrap e autenticazione operatori

- Nessun admin o secret di default entra in migration, seed o repository.
- Il primo admin nasce `invited` mediante un comando CLI one-shot eseguito
  nell'ambiente di deploy con accesso DB, mai tramite endpoint pubblico.
- La procedura usa transazione e lock e funziona solo se non esiste gia' un
  admin attivo o invitato.
- Dopo l'attivazione del primo admin, un secondo comando one-shot puo' invitare
  esclusivamente il secondo admin quando esiste esattamente un solo admin
  attivo, nessun altro admin attivo/invitato e il bootstrap non e' chiuso. La
  sua esecuzione richiede due custodi nominati, motivo e audit operativo; il
  secondo admin si attiva comunque tramite l'autenticatore AAL2.
- Quando due admin sono attivi, il backend registra
  `admin_bootstrap_closed_at`; entrambi i comandi bootstrap rifiutano per
  sempre nuove esecuzioni. Se l'invito del secondo scade prima
  dell'attivazione, il comando puo' riemetterlo soltanto nello stesso stato,
  con nuova doppia custodia e audit.
- L'attivazione passa da una porta `OperatorAuthenticator` con MFA almeno
  equivalente ad AAL2; il provider concreto resta fuori da questo ADR.
- Una prova valida del provider crea comunque una sessione opaca locale. Ruolo,
  scope, refresh, step-up e revoca restano autorevoli nel backend; il token del
  provider non autorizza direttamente endpoint applicativi.
- Prima del pilot sono richiesti due admin verificati.
- Recovery del quorum admin dopo la chiusura del bootstrap e' una procedura
  break-glass offline distinta, a doppia custodia e auditata, non un bypass
  applicativo.

Promozioni, revoche e cambi scope richiedono stato atteso, motivo, nuova
sessione e audit append-only. Il workflow dual-control e' accettato; la scelta
del provider concreto dell'autenticatore resta un gate proprietario separato
prima del pilot.

Il dual-control copre invito, attivazione, cambio ruolo/scope e disabilitazione
di un admin. Una richiesta lega payload e versione attesa e transita
`pending -> approved -> executed`, oppure
`pending -> expired|cancelled`; scade dopo 30 minuti. Richiedente e approvatore
sono due admin attivi distinti, entrambi con step-up fresco; l'auto-approvazione
e' vietata e l'esecuzione e' singola, transazionale e auditata. La revoca
globale emergenziale di sessioni resta invece immediata con un solo admin,
step-up e audit, per non ritardare il contenimento. Prima che esistano due admin
attivi, il bootstrap usa i comandi one-shot a doppia custodia definiti sopra;
dopo la chiusura, la perdita di quorum usa la procedura separata seguente.

Dopo `admin_bootstrap_closed_at`, se gli admin attivi scendono sotto due, il
backend entra in `operator_quorum_lost`: blocca deploy, nuove abilitazioni,
azioni admin e tutte le scritture civiche non necessarie alla cancellazione;
restano disponibili letture pubbliche e richieste di cancellazione gia'
protette dal journal. Il quorum viene ripristinato soltanto da un comando
offline separato che:

1. funziona esclusivamente con bootstrap chiuso e meno di due admin attivi;
2. richiede due custodi nominati, incident id, motivo e lock transazionale;
3. crea una sola invitation per una persona distinta senza modificare o
   riattivare direttamente gli admin esistenti;
4. richiede comunque attivazione AAL2 del sostituto;
5. registra audit applicativo e operativo append-only;
6. rifiuta se il quorum e' gia' ripristinato o esiste una recovery pendente.

Il servizio esce da `operator_quorum_lost` soltanto quando due admin distinti
sono nuovamente attivi. La procedura viene provata prima del pilot e dopo ogni
cambio dell'autenticatore o del runbook.

L'accettazione di questo ADR non apre il pilot. Il pilot con dati reali o
funzioni operatore resta chiuso finche' un autenticatore concreto non ha
dimostrato AAL2, il dual-control non e' implementato e testato, due persone
distinte non sono admin attivi e verificati e la verifica privacy/legale non ha
approvato retention, anonimizzazione, backup e deletion journal. Il prototipo
locale puo' continuare con fixture. Un prototipo remoto segue ADR-0003: e'
ristretto ai tester o pubblico in sola lettura, non raccoglie input applicativi
reali e tratta separatamente i metadati di connessione secondo DPA e retention.
Un remoto pubblico scrivibile riattiva il gate privacy anche se i contenuti
civici iniziali sono sintetici.

## Cancellazione e privacy

`DELETE /v1/me` adotta un flusso asincrono fail-toward-deletion:

1. il client genera e conserva prima della richiesta un `Idempotency-Key`
   casuale; la prima invocazione richiede access token attivo;
2. il server blocca il principal e registra una receipt idempotente in un
   deletion journal append-only fuori dal perimetro di restore del database;
3. il journal e' la source of truth: dopo la sua conferma, la richiesta e'
   accettata anche se il successivo commit applicativo o la risposta falliscono;
4. la stessa operazione tenta di portare il principal a `deletion_pending`,
   revocare sessioni e recovery set e impedire nuove scritture;
5. un reconciler legge ogni receipt non completata e ripete la transizione
   finche' il database converge; non riattiva mai il principal;
6. retry con la stessa idempotency key restituisce sempre `202` senza rivelare
   stato o identita', anche dopo revoca della sessione; una key sconosciuta
   senza sessione valida non crea una cancellazione ma riceve la stessa risposta
   non enumerante;
7. un job idempotente cancella preferenze civiche, voti, previsioni, risultati,
   reputazione, consensi e proposte non pubblicate;
8. cancella o anonimizza contributi pubblicati e minimizza moderazione/audit
   secondo policy, base giuridica e retention approvate;
9. un errore del purge viene ritentato e non riporta mai il principal ad
   `active`.

Il deletion journal contiene soltanto `deletion_ref`, digest della idempotency
key, request id e timestamp. `deletion_ref` e' calcolato con una chiave HMAC
dedicata e durevole; la stessa reference indicizzata viene associata al
principal alla creazione. Chiave e journal sono esterni al restore applicativo,
cifrati e access-controlled. Se la scrittura del journal fallisce, la
transazione applicativa viene annullata e la sessione resta valida; dopo una
receipt durevole, un failure e' sempre riconciliato verso la cancellazione.

Il journal ha retention approvata almeno pari alla massima eta' di ogni backup
recuperabile. Dopo ogni restore, il traffico resta chiuso finche' tutte le
receipt successive al punto di ripristino non sono state riapplicate e
verificate. Un journal o una chiave presenti soltanto nello stesso backup del
database non soddisfano questo requisito.

I dati cancellati presenti nei backup restano beyond-use fino alla
sovrascrittura programmata e vengono nuovamente eliminati dopo un restore. La
retention di dati, journal, audit, log e backup, e la scelta tra cancellazione e
anonimizzazione dei contributi pubblici, sono gate di `UC-08` e richiedono
verifica privacy/legale.

## Audit minimo

Devono produrre eventi append-only: emissione/rotazione/logout/revoca,
fallimenti di autenticazione e autorizzazione, cambio ruolo/scope,
sospensione/cancellazione, moderazione/override, transizioni turno, esiti,
bootstrap e break-glass. Ogni evento contiene correlation id, actor reference,
ruolo, scope, action, target, stato precedente/successivo, reason e timestamp
UTC, senza bearer, recovery code, secret o testo libero non necessario.

## Quality gate di UC-03, UC-07 e UC-08

La sicurezza necessaria a emettere sessioni non viene rinviata a `UC-08`.
Prima dell'uscita di `UC-03` sono obbligatori:

1. due principal non leggono o modificano dati reciproci;
2. `userId` e ruolo forniti dal client non hanno effetto;
3. token raw non compaiono in database, log o errori;
4. access, idle e absolute timeout usano un clock controllabile nei test;
5. un solo refresh concorrente riesce; una prova end-to-end con Flutter web e
   almeno due tab di un browser reale verifica lock cross-tab, replay, perdita
   della risposta sostitutiva, revoca della famiglia e fallback fail-closed;
6. logout corrente/globale e cambio ruolo revocano davvero le sessioni, mentre
   il logout ripetuto resta `204` e cancella i cookie;
7. ogni recovery code e' monouso, recover conserva codici residui, la rotazione
   del set e' in due fasi, `prepare`/`confirm` non consumano codici, l'eccezione
   bootstrap scade e un set scaduto non puo' essere rigenerato con la sola
   sessione; tutti i flussi non enumerano e applicano rate limit;
8. cookie persistenti e loro cancellazione, route credential slots, Origin,
   Fetch Metadata, CSRF e credential conflict sono verificati end-to-end via
   HTTPS same-origin in un browser reale; una seconda origin ostile verifica il
   rifiuto CORS e, se esiste una origin cross-origin consentita, il browser
   prova sia preflight autorizzato sia negato. `X-MP-Client` forza il preflight
   soltanto nei casi cross-origin; i soli test Node o HTTP simulati non
   soddisfano il gate;
9. segreto HMAC, key id e procedura di rotazione sono configurati fuori dal
   codice e i failure dello store sessioni sono fail-closed;
10. creazione principal, refresh e recover hanno quote/rate limit minimi e
    payload limit prima di essere esposti.

`UC-07` aggiunge e verifica:

11. sospensione, scope e ownership deny-by-default;
12. anonymous non puo' elevarsi a moderator/admin;
13. transizioni concorrenti di moderazione e turno non perdono aggiornamenti;
14. bootstrap one-shot del primo e del secondo admin, chiusura irreversibile
    dopo due attivazioni, perdita quorum, modalita' limitata, recovery offline
    a doppia custodia, sessione opaca operatore e protezione dell'ultimo admin.

`UC-08` chiude e verifica:

15. idempotency key, journal source of truth, failure tra journal e database,
    retry post-revoca e reconciler convergono sempre verso la cancellazione;
16. purge idempotente non riattiva il principal;
17. restore isolato riapplica il deletion journal prima del traffico e usa la
    chiave HMAC esterna al restore;
18. export, retention e anonymization corrispondono alla policy approvata;
19. threat model e test anti-abuso estendono i controlli minimi di `UC-03`.

Secure storage e integrazione native hanno un gate separato quando il
repository abilita quei target; oggi il gate Flutter applicabile e' web e deve
includere pulizia di cache, Cubit e repository.

## Alternative considerate

### JWT stateless

E' respinto per il pilot. Con singolo backend e PostgreSQL, claim di ruolo e
scope diventano rapidamente stantii e revoca, cancellazione, replay e cambio
ruolo richiedono comunque denylist o stato server. I token opachi riducono i
dati esposti e rendono immediata la revoca. JWT puo' essere rivalutato solo se
piu' resource server devono validare offline e viene definita una strategia di
revoca equivalente.

### Un solo token a lunga durata

Riduce il numero di endpoint ma amplia la finestra di furto e non consente
rotazione/replay detection separati. E' respinto.

### Grace window o riemissione del refresh sostitutivo

Una finestra temporale non distingue due tab da un attaccante che usa per
primo un token rubato. Riemettere la stessa risposta richiederebbe conservare o
cifrare token raw e definire una chiave idempotente o sender-constrained. E'
respinto per il pilot: il client serializza e ogni riuso revoca fail-closed.

### Identificativo scelto dal client

Mantiene compatibilita' con lo scaffold ma permette impersonificazione e non
offre revoca o ownership verificabile. E' ammesso soltanto nel mock locale,
mai nel pilot.

### Account nominativo o social login

Semplifica il recupero ma amplia dati personali, dipendenza da provider e UX.
E' fuori scope del pilot definito come anonimo.

### Device fingerprint o recupero manuale operatore

Non dimostra ownership, e' fragile e introduce trattamento dati ulteriore. E'
respinto; un recovery code inutilizzato e' l'unica prova di possesso fuori
sessione.

## Conseguenze

### Positive

- Ownership e isolamento non dipendono da input Flutter.
- Revoca, logout, sospensione e blocco iniziale della cancellazione hanno
  effetto immediato; il purge procede in modo osservabile e idempotente.
- Nessun ruolo o dato utente e' leggibile nel token.
- Web e native condividono il modello server senza condividere storage
  insicuro.
- Ruoli, scope e transizioni sono verificabili e auditabili.
- Il recupero senza email o telefono resta possibile soltanto finche' l'utente
  possiede almeno un recovery code valido, non consumato e non scaduto.

### Negative

- Ogni richiesta autenticata dipende dalla disponibilita' dello store
  sessioni.
- Refresh rotation, replay detection e piu' tab richiedono logica e test
  accurati.
- Perdere o consumare tutti i recovery code dopo logout rende l'identita'
  irrecuperabile.
- Rubare un recovery code consente takeover; i codici residui limitano il
  rischio di lockout definitivo ma richiedono rate limit, copy e custodia
  chiari.
- Cookie web richiedono hosting same-site, CORS credentialed e protezione
  CSRF.
- Cancellazione e backup richiedono policy e operazioni esplicite.
- L'autenticazione operatori resta incompleta finche' non e' scelto un provider
  compatibile con i requisiti.

## Condizioni di accettazione

L'accettazione del proprietario del 14 luglio 2026 copre:

- token opachi access/refresh e verifier HMAC server-side;
- durate accettate 15 minuti, 30/90 giorni e recovery set 180 giorni, con
  warning rispettivamente a 14 e 30 giorni e rinnovo esplicito;
- rotazione refresh rigorosa, lock cross-tab e recupero necessario se la
  risposta sostitutiva viene persa;
- set di otto recovery code, consumo singolo, rotazione in due fasi e rischio
  di perdita/furto; `prepare`/`confirm` non consumano codici e un set scaduto
  non viene ricreato con la sola sessione;
- promessa di recupero limitata a un codice valido, non consumato e non
  scaduto, senza recupero manuale garantito;
- change plan coordinato OpenAPI/backend/Flutter degli input `userId`, con
  artefatto combinato o rollout compatibile in tre fasi e nessuna finestra
  autoritativa lato client;
- cookie web persistenti, slot di credenziale per route, matrice CSRF/CORS e
  profilo HTTPS loopback, con gate end-to-end in browser reale;
- secure storage native come requisito condizionato all'abilitazione del
  target;
- separazione tra identita' anonymous e operatori;
- matrice ruoli, scope e admin non-superset di moderator;
- lifecycle di identita', sessione, moderazione e turno;
- gate pilot vincolante: autenticatore concreto validato AAL2, bootstrap
  offline one-shot del primo e secondo admin, chiusura del bootstrap, workflow
  dual-control e recovery offline del quorum implementati e testati e due admin
  appartenenti a persone distinte;
- prototipo remoto ristretto o pubblico in sola lettura, senza input
  applicativi reali e con metadati di connessione coperti da DPA/retention;
- distinzione tra logout, reset locale e cancellazione;
- cancellazione asincrona fail-toward-deletion, idempotency key, deletion
  journal source of truth e chiave HMAC separati dal perimetro di restore;
- cancellazione/anonimizzazione, retention e trattamento backup come gate privacy
  prima del pilot.

## Riferimenti

- [RFC 6750: bearer token usage](https://www.rfc-editor.org/rfc/rfc6750.html)
- [RFC 7009: token revocation](https://www.rfc-editor.org/rfc/rfc7009.html)
- [RFC 9700: OAuth security best current practice](https://www.rfc-editor.org/rfc/rfc9700.html)
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
- [NIST SP 800-63B-4: authenticator assurance levels](https://pages.nist.gov/800-63-4/sp800-63b/aal/)
- [NIST SP 800-63B-4: session management](https://pages.nist.gov/800-63-4/sp800-63b/session/)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain-services/)
- [Android Keystore](https://developer.android.com/privacy-and-security/keystore)
- [EDPB: anonymisation and pseudonymisation](https://www.edpb.europa.eu/topics/ai-and-technology/anonymisationpseudonymisation_en)
- [GDPR: Regulation (EU) 2016/679](https://eur-lex.europa.eu/eli/reg/2016/679/2016-05-04)
