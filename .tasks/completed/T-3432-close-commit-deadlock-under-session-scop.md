---
id: T-3432
name: "close-commit deadlock under session-scoped focus: update-task.sh clears the
  unscoped focus.yaml while the gate reads focus.SESSION.yaml"
description: >
  close-commit deadlock under session-scoped focus: update-task.sh clears the unscoped
  focus.yaml while the gate reads focus.SESSION.yaml

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh]
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
created: 2026-09-22T12:03:48Z
last_update: 2026-09-22T12:29:52Z
date_finished: 2026-09-22T12:29:52Z
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
  - ts: '2026-09-22T12:15:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=271,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T12:15:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3432: close-commit deadlock under session-scoped focus: update-task.sh clears the unscoped focus.yaml while the gate reads focus.SESSION.yaml

## Context

Found live by the T-3428 worker (OBS-468). `update-task.sh:2267` hardcodes
`$CONTEXT_DIR/working/focus.yaml` when clearing focus on `work-completed`,
while the task gate (`check-active-task.sh` → `fw_focus_file`, T-3038)
reads the worker's own `focus.<key>.yaml` under `FW_SESSION_SCOPED_FOCUS=1`.
After a clean close the scoped file still names the completed task, so the
gate refuses every Bash and Write ("task is work-completed") and the close
commit cannot be made; T-2054's null-focus checkpoint allowance never fires
because the focus the gate sees is not null. Every dispatched worker that
closes a task hits this, and T-3422 (seeding the scoped file at dispatch)
made it universal. Fix: resolve the file to clear through the same helper
the reader uses (L-399 producer/consumer parity); default mode unchanged.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `agents/task-create/update-task.sh:2266` resolves the focus file through `fw_focus_file "$PROJECT_ROOT"` (honouring `FW_SESSION_SCOPED_FOCUS`) instead of hard-coding `$CONTEXT_DIR/working/focus.yaml`, so a full close clears the SAME file the gate reads
  - Evidence: `update-task.sh:2279` now reads `FOCUS_FILE="$(fw_focus_file "$PROJECT_ROOT")"`; `lib/paths.sh` was already sourced at line 18, so no new dependency. `fw_focus_file` honours `CONTEXT_DIR` itself (`lib/paths.sh:187`).
- [x] A regression test pins the deadlock: with `FW_SESSION_SCOPED_FOCUS=1` and a session-scoped focus naming task X, `update-task.sh X --status work-completed` leaves `current_task: null` in `focus.<key>.yaml` — red before the fix, green after
  - Evidence: `tests/unit/t3432_scoped_close_clears_scoped_focus.bats`, 7/7 ok. Measured red-before by `git stash`-ing only the fix: tests 1 and 7 flipped to `not ok`, the other five stayed green — i.e. exactly the two legs that pin the defect.
- [x] The unscoped path still clears correctly when `FW_SESSION_SCOPED_FOCUS` is unset (no regression for interactive sessions)
  - Evidence: tests 4 and 5 (shared file nulled; no scoped file written), both green before AND after the fix. `fw_focus_file` returns `${CONTEXT_DIR}/working/focus.yaml` verbatim outside scoped mode, so the default path is byte-for-byte the previous expression.
- [x] Concern registered in `.context/concerns.yaml` describing the class: close clears one focus file, the PreToolUse gate reads another, and the T-2054 null-focus commit allowance is therefore unreachable for every session-scoped worker
  - Evidence: OBS-255, commit `501389397`. Names the sharper form of the class — the split did not merely misroute a write, it silently disarmed T-2054, the escape hatch built for this exact deadlock — and names the residual (nothing enumerates the writers of `focus.yaml`).

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
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

# --- The regression suite. Two lines: "did anything fail" and "did everything run".
timeout 300 bats tests/unit/t3432_scoped_close_clears_scoped_focus.bats > /tmp/.t3432.out 2>&1 && ! grep -q "^not ok" /tmp/.t3432.out
test "$(grep -c "# skip" /tmp/.t3432.out)" -eq 0 && grep -q "^ok 7 " /tmp/.t3432.out

# --- The two suites this change sits between: the reader (T-3038) and the seeder (T-3422).
timeout 300 bats tests/unit/t3038_session_scoped_focus.bats > /tmp/.t3432-3038.out 2>&1 && ! grep -q "^not ok" /tmp/.t3432-3038.out
timeout 300 bats tests/unit/t3422_dispatch_seeds_focus.bats > /tmp/.t3432-3422.out 2>&1 && ! grep -q "^not ok" /tmp/.t3432-3422.out

# --- The fix itself: one resolver, and no surviving hard-coded shared path.
grep -q 'FOCUS_FILE="$(fw_focus_file "$PROJECT_ROOT")"' agents/task-create/update-task.sh
! grep -q "CONTEXT_DIR/working/focus.yaml" agents/task-create/update-task.sh

# --- Vendor parity, scoped to THIS task's file. A repo-wide `vendor self --check`
# would fold in a concurrent worker's in-flight files and say nothing about mine.
cmp -s agents/task-create/update-task.sh .agentic-framework/agents/task-create/update-task.sh

# --- The concern exists and names the mechanism, not just the symptom.
python3 -c "import yaml; c=yaml.safe_load(open('.context/concerns.yaml')); e=[x for x in c if x['id']=='OBS-255']; assert len(e)==1 and 'T-2054' in e[0]['root_cause']"

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

