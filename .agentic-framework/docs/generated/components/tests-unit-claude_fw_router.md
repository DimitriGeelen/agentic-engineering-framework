# claude_fw_router

> Pins bin/claude-fw-router's resolution: routes to a vendored consumer's own claude-fw, walks up from a nested subdirectory, prefers the framework repo's own bin/claude-fw over its self-vendored copy, falls back to plain claude when no project/sibling is found (announced on stderr), and skips an incomplete vendor mid-init.


**Type:** script | **Subsystem:** framework-core | **Location:** `tests/unit/claude_fw_router.bats`

**Tags:** `router`, `claude-fw`, `D-377`, `T-2854`

## What It Does

T-2854 (D-377) — bin/claude-fw-router: the `claude-fw` entry point on PATH.
Sibling of tests/unit/fw_router.bats / router_no_global_fallback.bats, same
testing shape: stub the thing being routed to with a script that prints its
own path, and assert on that path. Unlike bin/fw-router, claude-fw-router has
no framework-only refusal to fall back to — a bare directory or a project
with no claude-fw sibling both degrade to plain `claude`, they don't error.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [claude-fw-router](/docs/generated/bin-claude-fw-router) | calls | The `claude-fw` entry point installed onto PATH. Walks up from cwd to find the current project (framework repo or vendored consumer, same predicate as bin/fw-router) and execs THAT project's own bin/claude-fw. Replaces a fixed copy of the wrapper's logic that install.sh used to put on PATH — a fixed copy runs the same bytes regardless of which project you're standing in, which is the global-install problem wearing a different name (T-2854). Falls back to plain `claude` when no project is found or the resolved project has no claude-fw sibling. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-claude_fw_router.yaml`*
*Last verified: 2026-08-07*
