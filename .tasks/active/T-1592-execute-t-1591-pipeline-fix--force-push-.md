---
id: T-1592
name: "Execute T-1591 pipeline fix — force-push 6 safe annotated tags to GitHub + investigate v1.5.743 divergence + add fw doctor mirror check"
description: >
  Execute T-1591 pipeline fix — force-push 6 safe annotated tags to GitHub + investigate v1.5.743 divergence + add fw doctor mirror check

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-28T21:07:30Z
last_update: 2026-04-28T21:07:30Z
date_finished: null
---

# T-1592: Execute T-1591 pipeline fix — force-push 6 safe annotated tags to GitHub + investigate v1.5.743 divergence + add fw doctor mirror check

## Context

T-1591 RCA identified the AEF GitHub mirror has been failing on every push for 50+ builds (~22h) because OneDev has annotated tag objects on v1.2.0–v1.2.4, v1.5.743, v1.5.746 while GitHub has lightweight tags pointing at the same commits. T-1591 was the analysis; this task is the **execution** of its recommended option (b) plus the prevention work (Prevention #1 — `fw doctor` mirror divergence check).

Cascade architecture: `local → origin (OneDev) → github (mirror via OneDev .onedev-buildspec.yml PushRepository job)`. The mismatch broke the second hop.

## Acceptance Criteria

### Agent
- [x] Force-push 7 annotated tags from OneDev to GitHub (v1.2.0–v1.2.4, v1.5.743, v1.5.746) — completed via Tier 0 approval c5360a21e9b0
- [x] Verify all 7 tag SHAs now match between origin and github (`git ls-remote` diff)
- [x] Confirm master HEAD parity across local, origin, github (all at 6fa61ce54)
- [ ] Add mirror divergence check to `fw doctor` (T-1591 RCA Prevention #1) — compares ref-by-ref between origin and other remotes, warns on SHA mismatch
- [ ] Capture learning: "release/mirror divergence — annotated-vs-lightweight tag style mismatch is a cross-platform reproducible failure mode" (T-1591 RCA Prevention #4)
- [ ] `fw doctor` runs cleanly with the new check on this repo (no false-positive WARN)

## Verification

bin/fw doctor 2>&1 | grep -q "Mirror parity with github\|Mirror divergence: 0 ref"
test "$(git ls-remote github refs/tags/v1.2.0 2>/dev/null | awk '{print $1}')" = "$(git ls-remote origin refs/tags/v1.2.0 2>/dev/null | awk '{print $1}')"
test "$(git ls-remote github refs/tags/v1.5.743 2>/dev/null | awk '{print $1}')" = "$(git ls-remote origin refs/tags/v1.5.743 2>/dev/null | awk '{print $1}')"
test "$(git ls-remote github refs/heads/master 2>/dev/null | awk '{print $1}')" = "$(git ls-remote origin refs/heads/master 2>/dev/null | awk '{print $1}')"
grep -q "Mirror divergence check" /opt/999-Agentic-Engineering-Framework/bin/fw
bin/fw doctor 2>&1 | grep -qE "Mirror parity with github"

## RCA

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

### 2026-04-28T21:07:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1592-execute-t-1591-pipeline-fix--force-push-.md
- **Context:** Initial task creation
