# Classificazione della PR34

Sorgente f3f4d4f8001f972c1dee598ff6519ba2008bb25e, base1fad162; destinazione main6bc103d preceduta dalla33. Revisione iniziale indipendente avviata; agente interrotto dal limite account. Le conclusioni seguenti derivano dalla lettura effettiva dei file con git show e devono essere rivalutate sul diff portato.

| Gruppo | Decisione | Motivo/adattamento |
|---|---|---|
| Token/tema/componenti core | trasferibile con review chiamanti | Fantasy ha chiamanti aggiuntivi; gate sezione rappresentativa prima propagazione |
| local_data_store, bozza, intento, ricevuta, controller/dettaglio/similarità | trasferibile con test | Persistenza atomica locale/epoch utile; scope deve includere modalità fantasy/legacy |
| API repository/session store | riscrivere |34 usa bearer in local storage, UUID, userId client, header Idempotency-Key, endpoint submissions/own;33 usa cookie HttpOnly, scope opaco, chiave/body e next-problem-submissions |
| ApiClient | adattare | Preservare deleteJson e cookie factory main; importare errori strutturati/RetryAfter. Escludere retry automatico |
| AppPrefs | adattare | Conservare chiavi/formato stato e ricevute fantasy; reset33 e barriera epoch locale |
| AppDependencies/app/router | adattare | Preservare repository API game/fantasy, Manager default, entrambi router e pilot; coordinatore sopra route |
| Comune catalog | adattare | Alias e convalida route senza cambiare silenziosamente Comune; preservare mapping main |
| CivicLoopStore/mock game | adattare | Persistenza demo utile; controllare regole e invarianti, non importare nuova economia |
| Legacy/proposte UI | trasferibile con adattamento | Preservare accessi e dati API, filtri/ritorno/pilot; ricevuta non è approvazione |
| Profile/onboarding/boot | adattare | Reset server già presente main; onboarding rispetta Manager e pilot |
| Test34 | trasferibile selettivamente | Harness main conserva fantasy; sostituire test bearer/contract34 con33; eseguire sul port |
| Backend34 modularizzato | escluso | Baseline divergente; eventuali gap implementati nel server main con OpenAPI/test |
| PostgreSQL/migrazioni/dependency pg/workflow/CLI review | escluso | Piano esplicito; SQLite e admin main preservati |
| Design preview e documenti di accettazione34 | escluso | Non funzionalità runtime del port; prove34 non attestano port |

## Rischi accertati

- ApiClient34 reinvia automaticamente su errore di trasporto con chiave in header: incompatibile con recupero manuale del piano.
- AppPrefs34 non ha stato/ricevute fantasy; copia diretta perderebbe interfacce e reset fantasy.
- Session store34 memorizza bearer e richiede UUID/capabilities booleani; totalmente incompatibile con33.
- Router34 ha solo modalità legacy, niente pilot; non copiarlo interamente.
- Backend33 manca Retry-After nella risposta429; controllare ricerca location/civic/reference prima implementazione.
- PR33: race reset con body sospeso riprodotta su previsione e enrollment; corretta separatamente nella33 prima port.

Non sono ancora verificati UI reale, browser, hardware o qualità formativa del port. Nessuna accettazione automatica dedotta dal numero di test.
