# Migliora Paese backend

Backend HTTP per il pilot e per la migrazione progressiva dai repository mock
Flutter.

## Requisiti e comandi

Richiede Node.js 24 o superiore e non usa dipendenze npm.

    npm test
    npm run dev

Il server usa HOST (default 127.0.0.1) e PORT (default 8787). Il log di avvio
viene emesso soltanto dopo che la socket è in ascolto.

    HOST=127.0.0.1 PORT=8787 npm run dev
    curl http://127.0.0.1:8787/health

In sviluppo lo store resta in-memory se `DATABASE_PATH` non e' impostato. Per
provare la persistenza SQLite:

    DATABASE_PATH=./data/pilot.sqlite npm run dev

In produzione sono obbligatori sia `DATABASE_PATH` sia
`ANON_IDENTITY_SECRET`. Il secret deve contenere almeno 32 byte e deve essere
fornito dal secret manager dell'ambiente, non committato nel repository.

    DATABASE_PATH=/data/pilot.sqlite \
    ANON_IDENTITY_SECRET=<secret-di-almeno-32-byte> \
    npm start

## Identificativi Comune

Gli ID API canonici sono slug, attualmente bologna e castel-bolognese. Per
compatibilità sono accettati anche comune:Bologna e
comune:Castel Bolognese.

## CORS locale

Le origin HTTP(S) loopback (localhost, 127.0.0.1, ::1, con qualsiasi porta)
sono abilitate. Origin aggiuntive possono essere elencate esplicitamente in
CORS_ALLOWED_ORIGINS, separate da virgola; il wildcard non è accettato. Le
risposte CORS consentono credenziali perché l'identità anonima usa cookie.

    CORS_ALLOWED_ORIGINS=https://pilot.example npm run dev

## Persistenza e identita' anonima

La versione 0.4 usa `node:sqlite`, disponibile in Node 24, con foreign key,
WAL, timeout sui lock e migrazione iniziale registrata in
`schema_migrations`. Lo stato del pilot e' salvato atomicamente in uno snapshot
JSON versionato; la normalizzazione in tabelle di dominio resta un passo
successivo alla validazione del pilot.

Alla prima richiesta API il server emette `mp_anon`, un identificativo opaco
firmato HMAC con `HttpOnly`, `SameSite=Lax`, `Path=/` e durata annuale. In
produzione viene aggiunto `Secure`. I valori `userId` eventualmente inviati da
client precedenti sono ignorati. Il client Flutter Web abilita le richieste con
credenziali; staging deve servire app e API nello stesso sito per evitare le
limitazioni dei cookie di terze parti.

## Moderazione e limiti del pilot

- Il body JSON deve essere un oggetto ed è limitato a 64 KiB.
- Titolo e descrizione sono limitati rispettivamente a 120 e 1000 caratteri.
- Le motivazioni sono enum note, uniche e al massimo due.
- Le proposte con link, email, numeri di telefono, caratteri di controllo o
  termini abusivi noti vengono rifiutate con `content_rejected`.
- Ogni identità anonima può inviare al massimo tre proposte in un'ora.
- La moderazione automatica e' un primo filtro: il pilot richiede ancora una
  coda operativa e un responsabile umano per escalation e ricorsi.

L'identità anonima non sostituisce autenticazione forte o protezioni anti-abuso
distribuite. Prima di esposizione pubblica servono proxy trusted, rate limiting
condiviso, backup, retention/privacy policy e osservabilita'.

Il contratto eseguibile è descritto in openapi.yaml.

## Contratto di gioco

La versione 0.3 ha aggiunto letture coerenti con `GameRepository` per:

- esiti salvati del turno (`/v1/turns/{turnId}/prediction-results`);
- reputazione corrente e storico comunale;
- insight aggregato, storico e critico per problema.

La risoluzione accetta soltanto la scelta già salvata per lo stesso utente e
salva un esito `correct`, `partial` o `wrong` per la coppia turno/utente.
Reputazione e riepilogo civico sono calcolati dagli esiti salvati. Gli insight
aggregano le previsioni di tutti gli utenti del turno; non sono ancora applicate
soglie minime di anonimizzazione, che fanno parte del lavoro privacy prima del
pilot pubblico.
