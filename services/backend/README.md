# Migliora Paese backend

Backend HTTP iniziale per sostituire progressivamente i mock Flutter.

## Comandi

Richiede Node.js 20 o superiore.

```bash
npm test
npm run dev
```

Il server ascolta su `PORT`, default `8787`.

```bash
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/v1/municipalities/castel-bolognese/summary
```

## Note

Questa fase usa uno store in-memory. Serve a bloccare contratti, shape JSON e comportamento minimo. La persistenza reale va aggiunta in una fase successiva mantenendo gli endpoint di `openapi.yaml`.
