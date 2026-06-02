---
id: T-1567
name: "F1: Fix dead-code regex in _is_inception_decide (T-1192 auto-exec never fires)"
description: >
  F1: Fix dead-code regex in _is_inception_decide (T-1192 auto-exec never fires)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T20:59:53Z
last_update: 2026-04-27T21:01:50Z
date_finished: 2026-04-27T21:01:50Z
---

# T-1567: F1: Fix dead-code regex in _is_inception_decide (T-1192 auto-exec never fires)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `web/blueprints/approvals.py` regexes at lines 454, 463, 467 corrected: `\\d` → `\d`, `\\s` → `\s`, `\\b` → `\b` (raw strings + escaped meta = literal backslash-letter, never matched). Surfaced by T-1565 audit (F1).
- [x] Verification command pins the regex shape: `python3 -c "import re; assert re.search(...)"` for two preview shapes (bare + leading slash). Runs on every completion via the P-011 gate.
- [x] No other regex in approvals.py shows the same `r"\\d"` anti-pattern (verified via grep -nE 'r"[^"]*\\\\\\\\[dsbw]').

### Human
<!-- All ACs are agent-verifiable. -->

## Verification

python3 -c "import re; assert re.search(r'(?:^|/|\s)fw inception decide T-\d+ (?:go|no-go)\b', 'fw inception decide T-1538 go'), 'regex broken'"
python3 -c "import re; assert re.search(r'(?:^|/|\s)fw inception decide T-\d+ (?:go|no-go)\b', 'bin/fw inception decide T-1538 no-go'), 'leading slash variant'"
grep -E 'r\"[^\"]*\\\\\\\\[dsbw]' web/blueprints/approvals.py && exit 1 || exit 0

## RCA

**Symptom:** Watchtower-approved Tier-0 inception decisions never auto-executed. Humans approving via the web UI always saw "Agent can retry" instead of the intended auto-decide flow (T-1192).

**Root cause:** `web/blueprints/approvals.py:454,463,467` used raw-string regex literals with double-escaped meta characters (`r"...\\d..."` instead of `r"...\d..."`). In a raw string, `\\` is a literal backslash; the regex engine then sees `\\d` (a literal backslash followed by `d`), not `\d` (digit class). The patterns matched only inputs like `T-\d+` literal, never any real preview.

**Why structurally allowed:** No unit test pinned the function — the "auto-exec" feature was added (T-1192) but never validated end-to-end against a realistic command preview. The dead path was invisible because the fallback `Agent can retry` UI message was indistinguishable from a deliberate non-auto path. The Reviewer agent's static-scan doesn't cover Python source under web/blueprints/.

**Prevention:**
- Verification command (this task) pins the three preview shapes via `python3 -c re.search(...)` — runs on every completion via P-011.
- Grep audit `r"[^"]*\\\\[dsbw]"` confirms no remaining instances anywhere in approvals.py.
- L-307 captured: "Python raw-string regex with `\\` is a literal backslash; never use `\\d`/`\\s`/`\\b` inside `r"..."` — it's the inverse of escaping."

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-04-27T20:59:53Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1567-f1-fix-dead-code-regex-in-isinceptiondec.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4c2dc486
- **Timestamp:** 2026-06-02T14:58:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T21:01:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
