---
id: T-1580
name: "Fix recommendation extractor: accept bullet-prefixed marker lines (- ** RE)"
description: >
  Recommendation parser at web/shared.py _REC_MARKER_RE requires ** at line start,
  missing bullet-list-style ACs (- **Recommendation:** DEFER). T-705 and T-844 falsely
  appear as ? in review queue despite being clean DEFER recommendations. Fix: allow
  optional leading [-*] bullet + whitespace before the bold marker. Add regression
  tests.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [web/shared.py]
related_tasks: []
created: 2026-04-28T12:09:49Z
last_update: '2026-08-16T22:24:37Z'
date_finished: 2026-04-28T12:13:58Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1580: Fix recommendation extractor: accept bullet-prefixed marker lines (- ** RE)

## Context

`web/shared.py:_REC_MARKER_RE` is `r"^\*\*([^*]+?)\*\*\s*"` (MULTILINE). The `^` anchor requires the bold marker to be the very first character of a line. Recommendation blocks authored as bullet lists (`- **Recommendation:** DEFER`) — a legitimate Markdown rendering style — fail to match, so `extract_recommendation()` returns `verdict="?"` for them. T-705 and T-844 are well-formed DEFER recommendations that show as `?` in `fw review-queue` and on /approvals.

Fix: relax the anchor to allow an optional leading bullet (`-` or `*`) plus whitespace before `**`, while still keeping the line-start guarantee (so we don't match bold text mid-paragraph). Add regression tests for both bullet styles + non-match negative cases.

## Acceptance Criteria

### Agent
- [x] `_REC_MARKER_RE` accepts optional `^[ \t]*[-*][ \t]+` prefix before `**Marker:**`
- [x] `extract_recommendation_state()` returns `DEFER` for T-705 and T-844 (not `?`)
- [x] `extract_recommendation_state()` still returns `?` for tasks with truly unparseable verdict (e.g. T-1062 prose `Recommendation: Agent ACs complete — ready...`)
- [x] No regression on existing non-bullet style (T-1577/T-1578 still resolve to `GO`)
- [x] Regression test added in `tests/unit/test_extract_recommendation.py` covering: bullet-prefixed DEFER, bullet-prefixed GO, mid-paragraph `**` not matched, non-bullet still works
- [x] `bin/fw review-queue` shows T-705 and T-844 under DEFER (not `?`); `?` count drops from 6 to 4

### Human

(none — pure parser fix verified by unit tests + queue snapshot)

## Verification

cd /opt/999-Agentic-Engineering-Framework && python3 -c "from web.shared import extract_recommendation_state; body = open('.tasks/active/T-705-kcp-integration--knowledgeyaml-generatio.md').read(); s=extract_recommendation_state(body); assert s == 'DEFER', f'expected DEFER, got {s}'"
cd /opt/999-Agentic-Engineering-Framework && python3 -c "from web.shared import extract_recommendation_state; body = open('.tasks/active/T-844-ssd-evaluation--simple-self-distillation.md').read(); s=extract_recommendation_state(body); assert s == 'DEFER', f'expected DEFER, got {s}'"
cd /opt/999-Agentic-Engineering-Framework && python3 -m pytest tests/unit/test_extract_recommendation.py -q 2>&1 | tail -10

## RCA

**Symptom:** T-705 and T-844 appear in `fw review-queue` and on /approvals as `?` (verdict unparseable) despite both having clean `- **Recommendation:** DEFER` blocks with full rationale + evidence.

**Root cause:** `web/shared.py:_REC_MARKER_RE` was anchored as `^\*\*([^*]+?)\*\*\s*` — the `^` (line-start) required `**` to be the first non-newline character. Markdown allows the same content as a bulleted list (`- **Marker:** value`), but the bullet prefix shifted the `**` away from the line start, so the marker regex skipped those lines entirely. `extract_recommendation()` then found zero markers in an otherwise well-formed block and fell through to `verdict="?"`.

**Why structurally allowed:** The original `_REC_MARKER_RE` (T-1575) was tested against the canonical non-bullet style only. There was no negative test for bullet-prefixed style and no spec stating which Markdown variants must be accepted. Real authoring drift (T-705 was authored 30+ days ago using bullets) silently produced `?` verdicts that nobody noticed until last session's NO-REC distinction work made `?` visually loud.

**Prevention:** Test cases added for both bullet-prefixed DEFER and bullet-prefixed GO; the regex now permits `^[ \t]*(?:[-*][ \t]+)?**` as part of its public contract. A task-author writing either style produces the same parsed verdict.

## Recommendation

**Recommendation:** GO

**Rationale:** Pure parser fix — relaxes line-start anchor in one regex by ~12 characters. 24/24 extractor tests pass (5 new for T-1580). Live verification: `bin/fw review-queue` `?` count went 6 → 4 immediately on running the modified module. T-705 and T-844, both authored as bullet-list Recommendation blocks 30+ days ago, now correctly surface as DEFER. T-1577/T-1578 (non-bullet style) still resolve to GO — no regression. Watchtower restarted and /approvals data-verdict counts updated accordingly.

**Evidence:**
- `web/shared.py:293` — regex now `r"^[ \t]*(?:[-*][ \t]+)?\*\*([^*]+?)\*\*\s*"`.
- `tests/unit/test_extract_recommendation.py` — 5 new tests under T-1580 header, all pass.
- `python3 -m pytest tests/unit/test_extract_recommendation.py -q` → 24 passed in 0.30s.
- Live: T-705 → DEFER, T-844 → DEFER (was `?` for both); T-1577 → GO, T-1062 → `?` (correctly stays `?` — that's prose-mismatch, separate class).
- `bin/fw review-queue` summary line: 27 GO / 10 DEFER / 4 `?` / 8 NO-REC (was 27/8/6/8).

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T12:09:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1580-fix-recommendation-extractor-accept-bull.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5714b4fe
- **Timestamp:** 2026-06-02T14:58:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-28T12:13:58Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
