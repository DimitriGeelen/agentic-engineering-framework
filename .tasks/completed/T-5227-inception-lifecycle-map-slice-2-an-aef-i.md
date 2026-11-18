---
id: T-5227
name: "Inception lifecycle map (slice 2): an aef-inception-lifecycle designer map;
  each inception an instance with current step and entered_at; waiting steps (agent
  / peer / operator) carry revisit dates that drive a daily routing (handover, peer
  reminder, fw operator pending + Watchtower approvals); time-in-step measured"
description: >
  Operator rulings 2026-11-18 on question 2 (EXPLORING; options A and 1; follow-up
  option 1: inception map with instances). See fw decisions.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/audit/audit.sh, agents/context/check-inception-schema.py, agents/context/revisit-due-scan.sh, agents/handover/handover.sh, agents/task-create/create-task.sh, lib/inception.sh, lib/render_task.py, tools/corpus_overlay.py, web/blueprints/approvals.py, web/blueprints/designer_api.py, web/templates/_approvals_content.html]
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-11-18T12:14:14Z
last_update: 2026-11-18T22:10:21Z
date_finished: 2026-11-18T22:10:21Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
cost_estimate_proposed:
  - ts: '2026-11-18T12:30:40Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=302,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-18T12:31:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-5227: Inception lifecycle map (slice 2): an aef-inception-lifecycle designer map; each inception an instance with current step and entered_at; waiting steps (agent / peer / operator) carry revisit dates that drive a daily routing (handover, peer reminder, fw operator pending + Watchtower approvals); time-in-step measured

## Context

<!-- All four parts are required before source edits (T-4907). Plain language; link design docs for substantial tasks. -->
**Background / trigger:** Operator rulings 2026-11-18 on question 2 (see `fw decisions`):
- EXPLORING inceptions name what they wait for (agent / peer / operator) and a revisit date (default 7 days).
- A daily check routes overdue ones.
- The follow-up ruling (option 1): build this as an inception lifecycle map (the class) with each inception as an instance, using the dates as triggers and measurements.

Slice 1 (T-5226) shipped the EXPLORING state. The task lifecycle already has this model: the designer map `.context/designer/projects/aef-task-lifecycle/`, and `GET /api/instances` (web/blueprints/designer_api.py, T-4831, with one status→node table and runtime projection v2 in T-5193).

**Problem / hypothesis:** About 71 open inceptions have no recorded "waiting on whom / until when". Nothing moves an undecided one forward, and nothing measures how long inceptions sit in each step.

**Goal:** Every open inception is an instance on an inception lifecycle map, with an owner for its next step and a date.
- **Map.** A designer map `aef-inception-lifecycle` with these state nodes:
  - exploring, waiting on the agent;
  - exploring, waiting on a peer;
  - exploring, waiting on the operator;
  - ready for a recommendation;
  - awaiting the operator's decision;
  - decided GO, with build tasks open;
  - decided NO-GO or DEFER;
  - closed.
  It validates with the existing corpus validator and follows the shared contract with 832 (contracts v2; no new contract fields).
- **Instance fields** (frontmatter, inceptions only): `waiting_on: agent|peer|operator` and `revisit_at: YYYY-MM-DD` (default filing date + 7). The entered-at time of each step comes from the status/recommendation history already in the task file, or a recorded `step_entered_at`.
- **Instances.** `GET /api/instances?template=aef-inception-lifecycle` returns each open inception on its node, with entered_at and revisit_at, through one table like the task map's. An inception that cannot be placed comes back as NO-POSITION, the same as for tasks.
- **Daily routing.** A daily check (audit section plus handover) lists each overdue inception under its owner:
  - agent: in the handover's next actions;
  - peer: an item for the agent to remind that peer (the agent sends it, not a cron);
  - operator: in `fw operator pending` and on the approvals page as "questions waiting for you" (no decide link).
