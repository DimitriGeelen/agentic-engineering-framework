---
id: T-1592
name: "Execute T-1591 pipeline fix — force-push 6 safe annotated tags to GitHub + investigate v1.5.743 divergence + add fw doctor mirror check"
description: >
  Execute T-1591 pipeline fix — force-push 6 safe annotated tags to GitHub + investigate v1.5.743 divergence + add fw doctor mirror check

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-28T21:07:30Z
last_update: 2026-04-28T21:36:09Z
date_finished: 2026-04-28T21:36:09Z
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
- [x] Add mirror divergence check to `fw doctor` (T-1591 RCA Prevention #1) — bin/fw lines 1625-1681, compares ref-by-ref between origin and other remotes, warns on SHA mismatch
- [x] Capture learning: L-323 captured (`fw context add-learning … --task T-1592 --source P-002`)
- [x] `fw doctor` runs cleanly with the new check on this repo: emits "INFO Mirror asymmetry with github: origin-only=2, github-only=1 (no SHA conflicts)" — no false-positive WARN

## Verification

# Tags now match (the T-1591 root cause)
test "$(git ls-remote github refs/tags/v1.2.0 2>/dev/null | awk '{print $1}')" = "$(git ls-remote origin refs/tags/v1.2.0 2>/dev/null | awk '{print $1}')"
test "$(git ls-remote github refs/tags/v1.5.743 2>/dev/null | awk '{print $1}')" = "$(git ls-remote origin refs/tags/v1.5.743 2>/dev/null | awk '{print $1}')"
# Master heads at parity across all three
test "$(git ls-remote github refs/heads/master 2>/dev/null | awk '{print $1}')" = "$(git ls-remote origin refs/heads/master 2>/dev/null | awk '{print $1}')"
# Mirror check exists in bin/fw
grep -q "Mirror divergence check" /opt/999-Agentic-Engineering-Framework/bin/fw
# fw doctor emits the mirror check (parity, asymmetry, or divergence — any active state proves it ran)
bin/fw doctor 2>&1 | grep -cE "Mirror (parity|asymmetry|divergence)" | grep -q '^[1-9]'
# No SHA conflicts between origin and github (the actually load-bearing invariant)
bin/fw doctor 2>&1 | grep -E "Mirror.*github" | grep -qv "Mirror divergence:"

## RCA

**Symptom:** AEF GitHub Mirror job in OneDev project 26 failed on every push for 50+ consecutive builds (~22h). GitHub master stayed at `eb18c73c5` (2026-04-27 23:13) while OneDev advanced 68 commits to `2b9413655` (2026-04-28 20:15). Nothing AEF-side reached GitHub during that window. T-1591 produced the analysis; this task is the execution + prevention.

**Root cause:** Annotated-vs-lightweight tag SHA mismatch on 7 tags (v1.2.0–v1.2.4, v1.5.743, v1.5.746). OneDev has annotated tag *objects* with their own SHAs wrapping commit + tagger metadata; GitHub had lightweight tags pointing directly at the same commits. Tag *content* dereferences identically (`tag^{} == lightweight SHA` for 6 of 7; for v1.5.743 OneDev's annotated points at a descendant of GitHub's commit — forward-move re-tag, not orphan-creating). Mirror push tried to update each ref non-fast-forward; even with `force: true` configured in `.onedev-buildspec.yml` since T-1513, the 22h window pre-dated the fix or some refs failed the per-ref force.

**Why structurally allowed:**
1. **No detection layer** — `fw doctor` had no check comparing remote refs. Drift between origin and mirror was invisible to the framework. T-1591 was discovered only via human side-channel observation after 50 failed builds.
2. **No release-flow guardrail** — tag creation can be `git tag <name>` (lightweight) or `git tag -a <name>` (annotated) with no project convention enforced. Mixed creation over time produces silent SHA drift.
3. **Mirror failure invisible** — OneDev build status isn't surfaced to the framework; the GitHub-mirror health is opaque from inside the consumer project.

**Prevention:**
1. **`fw doctor` mirror divergence check** (this task, bin/fw lines 1625-1681) — compares ref-by-ref between origin and other remotes, warns on SHA conflict, infos on benign asymmetry (origin-only/mirror-only refs without conflicts). Now runs on every audit pass and `fw doctor` invocation.
2. **Learning L-323** captures the failure-mode + detection + fix recipe so a future agent encountering tag-mismatch-mirror-rejection doesn't re-discover from scratch.
3. **Open follow-up:** standardise on annotated tag style at release time (T-1591 RCA Prevention #2) — separate concern, not in this task's scope. Suggest a future task to add `--annotated` default to whatever release script creates tags.
4. **Open follow-up:** wire OneDev mirror-job failure into Watchtower or `fw doctor` (T-1591 RCA Prevention #3) — currently the mirror is opaque; the divergence check catches the *symptom* but not the *upstream alarm*. Separate concern.

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6a0f3e37
- **Timestamp:** 2026-06-02T14:58:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 9
     - evidence: `bin/fw doctor 2>&1 | grep -cE "Mirror (parity|asymmetry|divergence)" | grep -q '^[1-9]'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 11
     - evidence: `bin/fw doctor 2>&1 | grep -E "Mirror.*github" | grep -qv "Mirror divergence:"`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `Force-push`
### 2026-04-28T21:36:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
