---
id: T-4149
name: "SECURITY: project-boundary hook (check-project-boundary.sh Pattern 3) misses
  outside writes spelled with a quoted target, a quote-split verb, a .. traversal,
  a leading redirection, or a bundled sed -i suffix — parser differential vs bash"
description: >
  Verified 2026-10-13 by feeding PreToolUse payloads to agents/context/check-project-boundary.sh
  (repro: .context/scratch/t4125-repro.py; target built at run time): plain 'touch
  /etc/X' BLOCKED, but ALLOWED: touch "/etc/X"; to""uch /etc/X; touch /tmp/../etc/X;
  > /tmp/x touch /etc/X; sed -ibak s/a/b/ /etc/X. Found by an independent codex review
  seat chasing ring20-dashboard's unconfirmed hint (msg 263d69bf, finding 3); the
  seat was cut off by the vendor's cyber filter before writing up, its event log holds
  the candidates. Root cause class: regex/word parsing that differs from bash (quote
  removal, path normalisation, redirection position, option bundling). Fix with a
  real shell-word tokeniser (shlex with posix rules or the tier0_action grammar approach),
  normalise paths (realpath -m) before the inside/outside test, treat redirections
  anywhere in a simple command, accept -i<suffix>; tests: each case above must fail
  on HEAD; controls for in-project writes stay allowed.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
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
created: 2026-10-13T13:45:20Z
last_update: 2026-10-13T14:16:10Z
date_finished:
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
  - ts: '2026-10-13T13:46:50Z'
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
cost_estimate_proposed:
  - ts: '2026-10-13T14:00:17Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=288,acs=8)
    rubric_sha: e4a00f38e801
---

# T-4149: SECURITY: project-boundary hook (check-project-boundary.sh Pattern 3) misses outside writes spelled with a quoted target, a quote-split verb, a .. traversal, a leading redirection, or a bundled sed -i suffix — parser differential vs bash

## Context

