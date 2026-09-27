# resolver

> Resolver — workflow lookup, prompt assembly, variant selection, telemetry.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/resolver.py`

## What It Does

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [spawn](/docs/generated/lib-spawn) | calls | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |
| [bvp](/docs/generated/lib-bvp) | calls | lib/bvp.sh — Business Value Points (BVP) read-only CLI |
| [keylock-py](/docs/generated/lib-keylock-py) | uses | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [spawn](/docs/generated/lib-spawn) | uses | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |
| [worker_identity](/docs/generated/lib-worker_identity) | uses | worker_identity — the git identity a dispatch-spawned worker commits under (T-2917). |
| [value-drivers](/docs/generated/policy-value-drivers) | calls | BVP value-driver registry (T-1918, arc-006): constitutional directives D1-D4 plus free drivers with weights, rubrics, and retire_when conditions. Drives BVP scoring, ranking, the estimator worker, and the audit retire_when advisory rail. |

## Used By (21)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver-shim](/docs/generated/lib-resolver-sh) | called_by | Thin shell shim that routes `fw resolver` invocations to lib/resolver.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [test_resolver](/docs/generated/tests-unit-test_resolver) | called_by | T-1696: Unit tests for lib/resolver.py. |
| [spawn](/docs/generated/lib-spawn) | called_by | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |
| [pause_resolve](/docs/generated/lib-pause_resolve) | uses_by | Pause re-dispatch chain — capture operator's answer + fire a retry via Resolver. |
| [workflow_lint](/docs/generated/lib-workflow_lint) | called_by | Workflow schema linter for `.context/project/workflows/*.yaml`. |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | T-1946 — Worker-kinds parity check helper. |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | uses_by | T-1946 — Worker-kinds parity check helper. |
| [test_resolver_run](/docs/generated/tests-unit-test_resolver_run) | called_by | T-1774: Unit tests for `fw resolver run` CLI integration. |
| [escalation-scan-v0.5](/docs/generated/tools-escalation-scan-v0-5) | called_by | T-1727 — Layer B v0.5: per-candidate LLM augmentation of escalation-scan v0. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [ask-py](/docs/generated/lib-ask-py) | called_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |
| [ask-py](/docs/generated/lib-ask-py) | uses_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | uses_by | workflow_coverage — audit-time check for workflow → dispatcher coverage. |
| [t2915_resolver_inflight_expiry](/docs/generated/tests-unit-t2915_resolver_inflight_expiry) | called_by | T-2915: the resolver's in-flight latch never expired — a dispatch row with no terminal_event excluded its task from the loop forever, because `_inflight_task_ids()` had no age bound. |
| [t2915_resolver_inflight_expiry](/docs/generated/tests-unit-t2915_resolver_inflight_expiry) | tests_by | T-2915: the resolver's in-flight latch never expired — a dispatch row with no terminal_event excluded its task from the loop forever, because `_inflight_task_ids()` had no age bound. |
| [t2916_stall_guard_coverage](/docs/generated/tests-unit-t2916_stall_guard_coverage) | called_by | T-2916 — the stall guard must JUDGE, not merely run. |
| [t2916_stall_guard_coverage](/docs/generated/tests-unit-t2916_stall_guard_coverage) | tests_by | T-2916 — the stall guard must JUDGE, not merely run. |
| [t3030_two_writer_guard](/docs/generated/tests-unit-t3030_two_writer_guard) | called_by | T-3030 / G-083: the autonomous dispatch loop and an interactive session share one working tree. These tests pin the guard that separates them, and the provenance record that makes a worker's writes attributable afterwards. |
| [t3030_two_writer_guard](/docs/generated/tests-unit-t3030_two_writer_guard) | tests_by | T-3030 / G-083: the autonomous dispatch loop and an interactive session share one working tree. These tests pin the guard that separates them, and the provenance record that makes a worker's writes attributable afterwards. |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | called_by | T-1773: Unit tests for lib/spawn.py. |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | called_by | workflow_coverage — audit-time check for workflow → dispatcher coverage. |

---
*Auto-generated from Component Fabric. Card: `lib-resolver.yaml`*
*Last verified: 2026-05-03*
