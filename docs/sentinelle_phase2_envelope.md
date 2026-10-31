# Sentinelle — envelope fase 2: account e continuità

Preparazione del 14 ottobre 2026; non avvia la fase prima del gate fase 1.
Gate fase 1 superato il 14 ottobre; fase 2 avviata, codice baseline
`f9ce0767e67155259bf2591a970a5cdfd2ad60b78024cedd1439c3cfe3783c0a`.
Requisiti: FG-08, FG-09 del piano. Baseline esecutiva da congelare dopo le
verifiche finali fase 1 nel registro; non usare solo HEAD, che non contiene il
diff locale. Autori backend e Flutter distinti, review indipendente e integrazione
dell'orchestratore come fase 1. Esclusi missioni, XP, v2 e servizi esterni.

## Risultato richiesto

Account recuperabile con email verificata tramite codice monouso, pseudonimo,
login da altro dispositivo, logout e revoca dispositivi. Collegamento ospite
atomico e idempotente conserva squadra e membership senza duplicare punti.
Se l'account ha già una squadra concorrente, conservarla e richiedere una scelta
esplicita prima di abbandonare lo stato ospite. Nessun import di snapshot demo.
Ripresa dell'intento dopo login; i token restano esclusi da log e analytics.

## Vincoli di integrazione

La tabella attuale `proposal_sessions` ha `submission_scope` UNIQUE per token.
Non rendere indistinguibili scope delle ricevute legacy o assegnare lo stesso
scope a due righe violando il vincolo. Introdurre un principal account autorevole
o una relazione esplicita; preservare la recovery di bozze e ricevute esistenti.
La sessione locale Flutter verifica lease, epoch e generation prima di applicare
ogni risposta: login/logout/linking e revoca devono rispettare lo stesso barrier.

Identità, codice, expiry, tentativi e riconciliazione sono determinati dal server.
Migrazioni additive: le sette migrazioni precedenti e i loro checksum restano
invariati. Server `/v1`, PostgreSQL transazionale, OpenAPI e mapper/test aggiornati
insieme. La classifica pubblica legacy non deve esporre i nuovi principal account,
come già escluso per `session:`; le leghe mantengono pseudonimi e ranking proprio.

Consegna email attraverso adapter separato. Prove locali solo indirizzi/codici
sintetici e outbox simulata; non scegliere provider né inviare email reali.
Configurazione account esplicita e disattivata finché incompleta. Non esporre un
canale di recupero dei codici di test come capacità operativa.

## Accettazione

- Codice scaduto, riutilizzato, errato e reinvio limitato; consumo atomico con
  richieste concorrenti. Nessun codice o indirizzo nei log tecnici.
- Account recuperato su secondo dispositivo con squadra e leghe corrette;
  revoca impedisce ulteriori letture/scritture anche in concorrenza.
- Guest linking ripetuto e risposta persa non duplicano identità, team o punti;
  conflitto preserva account e guest finché viene effettuata una scelta esplicita.
- Stato locale demo non è importato nel server; scope, Comune e stagione restano
  isolati; callback asincrona precedente al logout non ripopola lo stato.
- API→mock assente; esplorazione anonima possibile; ripresa dell'intento prevista
  nel contratto, senza attivare le missioni delle fasi successive.
- Backend reale PostgreSQL, test repository/flow Flutter, render a 390/1024/1440,
  tastiera, errori/offline e build interessate; regressione legacy fase 1.

La verifica tecnica non chiude provider/email, autenticazione forte operatori,
privacy/retention o altri gate operativi del piano. Registrare file, revisioni,
comandi, risultati effettivi e limiti prima di avanzare alla fase 3.

## Contratto iniziale concordato

- `POST /v1/auth/code` con email sintetica restituisce challenge, scadenza
  e tempo per il reinvio. Adapter email simulato in-process, nessuna route che
  espone il codice; la UI non afferma che una email reale è stata consegnata.
- `POST /v1/auth/verify` consuma challenge/codice e restituisce token
  opaco compatibile con proposal-session, scope, account/pseudonimo e dispositivo.
- `GET /v1/auth/me`, `GET /v1/auth/devices`, `POST /v1/auth/logout`,
  `POST /v1/auth/devices/{deviceId}/revoke`: identità dal bearer, mai dal body.
- `POST /v1/auth/guest-link`: bearer account, token ospite e chiave idempotente;
  conflitto restituisce stato esplicito senza mutation. La scelta `keepAccount`
  richiede conferma consapevole; rinvio/annullamento conserva entrambi gli stati.
  Non offrire sostituzione della squadra account con quella ospite.

Principal account riservato `account:<uuid>`, escluso dal leaderboard pubblico
legacy insieme a `session:`. Il backend mantiene proprietà degli scope legacy
tramite relazioni esplicite, senza violare UNIQUE né sommare ledger/snapshot.
Configurazione prevista `ACCOUNT_ENABLED=true`, PostgreSQL e
`EMAIL_DELIVERY=simulated`; nessun adapter operativo viene scelto o attivato.
Queste firme saranno aggiornate insieme a OpenAPI e codice se l'integrazione
richiede campi additivi; non attestano endpoint già implementati.

I path canonici `auth/code` e `auth/verify` sostituiscono i nomi preliminari
`auth/email-code` e `auth/email-code/verify`, prima di qualunque pubblicazione.
Backend, OpenAPI, client e fixture usano soltanto il contratto canonico condiviso.
L'estensione `auth/profile` permette di impostare il pseudonimo.
La recovery di ricevute con chiavi coincidenti in più scope account restituisce
conflitto esplicito e consente selezione di `submissionScope` verificato come
proprietà dell'account; nessuna lookup arbitraria di scope altrui.
