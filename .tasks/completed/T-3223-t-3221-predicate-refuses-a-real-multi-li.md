---
id: T-3223
name: "T-3221 predicate refuses a real multi-line commit message"
description: >
  T-3221 predicate refuses a real multi-line commit message

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/context/check-active-task.sh, agents/context/lib/safe-commands.sh, tests/unit/safe_commands_chain.bats, tests/unit/t3221_commit_exemption_clause.bats]
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
created: 2026-08-30T10:18:41Z
last_update: 2026-08-30T10:29:29Z
date_finished: 2026-08-30T10:29:29Z
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
  - ts: '2026-08-30T10:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=375,acs=11)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-30T10:30:22Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3223: T-3221 predicate refuses a real multi-line commit message

## Context

Found by the fix in T-3221 refusing the very first commit made after it — the
close of T-3221 itself. That command was `git add -A .tasks/ .context/ .fabric/
&& git commit -q -m "<multi-line message>"`, the framework's own documented
post-completion form, and it was ADMITTED before T-3221 and refused after. A
regression on a legitimate workflow, filed separately because T-3221 was already
closed and its own gate refused to reopen it — the escape the block message
names is a new task, so a new task was taken.

**Measured cause**, not inferred. `_fw_chain_split` was already quote-aware and
correctly kept the message's newlines INSIDE the commit segment. It then printed
each segment with `printf '%s\n'`, and all three callers read that stream with
`mapfile -t` / `read -r` — line-delimited. One segment containing newlines came
back as six, five of them prose from the message body, every one read as an
unsafe command:

```
safe     git add -A .tasks/ .context/ .fabric/
UNSAFE    git commit -q -m "T-3221: close as partial-complete — 12/
UNSAFE   Gate ran all 12 verification commands (14/14 in the new suit
UNSAFE   147 ok across ten adjacent gate suites, corpus silent-skip l
UNSAFE   self-vendor in sync). Lands partial-complete: the one Human
UNSAFE   blast-radius call, since every consumer vendors this hook."
```

The structure was right; the **channel** threw it away. Same class as the bug
T-3221 fixed, and as everything else in this cluster (L-547, OBS-355), one layer
down — a delimiter scan standing in for structure, so an argument that CONTAINS
a delimiter is treated as a boundary.

Fixed at the contract, not at the caller that noticed: `_fw_chain_split` now
emits NUL-terminated segments and all three readers use `read -d ''`. NUL is the
only delimiter that cannot appear in a bash command string. This also repairs
`is_bash_safe_command`, which had the same latent defect for any multi-line
quoted argument since T-2834.

**Ninth instance of the class, observed while writing this file.** The
focus-drift gate blocked the command that was going to write this very RCA,
because the heredoc *mentioned* the predecessor task ID. My focus was correct
and the target file was this task's own. The remedy was the Edit tool rather
than the `FW_SWITCH_FOCUS=1` bypass the block message offers, because logging a
Tier-2 drift bypass for a command that never drifted would put a false entry in
the audit trail. Filed as evidence, not fixed here.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The refusal is REPRODUCED and its cause MEASURED — clause split, quote
      strip return code, write-pattern verdict, per-clause verdict — not
      inferred from reading the predicate
- [x] `git add -A <paths> && git commit -q -m "<multi-line message>"` is
      ADMITTED again at both exemption branches
- [x] The four shapes T-3221 closed stay blocked — this must not be fixed by
      loosening back toward the substring match
- [x] T-3221's suite gains a leg using a REALISTIC commit message (multi-line,
      punctuation, parentheses, an apostrophe) — the short `-m "TT-9: x"`
      fixture is what let this through
- [x] The no-widening sweep still passes with the corrected predicate
- [x] `bin/fw vendor self --check` reports in sync
- [x] A newline-separated command OUTSIDE quotes is still blocked — the fix must
      not be mistaken for "stop splitting on newlines", which would widen
- [x] A mutation control reverts the splitter to newline output and asserts the
      multi-line refusal comes back, so the two legs above pass BECAUSE of the
      NUL delimiter and not incidentally
- [x] The two tests that call `_fw_chain_split` directly are updated to the new
      contract rather than left to pass vacuously (both counted segments as
      lines, which would report 1 for every input)

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

