# termlink

> TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary.

**Type:** script | **Subsystem:** termlink-integration | **Location:** `agents/termlink/termlink.sh`

## What It Does

termlink.sh — Framework wrapper for TermLink cross-terminal communication
Thin wrapper around the `termlink` binary. Adds framework concerns
(task-tagging, budget checks, cleanup tracking) but delegates all
real work to the binary. Adapted from tl-dispatch.sh (T-143, tested
with 3 parallel workers).
TermLink repo: https://onedev.docker.ring20.geelenandcompany.com/termlink
Install: cargo install --path crates/termlink-cli
Part of: Agentic Engineering Framework (T-503, from T-502 inception)

### Framework Reference

**Async, parallel, or observable framework work runs through TermLink
(`claude-fw --termlink`), not through Claude Code's own background-job
daemon.** This is a distinct layer from the Sub-Agent Dispatch Protocol and
the Built-in Task Tool Ban above: those govern dispatch *inside* a running
conversation (Task-tool agents, TermLink workers); this governs how the
*session itself* was launched, before any conversation starts.

*(truncated — see CLAUDE.md for full section)*

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [ollama-tool-loop](/docs/generated/tools-ollama-tool-loop) | calls | T-1706 — thin tool-execution loop for ollama-research workflow. |
| [git-identity](/docs/generated/lib-git-identity) | calls | lib/git-identity.sh — one answer to "can this machine commit?" (T-2883) |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (14)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [termlink](/docs/generated/tests-unit-termlink) | tested_by | Unit tests for agents/termlink/termlink.sh (8 tests) |
| [termlink](/docs/generated/tests-unit-termlink) | called_by | Unit tests for agents/termlink/termlink.sh (8 tests) |
| [termlink](/docs/generated/tests-unit-termlink) | tests_by | Unit tests for agents/termlink/termlink.sh (8 tests) |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | called_by | T-1708 — worker_kind drift regression test. |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | tests_by | T-1708 — worker_kind drift regression test. |
| [test_workflow_env_isolation](/docs/generated/tests-unit-test_workflow_env_isolation) | called_by | T-1700 AC6 — workflow env: plumb-through isolation invariants. |
| [test_workflow_env_isolation](/docs/generated/tests-unit-test_workflow_env_isolation) | tests_by | T-1700 AC6 — workflow env: plumb-through isolation invariants. |
| [test_termlink_dispatch_task_type](/docs/generated/tests-unit-test_termlink_dispatch_task_type) | called_by | Unit tests for fw termlink dispatch/spawn orchestrator-substrate wiring (T-1643/W1-W4) — pins _derive_task_type, _resolve_dispatch_model fallback chain, --task-type flag handlers in cmd_spawn/cmd_dispatch, and meta.json schema (task_type/model_used/fallback_used). |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | called_by | T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page. |
| [ollama_loop](/docs/generated/lib-ollama_loop) | called_by | OllamaLoopWorker — subprocess wrapper for `claude -p` with redirected env vars. |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | called_by | T-3038 (OBS-291) — focus is per-session, not per-project, for dispatched workers. |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | tests_by | T-3038 (OBS-291) — focus is per-session, not per-project, for dispatched workers. |
| [t3422_dispatch_seeds_focus](/docs/generated/tests-unit-t3422_dispatch_seeds_focus) | tests_by | T-3422 — dispatch pre-seeds the worker's session-scoped focus file. |

## Related

### Tasks
- T-798: Shellcheck cleanup: remaining peripheral agent scripts
- T-822: Complete fw_config migration — remaining hardcoded settings in hooks and lib scripts
- T-843: Fix TermLink cleanup killing active dispatch workers
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements
- T-972: Pickup: TermLink cleanup kills active dispatch workers — fw termlink cleanup treats running workers as orphans because they lack exit_code file (from 999-Agentic-Engineering-Framework)

---
*Auto-generated from Component Fabric. Card: `agents-termlink-termlink.yaml`*
*Last verified: 2026-03-23*
