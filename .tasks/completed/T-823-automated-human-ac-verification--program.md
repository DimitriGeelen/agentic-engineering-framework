---
id: T-823
name: "Automated Human AC verification — programmatic, TermLink E2E, and Playwright
  approaches for stale task clearance"
description: >
  Inception: Automated Human AC verification — programmatic, TermLink E2E, and Playwright
  approaches for stale task clearance

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: []
created: 2026-04-03T22:52:29Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-03T23:05:55Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
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
---

# T-823: Automated Human AC verification — programmatic, TermLink E2E, and Playwright approaches for stale task clearance

## Problem Statement

51 stale tasks, 27 with unchecked Human ACs. Many have been waiting 10-26 days. Can we reduce this backlog by verifying them programmatically instead of requiring manual human testing?

## Assumptions

1. RUBBER-STAMP ACs with clear test steps can be automated
2. Watchtower UI verification can be done with HTTP requests + HTML parsing
3. TermLink can be used for E2E tests requiring separate processes
4. Playwright MCP can automate browser-based UI verification

## Exploration Plan

1. Categorize all 27 tasks by verification approach (30 min)
2. Phase 1: Run programmatic verification (shell commands) (15 min)
3. Phase 2: Playwright/HTTP verification of Watchtower UI (30 min)
4. Phase 3: TermLink E2E for CLI-based tests (30 min)
5. Compile evidence, present to human for approval

## Technical Constraints

- **Root Linux**: Playwright/Chrome fails with sandbox error on root — workaround: curl + HTML parsing
- **No macOS access**: 6 tasks require macOS (Homebrew, bash 3.2, Python 3.9) — no TermLink peer available
- **No API key**: E2E tests requiring Claude API calls can't run without ANTHROPIC_API_KEY
- **Authority model**: Agent can verify, but only human can CHECK the ACs

## Scope Fence

**IN:** Categorize tasks, run automated verification, collect evidence, present to human
**OUT:** Actually checking Human ACs (human authority), fixing Playwright sandbox, connecting to .107 Mac

## Acceptance Criteria

### Agent
- [x] Categorized 27 tasks by verification approach (A/B/C/D)
- [x] Phase 1: 4 programmatic tests run — 2 PASS, 2 SKIP
- [x] Phase 2: 7 HTTP verification tests — all 7 PASS
- [x] Phase 3: T-594 loop detector verified via synthetic test — PASS
- [x] Research artifact with full results: `docs/reports/T-823-automated-human-ac-verification.md`
- [x] Recommendation written

### Human
- [x] [REVIEW] Review 10 verified tasks and approve/close those with sufficient evidence
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-823-automated-human-ac-verification.md`
  2. Review "Execution Results" section — 10 tasks verified with evidence
  3. For each, decide if evidence is sufficient to check the Human AC
  4. Check ACs via Watchtower at http://192.168.10.107:3000/approvals
  **Expected:** At least 8 of 10 verified tasks have sufficient evidence for closure
  **If not:** Note which tasks need additional verification and why

## Go/No-Go Criteria

**GO if:**
- At least 10 tasks can be verified without human judgment
- Verification can run in under 5 minutes total
- Evidence is clear enough for human to approve without re-testing

**NO-GO if:**
- Automated verification provides false positives (passes when feature is broken)
- Evidence is insufficient for human to make confident approval decisions

## Recommendation

**GO** — 10 of 27 tasks (37%) verified with clear evidence. Verification ran in under 3 minutes total.

Findings:
- **Programmatic (curl + HTML)** is the best approach for Watchtower UI verification — faster and more deterministic than Playwright
- **Playwright** doesn't work on root Linux (sandbox issue). Not a blocker since curl-based verification is superior for server-rendered pages
- **TermLink E2E** works for process-level tests (loop detector), but macOS tests need .107 access
- **8 tasks genuinely require human judgment** (writing quality reviews, inception decisions) — cannot and should not be automated

**Recommended build tasks if GO:**
1. Create `bin/fw verify-acs` command that runs automated verification across stale tasks
2. Add HTTP smoke tests to Watchtower's existing test suite
3. Fix Playwright sandbox for interactive UI testing (lower priority)

## Verification

# Research artifact exists with results
test -f docs/reports/T-823-automated-human-ac-verification.md
grep -q "PASS" docs/reports/T-823-automated-human-ac-verification.md
grep -q "Phase 1" docs/reports/T-823-automated-human-ac-verification.md

## Decisions

**Decision**: GO

**Rationale**: GO — 10 of 27 tasks (37%) verified with clear evidence. Verification ran in under 3 minutes total.

Findings:
- Programmatic (curl + HTML) is the best approach for Watchtower UI verification — faster and more deterministic than Playwright
- Playwright doesn't work on root Linux (sandbox issue). Not a blocker since curl-based verification is superior for server-rendered pages
- TermLink E2E works for process-level tests (loop detector), but macOS tests need .107 access
- 8 tasks genuinely requ...

**Date**: 2026-04-03T23:05:55Z
## Decision

**Decision**: GO

**Rationale**: GO — 10 of 27 tasks (37%) verified with clear evidence. Verification ran in under 3 minutes total.

Findings:
- Programmatic (curl + HTML) is the best approach for Watchtower UI verification — faster and more deterministic than Playwright
- Playwright doesn't work on root Linux (sandbox issue). Not a blocker since curl-based verification is superior for server-rendered pages
- TermLink E2E works for process-level tests (loop detector), but macOS tests need .107 access
- 8 tasks genuinely requ...

**Date**: 2026-04-03T23:05:55Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-03T22:52:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-03T23:05:55Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** GO — 10 of 27 tasks (37%) verified with clear evidence. Verification ran in under 3 minutes total.

Findings:
- Programmatic (curl + HTML) is the best approach for Watchtower UI verification — faster and more deterministic than Playwright
- Playwright doesn't work on root Linux (sandbox issue). Not a blocker since curl-based verification is superior for server-rendered pages
- TermLink E2E works for process-level tests (loop detector), but macOS tests need .107 access
- 8 tasks genuinely requ...

### 2026-04-03T23:05:55Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6ef44bfd
- **Timestamp:** 2026-06-02T15:05:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
