---
id: T-2995
name: "cross-project dispatch containment: the boundary hook routes agents to the
  ungated write path"
description: >
  Inception: cross-project dispatch containment: the boundary hook routes agents to
  the ungated write path

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-08-14T19:21:01Z
last_update: 2026-08-15T05:20:04Z
date_finished: 2026-08-15T05:20:04Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-14T19:22:26Z'
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
  - ts: '2026-08-14T19:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2995: cross-project dispatch containment: the boundary hook routes agents to the ungated write path

## Problem Statement

Reported by a peer session in consumer project 001-CashWeb (AEF v1.6.212).
Full analysis: `docs/reports/T-2995-cross-project-dispatch-containment.md`.

`check-project-boundary` (T-559) blocks every cross-project **read** — `ls
/opt/`, even invoking a binary by absolute path. Its block message then
prescribes the remedy:

> For legitimate cross-project work, use TermLink dispatch which runs the
> command in the target project's own session context […] Neither path crosses
> the boundary of *this* session; each target project enforces its own
> governance in its own process.

That last claim is conditional on the target being a governed AEF project, and
nothing verifies it. Tracing `--project` through `agents/termlink/termlink.sh`:
parsed at 514, defaulted to `$(pwd)` at 617, embedded in the envelope at 717,
handed to the worker at 923 — and first touched at 742, `cd "$PROJECT_DIR" ||
FATAL`, which is **after** spawn, inside the target.

So reads are gated, writes are not, and the guard names the ungated path.

**The luck was narrower than the reporter thought.** Their incident failed safe
because the path did not exist. A path that *exists but is not an AEF project*
is the dangerous case: `cd` succeeds, `claude -p --permission-mode acceptEdits`
runs, and with no `.claude/settings.json` there are **no hooks at all** — no
task gate, no Tier 0, no boundary hook, no budget gate. The guarantee inverts
exactly where it matters.

## Assumptions

- **A1** — the target-enforces-its-own-governance claim is unverified before
  spawn. *Confirmed: no existence or AEF-ness check on any path.*
- **A2** — an ungoverned-but-existing target is the real hazard, not a
  missing one. *Confirmed by construction: hooks load from the target's
  `.claude/settings.json`, which an ungoverned directory lacks.*
- **A3** — the fix is bounded and does not require redesigning dispatch.
  *Holds: a precondition check at one call site, before spawn.*

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

- **IW-1: Does `fw termlink dispatch --project <path>` verify the target exists and is a governed AEF project before spawning a worker?**
  confidence: 3
  disposition: answered
  rationale: No validation anywhere: parsed at termlink.sh:514, defaulted to pwd at 617, embedded at 717, handed to the worker at 923; `cd` fails only at 742 — after spawn, inside the target.
- **IW-2: Is the boundary hook's prescribed remedy (dispatch) genuinely less contained than the read it blocks — i.e. is the asymmetry real?**
  confidence: 3
  disposition: answered
  rationale: Real, and sharper than reported: reads blocked at check-project-boundary.sh:386, writes unvalidated, and the block message names the write path as the sanctioned remedy.
- **IW-3: Should `--permission-mode acceptEdits` + a `--project` outside the current root require Tier 0/2 approval rather than being a plain flag?**
  confidence: 2
  disposition: answered
  rationale: Plain passthrough (T-2282: parsed 532-541, permission_mode.txt 676-679, flag rebuilt 795-796). No tier interaction with an out-of-root --project today.
- **IW-4: Is the `--task` requirement resolvable without forcing a foreign-work task into the dispatching project's `.tasks/`?**
  confidence: 1
  disposition: answered
  rationale: Tension is real (P-002 reads the dispatcher, the authorising task belongs to the target) but the design choice is open — split to its own task, must not block the Finding 1 fix.
- **IW-5: Of the four side findings (G-006 seed assertion, G-007 claude-fw drift FP, G-008 merge-commit traceability, T-2036 close-deadlock), which are upstream-owned and which are the consumer's?**
  confidence: 2
  disposition: answered
  rationale: All four upstream-owned if the claims hold (seeds, doctor, audit metrics, task lifecycle — none durably fixable by a consumer). T-2036 confirmed here; G-006/7/8 remain first-read, reported against v1.6.212 vs our 1.6.227.
## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

**IN:** Finding 1 — validate `--project` before spawn, and stop the boundary
hook advertising an unvalidated path as the sanctioned remedy.

**OUT, each to its own task if GO'd** (deliberately, so a containment fix does
not wait on a design debate):
- Finding 2 — `--task` resolving in the dispatching project (modelling
  question: `.context/dispatches/` record vs foreign-target task type).
