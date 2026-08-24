# resolver

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/resolver.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [patterns-data](/docs/generated/patterns-data) | calls | Stores failure, success, and workflow patterns discovered during project work. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [spawn](/docs/generated/lib-spawn) | calls | TODO: describe what this component does |
| [bvp](/docs/generated/lib-bvp) | calls | TODO: describe what this component does |
| [keylock-py](/docs/generated/lib-keylock-py) | uses | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [spawn](/docs/generated/lib-spawn) | uses | TODO: describe what this component does |

## Used By (20)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver-shim](/docs/generated/lib-resolver-sh) | called_by | Thin shell shim that routes `fw resolver` invocations to lib/resolver.py. Per D-073: shim does PROJECT_ROOT export + argv passthrough only — no script-level logic. |
| [test_resolver](/docs/generated/tests-unit-test_resolver) | called_by | TODO: describe what this component does |
| [spawn](/docs/generated/lib-spawn) | called_by | TODO: describe what this component does |
| [pause_resolve](/docs/generated/lib-pause_resolve) | uses_by | TODO: describe what this component does |
| [workflow_lint](/docs/generated/lib-workflow_lint) | called_by | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | called_by | TODO: describe what this component does |
| [worker_kinds_parity](/docs/generated/lib-worker_kinds_parity) | uses_by | TODO: describe what this component does |
| [test_resolver_run](/docs/generated/tests-unit-test_resolver_run) | called_by | TODO: describe what this component does |
| [escalation-scan-v0.5](/docs/generated/tools-escalation-scan-v0-5) | called_by | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [ask-py](/docs/generated/lib-ask-py) | called_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |
| [ask-py](/docs/generated/lib-ask-py) | uses_by | Python implementation of fw ask subcommand (sibling of lib/ask.sh) |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | uses_by | TODO: describe what this component does |
| [t2915_resolver_inflight_expiry](/docs/generated/tests-unit-t2915_resolver_inflight_expiry) | called_by | TODO: describe what this component does |
| [t2915_resolver_inflight_expiry](/docs/generated/tests-unit-t2915_resolver_inflight_expiry) | tests_by | TODO: describe what this component does |
| [t2916_stall_guard_coverage](/docs/generated/tests-unit-t2916_stall_guard_coverage) | called_by | TODO: describe what this component does |
| [t2916_stall_guard_coverage](/docs/generated/tests-unit-t2916_stall_guard_coverage) | tests_by | TODO: describe what this component does |
| [t3030_two_writer_guard](/docs/generated/tests-unit-t3030_two_writer_guard) | called_by | TODO: describe what this component does |
| [t3030_two_writer_guard](/docs/generated/tests-unit-t3030_two_writer_guard) | tests_by | TODO: describe what this component does |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-resolver.yaml`*
*Last verified: 2026-05-03*
