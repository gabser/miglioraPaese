# EVO-001 — Economia del gioco e criptovalute

- Creazione e aggiornamento: 16 ottobre 2026
- Stato: discovery
- Priorità: alta, richiesta esplicita dell'utente
- Responsabile: da assegnare
- Destinazione: main, per incrementi
- Issue/PR: non create
- Autorizzazione corrente: organizzazione e pianificazione; nessun lancio monetario.

## Obiettivo

Progettare un collegamento tra economia del gioco e criptovalute che possa
aumentare ricavi e valore per gli utenti. Valutare ricavi incrementali, margine,
retention e costi operativi. L'utente ha chiarito di voler creare un token proprio:
questo è ora l'obiettivo di prodotto, mentre rete, diritti economici e lancio
restano da definire. La sostenibilità è un criterio da dimostrare, non una garanzia.

Vedi [selezione tecnologica ed economia del token](EVO-001-token-design.md).

## Evidenze e ipotesi

Nella checkout esaminata il budget fantasy iniziale è 100; il saldo deriva dal
costo della rosa. Riferimenti: `lib/features/fantasy/domain/fantasy_models.dart`,
`lib/features/fantasy/domain/fantasy_game.dart`,
`services/backend/src/application/fantasy/teams.js` e `market.js`.
Alcuni di questi file sono modifiche locali non ancora integrate: verificare
la baseline del tronco prima dell'implementazione.

Non sono disponibili in questo studio metriche validate di utenti attivi,
conversione, retention, domanda crypto o disponibilità a pagare. I prezzi e
gli scenari discussi in chat sono ipotesi, non previsioni o budget approvati.

## Modelli da confrontare

| Modello | Collegamento ai crediti | Domanda da risolvere |
| --- | --- | --- |
| A — Pagamenti crypto | Crypto acquistano servizi o crediti commerciali interni | Aggiunge clienti o sostituisce pagamenti esistenti? |
| B — Ricompense finanziate | Budget sponsor finanzia ricompense separate | Il beneficio supera premi, abusi e costi di gestione? |
| C — Token proprietario | Token trasferibile con utilità nel prodotto | Quale domanda persistente esiste oltre la speculazione? |
| D — Conversione dei crediti | Conversione mono/bidirezionale, libera o limitata | Quali crediti, a quale cambio, con quali riserve e diritti? |
| Controllo — Economia interna | Servizi acquistabili senza blockchain | Qual è l'incremento attribuibile alla crypto? |

Per D distinguere budget fantasy, XP e nuovi crediti commerciali. Confrontare
esplicitamente cambio fisso, variabile e assenza di rimborso. Non presumere
equivalenza tra credito, euro e token. Un eventuale cambio garantito richiede
un modello di passività, liquidità e rimborso verificato.

Ipotesi iniziale consigliata: separare budget competitivo, reputazione e saldo
commerciale. Qualunque monetizzazione dei primi due richiede una decisione
dedicata sull'equità competitiva e sugli incentivi ai contributi civici.

## Piano e dipendenze

Gli ID seguenti sono attività locali, tutte da fare. Le fasi indicano ordine,
non scadenze promesse; assegnare responsabili e stime prima dello sviluppo.

| ID | Fase/attività | Dipende da | Risultato e criterio di accettazione |
| --- | --- | --- | --- |
| CR-01 | Definire economia e diritti | — | Glossario di crediti/XP/token; chi compra, spende, trasferisce e riscatta; flussi A–D confrontati |
| CR-02 | Validare domanda e ricavi | CR-01 | Dati di baseline o loro assenza esplicita; interviste/esperimenti; scenari e costi con assunzioni tracciate |
| CR-03 | Verificare perimetro legale/fiscale | CR-01 | Matrice per modello e mercato: classificazione, obblighi, premi, minori, privacy, fiscalità e questioni irrisolte |
| CR-04 | Selezionare modello del pilot | CR-02, CR-03 | Decisione motivata; budget, canale, pubblico e soglie di stop; alternative conservate |
| CR-05 | Progettare ledger e contratti | CR-04 | ADR, schema dati e proposta API; invarianti contabili, autorizzazioni e piano migrazioni revisionati |
| CR-06 | Prototipo provider sandbox | CR-05 | Pagamento/conferma/rimborso simulati; nessun denaro reale; confronto costi e limiti provider |
| CR-07 | Integrazione e verifiche | CR-06 | Test end-to-end, antifrode, riconciliazione e recupero; regressione del budget fantasy assente |
| CR-08 | Pilot controllato | CR-07 | Prerequisiti operativi e normativi chiusi; metriche raccolte entro budget e durata definiti |
| CR-09 | Valutazione e rollout | CR-08 | Incremento netto confrontato con controllo; decisione estendere/correggere/fermare documentata |
| CR-T1 | Studio token e conversione | CR-01 | Utilità, supply, emissione, distribuzione, trasferibilità, liquidità e scenari di stress descritti |
| CR-T2 | Decisione su prototipo token | CR-T1, CR-02, CR-03 | Scelta chain/custodia motivata e costo totale; eventuale prototipo solo testnet, senza valore reale |

