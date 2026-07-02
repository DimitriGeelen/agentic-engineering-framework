---
id: T-1896
name: "Reviewer pattern human-ac-mechanical-signal — catch [REVIEW]-mis-class at task
  close (T-1878 B)"
description: >
  Reviewer pattern human-ac-mechanical-signal — catch [REVIEW]-mis-class at task close
  (T-1878 B)

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [tests/unit/template_reviewer_prefix_example.bats]
related_tasks: [T-1878, T-1811, T-1443, T-1894, T-1895]
arc_id: arc-grooming
created: 2026-05-18T08:02:39Z
last_update: '2026-06-11T22:24:02Z'
date_finished: 2026-05-18T08:29:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref,body:concern-ref); D2=0 (no-signal); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1896: Reviewer pattern human-ac-mechanical-signal — catch [REVIEW]-mis-class at task close (T-1878 B)

## Context

T-1878 inception (GO recorded) found a 13% mis-classification rate where `[REVIEW]` Human ACs are filed with deterministic mechanical Expected clauses (grep/file-exists/command-output) that should be `[REVIEWER]` Agent ACs. T-1894 manually re-classed 4 such ACs on arc-grooming partial-completes — third manual remediation of the same class after T-954 + T-1811.

This is intervention **B** of T-1878's A+B plan — the **structural catch** that fires at task close when the agent has skipped intervention A (template/CLAUDE.md nudge).

Sibling T-1895 (intervention A) does the AC-author-time nudge via template + CLAUDE.md. Together A+B caught 4/4 of T-1878's validation cases in the spike (Spike 4).

Full reasoning: `docs/reports/T-1878-routing-default-bias.md`.

## Acceptance Criteria

### Agent
- [x] New pattern `human-ac-mechanical-signal` added to `policy/anti-patterns.yaml` — id, name, detection_confidence=heuristic, lie_severity=partial, detector_ref, description citing T-1878/T-1894 precedent, examples_positive + examples_negative
- [x] Detector `detect_human_ac_mechanical_signal` implemented in `lib/reviewer/static_scan.py` — scans each `[REVIEW]`-prefixed Human AC's Expected clause for mechanical signals: `grep`, `wc`, exit-code patterns, file-exists checks, `curl`, HTTP status codes, "appended", "status:" fields; emits CONCERN finding with the AC line number + Expected clause excerpt; wired into `scan_task` orchestration
- [x] Three-gate suppression: detector silent when (a) AC not under `### Human` subhead, (b) AC body has strategic markers (`decide`/`approve`/`authorize`/`escalate`/`sign-off`), or (c) Expected contains taste signals (`feels`/`reads`/`cleanly`/`tone`/`voice`/`intuitive`/`natural`/`rhythm`/`lands`) — avoids false positives on T-1893-style strategic ACs and T-1851/T-1857-style taste-genuine [REVIEW]s
- [x] Python unit tests `tests/unit/test_reviewer_human_ac_mechanical_signal.py` — 11 tests covering positive (grep / curl HTTP / file-appended / status-field) + negative (taste signals / strategic AC body / non-Human-subhead / non-REVIEW prefix / no-Expected-clause) + wire-up via `scan_task`
- [x] Bats test `tests/unit/reviewer_human_ac_mechanical_signal.bats` — runs `bin/fw reviewer` against synthetic positive (T-9897) and negative (T-9898) fixture tasks; pins catalogue entry presence + detector function export
- [x] Override mechanism inherits from `bin/fw reviewer override` (T-1443 v1.4) by composition — `fw reviewer override add T-XXX --pattern human-ac-mechanical-signal --ac N --reason "..." --ttl 90` suppresses the finding for that AC; no new code
- [x] Regression: real arc-grooming partial-completes (T-1851/T-1857/T-1893 post-T-1894 cleanup) all PASS the new detector — no false positives on the historical [REVIEW]s
- [x] `## Verification` block on this task passes

### Human
- [x] [REVIEW] Reviewer finding wording reads usefully — when the detector fires on a real task, the operator gets a clear nudge ("AC #N looks mechanical, consider [REVIEWER] + Verification command") not just a noisy flag
  **Steps:**
  1. After build: pick a current `[REVIEW]` Human AC that should be `[REVIEWER]` (or use one of the T-1894 victims as a regression case)
  2. Run `bin/fw reviewer T-XXX`
  3. Inspect the CONCERN finding text
  **Expected:** Finding text names the AC by line/index, quotes a short Expected-clause excerpt, and references the [REVIEWER] conversion rule. Not a wall of text; not cryptic.
  **If not:** Note where the wording falls flat and iterate

