---
id: T-1092
name: "Dispatch payload profiles — research path before architectural commitment"
description: >
  Research inception (Option 3 from prior reflection). Explore whether the orchestrator should tailor dispatch payloads (CLAUDE.md slice, MCP subset, starting context) per worker type to balance context cost against output quality. Deliverable: a research artifact enumerating profile use cases from episodic memory, sketching Path A (build-first, extract later) and Path B (schema-first, separate repo day 1) architectures side-by-side, and recommending a path with evidence. Scope fence: NO profiles built, NO CLAUDE.md sliced, NO schema locked, NO new repo created under this task. Decision at end is a path recommendation, not a build authorization — build tasks come from descendants.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-11T11:32:45Z
last_update: 2026-04-11T11:32:45Z
date_finished: null
---

# T-1092: Dispatch payload profiles — research path before architectural commitment

## Problem Statement

TermLink parallel dispatch of `claude -p` workers currently ships every worker the full orchestrator governance payload: ~45K-token CLAUDE.md, every MCP server, every hook. For a one-shot specialist (risk eval, enrichment, audit, single-question research) 80-90% of that is governance that only applies to the orchestrator session — task creation rules, inception discipline, commit cadence, handover protocol, memory rules. A T-909 3-parallel risk-eval dispatch was estimated at 100-300K tokens; most of that is onboarding tax, not the actual work. The cost scales linearly with parallelism, so the tax becomes dominant as dispatch counts rise.

**For whom:** The orchestrator session (the primary consumer of parallel dispatch), and indirectly the framework operator who pays the token bill. Secondarily: profile authors, framework integrators, and prompt researchers who'd benefit from a portable profile artifact.

**Why now:** T-909 made the cost concrete and user-visible. Prior sessions had smaller dispatches where the tax was tolerable; the 3-parallel pattern pushes it into uncomfortable territory. The ask landed on this framework after five related classes of cost-control work (T-818 dispatch persistence, T-1088 budget-gate timestamp filter, the T-1087 regression cycle) — cost is now the dominant frame, not correctness.

**What this task IS NOT:** A commitment to build profiles. A design of the profile schema. An approval to strip CLAUDE.md. A decision that the separate-repo architecture is right. It's research that informs those later decisions.

## Assumptions

A-1: Most of CLAUDE.md is orchestrator-specific and not needed by one-shot workers. (Testable by auditing CLAUDE.md sections against a small sample of actual dispatched worker transcripts and classifying each section as "worker-relevant" / "orchestrator-only" / "both".)

A-2: The semantic/declarative split the user articulated (purpose-level intent vs tool/file mechanics) is a stable axis that will survive contact with 3+ real profiles. (Testable by sketching two profiles and asking whether the split holds for both.)

A-3: The schema is NOT knowable up-front without concrete examples — schema-first designs in this framework have historically been rewritten after the second real use (result bus, component fabric, learnings, concerns, inception taxonomy). (Testable by searching episodic memory for evidence of this pattern.)

