# Token proprio: selezione tecnologica e sostenibilità

Data: 16 ottobre 2026. Stato: proposta tecnica ed economica, non implementata.
Collegamento: [EVO-001](EVO-001-crypto.md). Obiettivo esplicito dell'utente:
creare un token proprio riutilizzando una base open source valida, scegliendo
gli aspetti più convenienti di blockchain, DAG o altre DLT.

## Decisione proposta

Creare un token su una rete esistente. Confrontare ERC-20/OpenZeppelin su Base
con un token Move su Sui. Tenere IOTA come alternativa documentata; valutare
una chain dedicata solo se un requisito misurato la rende necessaria.
Non esiste un repository migliore in assoluto e questa è una shortlist,
non una valutazione completa di tutte le reti.

Token proprio non implica rete propria. Usare il consenso di una rete già
operativa evita di avviare un nuovo insieme di validatori. Copiare il codice
di una chain non ne copia sicurezza economica, liquidità, utenti o operatori.
Un consenso DAG non è una garanzia di assenza di commissioni o redditività.

## Repository e rete: confronto preliminare

| Candidato | Base ufficiale | Vantaggio da verificare | Costi e limiti da misurare |
| --- | --- | --- | --- |
| ERC-20 su Base | OpenZeppelin/openzeppelin-contracts | Standard EVM, componenti riusabili e integrazioni | Gas L2 e componente L1, wallet, RPC, dipendenze operative L2, audit del codice aggiunto |
| Token Move su Sui | MystenLabs/sui, framework ed esempi ufficiali | Modello ad oggetti e consenso DAG Mysticeti | Competenze Move, gas e storage, wallet Flutter/web, indexer e gestione capability |
| Token Move su IOTA | iotaledger/iota | Infrastruttura programmabile e transazioni sponsorizzate | Tooling e integrazioni effettive, commissioni a carico dello sponsor, supporto operativo |
| Blockchain dedicata | cosmos/cosmos-sdk | Controllo del protocollo e della valuta nativa | Validatori, sicurezza economica, upgrade, RPC, explorer, disponibilità e liquidità |

Le prime tre righe riguardano l'uso della rete, non il fork del suo protocollo.
La quarta è un progetto infrastrutturale di ordine diverso. Sui è una blockchain
con consenso basato su DAG; blockchain e DAG non sono categorie necessariamente
alternative. Il repository MystenLabs/mysticeti è destinato alla ricerca:
la sua documentazione rimanda all'implementazione di produzione dentro Sui.

Preferenza preliminare: OpenZeppelin/ERC-20 per minimizzare personalizzazioni
del contratto. Sui è il concorrente diretto per verificare il vantaggio del DAG
sul nostro carico. Nessuna conclusione quantitativa sui costi senza benchmark.
Nessun protocollo ibrido nuovo e nessun bridge nel primo pilot proposto.

## Come selezionare e riusare il repository

Prima del prototipo registrare release stabile e commit esatto, licenza del
componente e delle dipendenze, advisory, audit riferiti a quella versione,
procedure di aggiornamento e strumenti riproducibili. Non usare un branch
mobile o copiare un generico template di lancio token senza provenienza.
L'audit della libreria non equivale all'audit del nostro contratto e deployment.

Pesi proposti per la matrice, non punteggi già assegnati:

- 30% costo totale a 12 mesi, inclusi personale e gestione incidenti;
- 25% sicurezza, controllo chiavi e maturità dei componenti;
- 20% onboarding e integrazione con Flutter/web/backend;
- 15% affidabilità, finalità e prestazioni del carico applicativo;
- 10% portabilità e dipendenza da fornitori/rete.

Escludere prima del punteggio soluzioni prive dei requisiti necessari di
licenza, sicurezza o distribuzione. Registrare la copertura delle evidenze:
un dato mancante non va trasformato in un punteggio favorevole.

Benchmark comparabile: creazione, trasferimento, distribuzione batch,
spesa per servizio e lettura/riconciliazione del saldo. Usare lo stesso carico
logico; misurare latenza p50/p95, errori, gas/storage, RPC e lavoro operativo.
Testnet valida i flussi, non stima da sola costi e affidabilità mainnet:
stimare le fee reali con simulazioni e dati pubblici datati, senza fondi reali.
Scenari di volume: 10.000, 100.000 e 1.000.000 operazioni/mese; sono carichi
di prova, non previsioni di adozione. Proiettare gas a 1×/5×/10×.

## Economia candidata

Il token deve dare accesso a servizi concreti del prodotto, ad esempio
personalizzazioni e strumenti per organizzatori. Validare perché gli utenti
preferirebbero usarlo rispetto al pagamento diretto; la sola scarsità non prova
domanda. Non vendere influenza su esiti civici o punti competitivi.

Schema da validare:

1. Servizi reali e sponsor generano entrate esterne al mercato del token.
2. Il token può essere speso per utilità definite; diritti e prezzi sono espliciti.
3. Una quota sostenibile del margine finanzia incentivi e gas sponsorizzato.
4. La tesoreria conserva disponibilità operative indipendenti dal token proprio.

