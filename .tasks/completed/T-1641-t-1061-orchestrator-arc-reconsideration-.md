---
id: T-1641
name: "T-1061 orchestrator arc reconsideration — what got lost between inception, exploration, and shipped phases?"
description: >
  User flagged (2026-05-01 mid-loop): the arc is being treated as 'shipped' but nothing has been demonstrated to actually orchestrate; no test cases run; no human consultation on routing rules. Re-examine the original T-1061 inception, exploration, and scoping artefacts to surface what got lost. Multi-agent investigation via TermLink (up to 10 workers) writing to docs/reports/T-XXXX-worker-NN-*.md. C-001 research-artefact-first discipline. Output: aggregated findings + concrete arc-or-arcs proposal.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [from-T-1061, termlink, orchestrator, reconsideration, multi-agent]
components: [C-004, agents/audit/orchestrator-mcp-scan.sh, web/blueprints/__init__.py, web/blueprints/orchestrator.py, web/templates/orchestrator.html]
related_tasks: []
arc_id: orchestrator-rethink
created: 2026-05-01T11:30:01Z
last_update: 2026-05-01T18:58:36Z
date_finished: 2026-05-01T12:29:12Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1641: T-1061 orchestrator arc reconsideration — what got lost between inception, exploration, and shipped phases?

## Problem Statement

User pushback (2026-05-01, mid-/loop, verbatim):

> "i am absolutely seeing nothing that indicates we are now 'orchestrating' neither have we run test cases for it, nor have i been consulted for routing rules etc … lets multi agent termlink incept this, also look back at our original inception, exploration and scoping, feeling we missed out a whole bunch, that has gotten lost !!! also lets make sure we arc this means link it to and arc (or multiple for that matter) spend 10 agents if needed, this is major"

The agent has been treating the orchestrator arc (T-1061 → T-1062–T-1066) as "shipped" based on:
- `cargo check` and `cargo test --lib` passing (unit tests, in isolation)
- Reading line numbers in `tools.rs` showing the code paths exist
- One pure refactor (T-1638) shipped via TermLink dispatch

The agent did **not**:
- Run any end-to-end orchestrated call (no specialist routing observed)
- Spawn task-typed specialists and verify routing actually picks them
- Exercise the model fallback chain or breaker
- Observe a Governance frame (0x8) on the wire
- Consult the human on routing rules (task_types, model preferences, fallback order, bypass thresholds)
- Confirm the framework actually USES the new orchestration features anywhere

The honest current state is **code-complete, behaviorally unverified, policy unconsulted.**

## Assumptions

- A1: The original T-1061 inception artefact (`docs/reports/T-1061-termlink-governance-substrate.md`) and review-feedback artefact (`docs/reports/T-1061-termlink-review-feedback.md`) contain scope/concerns/capabilities that never became tasks.
- A2: The phases as shipped delivered less than what T-1061 promised (e.g., MCP "governance" vs a `task_id` parameter; orchestrator routing vs task_type tag matching).
- A3: G-011, G-015, G-017 (the three known governance gaps the arc aimed to address) have not measurably moved.
- A4: The framework (this repo) does not actually USE the orchestrator features it built — they sit in /opt/termlink unused.
- A5: There is no audit/test/monitor that catches the orchestrator arc rotting (no MCP-tool task_id-enforcement test, no fallback-chain regression test, no governance-frame smoke test).
- A6: Routing-rule decisions (task_types, model preferences, thresholds, fallback) were silently defaulted by code authors, not consulted with the human.

## Exploration Plan

Multi-agent TermLink dispatch — 10 workers in parallel, each writing findings to `docs/reports/T-1641-worker-NN-<topic>.md`:

