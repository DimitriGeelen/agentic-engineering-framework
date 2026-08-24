# fw_help_watchtower_discoverable

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/fw_help_watchtower_discoverable.bats`

## What It Does

T-2808 — `fw help` must make the Watchtower port resolvable.
CLAUDE.md's §Watchtower Port rule tells every agent to resolve the port with
`fw watchtower port|url` and never hard-code :3000. The T-2732 close gate
refuses a Verification line containing a bare port-3000 URL. And yet `fw help`
listed no `watchtower` entry at all, while advertising "default port 3000" on
the `serve` line — so the CLI's own front page taught the anti-pattern and hid
the verb the rule depends on.
Hit live: an onboarding agent on a fresh project ran `fw watchtower url`, got
http://localhost:3000 back, and could not find the command in `fw help` to
check itself against (operator report, 2026-08-05).

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-fw_help_watchtower_discoverable.yaml`*
*Last verified: 2026-08-05*
