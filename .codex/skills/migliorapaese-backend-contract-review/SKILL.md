---
name: migliorapaese-backend-contract-review
description: Review Migliora Paese backend API contract changes before merge. Use for PR reviews or pre-merge checks involving services/backend/openapi.yaml, services/backend/src/server.js, backend tests, README docs, and compatibility with Flutter GameRepository or NextProblemsRepository.
---

# Migliora Paese Backend Contract Review

## Review Order

1. Inspect the diff for these files first:
   - `services/backend/openapi.yaml`
   - `services/backend/src/server.js`
   - `services/backend/test/server.test.js`
   - `services/backend/README.md`
   - `docs/backend/backend_foundation_plan.md`
2. Compare backend behavior with Flutter repository contracts:
   - `lib/features/game/data/game_repository.dart`
   - `lib/features/next_problems/data/next_problems_repository.dart`
3. Report findings before summary. Prioritize bugs, broken contracts, missing tests, and behavior that would block Flutter API integration.

## What To Verify

- Every implemented route is represented in `openapi.yaml`.
- Every changed OpenAPI route has matching server behavior and test coverage.
- Request validation rejects malformed JSON, missing required fields, invalid enums, and unknown entities where applicable.
- Response shapes are stable and can map cleanly into existing Flutter domain classes.
- Error responses stay JSON and keep assertable `error` codes.
- CI paths still run backend checks for `services/backend/**` and do not run Flutter checks for backend/docs-only changes unless intended.

## Compatibility Rules

- Treat enum spelling changes as breaking unless Flutter is updated in the same PR.
- Treat field removals and response nesting changes as breaking unless all consumers are migrated in the same PR.
- Prefer additive backend changes while Flutter still has mock repositories.
- Do not require real auth, real persistence, or deploy automation for the scaffold phase unless the PR claims to implement those features.

## Validation

When reviewing locally, run:

```bash
cd services/backend
npm test
```

For mixed Flutter/backend changes, also run the project Flutter checks used by the repository:

```bash
flutter test
```

If a command cannot run because local tooling is unavailable, state that explicitly and continue with code-level review.
