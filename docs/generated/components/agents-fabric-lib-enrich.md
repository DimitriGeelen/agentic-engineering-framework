# enrich

> Fabric enrichment engine — auto-detect dependency edges from source analysis.

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/enrich.py`

## What It Does

T-3430: the describe pass. Imported by path because enrich.py is run as a
script from an arbitrary cwd, so a plain `import describe` is not reliable.

## Dependencies (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [shared](/docs/generated/web-shared) | calls | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [govd_policy](/docs/generated/lib-govd_policy) | calls | govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [arc](/docs/generated/lib-arc) | calls | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [handover](/docs/generated/agents-handover-handover) | calls | Handover Agent - Mechanical Operations |
| [yield-point](/docs/generated/agents-dispatch-yield-point) | calls | arc-011 M1 harness yield-point: cooperative-poll safety net that reads .context/working/.dispatch-flag and refuses conflicting writes during parallel dispatch (T-2338). |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |
| [pause](/docs/generated/lib-pause) | calls | Thin shim — routes `fw pause` to lib/pause_cli.py. Origin: T-1809 (dispatch-safety slice 5). |
| [worktree](/docs/generated/lib-worktree) | calls | lib/worktree.sh — fw worktree topology observability. |
| [check-inception-schema](/docs/generated/agents-context-check-inception-schema) | calls | T-2188: inception frontmatter schema validation hook (bash wrapper for Python). The fw hook dispatcher loads .sh files; logic lives in check-inception-schema.py. |
| [describe](/docs/generated/agents-fabric-lib-describe) | uses | Derive a component card's `purpose` and `subsystem` from the source file itself. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t2457_fabric_atomic_card_write](/docs/generated/tests-unit-t2457_fabric_atomic_card_write) | tests_by | T-2457 / OBS-080: fabric card writes must be atomic. |
| [test_enrich_unresolved_targets](/docs/generated/tests-unit-test_enrich_unresolved_targets) | called_by | T-2736 — enrich must not drop unresolvable and ignorable edges through one silent branch. |
| [test_t3430_enrich_describe](/docs/generated/tests-unit-test_t3430_enrich_describe) | called_by | T-3430 — `fw fabric enrich --describe`: fill the placeholders, never overwrite. |

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-enrich.yaml`*
*Last verified: 2026-09-03*
