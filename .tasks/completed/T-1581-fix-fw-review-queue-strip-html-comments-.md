---
id: T-1581
name: "Fix fw review-queue: strip HTML comments before AC counting (mirror L-298 in
  CLI)"
description: >
  fw review-queue (bin/fw:3447) regex ^\s*-\s*\[ \] matches placeholder ACs inside
  HTML comments. T-1274 and T-1542 have template-only ### Human sections (example
  AC inside <!-- -->), counted as unchecked. Cockpit (canonical parser) skips comments
  correctly — 2-task divergence. Strip HTML comments before regex match.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-28T12:22:44Z
last_update: '2026-06-11T22:23:52Z'
date_finished: 2026-04-28T12:32:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:52Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1581: Fix fw review-queue: strip HTML comments before AC counting (mirror L-298 in CLI)

## Context

`bin/fw review-queue` (line ~3447) counts unchecked Human ACs via regex `^\s*-\s*\[ \]` against the raw `### Human` section text. Tasks created from the default template have a placeholder example AC inside an HTML comment (`<!-- ... - [ ] [REVIEW] Dashboard renders correctly ... -->`). The regex matches that placeholder, so empty-template Human sections are counted as having 1 unchecked AC.

T-1274 and T-1542 have template-only `### Human` sections. CLI counts them as having 1 unchecked AC and includes them in the queue with state=NO-REC. Cockpit (using canonical `_parse_acceptance_criteria` from `web/blueprints/tasks.py`) correctly strips HTML comments and skips them. Both surfaces have the same 49 tasks but different NO-REC partitions (CLI: 3 vs cockpit: 1).

This is the mirror image of L-298: that learning was about the cockpit matching ACs inside HTML comments; this is the CLI doing the same thing on a different surface, fixed at a different time.

Fix: strip HTML comments from the human-section text before applying the unchecked-AC regex.

## Acceptance Criteria

### Agent
- [x] `fw review-queue` no longer counts placeholder ACs inside `<!-- -->` comments
- [x] T-1274 and T-1542 (template-only Human sections) drop out of `fw review-queue` output
- [x] CLI/cockpit/`/approvals` data-state counts converge on identical sets
- [x] No regression: tasks with real Human ACs still appear (T-449, T-967, T-460, T-1577, T-1574, T-1575, etc.)
- [x] CLI summary line shows 1 NO-REC matching cockpit (was 3 with falsely-included templates)
- [x] Removed now-redundant `owner=human OR status=work-completed` filter (T-1540 iter1 workaround for the comment-counted-as-AC bug — superseded by the canonical comment-strip fix)

### Human

(none — pure parser fix verified by CLI snapshot)

## Verification

cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-1274' && echo "FAIL T-1274 still in queue" && exit 1 || true
cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-1542' && echo "FAIL T-1542 still in queue" && exit 1 || true
cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-449' || (echo "REGRESSION: T-449 dropped" && exit 1)
cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-967' || (echo "REGRESSION: T-967 dropped" && exit 1)

## RCA

**Symptom:** Two cross-surface count divergences between `bin/fw review-queue` and the canonical cockpit list. (1) Tasks T-1274 / T-1542 appeared in CLI as NO-REC (3 NO-REC total) but were absent from cockpit (1 NO-REC). (2) Tasks T-1574 / T-1575 appeared in cockpit but not CLI. Net: CLI showed 49 entries with a different partition than cockpit's 49.

**Root cause:** Two distinct bugs in `bin/fw` (`do review-queue` block, lines ~3440-3460):
1. The unchecked-AC regex `^\s*-\s*\[ \]` ran against the raw `### Human` section, including HTML-commented placeholder ACs from the default task template (`<!-- ... - [ ] [REVIEW] Dashboard renders correctly ... -->`). Template-only Human sections (no real ACs, just the example block in the comment) were counted as 1 unchecked AC.
2. To compensate, T-1540 iter1 added a downstream filter `if owner != "human" and status != "work-completed": continue` to drop the resulting noise. That filter then incorrectly hid legitimate cases — agent-owned `started-work` tasks where the agent had finished Agent ACs and written a Recommendation block, awaiting human review (T-1574, T-1575).

**Why structurally allowed:** The original CLI was hand-rolled (regex over raw text) instead of reusing the canonical `_parse_acceptance_criteria` from `web/blueprints/tasks.py`. When the cockpit was migrated to the canonical parser (T-1577 / L-311), the CLI was not migrated; the two surfaces drifted on parsing semantics. The compensating filter (T-1540 iter1) papered over the symptom without addressing the comment-matching root cause, masking the second bug.

**Prevention:** Comment stripping is now applied directly to `human_text` before the unchecked-AC regex (mirror of L-298, applied to the CLI surface). The compensating owner/status filter is removed since its rationale no longer holds. L-309 already calls out exactly this drift class — adding a CLI-side L-309 instance to the trail (this task) reinforces that the canonical parser must be the single source of truth across surfaces. Long-term: migrate CLI to import `web.shared._parse_acceptance_criteria` directly rather than mirror its logic in regex (out-of-scope for T-1581).

## Recommendation

**Recommendation:** GO

**Rationale:** Two-line fix (strip HTML comments before count + drop now-redundant filter) achieves triple-surface parity (CLI = cockpit = `/approvals` data-state attribute). Live verification: `bin/fw review-queue` and `get_human_verify_tasks()` return identical 49-task sets with no symmetric difference. T-1274 and T-1542 (template-only Human sections) drop out correctly; T-1574 and T-1575 (agent-handoff cases) surface correctly. No regression on tasks with real Human ACs. Reinforces L-309 (single canonical parser across surfaces).

**Evidence:**
- `bin/fw review-queue` → 49 task(s) awaiting human review (36 GO / 12 DEFER / 1 NO-REC).
- `get_human_verify_tasks()` Python output → same 49 tasks, same partition.
- `curl /approvals | grep data-state=` → 36 GO / 12 DEFER / 1 NO-REC (matches).
- Set-symmetric difference between CLI and cockpit: empty in both directions.
- T-1274 and T-1542 (template-only Humans) absent from queue; T-1574, T-1575 (agent-handoff) present.

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

### 2026-04-28T12:22:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1581-fix-fw-review-queue-strip-html-comments-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-84226711
- **Timestamp:** 2026-06-02T14:58:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-1274' && echo "FAIL T-1274 still in queue" && exit 1 || true`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-1542' && echo "FAIL T-1542 still in queue" && exit 1 || true`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-449' || (echo "REGRESSION: T-449 dropped" && exit 1)`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bin/fw review-queue 2>&1 | grep -q 'T-967' || (echo "REGRESSION: T-967 dropped" && exit 1)`
### 2026-04-28T12:32:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