1. **W01 — Inception coverage gap:** read T-1061 fully; cross-reference each phase's promise vs what the corresponding task actually shipped.
2. **W02 — Review-feedback mining:** read `T-1061-termlink-review-feedback.md` (19KB); surface every concern/capability/correction that never became a task.
3. **W03 — /opt/termlink current state vs promises:** probe live code via `termlink interact termlink-agent`; verify each T-1061 claim against actual implementation (which MCP tools enforce task_id? what task_types are recognized? what's the actual fallback chain?).
4. **W04 — Framework-side usage:** is the arc actually wired into /opt/999 daily operation, or sitting unused in /opt/termlink?
5. **W05 — Gap movement (G-011/G-015/G-017):** has the arc moved the needle on any of these in `concerns.yaml`?
6. **W06 — Constitutional directive evidence:** for each phase's claim against Antifragility/Reliability/Usability/Portability, find evidence (or absence) of delivery.
7. **W07 — Cross-arc connections:** does this arc connect to T-1626 (immune system loop), T-1633 (fw upgrade redesign), T-1542, or other in-flight work?
8. **W08 — Routing-rules policy questions:** list every parameter/threshold/default/fallback in the orchestrator code; surface what should have been a human decision but wasn't.
9. **W09 — End-to-end orchestration smoke:** actually run a routed call (spawn 2 specialists with different task-type tags, route a request, observe behavior); produce live-evidence report.
10. **W10 — Drift defenses:** what tests/audits/monitors should EXIST to keep the arc from rotting; surface absent defenses.

## Technical Constraints

- Workers run via `fw termlink dispatch` — each gets its own session, zero parent-context cost.
- W09 needs live TermLink to spawn specialists; must run after sessions are clean (no leftover from this session's t1638-worker).
- Per CLAUDE.md TermLink output rule (T-818): all worker outputs to `docs/reports/T-1641-worker-NN-*.md`, NOT `/tmp/`.
- Workers must reference T-1641 in their prompts for governance traceability.
- Aggregation step has to read 10 files of ~3-5KB each = manageable in one session if budget allows; otherwise hand back to next session.

## Scope Fence

**IN scope:**
- Re-reading T-1061 inception + review-feedback artefacts and child task files
- Probing /opt/termlink current state vs promises
- Surfacing what got lost / never tasked / never consulted
- Filing new tasks for surfaced gaps with `from-T-1641` tag and arc linkage
- Producing a clear arc-or-arcs proposal for the next pass

**OUT of scope:**
- Implementing any of the surfaced gaps in this inception (build tasks file separately)
- Re-litigating already-shipped code unless a worker surfaces a real defect
- Multi-LLM cost-aware routing (T-1637, kept horizon:later)
- RoutingKey newtype refactor (T-1636, kept horizon:later until next dimension lands)

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Research artefact `docs/reports/T-1641-orchestrator-arc-reconsideration.md` exists with the user pushback dialogue captured verbatim and the investigation plan
- [x] At least 8 of 10 TermLink workers dispatched (slots W01–W10), each writing findings to `docs/reports/T-1641-worker-NN-<topic>.md` — 10/10 dispatched 2026-05-01T11:36Z, sessions: w01-coverage, w02-feedback, w03-state, w04-usage, w05-gaps, w06-directives, w07-arcs, w08-policy, w09-smoke, w10-defenses
- [x] Aggregated "what got lost" list compiled into the master research artefact — 30 items (L1–L30) reconciled in `docs/reports/T-1641-orchestrator-arc-reconsideration.md` §Findings
- [x] Each "lost" item is either filed as a new task (with `from-T-1641` tag) or explicitly reconciled — T-1642 (Arc A inception, policy), T-1643 (Arc B build, framework wiring), T-1644 (Arc C build, drift defenses), T-1645 (G-015 reframe inception); 4 items reconciled by direct edit (G-011/G-017 in concerns.yaml, related_tasks cross-link on T-1062/4/5/6/T-1636/7/9/40, Recommendation rewrites on T-1062/4/5/6, L-334 + D-058 captured); 5 deferred to T-1637 / horizon:later or out-of-scope
- [x] Recommendation written with concrete arc-or-arcs proposal for the next pass — three distinct arcs (A=policy, B=wiring, C=defenses) with explicit blocking relationship (B blocked on A) + decision-only inception L9 + housekeeping reconciled in this pass; G-061 (orchestrator-arc rot) and G-062 (framework-blindness pattern) registered in concerns.yaml

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

**Recommendation:** GO — but **NOT** as a single-arc continuation of T-1061. Split into three distinct arcs (A=policy, B=wiring, C=defenses) with one decision-only inception.

**Rationale:** 10-worker investigation confirmed the user's pushback: the orchestrator arc is **behaviorally real (W09 proved task-type routing + cache + failover on the wire), but operationally dormant and policy-unconsulted.** Bundling the gaps into one mega-arc is exactly the T-1061 mistake replayed — three different failure modes wearing one outfit.

**The three arcs and inception:**
- **T-1642 (Arc A — INCEPTION, horizon:now):** Routing-policy consultation. 13 hardcoded constants surface as explicit human decisions. **Blocks Arc B's framework-wiring completion.**
- **T-1643 (Arc B — BUILD, horizon:next):** Framework-side wiring. Make /opt/999 actually USE the substrate (zero call-sites pass task_type or --model today). Co-arc with /opt/termlink hardening (gate the 71 ungated MCP mutators, wire run_with_governance, ship min-sample guard, surface fallback state). **Blocked on T-1642.**
- **T-1644 (Arc C — BUILD, horizon:now):** Drift defenses. 10 absent structural protections from W10 — MCP-tool task_id audit, fallback-chain regression test, governance-frame golden fixture, tag-format validator, route_cache schema test, Watchtower /orchestrator page. Runs parallel to Arc A.
- **T-1645 (decision-only inception, horizon:next):** G-015 reframing — narrow T-1061's claim or open non-TermLink workstream for sub-agent /tmp/ bypass.

**Evidence:** (full trace in `docs/reports/T-1641-orchestrator-arc-reconsideration.md`)
- W09 live wire test: orchestration **does** work — spawned 2 specialists with `task-type:` tags, routed 3 ways, killed one, observed cache rewrite + fallback. Core T-1061 promise is not vapourware.
- W03: 4 of 75 MCP tools enforce `check_task_governance`; 71 ungated (incl. mutators `inject`, `run`, `remote_exec`, `batch_exec`, `send`, `kv_*`).
- W04: Framework has zero call-sites passing `task_type`; `--model` flag exists in `agents/termlink/termlink.sh:278` but no caller passes it; zero `GovernanceSubscriber` references anywhere in `agents/ bin/ lib/ web/`.
- W06: Production audit log records only `{ts, method, peer_addr}`; `orchestrator.route` fired **0×** in 71,275 events — circuit breaker never opened, fallback chain never exercised.
- W08: 13 routing-policy constants silently defaulted (model fallback chain, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, DEFAULT_TTL_HOURS=168, CONFIDENCE_THRESHOLD=0.8, task_type taxonomy free-string, tag prefix, concurrency cap, success/failure attribution, selector role contract, default-on governance, discovery filter strictness).
- W05: Concerns register went unmodified across the entire arc; G-011/G-015/G-017 last_reviewed dates predate T-1061's inception.
- W07: Same "shipped before substrate-verified" signature as T-1626 + T-1633 — three independent G-019 escalations in five weeks. Captured as **G-062** with proposed structural mechanisms.
- W10: Zero drift defenses exist (10 enumerated). Captured as **G-061**.

**Housekeeping completed in this aggregation pass (not new tasks):**
- Updated G-011 (record T-1063 partial mitigation) and G-017 (accepted-risk with rationale) in concerns.yaml.
- Added G-061 (orchestrator-arc rot) and G-062 (framework-blindness pattern, references T-1626/T-1633/T-1641).
- Captured L-334 (arc completion ≠ code-complete) and D-058 (framework-blindness pattern decision).
- Cross-linked `related_tasks: [T-1641]` on T-1062, T-1064, T-1065, T-1066, T-1636, T-1637, T-1639, T-1640.
- Rewrote Recommendation blocks on T-1062/4/5/6 to honestly flag what shipped vs what was promised.

**For human reviewer:** decide GO/NO-GO/DEFER on the **arc-or-arcs proposal** (split into three distinct arcs, vs continue as one). Recommendation: GO on the split. Then T-1642 (Arc A) needs its own GO when the policy questions are surfaced.

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

**Rationale**: Recommendation: GO — but NOT as a single-arc continuation of T-1061. Split into three distinct arcs (A=policy, B=wiring, C=defenses) with one decision-only inception.

Rationale: 10-worker investigation confirmed the user's pushback: the orchestrator arc is behaviorally real (W09 proved task-type routing + cache + failover on the wire), but operationally dormant and policy-unconsulted. Bundling the gaps into one mega-arc is exactly the T-1061 mistake replayed — three different failure modes wearing one outfit.

The three arcs and inception:
- T-1642 (Arc A — INCEPTION, horizon:now): Routing-policy consultation. 13 hardcoded constants surface as explicit human decisions. Blocks Arc B's framework-wiring completion.
- T-1643 (Arc B — BUILD, horizon:next): Framework-side wiring. Make /opt/999 actually USE the substrate (zero call-sites pass task_type or --model today). Co-arc with /opt/termlink hardening (gate the 71 ungated MCP mutators, wire run_with_governance, ship min-sample guard, surface fallback state). Blocked on T-1642.
- T-1644 (Arc C — BUILD, horizon:now): Drift defenses. 10 absent structural protections from W10 — MCP-tool task_id audit, fallback-chain regression test, governance-frame golden fixture, tag-format validator, route_cache schema test, Watchtower /orchestrator page. Runs parallel to Arc A.
- T-1645 (decision-only inception, horizon:next): G-015 reframing — narrow T-1061's claim or open non-TermLink workstream for sub-agent /tmp/ bypass.

Evidence: (full trace in `docs/reports/T-1641-orchestrator-arc-reconsideration.md`)
- W09 live wire test: orchestration does work — spawned 2 specialists with `task-type:` tags, routed 3 ways, killed one, observed cache rewrite + fallback. Core T-1061 promise is not vapourware.
- W03: 4 of 75 MCP tools enforce `check_task_governance`; 71 ungated (incl. mutators `inject`, `run`, `remote_exec`, `batch_exec`, `send`, `kv_`).
- W04: Framework has zero call-sites passing `task_type`; `--model` flag exists in `agents/termlink/termlink.sh:278` but no caller passes it; zero `GovernanceSubscriber` references anywhere in `agents/ bin/ lib/ web/`.
- W06: Production audit log records only `{ts, method, peer_addr}`; `orchestrator.route` fired 0× in 71,275 events — circuit breaker never opened, fallback chain never exercised.
- W08: 13 routing-policy constants silently defaulted (model fallback chain, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, DEFAULT_TTL_HOURS=168, CONFIDENCE_THRESHOLD=0.8, task_type taxonomy free-string, tag prefix, concurrency cap, success/failure attribution, selector role contract, default-on governance, discovery filter strictness).
- W05: Concerns register went unmodified across the entire arc; G-011/G-015/G-017 last_reviewed dates predate T-1061's inception.
- W07: Same "shipped before substrate-verified" signature as T-1626 + T-1633 — three independent G-019 escalations in five weeks. Captured as G-062 with proposed structural mechanisms.
- W10: Zero drift defenses exist (10 enumerated). Captured as G-061.

Housekeeping completed in this aggregation pass (not new tasks):
- Updated G-011 (record T-1063 partial mitigation) and G-017 (accepted-risk with rationale) in concerns.yaml.
- Added G-061 (orchestrator-arc rot) and G-062 (framework-blindness pattern, references T-1626/T-1633/T-1641).
- Captured L-334 (arc completion ≠ code-complete) and D-058 (framework-blindness pattern decision).
- Cross-linked `related_tasks: [T-1641]` on T-1062, T-1064, T-1065, T-1066, T-1636, T-1637, T-1639, T-1640.
- Rewrote Recommendation blocks on T-1062/4/5/6 to honestly flag what shipped vs what was promised.

For human reviewer: decide GO/NO-GO/DEFER on the arc-or-arcs proposal (split into three distinct arcs, vs continue as one). Recommendation: GO on the split. Then T-1642 (Arc A) needs its own GO when the policy questions are surfaced.

**Date**: 2026-05-01T12:29:11Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-01T12:29:11Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — but NOT as a single-arc continuation of T-1061. Split into three distinct arcs (A=policy, B=wiring, C=defenses) with one decision-only inception.

Rationale: 10-worker investigation confirmed the user's pushback: the orchestrator arc is behaviorally real (W09 proved task-type routing + cache + failover on the wire), but operationally dormant and policy-unconsulted. Bundling the gaps into one mega-arc is exactly the T-1061 mistake replayed — three different failure modes wearing one outfit.

The three arcs and inception:
- T-1642 (Arc A — INCEPTION, horizon:now): Routing-policy consultation. 13 hardcoded constants surface as explicit human decisions. Blocks Arc B's framework-wiring completion.
- T-1643 (Arc B — BUILD, horizon:next): Framework-side wiring. Make /opt/999 actually USE the substrate (zero call-sites pass task_type or --model today). Co-arc with /opt/termlink hardening (gate the 71 ungated MCP mutators, wire run_with_governance, ship min-sample guard, surface fallback state). Blocked on T-1642.
- T-1644 (Arc C — BUILD, horizon:now): Drift defenses. 10 absent structural protections from W10 — MCP-tool task_id audit, fallback-chain regression test, governance-frame golden fixture, tag-format validator, route_cache schema test, Watchtower /orchestrator page. Runs parallel to Arc A.
- T-1645 (decision-only inception, horizon:next): G-015 reframing — narrow T-1061's claim or open non-TermLink workstream for sub-agent /tmp/ bypass.

Evidence: (full trace in `docs/reports/T-1641-orchestrator-arc-reconsideration.md`)
- W09 live wire test: orchestration does work — spawned 2 specialists with `task-type:` tags, routed 3 ways, killed one, observed cache rewrite + fallback. Core T-1061 promise is not vapourware.
- W03: 4 of 75 MCP tools enforce `check_task_governance`; 71 ungated (incl. mutators `inject`, `run`, `remote_exec`, `batch_exec`, `send`, `kv_`).
- W04: Framework has zero call-sites passing `task_type`; `--model` flag exists in `agents/termlink/termlink.sh:278` but no caller passes it; zero `GovernanceSubscriber` references anywhere in `agents/ bin/ lib/ web/`.
- W06: Production audit log records only `{ts, method, peer_addr}`; `orchestrator.route` fired 0× in 71,275 events — circuit breaker never opened, fallback chain never exercised.
- W08: 13 routing-policy constants silently defaulted (model fallback chain, PROMOTION_THRESHOLD=5, FAILURE_THRESHOLD=3, COOLDOWN=60s, DEFAULT_TTL_HOURS=168, CONFIDENCE_THRESHOLD=0.8, task_type taxonomy free-string, tag prefix, concurrency cap, success/failure attribution, selector role contract, default-on governance, discovery filter strictness).
- W05: Concerns register went unmodified across the entire arc; G-011/G-015/G-017 last_reviewed dates predate T-1061's inception.
- W07: Same "shipped before substrate-verified" signature as T-1626 + T-1633 — three independent G-019 escalations in five weeks. Captured as G-062 with proposed structural mechanisms.
- W10: Zero drift defenses exist (10 enumerated). Captured as G-061.

Housekeeping completed in this aggregation pass (not new tasks):
- Updated G-011 (record T-1063 partial mitigation) and G-017 (accepted-risk with rationale) in concerns.yaml.
- Added G-061 (orchestrator-arc rot) and G-062 (framework-blindness pattern, references T-1626/T-1633/T-1641).
- Captured L-334 (arc completion ≠ code-complete) and D-058 (framework-blindness pattern decision).
- Cross-linked `related_tasks: [T-1641]` on T-1062, T-1064, T-1065, T-1066, T-1636, T-1637, T-1639, T-1640.
- Rewrote Recommendation blocks on T-1062/4/5/6 to honestly flag what shipped vs what was promised.

For human reviewer: decide GO/NO-GO/DEFER on the arc-or-arcs proposal (split into three distinct arcs, vs continue as one). Recommendation: GO on the split. Then T-1642 (Arc A) needs its own GO when the policy questions are surfaced.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6368a867
- **Timestamp:** 2026-06-02T14:58:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-01T12:29:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-05-01T18:58:36Z — status-update [task-update-agent]
- **Change:** tags: +arc:orchestrator-rethink
