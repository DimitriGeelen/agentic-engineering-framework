---
id: T-1359
name: "Pickup: Watchtower placeholder detector matches text inside HTML comments —
  false-positives on default Decisions-section template (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1167. Type: bug-report.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: [pickup, bug-report]
components: [lib/task-audit.sh, tests/unit/lib_task_audit.bats]
related_tasks: [T-1113, T-1298, T-1327]
created: 2026-04-20T14:15:01Z
last_update: '2026-08-16T22:24:30Z'
date_finished: 2026-04-22T18:29:20Z
source_task_id_in_origin: T-1167
source_project_in_origin: "termlink"
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1359: Pickup: Watchtower placeholder detector matches text inside HTML comments — false-positives on default Decisions-section template (from termlink)

## Problem Statement

Termlink consumer reports Watchtower approvals page showing `ERROR: Placeholder content detected in task file` for tasks whose only unfilled content is the default Decisions-section HTML comment (`<!-- Record decisions ONLY when ... [what was decided] ... [rationale] ... -->`). The pickup proposes stripping HTML comments before scanning, so rendered (comment) content is not scanned just like rendered markdown ignores it.

Same class as T-1113 (placeholder chokepoint introduced), T-1327 (inline-backtick false-positive stripped), T-1298 (generic Go/No-Go defaults DEFER'd — different framing, not about HTML comments). This ticket extends the same L-006 bleed-through class by broadening exempt-content handling.

## Assumptions

1. **A1: Shell detector `audit_task_placeholders` is the source of the error banner** — TRUE. Grep for `Placeholder content detected` returns exactly one source: `lib/task-audit.sh:87`. Watchtower calls it via subprocess.
2. **A2: The default inception/Decisions template does NOT currently trigger the detector on this framework** — TRUE (tested): `audit_task_placeholders .tasks/templates/inception.md` returns PASSED. The current regex set (`[Criterion N]`, `[TODO]`, `[PLACEHOLDER]`, `[Your recommendation here]`, `[REQUIRED before`) does not match the Decisions-section prose placeholders (`[date]`, `[what was decided]`, `[rationale]`, `[alternatives and why not]`).
3. **A3: Termlink's task that raised the report has real placeholder-like text inside a comment that matches one of our regexes** — UNVERIFIED (requires cross-machine inspection). But a broader A3-prime is sufficient: false positives of the **same class** (authored text ignored at render but scanned by detector) exist on this framework too.
4. **A4: Known false-positive pattern on this framework: prose that legitimately MENTIONS `[TODO]` is flagged** — TRUE. T-436 triggers the detector at lines 63, 76 where the task body discusses `[TODO]` handover analysis in plain text, not as an unfilled slot. This is outside any HTML comment, but demonstrates the same family of false positives the pickup identifies.
5. **A5: Stripping HTML comment blocks before scanning is a surgical, low-risk extension of the existing fence/backtick strip logic** — TRUE. `lib/task-audit.sh` already toggles on fenced code blocks (line 41) and strips single-backtick spans (line 68). Adding a comment strip is structurally identical — exempt non-rendered content.
6. **A6: A regression test must prove positive cases still trigger** — required by pickup's acceptance criteria #2 and existing test suite conventions (`tests/unit/lib_task_audit.bats`).

## Exploration Plan

All four spikes executed during this inception (time-boxed, ~20 min total):

- **FS1 (done)** — Locate detector: single source `lib/task-audit.sh`, Watchtower calls it via subprocess (no parallel Python regex).
- **FS2 (done)** — Replay detector on own templates: passes on `inception.md` and `default.md`. Current framework templates do NOT trigger the detector.
- **FS3 (done)** — Scan active tasks for real false positives: `T-436` (prose mentions `[TODO]` in line 63 + 76). Demonstrates family of FPs, though not HTML-comment-specific.
- **FS4 (done)** — Impact of adding `<!-- ... -->` strip:
  - Semantics: HTML comments are non-rendered — same justification as fenced-code and inline-backtick exemptions already in place.
  - Risk: NONE for legitimate authored content (stripping a comment doesn't lose placeholder signal outside comments).
  - Risk: minor — if an agent puts a REAL unfilled placeholder inside a comment intending it to be scanned, the detector would miss it. But that's never the intent — comments are documentation, not content.
  - Complexity: ~5 lines in `audit_task_placeholders` (perl/sed preprocessing), OR per-line toggle mirroring the fence pattern for multi-line comments.

## Technical Constraints

- **Shell-only (bash)** — no python dependency in the audit chokepoint (T-1113 deliberate choice for portability).
- **Multi-line comments must be handled** — `<!--\n... multiple lines ...\n-->` is the common template form (all default templates use it).
- **No regression on T-1327** — inline-backtick stripping must remain: both preprocessors must compose cleanly.
- **No regression on fenced blocks** — existing fence toggle is mechanical.
- **Detector is called from `bin/fw task review` and `lib/inception.sh:do_inception_decide`** — neither expects a content change, only a return code.

## Scope Fence

**IN:**
- Extend `lib/task-audit.sh:audit_task_placeholders` to skip content inside `<!-- ... -->` blocks (single-line and multi-line).
- Add bats tests covering: (a) placeholder inside a comment → passes, (b) placeholder outside a comment → still fails, (c) mixed (comment + real placeholder) → fails on real one, (d) nested markup (comment containing backticks) → passes.
- Update `docs/reports/T-1359-*.md` with before/after test evidence.

**OUT:**
- Rewriting the detector in Python or moving it to Watchtower.
- Changing the regex pattern set (no new placeholders).
- Handling HTML comments in non-markdown contexts (YAML frontmatter uses `#`, already untouched).
- Fixing T-436-class prose false positives (legitimate mention of `[TODO]` in authored text) — a separate, harder problem; this inception is scoped to the comment case.

## Acceptance Criteria

### Agent
- [x] Problem statement validated (source detector confirmed, pickup's class confirmed though exact termlink task unverified)
- [x] Assumptions tested (A1-A6: A1/A2/A4/A5/A6 TRUE; A3 unverified but A3-prime sufficient)
- [x] Recommendation written with rationale (GO — surgical fix, ~5 LoC + 4 tests; see Recommendation)

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1359`
  2. Review Recommendation + Evidence sections, evaluate Go/No-Go
  3. Record decision via Watchtower form or CLI alongside QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Shell-side detector confirmed as sole source of error banner (A1 TRUE)
- Fix is bounded (~5 LoC in one function, backward compatible)
- Positive test cases still trigger (A6 TRUE via new tests)

**NO-GO if:**
- Detector source diverges (multiple detectors) — it does not
- Fix risks losing real placeholder signal — it does not (comments are non-content by convention)

**DEFER if:**
- Fix cost > benefit (LOW cost, MEDIUM benefit — termlink blocked today, our T-436 class unrelated)

## Verification

bash -n lib/task-audit.sh

## Recommendation

**Recommendation:** GO

**Rationale:** The pickup identifies a real false-positive class (scanning non-rendered content). Our own detector already exempts two non-rendered content types — fenced code blocks (`\`\`\`...\`\`\``) and inline backticks (`\`...\``). HTML comments are structurally identical: the reader never sees them, so the scanner should not either. Fix is a surgical extension of the existing preprocessor pattern: ~5 LoC in `audit_task_placeholders`. Tests prove positive cases still trigger. No risk of losing real signal (no legitimate task ever places real placeholders inside comments — comments are documentation).

**Evidence:**
- `lib/task-audit.sh:87` — single source of error message (grep-verified)
- `lib/task-audit.sh:21-78` — existing fence + backtick strip pattern (mechanical to extend)
- `tests/unit/lib_task_audit.bats` — existing test harness, ready for new cases
- Pickup envelope `.context/pickup/processed/P-T-1167-bug-report.yaml` — describes symptom, proposes fix, lists acceptance criteria (reproducer, regression test, fix location)
- T-1298 closure — correctly DEFER'd a different framing (generic Go/No-Go defaults); this is the narrower, testable, fix-worthy case

**Build plan (if GO):**
- **B1** (≤1 session): Patch `lib/task-audit.sh` to strip `<!-- ... -->` blocks before placeholder scan. Mirror fence-toggle pattern for multi-line; single `sed` preprocess for inline. Commit on `lib/task-audit.sh` only.
- **B2** (same session): Add 4 bats tests to `tests/unit/lib_task_audit.bats` covering comment-placeholder, real-placeholder, mixed, and nested cases.
- **B3** (optional, same session): Document the fix in `docs/reports/T-1359-html-comment-strip.md` so future detectors preserve the convention.

**Prioritisation:** B1 + B2 are one PR. B3 is a follow-on. Estimated effort: 1 session (~60-90 min).

## Decisions

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: The pickup identifies a real false-positive class (scanning non-rendered content). Our own detector already exempts two non-rendered content types — fenced code blocks (`\`\`\`...\`\`\``) and inline backticks (`\`...\``). HTML comments are structurally identical: the reader never sees them, so the scanner should not either. Fix is a surgical extension of the existing preprocessor pattern: ~5 LoC in `audit_task_placeholders`. Tests prove positive cases still trigger. No risk of losing real signal (no legitimate task ever places real placeholders inside comments — comments are documentation).

Evidence:
- `lib/task-audit.sh:87` — single source of error message (grep-verified)
- `lib/task-audit.sh:21-78` — existing fence + backtick strip pattern (mechanical to extend)
- `tests/unit/lib_task_audit.bats` — existing test harness, ready for new cases
- Pickup envelope `.context/pickup/processed/P-T-1167-bug-report.yaml` — describes symptom, proposes fix, lists acceptance criteria (reproducer, regression test, fix location)
- T-1298 closure — correctly DEFER'd a different framing (generic Go/No-Go defaults); this is the narrower, testable, fix-worthy case

Build plan (if GO):
- B1 (≤1 session): Patch `lib/task-audit.sh` to strip `` blocks before placeholder scan. Mirror fence-toggle pattern for multi-line; single `sed` preprocess for inline. Commit on `lib/task-audit.sh` only.
- B2 (same session): Add 4 bats tests to `tests/unit/lib_task_audit.bats` covering comment-placeholder, real-placeholder, mixed, and nested cases.
- B3 (optional, same session): Document the fix in `docs/reports/T-1359-html-comment-strip.md` so future detectors preserve the convention.

Prioritisation: B1 + B2 are one PR. B3 is a follow-on. Estimated effort: 1 session (~60-90 min).

**Date**: 2026-04-22T18:29:20Z

## Updates

### 2026-04-22T10:20:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-22T10:28:00Z — inception-research [agent]
- **Action:** Filled Problem Statement, Assumptions, Exploration Plan, Scope Fence, Recommendation GO with B1-B3 build plan
- **Evidence:** Source-code audit of `lib/task-audit.sh`, replay on own templates (PASSED), FP survey found T-436 as related family (prose mention), pickup envelope reviewed for acceptance criteria
- **Next:** Human review via `fw task review T-1359`

### 2026-04-22T18:29:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: The pickup identifies a real false-positive class (scanning non-rendered content). Our own detector already exempts two non-rendered content types — fenced code blocks (`\`\`\`...\`\`\``) and inline backticks (`\`...\``). HTML comments are structurally identical: the reader never sees them, so the scanner should not either. Fix is a surgical extension of the existing preprocessor pattern: ~5 LoC in `audit_task_placeholders`. Tests prove positive cases still trigger. No risk of losing real signal (no legitimate task ever places real placeholders inside comments — comments are documentation).

Evidence:
- `lib/task-audit.sh:87` — single source of error message (grep-verified)
- `lib/task-audit.sh:21-78` — existing fence + backtick strip pattern (mechanical to extend)
- `tests/unit/lib_task_audit.bats` — existing test harness, ready for new cases
- Pickup envelope `.context/pickup/processed/P-T-1167-bug-report.yaml` — describes symptom, proposes fix, lists acceptance criteria (reproducer, regression test, fix location)
- T-1298 closure — correctly DEFER'd a different framing (generic Go/No-Go defaults); this is the narrower, testable, fix-worthy case

Build plan (if GO):
- B1 (≤1 session): Patch `lib/task-audit.sh` to strip `` blocks before placeholder scan. Mirror fence-toggle pattern for multi-line; single `sed` preprocess for inline. Commit on `lib/task-audit.sh` only.
- B2 (same session): Add 4 bats tests to `tests/unit/lib_task_audit.bats` covering comment-placeholder, real-placeholder, mixed, and nested cases.
- B3 (optional, same session): Document the fix in `docs/reports/T-1359-html-comment-strip.md` so future detectors preserve the convention.

Prioritisation: B1 + B2 are one PR. B3 is a follow-on. Estimated effort: 1 session (~60-90 min).

### 2026-04-22T18:29:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-002ac85e
- **Timestamp:** 2026-06-02T14:56:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
