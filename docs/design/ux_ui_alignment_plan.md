# Fanta Comune UX/UI alignment plan

## Stato di partenza

Questo piano parte dal nuovo mockup v2 e dal baseline Flutter gia' introdotto nella PR #19, che ha portato nel codice:

- palette civic game moderna blu/navy con superfici chiare;
- token e tema centralizzati in `lib/core/theme`;
- componenti condivisi `Fc*` in `lib/core/widgets`;
- shell, home, board, profilo e `ProblemCard` gia' parzialmente riallineati;
- riferimento visuale in `docs/design/fanta-comune-standalone.html`.

Resta aperta la PR #20 sul primo loop civico. Prima di modificare in modo profondo `PlayPage`, onboarding o flussi di attivazione e' opportuno decidere se mergearla o ribasare il lavoro successivo su quella branch.

## Obiettivo

Allineare il prodotto al nuovo design system senza limitarsi al restyling UI. Il mockup v2 cambia anche la promessa UX: Fanta Comune deve funzionare bene sia per un Comune gia' attivo, sia per un Comune piccolo o nuovo che parte senza problemi, previsioni o proposte.

## Schermate di riferimento

Il mockup copre 12 schermate principali piu' 2 bonus, con varianti mobile e desktop:

1. Welcome
2. Scelta Comune
3. Home attiva
4. Home in attivazione
5. Play con carte
6. Play vuota
7. Proponi tema
8. Lista proposte e voto
9. Board vuota
10. Board popolata
11. Profilo e reputazione
12. Classifica
13. Esito e insight
14. Tutorial

## Principi UX

- Stati vuoti operativi: una schermata senza dati deve proporre il prossimo passo utile, non solo spiegare che manca contenuto.
- Comune in attivazione come caso primario: `Castel Bolognese` nel mockup non e' un edge case, ma il flusso di onboarding reale per molti piccoli comuni.
- Primo turno chiaro: l'utente deve capire cosa serve per aprire il primo turno civico e come contribuire.
- CTA singola dominante per schermata: evitare doppie azioni equivalenti, soprattutto su mobile.
- Trasparenza civica: ribadire nei punti sensibili che l'app non sostituisce i canali ufficiali del Comune.
- Desktop intenzionale: sidebar, rail laterali e max width devono evitare il semplice stretch della UI mobile.

## Principi UI

- Usare solo superfici pulite, bordi sottili e shadow leggere.
- Ritirare progressivamente il linguaggio vintage/carta: `VintagePaper`, `PaperTexture`, `StampActionButton`, `StampBadge`, `StickerBadge`, `PinnedNote`, `WaxSealHighlight`.
- Mantenere palette semantica coerente:
  - blu/navy per identita' e navigazione;
  - verde per migliora/successo;
  - ambra per stabile/attenzione;
  - rosso per peggiora/rischio;
  - grigi neutrali per struttura e testo secondario.
- Preferire componenti riusabili `Fc*` a composizioni locali duplicate.
- Nessun overflow testuale su viewport target 390x844 e 1440x900.

## Sequenza consigliata di PR

### PR A - Token e componenti base

- Allineare `AppTokens` e `assets/tokens.json` su colori, radius, spacing, shadow e font.
- Decidere se introdurre font asset Geist o mantenere Roboto in Flutter con scala equivalente.
- Completare o stabilizzare `FcPanel`, `FcMetricCard`, `FcStatusChip`, `FcPredictionBar`, `FcSectionHeader`, `FcActionButton`, `FcProblemTile`.
- Aggiungere widget test minimi sui componenti critici.

Criterio di uscita: tutte le nuove schermate possono essere costruite senza introdurre componenti one-off.

### PR B - Shell responsive e navigazione

- Rifattorizzare la shell con breakpoint espliciti.
- Mobile: bottom navigation stabile.
- Tablet/desktop: sidebar sinistra con stato attivo e contenuto a larghezza massima.
- Evitare nested scroll inutili: una sola superficie scrollabile per pagina.

Criterio di uscita: le route principali hanno layout coerente su 390x844 e 1440x900.

### PR C - Home attiva e Home in attivazione

- Home attiva: header Comune, turno del giorno, metriche, problemi prioritari, reputazione, insight e proposte.
- Home in attivazione: banner dedicato, micro-obiettivo, CTA primaria verso proposta tema, CTA secondaria verso lista proposte.
- Evitare metriche finte quando il Comune non ha dati reali o mock coerenti.

Criterio di uscita: un Comune nuovo non mostra una dashboard vuota o ingannevole.

### PR D - Play con carte e Play vuota

- Play con carte: progressione problema X di Y, prediction card compatta, motivazioni contestuali, confidence e feedback chiari.
- Play vuota: spiegare che il turno non e' partito, proporre missioni leggere di osservazione e guidare a `SuggestProblemPage`.
- Verificare performance scroll con liste potenzialmente lunghe.

Criterio di uscita: l'utente capisce sempre cosa fare anche senza carte attive.

### PR E - Proposte e voto

- `SuggestProblemPage`: form leggibile, scrollabile, CTA raggiungibile con tastiera aperta.
- `NextProblemsPage`: card compatte con stato, categoria, voti e CTA di voto.
- Stato vuoto: esempi concreti e CTA per proporre il primo tema.

Criterio di uscita: il percorso per avviare il primo turno e' completo.

### PR F - Board vuota e popolata

- Board popolata: problemi ordinabili/scansionabili con status, trend e distribuzione previsioni.
- Board vuota: mappa in costruzione, categorie suggerite, invito a osservare zone e proporre temi.
- Nessuna segnalazione finta presentata come dato reale.

Criterio di uscita: board utile anche prima della massa critica.

### PR G - Profilo, classifica, esito e tutorial

- Profilo: reputazione, livello, precisione, storico recente e progressione lente civica.
- Classifica: ranking comunale, posizione utente evidenziata, switch Comune/Regione se presente nel dominio.
- Esito e insight: feedback post-previsione comprensibile, non punitivo.
- Tutorial: opzionale, breve, accessibile dal welcome o dal profilo/info.

Criterio di uscita: loop reputazione e apprendimento sono coerenti con il nuovo sistema.

## Verifica

Per ogni PR:

```bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
```

Per le PR con UI rilevante:

- verifica manuale mobile 390x844;
- verifica manuale desktop 1440x900;
- controllo overflow testi in bottoni, card, nav e form;
- controllo che gli stati vuoti abbiano sempre una CTA utile.

## Priorita' immediata

1. Chiudere o integrare PR #20.
2. Fare PR A/B se il baseline non e' ancora abbastanza stabile.
3. Portare subito Home in attivazione, Play vuota e Board vuota a livello mockup, perche' sono i punti UX piu' deboli e piu' importanti per il lancio in piccoli comuni.
