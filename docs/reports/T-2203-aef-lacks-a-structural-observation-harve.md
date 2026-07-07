# T-2203 — AEF lacks a structural-observation harvester from dispatched workers back to

> **Inception research artifact** (backfilled by T-2515 from the `T-2203` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-2203-aef-lacks-a-structural-observation-harve.md`. **Decision recorded: DEFER.**

## Problem Statement

Workers dispatched via `fw termlink dispatch` operate inside consumer projects (`/opt/fan-dashboard`, `/opt/832-Workflow-designer`, etc.) and can observe framework-level gaps as they work. T-2200's worker hit a corrupted `/root/.claude.json` diagnostic that the dispatch surface should have caught; T-2202's worker hit a `FRAMEWORK_ROOT` env-leak from the parent that the dispatch contract should have scrubbed. Both observations are valuable structural-improvement signal, but **there is no mechanism for them to bubble back to `/opt/999-Agentic-Engineering-Framework`**.

In this session, the bubble-up happened only because the parent (this agent) was alive, attentive, and tailing the workers' `result.jsonl`. Once the parent session ends, anything a worker observes in `/opt/<consumer>/.tasks/active/*upstream-framework*` will sit there indefinitely — no harvester polls it, no cron picks it up, no human will see it unless they happen to walk into that consumer's repo.

**For whom:** every framework maintainer (today: the operator + this agent class) who wants worker-side framework-blindness observations to feed the inception backlog.

**Why now:** two worker-side observations landed in one session (T-2200 + T-2202). The pattern is repeating. The `fw pickup` primitives exist but aren't wired to "upstream-framework" semantics; my worker prompt (T-2200's brief) ASKED workers to file local inceptions tagged `upstream-framework`, which is structurally hollow — nothing harvests them.

## Assumptions

- A1: `fw pickup send|process|list` covers the cross-project transport layer (text payload, recipient project, deliverable artefact). What's missing is the *what-to-send* contract for structural observations, not the transport. Verify: `bin/fw pickup --help` and read `lib/pickup.sh`.
- A2: Workers can `cd` and run fw commands inside the framework repo via `--remote` SSH dispatch from the consumer's TermLink session. If true, the worker can directly file an inception in the framework repo without a separate harvester step. Verify: try `fw dispatch send --host localhost --task T-XXX ...` from a worker context.
- A3: The volume of structural observations from workers will be low (~0-5 per worker run, only when framework gaps surface). A polled harvester would be overkill; event-driven bus or direct fw-pickup is sufficient. Test: observe T-2200 + T-2202 workers' final reports; count `upstream-framework`-class observations.

## Open Questions

- **IW-1: Which side files the inception — worker files local + parent harvests, OR worker directly sends via `fw pickup` (or `fw dispatch send`) to the framework repo?**
  confidence: 1
  disposition: <decide-time>
  rationale: <decide-time>

- **IW-2: If "worker files local + parent harvests", what's the harvester trigger — cron, `fw pickup process` manual, dispatch-end event, OR `fw doctor` advisory?**
  confidence: 0
  disposition: <decide-time>
  rationale: <decide-time>

- **IW-3: What's the structural-observation envelope — frontmatter tag (`upstream-framework`), prefix on inception name (`UPSTREAM:`), separate file class (`.context/observations/`), OR existing `fw note` observation primitive?**
  confidence: 2
  disposition: <decide-time>
  rationale: <decide-time>

- **IW-4: Should the dispatch contract REQUIRE workers to write a `## Framework Observations` section in their final-report blob (even if empty), making the absence-of-signal explicit and the presence-of-signal greppable?**
  confidence: 2
  disposition: <decide-time>
  rationale: <decide-time>


-->

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Recommendation

**Recommendation:** DEFER

**Rationale:** Genuine evidence gap, not a confidence gap (T-2144 author-time discipline). Four open questions (IW-1..IW-4) are untested — no spike has been run to confirm (a) whether workers can directly call `fw pickup send` from inside a consumer-side TermLink session back to the framework repo, (b) what cadence harvester is appropriate, (c) what envelope shape is greppable enough to be a structural signal, (d) whether the dispatch contract should mandate a `## Framework Observations` section in the final-report blob. The observable problem is real (T-2200 and T-2202 workers both produced structural-improvement signal that would sit unread without an active parent), but the fix surface (where the harvester lives + which side files) is unconstrained. DEFER until at least one of: (i) `fw pickup send` transport spike from inside a worker context succeeds and gives IW-1 a bias, (ii) a third worker-dispatch session produces a structural observation, raising signal volume above the "low frequency, parent-attentive" assumption (A3). Re-surface trigger: third worker incident OR completion of IW-1 transport spike.

**revisit_at:** 2026-06-18 (two weeks; matches the rough cadence of upstream-framework-observation worker incidents this session — 2 in 30 minutes; even a conservative re-rate of 1/week implies a third incident by then).

**revisit_evidence_needed:** EITHER (a) third worker-dispatch session producing an upstream-framework observation, OR (b) a 30-minute spike confirming `fw pickup send` works from inside a consumer-side TermLink session, OR (c) operator pushes a different harvester contract proposal.

**Evidence:**
- T-2200 worker (fan-dashboard) produced FRAMEWORK_ROOT env-leak observation — would sit unread without active parent.
- T-2202 worker (workflow-designer) produced same — second incident, same session.
- Worker brief in T-2200 asked workers to file local upstream-framework-tagged inceptions, but no harvester reads those (structurally hollow contract).
- `fw pickup` transport layer exists (`lib/pickup.sh`) but is not wired to upstream-framework semantics.
- No spike done on whether workers can `fw dispatch send` back to the framework repo from inside their TermLink session.
- All 4 IW-N questions filed at confidence 0-2 — disposition pending data.

## Decision

**Decision**: GO

**Rationale**: Genuine evidence gap, not a confidence gap (T-2144 author-time discipline). Four open questions (IW-1..IW-4) are untested — no spike has been run to confirm (a) whether workers can directly call `fw pickup send` from inside a consumer-side TermLink session back to the framework repo, (b) what cadence harvester is appropriate, (c) what envelope shape is greppable enough to be a structural signal, (d) whether the dispatch contract should mandate a `## Framework Observations` section in the final-report blob. The observable problem is real (T-2200 and T-2202 workers both produced structural-improvement signal that would sit unread without an active parent), but the fix surface (where the harvester lives + which side files) is unconstrained. DEFER until at least one of: (i) `fw pickup send` transport spike from inside a worker context succeeds and gives IW-1 a bias, (ii) a third worker-dispatch session produces a structural observation, raising signal volume above the "low frequency, parent-attentive" assumption (A3). Re-surface trigger: third worker incident OR completion of IW-1 transport spike.

**Date**: 2026-06-04T19:47:41Z
