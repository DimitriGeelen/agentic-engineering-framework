# expand_patterns

> TODO: describe what this component does

**Type:** script | **Subsystem:** component-fabric | **Location:** `agents/fabric/lib/expand_patterns.py`

## What It Does

Fabric — shared pattern expansion with exclude support (T-1842).
Origin: Penelope (email-archive) T-1458 via framework:pickup offsets 5/6.
Both do_scan (register.sh) and do_drift (drift.sh) read watch-patterns.yaml
patterns: only and silently drop exclude:. In projects with node_modules/
the scanner descended into the excluded tree and produced 5946/6339 (93.8%)
junk cards, undetected for ~22 days because the bug appears in both code
paths identically.
Centralising the expansion here means the exclude predicate has one source
of truth — the same bug class cannot recur independently in register.sh and
drift.sh again.

---
*Auto-generated from Component Fabric. Card: `agents-fabric-lib-expand_patterns.yaml`*
*Last verified: 2026-05-14*
