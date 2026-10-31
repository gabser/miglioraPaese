# Sentinelle — fase 8: candidato e rehearsal operativa

15 ottobre 2026; chiusa localmente il 16 ottobre. **Verificata in ambiente sintetico**.
Baseline di ingresso449fileSHA256
`e5666957872d81e44ffd287632b1e423345d6c9120523bb9d6f25cf581bfa237`,
`.sentinelle-local/checkpoints/phase7-code-files.json` e `phase7-workspace.tar.gz`.
Contratto fissato prima delle deleghe. Risultati finali nel registro e nel dossier:
217 backend, 466 Flutter, cinque build e rehearsal identificata PASS; candidato
`e75f7744a9d55c620fb7c08388761d98b911a850d0f29eeeb6588faa9c7b1fad`.
Solo ambiente sintetico locale. Gate umani del dossier operativo ancora aperti.

## Verifiche e confini da fissare sul candidato ottenuto

Identità candidato: HEAD più digest manifesto file/config reali, schema/manifest
migrazioni e profilo effettivo. Non fingere un commit del diff non committato.
Smoke e risposte diagnostiche devono consentire di riconoscere il candidato;
non restituire path locali, config segreta, URL database o dati personali.

Rehearsal PostgreSQL e Flutter: account recuperato, nuova stagione pubblicata,
missione con criticità e senza criticità, prove sintetiche, integrazione,
validazione10XP, protocollo quantitativo, intervento temporaneo, esito/ricorso/
rettifica, invito/trasferimento, obiettivo cooperativo/inbox, secondo controllo
settimanale. Clock dichiarato, retry/risposta persa/restart e altro utente intatto.
Collegare evidenze alle revisioni effettive, senza ricontare fixture non eseguite.

Backup PostgreSQL: dump coerente, manifest con schema/digest/config non segreta,
snapshot prove private compatibile, cartella locale700/file600. Restore soltanto
verso database usa e getta con nome consentito e connessione loopback verificata;
mai restore in-place, reset dei dati sorgente o downgrade automatico. Verificare
integrità, ricevute, XP, storico esiti, membership/inbox e readiness dopo restore.
Provare errore/copia incompleta: nessun candidato restaurato dichiarato pronto.

Cancellazione/retention: fissare prima la matrice classi di dati/operazioni già
esistenti sul codice reale. Diario di cancellazioni separato dal backup da
riapplicare prima di esporre una copia restaurata; replay idempotente e revoca
accesso del soggetto, nessuna resurrezione dei dati eliminati. Prove scadute
inaccessibili già tramite policy; cleanup elimina anche file/chunk e orfani,
senza seguire symlink o cancellare fuori dalla root privata. Fault injection fra
DB e file lascia stato recuperabile; gli altri utenti restano intatti.
Conservazione degli aggregati/audit va dichiarata esplicitamente: non promettere
una cancellazione completa se restano note, foto, email o token recuperabili.
Politica operativa e base giuridica reali restano gate umano del dossier.

Prima di implementare strumenti di cancellazione, separare le operazioni:
erasure fantasy già esistente (account e guest), revoca sessione, rimozione prove
per retention e possibile chiusura completa account. Non equiparare le prime tre
alla quarta. La prova minima comprende cancellazione fantasy dopo backup più
restore senza resurrezione, retention/upload incompleti/orfani e isolamento di
un altro utente; eventuali classi non eliminate vanno riportate nella matrice
e nel NO-GO, senza affermare una cancellazione integrale non realizzata.
Il diario esterno non va perso insieme al dump; restore fallisce chiuso se il
diario richiesto manca, è corrotto o contiene operazioni non riconciliate. Non
esporre una copia potenzialmente antecedente a una cancellazione confermata.

Osservabilità: route name statico/status/durata/revisione; nessun raw URL, query,
frammento invito, header auth, OTP/email, body/note/prove o ID personale in log/
label. Generare requestID server senza copiare header arbitrari: anche un ID con
caratteri consentiti potrebbe contenere OTP/token o altri dati personali.
Readiness distingue feature e dipendenze richieste, degradazione/fault-injection
non perde gli errori e non scrive segreti; niente collector/provider impliciti.