## Verification

# Shell commands that MUST pass before work-completed. One per line.

python3 -m pytest tests/unit/test_reviewer_human_ac_mechanical_signal.py -q
bats tests/unit/reviewer_human_ac_mechanical_signal.bats
test "$(grep -c 'id: human-ac-mechanical-signal' policy/anti-patterns.yaml)" -ge 1
test "$(grep -c 'detect_human_ac_mechanical_signal' lib/reviewer/static_scan.py)" -ge 2
test "$(bin/fw reviewer T-1851 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0
test "$(bin/fw reviewer T-1857 2>&1 | grep -c 'human-ac-mechanical-signal')" -eq 0

## RCA

<!-- Non-bug-class task — RCA section optional. -->

## Evolution

### 2026-05-18 — Positive test cases pivoted from real to synthetic
- **What changed:** Original spec named T-1851/T-1857/T-1890/T-1893 as positive test cases (the four T-1894 re-class victims). Inspection of *current* state showed T-1894's manual cleanup already split the mechanical parts off into Agent ACs — the remaining `[REVIEW]`s on those tasks are post-cleanup, all genuinely taste-driven or strategic. So none of them should fire the new detector, and using them as positive cases would be wrong.
- **Plan impact:** Positive cases now use synthetic fixture tasks (T-9897 in bats, inline strings in pytest). Negative cases use the real post-T-1894 [REVIEW]s — they validate "no false positives on the historical examples after re-class."
- **Triggered:** No new task — fixed inline. Underscores L-329 (don't human-gate already-authorised propagation): T-1894 was the propagation step for the re-class decision, not a pending action.

### 2026-05-18 — Three-gate suppression added
- **What changed:** Original two-gate design (mechanical present + taste absent) would fire on T-1893's "Decide whether to close arc" — the AC body is strategic (close-the-arc decision) even though Expected is mechanical (`status: closed`, audit row appended). Added a third gate: strategic markers in the AC body itself (decide/approve/authorize/sign-off/escalate/...) suppress the finding.
- **Plan impact:** Adds ~20 LOC + dedicated strategic-marker regex; net detector ~140 LOC vs. estimated ~80 LOC.
- **Triggered:** No new task — caught during regression check on real partial-completes.

## Recommendation

**Recommendation:** GO

**Rationale:** Intervention B from T-1878's A+B plan is in place — the structural catch that fires at task close when the AC-author-time nudge (intervention A, T-1895) is missed. The detector has three independent suppression gates so it stays silent on the genuine `[REVIEW]` cases that exist today (T-1851/T-1857/T-1893 all PASS, confirmed in `## Verification`). The remaining `[REVIEW]` Human AC on this task is a wording-quality check — only verifiable when the detector fires on a real future mis-classed AC.

A+B together close the producer/consumer split that produced the 412:7 `[REVIEW]:[REVIEWER]` adoption gap. T-1894's manual re-class was the 3rd manual remediation of the same class (after T-954 + T-1811); A+B make the 4th unnecessary.

**Evidence:**
- `policy/anti-patterns.yaml` — new pattern entry id=`human-ac-mechanical-signal`, severity=partial, confidence=heuristic, detector_ref wired
- `lib/reviewer/static_scan.py` — `detect_human_ac_mechanical_signal` (~140 LOC) with `_HUMAN_AC_MECHANICAL_RE` / `_HUMAN_AC_TASTE_RE` / `_HUMAN_AC_STRATEGIC_RE`; wired into `scan_task` orchestration
- `tests/unit/test_reviewer_human_ac_mechanical_signal.py` — 11/11 PASS
- `tests/unit/reviewer_human_ac_mechanical_signal.bats` — 4/4 PASS
- Regression: `bin/fw reviewer T-1851/T-1857` → 0 findings for `human-ac-mechanical-signal` (genuine taste-genuine [REVIEW]s correctly suppressed)
- `bin/fw reviewer T-1896` → Overall PASS, needs_human=no, no findings
- Verification block: 6/6 commands PASS

**Override:** `fw reviewer override add T-XXX --pattern human-ac-mechanical-signal --ac N --reason "..." --ttl 90` (inherits T-1443 v1.4 mechanism, no new code).

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

### 2026-05-18T08:22:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-05dc67b2
- **Timestamp:** 2026-06-02T15:00:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-18T08:29:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
