---
id: T-1443
name: "Independent reviewer agent — TermLink-dispatched, evidence-gated, can auto-tick Agent ACs"
description: >
  Inception I-B (linked to T-1442 I-A). Design an independent reviewer agent dispatched via TermLink (own profile in agents/reviewer/) that reads recorded evidence (per I-A) and auto-ticks Agent ACs when evidence is sufficient, escalating to human only for genuine judgment ACs. Authority is mechanical-tick only; sovereignty preserved. Open: scope (generic vs per-tier), trigger (work-completed gate vs button), profile location/shape, output protocol (bus? task body? Watchtower?).

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [governance, reviewer-agent, termlink-dispatch, friction-reduction, slash-command, orchestrator-routing]
components: []
related_tasks: [T-1442, T-1064, T-1065]
created: 2026-04-25T06:35:13Z
last_update: 2026-04-25T07:29:59Z
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

(Active dialogue underway 2026-04-25. Several spikes resolved; remaining captured below.)

- **Spike A** (RESOLVED): Reviewer interface — structured envelope (input = task file + frontmatter + agent_acs + evidence + context + routing; output = overall_verdict + per_ac granular verdicts + drivers_evaluated + classification_drift_flag + reviewer_signature + digest). Per-AC granularity is foundational. Full sketch in dialogue log.
- **Spike B** (15m, OPEN, REFRAMED): Routing strategy — what rules govern which model class handles which review. Inputs: task risk, Layer 1 match, evidence size, AC count, fabric blast-radius. Outputs: model class (Haiku/Sonnet/Opus/external) + dispatch path. Tackled after Spike G.
- **Spike C** (10m, OPEN): Authority bounds — explicit cannot-list (cannot tick Human ACs structurally enforced; cannot decide inceptions; cannot mark `work-completed` itself; cannot bypass Layer 1; cannot create or revoke its own overrides — Spike I).
- **Spike D** (10m, RESOLVED): Failure-mode design — `insufficient-evidence` verdict structurally blocks `work-completed` (Model V hard prereq); `needs-human` puts AC on human queue but doesn't reject whole task; per-AC granularity means partial blocks are possible.
- **Spike E** (5m, OPEN): Reviewer auditability — sampling rate, shadow review, reviewer_signature + digest already in envelope. Concrete sampling policy still TBD.
- **Spike F** (RESOLVED with refactor): Anti-pattern catalogue — 12-category seed (tautology, empty-body, mock-only-integration, empty-output-success, skip-as-pass, safety-bypass, stale-evidence, AC-verify-mismatch, output-spoofing, swallowed-errors, zero-test-gaming, partial-truth-scope). REFACTORED severity model (T-1443 Turn 13): separate pattern attributes (`detection_confidence`, `lie_severity`) from task attributes (`risk`, `blast_radius` via T-1442) from action policy. Two policy files: `policy/anti-patterns.yaml` (catalogue) + `policy/action-matrix.yaml` (response mapping).
- **Spike G** (10m, OPEN, NEXT): Pattern-consultation interface — how reviewer mechanically loads + applies all policy files together (`policy/anti-patterns.yaml` + `policy/escalation-patterns.yaml` from T-1442 + `policy/action-matrix.yaml` + `policy/escalation-overrides.yaml` from Spike I) over evidence + commits + fabric components + frontmatter + AC content.
- **Spike H** (15m, OPEN): Slash-command + orchestrator routing — `/review T-XXX` as uniform entry point; behind it orchestrator (T-1064) routes to model class. Tackled after Spike G + B cluster.
- **Spike I** (RESOLVED): Override mechanism (NEW from T-1443 dialogue) — Watchtower review-screen UX with one-click defaults + opt-in structured-feedback checkboxes (don't-escalate-pattern / reclassify-AC-type / snooze) + free-text reason. Override file format `policy/escalation-overrides.yaml` with TTL + auto-revoke triggers. 7 UX principles locked (frictionless, opt-in, structured, consistent, aggregable, reversible, sovereignty-preserving). Append-only feedback stream `.context/working/feedback-stream.yaml`.

## Build follow-ups (anticipated, recorded for eventual Recommendation)

- **B-Reviewer-Core**: Reviewer agent profile (`agents/reviewer/`) + `/review` slash-command surface
- **B-Routing**: Orchestrator routing integration (T-1064 dep)
- **B-Anti-Patterns-Seed**: Initial 12-category catalogue (`policy/anti-patterns.yaml`)
- **B-Anti-Patterns-Expansion** (B-N): Multi-source catalogue expansion — external research (test-smell literature, mutation testing) + internal corpus mining (`.tasks/completed/` + `.context/audits/` + `concerns.yaml`) + peer-agent TermLink dispatch for cross-project anti-pattern capture
- **B-Action-Matrix**: `policy/action-matrix.yaml` + decision-tree implementation
- **B-Override-System**: `policy/escalation-overrides.yaml` schema + Watchtower UX + auto-revoke triggers + feedback stream writer
- **B-Auditability**: Reviewer-of-reviewer sampling + Watchtower override-management page
- **B-Authority-Enforcement**: Structural enforcement of cannot-list (e.g. `update-task.sh` rejects ticks on `### Human` ACs from agent-signed envelopes)

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

### 2026-04-25T07:29:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
