---
name: migliorapaese-flutter-quality-gate
description: Validate Migliora Paese Flutter changes before PR or merge. Use for frontend feature work, UI changes, repository wiring, routing changes, tests, accessibility checks, and ensuring Flutter changes remain consistent with the local design system and backend API contract.
---

# Migliora Paese Flutter Quality Gate

## Review Workflow

1. Inspect the changed Flutter files and identify the feature area under `lib/features/*`.
2. Check whether the change touches shared code under `lib/core/*`, routing under `lib/app/*`, assets, or repository contracts.
3. Verify that new UI follows existing components and theme tokens before adding new styling.
4. Confirm tests cover the changed behavior at the right level: unit, repository, cubit, widget, or routing smoke test.
5. Run the relevant Flutter checks.

## Design And Architecture Rules

- Reuse the local design system in `lib/core/theme` and `lib/core/widgets`.
- Keep feature state in existing logic layers such as cubits; avoid moving network or persistence logic into widgets.
- Keep widgets responsive and ensure text fits on mobile widths.
- Preserve existing navigation patterns in `lib/app/router.dart` and `lib/features/shell`.
- Keep mock data and API data behind repository abstractions.
- Use existing SVG assets and `AppIcons`/`AppAssets` helpers when available.

## Backend-Aware Checks

If the Flutter change consumes backend data:

- Compare mappers with `services/backend/openapi.yaml`.
- Keep enum spellings aligned at the repository boundary.
- Add tests for missing fields, unknown enum values, and backend error responses when those paths affect UI state.
- Keep mock repository behavior equivalent enough that widget tests still represent real user flows.

## Commands

Run these from the repository root when tooling is available:

```bash
flutter analyze
flutter test
```

For backend-coupled Flutter work, also run:

```bash
cd services/backend
npm test
```

If local Flutter tooling is unavailable, state the missing executable or SDK version and rely on code review plus available tests.

## Pre-PR Checklist

- No unrelated formatting churn outside touched feature areas.
- New files follow existing package imports and naming style.
- Tests are deterministic and do not require a live backend unless explicitly marked as integration tests.
- Documentation or README snippets are updated when setup, commands, or runtime configuration changes.
