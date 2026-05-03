# Consumer Sweep — Group W1
**Consumers:** 3 reviewed
**Summary:** 0 in-sync, 0 stale, 3 unknown (consumer pin ahead of framework HEAD), 3 with-uncommitted-changes
**Reviewer:** TermLink consumer-sweep worker W1 under T-1602
**Date:** 2026-04-29

## Cross-cutting anomaly

All three consumers pin framework `version: 1.5.307` in `.framework.yaml` and carry `.agentic-framework/VERSION = 1.5.307`, but the framework repo at `/opt/999-Agentic-Engineering-Framework` is at HEAD `1.5.167`. Consumer pins are ~140 patch versions AHEAD of framework HEAD. This is anomalous — possible causes: framework HEAD rolled back, version-numbering scheme changed, or consumers were synced from an external/upstream source. Drift verdict for all three is **unknown (consumer ahead of HEAD)** rather than stale. Worth a framework-level investigation, not a per-consumer fix.

All three also share `last_upgrade: 2026-04-25T16:18–16:19Z` — they were swept together (likely by `fw upgrade` against a remote upstream), so the anomaly is consistent and structural, not random.

---

## /opt/001-sprechloop
- **Pinned framework:** 1.5.307 (`upgraded_from: 1.5.16`, `last_upgrade: 2026-04-25T16:18:47Z`)
- **Vendored framework version:** 1.5.307
- **Consumer's own VERSION:** n/a (no top-level VERSION file)
- **Branch:** develop
- **Git status:** 89 modified, 111 untracked (200 total lines) — overwhelmingly inside `.agentic-framework/` (vendored agents, bin/fw, docs/generated, etc.)
- **Active tasks:** 8
- **Recent commits:**
  - `aa93348 T-012: fw upgrade — sync framework v1.5.16`
  - `83f6d27 T-012: fw upgrade — sync framework v1.5.5 improvements`
  - `464d6a9 T-012: fw upgrade — perf cache + YAML fixes`
- **Drift verdict:** unknown (consumer pin 1.5.307 vs framework HEAD 1.5.167 — pin ahead by 140 patch)
- **Recommendation:** investigate-uncommitted-changes
- **Notes:** The dirty state is dominated by uncommitted edits inside `.agentic-framework/*` (89 M files: audit, context, fabric, git, handover, monitor, observe, task-create, bin/fw, watchtower.sh, generated component docs, etc.). Last vendored-framework commit on this branch is from `T-012: fw upgrade — sync framework v1.5.16` — meaning the v1.5.307 sync (logged in `.framework.yaml` `last_upgrade: 2026-04-25`) was never committed. The vendored tree has been re-synced on disk but the consumer never committed the sync. This is the same shape of staleness as the other two consumers.

## /opt/002-Claude-Partner-Network
- **Pinned framework:** 1.5.307 (`upgraded_from: 1.4.1516`, `last_upgrade: 2026-04-25T16:18:56Z`)
- **Vendored framework version:** 1.5.307
- **Consumer's own VERSION:** n/a
- **Branch:** master
- **Git status:** 4 modified, 3 untracked (7 total lines)
- **Active tasks:** 5
- **Recent commits:**
  - `e03460f T-005: Session handover S-2026-0421-1301`
  - `7c3b38e T-005: Enrich handover S-2026-0421-0430 with session narrative`
  - `841ddbe T-005: Session handover S-2026-0421-0430`
- **Drift verdict:** unknown (consumer pin 1.5.307 vs framework HEAD 1.5.167)
- **Recommendation:** investigate-uncommitted-changes
- **Notes:** Cleanest of the three. Modifications are limited to `.claude/commands/resume.md`, `.framework.yaml` (the pin bump itself), `.tasks/active/T-011-...md`, and `CLAUDE.md`; untracked = two `.bak` files plus `.context/audits/upgrades.yaml`. The nested `agentic-engineering-framework/` and `termlink/` dirs are explicitly out of W1 scope. No structural breakage.

## /opt/termlink
- **Pinned framework:** 1.5.307 (`upgraded_from: 1.5.16`, `last_upgrade: 2026-04-25T16:19:05Z`)
- **Vendored framework version:** 1.5.307
- **Consumer's own VERSION:** 0.9.1562 (this is the TermLink product version, separate from the framework pin)
- **Branch:** main
- **Git status:** 27 modified, 56 deleted, 68 untracked (151 total lines)
- **Active tasks:** 8
- **Recent commits:**
  - `8e1f8c09 T-1300/T-1301: closed via Watchtower — fix verify-chain hang + episodic generation`
  - `f6d47ebe T-1300/T-1301: add Human ACs (rubber-stamp) — unblocks Watchtower close`
  - `dcf6c1c0 T-1300/T-1301: live fleet A/B evidence on .107 — suppress vs warn`
- **Drift verdict:** unknown (consumer pin 1.5.307 vs framework HEAD 1.5.167)
- **Recommendation:** investigate-uncommitted-changes
- **Notes:** The 56 deleted files are almost entirely `.context/audits/cron/2026-04-2*.yaml` artefacts (cron audit log rotation/cleanup that hasn't been committed). Modified set spans `.agentic-framework/.context/working/.fleet-failure-state.json`, `.claude/settings.local.json`, `.context/audits/2026-04-28.yaml`, etc. — looks like ongoing operational state rather than feature work. No broken framework dir; `.agentic-framework/` exists and is populated. Healthy enough to operate; just dirty.

---

## Reviewer summary

The dominant pattern is a coordinated `fw upgrade` to v1.5.307 on 2026-04-25 across all three consumers, but (a) the framework HEAD here is 1.5.167 — 140 patch versions BEHIND the consumer pin, and (b) on at least 001-sprechloop the upgrade was syncd to disk but never committed. Single highest-leverage follow-up is at the framework level: reconcile why consumers are pinned to a higher version than the framework repo at this path, then decide whether to commit/squash the in-flight `.agentic-framework/*` edits in 001-sprechloop.
