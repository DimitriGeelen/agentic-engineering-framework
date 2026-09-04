---
id: T-3274
name: "Verification blocks pin .tasks/active/T-XXXX and decay to permanent false-reds once that task completes"
description: >
  Verification blocks pin .tasks/active/T-XXXX and decay to permanent false-reds once that task completes

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
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
created: 2026-09-04T08:06:05Z
last_update: 2026-09-04T08:06:05Z
date_finished: null
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
---

# T-3274: Verification blocks pin .tasks/active/T-XXXX and decay to permanent false-reds once that task completes

## Context

A `## Verification` line that pins another task's file by its **`.tasks/active/`**
path is a *decaying* reference: it passes at close (the referenced task is still
active) and turns into a permanent false-red the moment that task moves to
`.tasks/completed/`. Nothing fires at the moment of decay — the referenced task's
own close is what breaks a *different* task's verification block, and no gate
looks sideways.

Measured on this corpus (T-3274, round 5 of the T-3265 audit sweep):

- **79** completed tasks pin `.tasks/active/<T-XXXX>` inside `## Verification`
- **54** of those have already decayed (referenced task no longer in `active/`)

Only 1-2 surface per audit run because CTL-013 re-runs a rotating window
(latest 3 completed + a review-queue slice), so the population is latent: each
decayed task reports a false failure only when it rotates into view. This is the
second independent hit on the class — round 3 of the same sweep found all 14
CTL-028 backfills blocked by the *self*-referential form of exactly this bug
(`.tasks/active/<its own file>`), which per CLAUDE.md §Bug-Fix Learning
Checkpoint ("same class hit 2+ times") makes it systemic rather than incidental.

Concrete instance repaired here: **T-1894**, whose 2 failing lines glob
`.tasks/active/T-1851|T-1857|T-1890|T-1893-*.md` — all four completed since.

## Acceptance Criteria

### Agent
- [x] Detector `detect_decaying_task_path_ref` in `lib/reviewer/static_scan.py` flags a Verification line pinning `.tasks/active/<T-XXXX>` and returns no finding for the path-agnostic `.tasks/*/` form
- [x] Detector distinguishes *decayed* (referenced task not in `active/`) from *live* references, so it does not cry wolf on a task that legitimately references an in-flight sibling
- [x] Pattern registered in `policy/anti-patterns.yaml` under id `decaying-task-path-ref`
- [x] Non-blocking advisory fires at `--status started-work` in `agents/task-create/update-task.sh`, mirroring the L-387 sibling (suppress via `FW_SKIP_DECAY_ADVISORY=1`, never blocks)
- [x] T-1894's two decayed verification lines repaired to the path-agnostic form and both re-run green
- [x] Pinning tests cover both directions (flags the decayed form; stays silent on the repaired form and on live references)

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

## Verification

bash -n agents/task-create/update-task.sh
python3 -c "import yaml; yaml.safe_load(open('policy/anti-patterns.yaml'))"
grep -q "decaying-task-path-ref" policy/anti-patterns.yaml
grep -q "FW_SKIP_DECAY_ADVISORY" agents/task-create/update-task.sh
grep -q "detect_decaying_task_path_ref" lib/reviewer/static_scan.py
out=$(python3 -m pytest tests/unit/test_reviewer_decaying_task_path_ref.py -q 2>&1); echo "$out" | grep -q "9 passed" && ! echo "$out" | grep -q "failed"
# T-1894's repaired block must now run fully green (it was 7 pass / 2 fail).
test "$(grep -lE 'REVIEWER\]|T-1894 re-class' .tasks/*/T-1851-*.md .tasks/*/T-1857-*.md .tasks/*/T-1890-*.md .tasks/*/T-1893-*.md | wc -l)" -eq 4
test "$(grep -lE 'T-1894 re-class note' .tasks/*/T-1851-*.md .tasks/*/T-1857-*.md .tasks/*/T-1890-*.md .tasks/*/T-1893-*.md | wc -l)" -eq 4
# T-1894 must no longer pin the decaying .tasks/active/ form.
awk '/^## Verification/{v=1;next} /^## /{v=0} v' .tasks/completed/T-1894-re-class-mis-classified-human-acs-on-4-a.md | grep -v '^[[:space:]]*#' | grep -cq 'tasks/active/' && exit 1 || exit 0

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
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
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
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

