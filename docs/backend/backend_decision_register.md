# Registro decisioni backend

## Stato

- Ultimo aggiornamento: 16 luglio 2026.
- Decision owner: proprietario del prodotto/repository.
- Work package in esecuzione: `UC-02`.
- Stato: decisioni consolidate; `UC-01` e `UC-02.1`--`UC-02.4` completati.
- Prossima unita' eseguibile: `UC-02.5`, backup, restore e gate completo.

Questo registro riassume gli ADR accettati e distingue le decisioni gia' prese
da quelle intenzionalmente rinviate. In caso di conflitto, il testo completo
del relativo ADR resta autorevole.

## Decisioni accettate

| ADR | Scelta consolidata | Guardrail principali |
| --- | --- | --- |
| [ADR-0001](adr/0001-postgresql-access-and-migrations.md) | PostgreSQL tramite `pg` 8.22.0 senza ORM; `node-pg-migrate` 8.0.4; porte repository e migrazioni forward-only | Versioni senza range, ledger append-only dei checksum applicati, ruolo di attestazione separato, pool entro il 70% del limite, timeout numerici e restore drill prima di ogni `contract` distruttivo |
| [ADR-0002](adr/0002-anonymous-identity-sessions-and-authorization.md) | Principal server-side, token opachi, otto recovery code, ruoli separati e cancellazione fail-toward-deletion | Promessa di recupero limitata a codici validi, cutover `userId` coordinato, test browser reali, AAL2, dual-control, quorum di due admin, recovery offline e gate privacy prima del pilot |
| [ADR-0003](adr/0003-local-and-zero-cost-remote-prototype.md) | Locale autorevole; remoto gratuito opzionale e provider ancora aperto | Costo zero senza overage, pubblico read-only oppure fixture-only ristretto, soli dati applicativi sintetici, evidenza free entro 30 giorni, teardown, nessuna garanzia operativa e nuovo ADR hosting prima di `UC-09` |

## Decisioni rinviate intenzionalmente

Questi punti non sono impliciti e non possono essere scelti durante
l'implementazione senza il relativo gate:

1. provider AAL2 degli operatori e policy privacy/legale di retention,
   anonimizzazione e backup: obbligatori prima del pilot;
2. provider del remote-prototype gratuito: eventuale shortlist e PoC separati,
   seguiti da approvazione esplicita prima di creare ogni risorsa;
3. provider, regioni, budget, DPA, HA, RPO/RTO, backup e osservabilita' di
   staging/pilot: nuovo ADR accettato tra `UC-08` e `UC-09`;
4. qualsiasi piano a pagamento o con rischio di addebito: nuova decisione del
   proprietario, mai upgrade automatico.

## Confine dell'autorizzazione

Il proprietario ha autorizzato `UC-02` il 15 luglio 2026. L'autorizzazione
copre il database locale, le dipendenze fissate da ADR-0001 e le cinque
micro-sessioni del work package; non si estende ai work package successivi.
Fino a un nuovo comando non vengono avviati:

- `UC-03`--`UC-10` o modifiche applicative collegate;
- dipendenze o database estranei a `UC-02`;
- account, registry, app, bucket, domini o secret esterni;
- inserimento di metodi di pagamento o assunzione di costi;
- deploy locali esposti, tunnel o remote-prototype;
- trattamento di dati o account appartenenti a persone reali.

L'esecuzione e' iniziata da `UC-01` e continua a seguire dipendenze,
micro-sessioni e quality gate del
[backend productization plan](backend_productization_plan.md). L'accettazione
di ADR-0003 non anticipa il gate hosting persistente di `UC-09`.

## Criteri di riapertura

Una decisione deve tornare `proposed` o essere sostituita da un nuovo ADR se
cambia uno dei suoi elementi sostanziali, per esempio:

- ORM, driver, major PostgreSQL o migration tool;
- account nominativi, recupero assistito, tipo di token o matrice dei ruoli;
- remoto pubblico scrivibile, dati reali, costo non zero o affidabilita'
  dichiarata del prototipo;
- provider o architettura operativa di staging/pilot.

## Evidenza di chiusura UC-00

- [Matrice dei gap contrattuali](api_contract_gap_matrix.md) completa e senza
  righe `not_assessed`.
- ADR-0001, ADR-0002 e ADR-0003 in stato `accepted`.
- Backlog `UC-01`--`UC-10`, dipendenze, ordine PR e quality gate registrati nel
  piano.
- Nessuna dipendenza, risorsa esterna o modifica applicativa introdotta da
  `UC-00`.

## Evidenza di chiusura UC-01

- Dominio, application service, HTTP, configurazione e `MemoryStore` estratti
  dal file unico; `src/server.js` conserva gli export pubblici ed e' ridotto al
  composition root.
- `services/backend/openapi.yaml`, `/v1`, enum, response ed error code
  invariati.
- 19 test backend verdi con Node.js 24.14.0, inclusi configurazione e nuovi
  casi di regressione.
- Quality gate Flutter verde: formattazione invariata, analisi senza errori
  bloccanti, 34 test passati e build web release riuscita.
- Nessuna dipendenza di produzione, risorsa esterna, credenziale, dato reale o
  spesa introdotta.

## Evidenza di avanzamento UC-02

- `UC-02.1`: schema reversibile, versioni fissate, manifest SHA-256 e ledger
  append-only verificati su PostgreSQL 17 reale.
- `UC-02.2`: `DATA_STORE` obbligatorio, pool e timeout numerici, seed
  locale/test separati, mapper fail-closed e letture PostgreSQL per Comuni,
  turni, problemi, proposte e previsioni.
- `UC-02.3`: proposta, voto/promozione/attivazione e previsione usano un solo
  client per transazione; rollback e traduzione SQLSTATE sono verificati.
- `UC-02.4`: chiavi idempotenti persistite nella transazione, retry Flutter con
  chiave stabile, voto/previsione concorrenti, fault injection, due runner,
  recovery transazionale e gate append-only sono verificati.
- Nessun fallback da PostgreSQL a `MemoryStore`: letture e scritture
  autorizzate usano esclusivamente l'adapter selezionato.
- Pool runtime unico per composition root e shutdown verificato; nessuna
  migrazione o seed viene eseguito implicitamente all'avvio HTTP.
