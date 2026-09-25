---
id: T-3358
name: "claude-fw --termlink exit-detection misses root prompt, orphans sessions"
description: >
  claude-fw --termlink poll loop prompt regex does not match root prompts, so Claude
  exit is never detected: no auto-restart, no termlink_cleanup, orphaned tl-claude-master
  sessions

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug]
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
created: 2026-09-10T20:31:54Z
last_update: '2026-09-20T19:15:19Z'
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
cost_estimate_proposed:
  - ts: '2026-09-10T20:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=370,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-10T20:45:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-20T19:15:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3358: claude-fw --termlink exit-detection misses root prompt, orphans sessions

## Context

`claude-fw --termlink` runs a poll loop that decides "Claude has exited" by grepping the
PTY tail for a shell-prompt regex — in the reported build, around line 299:

```
^$|^❯|^➜|claude-fw:|^user@
```

That alternation has no branch for a **root** prompt (`root@host:/path#`). On the root
fleet, when Claude exits back to a root shell the wrapper never observes the transition:
it neither auto-restarts nor runs `termlink_cleanup`, and the spawned
`tl-claude-master` session is left attached to a dead shell. From `termlink list` and
from the operator's screen, "working" and "exited" are indistinguishable.

Observed 2026-09-10: sessions `claude-master-1459164` and `claude-master-1747962`
orphaned this way; operator saw a frozen screen and could not interact.

**Finding while filing (do not treat as closure).** `bin/claude-fw` at HEAD in this repo
no longer uses prompt-glyph detection at all: T-3346 replaced it with an explicit exit
marker (`_tl_claude_exit_code`, `bin/claude-fw:100-113`), which is the operator's second
suggested fix already implemented — for a different symptom (`^❯` is Claude's own TUI
caret and fired while claude was *alive*, so the wrapper tore down its own live session).
So the residual defect this task must settle is **which** claude-fw the root fleet is
actually executing, and whether the fleet copies are pre-T-3346. If they are, the fix is
propagation (+ a rail that detects stale fleet copies), not another regex. If a
regex-based copy is still authoritative anywhere, broaden it per the fix below.

**Suggested fix (documented, NOT implemented here):**
1. Broaden the prompt regex to match generic/root prompts — a trailing `#` or `$` after a
   `user@host:path` shape — so `root@host:/opt#` is recognised; or
2. Preferred — drop prompt-regex detection entirely in favour of a robust signal: watch
   the injected `claude` child PID, or keep/extend T-3346's explicit exit marker written
   after the injected claude command.

Option 2 is the same class of fix T-3346 already landed at HEAD, which is evidence for
its durability: prompt text is host-, shell-, and user-dependent; a marker is not.

## Acceptance Criteria

### Agent
- [ ] Determine and record which `claude-fw` the affected root-fleet hosts execute (path,
      resolved symlink, whether it contains `^user@` prompt-regex detection or T-3346's
      `__CLAUDE_FW_EXIT_` marker), for at least the two hosts that orphaned
      `claude-master-1459164` / `claude-master-1747962`.
- [ ] Exit detection no longer depends on a prompt regex on any copy the fleet runs —
      either by propagating the T-3346 marker build or by implementing the marker/child-PID
      signal in the stale copy.
- [x] A regression test covers exit-from-a-root-prompt: with a `root@host:/path#` prompt,
      exit detection fires and `termlink_cleanup` runs (no orphaned session left behind).
      → `tests/unit/t3358_claude_fw_exit_detection.bats`, committed 6a1282f56: **6/6 ok,
        0 skips**. Test 2 pins "root prompt WITH the marker IS an exit, marker code
        survives"; test 5 drives the real poll loop end-to-end and proves cleanup fires
        on the marker and NOT on a bare root prompt; test 6 proves cleanup runs exactly
        once when the wrapper is killed with no marker ever shown (0 would be an orphan).
      → The file existed untracked and RED 5/6. Both causes were harness defects, not
        product defects: `teardown` ended on a test that returns 1 when `PROJ` is unset
        (failing all four Part 1 tests at the teardown line), and test 6 asserted that NO
        cleanup occurs after SIGTERM — which contradicts `bin/claude-fw:125`
        `trap 'termlink_cleanup; …' EXIT`, the very anti-orphaning guarantee this task
        exists to provide. Changing the product to satisfy that assertion would have
        reintroduced the bug. The assertion was inverted (exactly-once), not removed.