A-4: Tailoring CAN meaningfully cut per-worker token cost (target: >50% reduction on a risk-eval-style one-shot). (Not testable under this inception — that's a build-phase measurement. This is registered but deferred.)

A-5: There exist 3+ distinct worker archetypes in this framework's real dispatch history that would each benefit from a different profile. (Testable by mining episodic memory for past dispatch patterns.)

A-6: The portability constraint (separate repo, cross-framework consumption) is load-bearing — i.e., the profiles would actually be consumed by a framework other than this one within some reasonable horizon. (Not testable from inside this framework — the honest answer is probably "not yet, but designing for it is cheap if we do it from day 1.")

## Exploration Plan

Phase 1 — Evidence gathering (time-box: 1 session)
- Mine episodic memory + handovers + task history for every parallel-dispatch event (Task tool agents and TermLink dispatch)
- Catalog: worker role, token cost if recorded, output shape, success/failure
- Identify dispatch archetypes empirically (not theoretically)
- Look for the T-073 session (9 agents → context explosion) and other expensive dispatches as anchoring examples

Phase 2 — CLAUDE.md audit (time-box: 1 session)
- Walk every H2 section of CLAUDE.md
- Classify each as: worker-relevant (ship to workers), orchestrator-only (never ship), constitutional-floor (must ship), conditional (ship if task type matches)
- Estimate token weight of each bucket
- Produce a concrete "what a minimal worker payload would look like" sketch (not a build artifact — a sketch for the artifact)

Phase 3 — Schema side-by-side (time-box: 1 session)
- Sketch Path A (build-first, extract later) profile structure using risk-eval as the concrete example
- Sketch Path B (schema-first, portable repo day 1) profile structure for the same risk-eval use case
- Articulate what each sketch locks in, what each defers, and where they diverge
- Explicitly NOT choosing yet — just making both visible

Phase 4 — Governance floor (time-box: 1 session)
- Enumerate what MUST stay in every worker payload regardless of profile
- For each floor item, state: what breaks if stripped, which real incident would validate this
- Flag items where I'm uncertain — those are the load-bearing unknowns

Phase 5 — Recommendation (time-box: same session as Phase 4)
- Synthesize evidence from phases 1-4 into a path recommendation
- State the recommendation, cite the evidence, identify what would change the recommendation if we learned something new

All phases write to `docs/reports/T-1092-dispatch-profile-research.md` incrementally (C-001: research artifact IS the deliverable, not a byproduct). Dialogue log in the same artifact per C-001 extension.

## Technical Constraints

- Agent runs `claude -p` under Claude Code CLI; CLAUDE.md is loaded via `--append-system-prompt` or similar. Not all loader mechanisms are inspectable from inside this framework.
- MCP server set is declared in `.mcp.json` at session root; per-dispatch override mechanism exists via `TERMLINK_TASK_GOVERNANCE=1` but full per-worker MCP subsetting is untested.
- `agents/dispatch/preamble.md` is the existing preamble hook point; profile materialization likely happens here.
- Any profile repo would need to be consumable by at least: git submodule, git clone, or plain `curl`. Assume no package manager.
- Portability implies no framework-specific binary dependencies in the profile layer itself — bindings can require them, intent cannot.

## Scope Fence

**IN scope (this task):**
- Evidence gathering from episodic memory and handovers
- CLAUDE.md section classification
- Side-by-side schema sketches (not production schemas)
- Governance floor enumeration
- A written recommendation with evidence

**OUT of scope (explicitly — attempts will create separate build tasks):**
- Building any profile
- Creating a separate repo
- Slicing CLAUDE.md into real files
- Modifying `fw termlink dispatch` or `agents/dispatch/preamble.md`
- Measuring actual token savings (requires build, deferred to A-4 validation)
- Locking a schema format
- Framework-side loader/consumer code

## Acceptance Criteria

### Agent
- [ ] Research artifact `docs/reports/T-1092-dispatch-profile-research.md` exists with Phase 1-5 findings
- [ ] At least 3 distinct dispatch archetypes identified from episodic evidence (A-5 validated or falsified)
- [ ] CLAUDE.md section-by-section classification recorded (A-1 validated or falsified)
- [ ] Path A and Path B schema sketches present side-by-side in the artifact
- [ ] Governance floor list with "breaks if stripped" justification per item
- [ ] Recommendation section filled with cited evidence
- [ ] Dialogue log section updated with any clarifying Q&A during exploration

### Human
- [ ] [REVIEW] Review recommendation and record go/no-go
  **Steps:**
  1. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw task review T-1092`
  2. Read `docs/reports/T-1092-dispatch-profile-research.md` — focus on Phase 5 recommendation + governance floor
  3. Record decision via Watchtower, or via the command printed alongside the QR code
  **Expected:** Decision recorded. GO creates build task(s) for the chosen path. NO-GO archives the research.
  **If not:** Ask agent to clarify specific findings or extend a phase

## Go/No-Go Criteria

**GO (research complete, path recommended, build tasks should follow) if:**
- Evidence supports that tailoring would produce meaningful savings on real workloads (not hypothetical ones)
- At least one path (A or B) has a concrete, actionable next step — a build task that could start tomorrow
- The governance floor is enumerated and defensible
- The recommendation cites specific evidence, not just reasoning

**NO-GO (don't build this at all) if:**
- Evidence shows parallel dispatch is rare enough that the token tax isn't worth engineering
- The governance floor turns out to BE most of CLAUDE.md (i.e., workers need almost everything, so there's nothing meaningful to strip)
- A simpler mechanism (e.g., raising the per-worker context budget, switching to a cheaper model for workers) dominates the profile approach

**DEFER (right idea, wrong time) if:**
- Evidence gathering reveals that profile design is blocked on a prerequisite not yet built (e.g., orchestrator routing from T-1064 is upstream and must land first)
- The separate-repo portability constraint turns out to be a 2026-H2 question, not a now question

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