## RCA

**Symptom:** `fw audit` CTL-013 reported `T-1894 verification re-run: 2 command(s)
failing`. Re-running the block by hand reproduced it exactly — 7 pass, 2 fail. The
two failing lines assert that four sibling tasks carry a re-class marker; the
markers are all present, and the work T-1894 did is entirely intact.

**Root cause:** both lines glob `.tasks/active/T-1851-*.md` (and T-1857, T-1890,
T-1893). All four tasks have since moved to `.tasks/completed/`, so the globs match
nothing, bash passes the unexpanded pattern to `grep`, and the count comes back 0
instead of 4. The assertion was never wrong — the *path* it pins moved out from
under it.

**Why structurally allowed:** the reference is a **decaying** one, and nothing in
the framework looks at it in the direction it decays.

1. At close, P-011 runs the block and it passes — the referenced tasks are still
   in `active/` at that moment. The gate is green and correct.
2. Decay happens later, and is caused by a *different* task's close. Closing
   T-1851 breaks T-1894's verification block. No gate looks sideways: nothing on
   the close path asks "does any other task's verification pin this file's
   current path?"
3. The only thing that re-reads a completed block is CTL-013, which re-runs a
   **rotating window** (latest 3 completed + a review-queue slice). So a decayed
   task reports its false failure only when it happens to rotate into view —
   1-2 per run, out of a much larger latent population.

That third point is what kept the class invisible: it never looks like a class.
It looks like one flaky task per audit, a different one each time.

**Measured population** (this corpus, at the time of the fix): **79** completed
tasks pin `.tasks/active/<T-XXXX>` inside `## Verification`; **54** of those have
already decayed. This is the second independent hit — round 3 of the same T-3265
sweep found all 14 CTL-028 status backfills blocked by the *self*-referential
variant (`.tasks/active/<its own file>`, which decays the instant the task itself
closes), and that was mis-read at the time as a per-task quirk rather than one
instance of a general shape.

**Prevention** (distinct from the fix):

- `detect_decaying_task_path_ref` in `lib/reviewer/static_scan.py`, registered as
  `decaying-task-path-ref` in `policy/anti-patterns.yaml`, so `fw reviewer` sees
  it on every scanned task.
- A non-blocking advisory at `--status started-work` in `update-task.sh`, sibling
  to the proven L-387 one, so the author is told at the moment they are writing
  the block. Suppress with `FW_SKIP_DECAY_ADVISORY=1`; it never blocks, because
  the *work* is intact — only the path is stale, and failing the close would
  punish an author for a sibling task's later close.
- Only *decayed* references are flagged. A live reference to an in-flight sibling
  is legitimate and common; flagging those would cry wolf on nearly every task
  that coordinates with another, and a detector nobody trusts is worse than none.
- `tests/unit/test_reviewer_decaying_task_path_ref.py` pins both directions,
  including the control legs that separate "works" from "always fires".

**Note on the fix's own verification:** the advisory was proven end-to-end
through `fw task update`, not just as a unit. That mattered — the first live-fire
run printed nothing, because `update-task.sh` short-circuits on
`Status already 'started-work' — no change` and never reaches the advisory block.
The L-387 sibling has the same behaviour, so this is pre-existing and out of scope
here, but it is exactly the L-399 producer/consumer parity trap: the detector was
correct in isolation while the path that invokes it was unreachable in the case I
first tested.

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-04T08:06:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3274-verification-blocks-pin-tasksactivet-xxx.md
- **Context:** Initial task creation
