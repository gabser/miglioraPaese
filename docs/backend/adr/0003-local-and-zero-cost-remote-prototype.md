# ADR-0003: runtime locale e prototipo remoto opzionale a costo zero

- Stato: `accepted`.
- Data: 14 luglio 2026.
- Accettato dal decision owner: 14 luglio 2026.
- Work package: `UC-00.6`.
- Decision owner: proprietario del prodotto/repository.
- Provider remoto: non selezionato.
- Esecuzione: non avviata; richiede un comando separato del proprietario.
- Relazione: sostituisce la bozza non approvata del 13 luglio 2026 che
  proponeva direttamente un hosting pilot a pagamento.

## Contesto

Il repository e' oggi un prototipo Flutter web. La demo GitHub Pages usa dati
mock locali e non espone il backend. Il piano di productization deve poter
proseguire in locale, con test e PostgreSQL riproducibili, senza rendere un
account cloud una dipendenza dello sviluppo.

Il proprietario non ha ancora scelto dove eseguire il prototipo fuori dal
computer locale e vuole valutare una soluzione gratuita. Non e' quindi
approvata la precedente ipotesi DigitalOcean, AWS e Better Stack, ne' un
budget ricorrente. Free tier, quote e condizioni cambiano frequentemente: la
scelta di un provider oggi sarebbe una decisione implicita e fragile.

Occorre distinguere tre ambienti:

- `local`: baseline autorevole per sviluppo, test e dimostrazione full-stack;
- `remote-prototype`: deploy remoto opzionale e gratuito, ad accesso ristretto
  oppure pubblico in sola lettura, con soli dati applicativi sintetici e
  sacrificabili;
- `staging` e `pilot`: ambienti persistenti futuri con dati e responsabilita'
  operative reali, fuori dal perimetro di questo ADR.

Il `remote-prototype` non e' staging, produzione o pilot e non puo' essere
rinominato o promosso silenziosamente a uno di questi ambienti.

## Decisione

Adottare i seguenti confini:

1. l'ambiente locale resta sufficiente e obbligatorio per eseguire `UC-01`--
   `UC-08`;
2. un prototipo remoto e' opzionale e viene creato soltanto se una soluzione a
   costo ricorrente zero supera il PoC definito in questo ADR;
3. questo ADR non sceglie un provider, una regione, un database gestito o un
   servizio di osservabilita';
4. il prototipo usa artefatti e configurazione provider-neutral e, quando
   espone il backend reale, mantiene Flutter e API sulla stessa origin HTTPS;
5. il prototipo remoto tratta esclusivamente fixture e identita' sintetiche,
   puo' essere azzerato in qualsiasi momento e non assume obblighi verso un
   Comune o utenti reali;
6. le scritture remote sono disabilitate per default; vengono abilitate solo
   per tester autorizzati e input predefiniti, mai come raccolta pubblica;
7. nessun costo, account, metodo di pagamento o risorsa esterna viene
   autorizzato dall'accettazione di questo ADR;
8. prima di `UC-09` serve un nuovo ADR, separato e accettato dal proprietario,
   per hosting persistente di staging e pilot.

Se nessun provider gratuito rispetta tutti i gate, non viene creato alcun
ambiente remoto. Restare local-only e' un esito valido e non blocca i work
package che precedono `UC-09`.

## Baseline locale

La baseline locale deve essere riproducibile senza servizi esterni:

- Node.js 24, dipendenze fissate dal lockfile e comandi documentati;
- Flutter in modalita' mock per demo veloci e in modalita' API per gli scenari
  full-stack;
- `MemoryStore` per unit test e demo mock;
- PostgreSQL reale locale o effimero per migrazioni, repository, vincoli e test
  di integrazione da `UC-02`;
- backend in bind loopback per default; `0.0.0.0` e' ammesso soltanto dentro un
  container o un ambiente remoto esplicitamente selezionato;
- configurazione e secret fuori dal repository;
- nessuna dipendenza della CI dal prototipo remoto.

Tunnel pubblici, port forwarding del router o esposizione della macchina
personale non fanno parte della soluzione. Un URL remoto deve provenire da un
provider valutato e da una risorsa isolata e revocabile.

## Packaging e portabilita'

Il lavoro applicativo non viene adattato a una specifica free tier:

- una build riproducibile associa commit, lockfile, versione Node.js e digest
  dell'artefatto;
