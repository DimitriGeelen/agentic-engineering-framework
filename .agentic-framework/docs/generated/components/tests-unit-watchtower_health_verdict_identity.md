# watchtower_health_verdict_identity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/watchtower_health_verdict_identity.bats`

## What It Does

T-2445 (F9, T-2442 batch): Watchtower HEALTH-VERDICT call-sites must gate on
the identity-verified resolver, never on a default-port `/health` curl.
Regression origin: T-2441 onboarding dogfood. `fw doctor` and `fw audit`
reported the Watchtower healthy when a FOREIGN service held the default port
and the project's own dashboard never started. T-1803 had already hardened the
resolver (`_watchtower_url` verifies /api/_identity and fails loud), but two
consumers kept a pre-T-1803 fallback —
_watchtower_url 2>/dev/null || echo "http://localhost:<PORT>"
— then curled /health (an endpoint ANY server answers 200). When the resolver
correctly failed, the `|| echo` re-substituted the foreign port and the verdict

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [watchtower](/docs/generated/lib-watchtower) | calls | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | tests | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [watchtower](/docs/generated/lib-watchtower) | tests | Detects the running Watchtower instance URL and provides browser-open helpers for scripts that need to link to the web UI |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-watchtower_health_verdict_identity.yaml`*
*Last verified: 2026-06-21*
