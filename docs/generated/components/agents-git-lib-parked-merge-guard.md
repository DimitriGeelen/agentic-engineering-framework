# parked-merge-guard

> parked-merge-guard.sh — refuse a merge whose source branch's governing task is deliberately parked (T-3511, prevention leg of OBS-547).

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/parked-merge-guard.sh`

## What It Does

parked-merge-guard.sh — refuse a merge whose source branch's governing task is
deliberately parked (T-3511, prevention leg of OBS-547).
Usage: parked-merge-guard.sh check     (exit 0 = allow, 1 = block, 2 = usage error)
ORIGIN. On 2026-09-26 a TermLink batch-merge worker merged four unlanded branches
into bleeding-edge. One was `t3487-remove-bvp-arc-approval-gate`, whose governing
task T-3487 was `captured` / `horizon: later` on an UNANSWERED Sovereign question.
The merge took the `fw arc close` identity gate — earned over four repeat
incidents (T-1670/T-1671) — off by default. No rule was broken and no gate was
bypassed: three locally-defensible decisions composed, because parking is recorded
in the TASK and a branch sweeper reads TOPOLOGY. T-3510 stopped the audit

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-parked-merge-guard.yaml`*
*Last verified: 2026-09-26*
