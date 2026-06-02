---
id: T-1442
name: "AC validation default-flip — mechanical verification with persisted evidence"
description: >
  AC validation default-flip — mechanical verification with persisted evidence

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [governance, ac-validation, friction-reduction, orchestrator-routing]
components: []
related_tasks: [T-1443, T-954, T-1064]
created: 2026-04-25T06:34:35Z
last_update: 2026-04-25T07:22:38Z
date_finished: 2026-04-25T07:22:38Z
---

# T-1442: AC validation default-flip — mechanical verification with persisted evidence

## Problem Statement

Human ACs are accumulating as approval-queue noise across multiple consumer projects. Many describe checks that don't require human judgment — they're mechanically evidenceable but currently default to Human review. Friction without proportional risk-management value.

**Goal:** frictionless development. **Constraint:** preserve antifragility + reliability + auditability. **Solution shape:** flip the default toward mechanical verification with persisted evidence; reserve Human AC for genuine judgment.

Full framing + dialogue genesis: `docs/reports/T-1442-ac-validation-default-flip.md`.

## Assumptions

1. Most current Human ACs are mechanically evidenceable in retrospect — TESTING DEFERRED (Spike A folded into B1 pilot). Decision proceeds independently — even at 50% mechanically evidenceable, friction reduction is significant.
2. Persisting evidence (not just exit codes) materially improves auditability — VALIDATED via dialogue (reviewer agent in T-1443 needs richer evidence than exit codes to assess quality).
3. Default-flip can extend T-954 / P-011 / `fw verify-acs` rather than replace them — VALIDATED (Spike B inventory done; all existing infra reusable).
4. The three existing tiers (programmatic / TermLink E2E / Playwright) cover ≥90% of current Human-AC use cases — TESTING DEFERRED (Spike A in B1 pilot).
5. (Emergent) "False success is worse than acknowledged failure" justifies pure-V (no cache, no first-time exception) — VALIDATED by user principle 2026-04-25.
6. (Emergent) Two-layer escalation with audit safety-net achieves antifragile coverage of high-risk patterns — VALIDATED via dialogue + cron design.

## Exploration Plan

- **Spike A** (deferred to B1 pilot): Sample audit of 20 recent Human ACs — not blocking GO. Tests Assumption 1 + 4 in production data.
- **Spike B** (RESOLVED via dialogue): Existing-controls inventory — T-954, P-011, `fw verify-acs`, `fw fabric`, `fw cron`, `docs/reports/` all reusable. Design extends, doesn't replace. Resolves Assumption 3.
- **Spike C** (RESOLVED via dialogue): Evidence persistence shape (Q1) — task body `## Verification Output` summary section + full evidence in `docs/reports/T-XXX-evidence.md` + optional `fw bus post` envelope for cross-agent review.
- **Dialogue D** (RESOLVED): Trigger model (Q3) — Model V pure, always-invoke validation agent on `--status work-completed`, hard prereq gate. No cache. No first-time exception.
- **Dialogue E** (emergent, RESOLVED): Human-escalation codification — two-layer (mechanical patterns in `policy/escalation-patterns.yaml` + declared frontmatter `risk` / `human_signoff` fields) + Layer 3 daily audit cron. Honest false-negative limit accepted; antifragile loop tunes Layer 1.

## Technical Constraints

