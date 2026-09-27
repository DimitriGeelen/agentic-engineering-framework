# comment_strip

> Structural HTML-comment stripping — the single canonical rule (T-2954).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/comment_strip.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [verification-port](/docs/generated/lib-verification-port) | calls | lib/verification-port.sh — hard-coded Watchtower port detection (T-2732) |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [check-human-ac-tick](/docs/generated/agents-context-check-human-ac-tick-py) | calls | T-1731: Human-AC tick guard hook. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-human-ac-tick](/docs/generated/agents-context-check-human-ac-tick-py) | called_by | T-1731: Human-AC tick guard hook. |

---
*Auto-generated from Component Fabric. Card: `lib-comment_strip.yaml`*
*Last verified: 2026-08-12*
