# Consumer Sweep — Group W3
**Consumers:** 3 reviewed
**Summary:** 0 in-sync, 0 stale, 3 unknown (version-mismatch), 3 with-uncommitted-changes
**Reviewer:** TermLink consumer-sweep worker W3 under T-1602
**Date:** 2026-04-29

---

## /opt/150-skills-manager
- **Pinned framework:** 1.5.307 (`.framework.yaml` `version:`, `last_upgrade: 2026-04-25T16:19:01Z`, `upgraded_from: 1.5.16`)
- **Vendored framework version:** 1.5.307 (`.agentic-framework/VERSION`)
- **Consumer's own VERSION:** n/a (no top-level `VERSION` file)
- **Branch:** master
- **Git status:** 96 modified, 283 deleted, 395 untracked (774 lines total) — heavily dirty state, almost entirely inside `.agentic-framework/`
- **Active tasks:** 18
- **Recent commits:**
  - `1a2cff7 T-012: fw upgrade — sync framework v1.5.16`
  - `56f6ca8 T-012: fw upgrade — sync framework v1.5.5 improvements`
  - `cfc770e T-012: fw upgrade — perf cache + YAML fixes`
- **Drift verdict:** unknown — consumer pinned/vendored at 1.5.307 but framework HEAD is 1.5.167. Numerically the consumer is *ahead* of the framework repo at this checkout, meaning the framework repo here is either on an older lineage/branch or the consumer was upgraded from a different framework checkout. Cannot classify as in-sync or stale without reconciling lineage.
- **Recommendation:** investigate-uncommitted-changes — the M/D/?? mix all under `.agentic-framework/` looks like a partially-applied upgrade or a vendor sync that left both new and old files coexisting. Also note `.agentic-framework.rollback/.agentic-framework` (per scope brief) — typical signature of an in-flight upgrade. Last commit was the v1.5.16 sync; nothing committed for the 1.5.307 sync that VERSION/`.framework.yaml` reflect.
- **Notes:** rollback artifact exists at `.agentic-framework.rollback/` (per scope brief, skipped). The 774 dirty paths are concentrated in `.agentic-framework/agents/`, `.agentic-framework/docs/generated/components/`, `.agentic-framework/bin/`, `.agentic-framework/lib/`. `last_upgrade` timestamp 2026-04-25 matches the dirty mtimes.

---

## /opt/openclaw-evaluation
- **Pinned framework:** 1.5.307 (`.framework.yaml` `version:`, `last_upgrade: 2026-04-25T16:19:04Z`, `upgraded_from: 1.5.16`, `provider: generic`)
- **Vendored framework version:** 1.5.307 (`.agentic-framework/VERSION`)
- **Consumer's own VERSION:** n/a (no top-level `VERSION` file)
- **Branch:** main
- **Git status:** 85 modified, 109 untracked (194 lines total) — moderately dirty, no deletions
- **Active tasks:** 37
- **Recent commits:**
  - `c9328fdad3 T-012: fw upgrade — sync framework v1.5.16`
  - `d5c70cea26 T-012: fw upgrade — sync framework v1.5.5 improvements`
  - `d016e79875 T-012: fw upgrade — perf cache + YAML fixes`
- **Drift verdict:** unknown — same lineage mismatch as 150 (consumer at 1.5.307, framework HEAD at 1.5.167).
- **Recommendation:** investigate-uncommitted-changes — last commit is v1.5.16 sync, but `.agentic-framework/VERSION` reads 1.5.307 with no commit covering the delta. The 85 modified + 109 untracked likely represent that uncommitted upgrade.
- **Notes:** `.agentic-framework.rollback/` directory exists (mentioned in scope as another rollback artifact pattern). `CLAUDE.md` is a symlink to `AGENTS.md`. 37 active tasks is high — second-largest of the three.

---

## /opt/3021-Bilderkarte-tool-llm
- **Pinned framework:** 1.5.307 (`.framework.yaml` `version:`, `last_upgrade: 2026-04-25T16:19:03Z`, `upgraded_from: 1.5.16`, `provider: generic`)
- **Vendored framework version:** 1.5.307 (`.agentic-framework/VERSION`)
- **Consumer's own VERSION:** 2.0.0 (top-level `VERSION` file)
- **Branch:** fix/stale-prompt-bug (NOT main/master)
- **Git status:** 91 modified, 769 deleted, 891 untracked (1751 lines total) — most dirty of the three by a wide margin
- **Active tasks:** 47 (highest in this group)
- **Recent commits:**
  - `b823771 T-560: add missing </script> closing tag in index.html`
  - `7de2664 T-012: fw upgrade — sync framework v1.5.16`
  - `9f112f8 T-012: fw upgrade — sync framework v1.5.5 improvements`
- **Drift verdict:** unknown — same 1.5.307 vs framework-HEAD-1.5.167 lineage mismatch.
- **Recommendation:** investigate-uncommitted-changes — sitting on a feature branch (`fix/stale-prompt-bug`) with 1751 dirty paths and an uncommitted framework upgrade on top. High risk of confusion when the bugfix branch is merged: framework changes will be entangled with the prompt-bug fix unless cleanly separated.
- **Notes:** `CLAUDE.md.bak` exists alongside `CLAUDE.md` (likely from upgrade). Active task count (47) is the largest in this group. Consumer has its own product semver (2.0.0) independent of framework version, which is correct usage.

---

## Cross-cutting observations (advisory only)

1. **All three consumers report `version: 1.5.307` but framework repo HEAD is `1.5.167`.** The framework checkout I'm running from cannot be the one that produced these upgrades. Either (a) framework HEAD is on an older branch and the upgrades came from a different lineage with higher version numbers, or (b) `version:` in `.framework.yaml` is being treated as a free-form field rather than a true pin against framework HEAD. This is a measurement/lineage problem — flagging for human reconciliation, not classifying any consumer as "stale" since "stale" implies behind, not ahead.
2. **All three have uncommitted state from the same `last_upgrade: 2026-04-25` event.** The 4-day-old upgrade has not been committed in any of them. A coordinated "commit + push" sweep across consumers may be warranted.
3. **None of the three would pass `fw upgrade --verify` cleanly** given the dirty state — but per HARD CONSTRAINTS this was not run.
