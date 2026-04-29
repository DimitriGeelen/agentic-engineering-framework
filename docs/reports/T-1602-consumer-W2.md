# Consumer Sweep — Group W2
**Consumers:** 3 reviewed
**Summary:** 0 in-sync, 1 stale, 2 unknown (pinned ahead of framework HEAD), 3 with-uncommitted-changes
**Reviewer:** TermLink consumer-sweep worker W2 under T-1602
**Date:** 2026-04-29

**Framework HEAD:** 1.5.167 (`/opt/999-Agentic-Engineering-Framework/VERSION`)

---

## /opt/052-KCP
- **Pinned framework:** 1.5.307 (`.framework.yaml: version`, `upgraded_from: 1.5.16`, `last_upgrade: 2026-04-25T16:18:59Z`)
- **Vendored framework version:** 1.5.307 (`.agentic-framework/VERSION`)
- **Consumer's own VERSION:** n/a (no top-level VERSION file)
- **Branch:** main
- **Git status:** 201 modified (entire `.agentic-framework/` tree dirty — vendored sync never committed), 0 untracked
- **Active tasks:** 1
- **Recent commits:**
  - `78a9534` T-012: fw upgrade — sync framework v1.5.16
  - `9a16741` T-012: fw upgrade — sync framework v1.5.5 improvements
  - `2876bb9` T-012: fw upgrade — perf cache + YAML fixes
- **Drift verdict:** unknown — pinned 1.5.307 is *higher* than framework HEAD (1.5.167); version-pin anomaly (rollback or upgraded from a different framework source)
- **Recommendation:** investigate-uncommitted-changes (and reconcile version anomaly)
- **Notes:** Massive uncommitted diff across `.agentic-framework/agents/**`, `bin/fw`, `bin/fw-shim`, `bin/watchtower.sh`, generated component docs, etc. Pattern matches a `fw upgrade` run that ran but was never committed. Last commit subjects are still about v1.5.16 / v1.5.5 — many upgrades have happened on disk since.

## /opt/053-ntfy
- **Pinned framework:** 1.5.307 (`.framework.yaml: version`, `upgraded_from: 1.5.16`, `last_upgrade: 2026-04-25T16:19:00Z`)
- **Vendored framework version:** 1.5.307 (`.agentic-framework/VERSION`)
- **Consumer's own VERSION:** n/a (no top-level VERSION file)
- **Branch:** main
- **Git status:** 201 modified (identical pattern to KCP — entire vendored framework dirty), 0 untracked
- **Active tasks:** 6
- **Recent commits:**
  - `072e537c` T-012: fw upgrade — sync framework v1.5.16
  - `0dcdb716` T-012: fw upgrade — sync framework v1.5.5 improvements
  - `1d58c895` T-012: fw upgrade — perf cache + YAML fixes
- **Drift verdict:** unknown — pinned 1.5.307 > framework HEAD 1.5.167 (same anomaly as KCP)
- **Recommendation:** investigate-uncommitted-changes (and reconcile version anomaly)
- **Notes:** Same uncommitted-vendored-upgrade pattern as KCP. Both projects upgraded within one minute of each other (16:18 / 16:19 on 2026-04-25) and neither committed. Suggests a batch `fw upgrade` job that did not run `git add/commit` afterwards.

## /opt/050-email-archive
- **Pinned framework:** 1.5.133 (`.framework.yaml: version`, `upgraded_from: 1.5.477`, `last_upgrade: 2026-04-28T16:30:00Z`)
- **Vendored framework version:** 1.5.133 (`.agentic-framework/VERSION`)
- **Consumer's own VERSION:** 0.48.1 (consumer app version, unrelated to framework)
- **Branch:** pen-dev
- **Git status:** 24 modified, 0 untracked. Mostly `.context/working/*` runtime state (`.budget-status`, `.session-metrics.yaml`, `.tool-counter`, `focus.yaml`, etc.), plus `.context/project/{assumptions,learnings}.yaml`, `.context/bypass-log.yaml`, `CLAUDE.md.bak`, `VERSION`, `node_modules/.package-lock.json`. One deletion: `.context/working/.tier0-approval.pending`.
- **Active tasks:** 42
- **Recent commits:**
  - `168d25c1` T-1218: Bump deploy timeout 900s → 1500s
  - `ca83fb83` T-1218: Task housekeeping — sync status updates from S-2026-0428-2330
  - `b5a442a6` T-005: Session handover S-2026-0428-2330
- **Drift verdict:** stale — 1.5.133 is 34 patch versions behind framework HEAD 1.5.167 (`1.5.167 − 1.5.133`)
- **Recommendation:** upgrade-needed (and commit/clean working state before upgrading)
- **Notes:** On non-default branch `pen-dev`. `upgraded_from: 1.5.477` in `.framework.yaml` is suspicious (downgrade pattern: previously synced from a 1.5.477 source, now pinned at 1.5.133 — same kind of source-of-truth confusion as KCP/ntfy in the opposite direction). 42 active tasks is heavy backlog. Working state is mostly normal session churn but `CLAUDE.md.bak` (renamed backup) and `VERSION` modifications stand out as non-runtime.

---

## Cross-cutting observations
1. **Version-pin anomaly across the fleet:** KCP and ntfy pin 1.5.307 (above HEAD), email-archive pins 1.5.133 (below HEAD) with `upgraded_from: 1.5.477`. The framework's `VERSION` numbering is not behaving as a monotonic source of truth across consumers — likely multiple framework checkouts pushing different version sequences, or a rollback in the framework repo. Worth investigating before any further fleet-wide upgrade.
2. **Identical 201-file dirty diff in KCP and ntfy:** strongly suggests a scripted batch upgrade that succeeded mechanically but skipped the commit step. Whatever ran the 16:18/16:19 upgrade pair on 2026-04-25 needs the commit-after-upgrade step audited.
3. **No project in this group is in-sync.** All three need attention before they can be considered healthy.
