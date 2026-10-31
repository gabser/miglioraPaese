# Sentinelle — deploy con Supabase e Resend Free

Aggiornato il 16 ottobre 2026. Stato: architettura target scelta, implementazione e deploy da eseguire.
Budget: 0 € di canone; nessuna attivazione di piani a pagamento.

Questa revisione sostituisce la proposta Render Free: l’attesa di circa un minuto
al risveglio è stata rifiutata dall’utente. Tecnologia e architettura backend
possono cambiare. Le scelte concordate sono Supabase e Resend Free; Cloudflare
Pages resta la proposta per ospitare Flutter web.

Le evidenze locali Sentinelle restano valide nel loro ambito storico: non
attestano il porting cloud. Il pilot resta NO-GO fino al collaudo del nuovo
candidato e ai gate del [dossier](sentinelle_operational_dossier.md).
Nessun account, dominio o deploy è stato creato da questo aggiornamento.

## 1. Prodotti e responsabilità

| Funzione | Prodotto target | Stato |
|---|---|---|
| App web | Flutter su Cloudflare Pages Free | Hosting proposto; build da configurare |
| Identità e sessioni | Supabase Auth | Scelto; sostituisce l’account custom locale |
| Accesso senza password | Codice email OTP Supabase Auth | Flusso previsto, da integrare nel client |
| Consegna email | Resend Free via SMTP di Supabase Auth | Scelto; dominio verificato ancora da acquisire |
| Regole privilegiate | Supabase Edge Functions e transazioni PostgreSQL | Target da validare con prova tecnica |
| Dati applicativi | Supabase PostgreSQL | Migrazioni e porting da verificare |
| Fotografie | Supabase Storage, bucket privato | Upload, accessi e retention da implementare |
| Operatori | Supabase Auth con secondo fattore TOTP e ruoli applicativi | Target da verificare end-to-end |
| Backup e diario cancellazioni | Copie cifrate indipendenti e persistenza durevole | Disegno/prodotto operativo ancora da definire |

Vedere [architettura e diagramma prodotti](sentinelle_cloud_architecture.md).
Non sono previsti Render, Firebase Auth, Firebase Functions o un processo Node
sempre acceso nel target. Non è obbligatorio riscrivere tutta la logica: riusare
regole e test compatibili, adattando runtime e confini di persistenza.

## 2. Evidenze ufficiali e limiti

Verifica documentale: 16 ottobre 2026. Ricontrollare prezzi e condizioni prima dell’attivazione.

