---
id: T-2921
name: "P-011 verification extractor strips HTML comments from the command text, mangling
  lines containing comment delimiters"
description: >
  The P-011 extractor strips HTML comments from the task body before executing Verification
  lines. It does not distinguish a comment wrapping prose from the same delimiters
  appearing INSIDE a command, so a legitimate verification line was executed as sed
  '//d' — empty regex, no previous regular expression, exit 1. Found live by the T-2862
  greenfield end-to-end run: the greenfield seed's own Recommendation check was destroyed
  this way, so every new project's first inception failed its own verification gate.
  The SEED was fixed in T-2862 by dropping the sed pre-pass; the extractor is still
  broken for any other command containing the delimiters. Same mention-vs-instance
  class as L-576: the stripper asks 'is this a comment delimiter' when the question
  is 'is this delimiter structural, or is it argument text'.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-active-task.sh, lib/review.sh, tests/unit/t2862_greenfield_first_inception_e2e.bats, tests/unit/t2948_review_human_ac_comment_aware.bats]
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
created: 2026-08-11T15:41:21Z
last_update: 2026-08-12T18:40:17Z
date_finished: 2026-08-12T18:40:17Z
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
  - ts: '2026-08-11T15:45:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-12T18:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-11T15:45:15Z'
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
  - ts: '2026-08-12T18:30:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=4 (body:cross-machine); F-RECALL=0 
      (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal);
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2921: P-011 verification extractor strips HTML comments from the command text, mangling lines containing comment delimiters

## Context

`run_verification_commands` (agents/task-create/update-task.sh:1124) strips HTML
comments from the ## Verification block with a single whole-block regex:

    re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)

The block it runs over is not prose — every surviving line is handed to `eval`.
So the strip cannot tell a *structural* comment (guidance the author wrote for a
reader, correctly discarded) from a delimiter appearing as *argument text* inside
a command (correctly executed). Two distinct failures follow, and the second is
worse than the one that was reported:

1. **Mangling.** `sed '/<!--/,/-->/d' f` → `sed '/d' f`. The command errors, the
   gate FAILs, the author sees a red line. Loud. This is the T-2862 origin.
2. **Silent deletion.** `.*?` under DOTALL spans newlines, so a mid-line `<!--`
   pairs with the *next* `-->` anywhere below — including the close of a genuine
   comment block further down. Every command line between them is deleted before
   `wc -l` counts them. The gate then reports "Running N command(s)" and
   "Verification: N/N passed" over a population it silently shrank. **False
   green** — the failure mode that reached 371 instances in the port-3000 class
   precisely because a green line that asserts nothing looks exactly like a
   green line that asserts everything.

Same mention-vs-instance class as L-576 and as T-2948 one layer up: the stripper
asks "is this a comment delimiter" when the question is "is this delimiter
structural, or is it argument text". Direction rule (T-2948): comment-stripping
is correct where the span is DISCARDED as prose, and a defect where the span is
EXECUTED. This is the executed side.

Found live by the T-2862 greenfield end-to-end run — the greenfield seed's own
Recommendation check was destroyed this way, so every new project's first
inception failed its own verification gate. The SEED was fixed in T-2862 by
dropping the sed pre-pass; the extractor was left broken for every other command.

**Cross-project:** 832 (workflow-designer) reported the identical defect
independently as their T-456 and proposed the remedy shape — strip at the
guidance/command split rather than over the whole block. That is what this task
builds. Agreed on the DM rail at 568. Their sibling finding (composition
`a ; b` judged on `b` alone) is a DIFFERENT defect in the same function and is
NOT in this task's scope — one bug, one task.

## Acceptance Criteria

### Agent
- [x] A ## Verification line containing `<!--` and `-->` as argument text reaches `eval` byte-identical to the task file (the T-2862 mangling case is gone)
- [x] A structural comment block — opening `<!--` as the first non-blank token on its line — is still stripped in full, single-line and multi-line, including its closing line
- [x] Command lines are no longer swallowed between a mid-line `<!--` and a later structural `-->`; the command COUNT the gate reports equals the number of real command lines (the false-green)
- [x] `tests/unit/t2921_verification_comment_strip.bats` drives the real `bin/fw task update --status work-completed` gate in a sandbox PROJECT_ROOT (not a reimplementation of the predicate), and every leg is falsified against the pre-fix extractor
- [x] `## RCA` filled: symptom, root cause, why structurally allowed, prevention distinct from the fix

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

