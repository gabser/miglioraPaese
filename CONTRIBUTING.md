# Contribuire

Grazie per l'interesse. Il progetto è un prototipo web basato su dati mock; il
backend in `services/backend` è uno scaffold locale, non un servizio pubblico.

## Ambiente

- Flutter `3.44.2`, preferibilmente tramite [FVM](https://fvm.app/);
- Node.js 24 per il backend locale.

```bash
fvm flutter pub get
fvm flutter run -d chrome
```

Se FVM non è disponibile, usa un'installazione Flutter esattamente alla versione
indicata in `.fvmrc`. Quando usi FVM, anteponi `fvm` anche ai comandi Flutter e
Dart riportati sotto.

## Verifiche

Prima di aprire una pull request esegui:

```bash
dart format --set-exit-if-changed .
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release
```

Per modifiche al backend:

```bash
cd services/backend
npm test
```

## Pull request

- Mantieni ogni PR piccola e focalizzata.
- Descrivi comportamento, motivazione e verifiche eseguite.
- Aggiorna test e documentazione quando cambia un contratto pubblico.
- Non inserire segnalazioni civiche reali, credenziali o dati personali in
  codice, fixture, log, issue o screenshot.
- Segnala vulnerabilità tramite il canale privato indicato in `SECURITY.md`.

Le contribuzioni accettate saranno distribuite secondo la licenza indicata dal
repository. Non aggiungere asset di terze parti senza documentarne fonte e
condizioni d'uso.
