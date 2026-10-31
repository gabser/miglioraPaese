# Sentinelle — dossier del candidato locale

> Aggiornamento decisionale del 16 ottobre 2026: scelti Supabase (Auth,
> PostgreSQL, Storage e target Edge Functions) e Resend Free per le email;
> Cloudflare Pages è l'hosting frontend proposto. Render Free escluso per
> l'attesa al risveglio. [Runbook aggiornato](sentinelle_deploy_zero_budget_runbook.md)
> e [diagramma prodotti](sentinelle_cloud_architecture.md). Si tratta di scelte
> di progetto, non di servizi attivati o porting verificato. Le diciture
> «provider non scelti» nelle evidenze del candidato sotto descrivono lo stato
> storico della fase 8. Restano aperti dominio/DNS, regioni effettive,
> verifica account Resend senza carta, implementazione e gate operativi.

Aggiornato il 16 ottobre 2026. **Fasi 0–8 verificate localmente; NO-GO operativo**.
Le evidenze sintetiche consentono di chiudere la preparazione locale. Restano
aperte le approvazioni per pilot, dati reali e punteggio competitivo reale.

## Candidato e configurazione

| Campo | Evidenza finale |
|---|---|
| HEAD di base | `1fad162218e758efa3a556790e42b335a6196959`, con modifiche locali preservate; nessun nuovo commit |
| CANDIDATE_ID | `e75f7744a9d55c620fb7c08388761d98b911a850d0f29eeeb6588faa9c7b1fad` |
| Identità del codice | SHA256 del manifesto di 462 file codice/config; documentazione Markdown esclusa per evitare auto-riferimenti |
| Checkpoint | `.sentinelle-local/checkpoints/phase8-final-code-files.json` e `phase8-final-workspace.tar.gz`; copia privata locale esclusa da Git |
| Database | PostgreSQL 17 locale, schema 16, manifest migrazioni 1–16 verificato senza modifiche storiche |
| Contratto | OpenAPI: 108 path e 591 riferimenti locali risolti |
| Distribuzione | Nessuna; cinque build web release locali, profili distinti nella tabella seguente |
| Servizi esterni | Provider, regione, hosting, budget, email e storage operativi non scelti né attivati |

Il digest identifica il contenuto del workspace, non un commit inesistente né
una certificazione. I manifesti dei build registrano comandi, flag, identificativo
e hash degli artefatti. Health/readiness nella rehearsal restituiscono lo stesso
identificativo; la pagina client `/diagnostics` mostra solo la configurazione e
scrive esplicitamente che non verifica il backend.

| Build verificato | Configurazione osservata nel browser |
|---|---|
| legacy-mock | Demo locale; gioco/proposte mock, fantasy e funzioni Sentinelle disattivati |
| legacy-api | API configurata; gioco/proposte API, fantasy e funzioni Sentinelle disattivati |
| fantasy-mock | Demo locale; fantasy mock, funzioni Sentinelle disattivate |
| fantasy-api | Gioco/proposte/fantasy API, pilot sintetico Bologna; funzioni Sentinelle disattivate |
| sentinelle-api | Laboratorio sintetico configurato; API e account, missioni, revisione, misurazioni, continuità e cooperazione attivi; pilot sintetico Tuglie |

Tutti i cinque build PASS; smoke browser sulla diagnostica dei cinque binari:
identificativo completo corrispondente, flag coerenti e avviso NO-GO visibili.
Controllo visivo desktop della pagina senza overflow. Le prove di layout
390/1024/1440 e scala testo 2x restano nei test widget; questo smoke non è una
nuova rehearsal interattiva completa di tutti i flussi.

## Evidenze tecniche eseguite

Artefatti sotto `.sentinelle-local/phase8/`, privati e ignorati da Git:

- Backend `backend/full-final.log`: **217/217 PASS**, 13 suite, zero fail/skip.
- Flutter `client/full-final.log`: **466/466 PASS**. Analisi
  `client/analyze-final.log`: 462 info, zero warning/error; non lint senza segnalazioni.
- Cinque `client/build-*.manifest.json`, relativi log e directory `builds/`:
  build release PASS e hash degli artefatti ricontrollati dopo lo smoke.
- `backend/rehearsal-final.log`: PASS con il CANDIDATE_ID reale;
  artefatto `rehearsal-6b4285cc-b546-4c1c-ae38-a3cd4f6ae116`.
- Review indipendente operazioni e recheck dei tre fix PASS; review client e
  routing completata. Registro con dettagli e verifiche mirate.

Rehearsal HTTP e PostgreSQL reale, profilo `synthetic-local`, clock controllato
2027-01-01–2027-01-09 UTC: recupero account, pubblicazione calendario, invito e
trasferimento, osservazioni con/senza criticità, quattro prove sintetiche,
integrazione, XP, risposta persa/retry e restart, intervento temporaneo,
esito/ricorso/rettifica non determinabile, copertura/inbox e secondo controllo.
Dump PG reale e restore in nuovo database di test: readiness HTTP pronta,
quattro prove verificate, replay di una cancellazione successiva al backup;
altro utente, ricevute, XP e pubblicazioni preservati. 77 eventi log statici.
La precedente rehearsal con ID placeholder non è usata come prova del candidato.