**Symptom:** A dispatched worker that closes its own task cannot commit that
close. `bin/fw task update T-XXXX --status work-completed` succeeds cleanly —
exit 0, "Focus cleared (task completed)" printed — and then every subsequent
Bash and every Write is refused by the PreToolUse gate with `BLOCKED: Task
T-XXXX is not active (may be completed or missing)`. The task's file move and
episodic sit uncommitted with no stated remedy in the block message. Found live
by the T-3428 worker mid-close (OBS-468 → OBS-255).

**Root cause:** T-3038 split focus into per-session files. `fw_focus_file`
(`lib/paths.sh:185`) returns `focus.<key>.yaml` under
`FW_SESSION_SCOPED_FOCUS=1` and the shared `focus.yaml` otherwise; the reader
(`agents/context/check-active-task.sh`) and `fw context focus` were both moved
onto it. `update-task.sh`'s close path — a *third* writer — kept the literal
`FOCUS_FILE="$CONTEXT_DIR/working/focus.yaml"`. So the close nulled a file
nobody was reading and left the file the gate reads still naming a task that had
just moved to `.tasks/completed/`. A producer/consumer split of the L-399 class.

The sharper form, and the part worth carrying: **the defect disarmed the escape
hatch built for this exact deadlock.** T-2054 allows a bare `git commit` when
focus is NULL, precisely so a just-closed task can checkpoint itself. That
allowance is predicated on the close having nulled the focus *the gate reads*.
It had not — so the gate saw a non-null focus naming an archived task, took the
"not active" branch, and the remedy never fired. Not a misrouted write; a safety
valve silently disarmed by a file split it was never told about.

**Why structurally allowed:** Three things had to line up, and each is ordinary
on its own.

1. **Nothing enumerates the writers of focus.yaml.** T-3038 moved the reader and
   the obvious writer onto the helper and had no way to discover there was a
   third. Grep for the literal path is the only instrument, and it is not run.
2. **The gate's silence is indistinguishable from correctness at close time.**
   The close prints "Focus cleared" and exits 0. The lockout only manifests on
   the *next* tool call, in a different process, attributed to a different-looking
   failure ("task is not active"). Nothing connects the two.
3. **`FW_SESSION_SCOPED_FOCUS=1` is a worker-only env.** Every interactive
   session — where a human would have noticed within seconds — resolves to the
   same shared file as before and is entirely unaffected. The bug was only ever
   visible to workers, which are precisely the sessions nobody is watching. T-3422
   then seeded a scoped focus file for *every* dispatched worker, converting an
   opt-in latency into a universal one.

**Prevention:** The fix is one resolver on both sides. Prevention is
`tests/unit/t3432_scoped_close_clears_scoped_focus.bats`, and specifically the
shape of it: it runs **the command that deadlocked** — after a scoped close, the
gate must ALLOW `git commit -m "<id>: close"` — rather than only asserting
`current_task: null`. A contents-only assertion would pass on a fix that cleared
the wrong key. It is paired with a control leg pinning the gate REFUSING that
same command in the reconstructed pre-fix state, so a green suite cannot come
from a gate that allows `git commit` unconditionally. Red-before was measured,
not assumed: stashing the one-line fix flips exactly tests 1 and 7.

Honest residual, filed in OBS-255 rather than fixed here: a *fourth* writer added
later reintroduces this the same way, because item 1 above is untouched. The
candidate is a lint refusing a literal `working/focus.yaml` outside
`lib/paths.sh`. Worth noting that T-3179 is the same class one layer over — the
partial-complete half of the same T-2054 deadlock — which makes this the second
recorded instance of "a focus-predicated allowance stops being reachable when the
focus state it reads changes shape", and is the argument for the lint.

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

### 2026-09-22T12:03:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3432-close-commit-deadlock-under-session-scop.md
- **Context:** Initial task creation

### 2026-09-22 — control leg corrected a wrong assumption about where the gate blocks
- **Action:** The first draft of the control leg reproduced the pre-fix state by
  flipping the task's status to `work-completed` while leaving the file in
  `.tasks/active/`. It went green — the gate ALLOWED the commit.
- **Finding:** That state reaches T-3179's partial-complete allowance, which lets
  `git commit` through on purpose. The deadlock needs the file ARCHIVED to
  `.tasks/completed/` *and* a stale scoped focus; the block is then "not active
  (may be completed or missing)", not the `work-completed` branch. Verified by
  reproducing both states against the gate directly before rewriting the leg.
- **Why it matters:** without the control the suite would still have been 7/7
  green and would still have gone red-before-fix on the right two legs — the
  wrong control was invisible, not noisy. It is the leg that distinguishes a
  working fix from a gate that allows `git commit` unconditionally, so a control
  that passes for the wrong reason is worse than none.

### 2026-09-22 — vendor sync
- **Action:** `FW_VENDOR_ONLY="agents/task-create/update-task.sh" bin/fw vendor self`,
  then `bin/fw vendor self --check`.
- **Output:** "vendored .agentic-framework/ in sync with source", rc 0 — clean
  repo-wide at the time of running, so the anticipated T-3430 in-flight drift in
  `agents/fabric/*` did not appear and nothing outside this task's file was
  touched or vendored. The P-011 line is still scoped to this file by `cmp`, so
  the gate's verdict does not depend on another worker's timing either way.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7446661c
- **Timestamp:** 2026-09-22T12:30:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-22T12:29:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