- il target preferito e' un'immagine OCI privata; e' accettabile anche una
  build dal repository privato se il provider non richiede di pubblicare
  sorgenti o layer;
- rendere pubblici repository, package o immagini resta subordinato a
  `docs/public_release_plan.md`;
- configurazione runtime standard: `PORT`, `HOST`, `DATABASE_URL`, origin,
  limiti e riferimenti secret;
- domain, application e repository ports non importano SDK del provider;
- le migrazioni restano un comando o job separato dallo start applicativo e
  usano una credenziale distinta quando il provider lo consente;
- frontend e API usano la stessa origin per mantenere verificabili cookie,
  CSRF e sessioni di ADR-0002;
- `/health`, `/ready`, shutdown e smoke funzionano allo stesso modo in locale e
  nell'eventuale ambiente remoto.

Una soluzione gratuita che richiede un cambio irreversibile del dominio,
l'esposizione di secret nel client o migrazioni automatiche allo start non e'
idonea. Il requisito free non giustifica una deroga agli ADR precedenti.

## Gate di costo zero

Per questo ADR, `free` significa:

- costo ricorrente effettivo pari a `0` per compute, database, storage,
  registry, log e traffico previsto dal prototipo;
- nessun trial che si converte automaticamente in un piano a pagamento;
- nessun autoscaling, add-on o upgrade automatico;
- nessuna possibilita' di addebito senza una nuova approvazione esplicita del
  proprietario;
- assenza di metodo di pagamento oppure hard cap provider-side pari a zero con
  sospensione del servizio al raggiungimento della quota;
- quote, data di scadenza, sleep, cold start, limiti database, egress e policy
  di cancellazione documentati al momento della selezione.

Se il provider non offre un hard stop verificabile e puo' generare overage, la
risorsa non rientra in questo ADR. Un eventuale account o piano con rischio di
addebito richiede un'altra decisione proprietaria prima della creazione.

Termini e quote vengono riconfermati prima del provisioning, prima di ogni
deploy e almeno ogni 30 giorni mentre la risorsa esiste. L'evidenza tariffaria
piu' vecchia di 30 giorni non e' valida. Il prototipo ha una scadenza operativa
massima di 30 giorni: senza nuova verifica e approvazione viene spento e
eliminato. Se la free tier cambia, si torna local-only; non viene effettuato un
upgrade automatico.

## Confine dei dati

Per `dati sintetici` si intendono i dati applicativi di dominio. Un tester reale
genera comunque metadati di connessione presso il provider, come IP, orario e
User-Agent: accesso, DPA, regione e retention di questi metadati vengono
valutati nel PoC, minimizzati e non copiati nei log applicativi.

Il prototipo remoto accetta soltanto:

- Comuni, problemi, proposte, voti e previsioni generati come fixture;
- principal e operatori sintetici senza relazione con persone reali;
- secret usa-e-getta e separati da qualunque futuro ambiente pilot;
- database che puo' essere azzerato senza perdita di informazione reale.

Sono vietati:

- testo, feedback o identificativi raccolti da cittadini reali;
- credenziali, recovery code o account operatore di persone reali;
- dump di staging/pilot o dati derivati non anonimizzati;
- deletion journal, chiavi HMAC o backup appartenenti al futuro pilot;
- presentazione del prototipo come canale attivo di un Comune.

Il profilo remoto usa `REMOTE_WRITE_MODE=disabled|fixture-only`, con default
`disabled`. In modalita' pubblica tutte le route mutanti e la creazione di
sessioni sono disabilitate e il database serve soltanto fixture in lettura. La
modalita' `fixture-only` richiede access control provider-side o applicativo per
tester autorizzati e rifiuta free text, identificativi esterni e payload non
presenti nel catalogo fixture. Se il provider gratuito non offre un accesso
ristretto verificabile, il remoto resta pubblico in sola lettura.

L'interfaccia remota mostra in modo permanente:

> PROTOTIPO - DATI SINTETICI - IL CONTENUTO PUO' ESSERE AZZERATO

La configurazione dichiara `DATA_CLASSIFICATION=synthetic`; un valore assente o
diverso impedisce l'avvio del profilo remote-prototype. Moderazione reale,
bootstrap di operatori e inviti sono disabilitati. I relativi flussi possono
essere provati soltanto con fixture controllate e accesso ristretto.

