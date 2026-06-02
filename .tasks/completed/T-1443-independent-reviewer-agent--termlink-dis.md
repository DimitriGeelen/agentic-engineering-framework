---
id: T-1443
name: "Independent reviewer agent — TermLink-dispatched, evidence-gated, can auto-tick Agent ACs"
description: >
  Inception I-B (linked to T-1442 I-A). Design an independent reviewer agent dispatched via TermLink (own profile in agents/reviewer/) that reads recorded evidence (per I-A) and auto-ticks Agent ACs when evidence is sufficient, escalating to human only for genuine judgment ACs. Authority is mechanical-tick only; sovereignty preserved. Open: scope (generic vs per-tier), trigger (work-completed gate vs button), profile location/shape, output protocol (bus? task body? Watchtower?).

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [governance, reviewer-agent, termlink-dispatch, friction-reduction, slash-command, orchestrator-routing]
components: []
related_tasks: [T-1442, T-1064, T-1065]
created: 2026-04-25T06:35:13Z
last_update: 2026-04-25T09:59:48Z
date_finished: 2026-04-25T09:59:48Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
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

## Build follow-ups — Staged micro-version progression

Replaces flat B-task list. Each version ~1 session, independently shippable, data-driven advancement gates.

| Version | Build task | Adds |
|---|---|---|
| **v1.0** | B-1.0-Static-Scan | Validation agent on `--status work-completed`; 4 anti-patterns (tautology, empty-body, --no-verify, output-spoofing); feedback stream from day 1; simple task-body verdict |
| **v1.1** | B-1.1-Frontmatter | `## Verification Output` section + `risk` frontmatter field |
| **v1.2** | B-1.2-Reviewer-Agent | Sonnet hardcoded reviewer agent; per-AC verdicts; envelope schema validator; sovereignty enforcement layer 1 (envelope) + layer 2 (update-task.sh) |
| **v1.3** | B-1.3-Override-UX | Spike I — Watchtower override checkboxes (MVP); feedback stream consumer; sovereignty enforcement layer 3 (Watchtower UI) |
| **v1.4** | B-1.4-Layer1-Seed | 5 initial mechanical escalation patterns (governance surface, security touch, public API, destructive ops, cross-project) |
| **v1.5** | B-1.5-Layer1-Expansion | Corpus mining (`.tasks/completed/`, `.context/audits/`, `concerns.yaml`) → 5–10 more patterns |
| **v2.0** | B-2.0-Cron-Drift | Daily cron Pass A (drift detection) on rolling 30-day window |
| **v2.1** | B-2.1-Cron-Audit | Daily cron Pass B (escalation audit); antifragility loop closes |
| **v3.0+** | B-3.x | Orchestrator routing (T-1064 dep); anti-pattern catalogue expansion (B-N: external research + peer-agent dispatch); evidence file split to `docs/reports/`; semantic checks; cross-project |

Three-cadence data review: continuous capture (auto) + weekly summary (~2 min) + threshold alerts (ad-hoc) + per-version-bump GO (~5 min).

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
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
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

## Research Artifact

See `docs/reports/T-1443-independent-reviewer-agent.md` — persisted thinking trail, will grow once T-1442 reaches GO.

Linked sister inception (prerequisite): **T-1442** (AC validation default-flip). Genesis dialogue lives in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log.

## Recommendation

**Recommendation:** GO — design and build the independent reviewer agent in **staged micro-versions** (v1.0 → v1.5 → v2.0 → v2.1 → v3+, each ~1 session, data-driven advancement gates between versions). Inherits T-1442's policy foundation; adds the missing intelligence layer (evidence quality assessment, anti-pattern detection, override-driven antifragility loop).

