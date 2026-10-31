# Sentinelle — fase 6: inviti guidati e proprietà

15 ottobre 2026. **Fase 6 verificata localmente**, FG-11; gate operativo separato.
Baseline 417 file, digest `e75a4a6ff9e411ed649a89f3dadfc6928d13d6090ef288f634df459e301b90e0`,
`/tmp/sentinelle-baseline-20261013/phase5-code-files.json` e snapshot workspace5.
Contratto fissato sotto prima delle deleghe; HEAD e autorizzazioni invariati.

Ripresa dopo limite crediti: artefatti storici `/tmp` persi. Baseline5 sopra è
un riferimento registrato, non un file disponibile nella nuova sessione.
Checkpoint corrente partial6,426 file, digest
`3a3d18d4eef57b769c4152b8d39c270a5cd090c21078aec83a7594871c3da938`, salvato in
`.sentinelle-local/checkpoints/resume6partial-*`. Nuovi log e database sintetico
sono nella cartella locale esclusa da Git; non attestare un diff5 non recuperato.

## Decisioni e casi da conservare nel contratto

Invito come link copiabile, riepilogo prima di confermare adesione, intento
conservato durante login. Non inviare messaggi/email a persone reali.
Token escluso da URL richieste/log/analytics e Referer: preferire frammento
client, rimuoverlo dalla barra prima di richieste esterne; preview tramite body
JSON su endpoint pubblico. Nessuna preview consuma invito o crea membership.
Token a riposo continua hash-only sul server; nessun token nella ricevuta del join.
Pseudonimi, privacy ranking e soglia minima fase1 restano valide.

Riepilogo deve risolvere Comune/stagione/lega dal token server, scadenza e stato,
ruolo atteso competitor/spectator, motivo late join e primo lock. Client non
sceglie ruolo né iscrive automaticamente al termine login. Conferma guidata
usa revisione lega e ruolo atteso; se proprietà/ruolo cambia prima del join,
conflitto e nuovo riepilogo. Recompute tempo dopo lock. Vecchio contratto join
senza campi guidati resta compatibile; UI nuova richiede sempre riepilogo.
Revoca/rotazione/scadenza fra preview e conferma impediscono adesione; replay
non duplica membership e cambio identità/scopo invalida risposte pendenti.

Trasferimento in due passi: owner offre a membro attivo, il destinatario accetta
esplicitamente. Nessuna auto-promozione dell'owner, nessun semplice cambio ID
dal client. Account o guest membri esistenti restano compatibili con porting;
ownership organizzativa è distinta dal ruolo competitivo/spettatore.
Revisioni/CAS, chiavi idempotenti, tempo/autorizzazione server, offerta/revoca/
accettazione tracciate. Nessuna mutazione retroattiva di punti o classifica.

Se proprietario esce prima del trasferimento accettato, archivia la lega e
invalida offerte/inviti pendenti; il destinatario non può riattivarla dopo.
Se accettazione precede uscita, ex owner è membro ordinario e la lega resta
attiva sotto il nuovo owner. Target uscito, offerta obsoleta/revocata/scaduta,
self-transfer o altra lega/Comune sono rifiutati senza alterare proprietà.
Nuovo owner controlla gli inviti; ex owner non conserva privilegi amministrativi.
Un solo owner attivo, nessuna finestra senza owner durante la transazione.

Usare seasonId autorevole della lega anche dopo pubblicazione di nuove stagioni,
senza importare punti/membership implicitamente. Nuove tabelle/colonne richiedono
INSERT espliciti e integrazione atomica nel linking guest→account fase2: offerte
from/to e comandi devono seguire identità/server scope corretti, mantenendo snapshot
storici. Account con team concorrente preservato; offerte diventate self dopo link
annullate, guest esclusi non ottengono grant account tramite alias. Old guest token
non accetta un'offerta ora destinata all'account.

## Gate locale

Le nuove FK delle tabelle con owner mutabile devono essere DEFERRABLE INITIALLY
DEFERRED fin dall'inizio, coerenti con il linking atomico fase2. Non affidarsi
alla migrazione8 che rendeva differibili soltanto le tabelle allora esistenti.
Verificare linking con i nuovi record prima di congelare la migrazione.

