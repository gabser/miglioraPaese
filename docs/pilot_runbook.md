# Runbook staging e pilot comunale

## Stato e confine operativo

Il repository prepara un candidato di staging riproducibile, limitato a un
solo Comune, ma non autorizza da solo la raccolta di contributi reali. Il nome
del Comune, il referente istituzionale, il titolare del trattamento e il
provider devono essere registrati prima del go-live.

Il pilot usa:

- frontend Flutter compilato in modalità API e bloccato sul Comune scelto;
- backend Node.js in container, non esposto direttamente su Internet;
- volume SQLite persistente e backup separato;
- cookie anonimo firmato, moderazione umana obbligatoria e log senza contenuti
  o identificativi utente;
- insight aggregati oscurati finché non partecipano almeno tre identità;
- reverse proxy TLS che serve app e API nello stesso sito.

## Scheda decisionale del Comune

Compilare e approvare questa scheda in un issue privato o nel sistema
documentale dell'organizzazione, senza inserire segreti nel repository.

| Campo | Valore richiesto |
|---|---|
| Comune e slug API | `bologna` oppure `castel-bolognese` |
| Referente del Comune | nome, ruolo e canale istituzionale |
| Product owner | responsabile della decisione go/no-go |
| Moderatori | almeno un titolare e un sostituto |
| Responsabile incidenti | reperibilità e percorso di escalation |
| Titolare/responsabile privacy | ruolo e approvazione documentata |
| Durata pilot | data inizio e fine |
| Platea | staff, inviti nominativi o accesso controllato |
| Retention | durata e procedura di cancellazione |
| Provider e regione dati | ambiente, paese e backup |

## Gate go/no-go

Tutti i punti sono bloccanti:

- accordo scritto con il Comune e finalità del pilot approvata;
- informativa privacy, retention, cancellazione ed escalation definite;
- staging accessibile solo alla platea concordata;
- app e API sullo stesso sito HTTPS, con origin esatta in allowlist;
- segreti distinti per identità anonima e moderazione nel secret manager;
- backup completato, verificato e sottoposto a una prova di ripristino;
- dashboard o alert su errori 5xx, readiness e spazio disco;
- moderatore primario e sostituto formati sulla procedura;
- smoke test remoto verde e rollback provato;
- contenuti seed verificati con il referente comunale.

## Preparazione dell'ambiente

1. Copiare `services/backend/staging.env.example` in un file non versionato.
2. Impostare lo slug approvato e l'origin HTTPS pubblica. Mantenere
   `MIN_AGGREGATE_SAMPLE_SIZE` almeno a 3.
3. Generare due segreti indipendenti di almeno 32 byte e salvarli come file con
   permessi leggibili solo dall'operatore del deploy.
4. Avviare il backend dietro il reverse proxy:

       docker compose --env-file staging.env \
         -f services/backend/compose.staging.yaml up -d --build

5. Verificare `GET /health`, `GET /ready` e lo smoke test non mutante:

       STAGING_BASE_URL=https://pilot.example.test \
       PILOT_MUNICIPALITY_ID=castel-bolognese \
       npm --prefix services/backend run smoke

6. Eseguire manualmente il workflow **Build staging candidates** con lo stesso
   URL e lo stesso slug, quindi pubblicare l'artefatto soltanto nell'ambiente
   protetto.

L'ingress deve inoltrare l'API senza cambiare host pubblico. Se usa un prefisso
come `/api`, deve rimuoverlo prima di inoltrare la richiesta al backend. La
porta container resta collegata a loopback per impedire il bypass del proxy.

## Moderazione

Le proposte nuove restano `pending` anche quando ricevono voti. Il moderatore:

1. legge la coda con `GET /v1/municipalities/{id}/next-problems?status=pending`;
2. verifica pertinenza, dati personali, linguaggio, duplicati e rischio;
3. invia `approved` o `rejected` a
   `POST /v1/admin/municipalities/{id}/next-problems/{problemId}/moderation`;
