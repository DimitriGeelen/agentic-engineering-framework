# codex_render_backing

> T-5341 (Risk R-NEW-3): is every committed codex render green backed by a viewing peer?

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/codex_render_backing.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [vote_checker](/docs/generated/lib-vote_checker) | calls | T-5293 (T-5290 GO, G-136): a mechanical check of each `verdict/1` vote against what it cites. |
| `.context/reviews/verdicts.jsonl` | reads | — |
| `.context/reviews/review-dispatches.jsonl` | reads | — |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `lib-codex_render_backing.yaml`*
*Last verified: 2026-11-21*