- Finding 1b — whether `acceptEdits` + out-of-root `--project` should raise a
  tier. Depends on the Finding 1 fix landing first; may be moot once an
  ungoverned target is refused outright.
- G-006 / G-007 / G-008 — reported against v1.6.212, this repo is 1.6.227.
  Plausible and upstream-owned, but not accepted on report; each needs
  verification against current source.
- T-2036 close-deadlock — confirmed reproduced here (see report §Finding 3),
  but it is a task-lifecycle problem, not a dispatch one.

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

**Recommendation:** GO — validate `--project` before spawn (Finding 1 only)

**Rationale:**

Re-filed from DEFER. The DEFER was honest — I had not read the source. Having
read it, the report holds and understates the hazard.

**The report is correct.** No existence check, no AEF-ness check, at any point
between `--project` being parsed and the worker `cd`-ing into the target. The
guard's promise — "each target project enforces its own governance in its own
process" — is asserted, never verified.

**It understates it in one specific way.** The reporter attributes the safe
outcome to luck because the worker died. The luck is narrower: their path did
not *exist*. The dangerous case is a path that exists and is not an AEF
project — `cd` succeeds, `acceptEdits` runs, and with no `.claude/settings.json`
**no hooks load at all**. The guarantee is not merely unverified there; it is
false, and that is the case a precondition check must catch. Nothing today
distinguishes the two before spawn.

**Why GO rather than more care at the call site.** The reporter names their own
error plainly (inferred the target from transcript directory names, proceeded
after writing the concern down instead of stopping). That is exactly the
failure agents make under an off-topic request, and it is what the boundary
hook exists to catch — it caught every *read* and then handed over the write
path. Asking agents to be more careful is the remedy that already failed here.

**Scoped to Finding 1 alone, deliberately.** Finding 2 (`--task` resolving in
the dispatching project) is a real tension but a modelling question, and
bundling it would make a containment fix wait on a design debate. Same for
whether `acceptEdits` should raise a tier — that may be moot once an ungoverned
target is refused outright. Splitting is a judgement, not the reporter's
request; they asked for one RCA on Findings 1 and 2 together.

**What I am not asserting.** G-006/G-007/G-008 are recorded as plausible and
first-read only. They were reported against v1.6.212 against our 1.6.227, and a
careful, well-evidenced report is precisely the kind one is tempted to accept
without checking. Each needs its own task and verification against current
source. T-2036 I *am* asserting — it reproduced here while writing this up.

**Evidence:**

- `agents/context/check-project-boundary.sh:386` — the block message naming
  dispatch as the remedy, and the "enforces its own governance" claim
- `agents/termlink/termlink.sh` — `--project` parsed 514, defaulted 617,
  embedded 717, handed to worker 923; `cd … || FATAL` at 742, post-spawn
- `--permission-mode` passthrough (T-2282): 532-541, 676-679, 795-796 — no
  tier interaction with an out-of-root target
- T-2036 reproduced in this repo: five gates in sequence to commit T-2994's own
  close artifacts (report §Finding 3)
- Reporter's incident: `FATAL: cd /opt/2345-test-install failed`, zero writes
- Research: `docs/reports/T-2995-cross-project-dispatch-containment.md`

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

**Rationale**: Recommendation: GO — validate `--project` before spawn (Finding 1 only)

Rationale:

Re-filed from DEFER. The DEFER was honest — I had not read the source. Having
read it, the report holds and understates the hazard.

The report is correct. No existence check, no AEF-ness check, at any point
between `--project` being parsed and the worker `cd`-ing into the target. The
guard's promise — "each target project enforces its own governance in its own
process" — is asserted, never verified.

It understates it in one specific way. The reporter attributes the safe
outcome to luck because the worker died. The luck is narrower: their path did
not exist. The dangerous case is a path that exists and is not an AEF
project — `cd` succeeds, `acceptEdits` runs, and with no `.claude/settings.json`
no hooks load at all. The guarantee is not merely unverified there; it is
false, and that is the case a precondition check must catch. Nothing today
distinguishes the two before spawn.

Why GO rather than more care at the call site. The reporter names their own
error plainly (inferred the target from transcript directory names, proceeded
after writing the concern down instead of stopping). That is exactly the
failure agents make under an off-topic request, and it is what the boundary
hook exists to catch — it caught every read and then handed over the write
path. Asking agents to be more careful is the remedy that already failed here.

Scoped to Finding 1 alone, deliberately. Finding 2 (`--task` resolving in
the dispatching project) is a real tension but a modelling question, and
bundling it would make a containment fix wait on a design debate. Same for
whether `acceptEdits` should raise a tier — that may be moot once an ungoverned
target is refused outright. Splitting is a judgement, not the reporter's
request; they asked for one RCA on Findings 1 and 2 together.

