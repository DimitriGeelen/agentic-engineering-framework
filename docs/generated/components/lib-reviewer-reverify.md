# reverify

> Pass B re-verification (T-1483 v1.5).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/reverify.py`

## What It Does

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit](/docs/generated/lib-reviewer-audit) | called_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [reverify_cli](/docs/generated/lib-reviewer-reverify_cli) | called_by | CLI shim for re-verification (T-1483 v1.5 Pass B). |
| [drift](/docs/generated/lib-reviewer-drift) | called_by | Pass A drift detection (T-1483 v1.5). |
| [audit](/docs/generated/lib-reviewer-audit) | uses_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [reverify_cli](/docs/generated/lib-reviewer-reverify_cli) | uses_by | CLI shim for re-verification (T-1483 v1.5 Pass B). |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-reverify.yaml`*
*Last verified: 2026-05-06*
