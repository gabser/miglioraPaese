# Sentinelle — fase 7: cooperazione e ritorno

15 ottobre 2026. **Fase 7 verificata localmente**, FG-12/13/14; gate operativo separato.
Baseline432file SHA256 `ca3db6836dffd75f7acf9dc65220ec55d606d8347b4b8354c3892c01593f273b`,
`.sentinelle-local/checkpoints/phase6-code-files.json` e `phase6-workspace.tar.gz`.
Contratto fissato sotto prima delle deleghe, su eventi e selezione stagioni5/6.

Copertura cooperativa: unità server luogo/finestra UTC, condivisa fra missioni
equivalenti secondo fase4. Una unità coperta una volta da contributo validato;
replica, foto, XP, numero di voti o punti fantasy non moltiplicano la copertura.
Obiettivi attesi esplicitamente pubblicati per Comune/periodo; nessun obiettivo
inventato dall'attività osservata. Denominatore zero è obiettivo assente, non100%.
Risultato pubblico aggregato, nessun elenco di persone/follower o prove private.

Inbox in-app autenticata, paginata, con stato letto persistito sul server e
recuperabile da altro dispositivo. Eventi integrazione/decisione/esito/rettifica/
ricontrollo pertinenti all'account; niente messaggi esterni o provider impliciti.
ID messaggio e destinatario server-owned, tenant/ownership su ogni lettura/write.
Rifiuto/revoca/expiry non devono creare link che consentono prove non autorizzate.
Contenuti sintetici compatti, senza copia di foto, note personali o token invito.

Follow luogo facoltativo e revocabile; nessuna iscrizione automatica da apertura
pagina. Eventi pertinenti a contributori/giocatori/follower, senza duplicazioni
quando una persona ricade in più categorie. Unfollow interrompe nuovi eventi da
quel criterio; non modifica storico né obblighi di una propria integrazione.
Outbox/eventi e mutazione dominio nella stessa UoW, chiave evento/versione/recipient
unica; replay, riavvio e ricalcolo non producono notifiche duplicate. Eventuale
backfill di eventi storici solo comando locale esplicito idempotente, non al boot.

Calendario: comando amministrativo locale sintetico, input dichiarato e ricevuta
idempotente; riusare la costruzione/validazione v2 fixture come logica condivisa.
Pubblicare nuove stagioni e giornate con carte/versione/catalogo/deadline/obiettivi
coerenti prima del lock. Stesso comando ripetuto restituisce stesso risultato;
ID già pubblicato con contenuto diverso è conflitto, mai modifica dello storico.
Nessun rinnovo automatico demo, import punti o membership fra stagioni. Nuove
finestre/missioni devono avere protocollo pubblicato e capacità esplicita.

Default stagione attiva/prossima/ultima e selezione esplicita fase5 preservati;
nuova pubblicazione futura non sostituisce la stagione ancora attiva. Intent
pendenti restano nel loro scope originale. Senza prossimo calendario, UI comunica
indisponibilità; nessun fallback/seed casuale. Carico e capacità revisione restano
gate umano, non autorizzazione implicita a pubblicare dati reali.

Gate: dedup cross-missione/replica; unvalidated/rejected non coprono; inbox due
account/Comuni, doppio criterio, read/retry/newdevice/revoca, rollback outbox e
privacy; follow/unfollow; calendario stesso comando perso/restart, conflitto,
storico v1/v2 intatto, ritorno sintetico a secondo controllo settimanale;
PostgreSQL/Flutter/gate e nuove UI 390/1024/1440. Feature incomplete off.

## Contratto fissato dall'orchestratore

Guardie `COOPERATION_ENABLED=false` server e `COOPERATION_MODE_ENABLED=false`
client richiedono account/missioni/revisione/misurazioni/fantasy API. Outbox di
questa feature attiva solo quando configurata: nessun backfill implicito degli
eventi creati con flag spento. Il calendario amministrativo è un comando locale
separato, senza nuove route di pubblicazione e senza rinnovo al boot.