What I am not asserting. G-006/G-007/G-008 are recorded as plausible and
first-read only. They were reported against v1.6.212 against our 1.6.227, and a
careful, well-evidenced report is precisely the kind one is tempted to accept
without checking. Each needs its own task and verification against current
source. T-2036 I am asserting — it reproduced here while writing this up.

Evidence:

- `agents/context/check-project-boundary.sh:386` — the block message naming
  dispatch as the remedy, and the "enforces its own governance" claim
- `agents/termlink/termlink.sh` — `--project` parsed 514, defaulted 617,
  embedded 717, handed to worker 923; `cd … || FATAL` at 742, post-spawn
- `--permission-mode` passthrough (T-2282): 532-541, 676-679, 795-796 — no
  tier interaction with an out-of-root target
- T-2036 reproduced in this repo: five gates in sequence to commit T-2994's own
  close artifacts (report §Finding 3)
- Reporter's incident: `FATAL: cd /opt/2345-test-install failed`, zero writes
- Research: `docs/reports/T-2995-cross-project-dispatch-containment.md`

**Date**: 2026-08-15T05:20:04Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-14T19:22:25Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-15T05:20:04Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — validate `--project` before spawn (Finding 1 only)

Rationale:

Re-filed from DEFER. The DEFER was honest — I had not read the source. Having
read it, the report holds and understates the hazard.

The report is correct. No existence check, no AEF-ness check, at any point
between `--project` being parsed and the worker `cd`-ing into the target. The
guard's promise — "each target project enforces its own governance in its own
process" — is asserted, never verified.

It understates it in one specific way. The reporter attributes the safe
outcome to luck because the worker died. The luck is narrower: their path did
not exist. The dangerous case is a path that exists and is not an AEF
project — `cd` succeeds, `acceptEdits` runs, and with no `.claude/settings.json`
no hooks load at all. The guarantee is not merely unverified there; it is
false, and that is the case a precondition check must catch. Nothing today
distinguishes the two before spawn.

Why GO rather than more care at the call site. The reporter names their own
error plainly (inferred the target from transcript directory names, proceeded
after writing the concern down instead of stopping). That is exactly the
failure agents make under an off-topic request, and it is what the boundary
hook exists to catch — it caught every read and then handed over the write
path. Asking agents to be more careful is the remedy that already failed here.

Scoped to Finding 1 alone, deliberately. Finding 2 (`--task` resolving in
the dispatching project) is a real tension but a modelling question, and
bundling it would make a containment fix wait on a design debate. Same for
whether `acceptEdits` should raise a tier — that may be moot once an ungoverned
target is refused outright. Splitting is a judgement, not the reporter's
request; they asked for one RCA on Findings 1 and 2 together.

What I am not asserting. G-006/G-007/G-008 are recorded as plausible and
first-read only. They were reported against v1.6.212 against our 1.6.227, and a
careful, well-evidenced report is precisely the kind one is tempted to accept
without checking. Each needs its own task and verification against current
source. T-2036 I am asserting — it reproduced here while writing this up.

Evidence:

- `agents/context/check-project-boundary.sh:386` — the block message naming
  dispatch as the remedy, and the "enforces its own governance" claim
- `agents/termlink/termlink.sh` — `--project` parsed 514, defaulted 617,
  embedded 717, handed to worker 923; `cd … || FATAL` at 742, post-spawn
- `--permission-mode` passthrough (T-2282): 532-541, 676-679, 795-796 — no
  tier interaction with an out-of-root target
- T-2036 reproduced in this repo: five gates in sequence to commit T-2994's own
  close artifacts (report §Finding 3)
- Reporter's incident: `FATAL: cd /opt/2345-test-install failed`, zero writes
- Research: `docs/reports/T-2995-cross-project-dispatch-containment.md`

## Reviewer Verdict (v1.5)

- **Scan ID:** R-735cbec5
- **Timestamp:** 2026-08-15T05:20:05Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-4
     - evidence: `IW-4 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-594413bf
- **Timestamp:** 2026-08-15T05:20:05Z
- **Overall:** CONFIRMED
- **Claims:** 7

| Claim | Type | Status |
|-------|------|--------|
| `.claude/settings.json` | file | ✓ pass |
| `agents/context/check-project-boundary.sh:386` | file_line | ✓ pass |
| `agents/termlink/termlink.sh` | file | ✓ pass |
| `docs/reports/T-2995-cross-project-dispatch-containment.md` | file | ✓ pass |
| `T-2036` | task | ✓ pass |
| `T-2282` | task | ✓ pass |
| `T-2994` | task | ✓ pass |

### 2026-08-15T05:20:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
