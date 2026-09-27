# task-parked

> task-parked.sh — the SINGLE reader for "is this task deliberately parked?"

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/task-parked.sh`

## What It Does

task-parked.sh — the SINGLE reader for "is this task deliberately parked?"
T-3511 (OBS-547). Extracted from lib/branch-hygiene.sh:_bh_governing_task, which
T-3510 introduced one commit earlier, rather than writing a second copy for the
pre-merge gate.
Why extraction and not a second copy: arc membership reached FIVE independent
implementations of one predicate in this repo, three of which disagreed about the
legacy tag form, and the audit rail meant to catch that could only see the shell
ones (OBS-546). The cost of that divergence was a full day of repair on
2026-09-26. Parked-ness is now read in two places — a reporting rail and a
blocking gate — which is exactly the moment the second implementation usually

---
*Auto-generated from Component Fabric. Card: `lib-task-parked.yaml`*
*Last verified: 2026-09-26*
