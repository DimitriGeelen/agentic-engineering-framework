---
id: T-1620
name: "Strip HTML comments in inception.sh and verify-acs.sh AC counters"
description: >
  Strip HTML comments in inception.sh and verify-acs.sh AC counters

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-30T16:59:47Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-30T17:17:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1620: Strip HTML comments in inception.sh and verify-acs.sh AC counters

## Context

Follow-up to T-1618. The handover scanner phantom-AC fix landed at
`agents/handover/handover.sh:689` but the same bug class persists in two
other consumers of the Human-AC counter:

1. `lib/inception.sh:642` — `awk '/^### Human/,/^## [A-Z]/' "$f" | grep -cE '^\s*- \[ \]'`
   counts unchecked Human ACs after auto-tick. T-1274 reproduces: returns 1
   instead of 0, so the inception sweep keeps the task in active/ when it
   should move to completed/.
2. `lib/verify-acs.sh:224` — `re.findall(r'^\s*-\s*\[ \]', human_block, re.MULTILINE)`
   surfaces phantom unchecked ACs as work the human "needs to verify". T-1274
   reproduces here too.

Same structural gap as T-1618: no shared helper for "extract Human section,
strip comments, count unchecked". The fix mirrors the bin/fw verify-acs
G-047 / handover.sh T-1618 pattern.

## Acceptance Criteria

### Agent
- [x] `lib/inception.sh:642` strips `<!-- ... -->` blocks before counting unchecked Human ACs
- [x] `lib/verify-acs.sh:224` strips `<!-- ... -->` blocks before counting unchecked Human ACs
- [x] Regression test added: `tests/unit/ac_counter_strip_comments.bats` covers both call-sites with the T-1274 phantom fixture
- [x] All new tests pass (8/8); pre-existing `verify_acs.bats` (11/11) and `task_verify_extraction.bats` unchanged
- [x] Live re-scan: T-1274 no longer returns count=1 from either pattern (counts==0 in both, verified inline)
- [x] `bash -n` parses cleanly for both edited files

## Verification

bash -n lib/inception.sh
bash -n lib/verify-acs.sh
bats tests/unit/ac_counter_strip_comments.bats
grep -Fq "T-1620" lib/inception.sh
grep -Fq "T-1620" lib/verify-acs.sh

## RCA

**Symptom:** Two consumers of the unchecked-Human-AC counter inherited the
same phantom-AC bug class T-1618 fixed in handover.sh:
1. `lib/inception.sh:642` — sweep refuses to move a task to completed/
   because the auto-counter still sees 1 phantom unchecked Human AC from the
   template's Example block.
2. `lib/verify-acs.sh:224` — `fw verify-acs` lists T-1274-class tasks as
   pending human verification despite their Human section being entirely
   the template Example.

T-1274 reproduces both (count=1 pre-fix, count=0 post-fix in both call-sites).

**Root cause:** Same as T-1618 — no shared Human-AC parser. Each consumer
has its own regex/awk pipeline and the comment-stripping fix had to be
applied independently in each call-site (bin/fw verify-acs / G-047 first,
agents/handover/handover.sh / T-1618 second, lib/inception.sh + lib/verify-acs.sh
/ T-1620 third).

**Why structurally allowed:** No central helper. Four parallel implementations
of "extract Human section, strip comments, count unchecked" — each had to be
fixed when the bug surfaced in its surface area. T-1618's RCA explicitly
flagged these as a "Follow-up" against "one bug = one task"; T-1620 is that
follow-up.

**Prevention:**
1. `tests/unit/ac_counter_strip_comments.bats` — 8 cases pin both call-sites
   (source-level invariants + behavioural cases for phantom dropped + real
   preserved + bash -n).
2. Live re-scan: T-1274 reports count=0 from both pipelines.

**Follow-up (structural):** A shared `extract_human_acs()` helper would prevent
this recurrence by having one place to stripe comments. Not yet warranted
(four call-sites, all now consistent); revisit if a fifth consumer appears
or if the regex pattern needs to grow (e.g. nested comments, fenced code
blocks). File a refactor task only when a future bug forces the issue.

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

### 2026-04-30T16:59:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1620-strip-html-comments-in-inceptionsh-and-v.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-badfb118
- **Timestamp:** 2026-06-02T14:58:42Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T17:17:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
