---
id: T-1726
name: "escalation-scan v0.5 — LLM augmentation as G-064 first real consumer"
description: >
  Inception: escalation-scan v0.5 — LLM augmentation as G-064 first real consumer

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-05-04T21:34:52Z
last_update: 2026-05-04T21:53:12Z
date_finished: 2026-05-04T21:53:12Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1726: escalation-scan v0.5 — LLM augmentation as G-064 first real consumer

## Problem Statement

**G-064**: orchestrator substrate has zero production consumers — the v1 dispatch substrate (T-1689/1690/1691/1692) shipped in T-1700/1714 but no autonomous workload routes through it. Without real consumers, route_cache stays cold and the substrate's value is unmeasurable. T-1688's survey concluded that retrofitting any of the 18 existing crons is uneconomical (none LLM-amenable today) and named **escalation-scan v0.5** as the smallest greenfield path: an LLM-augmented sibling of `tools/escalation-scan-v0.py` that uses the orchestrator to dispatch per-candidate analysis.

**For whom:** the framework's own learning loop. v0 catches symptom-fix candidates structurally (H1/H2/H3 heuristics over `## RCA`, learning-IDs, fix-tagged commits). v0.5 turns "candidates" into "graded triage" — for each candidate, ask an LLM "is this a real symptom-fix incident, or a false positive?" and capture the verdict. This is the workload the route_cache was designed to learn from.

**Why now:** the dispatch substrate is in place (`fw resolver dispatch`, dispatch-outcomes.jsonl, route_cache); the v0 scan ships a report into `escalation-drift-LATEST.yaml` weekly via cron; oe-daily already wires `tools/escalation-scan-v0.py` (T-1665). Adding v0.5 as an additive sibling avoids any risk to v0's heuristic output and gives the orchestrator its first repeatable, autonomous, real consumer.

## Assumptions

- **A1**: LLM-graded triage of each v0 candidate adds signal v0's heuristics miss (i.e., the LLM disagrees with the heuristic verdict in non-trivial fraction of cases). Falsifier: <10% disagreement → v0.5 isn't worth its cost.
- **A2**: Daily cadence is the right granularity. Falsifier: candidates churn faster than daily (false-positive flare on every commit) or slower (no candidates for weeks).
- **A3**: Per-candidate cost is bounded. Falsifier: a single scan exceeds $0.50 of LLM tokens with default workflow.
- **A4**: Outcome enrichment (T-1697 substrate) cleanly captures the LLM verdict for route_cache learning. Falsifier: the verdict format doesn't fit dispatch-outcomes.jsonl schema.
- **A5**: ollama-local is sufficient quality for triage; cloud fallback is only for cost spikes / unreachability. Falsifier: ollama produces obviously wrong triages on common cases.

## Exploration Plan

Two spikes, time-boxed.

**Spike 1 — copy v0 heuristic output, dispatch one candidate** (~30 min):
- Take the most recent `escalation-drift-LATEST.yaml` candidate.
- Manually run `fw resolver dispatch <synthetic-task-id> escalation-triage --json` with that candidate as context.
- Inspect the dispatch envelope, run the worker (ollama-local), capture the outcome row.
- Question answered: does the substrate work end-to-end for this workload?

**Spike 1 first-pass result (2026-05-04, dry-run only, this session):**
`fw resolver dispatch T-1075 default --dry-run --json` succeeds end-to-end.
Envelope ships with prompt (assembled from task frontmatter + recent dispatches +
matched healing patterns), model=sonnet, worker_kind=TermLink, allowed_tools,
cost_cap_usd=1.5, blob_dir, cwd boundary guard. Substrate proven at envelope level.

**Open from Spike 1:**
- `ollama-research` workflow has `worker_kind: ollama-loop` which isn't in
  the validator's `valid: ['Task', 'TermLink', 'pi']` list. v0.5 needs either
  worker_kind=TermLink (with ollama prompt routing) or a new ollama-loop
  enum entry. Resolver-side validator change is small (~1 LOC + tests).
- Default prompt template emits `<!-- resolver: unresolved $VARs: ['VAR'] -->` —
  pre-existing template bug, irrelevant to v0.5 but worth filing.

**Spike 2 — disagreement rate on a small backlog** (~30 min):
- Run v0.5 prototype on the last 30 days of completed tasks.
- Compare LLM verdict vs heuristic verdict on overlapping candidates.
- Question answered: A1 — does the LLM add signal?

After both spikes: write findings to `docs/reports/T-1726-v0-5-spikes.md`, update Recommendation with evidence, hand to human.

## Technical Constraints

- **Cron host**: ollama is at 192.168.10.107:11434 (per CLAUDE.md). v0.5 cron must be reachable from the framework host.
- **Cost cap**: needs per-run hard cap. Fallback to cloud (claude-via-litellm) only on ollama unreachability, never as default. Configurable in workflow YAML.
- **Idempotency**: v0.5 runs daily — duplicate triage of the same candidate within N days should be detected and skipped (mtime/checksum guard).
- **Fail-safe**: v0.5 failure must NOT impair v0. Sibling, not replacement.

## Scope Fence

**IN scope (v0.5):**
- LLM-graded triage of v0's existing candidates (one workflow file, one worker_kind path).
- Output: `escalation-drift-LATEST-v0.5.yaml` mirror with `verdict` + `reasoning` per candidate.
- Daily cron via oe-daily.
- Watchtower panel surface (or augmentation of the existing v0 panel) showing the triage column.
- Outcome capture into route_cache via existing T-1697 substrate.