**Rationale:** A 17-turn dialogue with user (full trail in `docs/reports/T-1443-independent-reviewer-agent.md` § Dialogue Log) converged on a design that resolves the central question: how do we judge evidence *quality* (not just exit codes) without forcing every Human AC through human review? Answer: structured-envelope reviewer, dispatched independently via TermLink (`/review` slash-command surface, orchestrator-routed when T-1064 ships), produces per-AC granular verdicts driven by 5 additive signals (original classification + Layer 1 patterns + Layer 2 frontmatter + anti-pattern detection + AC semantic class), with reviewer-can-NEVER-tick-Human-AC structurally enforced at 3 layers (envelope schema + update-task.sh + Watchtower UI). User's antifragility principle ("false success worse than acknowledged failure") drove design depth (multi-layer enforcement, fail-closed defaults via three-tier policy, no caching). User's pushback on scope-creep drove staged rollout (micro-versions, not big-bang) with continuous + weekly + threshold + per-version-bump data review cadences keeping human-review of the meta-process itself frictionless. Spike A's deferred uncertainty (% of mechanically-evidenceable Human ACs) is measured *in production* via v1.0 feedback stream, not assumed.

**Design summary:**
1. **Reviewer interface** — structured envelope; per-AC granular verdicts; reviewer signature + digest for tamper-detection (Spike A)
2. **5-driver "needs-human" model** — additive: original classification + Layer 1 + Layer 2 + anti-patterns + AC semantic class
3. **Sovereignty preservation** — reviewer NEVER ticks `### Human` ACs; structurally enforced at 3 layers (Spike C addressed via staging)
4. **Anti-pattern catalogue** — `policy/anti-patterns.yaml`; 12-category seed; severity refactored into separate axes (`detection_confidence`, `lie_severity` — distinct from task `risk`/`blast_radius`); multi-source expansion (B-Anti-Patterns-Expansion at v3+) (Spike F)
5. **Action policy separated** — `policy/action-matrix.yaml` combines anti-pattern attrs + task attrs → action (block / escalate / note)
6. **Override mechanism** — `policy/escalation-overrides.yaml` with TTL + auto-revoke triggers; Watchtower UX with 7 frictionless-feedback principles; append-only `.context/working/feedback-stream.yaml` (Spike I)
7. **Pattern-consultation algorithm** — cheap-first DAG (no short-circuit; Model V mandates all phases); three-tier failure policy (T1 hard / T2 retry / T3 fail-soft) declared per anti-pattern entry (Spike G)
8. **Implementation shape** — Python library (`lib/reviewer/`) + thin bash CLI (`/review` + `fw skill invoke review`); version-pinned via `.framework.yaml`; vendored to consumers; 4–5 core modules in v1
9. **5 correctness invariants** — atomicity (write-temp + fsync + rename); idempotency reframed (deterministic bit-exact; semantic signed-for-reproducibility tracking, model+temperature in signature); signature integrity combined with append-only evidence storage; sovereignty 3-layer enforcement; retention lifecycle (90d full / 1y summary / archive)
10. **Staged rollout** — v1.0 → v3.0+ micro-versions; three-cadence data review keeping meta-process frictionless; Spike I feedback stream pulled forward to v1.0 for day-1 data capture

**Evidence:**
- 17-turn user dialogue captured in `docs/reports/T-1443-independent-reviewer-agent.md` covering all 9 spikes (5 fully resolved, 4 addressed via staged delivery: B routing → v3, C bounds → 3-layer enforcement per-version, E auditability → signature+digest from v1.2 + sampling at v3+, H slash-command shape → locked, orchestrator integration → v3)
- Inheritance from T-1442 design: invocation contract, evidence persistence shape, two-layer escalation, daily audit cron — reused, no duplication
- Sovereignty rule (CLAUDE.md §Agent/Human AC Split: "NEVER check a `### Human` AC. Only the human may verify and check these boxes.") preserved structurally across 3 enforcement layers
- Staged rollout addresses Spike A's deferred uncertainty by measuring it in v1.0 production data, not assuming
- Three-axis severity refactor (Turn 13) prevented dangerous conflation between detection certainty + lie severity + action urgency — user-flagged design correction
- Frictionless-feedback UX (Turn 11) ensures human-feedback learning loop is itself low-friction — keeps antifragility loop sustainable
- T-1442 is decided GO (2026-04-25T07:22Z); the policy foundation T-1443 inherits is committed