- **Measurement.** `fw inception lifecycle [--json]` prints, per node, the count, the median days in step and the overdue count.
- **Docs.** The lifecycle section of 050-Inceptions.md describes the map, the fields and the routing.

**Expected outcome:** Every open inception has a visible place on the map, an owner for the next step and a date. Overdue ones come back to whoever owns them, and time-in-step is measurable.

## Acceptance Criteria

### Agent
- [x] The map `aef-inception-lifecycle` exists under .context/designer/projects/, validates with the corpus validator, and its node set matches the Goal
- [x] `waiting_on` / `revisit_at` are accepted on inceptions (filing paths default revisit_at to +7 days; invalid values refused) and rejected on non-inceptions (tests)
- [x] `/api/instances?template=aef-inception-lifecycle` places fixture inceptions in each node, gives NO-POSITION for an unplaceable one, and conforms to runtime-projection v2 (tests reuse the T-5185/T-5193 schema checks)
- [x] The daily check lists overdue inceptions by owner: agent → handover; peer → reminder item for the agent; operator → `fw operator pending` and the approvals page, with no decide link (tests)
- [x] `fw inception lifecycle --json` gives per-node counts, the median days in step and overdue counts (test with fixtures)
- [x] 050-Inceptions.md is updated. Existing designer, instances, runtime-projection, inception and approvals suites pass, as do `bin/fw test invariants` and `bin/fw vendor self --check --task T-5227`. Watchtower is restarted and `bin/fw watchtower current` passes.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

<!-- T-4906: guidance is an HTML comment so GitHub does not render its `#` lines as
     headings; the completion gate strips HTML comments before running anything.
     Write your commands BELOW this comment, one per line.
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture with a HERE-STRING:
#     out=$(cmd 2>&1); grep -q "PATTERN" <<<"$out"
# No pipe, so no SIGPIPE at any size. Do NOT write `echo "$out" | grep -q PAT`:
# it is not safe "below 64 KB" as this file used to say (T-4921, 832 T-1340). The
# builtin writes a multi-line value line by line, so grep -q can exit before the
# last write at ANY size (measured 4 in 3,000 for a 40-line value), and above the
# pipe buffer it fails every time (T-2743: 146,366-byte page, 3/3). In a gate that
# allows on "no match" that is a fail-OPEN (T-4920: the Tier 0 pre-filter).
# The capture still discards cmd's exit code, so a 404 yields an empty capture that
# grep merely fails to match rather than a failed line — prefer THE DEFAULT above.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); grep -q passed <<<"$out" && ! grep -q failed <<<"$out"
#     out=$(bats <file> 2>&1); grep -q '^ok 1 ' <<<"$out" && ! grep -q '^not ok' <<<"$out"
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
-->
python3 -m pytest tests/unit/test_t5227_inception_lifecycle.py -q > /tmp/.t5227.out 2>&1 && grep -q passed /tmp/.t5227.out
python3 -m pytest tests/unit/test_t5193_runtime_projection_v2.py tests/unit/test_t5185_runtime_projection.py tests/unit/test_corpus_overlay.py tests/unit/t4095_operator_pending_test.py -q > /tmp/.t5227b.out 2>&1 && grep -q passed /tmp/.t5227b.out
bin/fw corpus validate aef-inception-lifecycle
timeout 600 bats tests/unit/t5221_create_batch.bats > /tmp/.t5227c.out 2>&1 && ! grep -q "^not ok" /tmp/.t5227c.out
test "$(grep -c '# skip' /tmp/.t5227c.out)" -eq 0
bin/fw inception lifecycle --json > /tmp/.t5227d.out 2>&1 && grep -q '"median_days_in_step"' /tmp/.t5227d.out
bin/fw vendor self --check --task T-5227
bin/fw watchtower current

## Visual Verification

Shots: `fw ux shots T-5227 inception-map=http://192.168.10.107:3000/designer/overlay?id=aef-inception-lifecycle`
(`.context/visual/T-5227/inception-map@{1024,1440,1920}.png`), plus the instance picker with one
inception chosen (`.context/visual/T-5227/instance-picked.png`, Playwright `selectOption`, which
`fw ux shots` steps cannot do).