Pattern 3 of `agents/context/check-project-boundary.sh` reads a quote-BLANKED copy of the
command with regexes, so its reading differs from bash on quoting, `..`, redirection
position and option clustering. Fix: a tokenised write-target pass reusing
`lib/shell_write_scan.py` (T-3695's bash-style scanner) in a boundary mode, with a real
quote/comment/heredoc-aware lexer for substitution bodies. Reproducer:
`.context/scratch/t4125-repro.py`.

## Acceptance Criteria

### Agent
- [x] `tests/unit/t4149_boundary_parser_differential.bats` has one test per verified case (quoted target, quote-split verb, `..` traversal, leading redirection, `sed -i<suffix>`), each built at run time, and each FAILS against HEAD's hook (recorded in Updates)
- [x] Same file pins the further same-class spellings the tokeniser closes (double-quoted `$(...)` body, unquoted heredoc body substitution, fake `<<EOF` in a comment/quote, brace expansion, `~`, quoted cd target) and the fail-closed case (unterminated quote naming an outside path)
- [x] Controls stay allowed: in-project writes (quoted, relative, `..` inside the project), `/tmp` writes, `2>/dev/null`/`>/dev/stderr`, commit messages / quoted heredoc bodies that MENTION outside writes, `echo '$(touch …)'`
- [x] Every existing test file referencing the boundary hook or `shell_write_scan` passes (T-3695 guard behaviour unchanged or stricter) — except `tests/integration/check_project_boundary.bats` "Bash redirect to /etc: blocked", which is red on HEAD too (it expects `> /etc/cron.d/…` blocked; `/etc/cron.d` is a sanctioned write zone since T-603/T-1191); not changed here
- [x] `## Decisions` states what the parser guarantees and what it does not (script files, run-time-built paths, inline interpreter code)
- [x] `bin/fw vendor self --check` clean for the touched files; `bin/fw test lint` introduces nothing

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
timeout 600 bats tests/unit/t4149_boundary_parser_differential.bats > /tmp/.t4149a 2>&1 && ! grep -q "^not ok" /tmp/.t4149a
test "$(grep -c '# skip' /tmp/.t4149a)" -eq 0
timeout 900 bats tests/unit/check_project_boundary.bats tests/unit/test_boundary_hook_arguments.bats tests/unit/t3076_boundary_termlink_segment_scope.bats tests/unit/t2920_boundary_heredoc_strip_order.bats tests/unit/t4114_boundary_tee_options.bats tests/unit/t4126_boundary_write_verbs.bats tests/unit/g065_readiness.bats tests/unit/t3766_review_credential.bats > /tmp/.t4149b 2>&1 && ! grep -q "^not ok" /tmp/.t4149b
# integration file minus its one HEAD-red test (redirect into /etc/cron.d, a sanctioned zone — see AC 4)
timeout 600 bats tests/integration/check_project_boundary.bats > /tmp/.t4149d 2>&1; grep -q '^ok ' /tmp/.t4149d && test "$(grep -c '^not ok' /tmp/.t4149d)" -le 1 && ! grep '^not ok' /tmp/.t4149d | grep -qv 'Bash redirect to /etc: blocked'
timeout 900 bats tests/unit/t3695_human_ac_tick_bash.bats tests/unit/human_ac_tick_guard.bats tests/unit/t2954_human_ac_tick_comment_aware.bats > /tmp/.t4149c 2>&1 && ! grep -q "^not ok" /tmp/.t4149c
bin/fw vendor self --check

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

**Symptom:** the project-boundary hook blocked `touch /etc/X` but allowed `touch "/etc/X"`,
`to""uch /etc/X`, `touch /tmp/../etc/X`, `> /tmp/x touch /etc/X` and `sed -ibak s/a/b/ /etc/X`
(verified 2026-10-13, `.context/scratch/t4125-repro.py`), plus the same-class spellings
pinned in `tests/unit/t4149_boundary_parser_differential.bats` (double-quoted `$(...)`,
unquoted heredoc substitution, a fake `<<EOF` in a comment, brace expansion, `~`, quoted
cd, `sh -c`/`eval`, `$'\c''`, relative `../..`, rm/mv/chmod).

**Root cause:** Pattern 3 never parsed the command. It ran regexes over a copy whose
quoted text had been BLANKED (`_strip_quoted`, T-1361 — added to stop prose in commit
messages false-positiving), so every quoted target was invisible; it took the first word of
a `<>`-split chunk as the verb (leading redirection, quote-split verbs); it prefix-tested
paths before normalising (`/tmp/../etc`); and its `sed -i` regex only knew `-i.SUFFIX`.
Each was a separate place where the hook's reading of the text differed from bash's.

**Why structurally allowed:** every fix to this hook (T-1702 heredocs, T-1361 quotes,
T-2920 strip order, T-3076 termlink scope, T-4114 tee options, T-4126 write verbs) added a
regex or a strip pass for the spelling just reported, and each came with tests of THAT
spelling. T-4114 and T-4126 tested option position and verb coverage over unquoted,
normalised, verb-first commands — none varied quoting, normalisation or redirection
position, because the defect class ("the scanner reads text differently from bash") was
never named, only its instances. A denylist of spellings cannot converge on a grammar —
the lesson Tier 0 learned in its review rounds 4-6 (CLAUDE.md T-3593). Meanwhile the repo
already had a bash-style tokeniser (`lib/shell_write_scan.py`, T-3695, three review rounds)
that the boundary hook did not use.

**Prevention:** the write-target decision now goes through one tokeniser shared with the
T-3695 task-file guard, so a reading fix lands in both gates; the new bats file varies the
SPELLING axis (quoting, escapes, `..`, redirection position, option clusters, expansion,
substitution context) against a fixed outside target, with controls in both directions;
unparseable text is refused rather than guessed. The corpus census script
(`.context/scratch/t4149-corpus.py`, 36,260 real agent commands) is the false-positive
check to rerun for any future lexer change.

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

### 2026-10-13 — tokeniser: reuse lib/shell_write_scan.py, not a third parser
- **Chose:** a boundary mode of `lib/shell_write_scan.py` (`scan_boundary(command, cwd,
  guarded, cd_ok)`), called from the hook as Pattern 5 on the RAW command. Patterns 1-4 are
  kept unchanged, so Pattern 5 only ever adds refusals.
- **Why:** T-3695's scanner already does bash quote removal, redirection stripping
  anywhere in a simple command, wrapper unwrapping, GNU option clusters (`sed -i<SUF>`),
  cwd tracking through `cd`, glob + realpath/normpath resolution, and it has three review
  rounds behind it. A second tokeniser in the hook would be one more reading to diverge.
- **Rejected:** `shlex` (no operators, no heredocs, no substitution bodies, no `$'..'`);
  the tier0_action grammar approach (a whitelist grammar suits APPROVAL keys, but a
  boundary gate must read arbitrary commands, and importing tier0_action is itself Tier 0).

### 2026-10-13 — what Pattern 5 guarantees, and what it does not
- **Guarantees:** for every write target the scanner names (redirections `> >> >| &> &>>
  <> >&FILE` anywhere in a simple command; tee/sponge; cp/mv/install/ln/rsync destinations
  and `-t`; mv sources; dd `of=`; sed/perl/ruby `-i` (clusters, suffixes); awk inplace;
  sort `-o`; editors; patch; find `-fprint`/`-exec`; touch/mkdir/mkfifo/mknod/truncate/
  rm/rmdir/unlink/shred; chmod/chown/chgrp) and every absolute cd destination, the path is
  judged AFTER bash's quote removal, `\`-escapes, `$'..'` decoding (incl. `\cX`), tilde and
  brace expansion, cwd resolution of relative targets, and BOTH realpath and normpath —
  in the top-level text, in every `$(...)`, `` `...` ``, `<(...)`/`>(...)` body (inside
  double quotes too), in UNQUOTED heredoc bodies, and in static `sh -c` / `eval` scripts.
  Quoted heredoc bodies and single-quoted text are data, as in bash. A `<<EOF` inside a
  comment or quote no longer hides the following lines. Text that does not lex
  (unterminated quote/substitution, missing heredoc delimiter) is REFUSED.
- **Does not (same boundary as Tier 0, CLAUDE.md T-2742):** a script file the command
  runs (`bash x.sh`, `make`); a target built at run time (`$VAR`, `$(printf …)`, a path
  read from a file, a symlink created earlier in the same command); code inside an
  interpreter (`python -c`, `perl -e`, awk programs, `xargs` operands from stdin); write
  verbs the scanner does not name (curl `-o`, tar `-C`, git `-C` …). `cd ..`/relative cd is
  not judged as a cd (only absolute destinations, as before) — the writes after it are.
- **Costs accepted:** writes via `~` and relative `..` now block (HEAD saw only absolute
  paths); `cd /` stays allowed (the `cd /; rm -rf $T` idiom); the prefilter now names
  characters instead of verbs, so most Bash calls reach the Python pass (~170 ms per call
  vs ~80 ms measured on a no-path command). Census over 36,260 real agent commands from 320
  transcripts: 37 refused, every one inspected — already blocked on HEAD, a genuine
  outside write, or text bash itself mis-reads (an inner heredoc terminator ending the
  outer heredoc early).

### 2026-10-13 — shared-scanner changes and T-3695
- **Chose:** boundary-only behaviour is gated by `ctx.boundary`; the T-3695 `scan()` keeps
  its old reading and ADDS the lexer's reading when the command mentions a guarded path
  (union — only more refusals). Two fixes apply to both modes because both readings were
  wrong: `$'\cX'` consumes X (a quote included), and a perl cluster `-MFile::Find` is a
  module, not `-i` (it surfaced as a boundary false block in tests/unit/t4126…:89).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-13T13:45:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4149-security-project-boundary-hook-check-pro.md
- **Context:** Initial task creation

### 2026-10-13T13:46:49Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-10-13 — pre-fix evidence [t4149-fix worker]
- `tests/unit/t4149_boundary_parser_differential.bats` run with HEAD's hook AND HEAD's
  `lib/shell_write_scan.py` swapped in: 17 of 19 blocking tests `not ok` (all five
  verified cases + the same-class spellings); `ok` only for the plain-touch control and
  process substitution (HEAD's `()`-split regex already caught that one); 5/5 controls ok.
- With the fix: 24/24 ok, 0 skips. Repro `.context/scratch/t4125-repro.py`: all 5 cases
  BLOCKED (were allowed).
- Related suites (boundary unit/integration, tee, write-verbs, termlink scope, heredoc
  order, g065, review-credential, T-3695 bash/guard/comment-aware): green except
  integration "Bash redirect to /etc: blocked", red on HEAD too (`/etc/cron.d` zone).
- `tests/governance/test_pretooluse_gates.bats` test 5 (check-active-task, a hook not
  touched here) failed once in a shared-checkout run; it rewrites the live focus.yaml, so
  it was not re-run.