- GET `/v1/municipalities/{municipalityId}/cooperation?seasonId=&matchdayId=`:
  `{municipalityId,seasonId,matchdayId,serverTime,goal:null|CoverageGoal,
  coverage:{expectedPlaceWindows,validatedPlaceWindows,ratio}}`. Ratio null con
  obiettivo assente/denominatore0. Goal
  `{id,title,version,publishedAt,expectedPlaceWindows}`. Nessun elenco persone,
  follower, prove o ID contributi. Unità coperte appartenenti ai target pubblicati,
  dedup placeId+UTCstart/end; il totale non cresce con repliche o XP.
- GET `/v1/me/inbox?municipalityId=&limit=&cursor=` richiede account verificato;
  limit1..50 default20, cursor opaco bounded. Risposta
  `{serverTime,items:InboxMessage[],nextCursor:null|string,unreadCount}`.
  InboxMessage `{id,type,title,createdAt,readAt:null|string,municipalityId,
  target:{kind,...scopeIds}}`; target è DTO tipizzato e il client costruisce
  soltanto route in allowlist, mai URL arbitrari. Nessun testo personale o token.
- PUT `/v1/me/inbox/{messageId}/read`, body vuoto: idempotente naturale,
  `{messageId,readAt}`; server recipient constraint, inesistente/altrui404.
- GET `/v1/me/followed-places?municipalityId=` -> `{items:[{placeId,municipalityId}]}`;
  PUT/DELETE `/v1/me/followed-places/{placeId}?municipalityId=`, body vuoto,
  risposta `{placeId,municipalityId,following}`. Nessuna azione implicita dal GET.
  Luogo deve esistere nel catalogo pubblico del Comune; alias/body account vietati.

Recipient solo account verificati, non ID guest inventati; il login conserva
inbox e follow lato server su due dispositivi. Un account non riceve retroattivamente
eventi guest; eventuale backfill esplicito resta distinto e auditabile. Eventi
`integrationRequested|observationApproved|observationRejected|outcomePublished|
outcomeCorrected|recheckRequested`: proprie integrazioni/decisioni sempre pertinenti;
pubblicazioni/rettifiche per contributori, giocatori con carte frozen pertinenti
e follower del luogo; ricontrolli per destinatario della replica e follower.
Sovrapposizioni una sola notifica per evento/versione/recipient. Nessuna copia
di reason/note/prove private. Titoli statici locali; destinatari calcolati server.

Outbox salvata insieme al comando dominio, con checkpoint fault-injection prima
commit. Materializzazione inbox idempotente nella stessa UoW o drain locale
transazionale riavviabile; GET può drenare solamente eventi già committed.
Unfollow si applica agli eventi nuovi, non cancella messaggi già generati.
Cancellazione account elimina inbox/follow/outbox del destinatario senza toccare
gli altri; progettare FK esplicite senza introdurre un nuovo link guest implicito.

Comando calendario legge JSON locale sintetico (body bounded) con
`idempotencyKey,municipalityId,season,cards,matchdays,missions,coverageGoals` e
produce ricevuta con digest canonico/ID/versioni pubblicate. Validazione riusa
costruzione v2 esistente; scope e fonti sintetiche dichiarati, solo loopback.
Goal privato di pubblicazione include target unici `{placeId,startsAt,endsAt}`
associati a missioni/finestre definite. Stessa chiave/body replay, chiave/body
diversi409; ID pubblicato diverso409 anche con nuova chiave. Tutti i riferimenti
validati prima commit; niente pubblicazione parziale. Storico immutabile,
nessuna modifica stagione v1 e nessuna importazione membership/punti.
Input amministrativo massimo256KiB; massimo200 carte,52giornate,500missioni,
52obiettivi e1000target per obiettivo, ID unici entro ogni scope. Finestre,
baseline/protocolli/deadline, capacità e unità validate sul server prima commit;
non accettare sourceStatus/verified dal file come attestazione di fonte reale.
Pubblicazione generale riusa la validazione v2 senza trasformare le fixture
esistenti in un calendario demo che si rinnova automaticamente.

### Obiettivo delle leghe: requisito FG-12 da non ridurre al solo Comune

