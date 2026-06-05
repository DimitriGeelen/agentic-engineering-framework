---
id: T-2209
name: "Capability-overlay arc — MCP subsystem + CLI route for agent-callable framework
  primitives"
description: >
  Inception: Capability-overlay arc — MCP subsystem + CLI route for agent-callable
  framework primitives

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-05T12:04:51Z
last_update: '2026-06-05T12:15:02Z'
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
# T-1984: machine-readable GO scope — each IW question's answer ships in a research-spike child task.
inception_decisions:
  - id: iw1-delivery-shape
    text: "MCP server vs CLI-overlay vs both-as-siblings vs federate-into-skills — which delivery shape does the arc produce?"
    ships_in: deferred:T-2210
  - id: iw2-verb-scope
    text: "Which fw verbs are in scope — curated 22, curated 40, or full 129; what's the classification rule?"
    ships_in: deferred:T-2211
  - id: iw3-auth-model
    text: "Auth model — env-inherit / per-client token / capability handshake / shell-only — which preserves §B-005 sovereignty?"
    ships_in: deferred:T-2212
  - id: iw4-headline-mechanic
    text: "Wire-level headline mechanic per G-062 §ACD — one named user-visible deliverable that proves the arc fires"
    ships_in: deferred:T-2213
  - id: iw5-overlap
    text: "Existing-MCP overlap — sibling framework MCP server vs federate into mcp__skills__*; what does the surface analysis say?"
    ships_in: deferred:T-2214
bvp_scores_proposed:
  - ts: '2026-06-05T12:05:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-05T12:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2209: Capability-overlay arc — MCP subsystem + CLI route for agent-callable framework primitives

## Problem Statement

**The directive (this turn):** *"focus on new MCP subsystem & CLI arc."* That is the operator's high-level signal — not a build instruction. No detailed handoff document exists on disk; a prior in-conversation reference to `HANDOFF-cli-mcp-overlay-2026-06-02 v3` was a memory phantom (verified absent across `.context/handoffs/`, pickup processed archive, and full-repo grep on 2026-06-05).

**The framework today already speaks MCP** — the running session has `claude-in-chrome`, `context7`, `skills`, and `termlink` MCP servers loaded. The framework's own surface (`bin/fw …`) is shell-only; agents reach it via Bash. **The arc question is whether the framework should expose its own primitives — `fw task review`, `fw inception start`, `fw arc create`, `fw bvp`, `fw reviewer`, `fw cron`, `fw handover`, etc. — through:**
1. **An MCP server** (so a Claude Code or other MCP client can invoke them as typed tools with structured argument schemas + JSON-shaped returns), and/or
2. **A "CLI route" overlay** (so the existing `bin/fw` verb tree gets a uniform machine-callable shape: structured JSON output, idempotent invocation, request IDs, capability discovery).

**For whom:** every agent that currently shells out to `bin/fw <verb>` and screen-scrapes ANSI-coloured output, every cross-machine TermLink worker that today serialises its requests as shell command strings, every Watchtower frontend that today builds POST payloads matching CLI argv shape. Today these consumers must keep the *shape* of the shell argv in mind; an MCP/CLI-overlay subsystem would let them call typed primitives with discoverable schemas.

**Why now:** operator-named ("focus on new MCP subsystem & CLI arc") — that is the trigger event for the inception itself. The arc-vs-task scoping is genuinely undetermined; the existing surface (`bin/fw` shell verbs) works, so this is value-add not bug-fix.

**Why this is an inception not a build (G-020 trigger fire):** new subsystem (MCP server process), new CLI surface (JSON-output overlay), >3 new files, secret handling possible (per-client auth tokens), potential cross-repo coordination with TermLink/skills servers, ambient-authority risk on a privileged surface that already gates Tier-0 actions. Each one of these alone meets G-020's "create an inception task (not build)" bar.

## Assumptions

