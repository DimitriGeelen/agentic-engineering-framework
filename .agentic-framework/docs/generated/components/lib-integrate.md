# integrate

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/integrate.py`

## What It Does

── Un-partitionable file taxonomy (T-2397 §3.2) ────────────────────────────
Each class maps to a join strategy that is NOT `git merge`. Order matters:
the first matching rule wins, so put specific paths before broad ones.
A rule is (predicate, class, strategy, needs_human). `needs_human` is the

---
*Auto-generated from Component Fabric. Card: `lib-integrate.yaml`*
*Last verified: 2026-06-14*
