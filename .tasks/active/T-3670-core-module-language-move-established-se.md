---
id: T-3670
name: "Core-module language: move established, security-critical core (Tier 0, task/focus/budget
  gates, verdict ledger, close gates) from bash to a typed strict language (lean:
  Go with mvdan.cc/sh parser); pilot = Tier 0 classifier on a real bash AST"
description: >
  Inception: Core-module language: move established, security-critical core (Tier
  0, task/focus/budget gates, verdict ledger, close gates) from bash to a typed strict
  language (lean: Go with mvdan.cc/sh parser); pilot = Tier 0 classifier on a real
  bash AST

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
origin: {kind: "operator", source: "", ref: "operator question 2026-10-01"}
created: 2026-10-01T17:36:53Z
last_update: '2026-10-05T20:15:18Z'
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
  - ts: '2026-10-01T17:37:58Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-10-01T17:45:18Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=148,acs=4)
    rubric_sha: e4a00f38e801
  - ts: '2026-10-05T20:15:18Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=7 (lines=162,acs=4)
    rubric_sha: e4a00f38e801
---

# T-3670: Core-module language: move established, security-critical core (Tier 0, task/focus/budget gates, verdict ledger, close gates) from bash to a typed strict language (lean: Go with mvdan.cc/sh parser); pilot = Tier 0 classifier on a real bash AST

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Which language for the established core: Go, Rust, or strict Python?**
  - Go: mvdan.cc/sh (shfmt's parser), a single static binary, fast hook cold-start.
  - Rust: matches TermLink, the strongest guarantees, but a less mature bash parser.
  - Strict Python (mypy --strict): the lowest migration cost, but slow hook startup, and only bashlex as a parser.
  Lean: Go.
  confidence: 1
  disposition: deferred
  rationale: Deferred to the pilot's parity experiment. Round 1 split (docs/reports/T-3670-r1-synthesis.md D2): 2 of 3 seats chose Go/mvdan.cc/sh for the Tier 0 classifier, 1 chose TypeScript, and all three keep bash as CLI glue and call the language secondary to the architecture. Settle it by running the 98-case §5 corpus against a Go and a TypeScript classifier.
- **IW-2: What counts as "established core"?** Proposed set: the Tier 0 classifier and pre-push guard, check-active-task (task/focus/G-020 gates), budget-gate, verdict ledger, and the update-task close gates. The criteria: security-critical, stable spec, a large existing test suite, fires on every tool call.
  confidence: 1
  disposition: answered
  rationale: The GO scope is the round-1 consensus core: the Tier 0 classifier plus the pre-push guard, the broker/approval store, and ledger signing/verification custody (3 of 3 seats). The task/focus gate engine (2 of 3) and the budget/task-close gates (split) wait for the pilot's result (r1 synthesis D3).
- **IW-3: Does the pilot (the Tier 0 classifier on a real bash AST) close the self-approval and normalisation class as claimed?** Measure it against the existing ~170 Tier 0 tests plus every review probe from rounds 3-7, and compare latency.
  confidence: 1
  disposition: deferred
  rationale: This is what the pilot measures, so it cannot be known before running it. Its STOP conditions are fixed in advance (r1 synthesis, Consensus 3): any unapproved effect, replay or self-approval executes; the agent uid can write any enforcement path; any benign case T0-101..122 newly blocks; or an approval costs the operator more than one action compared with today.
- **IW-4: Distribution and consumers.** How does a compiled binary ship? Built per OS/arch at release, vendored into `.agentic-framework/`, or built on `fw upgrade`? What happens on hosts where it is missing (fail closed to the current bash path)? What does it mean for the P-01 installer and Windows/WSL?
  confidence: 1
  disposition: answered
  rationale: Signed, version-pinned artefacts (static per-OS/arch binaries), and a missing or mismatched component means DENY with no fallback to the legacy bash path (3 of 3 seats, r1 synthesis D4). This corrects the question's own "fail closed to the current bash path": the reviewers rejected a fallback because it reopens the class.
- **IW-5: Migration discipline.** One module at a time, the old and new paths run side by side with a parity check, the existing bats suites as the contract, and no big-bang rewrite.
  confidence: 2
  disposition: answered
  rationale: As stated: one module at a time, old and new paths side by side with a parity check, the existing bats suites as the contract, and no big-bang rewrite. Consistent with all three seats' pilot-first plan.

<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

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

Operator question 2026-10-01 after 7 Tier 0 review rounds. Evidence: every Tier 0 round found another shell expansion the hand-written matcher did not model (braces, line continuation, ANSI-C, quoting, normalisation) — a parsing problem a real AST closes as a class; and the bash-core failure catalogue in learnings (heredoc-in-$(…), backticks in python -c, set -e semantics, pipefail/SIGPIPE false reds, dead negations) is silent-failure-shaped (D2). Go gives a mature bash parser (shfmt's), a single static binary (D4, P-01 installer), strong typing and fast hook cold-start. Pilot scope is bounded by an existing executable spec (~170 Tier 0 tests). Open: language choice (Go vs Rust vs strict Python), module scope, migration and vendoring/distribution, consumer impact.

**What your GO adopts** (updated 2026-10-05 from the round-1 review, T-3896): a **pilot**, not a language migration. All three review seats put the boundary in configuration, not in a rewrite:
- a non-root agent uid;
- enforcement files the agent cannot write;
- the aef-govd broker holding approval state;
- server-side ref protection.

The pilot routes the Tier 0 approval path through the broker, with fixed STOP conditions (IW-3). The rest of the plan:
- Scope is the consensus core (IW-2).
- Delivery is signed and pinned, and a missing component means deny (IW-4).
- Migration is one module at a time (IW-5).
- The implementation language is decided by the pilot's parity experiment (IW-1, deferred), not by this GO.

**Evidence:**
- `docs/reports/T-3670-core-language.md` is the research artifact. `docs/reports/T-3670-context-pack.md` is the frozen pack given to the reviewers.
- `docs/reports/T-3670-r1-synthesis.md` covers round 1, three blind internal seats (OpenAI codex, Z.ai GLM via opencode, Anthropic claude -p):
  - consensus on architecture (D1), elevation (D5), the pilot and delivery (D4);
  - a split on language (D2).
- `docs/reports/T-3670-r1-{openai,zai,anthropic}.md` hold the individual answers. The question was reviewed before it was asked: `T-3670-qreview-*.md`.
- Seven Tier 0 review rounds, each finding another shell expansion the hand-written matcher did not model. That is a parsing class a real AST closes (motivation; see Rationale).

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

### 2026-10-01T17:37:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
