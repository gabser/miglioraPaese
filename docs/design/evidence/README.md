# Evidenze del port PR34

Tutte le immagini sono catture reali del browser Chrome headless locale. Ogni profilo usa contesti browser isolati; viewport320/390/720/899/900/1120/1440 per Squadra mock e390/1440 per le aree principali di tutti i profili. I manifest registrano URL e pageerror. Il testo200% e le quattro aree Manager sono coperti anche dalla suite widget manager_responsive_test.dart.

build-profiles.json contiene i quattro comandi Flutter release e gli exit code. final-mock-builds.json, final-legacy-api-build.json e final-legacy-home-builds.json registrano le ricompilazioni dopo l’ultima correzione della sidebar. API_BASE_URL punta a un server locale effimero con SQLite, non a un servizio pubblicato. Le catture section-* sono la sezione rappresentativa iniziale, mentre fantasy-* e legacy-* documentano il controllo conclusivo.

controlled-* usa Playwright clock.install8 ottobre2026 UTC, conferma formazione, clock.fastForward52 ore più1 secondo, ritorno persistito a Giornata e avanzamento5 giorni. Le immagini mostrano conferma, blocco, fine osservazione e punteggio. Queste prove sono mock e non attestano il clock remoto API.

browser-api-recovery.json registra un POST reale dal browser, cookie HttpOnly, reload e lookup della medesima ricevuta con una sola proposta. Usa fetch e non simula perdita di rete dentro la UI. api_proposal_recovery_test.dart copre separatamente perdita/malformazione risposta nel coordinatore reale, ricostruzione e restart SQLite.

Riproduzione tecnica: usare Flutter3.44.2 e Node24; flutter pub get --enforce-lockfile, dart format --set-exit-if-changed ., flutter analyze --no-fatal-infos, flutter test; in services/backend eseguire npm test. Per i quattro profili usare i comandi di build-profiles.json. La CI Backend verifica anche docker build.

provenance.json identifica le fonti e l'hash dei file applicativi verificati. Nessuna prova con persone o dispositivo fisico è stata eseguita. Le immagini e i controlli automatici non certificano accessibilità, intuibilità o divertimento. Il port resta in draft e PR34 resta aperta.
