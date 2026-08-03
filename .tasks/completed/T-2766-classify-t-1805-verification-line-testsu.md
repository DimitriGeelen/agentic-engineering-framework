---
id: T-2766
name: "classify T-1805 verification line: tests/unit/test_outcome_read.py no longer
  exists"
description: >
  Found by the first fw verify-queue census (T-2765). T-1805 sits in the human review
  queue (unchecked Human AC) and its stored block runs: python3 -m pytest tests/unit/test_outcome_read.py
  tests/unit/test_outcome_list.py -q — rc=1, 'ERROR: file or directory not found:
  tests/unit/test_outcome_read.py'. Same two mutually exclusive readings as T-2764
  needing opposite responses: (a) WRONG — the tests were renamed/merged and the line
  pins a path that moved, repairable by re-pointing at the file that now holds those
  cases; (b) CORRECTLY FAILING — the tests were deleted and the coverage T-1805 shipped
  is genuinely gone, in which case the line must not be edited and the coverage must
  be restored. Evidence to decide: git log --diff-filter=D for that path, plus whether
  the outcome read/list cases exist under another filename today. Do not repair blind
  — a green reachable in thirty seconds is exactly when the classification gets skipped
  (832 RAIL-415).

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-03T13:35:42Z
last_update: 2026-08-03T16:45:53Z
date_finished: 2026-08-03T16:45:53Z
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
bvp_scores_proposed:
  - ts: '2026-08-03T13:41:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-03T13:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2766: classify T-1805 verification line: tests/unit/test_outcome_read.py no longer exists

## Context

Classify the red line the first `fw verify-queue` census (T-2765) found on T-1805.
The answer is neither of the two readings the task was filed with — see `## Findings`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Fate of `tests/unit/test_outcome_read.py` established from git history
      (`git log --diff-filter=D --follow`), not inferred: deleted, renamed, or merged
- [x] Whether the outcome read/list cases still exist under another path answered by
      searching for the test function names, not the filename
- [x] Classification recorded in `## Decisions` as exactly one of **(a) WRONG — path
      moved, repairable** or **(b) CORRECTLY FAILING — coverage genuinely gone, line must
      not be edited**, with the evidence that decides it
- [x] Response executed to match: if (a), T-1805's line re-pointed and its full block
      re-run green; if (b), the line left byte-identical and a coverage-restoration task
      filed
- [x] `bin/fw verify-queue --task T-1805` reflects the outcome (green for (a); still red
      with the reason recorded in the task for (b))
- [x] The red the fallback was masking is filed as its own task (T-2769), not folded into
      this repair

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

## Findings

The line under classification (T-1805, `## Verification` line 2):

    python3 -m pytest tests/unit/test_outcome_read.py tests/unit/test_outcome_list.py -q 2>&1 | tail -5 || python3 -m pytest tests/unit/ -k outcome -q

**1. Neither named file has ever existed.** Not deleted, not renamed — never added.
`git log --all --oneline --diff-filter=A -- '*test_outcome_read*'` and the same for
`*test_outcome_list*` are both **empty**, as is `git log --follow` on the literal path.
The two candidate readings the task was filed with (path moved / coverage deleted) both
presuppose the file existed once. It did not. The paths were written from intent, not
read off the tree.