**OUT of scope (deferred to v1+ if v0.5 succeeds):**
- New heuristics beyond H1/H2/H3 (those are v0's job).
- Auto-actioning — v0.5 is read-only triage, no mutations.
- Multi-LLM ensemble or self-critique loops.
- Reviewer integration (T-1722 territory).
- Coupling to fabric, learnings-bus, or external alerting.

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

**GO if:**
- Spike 1 shows the substrate works end-to-end for this workload (envelope → worker → outcome row).
- Spike 2 shows ≥10% LLM-vs-heuristic disagreement on the 30-day backlog (A1 holds).
- Cost projection per daily run is bounded (≤$0.10/day at expected candidate volume).
- Schema fit confirmed: LLM verdict cleanly serializes into `dispatch-outcomes.jsonl`.

**NO-GO if:**
- Spike 1 reveals a substrate gap requiring substrate work (kicks back to T-1700/T-1701 family).
- Spike 2 disagreement rate <10% (A1 falsified — heuristics are sufficient).
- Cost projection exceeds $0.50/day (A3 falsified — per-candidate cap doesn't hold).
- ollama produces visibly wrong triages on common cases (A5 falsified — quality floor not met).

**DEFER if:**
- Spikes blocked on dispatch substrate fixes that are still pending (T-1700 review, T-1714 follow-ups).
- Real-consumer signal degrades T-1688's option 4 ranking (e.g., a stronger candidate emerges from in-flight work).

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

**Recommendation:** GO

**Rationale:**

T-1688 surveyed all 18 autonomous workloads and concluded option 4 — file v0.5 inception — is the smallest concrete path to G-064 closure. v0 exists at tools/escalation-scan-v0.py (read-only heuristic scan, ships report); v0.5 adds LLM augmentation via the orchestrator (the named real consumer). Inception is needed to nail exact scope: what LLM-amenable analysis v0.5 adds beyond H1/H2/H3 heuristics, output schema, cost cap, integration with daily oe-daily cron. Path is named in T-1688; remaining open questions are scope, not whether-to-build.

**Evidence:**

- T-1688 ## Recommendation block (`.tasks/completed/T-1688-g-064-candidate-consumer-survey--classif.md`): GO on option 1+4 — accept G-064 long-term + file v0.5 inception. Survey output at `docs/reports/T-1688-candidate-consumer-survey.md`.
- v0 substrate: `tools/escalation-scan-v0.py` lines 6-10 ("intentionally simple") and line 1 ("v0 spike") name v0.5 as intended successor. Daily cron wiring already in place via T-1665 (oe-daily).
- Dispatch substrate: `lib/resolver.py`, `lib/outcome.py`, `.context/dispatches.jsonl`, `.context/dispatch-outcomes.jsonl` — all live (T-1689/1690/1691/1692 shipped). Outcome enrichment proven by T-1697.
- Sister-arc precedent: T-1700 (litellm proxy) is in human review and proves the v1 substrate's other half works. v0.5 is the workload; T-1700 is the dispatch path.
- G-064 description in concerns.yaml: "high" severity, watching since arc decision; T-1688 confirmed retrofit is exhausted.
- **Spike 1 dry-run executed this session**: `fw resolver dispatch T-1075 default --dry-run --json` produces a full dispatch envelope (prompt, model, worker_kind, allowed_tools, cost_cap, blob_dir, cwd) — substrate proven at envelope level. Two minor open items captured in Exploration Plan above (worker_kind validator + template `$VAR` leak).

**Risk acknowledged:**

- **Spike fatigue.** If both spikes produce ambiguous findings (e.g., 8% disagreement rate — close to threshold), the inception risks deferring forever. Mitigation: time-box spikes to one session each; if the disagreement signal is genuinely ambiguous, that's itself a NO-GO (means the heuristics already capture the actionable signal).
- **Substrate-vs-deliverable conflation (§ACD).** Same shape as G-066. Mitigation: headline mechanic for this consumer is *visible*: `/orchestrator` page must show v0.5 dispatches + outcomes as they accumulate. If the substrate fires but the user can't see the consumer in the UI, the AC isn't met.
- **Filing-without-build risk.** This inception names a build path. If GO is recorded, a separate build task (T-1727 placeholder, not yet filed) ships v0.5 — under §ACD, that build task must own the headline-mechanic verification, not this inception.

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

**Rationale**: T-1688 surveyed all 18 autonomous workloads and concluded option 4 — file v0.5 inception — is the smallest concrete path to G-064 closure. v0 exists at tools/escalation-scan-v0.py (read-only heuristic scan, ships report); v0.5 adds LLM augmentation via the orchestrator (the named real consumer). Inception is needed to nail exact scope: what LLM-amenable analysis v0.5 adds beyond H1/H2/H3 heuristics, output schema, cost cap, integration with daily oe-daily cron. Path is named in T-1688; remaining open questions are scope, not whether-to-build.

**Date**: 2026-05-04T21:53:12Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-04T21:53:12Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** T-1688 surveyed all 18 autonomous workloads and concluded option 4 — file v0.5 inception — is the smallest concrete path to G-064 closure. v0 exists at tools/escalation-scan-v0.py (read-only heuristic scan, ships report); v0.5 adds LLM augmentation via the orchestrator (the named real consumer). Inception is needed to nail exact scope: what LLM-amenable analysis v0.5 adds beyond H1/H2/H3 heuristics, output schema, cost cap, integration with daily oe-daily cron. Path is named in T-1688; remaining open questions are scope, not whether-to-build.

### 2026-05-04T21:53:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

## Reviewer Verdict (v1.5)

- **Scan ID:** R-88469ce2
- **Timestamp:** 2026-06-02T14:59:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T21:53:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
