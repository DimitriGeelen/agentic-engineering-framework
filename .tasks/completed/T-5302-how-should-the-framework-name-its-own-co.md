---
id: T-5302
name: "How should the framework name its own commands (fw, watchtower) in vendored
  projects, so every printed remedy, page and hand-off runs as written, without path
  rewriting that keeps breaking?"
description: >
  Inception: How should the framework name its own commands (fw, watchtower) in vendored
  projects, so every printed remedy, page and hand-off runs as written, without path
  rewriting that keeps breaking?

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
waiting_on: agent
revisit_at: 2026-11-27
created: 2026-11-20T13:38:57Z
last_update: 2026-11-20T13:49:00Z
date_finished: 2026-11-20T13:49:00Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-11-20T13:39:09Z'
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
  - ts: '2026-11-20T13:45:46Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (target_blast_radius:inception-T-2189); tier=4 
      (workflow:inception); effort=6 (lines=142,acs=4)
    rubric_sha: e4a00f38e801
---

# T-5302: How should the framework name its own commands (fw, watchtower) in vendored projects, so every printed remedy, page and hand-off runs as written, without path rewriting that keeps breaking?

## Problem Statement

The framework prints commands for people and agents to run: fw doctor remedies, gate block messages, handover first actions, Watchtower pages, runme scripts. In the framework repo the path is `bin/fw`; in a vendored project it is `.agentic-framework/bin/fw`; on some hosts a `fw` shim is on PATH. Printed commands get this wrong repeatedly: GitHub #68 (fw doctor names `bin/watchtower.sh`, absent in a vendored project), T-609 and T-1257 (handoffs with the wrong path or no cd), T-1633 (fw upgrade depended on the developer's layout). The proposed #68 fix (`bin/fw`) is also not runnable at a vendored project's root. Operator, 2026-11-20: "the bin/fw ... in vendored projects is just really a crappy buggy artifact we still have because it's path rewriting and isolation we should have in the project ... bin/fw is screwing a lot of things up often"; asked for reflection, research (how vendored projects are built, how isolation should work, how Watchtower rewrites pages) and consultation. Research: docs/reports/T-5302-command-naming-vendored.md.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->
- The failures share one cause: each printer decides on its own how to spell the command, instead of one resolver.
- Vendored projects that consult us see the same class of failure.

## Open Questions

