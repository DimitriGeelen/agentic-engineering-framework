---
id: T-2280
name: "fw doctor cross-instance Watchtower scan — WARN when N≥2 instances share cookie
  name"
description: >
  Inception: fw doctor cross-instance Watchtower scan — WARN when N≥2 instances share
  cookie name

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-09T08:38:27Z
last_update: 2026-06-09T08:39:50Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-09T08:39:50Z'
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
---

# T-2280: fw doctor cross-instance Watchtower scan — WARN when N≥2 instances share cookie name

## Problem Statement

T-2277 Leg C follow-on. `fw doctor` today checks the **current**
project's invariants — watchtower port file, secret key, vendored
config drift. It is **blind to cross-process / cross-host state**:
how many Watchtower instances run on this host, whether their cookie
names collide, whether their ports conflict, whether their secret_key
files have drifted. The class is invisible to every existing gate
(parent T-2277 RCA §5 "Why did no detector catch this?").

After T-2278 (Leg A, port-scoped cookie names) ships, the specific
failure class is gone — but the **operational reality** that this
host runs N Watchtower instances is still useful situational
awareness. `fw doctor` should surface it.

See `docs/reports/T-2277-watchtower-csrf-pollution.md` §"Observability
(Leg C)" for the parent design sketch.

## Assumptions

- **A1:** `ss -tlnp` is available on the operator host (verified — used
  elsewhere in framework, e.g. session capture).
- **A2:** Parsing `python3 -m web.app --port N` from `ss` output is a
  reliable Watchtower-instance signature (matches the current run
  pattern — 9 instances observed 2026-06-09).
- **A3:** Operators want to *know* about multi-instance state, not be
  blocked by it — this is WARN-only, never FAIL.

## Open Questions

- **IW-1: Should the scan run in `fw doctor` only, or also in `fw audit`?**
  confidence: 2
  disposition: answered
  rationale: `fw doctor` only. Audit is project-scoped (per CLAUDE.md
  governance); cross-host state belongs to doctor's operational-health
  surface. Same separation as port-resolution helpers.

- **IW-2: What exact WARN condition should fire?**
  confidence: 1
  disposition: deferred
  rationale: Build-time decision. Candidates: (a) N≥2 instances + any
  unscoped cookie name; (b) N≥2 instances always (informational); (c)
  detect cookie-name collision by probing each instance's
  `SESSION_COOKIE_NAME`. (c) requires HTTP probe; (a)/(b) are local.
  Recommend (a) — most actionable.

## Exploration Plan

RCA already in parent T-2277. Implementation plan:

1. Add `_check_multi_instance_watchtower` helper to `bin/fw doctor`
   or `lib/doctor.sh`.
2. Use `ss -tlnp 2>/dev/null | grep -oE "python3.*web.app.*port [0-9]+"`.
3. If N≥2 AND current instance's `SESSION_COOKIE_NAME` is the Flask
   default (i.e. T-2278 not deployed here), WARN.
4. One bats test pinning the WARN line shape.

## Technical Constraints

- `ss` requires CAP_NET_ADMIN for full info; without it we get less
  detail but still see ports — degrade gracefully.
- Cross-platform: `ss` is Linux-only. Add `command -v ss` guard and
  skip the check on non-Linux (BSD/macOS) with INFO line.
- No HTTP probes (would slow doctor + need each instance's port).

## Scope Fence

**IN scope:**
- `fw doctor` multi-instance scan emitting WARN.
- Bats test pinning WARN line shape.
- Linux gating + graceful skip on other OSes.

**OUT of scope:**
- HTTP probes against each instance.
- Auto-remediation (we WARN; operator fixes).
- Sniffing cookie names from running processes (overreach).
- Cross-host federation (only check the local host).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
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
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

fw doctor today checks the current project's invariants in isolation. Cross-host operational state (other Watchtower instances sharing cookie slots, port collisions, secret-key drift) is invisible. Add ~15-line scan: 'ss -tlnp | grep python3.*web.app' → if N≥2 AND current instance has unscoped SESSION_COOKIE_NAME → WARN with remediation pointer. Becomes redundant for T-2277 Leg A's failure class after that ships, but is generally useful observability for the multi-instance pattern. Origin: T-2277 Leg C.

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-09T08:39:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