| state | control | 1024 | 1440 | 1920 | note |
|-------|---------|------|------|------|------|
| inception-map | map steps and lanes (agent / peer / operator) | ok | ok | ok | the three waiting steps sit in three lanes |
| inception-map | instance picker (`instances:` dropdown) | ok | ok | ok | lists 129 inceptions as "T-XXXX · node · status"; one is placed at a time |
| inception-map | per-step count badges / overdue alert | hidden | hidden | hidden | the overlay payload is served (GET /api/overlay, overdue = alert) but the pinned 832 bundle does not emit aef:ready yet, so badges do not render (832 T-258) |

## RCA

<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

**Recommendation:** GO

**Rationale:** Every Agent criterion is met and tested. The map, the instances, the routing and the measurement work on fixtures and on the live corpus. The one gap is in the designer, and it is 832's: the pinned bundle lists inceptions one at a time in its instance picker, but it does not yet render the per-step count badges (`aef:ready`, 832 T-258). So the operator cannot yet see counts or an overdue marker on the steps themselves. The badges are already served (`GET /api/overlay?id=aef-inception-lifecycle`, overdue = alert) and will appear when the bundle is re-pinned.

**Evidence:**
- tests/unit/test_t5227_inception_lifecycle.py: 36 passed
- 1,358 Python tests on the touched surfaces pass. The one failure was the corpus census pin (48 → 49 versions); the pin was moved and the new map lints clean.
- 37 bats suites pass, including upgrade_fresh_machine_simulation (19/19). fw_inception.bats fails only under CLAUDECODE=1, because it files without `--rationale`; it passes 5/5 outside an agent and was already like that before this task.
- `bin/fw test invariants` passes. `bin/fw vendor self --check --task T-5227` passes. `bin/fw watchtower current` passes after a restart.
- Screenshots: .context/visual/T-5227/

## Decisions

### 2026-11-18 — the visual check moves to T-5240 (operator choice A1)
- **Chose:** Close T-5227 with the agent criteria met, and move its [REVIEW] criterion to T-5240.
- **Why:** The designer's per-step counts and overdue markers need 832's overlay rendering (832 T-1438). The approvals section "Questions waiting for you" lists only operator-owned EXPLORING inceptions whose revisit date has passed, and none exists until T-5228's dates come due. Neither surface can be judged on real data today. The operator chose this route (A1) over keeping T-5227 open (A2).
- **Rejected:** A demo inception seeded only for screenshots. It would judge a page state the operator never sees.

### 2026-11-18 — where entered_at and revisit_at are served
- **Chose:** `/api/instances` keeps the v2 instance shape. Only the `lifecycle_node` enum gains the seven inception uids. The dates come from `fw inception lifecycle --json` and the overlay tooltip.
- **Why:** The brief says no new fields in the projection shared with 832. The instance object is `additionalProperties: false`, so adding the dates would have been a contract change.
- **Rejected:** Adding x-internal `entered_at` / `revisit_at` instance fields. The schema allows x-internal changes without a version bump, but that is still a new field.

### 2026-11-18 — inceptions with no waiting_on
- **Chose:** No `waiting_on` means agent, and no `revisit_at` means created + 7. The ~71 existing inceptions are therefore placed now and are not NO-POSITION. T-5228 still writes the values into the files.
- **Rejected:** NO-POSITION until T-5228 runs. That would leave the map empty of exploring inceptions.

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-11-18T12:14:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-5227-inception-lifecycle-map-slice-2-an-aef-i.md
- **Context:** Initial task creation

### 2026-11-18T20:48:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-11-18T22:10:21Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0e3abd41
- **Timestamp:** 2026-11-18T22:13:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Scope:** static anti-pattern scan; PASS means no anti-pattern was found, not that the criteria hold
- **Needs Human:** no
- **Findings:** none
