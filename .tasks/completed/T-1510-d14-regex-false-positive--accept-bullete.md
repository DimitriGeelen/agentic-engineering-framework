---
id: T-1510
name: "D14 regex false-positive — accept bulleted '- **Recommendation:**' format in
  audit_inception_recommendation + agents/audit/audit.sh"
description: >
  D14 regex false-positive — accept bulleted '- **Recommendation:**' format in audit_inception_recommendation
  + agents/audit/audit.sh

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [C-004, lib/task-audit.sh]
related_tasks: []
created: 2026-04-26T14:15:02Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T14:18:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=4 (body:fw-audit-or-doctor); 
      D3=0 (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1510: D14 regex false-positive — accept bulleted '- **Recommendation:**' format in audit_inception_recommendation + agents/audit/audit.sh

## Context

T-1497's `audit_inception_recommendation` (in `lib/task-audit.sh:138`) and the D14 audit check (in `agents/audit/audit.sh`) both use a regex that requires whitespace-only indentation before `**Recommendation:**`:

```
^[[:space:]]*\*\*Recommendation:\*\*[[:space:]]*[A-Za-z]
```

But many existing inception tasks were authored with a markdown-bullet prefix:

```
- **Recommendation:** DEFER
```

The leading `- ` is not whitespace, so the regex rejects these as "empty Recommendation". Live evidence: D14 audit just flagged T-844 and T-705 as empty when both have substantive recommendations recorded weeks ago (T-844 DEFER on 2026-04-13, T-705 DEFER on 2026-03-29). Both are owner=human inceptions stuck in active/ with the decision already in their `## Decision` block — the audit noise is the problem, not the task content.

Fix: widen the pattern to accept an optional bullet marker `[-*]` before the bold marker. Same fix in both files, plus a test case in `tests/unit/inception_decide_recommendation_gate.bats` so the regression doesn't recur.

## Acceptance Criteria

### Agent
- [x] `lib/task-audit.sh:audit_inception_recommendation` accepts `- **Recommendation:** GO` (bulleted) AND `**Recommendation:** GO` (plain) AND `  **Recommendation:** GO` (indented).
- [x] `agents/audit/audit.sh` D14 Python helper `has_substantive_recommendation` accepts the same three forms.
- [x] New bats test case `audit_inception_recommendation: bulleted **Recommendation:** still passes` in `tests/unit/inception_decide_recommendation_gate.bats`.
- [x] After fix, `bin/fw audit` no longer flags T-844 and T-705 in D14 (both have bulleted recommendations).
- [x] Existing tests still pass: `bats tests/unit/inception_decide_recommendation_gate.bats` (all 6 prior cases) — now 8 cases total, all pass.

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

cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/inception_decide_recommendation_gate.bats
cd /opt/999-Agentic-Engineering-Framework && bash -c 'source lib/colors.sh; source lib/paths.sh; source lib/task-audit.sh; audit_inception_recommendation .tasks/active/T-705-kcp-integration--knowledgeyaml-generatio.md'
cd /opt/999-Agentic-Engineering-Framework && bash -c 'source lib/colors.sh; source lib/paths.sh; source lib/task-audit.sh; audit_inception_recommendation .tasks/active/T-844-ssd-evaluation--simple-self-distillation.md'
cd /opt/999-Agentic-Engineering-Framework && bin/fw audit 2>&1 | grep -q "PASS no_empty_recommendations\|D14.*WARN.*[0-9]_empty: T-1499 T-1507" || echo "D14 still flagging T-844/T-705 wrongly"

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

### 2026-04-26T14:15:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1510-d14-regex-false-positive--accept-bullete.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4e6fc280
- **Timestamp:** 2026-06-02T14:57:58Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `cd /opt/999-Agentic-Engineering-Framework && bin/fw audit 2>&1 | grep -q "PASS no_empty_recommendations\|D14.*WARN.*[0-9]_empty: T-1499 T-1507" || echo "D14 still flagging T-844/T-705 wrongly"`
### 2026-04-26T14:18:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
