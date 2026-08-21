# Piano di rilascio pubblico

## Obiettivo

Rendere disponibile Migliora Paese come prototipo open source `v0.1.0`, con:

- repository consultabile e contribuibile;
- demo Flutter web su GitHub Pages;
- dati di gioco mock locali come configurazione predefinita;
- pilot HTTP per proposte e voto attivabile solo in sviluppo;
- backend dichiarato esplicitamente come scaffold locale non deployabile.

Il rilascio pubblico del codice non equivale al lancio di un servizio civico reale.

## Criteri di uscita tecnici

- `dart format --set-exit-if-changed .` passa;
- `flutter analyze --no-fatal-infos --no-fatal-warnings` non riporta errori;
- `flutter test` passa;
- `flutter build web --release --base-href /miglioraPaese/` passa;
- i test Node del backend passano con la versione documentata;
- il mockup di design non incorpora runtime o font di terze parti;
- nessun segreto riconoscibile e nessun file IDE o ambiente locale e' tracciato;
- README, licenza, sicurezza, contributi e changelog descrivono lo stato reale.

## Gate prima della visibilita' pubblica

### 1. Strategia della cronologia Git

La cronologia privata contiene indirizzi e-mail personali/aziendali, percorsi locali e riferimenti a task nelle vecchie PR. Rendere pubblico il repository attuale li renderebbe consultabili.

Scelta raccomandata: pubblicare uno snapshot bonificato in un nuovo repository pubblico e mantenere questo repository privato come archivio. L'alternativa e' una riscrittura coordinata della cronologia e dei riferimenti remoti, con force-push e invalidazione dei cloni esistenti.

La scelta richiede approvazione esplicita del proprietario prima di qualsiasi rename, nuovo repository o riscrittura.

Decisione del proprietario del 21 agosto 2026: mantenere il repository corrente
come archivio privato, rinominarlo e pubblicare un nuovo repository
`miglioraPaese` da uno snapshot bonificato senza la cronologia privata.

### 2. Provenienza degli asset

Il proprietario dichiara che logo, icone e illustrazioni presenti in `assets/`
sono stati creati con AI generativa. Servizio, modello e date esatte non sono
stati conservati. Provenienza, limiti della dichiarazione e condizioni di
distribuzione sono documentati in [ASSETS.md](../ASSETS.md).

### 3. Controlli GitHub

- chiudere le PR obsolete;
- archiviare o eliminare i branch non piu' necessari;
- abilitare GitHub Pages con source GitHub Actions;
- proteggere `main` con i check Flutter e backend richiesti;
- abilitare secret scanning e private vulnerability reporting quando disponibili;
- eseguire uno scanner dedicato della cronologia prima del cambio di visibilita'.

Sul piano GitHub corrente, Pages e l'applicazione effettiva della protezione di
branch non sono disponibili mentre il repository resta privato; private
vulnerability reporting e i controlli di pubblicazione saranno abilitati sul
nuovo repository pubblico subito dopo la creazione dello snapshot.

## Confini di sicurezza

La demo Pages non deve chiamare il backend e non deve inviare contributi reali.
Il backend pilot dispone di SQLite, identita' anonima firmata, filtro automatico
e limite locale degli invii, ma non ancora di moderazione umana, backup,
cancellazione remota, privacy operativa o protezioni anti-abuso distribuite.
Queste ultime capacita' restano prerequisiti per un'apertura pubblica.

## Passi successivi al prototipo

1. Completato: contratto per risultati, reputazione e insight.
2. Completato per il pilot: identita' anonima server-side e persistenza con
   migrazione iniziale.
3. Parziale: filtro contenuti e limite locale; aggiungere processo umano,
   backup, cancellazione e policy privacy.
4. Preparare staging, test end-to-end remoti e osservabilita'.
5. Eseguire un rollout limitato con un Comune prima di un'apertura generale.
