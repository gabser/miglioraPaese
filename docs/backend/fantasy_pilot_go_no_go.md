# Fanta Comune — evidenze tecniche e decisione pilot

Verifica locale del 9 ottobre 2026. **Decisione operativa: NO-GO** finché i
responsabili non completano e approvano i gate sotto. Questo documento non
autorizza pubblicazione, dati reali o contatti con partecipanti.
Il [runbook](../pilot_runbook.md) resta il riferimento operativo.

## Perimetro implementato

Nove incrementi locali su branch codex/, con repository mock preservato e
API fantasy additive rispetto al legacy. SQLite single-instance, identità
anonime firmate e fonti sintetiche, anche quando marcate verified.
Il calendario demo persistito parte l'8 ottobre 2026, dura otto settimane e
non viene rinnovato automaticamente. Nessuna importazione dei risultati locali.

Leghe private per stagione e Comune; pseudonimi generati, minimo tre
competitori, ingresso competitivo prima del primo lock della stagione, poi
spettatori. Inviti con 256 bit casuali, scadenza, revoca e soli hash a riposo.
La rotazione invalida i precedenti. Cinque tentativi/minuto per sessione:
questo limite non impedisce identità anonime multiple.

La sessione è legata al browser. Nessun account recuperabile, login tra
dispositivi o modello anti-abuso per competizioni pubbliche.
Il candidato API supporta Flutter Web con cookie same-site; i test Dart
usano un cookie jar isolato per esercitare le stesse sessioni HTTP.

## Evidenze locali riproducibili

Da root, con Flutter 3.44.2/Dart 3.12 e Node 24 nel PATH:

    dart format --set-exit-if-changed .
    flutter analyze --no-fatal-infos --no-fatal-warnings
    flutter test
    npm --prefix services/backend test
    npm --prefix services/backend run rehearse-fantasy

La rehearsal non accetta URL o database di destinazione. Crea un database
temporaneo e un server loopback su porta casuale, usa fixture sintetiche,
prova tre sessioni, penalità, lock, pubblicazione autorizzata, riflessione e
classifica 29/28/20. Esegue backup, verifica schema/foreign keys e restore su
un'altra copia, confrontando tutte le righe personali e delle leghe. Controlla
cancellazione proprietario, isolamento degli altri, rollback su errore, backup
originale invariato, readiness degradata, crescita dei 5xx e assenza di token,
identità, motivazioni o fonti nei log e nelle metriche. Elimina le copie al termine.

I test Flutter includono il percorso reale contro Node/SQLite, riavvio,
risposta persa al trasferimento e alla creazione lega, errore/offline senza
fallback, revisione obsoleta, orologio client errato e reset remoto prima di
quello locale. UI e creazione lega sono verificate a 390, 1024 e 1440 px.
Le 48 fixture di punteggio sono condivise fra le vere funzioni Dart e Node.

Tre build release locali verificate: fantasy mock, fantasy API e legacy API.
Esiti numerici nel [registro locale](fantasy_local_evidence.json) e nello
[stato degli incrementi](fantasy_implementation_status.md).
CI GitHub, build Docker e prove su provider non sono state eseguite da questa
sessione. Docker non è disponibile sulla macchina; il job di build immagine
rimane nei workflow Backend e Build staging candidates.

## Candidati e smoke

Il workflow manuale Build staging candidates richiede profilo, URL HTTPS
same-site e Comune. Produce soltanto artefatti, con nome che include profilo,
Comune e commit, e un manifest staging-candidate.json privo di credenziali.
Non pubblica né autorizza il pilot.

| Profilo | Fantasy UI | Fantasy source | Game / Next problems |
|---|---|---|---|
| legacy-api | disattivata | mock, inutilizzata | api / api |
| fantasy-api | attivata | api | api / api |
| GitHub Pages | attivata | mock esplicito | mock / mock |

Lo smoke usa esclusivamente GET, non iscrive sessioni, non congela snapshot e
non legge reveal o classifiche che possono riconciliare risultati. Verifica
health/readiness/metriche e, nel profilo fantasy, catalogo, stagione e calendario
coerenti con tempo server. Supporta un prefisso API sullo stesso sito.

Solo dopo autorizzazione dell'ambiente protetto:

    STAGING_PROFILE=fantasy-api \
    STAGING_BASE_URL=https://pilot.example.test/api/ \
    PILOT_MUNICIPALITY_ID=tuglie \
    npm --prefix services/backend run smoke

