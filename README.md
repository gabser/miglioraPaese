# Migliora Paese · Fanta Comune

[![Flutter](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/flutter.yml)
[![Backend](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml/badge.svg)](https://github.com/gabser/miglioraPaese/actions/workflows/backend.yml)
[![License: GPL-3.0-only](https://img.shields.io/badge/license-GPL--3.0--only-blue.svg)](LICENSE)

Migliora Paese è un prototipo Flutter web di gioco civico locale. L'app, il cui
nome corrente nell'interfaccia è **Fanta Comune**, permette di scegliere un
Comune, osservare temi urbani in forma di carte, fare previsioni leggere e
confrontare esiti e percezioni aggregate.

> **Stato: prototipo v0.1.0.** La demo pubblica usa dati mock locali, non invia
> segnalazioni ufficiali e non certifica la realtà. Il backend pilot dispone di
> persistenza, identità anonima, moderazione operatore e asset di staging, ma
> non è ancora autorizzato né distribuito per contributi pubblici o dati reali.

## Funzionalità

- modalità **Manager civico** attivabile via feature flag, con stagione di 8
  giornate, rosa da 8 carte, 5 titolari, capitano e budget da 100 crediti;
- mercato non esclusivo, previsioni, reveal verificabile, leghe private,
  classifica comunale e punteggio cooperativo separato;
- onboarding leggero e scelta del Comune;
- shell responsive per mobile e desktop;
- turno di gioco con previsioni, motivazioni e confidence;
- tabellone, insight, reputazione e classifica mock;
- flusso per proporre e votare i temi del prossimo turno;
- stati operativi per Comuni nuovi o senza dati;
- privacy e reset della demo locale;
- pilot API opt-in per proposte, gioco, esiti, reputazione e insight.

## Stack e struttura

- Flutter 3.44.2 / Dart 3.12;
- go_router, flutter_bloc, provider e shared_preferences;
- design system locale in **lib/core/theme** e **lib/core/widgets**;
- API HTTP Node.js 24 con SQLite nativo in **services/backend**;
- contratto OpenAPI e test Node integrati;
- CI Flutter/backend e deploy della demo mock su GitHub Pages.

~~~text
.github/                    workflow e configurazione GitHub
docs/                       piani di design, backend e rilascio
lib/app/                    bootstrap, dipendenze e router
lib/core/                   config, rete, tema, copy e preferenze
lib/features/               dominio, repository, logica e UI
services/backend/           scaffold API locale e OpenAPI
test/                       test unit, repository, Cubit e widget
web/                        shell PWA Flutter
~~~

## Avvio rapido

Il repository versiona solo la piattaforma web. Usa [FVM](https://fvm.app/) o
un'installazione Flutter esattamente alla versione indicata in **.fvmrc**.

~~~bash
fvm flutter pub get
fvm flutter run -d chrome
~~~

La build standard abilita il nuovo flusso Manager civico con dati mock
persistenti. Per riaprire temporaneamente il prototipo precedente:

~~~bash
fvm flutter run -d chrome --dart-define=FANTASY_MODE_ENABLED=false
~~~

Le carte, le fonti e gli esiti inclusi nel seed sono esclusivamente demo e
restano etichettati come tali nell'interfaccia.

### Regole della demo Manager civico

- Le date della giornata vengono salvate sul dispositivo. Alla scadenza si
  bloccano rosa, formazione, capitano, previsioni e motivazioni, anche dopo
  un riavvio o un ritorno dell'app in primo piano.
- Solo una formazione valida e confermata al blocco genera punti. Ogni cambio
  di titolari, capitano o mercato richiede una nuova conferma; una previsione
  mancante assegna zero punti previsione.
- I primi due trasferimenti di ogni giornata sono gratuiti; ogni successivo
  costa 4 punti, dichiarati prima della conferma. La penalità viene sottratta
  una sola volta dal totale personale, che può essere negativo.
- Una fonte non disponibile sospende l'acquisto. Le carte con fonte in attesa
  sono acquistabili ma non generano punti prima di un esito verificato.
- Il reveal usa formazione, capitano e previsioni congelati per quella giornata:
  osservazione 4/1/0, previsione 4/2/0. Il capitano moltiplica per 1,5, con
  arrotondamento all'intero più vicino.
- Dopo il reveal, la prima riflessione confermata su una carta titolare vale
  un punto base, soggetto al moltiplicatore del capitano. Il bonus non si ripete
  dopo visite, modifiche o riavvii. La motivazione pre-partita non assegna bonus.
- Gli esiti precedenti senza uno snapshot storico restano esempi e non assegnano
  punti personali. Il punteggio cooperativo e le classifiche demo sono separati
  dal riepilogo personale della giornata.

Lo stato locale viene migrato al formato v2 conservando i dati validi; i dati
incompatibili vengono ripristinati con un messaggio. Gli errori di salvataggio
mostrano un'azione per riprovare. La demo locale non offre garanzie anti-manomissione
fra dispositivi: un pilot competitivo richiederà un orologio e uno stato server.
La build staging API imposta esplicitamente `FANTASY_MODE_ENABLED=false`.

Senza FVM:

~~~bash
flutter pub get
flutter run -d chrome
~~~

## Pilot API locale

La demo e i default restano mock. `NextProblemsRepository` e
`GameRepository` possono usare il backend soltanto quando vengono attivati
esplicitamente e in modo indipendente.

Avvia il backend locale in-memory:

~~~bash
cd services/backend
npm test
npm run dev
~~~

Per mantenere i dati tra i riavvii, imposta
`DATABASE_PATH=./data/pilot.sqlite`. Il backend assegna l'identità anonima con
un cookie firmato `HttpOnly`; `userId` non viene più accettato come autorità dal
client.

Per il pilot locale di Tuglie, con database dedicato e soli contenuti
sintetici, avvia il backend su loopback:

~~~bash
cd services/backend
npm run dev:tuglie
~~~

Il comando rifiuta `NODE_ENV=production`, usa esclusivamente
`127.0.0.1:8787` e accetta il frontend da `http://localhost:7357`. I segreti
predefiniti sono deliberatamente locali e non devono essere riutilizzati in
uno staging remoto.

Poi avvia Flutter con:

~~~bash
fvm flutter run -d chrome --web-port=7357 \
  --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
  --dart-define=GAME_DATA_SOURCE=api \
  --dart-define=API_BASE_URL=http://localhost:8787 \
  --dart-define=PILOT_MUNICIPALITY_ID=tuglie
~~~

In locale usa `localhost` sia per Flutter Web sia per l'API: il cookie
`SameSite=Lax` rimane così nello stesso sito anche se le due applicazioni usano
porte diverse.

`ApiGameRepository` usa HTTP per attivazione, riepilogo, turno, problemi,
previsioni, risultati, reputazione, insight e classifica. In questa fase le
domande di riflessione restano generate localmente; il segnale che modifica lo
stato di un problema è rifiutato esplicitamente finché manca il relativo
endpoint. Il lookup diretto di un problema usa la cache popolata dall'elenco
del Comune.

La modalità API supporta al momento gli ID canonici **bologna**,
**castel-bolognese** e **tuglie**, con mapping esplicito dagli ID Flutter
corrispondenti. I seed di Tuglie sono marcati come scenari dimostrativi e non
descrivono segnalazioni o condizioni reali.
Qualunque altro Comune produce un errore controllato e non ricade
silenziosamente sui dati di un'altra città.

Il filtro automatico rifiuta contatti personali, link, caratteri di controllo
e linguaggio abusivo noto, e limita gli invii ripetuti. In modalità pilot i voti
non promuovono contenuti: serve una decisione dell'operatore tramite endpoint
amministrativo protetto. Gli insight restano oscurati sotto la soglia minima di
partecipazione configurata.

Nella build API, il controllo dati nella pagina Privacy cancella voti,
previsioni ed esiti associati alla sessione anonima, anonimizza il collegamento
delle proposte pubblicate e scade il cookie server-side.

## Quality gate

~~~bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release
~~~

Per il backend:

~~~bash
cd services/backend
npm test
docker build --tag migliorapaese/backend:local .
~~~

La CI esegue gli stessi gate con Flutter 3.44.2 e Node.js 24.

## Demo web

Il workflow **.github/workflows/pages.yml** costruisce esclusivamente la demo
mock con base path **/miglioraPaese/**. Dopo aver selezionato **GitHub Actions**
come sorgente Pages, l'URL previsto è:

<https://gabser.github.io/miglioraPaese/>

Il workflow Pages non avvia e non espone **services/backend**.

## Documentazione

- [Piano di rilascio pubblico](docs/public_release_plan.md)
- [Fondazione backend](docs/backend/backend_foundation_plan.md)
- [Runbook staging e pilot](docs/pilot_runbook.md)
- [Piano UX/UI](docs/design/ux_ui_alignment_plan.md)
- [Reference statica del mockup](docs/design/fanta-comune-standalone.html)

## Limiti noti

- la demo Pages resta esclusivamente mock; SQLite è opt-in nel backend pilot;
- identità anonima e moderazione operatore non equivalgono ad autenticazione o
  protezione anti-abuso distribuita;
- nessun canale ufficiale con i Comuni;
- il repository di gioco HTTP è opt-in e due capability restano progressive:
  reflection locale e mutazione del segnale non supportata;
- il lancio richiede ancora selezione e accordo con un Comune, provider,
  privacy/retention, rate limiting distribuito, alert e prova di ripristino sul
  provider scelto.

## Contribuire e sicurezza

Leggi [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
e [SECURITY.md](SECURITY.md). Non inserire segnalazioni civiche reali, dati
personali o credenziali in issue, fixture, log e screenshot.

## Licenza e rilascio

Il codice sorgente è distribuito con licenza
[GPL-3.0-only](LICENSE). La provenienza dichiarata, le condizioni e i limiti
degli asset grafici sono riportati in [ASSETS.md](ASSETS.md).

La cronologia privata con metadati personali e operativi è conservata
nell'archivio separato `miglioraPaese-private`; questo repository pubblico nasce
da uno snapshot bonificato, come descritto nel
[piano di rilascio](docs/public_release_plan.md).

## Fanta Comune su API sintetiche

Il default e GitHub Pages restano mock. Per Flutter Web locale avviare
npm --prefix services/backend run dev:tuglie, poi:

    flutter run -d chrome --web-hostname localhost --web-port 7357 \
      --dart-define=FANTASY_MODE_ENABLED=true \
      --dart-define=FANTASY_DATA_SOURCE=api \
      --dart-define=GAME_DATA_SOURCE=api \
      --dart-define=NEXT_PROBLEMS_DATA_SOURCE=api \
      --dart-define=PILOT_MUNICIPALITY_ID=tuglie \
      --dart-define=API_BASE_URL=http://localhost:8787

Usare localhost per entrambi gli origin così i cookie restano same-site.
Le squadre remote non importano risultati demo. Leghe private, pseudonimi server,
almeno tre competitori; sessione legata al browser. Il calendario sintetico
persistito non si rinnova: per provare tutta la giornata senza attendere le date
usare npm --prefix services/backend run rehearse-fantasy.

[Stato dei nove incrementi](docs/backend/fantasy_implementation_status.md) ·
[Evidenze e gate pilot ancora aperti](docs/backend/fantasy_pilot_go_no_go.md).
Nessun deploy o raccolta di dati reali autorizzato dai test locali.
