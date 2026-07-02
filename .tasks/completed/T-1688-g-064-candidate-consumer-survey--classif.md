---
id: T-1688
name: "G-064 candidate-consumer survey — classify every autonomous workload for orchestrator
  retrofit"
description: >
  G-064 candidate-consumer survey — classify every autonomous workload for orchestrator
  retrofit

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-02T21:05:48Z
last_update: '2026-06-11T22:23:56Z'
date_finished: 2026-05-03T07:10:15Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:56Z'
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

# T-1688: G-064 candidate-consumer survey — classify every autonomous workload for orchestrator retrofit

## Problem Statement

G-064 says: orchestrator substrate has zero production consumers. Prior session brainstormed three candidate paths (audit refactor NO-GO, cron health-check captured, opt-in flag not autonomous). This survey asks the broader question: of every autonomous workload running today, which is the strongest retrofit candidate? Settling this lets the human decide between "accept G-064 long-term", "ship synthetic health-check", or "schedule a real consumer roadmap".

## Assumptions

- A1: At least one of the 18 cron jobs has LLM-amenable workload (where an LLM adds real value over current bash/python).
- A2: Retrofit is cheaper than building a brand-new consumer.
- A3: The "weakest path" (synthetic cron) only mitigates the cold-cache symptom, not the underlying gap.

## Exploration Plan

1. Enumerate every cron in `.context/cron/agentic-audit.crontab`.
2. Locate each entry point in `agents/` / `lib/` / `tools/`.
3. Classify each on three axes: workload kind, LLM-amenability, retrofit difficulty.
4. Code-wide scan for existing autonomous claude/termlink invocations.
5. Pick the strongest candidate (or rule out retrofit).

Time-box: one session.

## Technical Constraints

None new — survey is read-only.

## Scope Fence

**IN:** classify all autonomous workloads, recommend candidate (or rule out retrofit), write artifact.
**OUT:** building any consumer, deciding on reviewer v2.x or escalation-scan v0.5 scope, modifying route_cache or orchestrator code.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — survey enumerates every cron in `.context/cron/agentic-audit.crontab` and classifies each
- [x] All 18 autonomous workloads classified on three axes (workload kind, LLM-amenability, retrofit difficulty)
- [x] Code-wide scan for `claude -p` / `termlink dispatch` invocations completed and reported
- [x] Recommendation written with cited evidence (file paths, line numbers, route_cache state)
- [x] Research artifact at `docs/reports/T-1688-candidate-consumer-survey.md` exists and is committed

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if (option 1+4 — accept long-term + schedule escalation-scan v0.5):**
- Survey confirms zero existing autonomous workload is LLM-amenable retrofit
- Evidence shows escalation-scan v0 explicitly names a successor
- Human accepts that orchestrator stays a developer-facing tool while v0.5 proceeds as the real closure path

**NO-GO if:**
- Human prefers option 2 (T-1684 cron health-check now) — synthetic but immediate
- Or option 3 (commit to reviewer v2.x as the real closure) — bigger, slower, but stronger

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO on option **1 + 4** — accept G-064 as long-term reality (orchestrator is a developer-facing tool today) AND file a child inception for `escalation-scan v0.5` (LLM-augmented escalation scan as the planned real consumer).

**Rationale:** The survey rules out retrofit. None of the 18 existing autonomous workloads is LLM-amenable today; the two plausible candidates (reviewer v2.x, escalation-scan v0.5) are both genuine future work, not "ship this week" retrofits. Option 1 is honest; option 4 turns G-064 from "watching" to "mitigating" via the smallest concrete real-consumer path with internal source-code precedent (`tools/escalation-scan-v0.py:1` calls itself a v0 spike, lines 6–10 say "intentionally simple").

**Evidence:**
- 18 cron jobs surveyed in `.context/cron/agentic-audit.crontab` — all classified in `docs/reports/T-1688-candidate-consumer-survey.md`
- `grep -rln "claude -p\|fw termlink dispatch\|termlink dispatch" agents/ lib/ tools/` returns 4 files, none autonomous
- `lib/reviewer/static_scan.py:18-19` — explicit deferred consumer ("Orchestrator routing (v3+)")
- `tools/escalation-scan-v0.py:1,6-10` — explicit v0 spike with named successor
- Route cache state: 5 keys, all `last_used: 2026-05-02` (today), confirms cold-cache concern in G-064 description

T-1684 (cron health-check) stays captured as the "if 4 stalls" fallback.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO on option 1 + 4 — accept G-064 as long-term reality (orchestrator is a developer-facing tool today) AND file a child inception for `escalation-scan v0.5` (LLM-augmented escalation scan as the planned real consumer).

Rationale: The survey rules out retrofit. None of the 18 existing autonomous workloads is LLM-amenable today; the two plausible candidates (reviewer v2.x, escalation-scan v0.5) are both genuine future work, not "ship this week" retrofits. Option 1 is honest; option 4 turns G-064 from "watching" to "mitigating" via the smallest concrete real-consumer path with internal source-code precedent (`tools/escalation-scan-v0.py:1` calls itself a v0 spike, lines 6–10 say "intentionally simple").

Evidence:
- 18 cron jobs surveyed in `.context/cron/agentic-audit.crontab` — all classified in `docs/reports/T-1688-candidate-consumer-survey.md`
- `grep -rln "claude -p\|fw termlink dispatch\|termlink dispatch" agents/ lib/ tools/` returns 4 files, none autonomous
- `lib/reviewer/static_scan.py:18-19` — explicit deferred consumer ("Orchestrator routing (v3+)")
- `tools/escalation-scan-v0.py:1,6-10` — explicit v0 spike with named successor
- Route cache state: 5 keys, all `last_used: 2026-05-02` (today), confirms cold-cache concern in G-064 description

T-1684 (cron health-check) stays captured as the "if 4 stalls" fallback.

**Date**: 2026-05-03T07:10:14Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-02T21:09:09Z — status-update [task-update-agent]
- **Change:** tags: +gap-consumer

### 2026-05-02T21:09:09Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink

### 2026-05-03T07:10:14Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO on option 1 + 4 — accept G-064 as long-term reality (orchestrator is a developer-facing tool today) AND file a child inception for `escalation-scan v0.5` (LLM-augmented escalation scan as the planned real consumer).

Rationale: The survey rules out retrofit. None of the 18 existing autonomous workloads is LLM-amenable today; the two plausible candidates (reviewer v2.x, escalation-scan v0.5) are both genuine future work, not "ship this week" retrofits. Option 1 is honest; option 4 turns G-064 from "watching" to "mitigating" via the smallest concrete real-consumer path with internal source-code precedent (`tools/escalation-scan-v0.py:1` calls itself a v0 spike, lines 6–10 say "intentionally simple").

Evidence:
- 18 cron jobs surveyed in `.context/cron/agentic-audit.crontab` — all classified in `docs/reports/T-1688-candidate-consumer-survey.md`
- `grep -rln "claude -p\|fw termlink dispatch\|termlink dispatch" agents/ lib/ tools/` returns 4 files, none autonomous
- `lib/reviewer/static_scan.py:18-19` — explicit deferred consumer ("Orchestrator routing (v3+)")
- `tools/escalation-scan-v0.py:1,6-10` — explicit v0 spike with named successor
- Route cache state: 5 keys, all `last_used: 2026-05-02` (today), confirms cold-cache concern in G-064 description

T-1684 (cron health-check) stays captured as the "if 4 stalls" fallback.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b5ac02cc
- **Timestamp:** 2026-06-02T14:59:07Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T07:10:15Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
