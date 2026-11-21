# fw-command

> lib/fw-command.sh — the shell builder for every fw command the framework PRINTS (rule T-5302 GO; builder T-5303; moved here T-5304).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/fw-command.sh`

## What It Does

lib/fw-command.sh — the shell builder for every fw command the framework PRINTS
(rule T-5302 GO; builder T-5303; moved here T-5304).
Every command printed for a person or an agent is
cd <absolute project root> && <fw path> <args>
with <fw path> = bin/fw in the framework repo (FRAMEWORK.md + bin/fw at the
root) and .agentic-framework/bin/fw in a vendored project. Never bare `fw`:
the PATH fw is not the T-2793 router on every host (ring20 .122 keeps the old
fw-shim) nor on every PATH a worker or hook runs with (1409). Never
bin/watchtower.sh: Watchtower is `<fw path> watchtower ...`.
Python twin: lib/fw_command.py; Watchtower global: fw_cmd. Parity is pinned by

---
*Auto-generated from Component Fabric. Card: `lib-fw-command.yaml`*
*Last verified: 2026-11-20*