| Evidenza | Conseguenza operativa | Fonte |
|---|---|---|
| Supabase Free: 500 MB database, 1 GB storage, 50.000 MAU, 5 GB egress e 5 GB cached egress | Dimensionare foto, retention e traffico | [Prezzi](https://supabase.com/pricing) |
| Free: pausa dopo una settimana inattiva, niente backup automatici inclusi | Preparare riattivazione e backup indipendenti | [Prezzi](https://supabase.com/pricing) |
| Edge Functions Free: 500.000 invocazioni | Monitorare anche retry e invocazioni operative | [Prezzi funzioni](https://supabase.com/docs/guides/functions/pricing) |
| Funzioni: 256 MB RAM, 2 s CPU/richiesta, durata worker Free 150 s | Misurare operazioni pesanti e normalizzazione foto; nessuna garanzia di latenza | [Limiti](https://supabase.com/docs/guides/functions/limits) |
| Auth supporta codice email e link magico | Configurare il template per mostrare il codice; il comportamento predefinito manda un link | [Passwordless](https://supabase.com/docs/guides/auth/auth-email-passwordless) |
| SMTP incluso: solo indirizzi del team e attualmente 2 messaggi/ora | Non usarlo per i partecipanti | [SMTP](https://supabase.com/docs/guides/auth/auth-smtp) |
| SMTP personalizzato: limite iniziale Supabase 30 messaggi/ora modificabile | Coordinare rate limit Auth con quota Resend | [SMTP](https://supabase.com/docs/guides/auth/auth-smtp) |
| Resend Free: 3.000 email/mese, 100/giorno | Contare OTP e reinvii; nessuna crescita senza controllo | [Prezzi](https://resend.com/pricing) |
| Resend richiede dominio verificato per invio reale | Servono dominio/sottodominio e accesso DNS | [Guida Supabase](https://resend.com/docs/send-with-supabase-smtp) |
| Dominio test resend.dev: invii solo al proprio indirizzo | Non è una soluzione per il pilot | [Restrizione](https://resend.com/docs/knowledge-base/403-error-resend-dev-domain) |
| Pages: asset singoli entro 25 MiB | Verificare build Flutter prima dell’upload | [Limiti Pages](https://developers.cloudflare.com/pages/platform/limits/) |

Supabase Free non richiede carta; i piani gratuiti vanno mantenuti senza upgrade.
Il requisito di carta nel percorso Resend effettivamente disponibile va controllato
alla creazione: la documentazione consultata conferma piano Free e quote, non
costituisce una prova di registrazione del nostro account senza carta.
Fonte Supabase: [Free senza carta](https://supabase.com/blog/observability-for-every-supabase-project-with-grafana-cloud).

Un dominio non viene fornito gratuitamente da Resend: se non ne abbiamo uno,
serve un sottodominio offerto da un partner oppure un acquisto esplicitamente
approvato. Il sito può usare il sottodominio Pages gratuito.

## 3. Registro operativo

Compilare: responsabile e sostituto, account/progetti, regioni effettive,
URL frontend e funzioni, dominio mittente, commit/digest nuovo candidato,
Comune e platea approvati, data collaudo, destinazioni backup, responsabile
incidenti e decisione di avvio. Segreti e nominativi restano nel sistema privato.

Obiettivo iniziale proposto: 20–50 partecipanti su invito, RPO 24 ore e RTO
1 giorno. Sono ipotesi da approvare e provare, non prestazioni del provider.

## 4. Backlog prima del deploy

| ID | Lavoro | Prova di completamento |
|---|---|---|
| C1 | Prova tecnica Edge Functions/PostgreSQL | Lettura, prenotazione concorrente e accredito XP entro limiti runtime; nessun doppio effetto |
| C2 | Porting Auth | Login OTP, refresh, logout, recupero e revoca; collegamento ospite senza duplicare squadre/XP |
| C3 | Identità e ruoli | Mappa auth.users → profilo applicativo; RLS/privilegi minimi; operatori e Comune determinati server-side |
| C4 | Funzioni e transazioni | Regole fantasy, missioni, revisione ed esiti preservate; idempotenza e controllo revisioni verificati |
| C5 | Storage | Upload riprendibile, normalizzazione, accesso autore/operatori e cleanup; nessun bucket pubblico |
| C6 | Migrazioni | Compatibilità schema e manifesto; vecchi ID collegati ai nuovi UUID Auth; nessuna perdita storico |
| C7 | Dati personali e restore | Chiusura account coordinata Auth/DB/Storage; conservazioni approvate; diario indipendente e replay cancellazioni |
| C8 | Job operativi | Cleanup, scadenze e calendario recuperabili; scheduler/esecutore da scegliere e verificare nelle quote |
| C9 | Client e diagnostica | Configurazione cloud esplicita, gestione errori, flussi invito/missione ripresi dopo login; candidato riconoscibile |
| C10 | Operatività | Backup, allarmi, MFA operatori, contenuti reali, fonti e responsabilità verificati |

Il server attuale richiede email simulate e storage locale sintetico. Non
pubblicarlo con quei flag credendo di ottenere il target Supabase. Gli script
backup/restore attuali sono limitati a loopback/database di test: non rimuovere
i controlli per usarli nel cloud. Il runbook precedente per Render e i relativi
flag non descrivono più la distribuzione scelta.

Prova prestazionale proposta: prima operazione dopo inattività entro 3 s,
successive entro 1 s; registrare p50/p95 e casi peggiori, rete e regione.
Misurare anche login e transazioni, non solo un endpoint vuoto. L’invio/ricezione
email ha una latenza distinta da misurare. Se il target non regge, rivalutare
runtime e carichi prima di un porting esteso.

## 5. Preparare Supabase

1. Creare progetto Free in regione europea disponibile; registrare regione e limiti effettivi.
2. Preparare prima lo schema su database di test con lo stesso ambiente; verificare le migrazioni esistenti sul servizio gestito.
3. Definire identità e privilegi C2/C3/C6 prima di esporre tabelle. RLS attiva e accesso anonimo negato dove richiesto; le policy devono essere provate anche via Data API.
4. Per migrazioni e advisory lock usare connessione diretta o session pooler, non transaction pooler; TLS con certificato verificato.
5. Configurare sito e redirect Auth con origini esplicite; creazione utenti limitata al pilot mediante controllo server verificato, non solo un pulsante nascosto.
6. Creare bucket privato con limiti coerenti e policy C5. Chiavi amministrative solo nei segreti server.
7. Distribuire le funzioni solo dopo C1–C10. Fissare nomi, route, deploy commands e versioni nella fase implementativa: oggi non esiste ancora un pacchetto Edge distribuibile da attestare.
8. Pubblicare dati/protocolli approvati; mai seed sintetici sul pilot.

Per le operazioni che modificano punti, disponibilità o esiti usare funzioni
privilegiate con autenticazione/autorizzazione esplicita e una transazione DB
per ogni invariante atomica. Non suddividere una transazione in chiamate HTTP
indipendenti. Una chiave service-role può aggirare RLS: verificare ruoli e
ownership nel percorso privilegiato, non affidarsi alla sola policy client.

## 6. Collegare Resend a Supabase Auth

1. Creare account Resend Free; controllare condizioni della registrazione e non attivare upgrade o consumo extra.
2. Aggiungere dominio/sottodominio disponibile e pubblicare i record DNS richiesti; attendere verifica.
3. Creare una chiave di invio limitata al dominio, conservarla nel sistema segreti.
4. In Supabase Authentication → Email/SMTP abilitare SMTP personalizzato:

   | Campo | Valore |
   |---|---|
   | Host | smtp.resend.com |
   | Porta | 465 |
   | Username | resend |
   | Password | Chiave API Resend, mai nel client |
   | Mittente | Indirizzo del dominio verificato |
   | Nome | Migliora Paese |

5. Nel template di login mostrare `{{ .Token }}` per il codice; verificare che il client esegua verifica OTP e non scambio di link.
6. Impostare scadenza proposta di 10 minuti e reinvio non prima di 60 secondi, verificando gli effetti sugli altri link email. Supabase usa una configurazione di scadenza condivisa per più flussi.
7. Coordinare limiti orari, giornalieri e mensili; 100/giorno è una quota globale, non per partecipante. Configurare CAPTCHA e verificare gli effettivi controlli antiabuso.
8. Disabilitare tracking di apertura/click per email di autenticazione; testare consegna Gmail/Outlook, spam, ritardi, riuso e quota esaurita. Un invio SMTP riuscito non prova la ricezione.
9. Conservare evidenze senza OTP, token o indirizzi personali nei log pubblici.

Supabase genera/verifica il codice; Resend lo consegna. Non serve un adapter
OTP custom nel backend applicativo né una chiamata SMTP dal browser.

## 7. Preparare e pubblicare Flutter web

1. Implementare `supabase_flutter`, sessioni e configurazione C9; adeguare repository e contratto API al target.
2. Le variabili attuali `API_BASE_URL` e flag Sentinelle appartengono al backend precedente: documentare i nuovi nomi solo quando implementati.
3. URL progetto e chiave pubblicabile possono stare nel build; service-role, credenziali DB e chiave Resend devono restare server-side. La chiave pubblica richiede policy corrette, non rende i dati privati da sola.
4. Verificare toolchain, test mirati e suite finali locali con PostgreSQL di test; build release identificata dal nuovo candidato. Non riutilizzare il digest della fase 8 dopo modifiche.
5. Creare progetto Cloudflare Pages Free Direct Upload; caricare build con base path `/` e asset entro i limiti. Impostare redirect/route SPA e CORS delle funzioni per l’origine esatta.
6. Verificare login, refresh su URL interno, invito e ripresa missione. Conservare artefatto e manifesto per rollback.

Il workflow GitHub Pages esistente resta una demo mock: non è il deploy Supabase.

## 8. Collaudo e avvio

- [ ] Candidato nuovo identificato; prove locali precedenti distinte dalle nuove.
- [ ] Login OTP, sessione persistente, revoca e guest linking senza duplicazioni.
- [ ] Missione → prenotazione → foto → invio → revisione → 10 XP verificato.
- [ ] Concorrenza, retry/risposta persa e isolamento utenti/Comuni verificati.
- [ ] Ruoli, MFA operatori e divieto autovalidazione applicati server-side.
- [ ] Esiti, ricorso, rettifica, classifiche, leghe e inbox preservati.
- [ ] Performance dopo inattività misurate sul pilot, quote sotto controllo.
- [ ] Backup DB e oggetti, recupero Auth e chiavi documentati; restore isolato con cancellazioni successive al backup provato.
- [ ] Cancellazione account coordinata e retention corrispondono alla policy approvata.
- [ ] Scadenze, calendario e cleanup eseguiti anche senza browser aperto.
- [ ] Mobile web, tastiera, testo ingrandito e comprensione provati da persone.
- [ ] Dominio Resend verificato e ricezione email provata; limiti esauriti gestiti senza perdere bozze.
- [ ] Referenti, fonti, informativa, platea e decisione di avvio approvati nel dossier.

Non usare il verde dei test storici per dichiarare completato il porting.

## 9. Esercizio e guasti

Ogni giorno di raccolta: verificare backup cifrati, invii email, errori e code.
Due volte a settimana: controllare quote e billing. Proposta soglie: avviso al
70%, limitazione nuove adesioni/upload al 90%, preservando le operazioni già
avviate. Un esaurimento quota non autorizza upgrade o cancellazioni anticipate.

Pausa Supabase dopo inattività: verificare dashboard e riattivazione prima di
una sessione pubblica; non promettere disponibilità continua. Il cold start di
una funzione e la sospensione dell’intero progetto sono eventi distinti.

Rollback: sospendere scritture, verificare compatibilità codice/schema e usare
artefatto precedente solo se compatibile. Restore su ambiente isolato con
allineamento Auth/DB/Storage e diario cancellazioni. Nessun migrate:down alla
cieca. Alla chiusura del pilot applicare policy dati e revocare segreti prima
di eliminare risorse.

## 10. Decisioni aperte

Dominio mittente e disponibilità DNS; verifica percorso Resend senza carta;
prova C1 per runtime/foto/transazioni; strategia revoca e mappatura account;
prodotto per diario/backup; scheduler; regioni e responsabilità; gate privacy
e pilot. Firebase Auth resta alternativa non scelta, non un secondo sistema
attivo. Render Free è escluso dalla soluzione target per il requisito di latenza.