- **IW-1: Where does the framework print a command for someone to run, and how does each place spell `fw` today (count by spelling, framework repo vs vendored)?**
  confidence: 2
  disposition: answered
  rationale: report F3/F4: ~99 user-facing echo lines hard-code `bin/fw`; fw doctor "Run:" remedies 21 bare `fw`, 10 `bin/fw`, 2 `bin/watchtower.sh` (#68); 5 Watchtower templates and blueprint strings print `bin/fw`; handover "Regenerate in full: bin/fw task list"; /resume skill `bin/fw config get PORT` (832, 1409, ring20)
- **IW-2: What path rewriting and resolution already exist (fw path resolution in bin/fw, vendoring rewrites, Watchtower page rendering), and where do they disagree?**
  confidence: 3
  disposition: answered
  rationale: report F2/F3/F5: no rewriting at vendoring; the PATH router (T-2793) isolates at run time; `_fw_cmd` (lib/paths.sh) returns bare `fw` whenever any fw is on PATH, while Python `_fw()` (lib/delegation_cli.py, T-4250) never does; Watchtower runs fw by absolute path (T-3952) but prints literals
- **IW-3: What isolation should a vendored project have (what lives in the project, what in .agentic-framework/, what on PATH), and what should a printed command look like there?**
  confidence: 3
  disposition: answered
  rationale: framework bytes only under .agentic-framework/ (no root shim, 055's T-147 shim exists only to work around AEF's printing); a printed command must run from any folder and any shell without trusting PATH: `cd <absolute project root> && .agentic-framework/bin/fw ...` in a vendored project, `bin/fw` in the framework repo (all four peers; ring20 .122 still has the old fw-shim, 1409 measured non-login shells with another PATH)
- **IW-4: What do vendored projects (ring20, 055, 1409, 832, and the outside contributor) see break, and what would they want printed?**
  confidence: 3
  disposition: answered
  rationale: answers 055 375757be, 832 6e167fb8, 1409 be999d4b, ring20 eed8daaa in the report; all four rewrite printed `bin/fw` by hand or keep a shim; all want the resolved path with cd, bare `fw` only where the router is verified; 1409: "a function that builds the line instead of 99 literals"; 832: "one spelling per audience, documented". The outside contributor is not consulted (GitHub, operator's call).

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
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
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

One rule, one builder, used everywhere a command is printed for someone to run. The builder returns `cd <absolute project root> && <path to this project's fw> <args>`: `bin/fw` in the framework repo, `.agentic-framework/bin/fw` in a vendored project. It never prints bare `fw` and never `bin/watchtower.sh` (Watchtower is reached as `<fw> watchtower …`). The same builder serves people and agents (one spelling, documented, as 832 asked), because bare `fw` is not safe everywhere: ring20's host .122 still has the old fw-shim, not the router, and 1409 measured sessions and workers running without the login PATH. Nothing new goes into a vendored project's root (no shim): the isolation stays inside `.agentic-framework/`, and the run-time router (T-2793) stays as it is for people typing `fw` themselves. This fixes the cause the operator named: not one wrong line, but ~100 printers each spelling the command by hand, with Python and Watchtower keeping their own rules. Build slices: (1) the builder in shell (fix `_fw_cmd`, which today returns bare `fw` whenever any fw is on PATH) and Python, with a parity test, plus a Watchtower template global; `fw doctor` reports whether the PATH `fw` is the router, an old shim, or absent; (2) move the printers in bin/fw, lib/, agents/ to the builder (fw doctor remedies and gate messages first, including #68's two lines); (3) Watchtower templates and blueprint strings; (4) a lint that fails on a new hand-written `bin/fw` or `bin/watchtower.sh` in printed text (ratchet the rest); (5) skills, handover text and the consumer CLAUDE.md template. For #68: the contributor's PR becomes the first user of the builder (their two lines call it), so their answer is none of a, b, c as asked, but the resolved path through one function.

**Evidence:**

- Research F1-F6 in docs/reports/T-5302-command-naming-vendored.md: ~99 hard-coded `bin/fw` printers; `_fw_cmd` (lib/paths.sh) and Python `_fw()` (lib/delegation_cli.py) disagree; Watchtower prints literals; no rewriting at vendoring.
- All four vendored projects consulted (055 375757be, 832 6e167fb8, 1409 be999d4b, ring20 eed8daaa): each rewrites printed `bin/fw` by hand or keeps a root shim (055 T-147); all want the resolved path with `cd`; ring20 .122 has no router.
- Recurring incidents of this class: T-609, T-1257, T-1633, T-3952, T-4250 (ring20 G-235: 9 of 11 closes blocked), GitHub #68.

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

**Rationale**: One rule, one builder, used everywhere a command is printed for someone to run. The builder returns `cd <absolute project root> && <path to this project's fw> <args>`: `bin/fw` in the framework repo, `.agentic-framework/bin/fw` in a vendored project. It never prints bare `fw` and never `bin/watchtower.sh` (Watchtower is reached as `<fw> watchtower …`). The same builder serves people and agents (one spelling, documented, as 832 asked), because bare `fw` is not safe everywhere: ring20's host .122 still has the old fw-shim, not the router, and 1409 measured sessions and workers running without the login PATH. Nothing new goes into a vendored project's root (no shim): the isolation stays inside `.agentic-framework/`, and the run-time router (T-2793) stays as it is for people typing `fw` themselves. This fixes the cause the operator named: not one wrong line, but ~100 printers each spelling the command by hand, with Python and Watchtower keeping their own rules. Build slices: (1) the builder in shell (fix `_fw_cmd`, which today returns bare `fw` whenever any fw is on PATH) and Python, with a parity test, plus a Watchtower template global; `fw doctor` reports whether the PATH `fw` is the router, an old shim, or absent; (2) move the printers in bin/fw, lib/, agents/ to the builder (fw doctor remedies and gate messages first, including #68's two lines); (3) Watchtower templates and blueprint strings; (4) a lint that fails on a new hand-written `bin/fw` or `bin/watchtower.sh` in printed text (ratchet the rest); (5) skills, handover text and the consumer CLAUDE.md template. For #68: the contributor's PR becomes the first user of the builder (their two lines call it), so their answer is none of a, b, c as asked, but the resolved path through one function.

**Date**: 2026-11-20T13:48:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-11-20T13:39:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-20T13:48:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** One rule, one builder, used everywhere a command is printed for someone to run. The builder returns `cd <absolute project root> && <path to this project's fw> <args>`: `bin/fw` in the framework repo, `.agentic-framework/bin/fw` in a vendored project. It never prints bare `fw` and never `bin/watchtower.sh` (Watchtower is reached as `<fw> watchtower …`). The same builder serves people and agents (one spelling, documented, as 832 asked), because bare `fw` is not safe everywhere: ring20's host .122 still has the old fw-shim, not the router, and 1409 measured sessions and workers running without the login PATH. Nothing new goes into a vendored project's root (no shim): the isolation stays inside `.agentic-framework/`, and the run-time router (T-2793) stays as it is for people typing `fw` themselves. This fixes the cause the operator named: not one wrong line, but ~100 printers each spelling the command by hand, with Python and Watchtower keeping their own rules. Build slices: (1) the builder in shell (fix `_fw_cmd`, which today returns bare `fw` whenever any fw is on PATH) and Python, with a parity test, plus a Watchtower template global; `fw doctor` reports whether the PATH `fw` is the router, an old shim, or absent; (2) move the printers in bin/fw, lib/, agents/ to the builder (fw doctor remedies and gate messages first, including #68's two lines); (3) Watchtower templates and blueprint strings; (4) a lint that fails on a new hand-written `bin/fw` or `bin/watchtower.sh` in printed text (ratchet the rest); (5) skills, handover text and the consumer CLAUDE.md template. For #68: the contributor's PR becomes the first user of the builder (their two lines call it), so their answer is none of a, b, c as asked, but the resolved path through one function.

### 2026-11-20T13:49:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7ef8d129
- **Timestamp:** 2026-11-20T13:49:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-1
     - evidence: `IW-1 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`
  2. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-fcad5b99
- **Timestamp:** 2026-11-20T13:49:03Z
- **Overall:** CONFIRMED
- **Claims:** 8

| Claim | Type | Status |
|-------|------|--------|
| `bin/watchtower.sh` | file | ✓ pass |
| `T-2793` | task | ✓ pass |
| `T-147` | task | ✓ pass |
| `T-609` | task | ✓ pass |
| `T-1257` | task | ✓ pass |
| `T-1633` | task | ✓ pass |
| `T-3952` | task | ✓ pass |
| `T-4250` | task | ✓ pass |
