---
id: T-2770
name: "should a read-only fw query auto-init and vendor into cwd at all?"
description: >
  Split out of T-2769. When fw runs non-interactively in a directory that is not a
  framework project, bin/fw:534 silently runs do_init on $PWD and vendors the framework
  there, then re-execs. So a read-only query — fw orchestrator status --json — CREATES
  a project and writes a vendored copy into the caller's cwd. T-2769 fixes the stream
  (banner off stdout) but deliberately does NOT decide whether the side effect itself
  is right, because that is a behaviour change with consumer blast radius. Questions:
  (1) which callers actually rely on scripted auto-init (T-519 moved vendor before
  auto-init for some reason — find it); (2) should read-only verbs (status, list,
  show, doctor, version) be exempt; (3) should an explicitly-set PROJECT_ROOT that
  lacks markers be honoured rather than discarded as stale (bin/fw:185), which is
  what routes the test harness into this branch in the first place.

status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-08-03T16:51:01Z
last_update: 2026-09-24T18:52:17Z
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
  - ts: '2026-08-03T17:00:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T17:00:12Z'
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

# T-2770: should a read-only fw query auto-init and vendor into cwd at all?

## Problem Statement

<!-- What problem are we exploring? For whom? Why now? -->

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

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

Filed 2026-09-24 (autonomous run) before any research, at the G-067 gate's insistence —
its ordering is better than the one I started with: declare the questions, then measure.

- **IW-1: Does the vendor-before-auto-init ordering (T-519) encode a requirement that
  auto-init must be able to vendor, or is it an artefact?**
  confidence: 3
  disposition: answered
  rationale: artefact. `bin/fw:470-472` and T-519's own Context — `do_vendor()` was called
  by `do_init` before it was defined in the file; a bash function-ordering bug, no policy
  intent. Nothing rides on the ordering.

- **IW-2: Which callers actually rely on scripted (non-TTY) auto-init — i.e. would break
  if a known read-only verb stopped initialising?**
  confidence: 3
  disposition: answered
  rationale: none in this repository, and the one caller that reached it was harmed —
  `tests/unit/install_verify_no_cwd_init.bats:1-12` records a live incident measured
  against GitHub master 2026-08-04 where the documented `curl | bash` install ran
  `fw doctor`, hit this branch under a non-TTY pipe, and seeded a full project into the
  user's cwd behind a green checkmark. T-2799 fixed the CALLER (`install.sh:456,461`), not
  the branch. `fw_help_no_autoinit.bats:76` pins the branch firing, but as a discriminating
  control against vacuous passes, not as a dependency. Consumer projects unsearched (T-559).

- **IW-3: Is an exclusion list the right mechanism, and does one already exist?**
  confidence: 3
  disposition: answered
  rationale: it already exists and already contains read-only verbs — `bin/fw:987-991`
  excludes `init`, `help`/`-h`/`--help`, `version`/`-v`/`--version`, `update`, `hook`,
  `vendor`, plus any `--help` query, and T-2835 added `_fw_cmd_is_known`. The live question
  is which verbs belong on the existing list, not whether to build one.

- **IW-4: What does a caller lose if a read-only verb refuses instead of initialising?**
  confidence: 3
  disposition: answered
  rationale: nothing that is not already lost. Since T-2835 an unknown verb from a
  non-project directory already refuses with a clear error rather than bootstrapping, so
  the alternative behaviour is built, shipped, and already the norm for the neighbouring
  case. The user gets an error naming `fw init` instead of an unrequested ~27 MB tree.

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

**Recommendation:** GO — narrow, not remove

*(Supersedes the DEFER of 2026-08-03, which was correct when written: it named an evidence
gap, and the gap is now closed. Research: `docs/reports/T-2770-readonly-auto-init.md`.)*

**Rationale:** The evidence the DEFER waited for existed in this repository the whole time.
Three findings, each reversing part of the original framing:

1. **The mechanism already exists.** `bin/fw:987-991` already excludes `init`, `help`,
   `version`, `update`, `hook`, `vendor` and help queries — read-only verbs among them. This
   is a list edit, not a redesign.
2. **The ordering that looked load-bearing is an artefact.** T-519 moved `do_vendor` earlier
   because a bash function was called before it was defined (`bin/fw:470-472`, T-519's
   Context). No policy intent rides on it.
3. **No caller relies on this; the one that reached it was harmed.**
   `tests/unit/install_verify_no_cwd_init.bats:1-12` records a live incident measured
   against GitHub master on 2026-08-04: the documented `curl | bash` install ran `fw doctor`,
   hit this branch under a non-TTY pipe, and **seeded a complete project into whatever
   directory the user was standing in**, behind a green "Step 3/3 passes" checkmark. T-2799
   fixed the caller (`install.sh:456,461`), leaving the branch intact for every other caller.

Counter-evidence was sought. `tests/unit/fw_help_no_autoinit.bats:76` asserts the branch
still fires — but as a discriminating control so the help-exclusion tests cannot pass
vacuously, not as a dependency. It would be re-pointed at a write verb, a test edit.

**Proposal:** add the read-only query verbs (`status`, `list`, `show`, `doctor`, …) to the
existing exclusion list. Keep auto-init for write verbs, where a caller plausibly means
"set this up". Keep the interactive dialogue untouched — a human at a prompt is asked, not
surprised. Since T-2835 the refusal path (a clear error naming `fw init`) is already built
and already the norm for unknown verbs, so nothing new is needed to fall back to.

**Evidence:**
- `docs/reports/T-2770-readonly-auto-init.md` — full research artefact, findings §1–§4,
  recommendation and build slices §5.
- Live-incident record: `tests/unit/install_verify_no_cwd_init.bats:1-12` (T-2799).
- Prior narrowings that explicitly deferred this question: T-2769, T-2835 — both say so in
  code comments at `bin/fw:977` and `bin/fw:995-1010`.
- All four IW questions now `disposition: answered`, confidence 3.

**What is still unknown, stated plainly:** consumer projects were **not** searched for
reliance on scripted auto-init. The project-boundary gate (T-559) refuses that from this
session, and a per-project read-only census is a separate, larger unit. So the finding is
"no evidence of reliance in this repository, and unsearched elsewhere" — which is why the
go/no-go stays the operator's, and why the recommendation is to narrow rather than remove.

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

### 2026-09-24T18:52:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
