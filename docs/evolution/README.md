# Evoluzioni del prodotto

Registro di riferimento per organizzare change e funzionalità candidate sul
tronco principale. Creato il 16 ottobre 2026. La priorità crypto è una richiesta
esplicita di prodotto; modalità di collegamento ai crediti e lancio sono da decidere.

Questi documenti pianificano il lavoro: non attestano funzionalità implementate,
finanziamenti disponibili o autorizzazioni al lancio. Destinazione: `main`.
Sono stati preparati nella checkout `codex/uc-02-postgres-migrations`; l'integrazione
in `main` non è ancora avvenuta.

## Registro iniziative

| ID | Iniziativa | Priorità | Stato | Prossimo risultato verificabile |
| --- | --- | --- | --- | --- |
| EVO-001 | [Economia del gioco e criptovalute](EVO-001-crypto.md) | Alta, richiesta utente | discovery | Progetto token proprio, confronto reti e modello economico |
| EVO-002 | Servizi premium e strumenti per leghe | Da ordinare | proposta | Offerta, segmenti, prezzi da testare e metriche |
| EVO-003 | Sponsorizzazioni territoriali | Da ordinare | proposta | Proposta commerciale e separazione sponsor/valutazioni |
| EVO-004 | [Segnalazioni su mappa e città 3D](EVO-004-mappa-citta-3d.md) | Richiesta utente, 17 ottobre 2026 | discovery | Piano incrementale, verifica dati del Comune e prototipo cartografico senza servizi a pagamento |

EVO-002 ed EVO-003 sono ipotesi emerse nello studio: non sono prerequisiti
obbligatori per studiare crypto né progetti già approvati. Aprire una scheda
dedicata con il [template](feature-template.md) quando entrano in discovery.

## Ciclo di vita

`proposta → discovery → pronta → in sviluppo → pilot → rilasciata`

Gli stati `sospesa` e `scartata` richiedono una motivazione e, se utile, una
condizione di riesame. Una priorità alta non equivale a disponibilità al lancio.

- **Discovery:** problema, alternative, fattibilità, misure e dipendenze.
- **Pronta:** perimetro, responsabile, criteri di accettazione e decisioni
  necessarie documentati; ogni attività deve indicare il proprio ambiente.
- **In sviluppo:** issue/PR collegate e incremento compatibile con il tronco.
- **Pilot:** verifica limitata con popolazione, budget, durata e criteri di stop.
- **Rilasciata:** evidenze dei test, osservabilità, rollback e risultato del pilot.

Ogni scheda mantiene stato, prossima azione e registro decisioni. Aggiornare
questo indice quando cambia lo stato. I collegamenti GitHub si aggiungono dopo
la creazione effettiva delle issue/PR: gli ID locali non sono issue remote.

## Integrazione nel tronco principale

1. Integrare documentazione e decisioni prima delle funzionalità che ne dipendono.
2. Implementare incrementi piccoli con API e migrazioni retrocompatibili.
3. Per comportamenti sperimentali usare flag espliciti, disabilitati di default,
   con responsabile e condizione di rimozione; non creare ora flag senza codice.
4. Separare demo, sandbox e produzione. Un fallimento di provider non deve
   convertire implicitamente un flusso reale in un pagamento simulato.
5. Allegare alla PR criteri verificati e impatto sul gioco esistente.
6. Il merge non attiva un servizio monetario: la sua attivazione segue i criteri
   del pilot e le decisioni della scheda.

Per EVO-001, prima PR documentale: questa cartella e la sola voce nell'indice
del README. Non includere automaticamente le altre modifiche della checkout.

## Relazione con i piani esistenti

- [Rilascio pubblico](../public_release_plan.md): base operativa del prodotto.
- [Fondazione backend](../backend/backend_foundation_plan.md): dipendenze tecniche.
- [Decisioni backend](../backend/backend_decision_register.md): decisioni implementative.

Questa roadmap non sostituisce i piani esistenti. La scheda di evoluzione
definisce il perché e il perimetro; i piani tecnici descrivono l'esecuzione.