timeout 900 bats tests/unit/t3221_commit_exemption_clause.bats > /tmp/.t3223a.out 2>&1 && grep -q "^ok 17" /tmp/.t3223a.out && ! grep -q "^not ok" /tmp/.t3223a.out
test "$(grep -c '# skip' /tmp/.t3223a.out)" -eq 0
timeout 1200 bats tests/unit/fd_dup_not_chain_split.bats tests/unit/safe_commands_chain.bats tests/unit/check_active_task_cwd_resolution.bats tests/unit/check_active_task_fp_fix.bats tests/unit/check_active_task_memory_exempt.bats tests/unit/check_active_task_switch_focus.bats tests/unit/context_safe_commands.bats tests/unit/safe_commands_env_prefix.bats tests/unit/t3096_safe_commands_wrappers.bats tests/unit/t3179_partial_complete_commit.bats tests/unit/test_check_active_task_bootstrap.bats tests/unit/test_safe_commands_git_commit.bats > /tmp/.t3223b.out 2>&1 && ! grep -q "^not ok" /tmp/.t3223b.out
test "$(grep -c '# skip' /tmp/.t3223b.out)" -eq 0
bash -n agents/context/check-active-task.sh
bash -n agents/context/lib/safe-commands.sh
test "$(grep -c 'printf .%s.0. "\$seg"' agents/context/lib/safe-commands.sh)" -eq 3
# Anchored to statement position, not a bare substring: the contract note in the
# header also contains the idiom, so a plain count returns 3 and asserts nothing
# about the readers. That is the same mention-vs-instance confusion this whole
# task is about, reproduced in its own verification line — caught by the gate.
test "$(grep -cE "^[[:space:]]*while IFS= read -r -d ''" agents/context/lib/safe-commands.sh)" -eq 2
grep -qE "^[[:space:]]*while IFS= read -r -d ''" agents/context/check-active-task.sh
python3 tools/bats-silent-skip-lint.py tests/
bin/fw vendor self --check > /tmp/.t3223v.out 2>&1 && grep -q "in sync" /tmp/.t3223v.out

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

**Symptom.** The first real commit made after the predecessor fix landed was
refused by that fix. The command was the documented post-completion form and had
been admitted by the pre-fix code.

**Root cause.** `_fw_chain_split` used newline as its output delimiter while
being quote-aware about newlines in its input. Those two facts are jointly
impossible: if a segment may contain a newline, a newline cannot separate
segments. Three callers read the stream as lines and all three inherited it.

**Why the framework allowed it.** Two reasons, and the second is the one worth
keeping.

1. Every fixture in the predecessor's suite used `-m "TT-9: x"` — no newline, no
   apostrophe, no parentheses. The suite exercised the predicate thoroughly
   against inputs that could not reach the defect. That is why the new leg's
   fixture is deliberately ugly: newlines, an apostrophe, parentheses, a colon,
   an em dash and a `#`.

2. **The defect predates the predecessor by a year and generated no evidence.**
   `is_bash_safe_command` has used this splitter since T-2834 with the same
   blindness for any multi-line quoted argument. Nobody hit it because the
   failure direction is toward BLOCKING — a mis-split command reads unsafe and
   goes to the task gate, which admits it whenever a task is active. It surfaced
   only when a *second* consumer used the splitter in a context where blocking
   was itself the wrong answer. A latent fault that always fails safe produces
   no signal until something changes what "safe" means. That is the general
   lesson: erring toward blocking is the right default and it also hides the
   bug, so a fail-safe direction is not a reason to skip the test.

**Prevention.** The delimiter is NUL, which cannot collide with content, and the
contract is stated at the function with the reader idiom every caller must use.
Two mutation controls give it teeth: one reverts the library to newline output
and asserts the multi-line refusal returns; the other asserts a newline-separated
command OUTSIDE quotes is still blocked — so the fix cannot be mistaken for
"stop splitting on newlines", which would have been a genuine widening. The two
tests that call the splitter directly were updated to the new contract rather
than left counting NUL output as lines, which would have reported one segment
for every input and passed forever.

**Escalation level.** C (tooling). The fix is in the shared predicate, not in
the caller that noticed, so every present and future consumer inherits it.

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

### 2026-08-30T10:18:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3223-t-3221-predicate-refuses-a-real-multi-li.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c21cb68e
- **Timestamp:** 2026-08-30T10:30:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-30T10:29:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
