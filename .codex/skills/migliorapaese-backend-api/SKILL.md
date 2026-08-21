---
name: migliorapaese-backend-api
description: Maintain the Migliora Paese backend HTTP API in services/backend. Use when adding or changing backend endpoints, request validation, in-memory store behavior, OpenAPI schemas, or Node backend tests for the /v1 API that will replace Flutter mock repositories.
---

# Migliora Paese Backend API

## Workflow

1. Read `docs/backend/backend_foundation_plan.md`, `services/backend/openapi.yaml`, `services/backend/src/server.js`, and the relevant tests in `services/backend/test/server.test.js`.
2. Identify which Flutter repository contract the change must serve:
   - `lib/features/game/data/game_repository.dart`
   - `lib/features/next_problems/data/next_problems_repository.dart`
3. Update the API contract and implementation together. Do not add server behavior that is missing from `openapi.yaml`, and do not add contract entries without executable behavior.
4. Preserve the `/v1` prefix and current JSON enum spellings unless the Flutter domain model is changed in the same task.
5. Add or update `node:test` coverage for every route, validation branch, or response shape changed.
6. Run backend validation from `services/backend`:

```bash
npm test
```

## Backend Constraints

- Keep the current zero-dependency Node HTTP scaffold unless the task explicitly approves dependencies.
- Keep the in-memory store isolated behind `createMemoryStore()` so future persistence can replace it without changing route handlers more than necessary.
- Return JSON for every response, including errors.
- Use stable error codes such as `invalid_field`, `not_found`, or domain-specific codes that tests can assert.
- Keep default demo behavior explicit: `demo-user` is acceptable only for local scaffold flows.
- Do not introduce authentication, database persistence, cloud deploy, or admin flows unless requested.

## Contract Alignment

Use these enum spellings across backend, OpenAPI, and Flutter mappings:

- `PredictionChoice`: `improve`, `stable`, `worsen`
- `HypothesisConfidence`: `gutFeeling`, `considered`, `convinced`
- `VoteChoice`: `none`, `up`, `down` in Flutter; API vote requests accept `up`, `down`
- `SuggestedProblemStatus`: `pending`, `approved`, `rejected`
- `ProblemKey`: `lighting`, `potholes`, `waste`, `cleanliness`, `green`, `signage`, `transport`, `parking`, `decor`, `noise`, `safety`, `construction`, `queues`

When adding fields for Flutter consumption, prefer additive fields over renames. If a rename is unavoidable, update the Flutter mapper and tests in the same change.

## Review Checklist

- `openapi.yaml` path, method, request body, and response descriptions match `src/server.js`.
- Tests cover success, validation failure, and important not-found behavior.
- New response shapes can be mapped to existing Flutter domain objects without leaking transport naming into UI code.
- `services/backend/README.md` remains accurate if commands or local URLs change.