legacy-api resta il default dello smoke per compatibilità. La rehearsal
mutante resta limitata alle fixture, senza target pilot configurabile.

## Osservabilità e allarmi

Metriche con metodo, nome route statico, status e versione del pacchetto;
nessun ID Comune/giornata/carta/lega/sessione o token come label.
I log tecnici non contengono path, query, cookie, body, previsioni, motivazioni,
fonti o pseudonimi. Le route amministrative non registrano il bearer token.

src/pilot_signals.js e i test dimostrano localmente il rilevamento di readiness
ripetutamente fallita, incremento 5xx, disco sotto il 20% o ignoto, backup non
verificato da 24 ore e scraping assente. Risposte reali 500/503 e contatori
verificati con fault injection sulla copia temporanea. Il provider deve
collegare i segnali ai collector, applicare le finestre temporali del runbook
e provare notifiche ed escalation. Nessun servizio di monitoraggio installato.

## Scheda go/no-go operativa

I campi mancanti non vengono considerati approvati dalla CI o dai test locali.

| Gate obbligatorio | Evidenza locale | Evidenza operativa / stato |
|---|---|---|
| Accordo con Comune e finalità | Slug tecnico Tuglie, isolamento testato | Accordo e referente mancanti — aperto |
| Product owner e responsabile incidenti | Procedura nel runbook | Nomi, reperibilità e approvazione mancanti — aperto |
| Provider, regione e SQLite single-instance | Migrazioni 1–6, restart e readiness | Provider e limiti approvati mancanti — aperto |
| Privacy, retention e cancellazione | Reset transazionale e isolamento testati | Titolare/RPD, informativa e retention approvate mancanti — aperto |
| Platea protetta e sessioni | Leghe private, autorizzazioni e soglia tre | Ingress e platea concordata mancanti — aperto |
| HTTPS same-site e origin esatta | Cookie/CORS predisposti, URL candidato validato | TLS, proxy e browser remoto non provati — aperto |
| Segreti separati | File secret e log privati predisposti/testati | Secret manager, permessi e rotazione provider non provati — aperto |
| Backup/restore sul provider | Backup/restore completo su fixture locale | Backup cifrato, restore e tempi provider non provati — aperto |
| Alert e dashboard | Fault injection 500/503 e segnali locali verdi | Collector, canali, escalation e disco provider non provati — aperto |
| Moderatori e fonti | Pubblicazione controllata, immutabilità e audit demo | Titolare/sostituto formati, fonti reali approvate mancanti — aperto |
| Definitività e regole leghe | Versione 1, pseudonimi, late join e archiviazione testati | Ratifica delle politiche ancora da registrare — aperto |
| Smoke remoto e CI del candidato | Smoke locale non mutante e suite verdi | Workflow GitHub e smoke protetto non eseguiti — aperto |
| Rollback operativo | Procedura conservativa documentata | Esercitazione provider e approvazione mancanti — aperto |

Date del pilot, platea e riferimenti delle approvazioni da registrare nel
sistema privato dell'organizzazione. Nessun segreto o dato personale nei report.

## Cancellazione, conservazione e rollback

DELETE session elimina squadra, bozze, snapshot, mercato, ricevute, reveal,
riflessioni, membership e tentativi personali. Le pubblicazioni autorizzate
restano separate. Se il proprietario cancella la sessione, la lega è archiviata,
il legame del proprietario e la chiave di creazione vengono rimossi, gli inviti
revocati e gli altri giocatori conservati. L'uscita dalla lega archivia e revoca;
la ricevuta di creazione resta legata alla sessione ancora iscritta per impedire
che un vecchio retry crei una nuova lega. DELETE session rimuove anche quel legame.

Non è attiva una retention automatica: durate, archivi e rotazione dei backup
richiedono policy approvata prima di dati reali. Un backup precedente conserva
lo stato antecedente alla cancellazione; il ripristino richiede una procedura
approvata che consideri le cancellazioni intervenute. La rehearsal preserva
appositamente il backup originale e non modifica database live.

Il rollback chiude accesso e scritture preservando il database. Nessun downgrade
distruttivo, restore automatico, cambio fonti o riapertura di gare pubbliche.
Riapertura subordinata a readiness, verifica dati, smoke e decisione autorizzata.
