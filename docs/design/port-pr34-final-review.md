# Review tecnica conclusiva del port PR34

Base main dopo PR33:066533acdfbba8628edc40cedc0e31226591348a. Checkout isolato, Manager civico predefinito, SQLite e regole/persistenza fantasy conservati. Nessuna importazione PostgreSQL o migrazioni alternative. Provenienza applicativa e hash albero in evidence/provenance.json.

## Review indipendenti

- Agente contract_review: contratto cookie/scope opaco, idempotenza e ricevuta immutabile, lookup dopo commit incerto, reset/epoch/storage failure, guardie revoca11 route, ricerca luogo e Retry-After. Nessun rilievo. Eseguiti90/90 backend e44/44 test Flutter pertinenti.
- Agente independent_review: routing/UI/evidenze. Rilievo P2: ingresso e uscita dal form cancellavano filtri e origine; corretto con push/pop, aggiornamento lista e fallback deep link. Rilievo P3: etichetta ritorno ricevuta non corrispondeva alla destinazione; corretta. Review successiva conferma chiusura dei rilievi e delle lacune di evidenza ricevuta/dettaglio/incerto/vuoto.
- Ulteriore correzione dell’orchestratore, rivista separatamente senza rilievi: lista proposte vuota non implica Comune in attivazione. Badge e copy neutrali, regressione a390px/testo200% e asserzione browser.

## Verifiche riproducibili

307 test Flutter completi;90 backend. Analisi153 info, zero errori/warning. OpenAPI3.1 valida,46 avvisi documentali già registrati. Quattro build web release nel manifest evidence/next-step-builds.json. CI finale e link registrati nel corpo PR35 sullo SHA documentale conclusivo.

La verifica browser usa Chrome, Flutter legacy API locale e SQLite del backend. Avviare backend su127.0.0.1:8787 con allowedOrigins http://127.0.0.1:8899, pilot tuglie e moderazione attiva; compilare il profilo legacy-api del manifest, servire build/web su8899. Con Playwright disponibile eseguire:

```sh
REVIEW_REVISION=$(git rev-parse HEAD) node tools/verify_proposal_browser.mjs
```

Per un’installazione esterna di Playwright impostare PLAYWRIGHT_MODULE al percorso del suo index.mjs. APP_URL, API_BASE_URL ed EVIDENCE_DIR permettono di scegliere server e cartella locali. Il test inserisce proposte sintetiche nel database di sviluppo; usa contesti browser separati. Registra quattro recuperi UI (risposta persa/malformata,390/1440) e due fixture di lista vuota. Le ricevute recuperate sono confrontate integralmente con quelle del POST committato; lookup, scope, cookie e unicità sono verificati separatamente.

## Limiti e stato di accettazione

Review tecnica favorevole entro lo scope controllato. Nessuna certificazione di accessibilità, intuibilità, divertimento o uso su hardware fisico. I test con persone sono rinviati dall’utente; il dubbio sulla comprensione del gioco resta aperto. Mobile significa responsive web nelle prove attuali; progetti Android/iOS nativi assenti. Restano PR35 draft e PR34 aperta secondo il piano. Nessun deploy API o pilot pubblico.


Aggiornamento disponibilità: rilevato un iPhone wireless tramite Flutter; l’utente rinvia esplicitamente anche il collaudo hardware. Disponibilità del dispositivo non equivale a prova eseguita. Preview locale fermata, nessun lancio Safari sul telefono.
