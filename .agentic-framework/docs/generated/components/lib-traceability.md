# traceability

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/traceability.sh`

## What It Does

lib/traceability.sh — commit-traceability predicates (T-2851)
Single definition of the predicate. Sourced by:
- agents/audit/audit.sh                         (the P-002 traceability check)
- tests/unit/audit_root_commit_traceability.bats
It lives here rather than inline in the audit because the regression suite has
to run the REAL predicate — a test that re-types the producer's expression into
a local helper only ever checks the shape its author already had in mind
(L-533, from the T-2729/T-2730/T-2731 escape family).
Usage: source "$FRAMEWORK_ROOT/lib/traceability.sh"
trace_is_root_commit "$repo_dir" "$sha"   # rc 0 = root commit

---
*Auto-generated from Component Fabric. Card: `lib-traceability.yaml`*
*Last verified: 2026-08-07*