Build tutti i profili supportati documentati, smoke sul profilo identificato,
suite backend/Flutter finali, analyze con policy reale, manifest e OpenAPI.
Matrice da verificare sulla configurazione finale: legacy mock (default), legacy
API senza fantasy, fantasy mock esplicito, fantasy API senza feature Sentinelle,
Sentinelle API completo incluse continuità/cooperazione. Conservare output e
identità separati per non attribuire lo smoke dell'ultima build alle precedenti;
se un profilo non è supportato dichiararne la guardia reale invece di forzarlo.
Render e test non sono certificazione nativa/accessibilità umana/prova utenti.
Conservare nuovi log e snapshot in `.sentinelle-local/`, esclusa da Git; riavvio
ha già dimostrato che `/tmp` non è una custodia durevole delle evidenze.

Rollback locale documentato: sospendere scritture/accesso, conservare dati e
backup, procedura di ripristino provata sulla copia e non sul database live.
Limiti del downgrade10/11 con repliche popolate restano validi: usare restore
controllato, non modificare migrazioni storiche per far passare il rollback.
Anche15 può rifiutare down dopo trasferimenti con creator diversi e stessa key
sotto un owner: il vecchio uniqueowner non rappresenta il nuovo stato valido.
Non mutare key o identità per forzarlo; includere questo stato nella rehearsal
restore e provare il fallimento atomico del downgrade senza perdita dati.

Output: aggiornare registro, matrice porting/accettazione e dossier operativo
con soli risultati reali, digest finale, comandi/log, problemi residui e ruoli
richiesti. Decisione **NO-GO operativo** finché mancano approvazioni esterne;
il completamento tecnico locale non le sostituisce e non autorizza deploy.

## Contratto tecnico fissato dall'orchestratore

Identità candidata tramite `CANDIDATE_ID` (digest64hex del manifesto codice finale),
env backend e `--dart-define` Flutter omonimi; non generare un file codice che
contenga il proprio digest. ID assente resta dichiarato non identificato nei
profili preesistenti; gli smoke finali usano ID reale. `/health` e diagnostica
locale espongono solo ID/versione, persistenza, flag effettivi non segreti e stato;
nessun URL database/storage, token o path. Route frontend `/diagnostics` solo
top-level, raggiungibile dalle informazioni ambiente, senza cambiare i default
dei tab. Distingue demo/API/laboratorio e segnala che i gate operativi sono aperti.
Un caricamento diagnostico non crea sessione/player o altri dati; mock non
richiede il backend. Non mostrare una configurazione come se fosse deploy verificato.

Strumenti ops solo sintetici locali: loopback+database di test esplicito e root
private verificate, input/output bounded, backup e restore mai sul database
sorgente. Nessuna route admin di backup/delete o nuovo provider. Eventuale flag
`OPS_LOCAL_ENABLED=false` richiede profilo PostgreSQL sintetico e configurazione
esplicita del diario; documentare quali garanzie esistono quando è disabilitato.
L'erasure fantasy già esistente deve entrare nel diario nel profilo ops, anche
quando invocata tramite HTTP, non soltanto da script di rehearsal. Se un errore
fra file e DB lascia operazione incerta, restore deve rifiutare l'esposizione fino
a riconciliazione; nessuna garanzia basata sul solo log dentro il dump vecchio.
Usare HMAC/riferimenti non personali per il diario e mantenere materiale necessario
fuori dal dump; file e manifest privati non si committano né si stampano in chat.
Snapshot/manifest includono watermark o sequenza del diario coerente con il punto
del backup; restore riapplica solo cancellazioni successive, non tutte quelle
storiche. Prova discriminante: erase→nuovo enrollment lecito→backup2→restore2
preserva il nuovo stato; backup1 precedente a erase non lo fa riapparire.
Backup/prove/diario richiedono scritture sospese per questo laboratorio e lo
dichiarano esplicitamente; non assumere che un advisory lock copra tutti i writer
legacy o le operazioni filesystem. Nessuna sospensione/distruzione automatica di
connessioni o database live per forzare il test.

Sequenza finale per evitare ricostruzioni: autori backend/client completano codice,
mirati e review; suite complete prima di congelare l'identità; root salva manifesto
codice stabile e comunica CANDIDATE_ID. Solo allora build dei cinque profili con
output separati, rehearsal e smoke identificati. Se cambia codice dopo il freeze,
registrare nuovo ID e rivalutare i gate/build interessati; non attribuire alla
nuova revisione un vecchio binario. Root gestisce browser e documenti finali,
autori mantengono ownership disgiunta servizi backend e lib/test.
