# Sentinelle — checklist di accettazione per gli incrementi

Preparata il 13 ottobre, aggiornata il 16 ottobre 2026. **Fasi 0–8 verificate
localmente**; risultati e limiti nel registro e nel dossier operativo.
Questa matrice conserva i criteri; nessun test vale come approvazione umana.
Gate8 finale: 217 backend, 466 Flutter, cinque build release e rehearsal
PostgreSQL con identificativo reale PASS. Analyze: 462 info, zero warning/error.

| Fase | Prova osservabile | Condizione da verificare |
|---|---|---|
| 1 | Catalogo, stagione, calendario | DTO coerenti, UTC server, seed fisso senza rinnovo; scadenza esplicita |
| 1 | Squadra e conferma | Budget/ruoli, CAS, due richieste concorrenti, lock ±1ms, snapshot persistente anche dopo clock rollback |
| 1 | Mercato | Quote con revisione/catalogo/scadenza; terzo/quarto trasferimento penalità; replay dopo risposta persa e restart senza doppia spesa |
| 1 | Risultati v1 | 48 fixture scoring condivise, capitano/arrotondamento; provisional/final, snapshot non eleggibili senza punti |
| 1 | Riflessione | Stessa risposta replay prima di CAS, nessun doppio bonus; risposta diversa rifiutata; rollback insert |
| 1 | Leghe | Creazione idempotente/max3; membership isolata, minimo3 competitori, ranking 1/1/3, spettatori esclusi |
| 1 | Inviti | Hash a riposo, scadenza/revoca/rotazione; errore adesione consuma tentativo persistente; join concorrente con revoca |
| 1 | Revoca/cancellazione | Token falsificato rifiutato, identità body/query ignorata o rifiutata; race revoca/scrittura e isolamento; pubblicazioni/legacy preservati |
| 1 | Client | No API→mock; reset barrier, scope/stato persistente; creazione/adesione da UI, 390/1024/1440 e tastiera |
| 2 | Codice email simulato | Scadenza/riuso/tentativi/reinvio; risposta non enumera account; adapter locale distinto da operativo |
| 2 | Login/dispositivi | Recupero da altro dispositivo; logout/revoca sessione e revoca altri dispositivi; isolamento server |
| 2 | Guest linking | Transazione idempotente; non duplicare team/membership/XP; conflitto conserva account e richiede scelta esplicita |
| 2 | Ripresa | Missione/invito conservati dopo login senza esporre token a log o analytics; nessun import snapshot demo |
| 3 | Catalogo/dettaglio | Esplorazione anonima per Comune/zona; istruzioni/area/protocollo/finestra/durata/prove/10 XP dichiarati |
| 3 | Prenotazione | Email verificata; ultimo slot con due utenti, scadenza/rinuncia liberano slot; tempi server e retry idempotente |
| 3 | Questionario | Nessuna criticità/non osservabile/non so; bozza offline scoped, ripresa senza invio automatico |
| 3 | Prove | File sintetici, upload privato recuperabile, limiti/tipo/contenuto, metadati minimi; autorizzazione autore/operatori |
| 3 | Invio/ricevuta | Riepilogo e conferma server; doppio invio/risposta persa/riavvio non duplicano contributo; stato incerto esplicito |
| 4 | Revisione | Operatori distinti per ruolo; assegnazione/CAS/integrazioni/decisione motivata e audit |
| 4 | Conflitto | Autovalidazione vietata; decisione competitiva sulle proprie carte vietata, anche via ID contraffatto |
| 4 | XP | 10 una volta dopo validazione, anche nessuna criticità; persona/luogo/finestra unique salvo replica richiesta; doppia revisione concorrente |
| 5 | Protocollo | Problema/baseline/indicatore/soglia/finestra/istruzioni versionati prima lock; modifica tardiva rifiutata |
| 5 | Interventi | Entità distinta, relazione molti-a-molti, stato/temporaneità; nessuna attribuzione automatica del beneficio |
| 5 | Valutazione | Presente/assente/temporaneo, prove discordanti; motivazione/fonti e responsabile consultabili |
| 5 | Non determinabile | Disposizione distinta da stable; deadline chiude prove insufficienti; v2 solo nuove stagioni, zero osservazione/previsione, penalità/riflessione preservate |
| 5 | Rettifica | Originale e motivazione conservati; contestazione e revisione nuova; ricalcolo retry non duplica, storico consultabile, copertura visibile |
| 6 | Link invito | Riepilogo prima conferma, login mantiene intento; token escluso da log/analytics; ruolo late join visibile |
| 6 | Proprietà | Trasferimento a membro accettante con CAS; owner uscente archivia se nessun trasferimento completato |
| 7 | Cooperazione | Coverage unit luogo/finestra conteggiata una volta solo da contributo validato; separata da fantasy/XP |
| 7 | Ritorno | Inbox integrazioni/esiti/ricontrolli; follow luogo facoltativo; nessun canale esterno implicitamente attivato |
| 7 | Calendario | Pubblicazione admin idempotente nuova stagione/giornate; nessun seed automatico o modifica storico |
| 8 | Candidato | Commit se disponibile e digest diff locale/profilo identificati; build corretta, feature incomplete off |
| 8 | Rehearsal | End-to-end sintetico, PostgreSQL reale, retry/riavvio/isolation, backup/restore e cancellazioni successive al backup |
| 8 | Dossier | Log senza token, retention configurabile, incidenti/rollback documentati; separare prove locali da approvazioni umane |

Gate esterni aperti: provider/budget, consegna email/storage, autenticazione
forte operatori, responsabili e capacità, protocollo/fonti reali, privacy e
retention, backup/restore operativo, osservabilità/incidenti e autorizzazione
platea/target/avvio. Nessun campo può essere soddisfatto per inferenza da CI.
