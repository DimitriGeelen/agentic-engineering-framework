---
id: T-1983
name: "GO-scope traceability — inception decisions machine-readable + close gate"
description: >
  Inception: GO-scope traceability — inception decisions machine-readable + close
  gate

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: []
related_tasks: [T-1984, T-1849, T-1890, T-1442, T-1443, T-1950]
inception_decisions:
  - id: schema-frontmatter
    text: "inception_decisions: lives in inception task frontmatter (single source
      of truth, reuses T-1849 hook pattern)"
    ships_in: deferred:T-1984
  - id: ships-in-five-shapes
    text: "ships_in: accepts five shapes — file path / module.function / path::test_func
      / T-XXX / deferred:T-YYYY"
    ships_in: deferred:T-1984
  - id: gate-site
    text: "Close gate fires in update-task.sh --status work-completed on workflow_type:
      inception (not at inception-decide)"
    ships_in: deferred:T-1984
  - id: migration-grandfather
    text: "Grandfather completed inceptions without the field; gate only fires when
      inception_decisions: is non-empty"
    ships_in: deferred:T-1984
  - id: bypass-parity
    text: "Override is BOTH --skip-inception-scope-trace flag (direct) AND FW_SKIP_INCEPTION_SCOPE_TRACE=1
      env-var (downstream) per L-399"
    ships_in: deferred:T-1984
  - id: defer-then-go-sequencing
    text: "Ship substrate (T-1984) first, then dogfood via T-1950A/T-1951 (validation
      by use, not by spec)"
    ships_in: deferred:T-1984
created: 2026-05-21T18:53:14Z
last_update: '2026-06-11T22:24:05Z'
date_finished: 2026-05-21T19:29:36Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-21T18:56:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:24:05Z'
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
cost_estimate_proposed:
  - ts: '2026-05-21T19:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-1983: GO-scope traceability — inception decisions machine-readable + close gate

## Problem Statement

Inception GO decisions are **narrative markdown**, not machine-tracked. A 16-item
Decisions list (T-1443 was exactly this) can have 14 land and 2 drift unshipped —
and no part of the framework notices. G-066 is the post-hoc capture of one such
incident (T-1442/T-1443 closed work-completed while reviewer auto-tick + TermLink-
dispatch GO scope never wired). G-066's own mitigation is **symptom-level**: ship
the missing halves (T-1950/T-1951). It does not prevent the next inception from
doing the same thing.

The chain that should have caught T-1443's drift, and where each link failed:

| Link | Should catch | Why it didn't |
|------|--------------|---------------|
| Build children spec | "v1.0 implements decision 36" | Decisions are narrative; build children referenced versions, not decisions. No referent. |
| `update-task.sh --status work-completed` (T-1443) | "GO scope hasn't fully landed" | No model of GO scope. Checks Agent ACs (about running inception process), not decisions shipped. |
| `fw audit` | "decision X has no implementation" | No decisions→code traceability. |
| Reviewer (`static_scan.py`) | "task body contradicts shipped code" | No awareness of inception GO scope. |
| G-062 (arc closure gate) | "headline mechanic must fire" | Arc-level only; inception closes have no analogous gate. |

**The structural omission: inception GO scope is narrative, not enforceable.**

## Scope Fence

**IN scope:**
- Frontmatter schema for inception decisions (decision IDs, ships_in references)
- Frontmatter field on build children: `unlocks_inception_decision:`
- Refusal gate in `update-task.sh --status work-completed` for `workflow_type: inception`
- Migration story for existing completed inceptions (grandfather, do not retroact)
- One Tier-2 override flag with bypass log
- Reuse of T-1849 `arc_id:` validation pattern (PreToolUse hook + override env-var)

**OUT of scope (separate inception if needed):**
- Detective audit/reviewer patterns for **already-completed** inceptions (the B/C of the A/B/C — Layer 3 safety net, file later if A leaves drift)
- Decisions list redesign for arcs (`headline_mechanic` already serves this; arc model is sufficient)
- Multi-decision authorship workflow (multiple agents editing same Decisions list — not a current pain point)