Preview/login/summary/confirm con risposta persa e riavvio; token non presente
nei log e Referer sintetici; revoca/rotazione/expiry e primo lock attraversato;
due adesioni concorrenti una membership; trasferimento/revoca/uscite concorrenti
rispettano ordine e owner unico; nuovo dispositivo recupera offerte/risultati;
linking guest ripetuto/conflitto e sessione revocata durante attesa; regressioni
fantasy v1/v2, PostgreSQL reale e Flutter, layout 390/1024/1440 e tastiera.

Flag esplicito per percorso incompleto; nessuna espulsione, nome personalizzato,
notifica esterna o cross-season import aggiunti. Gate pilot ancora separato.

## Contratto fissato dall'orchestratore

Base fantasy esistente `F=/v1/fantasy/municipalities/{municipalityId}`.
Nessun nuovo ID account accettato dal client; target delle offerte è il memberId
opaco già assegnato nella lega. Guardia server `LEAGUE_CONTINUITY_ENABLED=false`
richiede fantasy PostgreSQL; client `LEAGUE_CONTINUITY_MODE_ENABLED=false`
richiede fantasy API. Account e guest già iscritti mantengono gli stessi diritti.

- POST `/v1/fantasy/league-invites/preview`, pubblico, body `{token}`: risolve
  scope senza richiedere preferenze Comune/stagione. Risposta allowlist
  `{serverTime,municipalityId,seasonId,leagueId,name,leagueRevision,expiresAt,
  firstLocksAt,expectedRole,lateJoinReason}`; nessun nome/ID owner o membro,
  hash/token o ranking. Token invalido/revocato/scaduto/lega archiviata:404.
  Applicare anche il Comune pilot configurato dopo la risoluzione; body limitato,
  nessuna cache, errori e telemetria senza token. La preview non richiede player
  o enrollment e non li crea; limitare tentativi senza leggere il token dai log.
- POST `F/leagues/join`: vecchio `{token}` conservato; percorso guidato aggiunge
  `{expectedLeagueRevision,expectedRole}` entrambi obbligatori insieme. Il token
  deve risolvere lo scope richiesto; ruolo calcolato dal server dopo lock.
  Stessa persona già membro: ricevuta coerente senza duplicazione; conferma
  guidata divenuta obsoleta:409 e riepilogo rinnovato prima di ritentare.
- GET `F/leagues/{leagueId}/ownership`: solo membri; ritorna revisione e offerta
  pendente visibile all'owner/destinatario. Lista candidati `{memberId,pseudonym}`
  solo all'owner, anche sotto la soglia ranking; nessun accountId. Nessuna lista
  candidati per gli altri membri. Dati inutili omessi dal DTO.
- POST `.../ownership/offers` con `{targetMemberId,expectedRevision,idempotencyKey}`;
  scadenza server min(7 giorni,fine stagione), una sola offerta pendente per lega.
- POST `.../ownership/offers/{offerId}/accept` e `/revoke` con
  `{expectedRevision,idempotencyKey}`; accept solo destinatario attualmente membro,
  revoke solo owner corrente. Non oltrepassare limite esistente di tre leghe
  possedute: verificare anche al momento dell'accettazione. Risposta snapshot
  persistita e replay prima del CAS, mantenendo controlli identità/autorizzazione.
- Metadata lega aggiunge `revision`; creazione, membership, invito/rotazione/
  revoca, offerte e trasferimento incrementano la revisione organizzativa.
  Ranking/riflessioni/punti non la incrementano. Aggiornare gli INSERT con colonne
  esplicite prima di estendere la tabella, preservando chiamanti legacy.