**2. The coverage T-1805 shipped is intact, in the file T-1805's own frontmatter names.**
`components:` lists `tests/unit/test_outcome.py`, and commit `2dcae62f7` ("T-1805:
pause_requested terminal_event class") modified exactly that file. The pause_requested
read/list cases are present and green:
`test_cmd_read_prints_pause_requested_fields`, `test_cmd_read_pause_optional_fields`,
`test_cmd_list_shows_pause_terminal_with_question`, `test_cmd_list_truncates_long_pause_question`.
`pytest tests/unit/test_outcome.py -q` → **39 passed**; the pause slice across
`test_outcome.py` + `test_spawn.py` → **12 passed**.

**3. The `||` fallback has been the sole executor since the line was authored — and it
silently widens the population.** Because the primary arm can never run, every execution
of this line has actually run `pytest tests/unit/ -k outcome -q`: **70 tests across at
least four files**, not the two the line names. That is the same defect family as L-539
and the T-2735/T-2737 fabric-denominator trio — *the set the check runs over is not the
set the check claims to be about*. A fallback that broadens the population is not a
fallback; it is a second, different check wearing the first one's name.

**4. The red is real, and it belongs to a different component.** The fallback's wider net
catches two genuine failures T-1805 never touched:

    tests/unit/test_orchestrator_status_outcomes.py::test_outcomes_json_exposes_aggregation
    tests/unit/test_orchestrator_status_outcomes.py::test_default_json_does_not_have_outcomes_key

Both fail on `json.loads(result.stdout)` with `Expecting value: line 1 column 1`.

**5. Root cause of that red — `fw <cmd> --json` on an uninitialised root emits setup
prose on stdout and exits 0.** Reproduced outside the test harness, in a bare temp dir:

    PROJECT_ROOT=$TD bin/fw orchestrator status --json > out.json

    → rc=0, and out.json begins:
        Setting up agentic governance for fwjson.B60s...
          ⚠  Git identity not configured (commits will fail)
        Vendoring framework into project...
        fw vendor — vendoring framework into project
      …then the JSON.

Two distinct defects in one reproduction, both onboarding-surface:
  (i) a read-only status query **auto-initialises and vendors** into the cwd as a side
      effect — `fw orchestrator status` created a project;
  (ii) the setup narrative goes to **stdout**, so `--json` is unparseable while rc stays
      **0** — a false green at the JSON layer for any programmatic consumer. Banner text
      belongs on stderr (`lib/init.sh:93` is the emitter).

This is the third instance of the class flagged as owed to 832: **checks written against
an imagined artifact rather than a measured one.** Filed T-1805's line names imagined
test files; our scanners matching on imagined stderr text are the sibling case.

## Decisions

**Classification: (a) WRONG — repairable — but by a third mechanism, not the one the task
anticipated.** The line is wrong because it names paths that never existed, not because a
path moved. Evidence that decides it: the empty `--diff-filter=A` history for both names
(rules out moved/deleted), plus the intact green coverage in `test_outcome.py`, the file
T-1805's own `components:` declares (rules out "coverage genuinely gone"). Reading (b) is
excluded on evidence, not on preference — had the pause cases been absent, the line would
have been left byte-identical.

**Repair shape: re-point at `tests/unit/test_outcome.py` AND drop the `-k outcome`
fallback.** Re-pointing alone would leave the population-widening arm in place, so the
line would keep reporting another component's failures as T-1805's. The fallback is the
more dangerous half of the defect and is what must not survive the repair.

**The orchestrator/JSON red is a separate task, not part of this repair.** One bug = one
task; it is a live product defect on the onboarding surface with its own root cause, and
folding it into a verification-line classification would bury it. Repairing T-1805's line
must not be allowed to make it invisible — which is precisely what "just re-point the
path" would have done in thirty seconds.

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
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# The repaired block is green through the rail that found it red.
bin/fw verify-queue --task T-1805 > /tmp/.t2766-vq.out 2>&1 && grep -q "0 red" /tmp/.t2766-vq.out

# The coverage the repair points at is real and passing.
python3 -m pytest tests/unit/test_outcome.py -q

# The phantom paths and the population-widening fallback are gone from the EXECUTABLE
# lines, while the provenance comment naming them survives (comments are stripped by the
# shared extractor — that asymmetry is the point).
bash -c 'source lib/verification-port.sh; extract_verification_block .tasks/active/T-1805-pauserequested-terminalevent-class--subs.md' > /tmp/.t2766-blk.out
! grep -q "test_outcome_read.py" /tmp/.t2766-blk.out
! grep -q -- "-k outcome" /tmp/.t2766-blk.out
grep -q "test_outcome.py" /tmp/.t2766-blk.out

# The finding that decides the classification, pinned so it cannot silently rot: neither
# named file has ever been ADDED in any branch. If this ever returns rows, the premise of
# the whole classification changed and the repair must be revisited.
test -z "$(git log --all --oneline --diff-filter=A -- '*test_outcome_read*' '*test_outcome_list*')"

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

**Symptom:** T-1805's stored verification block was red in the human review queue, on a
line pointing at `tests/unit/test_outcome_read.py` — a file that is not on disk.

**Root cause:** the line was written from intent rather than from the tree. Neither named
file has ever been added in any branch. Because the primary arm could never run, the `||`
arm was the sole executor from the day it was authored, and its population —
`pytest tests/unit/ -k outcome` — is a *superset* of the task's deliverable: 70 tests
across four files, versus the two the line names. So the line has never once judged what
it claims to judge, and its verdict has always been about other components.

**Why structurally allowed:** three gaps compose.
1. **Nothing verifies that a verification line's referents exist.** A path that never
   existed is indistinguishable at authoring time from one that does; the block is stored
   as text and first executed later, if ever.
2. **`||` in a verification line silently substitutes a different check.** The gate judges
   the line's exit status, so a fallback that passes makes the line green regardless of
   whether the intended check ran. A fallback that *widens* the population is the harmful
   case: it can only add failures the task does not own, and it hides the fact that the
   named check is dead.
3. **The block sat in `active/`, outside every rail's population until T-2765.** The line
   was authored 2026-05-13 and first executed by a rail on 2026-08-03 — the defect had no
   surface to appear on for ~12 weeks.

**Prevention:** distinct from the fix (which only repaired this one line).
- `fw verify-queue` (T-2765) now re-runs the review queue's blocks; this task is its first
  yield, so the detection leg exists and is proven by having produced this.
- Pinned in this task's own Verification: the phantom paths and the `-k` fallback must
  stay absent from T-1805's executable lines, and `git log --diff-filter=A` for both names
  must stay empty — if it ever returns rows, the premise of the classification changed.
- **Not yet built, and the real generalisation:** a static check that every path-like
  referent in a stored `## Verification` line resolves on disk, and a lint against `||`
  arms whose population is wider than the primary. Both are cheap greps over the corpus
  and would have caught this at authoring time rather than twelve weeks later. Filing that
  is the honest next step; recording it here so the gap is visible rather than implied.

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

### 2026-08-03T13:35:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2766-classify-t-1805-verification-line-testsu.md
- **Context:** Initial task creation

### 2026-08-03T13:41:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-67486d79
- **Timestamp:** 2026-08-03T16:46:06Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T16:45:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
