# preflight

> fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/preflight.sh`

**Tags:** `lib`, `fw-subcommand`, `validation`

## What It Does

fw preflight — Validate OS dependencies before init
Sovereignty principle: detect silently, inform clearly, act only with consent.
Same pattern as Tier 0: detect → inform → ask → execute with approval.
Usage:
fw preflight              # Interactive: check + offer to install
fw preflight --check-only # Non-interactive: check only, exit code 0/1
Exit codes:
0 = all required deps present
1 = required dep(s) missing

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `?` | uses |

## Related

### Tasks
- T-303: Create fw preflight command and integrate into fw init
- T-344: Interactive auto-init dialogue with directory and provider selection
- T-349: Streamline fw init output for new users

---
*Auto-generated from Component Fabric. Card: `lib-preflight.yaml`*
*Last verified: 2026-03-04*
