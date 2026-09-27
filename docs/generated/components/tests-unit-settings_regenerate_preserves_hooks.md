# settings_regenerate_preserves_hooks

> T-2710: a forced .claude/settings.json regenerate must not silently delete hooks that `fw hook-enable` added after init.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/settings_regenerate_preserves_hooks.bats`

## What It Does

T-2710: a forced .claude/settings.json regenerate must not silently delete hooks
that `fw hook-enable` added after init.
generate_claude_code_config (lib/init.sh) writes settings.json from a fixed heredoc
template. With force=true it overwrote unconditionally — so the 6 hooks this repo
added post-init (check-active-completed-dup, check-arc-id, check-heredoc-cmd-sub,
check-inception-decisions, check-inception-schema, check-settings-edit) were wiped
by any `fw upgrade` that took the regenerate branch. Six governance gates off, no
message. T-2709's A2 made that branch reachable on every consumer, which is what
turned a dormant trap into a live one.
Two invariants, and BOTH matter:

## Dependencies (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [settings_merge](/docs/generated/lib-settings_merge) | tests | T-2710 — carry non-template config forward across a settings.json regenerate. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-arc-id](/docs/generated/agents-context-check-arc-id) | calls | T-1849: arc_id task-frontmatter validation hook (bash wrapper for Python). The fw hook dispatcher (bin/fw:5489) loads .sh files; the actual logic lives in check-arc-id.py to keep YAML parsing + arc resolution clean. |
| [check-inception-decisions](/docs/generated/agents-context-check-inception-decisions) | calls | T-1984: inception_decisions / unlocks_inception_decision validation hook (bash wrapper). The fw hook dispatcher (bin/fw:5639) loads .sh files; actual logic in check-inception-decisions.py. |
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema) | calls | T-2188: inception frontmatter schema validation hook (bash wrapper for Python). The fw hook dispatcher loads .sh files; logic lives in check-inception-schema.py. |
| [check-active-completed-dup-sh](/docs/generated/agents-context-check-active-completed-dup-sh) | calls | Thin wrapper (T-2517) the fw hook dispatcher loads for the active/completed duplicate write-time guard. Execs check-active-completed-dup.py; the shell layer exists only because bin/fw's hook loader globs .sh files. |
| [check-heredoc-cmd-sub](/docs/generated/agents-context-check-heredoc-cmd-sub) | calls | T-1945 — Heredoc-in-command-substitution edit-time guard. |
| [check-settings-edit](/docs/generated/agents-context-check-settings-edit) | calls | PostToolUse hook (Write\|Edit matcher) that fires an advisory L-398 reminder when .claude/settings.json is written/edited. Reminds the agent to add `bin/fw enforcement baseline` to the active task's Verification block so the canonical hash refreshes at task-close. Strictly advisory (exit 0).  Origin: T-1886 RCA Candidate B — paired with T-1887 Candidate A (template hint). The enforcement-baseline-drift class accumulated for multiple sessions across T-1849/T-1730/T-1731 before T-1886 cleaned up. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-settings_regenerate_preserves_hooks.yaml`*
*Last verified: 2026-08-01*
