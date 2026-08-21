# Changelog

Le modifiche rilevanti al progetto sono documentate in questo file seguendo
[Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/).

## [Unreleased]

### Aggiunto

- documentazione per contributi, supporto, sicurezza e condotta;
- template GitHub per issue e pull request;
- aggiornamenti automatici per dipendenze Pub e GitHub Actions;
- workflow per verificare la build web e pubblicare la demo mock su GitHub Pages.
- pilot API opt-in per proposte e voto con client HTTP, mapping tipizzato e test;
- piano versionato per il rilascio pubblico e i relativi gate di sicurezza.

### Modificato

- Flutter fissato alla versione `3.44.2` per sviluppo e CI;
- backend CI aggiornato a Node.js 24;
- metadati locali degli IDE esclusi dal repository.
- contratto backend aggiornato a OpenAPI 0.2.0 con schemi response/error;
- reference del mockup resa statica, senza runtime o font incorporati;
- metadati PWA e messaggi privacy allineati allo stato del prototipo.

### Corretto

- avvio reale del backend, CORS locale, limiti body e validazione dei contratti;
- promozione proposta → attivazione Comune → carta del turno;
- isolamento visuale di `myVote`, filtro azzerabile e race nelle ricerche;
- dati hardcoded e fuorvianti nella sidebar desktop.
