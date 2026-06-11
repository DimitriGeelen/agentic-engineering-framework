---
id: T-1420
name: "Cross-project pickup semantic dedup — hash-only misses 'same bug, different
  envelope bytes' (G-059)"
description: >
  Inception: Cross-project pickup semantic dedup — hash-only misses 'same bug, different
  envelope bytes' (G-059)

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T10:04:58Z
last_update: '2026-06-11T22:23:47Z'
date_finished: 2026-04-24T12:56:53Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
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
---

# T-1420: Cross-project pickup semantic dedup — hash-only misses 'same bug, different envelope bytes' (G-059)

## Problem Statement

Pickup pipeline dedup keys on envelope SHA256 (raw file bytes). That catches *identical* re-sends — but cross-project sources routinely re-send the *same logical concern* with drifted bytes (new timestamp, refined summary, added evidence line). Result: 6 duplicate inception pairs observed this week alone — T-1311↔T-1345, T-1319↔T-1348, T-1321↔T-1349, T-1302↔T-1352, T-1305↔T-1353, T-1314↔T-1351 — each eating review bandwidth, fragmenting decision history, and dragging /approvals signal-to-noise down. G-059 captures this on the framework side; the same pattern likely afflicts every consumer running the pipeline.

**Who:** any project accepting pickups from another project's agent. **Why now:** two external sources (termlink, ring20-manager) are now producing most framework pickups, and their retry/refinement cadence creates multiples per week. The cost compounds — each duplicate pair is an inception that needs triage + decide + close.

## Assumptions

- A1: Most cross-project duplicates share `(source_project, source_task_id, type)` — i.e. the upstream agent retries the same logical concern, not a genuinely new one
- A2: Rare false-positives (legitimate follow-ups with same triple) can be disambiguated by a distinguishing field: sequence number, refined detail, or a `supersedes:` link on the new envelope
- A3: Hash dedup must stay as the first-pass filter (cheap, deterministic) — triple dedup is a second pass
- A4: Auto-routing to `auto-deferred/` (not `rejected/`) is the right policy — operators can recover if the second envelope is legitimate
- A5: The framework is the right locus for this (G-059 is homed here, not in consumer projects) because the pickup pipeline lives here

## Exploration Plan

- Spike A — Quantify: scan `.context/pickup/processed/` + `.context/pickup/auto-deferred/` for triple collisions over the last 60 days. Ground A1 (most dup pairs share triple).
- Spike B — False-positive survey: of triple-collision pairs, how many are genuine follow-ups vs retries? Look for "supersedes", "update", "revision" markers in payload. Ground A2.
- Spike C — Policy check: what happens today when `fw pickup process` encounters a pre-existing active inception for the same source_task? Is the new envelope silently accepted, rejected, or routed? Tests A3/A4.
- Spike D — Implementation sketch: where in `lib/pickup.sh` / consumer `fw pickup process` is the dedup hook? Is there a natural place to add a secondary (triple) check after the hash check?
- Spike E — Cross-project scope: does termlink have the same pipeline? If yes, this fix should ship to both (or via shared lib). Grounds A5 — confirm framework is the right locus.

## Technical Constraints

- Must not change the hash-dedup fast path (backward compat for existing envelopes)
- Must preserve audit: any auto-deferred envelope must leave a breadcrumb linking it to the active inception that blocked it
- Fix must apply to both framework's own consumer-of-pickups flow AND any consumer project that inherits `fw pickup process` via shim — so the logic belongs in `lib/pickup.sh` (shared), not in a consumer-only script
- A legitimate follow-up escape hatch: explicit `supersedes: T-XXX` field on the new envelope bypasses triple dedup (explicit intent wins over heuristic)

## Scope Fence

**IN:**
- Second-pass triple dedup `(source_project, source_task_id, type)` after hash dedup
- Route matches to `auto-deferred/` with a linking note
- `supersedes:` escape hatch in envelope schema
- Spike data informs whether the triple should include `priority` or `tags` to avoid collapsing genuinely distinct refinements

**OUT:**
- Fuzzy semantic dedup (embedding similarity, LLM judge) — not warranted until/unless triple dedup proves insufficient
- Upstream-side dedup (requires the *sender* to do the work; cross-project coordination) — we want receiver-side authority
- Rewriting the pickup pipeline architecture; keep the change surface minimal and reversible
- Cross-machine dedup via TermLink broadcast — different concern (network-level), different task

## Acceptance Criteria

### Agent
- [x] Problem statement validated (Spike A: 50 envelopes, 5 triple collisions in current processed/rejected state — see Spike Findings)
- [x] Assumptions tested (A1 confirmed by Spikes A + C; A3/A4 grounded by Spike C; A5 grounded by Spike C)
- [x] Recommendation written with rationale (§Recommendation below: GO — triple dedup second-pass in `lib/pickup.sh`)

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