- **A1:** The framework's existing `bin/fw` verb tree is the canonical authority surface, and any MCP/CLI overlay is a *projection* of those verbs — not a parallel implementation. Test: grep `bin/fw` for verb dispatch shape; confirm there's a single dispatch point that an MCP server could mechanically wrap.
- **A2:** Agents under `$CLAUDECODE=1` already adhere to the framework's sovereignty/§ACD/Tier-0 gates when they call `bin/fw`. An MCP overlay must inherit those gates unchanged — not weaken them, not duplicate them. Test: enumerate every gate that fires on shell invocation (`check-active-task`, `check-tier0`, `check-inception-decisions`, `check-inception-recommendation`, `check-arc-id`, `block-task-tools`, `boundary-hook`, `budget-gate`, `focus-drift`, `check-disposition-gate`) and verify each survives MCP wrapping.
- **A3:** A "CLI route" overlay is achievable without rewriting `bin/fw` — adding a structured-output mode (`--json` or `FW_OUTPUT=json`) on top of existing shell verbs gives the machine-callable shape, no new code paths. Test: count fw verbs that already accept `--json` (`fw orchestrator status --json`, `fw resolver dispatch --json`, etc.) vs those that don't; estimate retrofit cost.
- **A4:** TermLink and the local `skills` MCP server already proxy this kind of surface for *other* projects (TermLink session ops, skills declarative invocations). The framework would be the 4th-or-Nth MCP server on a Claude Code session, not the first. Test: examine the four currently-loaded MCP server descriptors (`claude-in-chrome`, `context7`, `skills`, `termlink`) for naming conventions, tool prefix shapes, and per-tool security stance.
- **A5:** The operator's mention of "arc" — not "task" — signals this is a multi-slice deliverable, not a single small piece. The headline mechanic per G-062 would be: *Claude Code (or other MCP client) calls `mcp__fw__task_review("T-2204")` and observes the same handoff URL the operator would see, with zero shell-string assembly.* Test: against the §ACD discipline — does this headline mechanic name a wire-level demo artefact, or is it substrate-phrased?

## Open Questions

- **IW-1: MCP server vs. CLI-route overlay vs. both? Which is the primary deliverable of the arc and which (if any) is a sibling?**
  confidence: 1
  disposition: deferred — needs operator input. Two genuinely distinct candidates with different blast radii.
  rationale: MCP server is a separate process with its own lifecycle/auth/transport (stdio JSON-RPC per Anthropic spec) — large surface. CLI-route overlay (`--json` on existing verbs) is small and additive. They are *related* (a thin MCP server can wrap `--json` CLI verbs almost trivially), but the operator may want one or the other or both; the answer changes the entire arc shape.

- **IW-2: Which fw primitives are in scope vs. out? All ~70 verbs, or a curated 10-20 (task lifecycle + inception + arc + review + handover)?**
  confidence: 1
  disposition: deferred — depends on IW-1's answer and on operator's mental model of "agent-callable primitives". A focused 10-20-verb scope respects §ACD discipline (small, verifiable headline mechanic); a 70-verb scope is the framework-wide rewrite that G-020 explicitly warns against.
  rationale: Verbs split into three classes — (a) state-changing under Sovereignty (e.g. `bvp confirm`, `inception decide`, `arc close`) which must keep their `$CLAUDECODE=1` agent-block, (b) state-changing with agent authority (`work-on`, `task update`, `cron generate`) which an MCP overlay can expose, (c) read-only (`bvp rank`, `inception status`, `review-queue`) which any overlay should expose by default. Need operator's primitive list, not the agent's guess.

- **IW-3: Authentication / authorisation — how does the MCP server know it's being called by an authorised agent vs. a misconfigured client? Does it inherit `$CLAUDECODE=1` from environment or require an explicit capability token?**
  confidence: 1
  disposition: deferred — Sovereignty boundary. The MCP transport (stdio JSON-RPC) does NOT carry an agent identity by default. If the framework's sovereignty model relies on `$CLAUDECODE=1` for gate-firing, the MCP server must either inherit that variable (risk: trivially spoofable) or implement its own capability model. The §B-005 enforcement-config protection class is directly precedent.
  rationale: Existing `claude-in-chrome` MCP server has no per-call auth (relies on the client process boundary). Existing `skills` MCP server similarly. TermLink uses TOFU-pinned tokens for *remote* calls but local stdio is trust-on-process. The framework's gates are *stricter* than those neighbours, so this question is real.