## Exploration Plan

Minimal. The four design questions (schema, build-child link, gate behaviour,
migration) are addressed inline in this body's **Decisions** section. No
external spikes needed — substrate already exists (T-1849 `arc_id:` validation
hook is the analogue; `update-task.sh` is the gate site). One prototype path:
shape the schema in this artefact, file build child T-1983A on GO, ship in one
slice.

## Technical Constraints

- Must not break existing 200+ completed inceptions (no retroactive gate firing).
- Must not require a separate sidecar file — agents already write task frontmatter; one substrate keeps the truth in one place (T-1849 precedent).
- Must support `deferred_to: T-YYYY` so legitimate scope cuts (e.g. T-1443 deferring v3+ to later) don't trigger the gate.
- Refusal text must name the override mechanism (L-399 — bypass contract parity).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated — chain-of-blindness mapped, root cause distinguished from G-066 symptom
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested — substrate analogue (T-1849 arc_id) confirmed; gate site identified (`update-task.sh --status work-completed`); migration grandfathering feasible
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
- Schema is small (one new optional frontmatter field on inception + one on build children)
- Gate fires only on inceptions that opt in (i.e. have a populated `inception_decisions:` block), grandfathering all existing completed inceptions
- Override mechanism is a single Tier-2 flag with bypass log entry — no proliferation of escape hatches
- Reuses existing T-1849 hook pattern (PreToolUse `check-arc-id` is the analogue)

**NO-GO if:**
- Schema requires changes to >2 files outside `lib/inception.sh` + `update-task.sh` + one new validation hook
- Migration requires touching existing completed inceptions retroactively (breaks the "do not invalidate the corpus" principle)
- Refusal text needs more than one paragraph to explain (signal that the contract is too complex)

**DEFER if:**
- T-1950A/T-1951 (G-066 symptom shipment) are mid-build and this introduces churn — defer A until those land, then T-1950A becomes the **first consumer** of A's substrate as the dogfood validation.

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

Root cause of G-066 (T-1442/T-1443 closed work-completed with auto-tick GO unshipped 26 days). Symptom-level mitigation is shipping the missing halves (T-1950/T-1951). Structural fix: inception Decisions become machine-readable; build children declare unlocks_inception_decision; update-task.sh refuses inception close until every decision has a shipped child or explicit deferred_to link. Preventive (closes the trap at GO time, not 26 days later). Reuses T-1849 arc_id frontmatter pattern. Cost: schema + parser + one refusal check. Pick A from the A/B/C analysis in T-1950 RCA exchange (S-2026-0521-resume).

**Evidence:**
- G-066 already registered in `.context/project/concerns.yaml` as "T-1442/T-1443 closed work-completed while half of GO scope … never wired — §ACD pattern at task level (G-062 family)"
- T-1443 GO decisions sanctioning unshipped auto-tick: `docs/reports/T-1443-independent-reviewer-agent.md:21, 36, 113, 213`
- Visible smoking-gun left in source 26+ days: `lib/reviewer/static_scan.py:7, 1130` ("NEVER modifies AC checkboxes" — leftover v1.0 text contradicting GO decision)
- Substrate analogue exists: T-1849 `arc_id:` frontmatter + `agents/context/check-arc-id` PreToolUse hook + `FW_ALLOW_ARC_ID_DRIFT=1` override — exact pattern to reuse
- Gate site exists: `agents/task-create/update-task.sh` already runs Verification commands + counts AC checkboxes at `--status work-completed`; adding one more refusal check is local
- Bypass-contract L-399 precedent: T-1890 codified producer/consumer parity; the proposed override does both `--skip-…` and `FW_SKIP_…` per that rule
- Sequencing rationale lives in this artefact's Decisions block (DEFER-then-A-then-T-1950A); T-1950 inception artefact at `docs/reports/T-1950-reviewer-auto-tick-inception.md` is the primary dogfood consumer

