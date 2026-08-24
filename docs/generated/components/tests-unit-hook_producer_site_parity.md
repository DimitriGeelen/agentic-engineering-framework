# hook_producer_site_parity

> Guards that lib/init.sh:generate_claude_code_config never diverges again from the framework repo's own .claude/settings.json (the cumulative record of every 'fw hook-enable' call) — name-keyed comparison plus an explicit framework-only allowlist and a negative control proving the comparator is non-vacuous.

**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/hook_producer_site_parity.bats`

**Tags:** `hooks`, `init`, `parity`, `T-2911`

## What It Does

T-2911 — the two hook-registration producer sites must not diverge again.
`fw hook-enable` (bin/hook-enable.sh) is how a hook gets added to THIS repo's own
.claude/settings.json over time — one call per hook, cumulative. `generate_claude_code_config`
(lib/init.sh) is the fixed template every `fw init`/`fw upgrade` regenerate writes into a
CONSUMER's settings.json. bin/hook-enable.sh:120 already said "both sites must change
together (L-399 producer/consumer parity)" — prose only, so it was broken 7 times (8 counting
check-rail-mcp-label, added via `fw hook-enable` by T-2908 one commit before this task's own
measurement, reproducing the exact defect this file exists to catch).
Key on hook NAME, not the raw command string or (event,matcher,command) tuple: the emitted
command differs between framework-mode (`bin/fw`) and consumer-mode

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | reads | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [hook-config](/docs/generated/hook-config) | reads | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [fw](/docs/generated/bin-fw) | triggers | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [init](/docs/generated/lib-init) | tests | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [hook-enable](/docs/generated/bin-hook-enable) | tests | Register framework hooks in .claude/settings.json idempotently — adds { type "command", command ".agentic-framework/bin/fw hook <name>" } entries under specified event/matcher pair. Built under T-1189 to repair T-977 false-complete (G-015). |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_producer_site_parity.yaml`*
*Last verified: 2026-08-10*