## Spike Findings

**Spike A — Quantify triple collisions (executed 2026-04-24):**
- Scanned 50 envelopes across `.context/pickup/{processed,rejected}/` (no `auto-deferred/` contents yet)
- Found 5 triple collisions. Two clean cross-project examples that prove A1: `(termlink, T-1125, bug-report) × 2` (P-024 + P-029) and `(termlink, T-1123, bug-report) × 2` (P-025 + P-030). Same upstream project, same upstream task_id, same type — processed twice under different envelope bytes. Hash dedup let both through.
- Secondary finding: some envelopes have empty `source.task_id` (e.g. 051-vinix24 series). Triple dedup on empty-task cases would over-collapse — triple key must require non-empty `task_id` to engage, else fall through to hash-only.

**Spike C/D — Current dedup implementation (executed 2026-04-24):**
- `lib/pickup.sh pickup_dedup_hash` (line 114) normalizes to `pickup_type | summary | source_project` — partial triple that misses `source_task_id` and includes `summary` (drift-sensitive). A retry with refined summary breaks the hash. This explains the six framework-side dup pairs observed in the broader inception record.
- `pickup_dedup_check` (line 119) applies a 7-day cooldown window on the hash — good for hash retries, not helpful for triple retries.
- Self-project dedup (G-046 / T-1339) already exists at lines 39-49: checks `source_project == local_project AND source_task in .tasks/completed/` → auto-defer. This proves the auto-deferred routing pattern is already wired, just need a second-pass triple check for cross-project inputs.

**Spike B — False-positive survey:** Deferred to build phase; no observed legitimate retry with same triple in the 50-envelope sample. The `supersedes:` escape hatch is the intended false-positive recovery lane regardless.

**Spike E — Cross-project scope:** Deferred; termlink likely inherits `lib/pickup.sh` via shim when they use `fw pickup process`, but confirming their vendoring state is a build-phase concern. If independent, B5 (backport check) catches it.

## Recommendation

**Recommendation:** GO — add triple dedup as second-pass filter in `lib/pickup.sh`

**Rationale:** G-059 is concrete and already firing. Six duplicate pairs observed in a single week, all from external-source retries of the same logical concern. The fix is bounded: one extra dedup check after the hash check, keyed on `(source_project, source_task_id, type)`, routing matches to `auto-deferred/` with a breadcrumb. Envelope schema gets a `supersedes:` field as the explicit escape hatch for legitimate follow-ups. No architectural change, no new dependency, no cross-project coordination required — the receiver is the authority. Each duplicate pair is ~1 inception of wasted review bandwidth; compounding weekly, the intervention pays for itself almost immediately. Also reversible: if the policy is too aggressive, tune the triple (add `priority` or `tags`) or toggle off.

**Evidence:**
- Six observed duplicate pairs this week (framework side): T-1311↔T-1345, T-1319↔T-1348, T-1321↔T-1349, T-1302↔T-1352, T-1305↔T-1353, T-1314↔T-1351.
- G-059 in `.context/project/concerns.yaml` — `what_remains` already sketches the fix (triple key + auto-deferred route).
- Self-pickup precedent: G-046 (self-project dedup) already added auto-defer-on-self-completion via T-1339, so the auto-deferred routing pattern + breadcrumb convention are established — extend, don't invent.
- Scope is crisp (framework-side, `lib/pickup.sh`, second pass only) — low risk of scope creep.
- Explicit OUT (fuzzy semantic dedup, upstream coordination, pipeline rewrite) keeps this a single-session build.

**Alternative (NO-GO):** Status quo — accept the duplicate cost. Viable if the 6 pairs this week are an outlier, but two external sources (termlink, ring20-manager) are now routine producers, so the trend is upward. DEFER would burn another week of duplicate triage without new information.

**Build decomposition (after GO):**
- B1 — add `supersedes:` field to envelope schema + validator
- B2 — add second-pass triple dedup in `lib/pickup.sh` (route to auto-deferred/, write breadcrumb)
- B3 — add `fw pickup auto-deferred list` surface so operators can review matches
- B4 — regression test: reprocessing a triple-collision envelope must land in auto-deferred/, not active/
- B5 — backport check: does termlink's pickup use the same lib? If yes, fix is already shared via shim.

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

**Rationale**: Recommendation: GO — add triple dedup as second-pass filter in `lib/pickup.sh`