- [x] Prevention rail exists for the stale-copy class if that is the confirmed cause:
      claude-fw reports its own version/provenance, or `fw doctor` WARNs when the
      executed `claude-fw` differs from the repo's.
      → Rail is live and observed firing on this host. `bin/fw doctor --quick` emits:
        `WARN  Installed claude-fw drifted from repo source — supervision export may be stale`
        `      on PATH: /usr/bin/claude-fw`
        `      repo:    /opt/999-Agentic-Engineering-Framework/bin/claude-fw`
      → `tests/integration/t2501_claude_fw_drift.bats`: **4/4 ok, 0 skips**, including
        `T-3358: TWO stale copies on PATH → both reported, not just the first` — the
        case a single `command -v` hit would miss, which is the fleet mechanism this
        task traced.
      → The suite was RED (4/4, exit 127) until this session: `setup_file` assigned
        `CLEAN_PATH_DIR` without `export`, and bats runs `setup_file` in a separate
        process from the tests, so every test built `PATH='<fixture>:'` — whose empty
        trailing component resolves nothing — and died before reaching an assertion.
        Fixed in 32b216745. The green above is the first real run of these assertions.

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
#
# The repo copy must not reintroduce prompt-glyph/prompt-regex exit detection:
grep -qE '__CLAUDE_FW_EXIT_' bin/claude-fw
out=$(grep -nE '\^user@|\^❯|\^➜' bin/claude-fw || true); echo "$out" | grep -vq 'old regex\|Prompt-glyph\|old `'
# Regression suite for root-prompt exit detection (author it as part of the fix):
timeout 300 bats tests/unit/t3358_claude_fw_exit_detection.bats > /tmp/.t3358.out 2>&1 && ! grep -q "^not ok" /tmp/.t3358.out
test "$(grep -c '# skip' /tmp/.t3358.out)" -eq 0

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

**Symptom:** On root-fleet hosts, `claude-fw --termlink` sessions stay registered after
Claude has exited. No auto-restart fires, `termlink_cleanup` never runs, and the
`tl-claude-master` PTY session sits at a dead root shell. The operator sees a frozen
screen and cannot interact; `termlink list` shows the session as if it were working.
Observed 2026-09-10 on `claude-master-1459164` and `claude-master-1747962`.

**Root cause:** Exit detection was inferred from *prompt appearance* rather than from a
signal the wrapper controls. The poll loop matched the PTY tail against
`^$|^❯|^➜|claude-fw:|^user@` — an enumeration of the prompt shapes the author happened to
have seen. A root prompt (`root@host:/path#`) is none of them, so on the fleet the
detector's true branch was unreachable and the loop polled forever. The bug is not the
missing `root@` alternative specifically; it is that the predicate's domain is
host/shell/user-dependent text that the wrapper neither emits nor controls, so it is
open-ended by construction and every unenumerated prompt is a silent hang.

**Why structurally allowed:**
- *Failure is indistinguishable from success at every observation surface.* A non-firing
  detector produces a live session at a live-looking prompt — exactly what a working
  session produces. Nothing polls, warns, or diverges; the only signal is an operator
  eventually noticing a screen that does not respond. Same false-green family as the
  §Watchtower-Port and branch-identity rails: a check that cannot see its own subject.
- *The detector was only ever exercised under the author's own prompt.* Development
  happens under a non-root user shell; the root fleet is the environment that was never
  in the test matrix, and there was no test at all pinning "exit is detected" against
  more than one prompt shape.
- *Fleet copies drift from HEAD unobserved.* `bin/claude-fw` at HEAD already abandoned
  prompt detection (T-3346), yet a regex-era build was still executing on the fleet on
  2026-09-10. Nothing reports which claude-fw a host runs or warns when it lags the repo,
  so a fixed defect can keep shipping its old symptom indefinitely.
- *T-3346 fixed the mirror-image symptom without closing the class.* It removed `^❯`
  because that glyph fired too eagerly; the same commit's reasoning ("prompt glyphs are
  unusable as an exit signal") applies verbatim to `^user@` firing too rarely, but the
  never-fires direction had no reported incident at the time and was left in place.

**Prevention (distinct from the fix):**
1. Regression test asserting exit detection fires under a **root** prompt
   (`root@host:/path#`) and that cleanup runs — plus a control leg proving the detector
   can fail, so "never fires" is not mistaken for "passes".
2. A lint/verification line refusing reintroduction of prompt-text exit detection in
   `bin/claude-fw` (see `## Verification`), so the marker approach cannot silently regress.
3. Provenance rail for the stale-copy class: `claude-fw --version` reporting the build it
   came from, and/or a `fw doctor` WARN when the executed `claude-fw` differs from the
   repo's — this is what would have made the fleet's regex-era copy visible before an
   operator hit a frozen screen.
