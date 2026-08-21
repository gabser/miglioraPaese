# Migliora Paese backend

Backend HTTP locale per il pilot e per la migrazione progressiva dai repository
mock Flutter.

## Requisiti e comandi

Richiede Node.js 24 o superiore e non usa dipendenze npm.

    npm test
    npm run dev

Il server usa HOST (default 127.0.0.1) e PORT (default 8787). Il log di avvio
viene emesso soltanto dopo che la socket è in ascolto.

    HOST=127.0.0.1 PORT=8787 npm run dev
    curl http://127.0.0.1:8787/health

## Identificativi Comune

Gli ID API canonici sono slug, attualmente bologna e castel-bolognese. Per
compatibilità sono accettati anche comune:Bologna e
comune:Castel Bolognese.

## CORS locale

Le origin HTTP(S) loopback (localhost, 127.0.0.1, ::1, con qualsiasi porta)
sono abilitate. Origin aggiuntive possono essere elencate esplicitamente in
CORS_ALLOWED_ORIGINS, separate da virgola; il wildcard non è accettato.

    CORS_ALLOWED_ORIGINS=https://pilot.example npm run dev

## Limiti e sicurezza dello scaffold

- Il body JSON deve essere un oggetto ed è limitato a 64 KiB.
- Titolo e descrizione sono limitati rispettivamente a 120 e 1000 caratteri.
- Le motivazioni sono enum note, uniche e al massimo due.
- userId è fornito e controllato dal client. Serve soltanto a separare viste e
  voti nel pilot locale: non è autenticazione e può essere falsificato.
- Lo store è in-memory e viene perso a ogni riavvio.

Questo backend non è deployabile in pubblico così com'è: mancano autenticazione,
persistenza, moderazione, rate limiting e garanzie operative. HOST=0.0.0.0 è
configurabile per test in container, ma non rende lo scaffold production-ready.

Il contratto eseguibile è descritto in openapi.yaml.

## Contratto di gioco

La versione 0.3 aggiunge letture coerenti con `GameRepository` per:

- esiti salvati del turno (`/v1/turns/{turnId}/prediction-results`);
- reputazione corrente e storico comunale;
- insight aggregato, storico e critico per problema.

La risoluzione accetta soltanto la scelta già salvata per lo stesso utente e
salva un esito `correct`, `partial` o `wrong` per la coppia turno/utente.
Reputazione e riepilogo civico sono calcolati dagli esiti salvati. Gli insight
aggregano le previsioni in-memory di tutti gli utenti del turno; non sono ancora
applicate soglie minime di anonimizzazione, che fanno parte del successivo
lavoro su identità, moderazione e persistenza.
