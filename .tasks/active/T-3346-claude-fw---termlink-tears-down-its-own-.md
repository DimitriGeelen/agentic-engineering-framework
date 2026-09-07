---
id: T-3346
name: "claude-fw --termlink tears down its own live claude — exit-detect false-positives on TUI caret"
description: >
  claude-fw --termlink tears down its own live claude — exit-detect false-positives on TUI caret

status: work-completed
workflow_type: build
owner: human
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
created: 2026-09-07T20:59:55Z
last_update: 2026-09-07T21:05:44Z
date_finished: 2026-09-07T21:05:44Z
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

# T-3346: claude-fw --termlink tears down its own live claude — exit-detect false-positives on TUI caret

## Context

`claude-fw --termlink` (bin/claude-fw:514-549) injects `claude` into a detached
TermLink PTY and then polls `termlink pty output --lines 3` for a shell-prompt
regex `^\$|^❯|^➜|claude-fw:|^user@` to decide "claude exited". But `❯` is Claude
Code's own TUI input caret — on screen the entire time claude is RUNNING — so the
wrapper false-positives within ~1 minute of every launch, concludes claude exited,
proceeds to its own exit, and the EXIT trap (`termlink_cleanup`) injects `exit`
into the PTY, killing the live claude TUI. Captured live 2026-09-07 22:52-22:53 on
session `claude-master-3884548` (tl-soxuds4g): registration succeeded, menu
rendered, then `exit` appeared at the caret with no human input. Sibling defect:
the regex also fails to match the actual root prompt (`root@host:…#`), so a REAL
claude exit would never be detected either. Follow-on from the T-3345 crash-loop
investigation (G-098 daemon-launch thread) — this is the reason `--termlink`
launches never stay alive long enough to be attached.

## Acceptance Criteria

### Agent
- [x] Injected command line appends an explicit exit marker (`printf '__CLAUDE_FW_EXIT_%s__\n' "$?"`) so claude's termination is signalled by content the PTY echo of the injection itself cannot produce (echo carries literal `%s`, real output carries digits)
- [x] A named helper `_tl_claude_exit_code` in bin/claude-fw parses the marker: returns non-zero (still running) on TUI-caret-only screens AND on the echoed `%s` form; prints claude's real exit code and returns 0 when a digit marker is present
- [x] The poll loop uses the helper; the prompt-glyph regex (`^\$|^❯|^➜|…`) is gone from bin/claude-fw
- [x] Regression test `tests/unit/t3346_termlink_exit_marker.bats` lifts the helper from the real wrapper source (house style: claude_fw_restart_mode.bats) and is green — caret screen no-exit, `%s` echo no-exit, digit marker parsed with correct code
- [x] `bin/fw vendor self --check` clean (bin/ touched)

### Human
- [ ] [REVIEW] A relaunched `claude-fw --termlink` session stays alive and attachable
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/claude-fw --termlink`
  2. Wait 3+ minutes (past the old ~1-min teardown window), then from a second terminal: `cd /opt/999-Agentic-Engineering-Framework && termlink list | grep claude-master`
  3. `termlink attach claude-master-<PID>` (PID from the wrapper's startup banner) — interact with the Claude TUI
  **Expected:** Session still `ready` after 3 minutes; attach shows the live Claude console; no unprompted `exit` appears at the caret
  **If not:** `termlink pty output claude-master-<PID> --strip-ansi | tail -30` and note what the screen shows; the wrapper's stdout will say which exit branch fired

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

timeout 300 bats tests/unit/t3346_termlink_exit_marker.bats > /tmp/.t3346-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3346-bats.out
test "$(grep -c '# skip' /tmp/.t3346-bats.out)" -eq 0
grep -q "__CLAUDE_FW_EXIT_" bin/claude-fw
! grep -q "➜" bin/claude-fw
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

**Symptom:** Every `claude-fw --termlink` launch registers fine, opens the Claude
TUI in the detached PTY, and dies ~1 minute later — the PTY shows an unprompted
`exit` typed at the caret and the shell prompt returns. Operators see a registered
session with "nothing happening", concluding TermLink mode is broken (2026-09-07,
session claude-master-3884548 / tl-soxuds4g).

**Root cause:** The exit-detection poll (bin/claude-fw:545) grepped the last 3 PTY
lines for shell-prompt glyphs `^\$|^❯|^➜|claude-fw:|^user@`. `❯` is Claude Code's
own TUI input caret, rendered continuously while claude RUNS — so "claude exited"
fired while claude was alive. The wrapper then fell through to exit, and the EXIT
trap's `termlink_cleanup` injected `exit` into the PTY, killing the claude it had
launched. Inverse defect in the same regex: the actual prompt on this host is
`root@…#`, matched by nothing — a real exit would spin forever undetected.

**Why structurally allowed:** The detection was a heuristic over rendered screen
content with no test — no fixture of what a live Claude TUI screen actually looks
like ever met the regex. The failure is silent and self-erasing: the wrapper exits
0, cleanup looks like user action (`exit` at the caret), and the surviving
registration ("ready", empty shell) reads as "session idle" not "session
murdered". Same false-green family as G-096/T-3187 — the check answered a question
adjacent to the one it appeared to answer.

**Prevention:** Detection no longer interprets screen glyphs at all — the injected
command line prints an explicit `__CLAUDE_FW_EXIT_<code>__` marker only when
claude terminates, and the echo of the injection cannot match (it carries literal
`%s`). Regression test t3346_termlink_exit_marker.bats lifts the helper from the
live wrapper source and pins caret-screen ≠ exit, echo ≠ exit, marker = exit with
the real code.

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
**Rationale:** The false-positive is proven from a live capture (unprompted `exit`
at the caret on claude-master-3884548, 2026-09-07) and the fix removes the
heuristic entirely: exit is now signalled by an explicit marker the injection's
own echo cannot produce, carrying claude's real exit code. 8/8 new tests lift the
helper from the live source; 49/49 neighboring claude-fw suites still green;
vendored copy synced. What remains is the one thing only you can do: relaunch
`claude-fw --termlink` on your terminal and confirm the session now survives and
attaches — the exact workflow that was failing.
**Evidence:**
- `bin/claude-fw`: `_tl_claude_exit_code` + marker injection replace the `^❯` prompt-glyph grep (the caret was Claude's own TUI input line)
- `tests/unit/t3346_termlink_exit_marker.bats` — 8/8 ok, including the caret-screen and `%s`-echo no-exit legs
- claude_fw_router / restart_mode / copy_not_symlink / restart_sentinel_ttl / t3243 / t3253 — 49/49 ok
- `bin/fw vendor self --check` — in sync

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

### 2026-09-07T20:59:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3346-claude-fw---termlink-tears-down-its-own-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-052f8886
- **Timestamp:** 2026-09-07T21:05:50Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Human)** — [REVIEW] A relaunched `claude-fw --termlink` session stays alive and attachable
  - **human-ac-mechanical-signal** (partial, heuristic) — `matched='shows the l' in Expected: Session still `ready` after 3 minutes; attach shows the live Claude console; no unprompted `exit` appears at the caret`

### 2026-09-07T21:05:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