# The suite. Guarded per T-2738 — a bats run that prints "3 failed, 9 passed"
# satisfies a bare `grep -q passed`, so assert the absence of `not ok` too.
out=$(bats tests/unit/t2921_verification_comment_strip.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Both edited files parse (L-408).
bash -n lib/verification-port.sh && bash -n agents/task-create/update-task.sh
# The executor calls the shared extractor and holds no whole-block strip of its
# own. Scoped to run_verification_commands deliberately: an unscoped
# `! grep "re.sub(r'<!--" update-task.sh` FAILS, and correctly so — the file
# keeps three such strips at lines 294/409/497 for the ## Recommendation body,
# the ## RCA body and the ### Human AC block. Those spans are PROSE, discarded
# and never executed, so the whole-block regex is right there. Only the
# executed block was wrong. (I wrote the unscoped form first and the gate caught
# it, which is the direction-rule from T-2948 earning its keep twice in one task.)
# The `grep -q extract_verification_block` clause is the non-vacuity guard: if
# the awk range ever stops matching, `$out` goes empty and the `!` test would
# otherwise pass while asserting nothing.
# This line also dogfoods the fix — it carries both delimiters as argument text.
out=$(awk '/^run_verification_commands\(\)/,/^}/' agents/task-create/update-task.sh); echo "$out" | grep -q 'extract_verification_block' && ! echo "$out" | grep -qF "re.sub(r'<!--"
# The three PROSE strips must SURVIVE. Guards the over-correction: a reader who
# takes this task's RCA too broadly and deletes them re-opens T-2765, where
# template prose came back as executable shell.
test "$(grep -cF "re.sub(r'<!--" agents/task-create/update-task.sh)" -ge 3
# No regression in the other three consumers of the shared extractor.
out=$(bats tests/unit/t2765_verify_queue.bats tests/unit/task_verify_extraction.bats tests/unit/update_task_verification.bats tests/unit/verification_port_hardcode.bats tests/unit/verification_unjudged_test_run.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

**Symptom.** Reported as a mangling: a Verification line reading
`sed '/<!--/,/-->/d' f` was executed as `sed '/d' f` and failed with "no
previous regular expression". Found by the T-2862 greenfield run, where the
casualty was the greenfield seed's own Recommendation check — so every new
project's first inception failed its own verification gate.

The reported symptom was the mild one. Investigating turned up a second,
quieter behaviour of the same expression, and the measurement below is the part
that matters: on a three-command block whose middle member is a failing
assertion, the pre-fix gate printed

    Running 2 verification command(s)...
    Verification: 2/2 passed ✓

and let the task close. The failing check had been deleted before it was
counted. Nothing was red, nothing was logged, and the gate's own output was
indistinguishable from a genuine pass.

**Root cause.** `re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)` applied to
a block every surviving line of which is handed to `eval`. The expression
recognises a comment *delimiter*; the question the site actually asks is
whether the delimiter is *structural* (prose the author wrote for a reader —
discard) or *argument text* (part of a command — execute). Those are different
questions and the regex cannot distinguish them. `DOTALL` then makes the second
failure mode possible at all: `.*?` crosses newlines, so a mid-line `<!--`
pairs with the next `-->` anywhere below — typically the close of a genuine
comment block — and everything between is deleted before `wc -l` counts it.

Same class as L-576 (mention vs instance) and as T-2948 one layer up. T-2948
established the direction rule and this is its other side: comment-stripping is
**correct where the span is discarded as prose, and a defect where the span is
executed**. Same regex, opposite correctness, decided entirely by what the
consumer does with the surviving text.

**Why structurally allowed.** Three compounding reasons.

1. *The predicate was duplicated.* The extraction existed twice — inline in
   `update-task.sh:1121` and in `lib/verification-port.sh:52` — and the library
   copy's own comment asserted "the same shape update-task.sh executes". Parity
   claimed in prose between two copies, which is the T-2949 shape exactly (one
   change, three artefacts, 57 days red). That same comment records that the
   claim had already been found false once, in T-2765, and it was repaired by
   editing the copy rather than removing the duplication.
2. *The failure mode is a false green.* P-011's entire job is to be the thing
   you trust when you cannot check by hand. A gate that under-reports its own
   population is not noisy-wrong, it is quiet-wrong, and quiet-wrong is what
   reached 371 instances in the port-3000 class before anyone looked. A red
   line gets noticed at the next close; a green line that asserts nothing never
   prompts anyone to look.
3. *Nothing tested the extractor on adversarial input.* Four suites covered
   this area (`t2765_verify_queue`, `task_verify_extraction`,
   `update_task_verification`, `verification_port_hardcode`) and all 53 legs
   were green throughout, because every fixture used commands with no comment
   delimiters in them. The population under test excluded the failing case —
   832's G-034, verdict over an empty population.

**Prevention** (distinct from the fix):

- `tests/unit/t2921_verification_comment_strip.bats` — 7 legs. Legs 1-5 drive
  the real shared function; legs 6-7 drive the real `update-task.sh
  --status work-completed` end-to-end, because the extractor being right and
  the gate *calling* it are separate claims and the bug lives at the join
  (L-399). Leg 7 asserts the false green specifically: three commands seen, the
  failing one run and reported, close refused. Leg 4 is a non-vacuity check
  that runs the old expression inline and asserts it corrupts the fixtures — if
  it ever passes, the other legs are asserting nothing.
- Falsified rather than assumed: restoring the DOTALL strip turns legs 1, 3, 6
  and 7 red. Recorded in the suite header so the next reader does not have to
  take it on trust.
- The duplication is removed, not annotated. `update-task.sh` now calls
  `extract_verification_block`, so the parity its comment claimed is true by
  construction. This follows the pattern already used two functions up for
  `find_port_literals` (L-533: run THIS expression, not a re-typed copy) —
  the codebase had the right idea in the neighbouring function and this site
  had not adopted it.

**What this does NOT fix** (registered, not silently absorbed):

- `agents/audit/audit.sh:3406` (CTL-013) holds a *third* copy. It is line-based
  and therefore closer to correct, but it drops any line *containing* `<!--`
  anywhere rather than only lines *opening* with it — so audit's scan
  population silently omits delimiter-carrying commands and diverges from what
  the gate executes. Same class, different component, its own tests. Filed as
  OBS-238 with a follow-up task rather than folded in here (one bug, one task).
- 832's sibling finding on the same function — composition `a ; b` judged on
  `b` alone, so a failing first clause is invisible — is a different defect and
  is not touched here. Their T-456; carried with attribution.

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

### 2026-08-11T15:41:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2921-p-011-verification-extractor-strips-html.md
- **Context:** Initial task creation

### 2026-08-12T18:24:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e34bf82f
- **Timestamp:** 2026-08-12T18:41:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T18:40:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
