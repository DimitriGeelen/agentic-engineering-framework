# single-host-parallel-demo

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/dispatch/single-host-parallel-demo.sh`

## What It Does

T-2341 (arc-011 M1 §4) — single-host parallel demo (headline_mechanic-firing).
Composes arc-011 M1 §1+§3+§6 (+§2) into one end-to-end demo:
1. Create sandbox with two file-write-only task fixtures whose write_sets
are disjoint (T-DEMO-A → docs/reports/_demo/A.md,
T-DEMO-B → docs/reports/_demo/B.md).
2. Verify orchestrator-graph (T-2339) emits BOTH as `parallel`.
3. Verify pre-flight gate (T-2340) APPROVES both (no in-flight overlap).
4. Spawn two bash-stub workers via background `&`, each:
- records dispatch start row to sandbox dispatches.jsonl (outcome="")
- sleeps briefly (creates overlap window)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `agents-dispatch-single-host-parallel-demo.yaml`*
*Last verified: 2026-06-11*