GET `F/leagues/{leagueId}/cooperation?matchdayId=` (F base fantasy del Comune)
richiede membership e usa la stagione autorevole della lega. Risposta
`{serverTime,municipalityId,seasonId,matchdayId,leagueId,goal,
coverage:{expectedPlaceWindows,validatedPlaceWindows,ratio},
municipalCoverage:{expectedPlaceWindows,validatedPlaceWindows,ratio}}`.
Goal pubblicato per Comune/giornata è anche obiettivo cooperativo esplicito delle
leghe di quella stagione; UI distingue progresso della lega e del Comune.
Non usare `cooperativeScore:null` come unica rappresentazione né mescolare unità
cooperative e punti fantasy. Nessun ranking personale delle sentinelle.

Target inbox è una union esatta: `{kind:observation,observationId}` verso propria
ricevuta/revisione; `{kind:evaluation,evaluationId,seasonId,matchdayId}` verso
dettaglio pubblico; `{kind:recheck,replicationRequestId,missionId}` verso richiesta
replica owned; `{kind:mission,missionId}` verso dettaglio pubblico per follower
avvisato di un ricontrollo. Le notifiche non creano replication_requests nuove,
obblighi privati, prenotazioni o scope XP extra per i follower. La replica umana
esistente resta soltanto del destinatario originale. municipalityId è quello
del messaggio e non è accettato come
identità. Il client risolve richiesta replica tramite repository missioni/review
esistente prima di prenotare; nessuna azione automatica dall'apertura messaggio.
Follow list può aggiungere `displayName` allowlist dal catalogo pubblico, senza
note/coordinate precise/follower. API non accetta destinatari o URL nel body.
Mission DTO pubblico aggiunge `placeId:string|null` dal catalogo server dei luoghi;
vecchie fixture senza proprietà restano compatibili. Nessuna derivazione dal
missionId o dalle coordinate nel client; con null non offrire follow del luogo.
EvaluationPublished aggiunge analogamente `placeId:string|null` pubblico dal
protocollo/catalogo per follow nel dettaglio esito. Vecchi payload senza campo
sono null; nessun UPDATE delle pubblicazioni storiche o delle ricevute per
arricchirle, nessuna inferenza da cardId. Con null l'azione follow non compare.

Competitori e spettatori possono contribuire. Accredito cooperativo di lega
soltanto per contributo validato appartenente ai target, account membro attivo
al momento della validazione e invio successivo alla propria adesione. Il server
registra unità luogo/intervallo con vincolo unique lega/goal/place/starts/ends
nella stessa UoW della validazione; replay/repliche non raddoppiano. Entrare dopo
l'invio non importa contributi precedenti. Uscire dopo accredito o trasferire
proprietà non cancella il progresso aggregato storico. Lega archiviata resta
consultabile ai membri rimasti con progresso congelato, non riceve nuovi crediti.
Nessun backfill automatico dei contributi validati prima dell'attivazione feature;
eventuale comando esplicito deve rispettare gli stessi criteri e dichiarare limiti.

Gate aggiuntivi: stessa persona in due leghe, spettatore valido, joinedAt oltre
submittedAt escluso, due membri sullo stesso target contano1, replay approvazione,
uscita/trasferimento dopo accredito preservano il totale, archivio impedisce nuovi
crediti, altra lega non leggibile, obiettivo assente ratio null. Mostrare tab
cooperazione nelle leghe API insieme all'obiettivo condiviso senza dati personali.

### Chiarimenti da review prima del gate finale

Gli ID sono opachi bounded: colon, spazi e Unicode sono leciti; vietati caratteri
di controllo, slash/backslash, `?`, `#`, `%` e segmenti esatti `.`/`..` nei nuovi
identificatori pubblicabili del calendario. Server max128, parser inbox max160
per compatibilità; nessuna conversione in ID scelti dal client. Union target
resta allowlist esatta e i segmenti di navigazione sono codificati con URI.
La grammatica ASCII-only del parser non deve impedire l'apertura di messaggi
prodotti da un calendario valido.

Pubblicazione calendario ricontrolla il clock dopo il checkpoint finale e
immediatamente prima del commit: se ha attraversato un lock, rollback completo
di stagioni/carte/giornate/missioni/goal/ricevuta. Replay di ricevuta già committed
resta prima delle guardie temporali, senza tentare di ripubblicare o mutare dati.