Osservabilità: request ID generato dal server; route statiche, metodi e status,
senza URL grezzi, token, OTP, email o contenuto delle prove nei log tecnici.
Readiness degrada su diario/key/marker mancanti, alterati o non allineati.
Marker restore firmato persistente impedisce accesso alla copia parziale anche
con operazioni locali disattivate; prova di fault e retry superata.
Collector, avvisi e reperibilità sul provider richiedono verifica separata.

Per i comandi con prerequisiti e variabili esplicite vedere
[runbook locale backend](../services/backend/README.md).
Rehearsal eseguita da `services/backend` con Node 24:
`CANDIDATE_ID=<digest sopra> TEST_DATABASE_URL=<database locale di test> node scripts/rehearse-operations.js`.
I dettagli privati restano negli artefatti locali, senza credenziali nel dossier.

## Cancellazione, retention e rollback: ambito verificato

| Classe | Comportamento locale verificato e limite |
|---|---|
| Dati fantasy del principal | Rimozione fantasy e diario HMAC esterno al backup; replay dopo watermark prima di esporre il restore |
| Account e sessioni | Conservati dalla cancellazione fantasy; logout e revoca accessi sono operazioni distinte. Non è una chiusura completa dell'account |
| Missioni, ricevute, XP, proposte e audit | Conservati; nessuna promessa di cancellazione/anonimizzazione generale |
| File prove privati | Policy TTL e cleanup di file/chunk/orfani, root private senza symlink; fault/retry e isolamento dell'altro utente verificati |
| Backup/restore | Solo connessioni loopback e database di test; restore nuovo, mai in-place; diario esterno necessario prima della readiness |

La policy privacy reale, tempi di conservazione, basi e responsabilità restano
soggetti al gate umano. Nessuna conformità privacy generale è attestata.

Rollback: sospendere scritture/accessi e usare una copia coerente con diario e
prove. I downgrade delle migrazioni 10 e 15 possono essere legittimamente
rifiutati dopo uso delle funzionalità; il rifiuto di down15 è provato atomico.
Non forzare downgrade o alterare chiavi storiche per aggirare i vincoli. La
rehearsal del restore non autorizza un restore automatico su dati operativi.

Gli snapshot storici 0–5 in `/tmp/sentinelle-baseline-20261013` sono andati persi
al reset runtime: risultati conservati nel registro come evidenze storiche,
originali non recuperati. I checkpoint 6–8 sono persistiti localmente e non sono
backup del database. Il checkout sorgente è rimasto invariato; le prove SQLite
sorgenti non sono trasferite a PostgreSQL. Nessun push, merge o deploy eseguito.

## Gate e responsabilità da acquisire

| Gate | Ruolo/input necessario | Evidenza approvata |
|---|---|---|
| Provider/hosting/budget | Proprietario del progetto e responsabile infrastruttura | Mancante |
| Email/storage | Responsabile operativo e risorse approvate | Mancante |
| Autenticazione forte operatori | Responsabile sicurezza e operatori | Mancante |
| Revisione/conflitti | Responsabili missioni, verifica ed esiti; capacità e sostituti | Mancante |
| Protocollo/fonti reali | Responsabile pilot e pubblicazione esiti | Mancante |
| Informativa/retention/cancellazione | Responsabile dei dati e referenti privacy | Mancante |
| Backup/restore operativo | Responsabile infrastruttura; gestione cancellazioni dopo restore | Mancante |
| Incidenti/rollback | Referenti reperibili e procedura provata sull'ambiente scelto | Mancante |
| Platea/target/avvio | Proprietario e responsabile pilot, decisione esplicita | Mancante |

Registrare nominativi, riferimenti e approvazioni nel sistema privato competente,
senza introdurre credenziali o dati personali in questo report. Nessun ruolo è
assegnato dalla preparazione del documento.

## Misurazione pilot da definire prima dell'avvio

Funnel scoperta/accettazione/invio/validazione, tempi per passo e di revisione,
abbandoni e motivi di rifiuto, carico operatori, copertura di luoghi/finestre,
ritorno al secondo controllo e feedback sulla comprensione degli esiti.
Target, platea, finestre di misurazione e referenti restano **da approvare**;
il volume grezzo delle segnalazioni non è una misura sufficiente di successo.

Decisione finale: **candidato locale verificato; NO-GO al pilot reale**, gate esterni aperti.

## Correzione successiva — avvio browser del 16 ottobre 2026

La prova interattiva sulla home ha riprodotto una pagina bianca: il collegamento
di `LeagueContinuityRepository` leggeva `FantasyManager.season` prima del
caricamento API, quando la proiezione era ancora nulla. Il callback ora restituisce
null finché `hasData` è falso; le notifiche successive aggiornano la stagione.
Un nuovo test del grafo reale copre avvio con richiesta pendente e caricamento
fallito. Suite Flutter corrente: **467 PASS** con fixture PostgreSQL isolate;
analyze: 462 info, zero warning/error. Build release e rendering della home in
Chrome verificati, backend locale pronto. Log in
`.sentinelle-local/browser-fix-{tests,analyze}.log`.

La build corretta è in `.sentinelle-local/browser-build`, servita su loopback
9105. Non contiene il precedente CANDIDATE_ID: questa modifica è successiva al
freeze e non è attestata dal digest sopra. Le build e i checkpoint della fase 8
restano conservati come evidenze dello stato precedente. Nessun deploy.