- Cannot add a hard pre-req gate without a fallback path (sovereignty: human can always override)
- Evidence persistence must survive context compaction (so Task tool sub-agent stdout is insufficient — must land on disk)
- Migration must be incremental — bulk re-classifying every existing Human AC across the backlog is out of scope (G-019: don't fix the past, prevent recurrence)

## Scope Fence

**IN:**
- Default classification policy (T-954 extension)
- Evidence persistence shape and protocol (Q1)
- Trigger model — when does mechanical verification fire (Q3)
- Relationship to existing controls (Q5a) — extend or replace
- Hand-off contract to T-1443 (reviewer agent's input shape)

**OUT:**
- Reviewer agent design (that's T-1443)
- Re-classifying existing Human ACs in bulk (incremental on next-touch only)
- Replacing P-011 verification gate (we extend, not replace)

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

See `docs/reports/T-1442-ac-validation-default-flip.md` — persisted thinking trail with framing, open questions, dialogue log. Updated incrementally as dialogue progresses (per C-001).

Linked sister inception: **T-1443** (reviewer agent design — captured, horizon=next, blocked on this inception's GO).

## Recommendation

**Recommendation:** GO — codify Model V (defense-in-depth verification) with two-layer human-escalation model and daily audit cron, extending (not replacing) existing controls T-954 / P-011 / `fw verify-acs` / `fw fabric` / `fw cron`.

**Rationale:** A 6-turn dialogue with user (full trail in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log) converged on a design that resolves the friction-vs-rigor tradeoff by reframing it: human-time friction is expensive and scarce, computational friction is cheap and tireless. The user's principle — *"work is only valuable when quality working product is delivered. False 'successfully tested' undermines this and can have severe downstream effects when subsequent development builds on it"* — rules out caching, lazy hybrids, and first-time exceptions. Every verification is fresh, every time. Antifragility is built in: Pass B of the daily cron tunes the escalation-pattern catalogue from its own near-misses. Design extends existing infrastructure — no greenfield subsystems. Scope-fence honored: re-classifying existing Human ACs in bulk is OUT (incremental on next-touch only).

**Design summary:**
1. **Model V (always-fresh)** — validation agent invoked on every `fw task update --status work-completed` request via `/review T-XXX` slash command (or programmatic equivalent `fw skill invoke review --task T-XXX`). Behind `/review`, the **orchestrator routes to an appropriate model class** (T-1064 dependency: Haiku for routine, Sonnet for standard, Opus for high-risk/governance, external for specialised). Hard prerequisite gate: status change rejected if validation fails. No cache.
2. **Evidence persistence (Q1)** — task body gets new `## Verification Output` section (reviewer verdict + summary + anti-pattern flags, ~10 lines); full stdout/stderr/exit-codes/env-fingerprint to `docs/reports/T-XXX-evidence.md`; `fw bus post` envelope optional for cross-agent review.
3. **Two-layer human escalation** — Layer 1 mechanical pattern triggers (`policy/escalation-patterns.yaml`: governance surfaces, security components, public APIs, destructive ops, fabric-flagged sensitive components, evidence anti-patterns); Layer 2 declared escalation (new frontmatter `risk: high|medium|low` + `human_signoff: required|optional`). Reviewer (T-1443) consults both before mechanical-ticking.
4. **Layer 3 audit safety-net (daily cron)** — Pass A: drift detection re-runs verification commands fresh against current HEAD on rolling 30-day window + always-on core fabric components, surfaces failures as `issues`. Pass B: escalation audit cross-references commits-since-completion + frontmatter against Layer 1 patterns, flags missed escalations. Output → Watchtower `/cron/validation-audit` antifragility dashboard.
5. **Reviewer responsibilities (T-1443 inherits)** — assesses evidence *quality*, not exit code: detects tautology, empty output, mock-only coverage, scope-narrowing, skip-as-pass; consults Layer 1 patterns; escalates to human on match or insufficient-evidence.
6. **Slash-command surface + orchestrator routing** — `/review` is the uniform entry point; orchestrator picks the model class per task profile (risk + Layer 1 pattern match + evidence size + fabric blast-radius). Same routing primitive as T-1064/T-1065. Daily cron Pass A and Pass B also route through `/review` with profile hints (cheap models for bulk re-validation, escalating only on detected drift).

**Evidence:**
- 6-turn user dialogue resolved Q1 (evidence persistence), Q2 (reviewer authority — confirmed mechanical-tick on Agent ACs only), Q3 (trigger = Model V pure, always-invoke), Q5a (extend not replace), plus emergent codification question. Full trail: `docs/reports/T-1442-ac-validation-default-flip.md`.
- Existing-infrastructure inventory (Spike B): T-954 (AC classification), P-011 (verification gate), `fw verify-acs`, `fw fabric` (blast-radius for drift), `fw cron` (scheduling), `docs/reports/` (artifact convention) — all reusable.
- Cost envelope estimated ~13 min/day for daily cron (rolling 30-day + core fabric ≈ 70 tasks × ~11s avg).
- Two-layer escalation accepts honest false-negative limit; mitigated by Layer 3 (every miss → new Layer 1 pattern → antifragile).
- T-1443 inherits design constraints (input contract = persisted evidence shape; reviewer scope expanded to anti-pattern detection); blocked on this inception's GO.
- User principle "false success is worse than acknowledged failure" is the antifragility directive applied to verification itself; ruled out three weaker alternatives (cached lazy hybrid, first-time-trust, source-touch invalidation alone).

**Decomposition (follow-up build tasks after GO):**
- B1: Validation-agent dispatch protocol — always-invoke on `--status work-completed`; integrates with P-011; pilot includes Spike A sample audit.
- B2: Evidence persistence schema — task body section writer + `docs/reports/T-XXX-evidence.md` template + bus envelope.
- B3: Layer 1 escalation-pattern catalogue (`policy/escalation-patterns.yaml`) — initial seed from CLAUDE.md Tier 0 list + governance surfaces + fabric tags.
- B4: Layer 2 frontmatter fields — task template + `update-task.sh` + audit awareness.
- B5: Daily cron Pass A (drift detection) — re-validate rolling-window completed tasks; record drift events.
- B6: Daily cron Pass B (escalation audit) — retrospective pattern check; surface missed escalations.
- B7: Watchtower `/cron/validation-audit` dashboard — drift events + missed escalations + pattern-tuning suggestions.
- B8: CLAUDE.md update — extend §AC Classification Guidance + §Verification Gate sections; document new fields and policy file.

T-1443 (parallel inception) designs the validation/reviewer agent itself.

**Honest limits acknowledged:**
1. False-negative escalations WILL happen until Layer 1 catalogue matures; Layer 3 catches them.
2. Sample-audit Spike A (Assumptions 1, 4) deferred to B1 pilot — not blocking GO; even partial coverage delivers significant friction reduction.
3. Cost envelope (~13 min/day) assumes well-scoped verification commands; runaway commands mitigated by per-task timeout in cron config.
4. Pure-V on every `work-completed` adds compute cost vs current P-011 baseline — accepted trade per user principle.

**GO/NO-GO criteria evaluation:**
- Root cause identified (Human-AC noise) with bounded fix path (8 follow-up build tasks): ✓
- Fix is scoped, testable, reversible (frontmatter fields removable, cron disablable, validation agent fall-back to current P-011 if disabled): ✓
- Does NOT require fundamental redesign — extends existing infra: ✓
- Cost (compute ~13 min/day + 8 build tasks) proportional to benefit (Human-AC backlog reduction across all consumer projects + antifragile audit): ✓

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

**Rationale**: A 6-turn dialogue with user (full trail in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log) converged on a design that resolves the friction-vs-rigor tradeoff by reframing it: human-time friction is expensive and scarce, computational friction is cheap and tireless. The user's principle — *"work is only valuable when quality working product is delivered. False 'successfully tested' undermines this and can have severe downstream effects when subsequent development builds on it"* — rules out caching, lazy hybrids, and first-time exceptions. Every verification is fresh, every time. Antifragility is built in: Pass B of the daily cron tunes the escalation-pattern catalogue from its own near-misses. Design extends existing infrastructure — no greenfield subsystems. Scope-fence honored: re-classifying existing Human ACs in bulk is OUT (incremental on next-touch only).

Design summary:
1. Model V (always-fresh) — validation agent invoked on every `fw task update --status work-completed` request via `/review T-XXX` slash command (or programmatic equivalent `fw skill invoke review --task T-XXX`). Behind `/review`, the orchestrator routes to an appropriate model class (T-1064 dependency: Haiku for routine, Sonnet for standard, Opus for high-risk/governance, external for specialised). Hard prerequisite gate: status change rejected if validation fails. No cache.
2. Evidence persistence (Q1) — task body gets new `## Verification Output` section (reviewer verdict + summary + anti-pattern flags, ~10 lines); full stdout/stderr/exit-codes/env-fingerprint to `docs/reports/T-XXX-evidence.md`; `fw bus post` envelope optional for cross-agent review.
3. Two-layer human escalation — Layer 1 mechanical pattern triggers (`policy/escalation-patterns.yaml`: governance surfaces, security components, public APIs, destructive ops, fabric-flagged sensitive components, evidence anti-patterns); Layer 2 declared escalation (new frontmatter `risk: high|medium|low` + `human_signoff: required|optional`). Reviewer (T-1443) consults both before mechanical-ticking.
4. Layer 3 audit safety-net (daily cron) — Pass A: drift detection re-runs verification commands fresh against current HEAD on rolling 30-day window + always-on core fabric components, surfaces failures as `issues`. Pass B: escalation audit cross-references commits-since-completion + frontmatter against Layer 1 patterns, flags missed escalations. Output → Watchtower `/cron/validation-audit` antifragility dashboard.
5. Reviewer responsibilities (T-1443 inherits) — assesses evidence *quality*, not exit code: detects tautology, empty output, mock-only coverage, scope-narrowing, skip-as-pass; consults Layer 1 patterns; escalates to human on match or insufficient-evidence.
6. Slash-command surface + orchestrator routing — `/review` is the uniform entry point; orchestrator picks the model class per task profile (risk + Layer 1 pattern match + evidence size + fabric blast-radius). Same routing primitive as T-1064/T-1065. Daily cron Pass A and Pass B also route through `/review` with profile hints (cheap models for bulk re-validation, escalating only on detected drift).

**Date**: 2026-04-25T07:22:38Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-25T07:22:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** A 6-turn dialogue with user (full trail in `docs/reports/T-1442-ac-validation-default-flip.md` § Dialogue Log) converged on a design that resolves the friction-vs-rigor tradeoff by reframing it: human-time friction is expensive and scarce, computational friction is cheap and tireless. The user's principle — *"work is only valuable when quality working product is delivered. False 'successfully tested' undermines this and can have severe downstream effects when subsequent development builds on it"* — rules out caching, lazy hybrids, and first-time exceptions. Every verification is fresh, every time. Antifragility is built in: Pass B of the daily cron tunes the escalation-pattern catalogue from its own near-misses. Design extends existing infrastructure — no greenfield subsystems. Scope-fence honored: re-classifying existing Human ACs in bulk is OUT (incremental on next-touch only).

Design summary:
1. Model V (always-fresh) — validation agent invoked on every `fw task update --status work-completed` request via `/review T-XXX` slash command (or programmatic equivalent `fw skill invoke review --task T-XXX`). Behind `/review`, the orchestrator routes to an appropriate model class (T-1064 dependency: Haiku for routine, Sonnet for standard, Opus for high-risk/governance, external for specialised). Hard prerequisite gate: status change rejected if validation fails. No cache.
2. Evidence persistence (Q1) — task body gets new `## Verification Output` section (reviewer verdict + summary + anti-pattern flags, ~10 lines); full stdout/stderr/exit-codes/env-fingerprint to `docs/reports/T-XXX-evidence.md`; `fw bus post` envelope optional for cross-agent review.
3. Two-layer human escalation — Layer 1 mechanical pattern triggers (`policy/escalation-patterns.yaml`: governance surfaces, security components, public APIs, destructive ops, fabric-flagged sensitive components, evidence anti-patterns); Layer 2 declared escalation (new frontmatter `risk: high|medium|low` + `human_signoff: required|optional`). Reviewer (T-1443) consults both before mechanical-ticking.
4. Layer 3 audit safety-net (daily cron) — Pass A: drift detection re-runs verification commands fresh against current HEAD on rolling 30-day window + always-on core fabric components, surfaces failures as `issues`. Pass B: escalation audit cross-references commits-since-completion + frontmatter against Layer 1 patterns, flags missed escalations. Output → Watchtower `/cron/validation-audit` antifragility dashboard.
5. Reviewer responsibilities (T-1443 inherits) — assesses evidence *quality*, not exit code: detects tautology, empty output, mock-only coverage, scope-narrowing, skip-as-pass; consults Layer 1 patterns; escalates to human on match or insufficient-evidence.
6. Slash-command surface + orchestrator routing — `/review` is the uniform entry point; orchestrator picks the model class per task profile (risk + Layer 1 pattern match + evidence size + fabric blast-radius). Same routing primitive as T-1064/T-1065. Daily cron Pass A and Pass B also route through `/review` with profile hints (cheap models for bulk re-validation, escalating only on detected drift).

### 2026-04-25T07:22:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f7b91252
- **Timestamp:** 2026-06-02T14:57:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