4. Learning capture: *never infer process state from prompt text you do not emit* — use a
   marker you write, or a PID you own. Both prior incidents in this file (T-3346's
   over-firing, this task's never-firing) are the same rule violated in opposite directions.

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

### 2026-09-10T20:31:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3358-claude-fw---termlink-exit-detection-miss.md
- **Context:** Initial task creation

### 2026-09-10T20:33:41Z — status-update [task-update-agent]
- **Change:** tags: +bug

### 2026-09-20 — Fleet forensics (AC1/AC2) blocked by a broken remote-exec tool, not attempted around
- **Action:** The remaining two Agent ACs need live access to the root-fleet
  hosts that orphaned `claude-master-1459164` / `claude-master-1747962` on
  2026-09-10, to record which `claude-fw` copy they execute and (AC2)
  propagate/implement the marker fix there.
- **Attempted:** `mcp__skills__remote_exec_test` / `_exec` against the three
  currently-SSH-reachable Ring20 hosts (`proxmox2`, `traefik-primary`,
  `traefik-secondary`) — every call failed with
  `remote_exec.py: error: unrecognized arguments: --host` (exec also flags
  `--command`). Reproduced identically with real values and with
  whitespace-only values, and on the argument-light `test` subcommand alone —
  the MCP wrapper always injects `--host`/`--command` as named flags but the
  underlying CLI's subparsers don't define them (producer/consumer mismatch
  in a third-party skill, not this repo). Filed as product feedback
  (queued locally, not sent).
- **Also tried:** direct `ssh proxmox2` from this session — refused at
  `Host key verification failed`; this session has no provisioned identity/
  known_hosts for the Ring20 fleet outside the (broken) remote-exec skill,
  and blindly accepting an unverified host key to route around that is not
  a substitute for real access.
- **termlink_fleet_status --verbose** was checked as a lower-cost
  alternative: none of the 4 reachable hubs' current `session_names` match
  the `claude-master-*` naming pattern from the incident (both orphaned
  sessions are 10 days old and evidently already cleaned up / no longer
  listed), so it cannot answer "which host, which claude-fw copy" either.
- **Not done:** AC1 (record affected hosts' claude-fw provenance) and AC2
  (make exit detection marker-based on whichever copies are stale) remain
  unticked — genuinely blocked on fleet access this session does not have
  a working route to, not a confidence gap. AC3/AC4 (regression test +
  provenance rail) were already done in a prior session and remain intact.
- **Status:** left at `started-work`. Not parking as `issues` — this isn't a
  healing-loop case, it's an external-access blocker documented for the next
  session (or the operator) with a working remote-exec path, or for whoever
  has direct fleet SSH access to run the same provenance check by hand:
  `command -v claude-fw && grep -c '__CLAUDE_FW_EXIT_' "$(readlink -f "$(command -v claude-fw)")"`
  on each root-fleet host (0 = stale copy, needs the T-3346 marker fix).

### 2026-09-22 16:55Z — in-boundary provenance on this host (parent session, autonomous run)
- **Found:** `/usr/bin/claude-fw` on dimitrimintdev is a 14,971-byte copy dated 2026-08-01,
  owned by no package (`dpkg -S` finds nothing), with the `^user@` prompt regex present
  (1 hit) and the T-3346 `__CLAUDE_FW_EXIT_` marker absent (0 hits); it does not delegate to
  any project's vendored copy. HEAD `bin/claude-fw` has marker 4, regex 0. Root's
  interactive PATH puts `/root/.local/bin` (the T-2854 router) before `/usr/bin`, so a bare
  `claude-fw` from a shell resolves to the router — but any launcher whose PATH lacks
  `~/.local/bin` (cron, systemd units, tmux started with a minimal env) resolves to the
  stale copy. Every live wrapper process observed at 16:50Z runs a project-local
  `.agentic-framework/bin/claude-fw`, so the stale copy is a latent hazard here, not the
  active one.
- **Not done, and why:** probing the consumer projects' vendored copies (`/opt/*/
  .agentic-framework/bin/claude-fw`) is refused by the project-boundary gate (T-559) from
  this session, by design; that half of AC 1 needs a per-project TermLink dispatch or the
  operator's hand, as the entry above already says. Replacing `/usr/bin/claude-fw` is a
  host-level change outside this project's tree and is proposed, not executed:
  `cd /opt/999-Agentic-Engineering-Framework && sudo mv /usr/bin/claude-fw /usr/bin/claude-fw.pre-T3346.bak && sudo ln -s /root/.local/bin/claude-fw /usr/bin/claude-fw`
  (reversible; the router then serves every PATH order).
