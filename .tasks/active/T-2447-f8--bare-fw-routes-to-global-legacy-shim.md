---
id: T-2447
name: "F8 — bare fw routes to global legacy shim instead of consumer-local fw (T-1257 hazard)"
description: >
  Inception: F8 — bare fw routes to global legacy shim instead of consumer-local fw (T-1257 hazard)

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-21T10:39:29Z
last_update: 2026-06-21T10:39:29Z
date_finished: null
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
---

# T-2447: F8 — bare fw routes to global legacy shim instead of consumer-local fw (T-1257 hazard)

## Problem Statement

On a host with a global install, `command -v fw` resolves to `~/.local/bin/fw` — a **symlink to the
GLOBAL framework's `bin/fw`** (`/root/.agentic-framework/bin/fw`), NOT the consumer's vendored copy. So
bare `fw` from inside a consumer runs the *global* framework's PROJECT_ROOT/FRAMEWORK_ROOT resolution
logic, at a different (older) version than the consumer's own vendored `bin/fw`. The T-1257 hazard
live: bare `fw` ≠ `.agentic-framework/bin/fw`. Audience: agents + onboarders who type bare `fw`.
Full analysis: `docs/reports/T-2447-f8-shim-routing.md`.

## Assumptions

- A-1: The global shim is a symlink to the global `bin/fw`, not a per-consumer copy.
      **VALIDATED** — `ls -la ~/.local/bin/fw → -> /root/.agentic-framework/bin/fw`.
- A-2: The global shim can be at a different version than the consumer's vendored fw.
      **VALIDATED** — `grep -c T-2446 ~/.local/bin/fw → 0` (global lacks this session's fix).
- A-3: Only the *resolution logic* skews; framework *code* stays vendored-correct.
      **VALIDATED** — `resolve_framework` T-498 preference (bin/fw:117) redirects FRAMEWORK_ROOT to the
      consumer's vendored copy even under global-shim invocation.

## Open Questions

- **IW-1: Is the version skew real, or does resolve_framework already neutralise it?**
  confidence: 3
  disposition: answered
  rationale: Skew is real — global shim lacks T-2446 (resolution logic); code stays vendored via T-498 bin/fw:117. Detail in docs/reports/T-2447-f8-shim-routing.md.
- **IW-2: Can a "re-exec to project-local" fix re-trigger the T-2099 fork bomb?**
  confidence: 3
  disposition: answered
  rationale: Yes — T-2099 was exactly re-exec + T-498 re-resolution recursion (bin/fw:598-606). Any
  re-exec MUST carry an env-sentinel guard. This is the dominant design constraint → drives the choice
  of Candidate C (isolated thin shim) over A (bin/fw hot path).
- **IW-3: Which candidate balances the defect against the SEV-1 blast radius?**
  confidence: 3
  disposition: answered
  rationale: Candidate C+E chosen; A rejected (bin/fw hot path), D rejected (T-1257 live), B folded. Constraint T-2099 bin/fw:598-606; matrix docs/reports/T-2447-f8-shim-routing.md.

## Exploration Plan

Completed in-session (no spike needed): (1) inspect the shim (symlink vs copy) ✓; (2) diff global vs
vendored version for a known fix ✓; (3) trace resolve_framework's vendored preference ✓; (4) review
T-2099 fork-bomb prior art for recursion constraints ✓. All four done — see research artifact.

## Technical Constraints

- Four invocation modes must keep working: framework-repo-self, direct-vendored, global-from-consumer,
  global-from-non-project (resolve_framework contract).
- No recursion (T-2099 fork-bomb) — env-sentinel guard mandatory on any re-exec.
- Explicit `PROJECT_ROOT` env still wins (T-2391/T-2446).
- `upgrade_fresh_machine_simulation.bats` stays green (T-1633 consumer-facing hygiene).

## Scope Fence

**IN:** routing of the bare-`fw` PATH entry point to the consumer-local fw + detecting silent version
skew. **OUT (sibling findings, separate tasks):** F2 (legacy-shim messaging), F3 (`fw --version` →
`vdev`). One inception = one question.

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
- Root cause identified with a bounded fix path that does NOT mutate bin/fw's SEV-1 hot path
- The re-exec carries a proven recursion guard (env-sentinel, per T-2099)
- All 4 invocation modes + the fresh-machine simulation stay green

**NO-GO if:**
- The only viable fix sits on bin/fw's resolution hot path (unacceptable blast radius)
- Version skew proves illusory (resolve_framework already neutralises it) — it does not (A-2)

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

**Recommendation:** GO — Candidate C (thin re-exec shim, env-sentinel guarded) + Candidate E (doctor
skew-WARN), shipped as one build slice. Reject A (bin/fw hot path) and D (do-nothing); fold B
(prompt-text fix) into the slice.

**Rationale:**

The defect is real and concrete — the global shim is a symlink to the global `bin/fw` and lacks the
T-2446 fix, so bare `fw` from a consumer runs stale resolution logic (the exact surface
T-2389→T-2446 keep fixing). Doing nothing (D) leaves the T-1257 hazard the operator flagged. The
operator's F8 instinct was re-exec; Candidate C delivers it while isolating the recursion risk to a
small, independently-testable shim **off** bin/fw's SEV-1 hot path (Candidate A puts it ON that path —
rejected). The env-sentinel guard is proven by T-2099 (which already uses env-scoped FRAMEWORK_ROOT to
break this exact recursion), so the fork-bomb class is preventable by construction. Candidate E ships
alongside because the real harm is *silent* skew and a new wrapper won't retroactively fix the symlink
shims already in the wild — the doctor WARN closes that gap. F2/F3 are sibling findings, deliberately
out of scope (one inception = one question).

**Evidence:**

- `~/.local/bin/fw -> /root/.agentic-framework/bin/fw` (symlink to GLOBAL, live).
- `grep -c T-2446 ~/.local/bin/fw` → 0 (concrete version skew vs the worktree's shipped fix).
- `resolve_framework` T-498 preference (bin/fw:117) — code stays vendored-correct; only resolution
  logic skews (narrows the blast, motivates C-not-A).
- T-2099 fork-bomb prior art (bin/fw:598-606) — the recursion constraint + the proven env-sentinel fix.
- Full analysis + 5-candidate matrix: `docs/reports/T-2447-f8-shim-routing.md`.

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

## Reviewer Verdict (v1.5)

- **Scan ID:** R-882e4fa8
- **Timestamp:** 2026-06-21T10:49:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