- **IW-4: Headline mechanic — what is the wire-level demo (per G-062 §ACD) the arc must produce? "Claude Code MCP-calls `fw_task_review` and the operator sees the same URL" is one shape; "Watchtower POSTs JSON to a local CLI overlay and recovers structured response" is another.**
  confidence: 1
  disposition: deferred — operator must name the headline mechanic. The §ACD class hazard is filing an arc whose headline mechanic is substrate-phrased ("MCP server exists and accepts calls") rather than deliverable-phrased ("an agent successfully completes a task via MCP-mediated `fw task update` and the operator observes the same `/review/T-XXX` page they would have seen on shell invocation").
  rationale: Per L-411 / G-062 — substrate-vs-deliverable conflation has burned three arcs (T-1626, T-1641, T-1670). Filing this arc without operator-named headline mechanic risks T-2143-class re-recursion.

- **IW-5: Existing-surface overlap — does the `skills` MCP server already host any of these primitives? Should the framework's MCP server be a sibling or should it federate into `skills`?**
  confidence: 1
  disposition: deferred — read-only spike needed (per Exploration Plan). Listed MCP tools on `skills` include `mcp__skills__tasks_*`, `mcp__skills__orchestrator_*`, `mcp__skills__knowledge_management_*` — names suggesting framework-task-system overlap. Federation would be cheaper if surface is already partial; greenfield is needed if the surface is conceptually different.
  rationale: G-020's "new subsystem" trigger is only honest if the surface IS new. If skills already exposes 80% of the primitives, the arc shape is "migrate the remaining 20% to skills" not "build a new MCP server".

## Exploration Plan

Time-boxed read-only spikes (no source edits — this is the inception's exploration, not its build):

- **Spike 1 (30 min): Surface inventory.** Enumerate every `bin/fw` verb. Classify each into (a) Sovereignty-bound, (b) agent-authority-bound, (c) read-only. Output: `docs/reports/T-2209-cli-mcp-overlay-inception.md §Surface Inventory`.
- **Spike 2 (20 min): Existing-MCP-surface inventory.** List tools exposed by `mcp__skills__*`, `mcp__termlink__*`, `mcp__context7__*` in the current session. Map any overlap with framework primitives. Answers IW-5. Output: `§Existing MCP Surface Overlap`.
- **Spike 3 (30 min): Authentication design candidates.** Read existing `.mcp.json` (if present), survey TermLink TOFU-token model, skills' transport. Three candidates: (a) env-only `$CLAUDECODE=1` inheritance, (b) per-client capability token in `.mcp.json` config, (c) capability-discovery handshake. Output: `§Auth Candidates`.
- **Spike 4 (20 min): Headline-mechanic candidates.** Draft 3-5 wire-level demos. For each: which fw verbs it requires, which gates it must traverse, which operator surface it terminates on. Output: `§Headline Mechanic Candidates` — surface to operator for selection.
- **Spike 5 (10 min): Arc-shape candidates.** Three sketches: MCP-server-only, CLI-overlay-only, both-as-siblings. Per-candidate: blast-radius estimate, slice count, dependency on TermLink/skills. Output: `§Arc Shape Candidates`.

Total spike budget: ~2 hours. **All output is read-only research artifact text; no source edits, no new fw verbs, no `.mcp.json` changes during exploration.** All edits gate-blocked under inception discipline anyway.

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

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

**Recommendation:** DEFER

**Rationale:**

Scope unbounded at filing: new subsystem + new CLI route + secret handling + potential cross-repo coordination per G-020 trigger; specific deliverables, integration points, and existing-surface overlap unknown. DEFER until Problem Statement and Open Questions surface a bounded candidate to recommend GO on.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

**Rationale**: Scope unbounded at filing: new subsystem + new CLI route + secret handling + potential cross-repo coordination per G-020 trigger; specific deliverables, integration points, and existing-surface overlap unknown. DEFER until Problem Statement and Open Questions surface a bounded candidate to recommend GO on.

**Date**: 2026-06-05T14:36:44Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-05T12:05:51Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-153d6d02
- **Timestamp:** 2026-06-05T12:11:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-06-05T14:36:44Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Scope unbounded at filing: new subsystem + new CLI route + secret handling + potential cross-repo coordination per G-020 trigger; specific deliverables, integration points, and existing-surface overlap unknown. DEFER until Problem Statement and Open Questions surface a bounded candidate to recommend GO on.