**Confirm:** `fw inception decide T-1983 go --rationale "approved, dogfood via T-1950A"` (via Watchtower at http://192.168.10.107:3000/inception/T-1983)

**Override:** NO-GO if the structural change is over-engineered for one incident (you'd rather rely on detective layer B/C); DEFER without ship if you want to gather more incident evidence first.

## Decisions

### 2026-05-21 — Schema lives in inception task frontmatter (not sidecar)

- **Chose:** New optional frontmatter field `inception_decisions:` on `workflow_type: inception` task files. List of `{id, text, ships_in}` entries. Build children gain optional `unlocks_inception_decision:` (list of `T-XXX:DYY` references). Both fields validated by a PreToolUse hook on Write|Edit (same shape as T-1849 `check-arc-id`).
- **Why:** Single source of truth in the task file itself; agents already write frontmatter; one parser; reuses T-1849's validated hook pattern. No new file class to back up / mirror / migrate.
- **Rejected:** Sidecar YAML at `.context/inceptions/T-XXX.yaml` (duplicates content, divergence risk). Frontmatter on `docs/reports/T-XXX-*.md` (report files have no schema convention; agents would forget). Free-form markdown table parsed by regex (T-1864 ate the corpus exactly this way — never parse load-bearing data out of prose).

### 2026-05-21 — `ships_in:` is one of {file path, function/symbol name, test name, task-id, literal `deferred`}

- **Chose:** `ships_in:` is a string; validator accepts five shapes — (1) `path/to/file.py`, (2) `module.function_name`, (3) `tests/.../test_name.py::test_func`, (4) `T-XXX` (task ID — points at a build child), (5) literal `deferred:T-YYYY` (explicit defer with target). At gate time: shapes 1-3 are verified by file/symbol existence; shape 4 by the target task being `work-completed`; shape 5 by the target task existing in `.tasks/{active,completed}/`.
- **Why:** Multiple referent types because decisions land in different artefacts (some are code, some are tests, some are policy YAML, some are explicit defers). Five shapes covers everything T-1443 needed without forcing a single style.
- **Rejected:** Force `ships_in: T-XXX` only (too rigid — decisions like "Spike F = 12-pattern catalogue" land as a YAML policy file, not a task). Free-form (loses gate enforceability). Composite YAML (overkill — one field, five validated shapes).

### 2026-05-21 — Gate fires in `update-task.sh --status work-completed` (not at inception-decide)

- **Chose:** When an inception task transitions to `work-completed`, `update-task.sh` parses `inception_decisions:` and validates every entry's `ships_in:`. If any entry's referent is unreachable (file missing, function not defined, task not work-completed, deferred-to target absent), refuse the transition with a block message naming the failing entry and the override flag. Override: `--skip-inception-scope-trace "rationale"` (Tier-2, logged in `.gate-bypass-log.yaml`).
- **Why:** The gate must fire when the inception **closes**, not when it decides — between decide and close, build children are filed and shipped, and the gate's job is to verify they actually landed. Decide-time validation is too early; cron-time validation is too late (G-066 was post-hoc).
- **Rejected:** Gate at `fw inception decide go` (would refuse before any building started — backwards). Gate at `fw audit` (detective; G-066 already proves this latency is unacceptable). Gate at git pre-push (file-scope mismatch — git hook can't reason about task lifecycle).

### 2026-05-21 — Migration: grandfather completed inceptions; gate applies only to populated `inception_decisions:`

- **Chose:** The new frontmatter field is **optional**. Completed inceptions without it (200+ in `.tasks/completed/`) are grandfathered — gate does not retroact. New inceptions filed from the next agent session forward are encouraged (CLAUDE.md text) to populate the field. The gate only fires when the field is **non-empty** — empty/missing = "opt out", logged on close as an info-level note in feedback-stream.
- **Why:** Retroactive enforcement would invalidate the existing corpus and produce noise. Grandfather + opt-in via population is the antifragile path — adoption is observable (count of inceptions with populated decisions over time), drift is preventable for new inceptions, existing trail is preserved.
- **Rejected:** Force-backfill on next-touch (high effort, agents would skip; produces "inception_decisions: []" placeholder noise). Hard cutoff date (arbitrary; introduces a class divide in the corpus). Mandatory on file (would block T-1442/T-1443's legitimate "captured" filing pattern that pre-dates decisions).

### 2026-05-21 — Bypass contract parity (L-399): refusal names BOTH the flag and the env-var prefix

- **Chose:** Override mechanism is **both** (a) `--skip-inception-scope-trace "rationale"` for direct invocations of `update-task.sh` (or `fw task update`) and (b) `FW_SKIP_INCEPTION_SCOPE_TRACE=1` env-var prefix for indirect invocations (commit hooks, git via `git commit`, etc). Refusal block message lists both with one-line guidance per L-399 (T-1890).
- **Why:** Hooks gate command patterns; downstream parsers reject unknown flags. T-1890 origin is the same class — focus-drift gate's `--switch-focus` worked on fw sub-scripts but not on `git commit`. The env-var prefix is the cross-cutting bypass.
- **Rejected:** Flag-only (breaks for indirect invocations — L-399). Env-var only (loses CLI discoverability). No override (Tier-2 needs an explicit escape hatch per CLAUDE.md §Enforcement Tiers).

### 2026-05-21 — DEFER vs GO sequencing

- **Chose (suggested to human):** **DEFER** A's shipment until T-1950A/T-1951 are ready to file, then **A ships first** so T-1950A/T-1951 become its first consumers (dogfood-as-validation). Net latency added: one slice. Net signal gained: the substrate is proven on its primary use case before adoption is asked of anyone else.
- **Why:** GO now means we'd file A as a separate build, ship it, then file T-1950A/T-1951 — but T-1950's inception is fresh and shippable; dogfooding A against it is the right antifragility signal. The user's directive ("proceed as you see fit, focus BVP arc HV-LC") favours the dogfood path.
- **Rejected:** GO-now-ship-A-before-T-1950A (forces a sequence where A's correctness isn't proven on a real workload). Defer-indefinitely (defeats the whole point — G-066 stays open).

## Decision

**Decision**: GO

**Rationale**: Root cause of G-066 (T-1442/T-1443 closed work-completed with auto-tick GO unshipped 26 days). Symptom-level mitigation is shipping the missing halves (T-1950/T-1951). Structural fix: inception Decisions become machine-readable; build children declare unlocks_inception_decision; update-task.sh refuses inception close until every decision has a shipped child or explicit deferred_to link. Preventive (closes the trap at GO time, not 26 days later). Reuses T-1849 arc_id frontmatter pattern. Cost: schema + parser + one refusal check. Pick A from the A/B/C analysis in T-1950 RCA exchange (S-2026-0521-resume).

**Date**: 2026-05-21T19:29:36Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-21T18:56:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-21T19:29:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Root cause of G-066 (T-1442/T-1443 closed work-completed with auto-tick GO unshipped 26 days). Symptom-level mitigation is shipping the missing halves (T-1950/T-1951). Structural fix: inception Decisions become machine-readable; build children declare unlocks_inception_decision; update-task.sh refuses inception close until every decision has a shipped child or explicit deferred_to link. Preventive (closes the trap at GO time, not 26 days later). Reuses T-1849 arc_id frontmatter pattern. Cost: schema + parser + one refusal check. Pick A from the A/B/C analysis in T-1950 RCA exchange (S-2026-0521-resume).

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1fc93b49
- **Timestamp:** 2026-06-02T15:00:44Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-21T19:29:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
