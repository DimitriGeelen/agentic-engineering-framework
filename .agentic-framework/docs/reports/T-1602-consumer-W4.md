# Consumer Sweep — Group W4
**Consumers:** 3 reviewed
**Summary:** 0 in-sync, 0 stale, 3 ahead-of-HEAD, 3 with-uncommitted-changes
**Reviewer:** TermLink consumer-sweep worker W4 under T-1602
**Date:** 2026-04-29

## Cross-cutting observations

All three consumers in this group exhibit the **same anomaly pattern**:

1. Vendored `.agentic-framework/VERSION` is **1.5.307**, but framework HEAD is **1.5.167**. Consumers are *ahead* of the framework repo's current VERSION file — implies either (a) framework VERSION was rolled back, or (b) the 2026-04-25 `fw upgrade` synced from a different framework checkout. Worth investigating at framework level, not in consumers.
2. All three have a stalled `fw upgrade` from **2026-04-25**: hundreds of `.agentic-framework/*` modifications uncommitted, including `.agentic-framework/VERSION` itself (M).
3. The most recent **committed** activity in each repo is unrelated to the recent upgrade — all three top out at `T-012: fw upgrade — sync framework v1.5.16` and older.
4. Conclusion: the sync ran, files were copied in, but the commit step never happened. All three consumers are now in identical "uncommitted upgrade" state.

---

## /opt/051-Vinix24
- **Pinned framework:** 1.5.307 (`.framework.yaml` `version:`)
- **Vendored framework version:** 1.5.307 (working tree; `.agentic-framework/VERSION` is itself M-modified vs HEAD)
- **Consumer's own VERSION:** 0.1.180
- **Branch:** main
- **Git status:** 86 modified, 53 deleted, 2 untracked (141 total) — all paths inside `.agentic-framework/`
- **Active tasks:** 4
- **Recent commits:**
  - `b3811de` T-012: fw upgrade — sync framework v1.5.16
  - `35697dd` T-012: fw upgrade — sync framework v1.5.5 improvements
  - `6f77c4b` T-012: fw upgrade v1.5.575 — performance cache, learnings, inception artifacts
- **Drift verdict:** ahead-of-HEAD (vendored 1.5.307 > framework HEAD 1.5.167) — anomalous; requires framework-side investigation
- **Recommendation:** investigate-uncommitted-changes (stalled upgrade from 2026-04-25 needs to either commit or revert; do not run `fw upgrade` again until current sync is resolved)
- **Notes:** Deleted `__pycache__` files visible in status — normal cleanup artifacts of upgrade. `.framework.yaml` `last_upgrade: 2026-04-25T16:18:59Z` matches uncommitted state. `upgraded_from: 1.5.16` shows historical baseline, not last sync source.

## /opt/995_2021-kosten
- **Pinned framework:** 1.5.307 (`.framework.yaml` `version:`)
- **Vendored framework version:** 1.5.307 (working tree; `.agentic-framework/VERSION` is M-modified)
- **Consumer's own VERSION:** n/a (no top-level VERSION file)
- **Branch:** master
- **Git status:** 89 modified, 24 deleted, 111 untracked (224 total) — all paths inside `.agentic-framework/`
- **Active tasks:** 14
- **Recent commits:**
  - `39945ec` T-012: fw upgrade — sync framework v1.5.16
  - `16c5d8c` T-012: fw upgrade — sync framework v1.5.5 improvements
  - `f7d256b` T-012: fw upgrade — perf cache + YAML fixes
- **Drift verdict:** ahead-of-HEAD (vendored 1.5.307 > framework HEAD 1.5.167)
- **Recommendation:** investigate-uncommitted-changes (largest uncommitted-untracked count of the three — 111 new files from upgrade never staged; same root cause as Vinix24)
- **Notes:** Last upgrade `2026-04-25T16:19:02Z`. Highest untracked-file count in group, suggests the 1.5.307 sync added many new framework files this consumer did not previously have.

## /opt/025-WokrshopDesigner
- **Pinned framework:** 1.5.307 (`.framework.yaml` `version:`)
- **Vendored framework version:** 1.5.307 (working tree; `.agentic-framework/VERSION` is M-modified)
- **Consumer's own VERSION:** 1.1.17
- **Branch:** master
- **Git status:** 88 modified, 45 deleted, 112 untracked (245 total) — all paths inside `.agentic-framework/`
- **Active tasks:** 79
- **Recent commits:**
  - `c94e3f6` T-012: fw upgrade — sync framework v1.5.16
  - `feaf316` T-012: fw upgrade — sync framework v1.5.5 improvements
  - `be19706` T-012: fw upgrade — perf cache + YAML fixes
- **Drift verdict:** ahead-of-HEAD (vendored 1.5.307 > framework HEAD 1.5.167)
- **Recommendation:** investigate-uncommitted-changes (same stalled-upgrade pattern; also unusually high active-task backlog — 79 active tasks may indicate task hygiene drift, but that is out of scope for this read-only sweep)
- **Notes:** `upstream_repo: /opt/999-Agentic-Engineering-Framework` (the only consumer in this group with a local-path upstream rather than the GitHub repo). Last upgrade `2026-04-25T16:18:56Z`. Provider is `claude` (others are `generic`).

---

## Suggested follow-ups (for human, not for this worker)

1. **Framework-side**: confirm whether HEAD VERSION 1.5.167 is intentional or was rolled back. If consumers are correctly at 1.5.307, the framework's VERSION file likely needs to be re-set forward.
2. **Consumer-side**: each of the three needs the 2026-04-25 upgrade either committed (if intended) or reverted (if the upgrade is being redone). Same fix recipe applies to all three.
3. The identical pattern across all three (and likely across the rest of the cohort) suggests a systemic issue with how `fw upgrade` finalizes: it copies files but does not commit, leaving consumers in a half-state. Worth a Level-C tooling improvement.