4. registra una motivazione breve e non sensibile;
5. usa il canale di escalation concordato per minacce, dati personali o ricorsi.

Il token amministrativo deve arrivare dal secret manager e non va scritto in
issue, log, cronologia shell o documenti condivisi. L'approvazione promuove il
tema nel turno; il rifiuto lo esclude. Una decisione successiva può correggere
la precedente e viene salvata con una nuova data.

## Osservabilità

- `/health` misura la sola raggiungibilità del processo.
- `/ready` interroga lo store e controlla se l'istanza può ricevere traffico.
- `/metrics` espone contatori e durata aggregati per metodo, nome route e
  status; va reso raggiungibile solo dalla rete di monitoraggio.
- ogni risposta include `X-Request-Id`;
- i log JSON contengono timestamp, request ID, metodo, nome route, status e
  durata, mai path grezzi, query, cookie, token, body o ID anonimi.

Alert minimi: readiness fallita per due minuti, qualsiasi crescita continuativa
dei 5xx, spazio volume sotto il 20%, backup non verificato nelle ultime 24 ore e
assenza del processo di scraping metriche.

## Backup, verifica e ripristino

Creare un backup con nome immutabile nel volume dedicato:

    docker compose --env-file staging.env \
      -f services/backend/compose.staging.yaml run --rm \
      -e BACKUP_PATH=/backups/pilot-YYYYMMDDTHHMMSSZ.sqlite \
      api npm run backup

Verificarlo prima di considerarlo valido:

    docker compose --env-file staging.env \
      -f services/backend/compose.staging.yaml run --rm \
      -e BACKUP_PATH=/backups/pilot-YYYYMMDDTHHMMSSZ.sqlite \
      api npm run verify-database

Provare inoltre il caricamento del backup con lo store applicativo, su una
copia temporanea isolata:

    docker compose --env-file staging.env \
      -f services/backend/compose.staging.yaml run --rm \
      -e BACKUP_PATH=/backups/pilot-YYYYMMDDTHHMMSSZ.sqlite \
      api npm run rehearse-restore

Il comando non tocca `/data/pilot.sqlite`: dimostra che il backup è leggibile
dalla versione corrente dell'applicazione. Il gate resta aperto finché la
procedura completa non viene provata nell'ambiente del provider scelto.

Il ripristino è un'operazione controllata: fermare l'API, conservare una copia
del database corrente, verificare il backup scelto, sostituire esclusivamente
`/data/pilot.sqlite`, riavviare e ripetere readiness e smoke test. Richiede
approvazione del product owner e dell'operatore; non va automatizzato su un
target ambiguo.

## Cancellazione della sessione anonima

La pagina Privacy della build API invia `DELETE /v1/session` dopo una conferma
esplicita. Il backend elimina voti, previsioni ed esiti della sessione, rimuove
il collegamento pseudonimo dalle proposte e scade il cookie. Le proposte già
pubblicate restano come contenuto civico non collegato alla sessione, per non
invalidare moderazione e discussione aggregate.

La cancellazione deve essere verificata durante lo smoke manuale del pilot e
descritta nell'informativa approvata. Non sostituisce la policy di retention,
la gestione di eventuali backup ancora conservati o le richieste amministrate
dal titolare del trattamento.

## Lancio e rollback

Procedere in tre finestre: staff interno, gruppo ristretto invitato, platea
pilot concordata. A ogni finestra controllare errori, tempo di moderazione,
proposte rifiutate, completamento dei turni e feedback qualitativo, senza
profilare singoli utenti.

Attivare il rollback se readiness resta rossa, i 5xx superano la soglia
concordata, la coda non può essere moderata, compare un incidente privacy o il
Comune chiede la sospensione. Il rollback consiste nel chiudere l'accesso al
frontend, fermare le scritture API, preservare database e log secondo retention
e pubblicare il messaggio operativo concordato. La demo mock pubblica resta
separata e non deve essere convertita automaticamente nel pilot.
