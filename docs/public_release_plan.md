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

Il repository pubblico usa Pages tramite GitHub Actions, protezione di `main`,
secret scanning e private vulnerability reporting. La cronologia originaria è
conservata nell'archivio privato separato.

## Confini di sicurezza

La demo Pages non deve chiamare il backend e non deve inviare contributi reali.
Il backend pilot dispone di SQLite, identita' anonima firmata, filtro automatico,
moderazione operatore, limite locale, backup verificabile e osservabilità di
base. Restano necessari prova di restore, cancellazione remota, privacy
operativa e protezioni anti-abuso distribuite prima dell'apertura pubblica.

## Passi successivi al prototipo

1. Completato: contratto per risultati, reputazione e insight.
2. Completato per il pilot: identita' anonima server-side e persistenza con
   migrazione iniziale.
3. Completato nel codice: filtro contenuti, moderazione umana, limite locale e
   backup verificabile; cancellazione e policy privacy restano operative.
4. Completato nel repository: candidato staging, smoke e osservabilità; manca
   il deploy su un provider approvato.
5. Prossimo: selezionare il Comune, superare i gate del runbook ed eseguire un
   rollout limitato prima di un'apertura generale.