CR-T1 è parte del percorso principale e procede insieme alla discovery
commerciale e normativa. CR-T2 è un prerequisito aggiuntivo di CR-05; audit
smart contract e gestione chiavi sono necessari prima di CR-08. Il solo
pagamento in una crypto esistente non soddisfa il nuovo obiettivo di prodotto.

## Architettura candidata, da confermare in CR-05

- Ledger server autorevole, separato da budget fantasy e XP; importi interi
  con unità/precisione esplicite e movimenti immutabili con rettifiche.
- Ordini, tentativi di pagamento, accrediti e rimborsi con stati distinti.
- Idempotenza, verifica delle firme dei webhook e protezione dai replay.
- Riconciliazione tra provider, ledger e saldo visualizzato.
- Adapter provider isolato; segreti esclusivamente lato server.
- Flag disabilitati di default e separazione tra sandbox e produzione.
- Per blockchain: finalità, riorganizzazioni, rete/asset errati e transazioni
  duplicate trattati esplicitamente; nessun dato civico personale on-chain.
- Per token proprio: ruoli amministrativi, gestione chiavi, audit indipendente,
  emissione/riscatto, arresto d'emergenza e responsabilità operativa documentati.

Non introdurre ora tabelle, endpoint, SDK, wallet o flag vuoti. Le scelte
tecniche seguono i diritti economici scelti, senza fissare prematuramente una chain.

## Verifiche richieste prima del pilot

Accredito esattamente una volta anche dopo retry e riavvio; webhook falsi o
duplicati rifiutati; pagamento scaduto/sottopagato non accreditato impropriamente;
rimborso e storno riconciliati; accesso al saldo altrui negato; saldo concorrente
coerente; limiti e antifrode verificati; recupero da indisponibilità del provider.
Per token aggiungere test delle invarianti di supply e prove di recupero chiavi.

Disabilitare nuovi ordini non elimina pagamenti pendenti o passività. Il piano
di stop deve mantenere riconciliazione, supporto e gestione rimborsi.

## Metriche e sostenibilità

Misurare conversione, ricavo netto per utente, retention, quota di utenti crypto
nuovi, sostituzione dei pagamenti tradizionali, commissioni, premi, frodi,
rimborsi, supporto e costo di acquisizione. Separare volume transato, incassi,
ricavi riconosciuti e margine; il valore dei token in tesoreria non è fatturato.

Formula di decisione: margine incrementale attribuibile al modello meno costi
incrementali di sviluppo, compliance, provider e operazioni. Confrontare scenari
prudente/base/ottimista, stress di prelievi e perdita di sponsor. Per un cambio
garantito modellare riserve e copertura delle passività.

Soglie numeriche, campione, durata e budget sono da definire in CR-04 prima del
pilot. Stop immediato a discrepanze contabili non spiegate, vulnerabilità sulle
chiavi o superamento del budget; riesame commerciale se il margine incrementale
non raggiunge la soglia concordata.

## Decisioni

| ID | Data | Tema | Stato |
| --- | --- | --- | --- |
| D-01 | 2026-10-16 | Crypto come iniziativa prioritaria nella roadmap | Confermata dall'utente |
| D-02 | 2026-10-16 | Documentazione e sviluppo incrementale destinati a main | Impostazione del piano |
| D-03 | 2026-10-16 | Separazione budget fantasy / XP / saldo commerciale | Proposta da valutare in CR-01 |
| D-04 | 2026-10-16 | Creare un token proprio | Obiettivo confermato dall’utente; utilità e conversione aperte |
| D-05 | 2026-10-16 | Chain, asset, custodia e provider | Aperta, dopo scelta del modello |
| D-06 | 2026-10-16 | Budget, responsabili e date | Aperti |

## Fonti di partenza

Riferimenti consultati nello studio del 16 ottobre 2026; da verificare nuovamente
in CR-03 sul modello concreto. Non costituiscono un parere legale o approvazione.

- [Banca d'Italia — soggetti MiCAR](https://www.bancaditalia.it/compiti/vigilanza/accesso-mercato/soggetti-mercato-cripto-attivita/)
- [ESMA — MiCA articolo 4](https://www.esma.europa.eu/publications-and-data/interactive-single-rulebook/mica/article-4-offers-public-crypto-assets-other)
- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play — contenuti blockchain](https://support.google.com/googleplay/android-developer/answer/13607354?hl=en)
- [MIMIT — manifestazioni a premio](https://www.mimit.gov.it/it/mercato-e-consumatori/concorrenza-e-commercio/manifestazioni-a-premio)

## Prossima azione

CR-01: produrre la matrice dei diritti economici A–D e scegliere quali crediti
possano partecipare a ciascun modello. Avviare quindi CR-02, CR-03 e CR-T1;
assegnare i responsabili prima di trasformare le attività in lavoro esecutivo.
