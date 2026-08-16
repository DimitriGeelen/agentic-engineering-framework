---
id: T-1543
name: "Sanitize YAML escapes in fw context add-decision (and add-learning) auto-capture"
description: >
  Sanitize YAML escapes in fw context add-decision (and add-learning) auto-capture

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-27T14:51:49Z
last_update: '2026-08-16T22:24:36Z'
date_finished: 2026-04-27T14:58:31Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 3
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=3 (body:fw-recall-or-memory-link);
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1543: Sanitize YAML escapes in fw context add-decision (and add-learning) auto-capture

## Context

`fw context add-decision` (`agents/context/lib/decision.sh:85`) interpolates the decision text directly into a YAML double-quoted string with no escape handling. `fw context add-learning` (`agents/context/lib/learning.sh:75,87`) escapes only `"` via awk gsub, missing backslashes entirely. YAML 1.2 only permits a fixed set of escape sequences after `\`; anything else (`\s`, `\``, `\'`, `\bash`, etc.) causes "found unknown escape character" parse errors.

Recurrence evidence: L-294 (T-1530), D-036 (T-1540), D-038 (T-1541) — three hand-fixes in 3 days, same class. Each occurrence blocked the pre-push audit until manually edited. OBS-033 captured this as a systemic issue.

Fix: add a `_yaml_escape_dquoted` helper that doubles backslashes and escapes double-quotes; apply at every interpolation site in both files.

## Acceptance Criteria

### Agent
- [x] `agents/context/lib/decision.sh` exposes `_yaml_escape_dquoted` and uses it for `decision`, `rationale`, `source`, `recommendation_type`, and rejected-list items
- [x] `agents/context/lib/learning.sh` uses `_yaml_escape_dquoted` for `learning` (replaces the partial awk-gsub-only escape; passes via ENVIRON to avoid awk -v's escape interpretation)
- [x] Bats regression: `fw context add-decision` with text containing `\s`, `\``, `"`, and `\` produces a YAML file that `python3 -c "import yaml; yaml.safe_load(...)"` parses cleanly
- [x] Bats regression: `fw context add-learning` same input set, same parse-clean assertion
- [x] Round-trip: written content matches input verbatim after YAML load (no double-escape, no character loss)
- [x] Existing decisions.yaml + learnings.yaml still parse after the change (no regression on already-stored entries)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

bats tests/unit/context_yaml_escape.bats
python3 -c "import yaml; yaml.safe_load(open('.context/project/decisions.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('.context/project/learnings.yaml'))"

## Decisions

### 2026-04-27 — Pass escape value via ENVIRON, not awk -v

- **Chose:** In `learning.sh`, pass the escaped string through environment variable (`L_ESC=...`) and read it inside awk via `ENVIRON["L_ESC"]`, rather than `-v learning=...`.
- **Why:** awk's `-v var=value` flag interprets backslash escape sequences in the value before assignment, so `\\backslash` collapses to `\backslash` and `\"quote\"` to `"quote"` — undoing the YAML escape. ENVIRON skips that interpretation and passes the raw string. Tested empirically: round-trip mismatch was masked by this exact behavior.
- **Rejected:** Restructure the awk pipeline to a python helper (more invasive; also changes file-rewrite semantics); double-escape (\\\\\\\\) before passing to -v (fragile, hard to reason about).

## Recommendation

**Recommendation:** GO

**Rationale:** Three-time recurrence of the YAML-escape bug class (L-294, D-036, D-038) eliminated by adding `_yaml_escape_dquoted` helper to both decision.sh and learning.sh, plus an ENVIRON-passing fix for awk in learning.sh. Five regression tests cover hostile inputs (`\s`, `\``, `\`, `"`) for both code paths, including round-trip equality. Existing context files still parse. Pre-push audit will no longer block on auto-captured decisions/learnings containing template-quoted regex patterns or backslash-anything sequences.

**Evidence:**
- `agents/context/lib/decision.sh` — added helper, applied to all 5 interpolation sites
- `agents/context/lib/learning.sh` — added helper, switched awk from `-v` to ENVIRON for escape preservation
- `tests/unit/context_yaml_escape.bats` — 5/5 PASS (parse + round-trip × 2 surfaces, plus rejected-list)
- `tests/unit/task_verify_extraction.bats` — 5/5 still PASS (no collateral regression)
- `python3 yaml.safe_load` against current `.context/project/decisions.yaml` and `learnings.yaml` — both parse

## Updates

### 2026-04-27T14:51:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1543-sanitize-yaml-escapes-in-fw-context-add-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d6aef6bc
- **Timestamp:** 2026-06-02T14:58:11Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T14:58:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