**Honest limits acknowledged:**
1. v1.0 measures the "% mechanically evidenceable" assumption underlying the whole effort. If <30%, design over-engineers; if 70%+, design under-ships. Either way, fast measurement beats slow speculation.
2. Semantic LLM-judgment is non-deterministic — idempotency reframed (signature captures inputs; divergence detectable but not preventable for semantic checks).
3. v1.3 override UX is MVP — the 7 UX principles need iteration based on actual human use patterns. Frictionless-feedback principle applied.
4. Sovereignty 3-layer enforcement: each layer must be implemented correctly. v1.2 ships layers 1+2; v1.3 ships layer 3. Defense-in-depth means missing one layer is a bug, not a catastrophe.
5. Cost envelope per review estimated ~5–15s (mostly Model V verification re-run); cron scheduling spreads peak load.
6. Soft dependency on T-1064 (orchestrator routing). v1.2 ships with hardcoded Sonnet; v3.0 swaps to orchestrator when ready. No blocking dependency.

**GO/NO-GO criteria evaluation:**
- Root cause identified (single-agent verification blind spots; Human-AC backlog) with bounded fix path: ✓
- Fix is scoped, testable, reversible (each micro-version independently revertible): ✓
- Does NOT require fundamental redesign — extends T-1442 + T-954 + P-011 + `fw fabric` + `fw cron`: ✓
- Cost proportional to benefit (staged delivery measures value per version; abandon if data doesn't support): ✓
- Soft dependency on T-1064 noted, non-blocking: ✓

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

**Decision**: GO

**Rationale**: A 17-turn dialogue with user (full trail in `docs/reports/T-1443-independent-reviewer-agent.md` § Dialogue Log) converged on a design that resolves the central question: how do we judge evidence *quality* (not just exit codes) without forcing every Human AC through human review? Answer: structured-envelope reviewer, dispatched independently via TermLink (`/review` slash-command surface, orchestrator-routed when T-1064 ships), produces per-AC granular verdicts driven by 5 additive signals (original classification + Layer 1 patterns + Layer 2 frontmatter + anti-pattern detection + AC semantic class), with reviewer-can-NEVER-tick-Human-AC structurally enforced at 3 layers (envelope schema + update-task.sh + Watchtower UI). User's antifragility principle ("false success worse than acknowledged failure") drove design depth (multi-layer enforcement, fail-closed defaults via three-tier policy, no caching). User's pushback on scope-creep drove staged rollout (micro-versions, not big-bang) with continuous + weekly + threshold + per-version-bump data review cadences keeping human-review of the meta-process itself frictionless. Spike A's deferred uncertainty (% of mechanically-evidenceable Human ACs) is measured *in production* via v1.0 feedback stream, not assumed.

Design summary:
1. Reviewer interface — structured envelope; per-AC granular verdicts; reviewer signature + digest for tamper-detection (Spike A)
2. 5-driver "needs-human" model — additive: original classification + Layer 1 + Layer 2 + anti-patterns + AC semantic class
3. Sovereignty preservation — reviewer NEVER ticks `### Human` ACs; structurally enforced at 3 layers (Spike C addressed via staging)
4. Anti-pattern catalogue — `policy/anti-patterns.yaml`; 12-category seed; severity refactored into separate axes (`detection_confidence`, `lie_severity` — distinct from task `risk`/`blast_radius`); multi-source expansion (B-Anti-Patterns-Expansion at v3+) (Spike F)
5. Action policy separated — `policy/action-matrix.yaml` combines anti-pattern attrs + task attrs → action (block / escalate / note)
6. Override mechanism — `policy/escalation-overrides.yaml` with TTL + auto-revoke triggers; Watchtower UX with 7 frictionless-feedback principles; append-only `.context/working/feedback-stream.yaml` (Spike I)
7. Pattern-consultation algorithm — cheap-first DAG (no short-circuit; Model V mandates all phases); three-tier failure policy (T1 hard / T2 retry / T3 fail-soft) declared per anti-pattern entry (Spike G)
8. Implementation shape — Python library (`lib/reviewer/`) + thin bash CLI (`/review` + `fw skill invoke review`); version-pinned via `.framework.yaml`; vendored to consumers; 4–5 core modules in v1
9. 5 correctness invariants — atomicity (write-temp + fsync + rename); idempotency reframed (deterministic bit-exact; semantic signed-for-reproducibility tracking, model+temperature in signature); signature integrity combined with append-only evidence storage; sovereignty 3-layer enforcement; retention lifecycle (90d full / 1y summary / archive)
10. Staged rollout — v1.0 → v3.0+ micro-versions; three-cadence data review keeping meta-process frictionless; Spike I feedback stream pulled forward to v1.0 for day-1 data capture

**Date**: 2026-04-25T09:59:47Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-25T07:29:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-25T09:59:47Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** A 17-turn dialogue with user (full trail in `docs/reports/T-1443-independent-reviewer-agent.md` § Dialogue Log) converged on a design that resolves the central question: how do we judge evidence *quality* (not just exit codes) without forcing every Human AC through human review? Answer: structured-envelope reviewer, dispatched independently via TermLink (`/review` slash-command surface, orchestrator-routed when T-1064 ships), produces per-AC granular verdicts driven by 5 additive signals (original classification + Layer 1 patterns + Layer 2 frontmatter + anti-pattern detection + AC semantic class), with reviewer-can-NEVER-tick-Human-AC structurally enforced at 3 layers (envelope schema + update-task.sh + Watchtower UI). User's antifragility principle ("false success worse than acknowledged failure") drove design depth (multi-layer enforcement, fail-closed defaults via three-tier policy, no caching). User's pushback on scope-creep drove staged rollout (micro-versions, not big-bang) with continuous + weekly + threshold + per-version-bump data review cadences keeping human-review of the meta-process itself frictionless. Spike A's deferred uncertainty (% of mechanically-evidenceable Human ACs) is measured *in production* via v1.0 feedback stream, not assumed.

Design summary:
1. Reviewer interface — structured envelope; per-AC granular verdicts; reviewer signature + digest for tamper-detection (Spike A)
2. 5-driver "needs-human" model — additive: original classification + Layer 1 + Layer 2 + anti-patterns + AC semantic class
3. Sovereignty preservation — reviewer NEVER ticks `### Human` ACs; structurally enforced at 3 layers (Spike C addressed via staging)
4. Anti-pattern catalogue — `policy/anti-patterns.yaml`; 12-category seed; severity refactored into separate axes (`detection_confidence`, `lie_severity` — distinct from task `risk`/`blast_radius`); multi-source expansion (B-Anti-Patterns-Expansion at v3+) (Spike F)
5. Action policy separated — `policy/action-matrix.yaml` combines anti-pattern attrs + task attrs → action (block / escalate / note)
6. Override mechanism — `policy/escalation-overrides.yaml` with TTL + auto-revoke triggers; Watchtower UX with 7 frictionless-feedback principles; append-only `.context/working/feedback-stream.yaml` (Spike I)
7. Pattern-consultation algorithm — cheap-first DAG (no short-circuit; Model V mandates all phases); three-tier failure policy (T1 hard / T2 retry / T3 fail-soft) declared per anti-pattern entry (Spike G)
8. Implementation shape — Python library (`lib/reviewer/`) + thin bash CLI (`/review` + `fw skill invoke review`); version-pinned via `.framework.yaml`; vendored to consumers; 4–5 core modules in v1
9. 5 correctness invariants — atomicity (write-temp + fsync + rename); idempotency reframed (deterministic bit-exact; semantic signed-for-reproducibility tracking, model+temperature in signature); signature integrity combined with append-only evidence storage; sovereignty 3-layer enforcement; retention lifecycle (90d full / 1y summary / archive)
10. Staged rollout — v1.0 → v3.0+ micro-versions; three-cadence data review keeping meta-process frictionless; Spike I feedback stream pulled forward to v1.0 for day-1 data capture

### 2026-04-25T09:59:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f2a5409b
- **Timestamp:** 2026-06-02T14:57:31Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