Il deletion journal di ADR-0002 viene implementato e testato tramite adapter e
failure injection in locale/CI. Il prototipo gratuito non costituisce evidenza
operativa sufficiente per dati reali o restore del pilot.

## Affidabilita' dichiarata

Per il prototipo remoto sono accettati sleep, cold start, reset, quote,
indisponibilita' e perdita totale dei dati sintetici. Non vengono promessi:

- SLA o SLO;
- alta disponibilita' o failover;
- RPO o RTO;
- backup, PITR o restore operativo;
- retention minima di log;
- reperibilita' o incident response verso utenti esterni.

Health, readiness, smoke, migrazioni e teardown restano test funzionali utili,
ma non trasformano la free tier in staging. Qualunque documentazione o UI che
usa i termini `staging`, `pilot`, `produzione`, `affidabile` o `persistente`
per questo ambiente fallisce il gate documentale.

## Selezione futura del provider gratuito

La selezione avviene con una micro-sessione separata e non puo' basarsi sul
ricordo di una free tier. Prima si crea una shortlist documentale; prima di
creare risorse il proprietario approva esplicitamente il candidato esatto.

Per ogni candidato si registrano almeno:

1. provider, piano, regione disponibile e data della verifica;
2. termini free, scadenza, quote, sleep/cold start e condizione di sospensione;
3. assenza di addebiti automatici e modalita' di eliminazione dell'account;
4. accesso a repository o immagine privata senza pubblicazione implicita;
5. supporto a Node.js 24 o OCI, HTTPS, `PORT`, secret e same-origin;
6. disponibilita' e limiti di PostgreSQL oppure motivo esplicito per cui il
   remoto resta solo una demo disposable;
7. isolamento del database, accesso non pubblico e reset completo;
8. log disponibili, loro retention e procedura di redazione;
9. DPA, data location e subprocessori applicabili anche ai dati sintetici;
10. procedura provata di teardown di app, database, storage, log e secret.

Il PoC usa soltanto fixture e prova build, deploy, access control o sola lettura
pubblica, rifiuto del free text, cold start, `/health`, `/ready`, smoke sessione
ristretta, migrazione separata, reset e teardown. Registra prova di costo zero
prima e dopo il test e programma verifica/teardown entro 30 giorni. Se una
capability manca, il candidato viene scartato o il prototipo resta local-only;
non si abilita un servizio pagato per completare il PoC.

## Decisione futura obbligatoria per staging e pilot

Questo ADR non soddisfa la dipendenza hosting di `UC-09`. Prima di quel work
package un nuovo ADR deve definire e ottenere approvazione almeno per:

- provider, regioni, costi e budget autorizzato;
- account, IAM, MFA, secret, DPA, subprocessori e data location;
- risorse separate di staging e pilot;
- PostgreSQL persistente, migrazioni e capacity;
- backup, restore, deletion journal e recovery delle chiavi;
- log, metriche, alert e retention;
- HA o rischio accettato, SLA, RPO, RTO e stop criteria;
- deploy, rollback, runbook, incident response e teardown.

La precedente analisi DigitalOcean/AWS/Better Stack puo' essere rivalutata
come una delle alternative, ma non e' approvata o preferita da questo ADR.
Nessun prototipo gratuito viene promosso direttamente: staging e pilot nascono
da risorse e credenziali nuove dopo la decisione proprietaria.

## Alternative considerate

### Solo locale

E' la baseline e resta sempre valida. Riduce esposizione e dipendenze, ma non
offre un URL condivisibile. Viene scelta automaticamente se nessun provider
free supera i gate.

### Prototipo remoto gratuito

E' l'opzione accettata ma condizionale. Offre un URL condivisibile e prova il
packaging in un ambiente esterno, accettando sleep, reset e nessuna garanzia.

### Hosting pilot a pagamento immediato

La bozza DigitalOcean/AWS/Better Stack e le alternative Render, Cloud Run,
Railway e VPS sono rinviate. Sceglierle ora introdurrebbe un provider e un
budget che il proprietario non ha ancora approvato.

### GitHub Pages

Resta la demo Flutter mock. Non ospita il backend persistente e non diventa
remote-prototype API senza un nuovo disegno esplicito.

### Macchina personale o tunnel

