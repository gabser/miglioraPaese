# Sentinelle — preparazione fase 3: missioni e prove

14 ottobre 2026: avvio. **Fase 3 verificata localmente il 15 ottobre 2026**;
evidenze e checkpoint finali nel registro.
Baseline codice `27284f29703acf5607435e8682e6c7369d701f228aba7ee12c42e2c064f91f19`,
snapshot `/tmp/sentinelle-baseline-20261013/phase2-workspace.tar.gz`.
Requisiti FG-01, FG-02. Il piano resta vincolante.

Risultato: esplorazione anonima del catalogo per Comune/zona, dettaglio con area
pubblica delimitata e istruzioni, accettazione con account email verificato,
rinuncia, questionario, bozza offline, prove sintetiche, invio e ricevuta server.
Prima categoria pulizia aree pubbliche e ricontrollo settimanale. Nessun catalogo
di missioni reali o protocollo ratificato inventato durante le prove locali.

## Confini del contratto

Missione, prenotazione, osservazione e prova sono risorse distinte sotto `/v1`.
Identità, tempo, deadline e slot dal server. Prenotazione e invio richiedono
risposta server; la bozza può vivere offline ma non assegna slot né attesta invio.
Non confondere risposta dell'osservazione con andamento fantasy: nessun esito
competitivo derivato automaticamente dal questionario.

Questionario breve consente nessuna criticità, non osservabile e non so, oltre
all'osservazione di rifiuti visibili. Rischio/accesso impossibile consentono
rinuncia senza penalità. Il dettaglio mostra durata, finestra, prove richieste,
punti fotografici ripetibili e riconoscimento dichiarato 10 XP dopo
validazione; nessun accredito prima della fase 4.

Prove locali con file sintetici e storage adapter separato. Upload privato,
autorizzazione autore/operatori, limiti/tipo/contenuto e metadati minimi sul
server, nessun URL pubblico diretto. Upload interrotto recuperabile, finalizzazione
idempotente e ricevuta interrogabile dopo risposta persa. Configurazione retention
esplicita; nessuna scelta di provider o storage operativo implicita.

Bozze e upload sono scoped a principal/Comune/missione/protocollo/finestra.
Logout, revoca, reset e cambio scope invalidano risposte pendenti prima di ogni
scrittura locale, come i barrier della fase 1. Preservare i flussi proposte
esistenti e il collegamento ospite/account fase 2.

## Prove obbligatorie prima del gate

- Ultimo slot richiesto da due account: uno solo confermato; retry stessa chiave
  non occupa un secondo slot. Prenotazione scaduta/rinuncia libera capacità.
- Account non verificato o revocato rifiutato; isolamento persone/Comuni;
  conflitto di revisione non modifica una bozza o contribuzione già inviata.
- Doppio invio, risposta persa e riavvio producono una sola contribuzione;
  ricevuta recupera lo stesso snapshot di accettazione.
- Upload interrotto/ripreso, file invalido, contenuto eccedente limite, metadata
  superflui e accesso di altro utente; nessuna prova pubblica prima di approvazione.
- Geolocalizzazione assente, permessi negati, offline, stato invio incerto e
  bozza recuperata; niente fallback API→mock.
- Layout 390/1024/1440, tastiera e feedback accessibili; contratto/backend/client
  aggiornati insieme, PostgreSQL reale e regressioni delle fasi precedenti.

Funzioni incomplete disattivate. Console di revisione e ledger XP vengono
implementati soltanto in fase 4, che precede qualunque raccolta reale. Test verdi
non soddisfano i gate operativi o una verifica umana sul territorio.

## Contratto iniziale concordato

Catalogo pubblico `GET /v1/municipalities/{id}/missions?zoneId` e dettaglio
`.../missions/{missionId}`. Stato personale `GET .../missions/{missionId}/booking`;
prenotazione `POST .../missions/{missionId}/bookings` con windowId e chiave
idempotente. `GET /v1/bookings/{bookingId}` e `POST .../release` con revisione.

Upload legato alla prenotazione `POST .../uploads`, metadata MIME PNG/byte totali
e chiave idempotente; stato `GET /v1/uploads/{uploadId}`, chunks base64 fino a
32 KiB tramite `PUT .../chunks` (offset identico/byte identici replay, diversi
conflitto), `POST .../complete` idempotente. `GET /v1/proofs/{uploadId}` restituisce
metadata e PNG base64 soltanto all'autore autorizzato, con no-store.
Backend PNG validato/sanitizzato, 2 MiB massimo; client importa JPEG/PNG e
normalizza prima dell'upload con limiti dichiarati, senza affidare al client la
validazione o la rimozione finale dei metadati.

Invio `POST /v1/bookings/{id}/observations` con chiave idempotente, revisione,
versione protocollo, risposta `noIssue|nonObservable|unsure|visibleWaste`, note
e proofIds. Ricevuta immutabile `pendingReview`, XP accreditati zero; recupero
`GET .../receipts/{key}` restituisce lo stesso snapshot dopo risposta persa.

Configurazione server esplicita: `MISSIONS_ENABLED=true` richiede PostgreSQL,
account abilitati e `MISSION_STORAGE=local-synthetic`, root assoluta privata
`MISSION_STORAGE_ROOT` e retention `MISSION_RETENTION_DAYS` fra 1 e 30.
File con ID opachi e ACL dal database; staging residuo dopo rollback non è
scaricabile. Cleanup di eventuali orfani nella rehearsal fase 8, senza attestare
che il solo rollback database rimuova file già scritti.
Questi endpoint sono implementati e verificati nel profilo sintetico; il registro
conserva i comandi/esiti e i limiti, distinti dal gate operativo.