Non promettere cambio in euro, riacquisto o rendimento. Se si introduce un
diritto di rimborso, modellarlo come passività e rivalutare classificazione e
riserve. Prezzi dei servizi, quantità di token richiesti e fonte del cambio
sono decisioni aperte: un oracle aggiunge costi e rischi di manipolazione.

Supply massima, quantità iniziale, distribuzione e vesting vanno dimensionati
dopo utilità e domanda. Proposta: emissione controllata con limite verificabile,
nessuna tassa automatica sui trasferimenti, nessun rendimento finanziato da
nuova emissione. Confrontare supply fissa e cap con emissioni programmate;
documentare poteri amministrativi e loro eventuale revoca.

I token distribuiti hanno costi economici e possono creare pressione di vendita
anche se coniarli costa poco. Burn e staking non creano ricavi esterni.
Una riserva di liquidità DEX è capitale esposto a rischio, non fatturato;
prevedere perdita di valore, slippage, arbitraggio e disallineamento con i
prezzi dei servizi. Evitare di aprire liquidità prima di averne deciso budget
e responsabilità. Non finanziare operazioni ricorrenti contando su prezzo in salita.

## Modello economico da compilare

Definizioni mensili, evitando doppio conteggio:

- R: ricavi di servizi effettivamente erogati e sponsorizzazioni, al netto di
  imposte indirette, rimborsi e sconti; la vendita iniziale di token è separata.
- V: costi variabili dei servizi, gas/RPC variabile, commissioni, frodi,
  supporto variabile e incentivi valorizzati economicamente.
- F: personale, infrastruttura fissa, sicurezza e compliance ricorrente.
- I: sviluppo, audit e avvio; scegliere un orizzonte H per valutarne il recupero.

Margine operativo = R − V − F.
Risultato economico mensile comprensivo del recupero investimento = R − V − F − I/H.
La pianificazione di cassa resta separata: I si paga secondo le scadenze reali.
Non equiparare incassi anticipati per token a ricavi già maturati.

Esempio puramente aritmetico: con F=3.000 €/mese, I=24.000 €, H=12 mesi e
margine per cliente dopo V pari a 5 €/mese, servono 1.000 clienti paganti
per coprire anche I/H, oppure 600 per il solo equilibrio operativo.
Sono input ipotetici, non preventivi o stime sul progetto.

## Criteri proposti di sostenibilità

Da approvare e valorizzare in CR-04; non sono risultati già raggiunti:

- Scenario base positivo dopo costi completi e recupero investimento.
- Almeno 12 mesi di copertura di cassa nello scenario prudente, escludendo
  vendite future e valorizzazione del token proprio dalle risorse disponibili.
- Sopravvivenza allo stress: utenti paganti −50%, token −80%, gas ×10,
  perdita del maggiore sponsor; esplicitare quanto tempo resta prima dello stop.
- Incentivi finanziati da margine disponibile o budget prefissato, mai obblighi
  illimitati. Se il budget finisce, interrompere nuove campagne rispettando
  i diritti già maturati.
- Costi del pilot entro un tetto definito; stop a discrepanze contabili,
  compromissione chiavi o deficit rispetto agli impegni già assunti.

Questo riduce il rischio ma non garantisce profitti o valore di mercato.
Una tecnologia conveniente non rende automaticamente sostenibile il prodotto.

## Prossimi deliverable

1. CR-01/CR-T1: specifica dei diritti del token, servizi acquistabili e modello
   della supply; conversione con i crediti competitivi separatamente motivata.
2. CR-02: foglio dei costi e scenari basati su preventivi e domanda osservata.
3. CR-T2: matrice OpenZeppelin/Base vs Sui con evidenze di versione e benchmark;
   IOTA da includere nel benchmark se risolve un requisito meglio dei primi due.
4. CR-03/CR-04: classificazione concreta e decisione sul pilot con budget.
5. CR-05: contratto minimo e test di invarianti; solo poi integrazione sandbox.

Non sono stati clonati repository, scelti nome/ticker, emessi token o attivate
transazioni. La scelta della rete resta provvisoria fino alla matrice misurata.

## Fonti ufficiali consultate

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Release e componenti OpenZeppelin](https://docs.openzeppelin.com/contracts/5.x)
- [ERC-20](https://docs.openzeppelin.com/contracts/5.x/erc20)
- [Base: commissioni](https://docs.base.org/specifications/transactions/network-fees)
- [Sui repository](https://github.com/MystenLabs/sui)
- [Sui: consenso DAG](https://www.docs.sui.io/develop/sui-architecture/consensus)
- [Sui: gas e storage](https://www.docs.sui.io/develop/transaction-payment/gas-in-sui)
- [Mysticeti: repository di ricerca e rinvio alla produzione](https://github.com/MystenLabs/mysticeti)
- [IOTA repository](https://github.com/iotaledger/iota)
- [IOTA: transazioni sponsorizzate](https://docs.iota.org/developer/iota-101/transactions/sponsored-transactions/about-sponsored-transactions)
- [Cosmos SDK](https://github.com/cosmos/cosmos-sdk)
