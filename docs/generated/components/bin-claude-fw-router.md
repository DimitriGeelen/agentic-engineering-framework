# claude-fw-router

> The `claude-fw` entry point installed onto PATH. Walks up from cwd to find the current project (framework repo or vendored consumer, same predicate as bin/fw-router) and execs THAT project's own bin/claude-fw. Replaces a fixed copy of the wrapper's logic that install.sh used to put on PATH — a fixed copy runs the same bytes regardless of which project you're standing in, which is the global-install problem wearing a different name (T-2854). Falls back to plain `claude` when no project is found or the resolved project has no claude-fw sibling.


**Type:** script | **Subsystem:** framework-core | **Location:** `bin/claude-fw-router`

**Tags:** `router`, `claude-fw`, `D-377`, `T-2854`

## What It Does

claude-fw-router — the `claude-fw` entry point on PATH (T-2854, completing D-377).
Mirrors bin/fw-router's reason for existing: before this file, `install.sh`
put a fixed COPY of bin/claude-fw onto PATH (T-2807). That copy is the
wrapper's actual logic — auto-restart, TermLink registration, the startup
banner — not project data, so unlike the copy's OWN runtime lookups (git
root, focus.yaml, the restart signal file, all resolved fresh per invocation)
its own BEHAVIOUR stayed pinned to whatever version happened to be on PATH
at install time. A `fw upgrade` in a project updates that project's vendored
`.agentic-framework/bin/claude-fw` (T-2502/_self_vendor_shim); it cannot
touch the on-PATH copy. That is the global-install problem wearing a

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [claude-fw](/docs/generated/bin-claude-fw) | triggers | Claude Code wrapper with auto-restart support. Runs claude normally, then checks for a restart signal file written by checkpoint.sh when auto-handover fires at critical budget. If found and fresh, auto-restarts with claude -c to continue seamlessly. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `install.sh` | calls | — |
| [claude_fw_router](/docs/generated/tests-unit-claude_fw_router) | called_by | Pins bin/claude-fw-router's resolution: routes to a vendored consumer's own claude-fw, walks up from a nested subdirectory, prefers the framework repo's own bin/claude-fw over its self-vendored copy, falls back to plain claude when no project/sibling is found (announced on stderr), and skips an incomplete vendor mid-init. |

---
*Auto-generated from Component Fabric. Card: `bin-claude-fw-router.yaml`*
*Last verified: 2026-08-07*
