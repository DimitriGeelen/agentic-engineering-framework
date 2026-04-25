---
id: T-1443
name: "Independent reviewer agent — TermLink-dispatched, evidence-gated, can auto-tick Agent ACs"
description: >
  Inception I-B (linked to T-1442 I-A). Design an independent reviewer agent dispatched via TermLink (own profile in agents/reviewer/) that reads recorded evidence (per I-A) and auto-ticks Agent ACs when evidence is sufficient, escalating to human only for genuine judgment ACs. Authority is mechanical-tick only; sovereignty preserved. Open: scope (generic vs per-tier), trigger (work-completed gate vs button), profile location/shape, output protocol (bus? task body? Watchtower?).

status: captured
workflow_type: inception
owner: agent
horizon: next
tags: [governance, reviewer-agent, termlink-dispatch, friction-reduction, slash-command, orchestrator-routing]
components: []
related_tasks: [T-1442, T-1064, T-1065]
created: 2026-04-25T06:35:13Z
last_update: 2026-04-25T06:35:13Z
date_finished: null
---

# T-1443: Independent reviewer agent — TermLink-dispatched, evidence-gated, can auto-tick Agent ACs

## Problem Statement

If T-1442 lands a default-flip toward mechanical AC verification with persisted evidence, *something* must judge whether the recorded evidence is sufficient to tick an Agent AC. Today the agent self-assesses (P-011 only checks exit codes). A second-opinion check would close the loop and make the system antifragile to a single agent's blind spots — without forcing the human to be that second opinion for every AC.

**Status:** captured, blocked on T-1442 GO. No active dialogue until I-A's policy is decided.

Full framing + dialogue genesis: `docs/reports/T-1442-ac-validation-default-flip.md`.

## Assumptions

1. An independent reviewer agent (TermLink-dispatched, own profile) catches misclassifications a single agent's self-assessment misses — UNTESTED
2. TermLink dispatch (vs Task tool sub-agent) materially preserves parent context — KNOWN TRUE (per CLAUDE.md §Task Tool vs TermLink Dispatch)
3. Reviewer can reliably distinguish "evidence sufficient" from "evidence insufficient" without human escalation in ≥80% of cases — UNTESTED (this is the value test)
4. Auto-ticking Agent ACs by an agent (not a human) is acceptable governance — CONFIRMED YES by user 2026-04-25, scope limited to Agent ACs only
5. (Inherited from T-1442) Reviewer must assess **evidence quality**, not just exit codes — VALIDATED (anti-pattern detection scope: tautology, empty output, mock-only, scope-narrowing, skip-as-pass)
6. (Inherited from T-1442) Reviewer must consult **Layer 1 escalation patterns** (`policy/escalation-patterns.yaml`) and **Layer 2 frontmatter** (`risk`, `human_signoff`) before mechanical-ticking — VALIDATED

## Exploration Plan

(NOT YET EXECUTED — waiting on T-1442 GO. Several spikes already shaped by T-1442 dialogue.)

- **Spike A** (15m, INPUT KNOWN per T-1442 Q1): Sketch reviewer interface — input = task `## Verification Output` summary + `docs/reports/T-XXX-evidence.md` full evidence + optional bus envelope. Output = verdict (mechanical-tick / needs-human / insufficient-evidence) + reasoning + anti-pattern flags. Output protocol still open.
- **Spike B** (15m, REFRAMED): Routing strategy (was: profile scope) — now scoped as "what routing rules govern which model class handles which review." Inputs: task `risk` field, Layer 1 pattern match, evidence size, AC count, fabric blast-radius. Outputs: model class (Haiku / Sonnet / Opus / external) + dispatch path (TermLink vs direct API). Cost/value comparison across profiles.
- **Spike C** (10m): Define authority bounds — explicit cannot-list (cannot tick Human ACs, cannot decide inceptions, cannot mark `work-completed` itself, cannot bypass Layer 1 pattern match).
- **Spike D** (10m): Failure-mode design — when reviewer says "evidence insufficient": block status change (hard prereq), warn, or surface to human queue? Default lean: block (per Model V principle).
- **Spike E** (5m): Reviewer auditability — sampling? periodic re-review of reviewer's tick decisions? Random-shadow human review of N% of ticks?
- **Spike F** (10m, NEW from T-1442 dialogue): Anti-pattern catalogue — enumerate the false-positive shapes the reviewer must specifically defend against (tautology assertions, empty outputs reported as success, mock-only coverage masquerading as integration, narrow happy-path-only tests, skipped tests counted as passes, --no-verify-style bypasses).
- **Spike G** (10m, NEW from T-1442 dialogue): Pattern-consultation interface — how does reviewer load `policy/escalation-patterns.yaml` and apply rules over commit list + fabric components + frontmatter + AC content?
- **Spike H** (15m, NEW from T-1442 dialogue): Slash-command interface + orchestrator routing integration. Design `/review T-XXX` (and `fw skill invoke review --task T-XXX` programmatic equivalent) as the single uniform entry point. Behind it: orchestrator (T-1064) routes to model class per task profile. Same routing primitive as T-1064/T-1065. Soft dependency: T-1064 must be operational, OR T-1443 ships with hard-coded model default and swaps when T-1064 lands.

## Technical Constraints

- Must dispatch via TermLink (`fw termlink dispatch`), NOT Task tool sub-agent — context isolation is a stated requirement
- Reviewer is an agent — sovereignty preserved means reviewer cannot tick Human ACs, ever, structurally enforced
- Reviewer's authority must be revocable — if reviewer makes systematic errors, framework must be able to disable auto-tick without redesign
- Reviewer output must be auditable — every tick traceable to reviewer + evidence reference

## Scope Fence

**IN:**
- Reviewer agent profile location, shape, and dispatch protocol
- Authority bounds (what reviewer can and cannot do)
- Output protocol (where reviewer's verdict lands)
- Failure modes (insufficient evidence, conflicting reviewers, reviewer crash)
- Reviewer-of-reviewer (auditability of the reviewer itself)

**OUT:**
- Evidence persistence shape (that's T-1442 Q1)
- Default-flip policy (that's T-1442)
- Building the agent (this inception decides whether/how — implementation is a follow-up build task)

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

## Research Artifact

See `docs/reports/T-1443-independent-reviewer-agent.md` — persisted thinking trail, will grow once T-1442 reaches GO.

Linked sister inception (prerequisite): **T-1442** (AC validation default-flip). Genesis dialogue lives in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log.

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