UI: link copiabile nella stessa origine e base path dell'app, frammento
`#league-invite=<token>`; cattura e rimozione prima di inizializzare il router
(Flutter web usa già il frammento per le route), richieste e navigazioni. Il
bootstrap passa soltanto l'intento locale alla landing. La landing rende
riepilogo/inizio login/iscrizione fantasy necessaria/conferma come passaggi
espliciti. Intent locale separato e recuperabile dopo riavvio; nessun token
in query/path, messaggi di errore, analytics o DTO di ricevuta. Conferma e owner
commands mantengono body/chiave se risposta incerta; revisioni obsolete liberano
solo il comando definitivo e richiedono nuovo riepilogo, preservando l'intento.
Cambio identità/Comune/stagione invalida letture pendenti tramite generation;
il token può risolvere un altro scope, ma non cambiarlo senza riepilogo esplicito.

Migrazione additiva soltanto dopo prova DDL up/down/up reversibile in transazione
annullata e linking con fixture complete. Audit organizzativo conserva ID opachi
e tempi, mai token; uscita owner/erase archivia anche offerte. Transfer accettato
è atomico con cambio owner/revisione/audit; replay non trasferisce una seconda
volta né ripristina privilegi dell'ex owner. Nessun nuovo comando messaggi esterni.

### DTO comuni e recovery

Preview è l'oggetto diretto sopra, expectedRole `competitor|spectator`,
lateJoinReason `firstLockReached|snapshotFrozen|null`. OwnershipWorkspace è
`{serverTime,seasonId,leagueId,revision,isOwner,candidates:[{memberId,pseudonym}],
pendingOffer:OwnershipOffer|null}`. OwnershipOffer è
`{id,targetMemberId,targetPseudonym,status,expiresAt,isTarget}`; status
`pending|accepted|revoked|expired|cancelled`. Candidates vuota per non-owner;
pendingOffer null per membro diverso da owner/target. Nessun account ID.
I tre comandi ownership rispondono `{serverTime,seasonId,leagueId,revision,offer}`;
expectedRevision è sempre revisione LEGA, non una seconda revisione offerta.
Risposta persa conserva comando; GET ownership recupera offerta da altro device.
Errori: invalid_field400, forbidden403, not_found404, league_revision_conflict409,
offer_closed409, league_archived409, idempotency_conflict409; usare codici legacy
esistenti per invito/scope/stagione/limite. Ogni nuovo comando idempotencyKey
usa formato esistente8..128; solo errori definitivi liberano body/chiave obsoleti.
Il riepilogo invito non è ricevuta di adesione; solo risposta join o lettura
membership posseduta conferma che l'utente è entrato.

### Chiusura regressione creazione dopo trasferimento

Il creator della lega è distinto dall'owner corrente. Trasferire proprietà non
modifica la creation_key originale; replay create dell'ex owner non crea nuova
lega. Lookup e unique usano stagione/creator/key, mentre limite3 e autorizzazioni
restano sull'owner attuale. Replay restituisce metadata attuali solo se il creator
è ancora membro; dopo uscita404, archiviazione409 legacy. Nessuna membership o
privilegio ricreati dal replay. Migrazione15 additiva,14 già applicata immutabile.
Creator storico sopravvive all'erasure senza una FK che lo cancelli; linking
guest→account nelle sole stagioni migrate rispetta collisioni e keepAccount,
senza dare accesso account al vecchio token guest.
Collisione storica dopo erasure squadra account: se esiste già creator account
con stessa stagione/key, quella chiave resta associata alla propria lega;
creator guest storico non viene sovrascritto. Ownership/membership/offerte della
lega guest migrano normalmente e la lega è accessibile dalla lista posseduta.
Nessun nuovo oggetto creato né grant al vecchio guest per risolvere l'ambiguità.

Limite downgrade15: dopo trasferimenti validi due creator possono avere stessa
key con owner corrente uguale. Il vecchio unique(stagione,owner,key) non può
essere ripristinato senza alterare dati; down15 è consentito solo prima di tali
scritture. Dopo uso feature rollback tramite sospensione scritture e restore
controllato provato in fase8, senza riscrivere creation_key o migrazioni congelate.
Testare il rifiuto23505 in transazione annullata preservando schema e dati;
la prova DDL pre-write non attesta reversibilità dopo qualsiasi uso della feature.
