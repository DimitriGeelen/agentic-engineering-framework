---
id: T-2538
name: "Child-2 write-out mode: how do compiled BPMN skeletons become governed AEF
  tasks"
description: >
  Inception: Child-2 write-out mode: how do compiled BPMN skeletons become governed
  AEF tasks

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-13T07:59:26Z
last_update: 2026-07-13T08:00:57Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-07-13T08:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-07-13T08:00:09Z'
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
---

# T-2538: Child-2 write-out mode: how do compiled BPMN skeletons become governed AEF tasks

## Problem Statement

The Child-2 compiler prints task **skeletons** to stdout; you cannot *use* them without
hand-copying each block into `.tasks/active/`. Write-out mode would close that last-mile gap —
but the Core Principle ("nothing gets done without a task") is enforced *structurally* (task
gate, G-020 AC-readiness, T-ID allocation). A compiler writing straight into `.tasks/active/`
bypasses all of it. So the real question is not "emit a file" but "through what
governance-respecting contract does a diagram become governed tasks?" Full analysis:
`docs/reports/T-2538-writeout-mode-governance.md`.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Open Questions

- **IW-1: Which governance entry point does write-out use — direct write to `.tasks/active/`,
  drive `fw task create` per node, or staged proposals promoted through the gate?**
  confidence: 2
  disposition: answered
  rationale: Candidate C (staged proposals) — only option satisfying C1–C3 by construction;
  direct-write (A) violates the Core Principle's task gate. See artifact §Candidate approaches.

- **IW-2: What is the `aef:uid` ↔ `T-NNNN` mapping contract with 832 (reverse-map reads it)?**
  confidence: 1
  disposition: deferred
  rationale: JOINT contract (C4) — cannot decide unilaterally (T-559). Surfaced to 832 at rail
  offset 48. Gates the *promotion* slice only; the *staging* slice is uid-native and unblocked.

- **IW-3: How is idempotency on re-compile enforced so an edited diagram never duplicates tasks?**
  confidence: 2
  disposition: answered
  rationale: Upsert by `aef:uid` — IW-1 is exactly the modify/create discriminator (ratified
  v1.1). Staging manifest keyed by uid; re-compile updates in place. See artifact §Constraints C3.

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** the governance contract for turning compiled skeletons into governed tasks; the
candidate-approach analysis (direct / task-create / staged / script); the uid↔T-ID mapping
question; a go/no-go on *whether and how* to build write-out.
**OUT:** actually building write-out (that is the GO build slices); the reverse direction
(tasks→diagram, 832's); any read of 832's repo (T-559 — contract flows over the rail); a
Watchtower surface for staged proposals (a later slice if warranted).

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
- A governance-respecting entry point exists that satisfies C1–C3 by construction (no task-gate
  bypass, no fabricated ACs, idempotent by uid)
- The build is decomposable into a slice that is unblocked AEF-side and a slice cleanly gated on
  the 832 id-mapping contract

**NO-GO if:**
- Every viable entry point requires bypassing the task gate (Core Principle violation)
- The uid↔T-ID contract cannot be separated from the unblocked work (all-or-nothing on 832)

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

**Recommendation:** GO — build write-out mode as **staged proposals (candidate C)**, two slices.

**Rationale:**

The go/no-go on *whether and how* is answerable now. Candidate C (compiler writes uid-keyed
*proposals* to `.context/bpmn-staged/`; a `fw bpmn promote` step runs them through
`fw task create`) is the only approach that satisfies C1–C3 by construction: it never bypasses
the task gate (proposals aren't tasks until promoted — C1), never fabricates ACs (promotion
inherits the G-020 gate — C2), and is idempotent by `aef:uid` (IW-1, the modify/create
discriminator — C3). It reuses the Authority Model directly: the compiler *proposes*
(initiative), promotion is the *authorized* act (the gate). Candidate A (direct write) is a
NOT-GO — it is the exact Core-Principle bypass this inception exists to reject.

Only ONE sub-question is a genuine evidence gap: the uid↔T-ID mapping contract with 832 (IW-2),
which gates the *promotion* slice but NOT the *staging* slice. That is a question-level DEFER,
not a decision-level one (T-2144: DEFER is for evidence gaps, not confidence hedges) — so the
overall recommendation is GO, with the promotion slice explicitly gated on 832's rail reply.

**Slices on GO:**
1. **Staging (unblocked, AEF-only):** `--write` → uid-keyed proposals + manifest in
   `.context/bpmn-staged/`. Idempotent upsert. `target_blast_radius` ≈ 2 (one tool + a dir).
2. **Promotion (gated on IW-2):** `fw bpmn promote <uid|all>` → `fw task create`, records the
   uid↔T-ID cross-ref. Starts only after 832 confirms the id mapping (surfaced rail offset 48).

**Evidence:**
- Design analysis + candidate matrix: `docs/reports/T-2538-writeout-mode-governance.md`
- Core Principle / task gate: `CLAUDE.md` §Core Principle, §Working with Tasks (G-020)
- IW-1 stable identity (idempotency basis): shipped in `tools/bpmn_to_tasks.py:_find_uid`,
  byte-validated against 832's real corpus (T-2536)
- 832 contract dependency surfaced: rail `dm:0e7ee6cad65137fc:6a646ce8b1bc6560` offset 48

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

### 2026-07-13T08:00:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
