# hook_version_marker_parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/hook_version_marker_parity.bats`

## What It Does

T-2852 — install-hooks must compare the installed commit-msg hook's
`# VERSION=` marker against the TEMPLATE's version, not against the git
agent's own version.
Those were different variables holding different quantities (template 1.11,
agent 1.6). The equality could never hold, so the "Hooks already installed"
short-circuit was unreachable and every install-hooks call rewrote all four
hooks while announcing a downgrade that nothing had actually computed.
agents/git/git.sh already carried a comment telling the reader to keep the two
in sync. It was correct, and it drifted anyway. Hence a test.

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_version_marker_parity.yaml`*
*Last verified: 2026-08-07*
