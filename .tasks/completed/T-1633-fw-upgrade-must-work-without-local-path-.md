---
id: T-1633
name: "fw upgrade must work without local-path knowledge — upstream URL + fresh-machine
  simulation guard"
description: >
  fw upgrade must work without local-path knowledge — upstream URL + fresh-machine
  simulation guard

status: work-completed
workflow_type: inception
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-05-01T10:13:34Z
last_update: '2026-06-11T22:23:54Z'
date_finished: 2026-05-01T10:29:47Z
bvp_scores_proposed:
  - ts: '2026-05-19T17:56:23Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 1
      D3: 0
      D4: 5
    rationale: D1=2 (body:learning-ref); D2=1 (body:log-or-error-line); D3=0 
      (no-signal); D4=5 (body:class-neutral)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:54Z'
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
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1633: fw upgrade must work without local-path knowledge — upstream URL + fresh-machine simulation guard

## Problem Statement

**Problem:** A vendored consumer cannot upgrade its framework. Every path an agent tries hits a structural wall (T-559 boundary + T-1542 self-target guard + no remote-fetch primitive) and the framework's own error message advertises a workaround the agent cannot run.

**For whom:** Every consumer in the wild — every agent on a fresh machine, every CI runner, every consumer's prod box. The flow has been silently dependent on the framework developer's local filesystem layout (`/opt/999-Agentic-Engineering-Framework`). My machine has it; nobody else's does.

**Why now:** Cohort agent on `002-Claude-Partner-Network` flailed today, exhausted every workaround, asked the human to type the command. This is the first time a consumer has actually had to upgrade itself without /opt/999 nearby. The blindness was always there; today made it audible.

**Full RCA + dialogue log:** [docs/reports/T-1633-fw-upgrade-no-local-path.md](docs/reports/T-1633-fw-upgrade-no-local-path.md)

## Assumptions

- A1: Every supported framework distribution is reachable via a stable git URL (onedev mirror + github mirror)
- A2: `git clone --depth 1` from inside a vendored consumer does not trip T-559 (it's not a `cd` to another project root)
- A3: Existing consumers can be migrated by reading `git remote get-url origin` from their `.agentic-framework/` if it's a git working tree; otherwise default URL
- A4: A clean LXC / docker container can run the fresh-machine simulation in under 60s

## Exploration Plan

This inception is **already complete** at the design-decision level — the RCA artifact captures the analysis. No spikes needed. The plan was the conversation that produced it.

GO decision authorizes filing two implementation build tasks:
- **T-XXXX (build):** `upstream:` field in `.framework.yaml` + git-fetch in `fw upgrade` (no-args path)
- **T-YYYY (build):** fresh-machine upgrade simulation — clean-container test, blocking on framework release

## Scope Fence

**IN scope:**
- New `upstream:` URL field; default seeded by `fw init` and `fw vendor`
- `fw upgrade` no-args path uses git clone instead of local source
- Clean-container simulation guard on every release
- Codify in CLAUDE.md: every consumer-facing command must run from a clean machine with no developer artifacts

**OUT of scope:**
- Auth for private upstreams (relies on user's existing git config; no new credential handling)
- Persistent `~/.framework-cache/` (start with per-invocation tempdir; add cache only if perf demands)
- Reverting T-1542 guard (stays as defensive safety net)
- Migrating consumers automatically — at most one-time prompt on next `fw upgrade`

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Recommendation:** GO — pursue all three sub-problems as a single arc

**Rationale:** A vendored consumer cannot upgrade itself without scavenging the developer's filesystem. The framework's upgrade flow has had an unstated precondition all along — *"the developer's checkout is somewhere on this filesystem"* — that's invisible until a non-developer hits it. T-1542 fixed the crash and shipped a louder dead-end; the user story stayed broken. The fix is structural: replace the local-path assumption with a remote URL, add the missing fresh-machine simulation guard, and codify the rule. Without the simulation guard, we will regenerate this class of failure forever.

**Evidence:**
- Cohort agent on `002-Claude-Partner-Network` exhausted every workaround today (subshell `cd`, `FRAMEWORK_ROOT=`, explicit `--target`) — all blocked by T-559 + T-1542 collision; ended by asking the human to type the command
- Every guard the framework has built is an inward guard (T-559, T-1542, PreToolUse task gate); no outward guard asks "can the consumer do its routine maintenance from a clean state"
- T-1542's decision log explicitly considered re-exec and rejected on "no reliable LOCAL target" — never considered remote URL; the frame excluded fetching
- This session: I shipped T-1626's immune-system loop (B-2/B-3a/B-3b/B-3c/B-4) — designed for catching this exact class of failure — and walked the same anti-pattern on T-1542 in the same session. The loop was for hooks; it didn't generalize. That's the second-order RCA.

**On GO, framework-agent files:**
- T-XXXX (build): `upstream:` field in `.framework.yaml` + git-fetch in `fw upgrade` no-args path; `fw init` + `fw vendor` seed the field
- T-YYYY (build): fresh-machine upgrade simulation — clean container, only `.agentic-framework/`, runs `fw upgrade`, asserts success + version bump; blocks framework release on failure; CLAUDE.md rule codified as part of the deliverable

T-1633 closes once both follow-ups are filed.

**On NO-GO / DEFER:** The upgrade flow remains broken for any consumer not on the developer's machine. Cohort agents will continue to flail and require human typing. T-1542's fail-fast will remain misleading. Defer would require an alternative remediation path (e.g., document the manual `fw vendor` + `.framework.yaml` edit sequence as the canonical agent flow, abandoning `fw upgrade` for vendored consumers).

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

**Rationale**: A vendored consumer cannot upgrade itself without scavenging the developer's filesystem. The framework's upgrade flow has had an unstated precondition all along — *"the developer's checkout is somewhere on this filesystem"* — that's invisible until a non-developer hits it. T-1542 fixed the crash and shipped a louder dead-end; the user story stayed broken. The fix is structural: replace the local-path assumption with a remote URL, add the missing fresh-machine simulation guard, and codify the rule. Without the simulation guard, we will regenerate this class of failure forever.

**Date**: 2026-05-01T10:29:46Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-01T10:29:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** A vendored consumer cannot upgrade itself without scavenging the developer's filesystem. The framework's upgrade flow has had an unstated precondition all along — *"the developer's checkout is somewhere on this filesystem"* — that's invisible until a non-developer hits it. T-1542 fixed the crash and shipped a louder dead-end; the user story stayed broken. The fix is structural: replace the local-path assumption with a remote URL, add the missing fresh-machine simulation guard, and codify the rule. Without the simulation guard, we will regenerate this class of failure forever.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d1663c3c
- **Timestamp:** 2026-06-02T14:58:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T10:29:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