Respinto perche' espone rete e macchina di sviluppo, lega la disponibilita' a
un dispositivo personale e rende opachi secret, accessi e teardown.

## Conseguenze

### Positive

- Nessun costo o provider diventa prerequisito dello sviluppo.
- Il prototipo locale resta sempre riproducibile.
- La ricerca della free tier non indebolisce dominio, contratto o migrazioni.
- Un remoto eventuale e' chiaramente separato dal futuro pilot.
- La decisione economica e operativa viene presa quando i requisiti sono piu'
  concreti e i prezzi possono essere verificati.

### Negative

- Non esiste ancora un URL backend remoto garantito.
- Una free tier puo' dormire, cambiare termini o scomparire.
- Il prototipo remoto non dimostra backup, restore, disponibilita' o gestione
  del pilot.
- Servira' un nuovo ADR e una nuova approvazione prima di `UC-09`.
- Mantenere visibile la distinzione tra demo, prototipo e pilot richiede gate
  documentali e UI.

## Quality gate del prototipo

Prima di dichiarare utilizzabile un remote-prototype devono essere verdi:

1. test backend, Flutter e integrazione pertinenti in locale;
2. build riproducibile con Node.js 24, lockfile, commit e digest;
3. nessuna dipendenza della CI dal provider remoto;
4. nessun SDK provider in domain, application o repository ports;
5. stesso artefatto o stessa build verificata per Flutter e API same-origin;
6. migrazione separata dallo start e failure fail-closed;
7. `/health`, `/ready`, cold start, reset e smoke con fixture;
8. `DATA_CLASSIFICATION=synthetic` obbligatorio e banner permanente;
9. `REMOTE_WRITE_MODE` fail-closed, route mutanti disabilitate in pubblico e
   rifiuto di free text/input esterno in modalita' fixture-only;
10. access control provato per ogni sessione interattiva e test da origin non
    autorizzata;
11. nessun dato applicativo, account, recovery code o secret reale;
12. metadati di connessione minimizzati e coperti dalla verifica DPA/retention;
13. secret fuori da repository, log e bundle Flutter;
14. evidenza di piano gratuito, quota, hard stop e costo zero non piu' vecchia
    di 30 giorni e riconfermata prima del deploy;
15. nessun metodo di pagamento oppure hard cap provider-side a zero;
16. scadenza operativa e teardown entro 30 giorni provati per compute,
    database, storage, log e credenziali;
17. nessun artefatto pubblico senza il gate di rilascio pubblico;
18. nessuna documentazione che presenti l'ambiente come staging o pilot.

Se uno qualunque dei gate 1--18 non e' dimostrabile, il remoto non viene
creato; l'esito resta local-only. Il quality gate locale resta comunque valido
per proseguire fino a `UC-08`.

## Condizioni di accettazione

L'accettazione del proprietario del 14 luglio 2026 copre:

- locale come baseline autorevole e indipendente dal cloud;
- remote-prototype opzionale, con provider ancora aperto;
- costo ricorrente zero, nessun upgrade automatico e nessun rischio di
  addebito senza una nuova approvazione;
- soli dati applicativi sintetici, sacrificabili e chiaramente etichettati,
  con metadati di connessione minimizzati;
- remoto pubblico in sola lettura oppure scritture fixture-only dietro accesso
  ristretto e verificato;
- assenza di SLA, HA, RPO, RTO, backup e retention garantiti;
- divieto di promuovere il prototipo a staging o pilot;
- PoC e creazione di qualunque risorsa subordinati ad approvazione specifica;
- ritorno local-only se nessuna soluzione gratuita supera tutti i gate;
- riconferma gratuita prima di ogni deploy e teardown entro 30 giorni senza
  nuova verifica/approvazione;
- nuovo ADR hosting, separato e accettato, obbligatorio prima di `UC-09`;
- nessun account, metodo di pagamento, spesa o risorsa autorizzato da questo
  ADR.

## Riferimenti

- `docs/public_release_plan.md`
- `docs/backend/backend_productization_plan.md`
- `docs/backend/adr/0001-postgresql-access-and-migrations.md`
- `docs/backend/adr/0002-anonymous-identity-sessions-and-authorization.md`
- [Open Container Initiative image specification](https://github.com/opencontainers/image-spec)
- [The Twelve-Factor App: config](https://12factor.net/config)
- [PostgreSQL documentation](https://www.postgresql.org/docs/)