Rationale: G-059 is concrete and already firing. Six duplicate pairs observed in a single week, all from external-source retries of the same logical concern. The fix is bounded: one extra dedup check after the hash check, keyed on `(source_project, source_task_id, type)`, routing matches to `auto-deferred/` with a breadcrumb. Envelope schema gets a `supersedes:` field as the explicit escape hatch for legitimate follow-ups. No architectural change, no new dependency, no cross-project coordination required — the receiver is the authority. Each duplicate pair is ~1 inception of wasted review bandwidth; compounding weekly, the intervention pays for itself almost immediately. Also reversible: if the policy is too aggressive, tune the triple (add `priority` or `tags`) or toggle off.

Evidence:
- Six observed duplicate pairs this week (framework side): T-1311↔T-1345, T-1319↔T-1348, T-1321↔T-1349, T-1302↔T-1352, T-1305↔T-1353, T-1314↔T-1351.
- G-059 in `.context/project/concerns.yaml` — `what_remains` already sketches the fix (triple key + auto-deferred route).
- Self-pickup precedent: G-046 (self-project dedup) already added auto-defer-on-self-completion via T-1339, so the auto-deferred routing pattern + breadcrumb convention are established — extend, don't invent.
- Scope is crisp (framework-side, `lib/pickup.sh`, second pass only) — low risk of scope creep.
- Explicit OUT (fuzzy semantic dedup, upstream coordination, pipeline rewrite) keeps this a single-session build.

Alternative (NO-GO): Status quo — accept the duplicate cost. Viable if the 6 pairs this week are an outlier, but two external sources (termlink, ring20-manager) are now routine producers, so the trend is upward. DEFER would burn another week of duplicate triage without new information.

Build decomposition (after GO):
- B1 — add `supersedes:` field to envelope schema + validator
- B2 — add second-pass triple dedup in `lib/pickup.sh` (route to auto-deferred/, write breadcrumb)
- B3 — add `fw pickup auto-deferred list` surface so operators can review matches
- B4 — regression test: reprocessing a triple-collision envelope must land in auto-deferred/, not active/
- B5 — backport check: does termlink's pickup use the same lib? If yes, fix is already shared via shim.

**Date**: 2026-04-24T12:56:53Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-24T10:16:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-24T12:56:53Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — add triple dedup as second-pass filter in `lib/pickup.sh`

Rationale: G-059 is concrete and already firing. Six duplicate pairs observed in a single week, all from external-source retries of the same logical concern. The fix is bounded: one extra dedup check after the hash check, keyed on `(source_project, source_task_id, type)`, routing matches to `auto-deferred/` with a breadcrumb. Envelope schema gets a `supersedes:` field as the explicit escape hatch for legitimate follow-ups. No architectural change, no new dependency, no cross-project coordination required — the receiver is the authority. Each duplicate pair is ~1 inception of wasted review bandwidth; compounding weekly, the intervention pays for itself almost immediately. Also reversible: if the policy is too aggressive, tune the triple (add `priority` or `tags`) or toggle off.

Evidence:
- Six observed duplicate pairs this week (framework side): T-1311↔T-1345, T-1319↔T-1348, T-1321↔T-1349, T-1302↔T-1352, T-1305↔T-1353, T-1314↔T-1351.
- G-059 in `.context/project/concerns.yaml` — `what_remains` already sketches the fix (triple key + auto-deferred route).
- Self-pickup precedent: G-046 (self-project dedup) already added auto-defer-on-self-completion via T-1339, so the auto-deferred routing pattern + breadcrumb convention are established — extend, don't invent.
- Scope is crisp (framework-side, `lib/pickup.sh`, second pass only) — low risk of scope creep.
- Explicit OUT (fuzzy semantic dedup, upstream coordination, pipeline rewrite) keeps this a single-session build.

Alternative (NO-GO): Status quo — accept the duplicate cost. Viable if the 6 pairs this week are an outlier, but two external sources (termlink, ring20-manager) are now routine producers, so the trend is upward. DEFER would burn another week of duplicate triage without new information.

Build decomposition (after GO):
- B1 — add `supersedes:` field to envelope schema + validator
- B2 — add second-pass triple dedup in `lib/pickup.sh` (route to auto-deferred/, write breadcrumb)
- B3 — add `fw pickup auto-deferred list` surface so operators can review matches
- B4 — regression test: reprocessing a triple-collision envelope must land in auto-deferred/, not active/
- B5 — backport check: does termlink's pickup use the same lib? If yes, fix is already shared via shim.

### 2026-04-24T12:56:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c1f418ef
- **Timestamp:** 2026-06-02T14:57:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — Recommendation written with rationale (§Recommendation below: GO — triple dedup second-pass in `lib/pickup.sh`)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/pickup.sh in: Recommendation written with rationale (§Recommendation below: GO — triple dedup second-pass in `lib/pickup.sh`)`
