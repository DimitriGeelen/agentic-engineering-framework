---
id: T-1896
name: "Reviewer pattern human-ac-mechanical-signal — catch [REVIEW]-mis-class at task close (T-1878 B)"
description: >
  Reviewer pattern human-ac-mechanical-signal — catch [REVIEW]-mis-class at task close (T-1878 B)

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [build, ac-routing, governance, reviewer, T-1878-B]
components: [policy/anti-patterns.yaml, lib/reviewer/static_scan.py]
related_tasks: [T-1878, T-1811, T-1443, T-1894, T-1895]
arc_id: arc-grooming
created: 2026-05-18T08:02:39Z
last_update: 2026-05-18T08:16:47Z
date_finished: null
---

# T-1896: Reviewer pattern human-ac-mechanical-signal — catch [REVIEW]-mis-class at task close (T-1878 B)

## Context

T-1878 inception (GO recorded) found a 13% mis-classification rate where `[REVIEW]` Human ACs are filed with deterministic mechanical Expected clauses (grep/file-exists/command-output) that should be `[REVIEWER]` Agent ACs. T-1894 manually re-classed 4 such ACs on arc-grooming partial-completes — third manual remediation of the same class after T-954 + T-1811.

This is intervention **B** of T-1878's A+B plan — the **structural catch** that fires at task close when the agent has skipped intervention A (template/CLAUDE.md nudge).

Sibling T-1895 (intervention A) does the AC-author-time nudge via template + CLAUDE.md. Together A+B caught 4/4 of T-1878's validation cases in the spike (Spike 4).

Full reasoning: `docs/reports/T-1878-routing-default-bias.md`.

## Acceptance Criteria

### Agent
- [ ] New pattern `human-ac-mechanical-signal` added to `policy/anti-patterns.yaml` with: id, name, severity (`partial-lie`), confidence (`heuristic`), needs_human (`no`), description citing T-1878/T-1894 precedent, fix-hint pointing at [REVIEWER] conversion rule
- [ ] Detector implemented in `lib/reviewer/static_scan.py` — scans each `[REVIEW]`-prefixed Human AC's Expected clause for mechanical signals: `grep`, `wc`, exit-code patterns, file-exists checks, `curl -sf`, deterministic command output strings; emits CONCERN finding with the AC line number + Expected clause excerpt
- [ ] Detector also recognises taste anti-signals (`feels`, `reads`, `clean`, `tone`, `intuitive`, `natural`) to AVOID false positives on legitimate [REVIEW] ACs — finding only fires when mechanical signals present AND taste signals absent
- [ ] Bats test `tests/unit/reviewer_human_ac_mechanical_signal.bats`: positive cases must fire on T-1851 / T-1857 / T-1890 / T-1893 (the four T-1894 re-class victims); negative cases must NOT fire on T-1852 / T-1853 / T-1891 (taste-genuine [REVIEW]s)
- [ ] Override mechanism reuses existing `bin/fw reviewer override` infrastructure (T-1443) — `fw reviewer override add T-XXX --pattern human-ac-mechanical-signal --ac N --reason "..." --ttl 90` suppresses the finding for that AC
- [ ] `## Verification` block on this task passes (reviewer self-scan + bats)

### Human
- [ ] [REVIEW] Reviewer finding wording reads usefully — when the detector fires on a real task, the operator gets a clear nudge ("AC #N looks mechanical, consider [REVIEWER] + Verification command") not just a noisy flag
  **Steps:**
  1. After build: pick a current `[REVIEW]` Human AC that should be `[REVIEWER]` (or use one of the T-1894 victims as a regression case)
  2. Run `bin/fw reviewer T-XXX`
  3. Inspect the CONCERN finding text
  **Expected:** Finding text names the AC by line/index, quotes a short Expected-clause excerpt, and references the [REVIEWER] conversion rule. Not a wall of text; not cryptic.
  **If not:** Note where the wording falls flat and iterate

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# (To be enabled when this task is started — currently captured/next.)
#
# When ready to work, replace these placeholders:
# command -v python3 >/dev/null && python3 -m pytest tests/unit/test_reviewer_human_ac_mechanical_signal.py -q
# bats tests/unit/reviewer_human_ac_mechanical_signal.bats
# bin/fw reviewer T-1851 2>&1 | grep -q "human-ac-mechanical-signal"
# bin/fw reviewer T-1852 2>&1 | grep -v -q "human-ac-mechanical-signal" || true   # negative case
# bin/fw enforcement baseline-check 2>&1 | grep -q "OK"

## RCA

<!-- Non-bug-class task — RCA section optional. -->

## Evolution

<!-- Arc-tagged build task (arc-grooming). Fill at slice boundaries / before work-completed.

     Format:
       ### YYYY-MM-DD — [topic]
       - **What changed:**
       - **Plan impact:**
       - **Triggered:**
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives. -->

## Updates

### 2026-05-18T08:02:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1896-reviewer-pattern-human-ac-mechanical-sig.md
- **Context:** Initial task creation

### 2026-05-18T08:18:00Z — ac-fill [agent]
- **Action:** Filled placeholder ACs with T-1878 GO spec (intervention B); demoted to horizon: next; tagged arc:arc-grooming; populated components + related_tasks
- **Context:** T-1896 was filed as part of T-1878 closeout but never had ACs written — last session's wrap-mode budget critical prevented filling. This unblocks build-readiness gate G-020 by giving the task real ACs instead of placeholders.
