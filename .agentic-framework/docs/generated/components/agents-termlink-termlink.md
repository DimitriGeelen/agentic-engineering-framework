# termlink

> TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary.

**Type:** script | **Subsystem:** unknown | **Location:** `agents/termlink/termlink.sh`

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

The Task tool and TermLink dispatch are two different mechanisms for parallel work. **Choose based on the work type:**

| Factor | Task tool agent | TermLink dispatch (`fw termlink dispatch`) |
|--------|----------------|---------------------------------------------|
| Edit/Write tools | Yes (sub-agent) | Yes (spawns full `claude -p` worker) |
| Context isolation | No (shares parent context window) | Yes (independent process, zero context cost) |
| Max parallel | 5 (hard limit) | Unlimited (real OS processes) |
| Observable from outside | No | Yes (attach, stream, output) |
| Survives context

*(truncated — see CLAUDE.md for full section)*

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [ollama-tool-loop](/docs/generated/tools-ollama-tool-loop) | calls | TODO: describe what this component does |

## Used By (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [termlink](/docs/generated/tests-unit-termlink) | tested_by | Unit tests for agents/termlink/termlink.sh (8 tests) |
| [termlink](/docs/generated/tests-unit-termlink) | called_by | Unit tests for agents/termlink/termlink.sh (8 tests) |
| [termlink](/docs/generated/tests-unit-termlink) | tests_by | Unit tests for agents/termlink/termlink.sh (8 tests) |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | called_by | TODO: describe what this component does |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | tests_by | TODO: describe what this component does |
| [test_workflow_env_isolation](/docs/generated/tests-unit-test_workflow_env_isolation) | called_by | TODO: describe what this component does |
| [test_workflow_env_isolation](/docs/generated/tests-unit-test_workflow_env_isolation) | tests_by | TODO: describe what this component does |
| [test_termlink_dispatch_task_type](/docs/generated/tests-unit-test_termlink_dispatch_task_type) | called_by | Unit tests for fw termlink dispatch/spawn orchestrator-substrate wiring (T-1643/W1-W4) — pins _derive_task_type, _resolve_dispatch_model fallback chain, --task-type flag handlers in cmd_spawn/cmd_dispatch, and meta.json schema (task_type/model_used/fallback_used). |
| [orchestrator](/docs/generated/web-blueprints-orchestrator) | called_by | TODO: describe what this component does |
| [ollama_loop](/docs/generated/lib-ollama_loop) | called_by | TODO: describe what this component does |

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
