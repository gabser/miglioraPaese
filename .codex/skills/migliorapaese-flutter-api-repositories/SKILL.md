---
name: migliorapaese-flutter-api-repositories
description: Implement Flutter API-backed repositories for Migliora Paese. Use when replacing mock repositories with HTTP implementations, adding API mappers, wiring feature flags or environment configuration, or aligning GameRepository and NextProblemsRepository with services/backend/openapi.yaml.
---

# Migliora Paese Flutter API Repositories

## Workflow

1. Read the backend contract in `services/backend/openapi.yaml`.
2. Read the target Flutter repository interface:
   - `lib/features/game/data/game_repository.dart`
   - `lib/features/next_problems/data/next_problems_repository.dart`
3. Read the matching mock implementation before writing the API implementation:
   - `lib/features/game/data/mock_game_repository.dart`
   - `lib/features/next_problems/data/mock_next_problems_repository.dart`
4. Add API-backed classes without removing mocks until the app has a proven runtime switch.
5. Keep HTTP parsing and DTO-to-domain mapping out of presentation widgets and cubits.
6. Add focused tests for mapper behavior, repository success paths, and important error states.

## Implementation Rules

- Preserve the abstract repository interfaces unless a backend contract change requires an interface change.
- Map transport strings into existing domain enums at the repository boundary.
- Keep UI state classes and widgets unaware of OpenAPI field names.
- Prefer constructor injection for base URL, HTTP client, user ID, and municipality ID defaults.
- Make local development target `http://127.0.0.1:8787` configurable, not hardcoded deep in feature code.
- Keep the app usable with mock repositories while backend integration is incomplete.

## Endpoint Mapping

Start with these mappings:

- `GameRepository.getMunicipalityActivationState` -> `GET /v1/municipalities/{municipalityId}/activation`
- `GameRepository.getCivicLoopSummary` -> `GET /v1/municipalities/{municipalityId}/summary`
- `GameRepository.getCurrentTurn` -> `GET /v1/municipalities/{municipalityId}/turn`
- `GameRepository.listProblems` -> `GET /v1/municipalities/{municipalityId}/problems`
- `GameRepository.getLeaderboard` -> `GET /v1/municipalities/{municipalityId}/leaderboard`
- `GameRepository.getMyPredictions` -> `GET /v1/turns/{turnId}/predictions`
- `GameRepository.upsertPrediction` -> `PUT /v1/turns/{turnId}/predictions/{problemId}`
- `GameRepository.resolvePrediction` -> `POST /v1/problems/{problemId}/resolve`
- `NextProblemsRepository.listNextProblems` -> `GET /v1/municipalities/{municipalityId}/next-problems`
- `NextProblemsRepository.submitSuggestedProblem` -> `POST /v1/municipalities/{municipalityId}/next-problems`
- `NextProblemsRepository.voteSuggestedProblem` -> `POST /v1/municipalities/{municipalityId}/next-problems/{problemId}/votes`

Methods without backend endpoints should stay mock-backed or receive explicit backend contract work first.

## Validation

Run the Flutter test suite after repository wiring:

```bash
flutter test
```

If backend behavior is touched in the same change, also run:

```bash
cd services/backend
npm test
```
