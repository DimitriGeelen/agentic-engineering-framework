---
id: T-2703
name: "Greenfield seeding emits tasks that fail the framework's own audit (CTL-027
  + missing Updates)"
description: >
  Inception: Greenfield seeding emits tasks that fail the framework's own audit (CTL-027
  + missing Updates)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-31T11:09:08Z
last_update: '2026-07-31T11:15:06Z'
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
  - ts: '2026-07-31T11:12:26Z'
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
  - ts: '2026-07-31T11:15:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2703: Greenfield seeding emits tasks that fail the framework's own audit (CTL-027 + missing Updates)

## Problem Statement

`fw init` in greenfield mode seeds `.tasks/active/T-001..T-005` from
`lib/seeds/tasks/greenfield/*.md`, a hardcoded template set separate from
`.tasks/templates/{default,inception}.md`. Seeded T-002 (`workflow_type:
inception`) has no `## Recommendation` / `## Decision` sections, and
T-002..T-005 have no `## Updates` section. `fw audit`'s CTL-027 control
(added by T-1263, 2026-04-25) hard-FAILs on the missing inception sections;
T-001's own `## Verification` block runs `fw audit; test $? -le 1`, so a
fresh install fails its own first onboarding gate before an agent has done
any work. Full RCA, reproduction, candidate fixes and a proved-RED prevention
test are in `docs/reports/T-2703-greenfield-seed-audit-failure.md`.

## Assumptions

- Confirmed: the seed templates (`lib/seeds/tasks/greenfield/T-002-*.md`) are
  a separate, hardcoded copy — not derived from `.tasks/templates/inception.md`
  — and have not been touched since their sole authoring commit (T-460,
  2026-03-13), i.e. never updated when CTL-027 landed 6+ weeks later.
- Confirmed: only CTL-027 produces the hard FAIL (exit 2); missing-`## Updates`
  and template-only-Recommendation are WARN-only and would not alone block
  T-001's Verification gate.
- Confirmed: no existing test (`upgrade_fresh_machine_simulation.bats`,
  `tests/e2e/onboarding-test.sh`) runs `fw audit` against a freshly seeded
  project — the gate that should have caught this drift does not exist.

## Open Questions

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

- **IW-1: Which layer owns the fix — seed templates, a shared template source with `.tasks/templates/`, CTL-027 scope, or T-001's Verification block?**
  confidence: 3
  disposition: answered
  rationale: RCA complete (docs/reports/T-2703-greenfield-seed-audit-failure.md §2-4). Recommend (a) patch seed templates now + (b) derive-from-templates as a follow-on build task; reject CTL-027 scope changes and reject weakening T-001's Verification.

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

RCA complete and reproduced independently of /opt/2026-Mehdi-demo (fresh seed
in a throwaway scratch dir). Root cause: two unsynchronized sources of truth
for inception task section-structure (`.tasks/templates/inception.md` vs
`lib/seeds/tasks/greenfield/T-002-*.md`), the latter untouched since its
authoring commit (T-460, 2026-03-13) despite CTL-027 landing 6+ weeks later
(T-1263, 2026-04-25) and requiring exactly the sections it lacks. No test
exercises `fw audit` against a freshly seeded project, so the drift was
invisible for 3+ months. Recommend: (a) patch the seed templates to add the
missing sections now (small, safe, fixes the live FAIL); (b) scope a follow-on
build task to derive seeds from `.tasks/templates/` so this class cannot
recur; reject changing CTL-027's scope (hides the failure, `fw inception
decide` genuinely needs those sections) and reject weakening T-001's
Verification gate (removes the only signal a fresh install is broken). Full
detail: `docs/reports/T-2703-greenfield-seed-audit-failure.md`.

**Evidence:**

- Reproduced live: fresh `fw init` in a scratch dir → `fw audit` exits 2,
  `CTL-027: Inception T-002 missing required sections: ## Recommendation,
  ## Decision` (docs/reports/T-2703-greenfield-seed-audit-failure.md §1).
- `git log --follow` on `lib/seeds/tasks/greenfield/T-002-define-project-goals.md`
  shows exactly one commit ever (`4e70ce9bf`, T-460, 2026-03-13) — never
  updated since, including after CTL-027 (T-1263, `95b1449e9`, 2026-04-25).
- `.tasks/templates/inception.md` already has `## Recommendation` /
  `## Decisions` / `## Decision` / `## Updates` — the canonical producer
  (`fw task create --type inception`) is unaffected; only the `fw init`
  greenfield seed producer diverges.
- Prevention prototype written and proved RED:
  `tests/unit/greenfield_seed_audit_prototype.bats` — seeds via real `fw init`,
  runs the seed's own vendored `fw audit`, asserts exit `<= 1`; currently
  fails with `audit exit: 2` against the unfixed seed.

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

### 2026-07-31T11:12:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
