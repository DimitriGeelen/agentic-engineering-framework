---
id: T-2759
name: "fw upgrade silently redirects steps 5-10 to the wrong directory and still reports
  success"
description: >
  lib/upgrade.sh:1305 declares 'local target_dir' INSIDE do_upgrade, which already
  binds target_dir to the consumer path at :566. Bash re-local in the same scope reassigns,
  so from that point target_dir is dirname(readlink -f ~/.local/bin/fw). Steps 5-10
  (.claude/settings.json, .mcp.json, resume.md, scripts/, context subdirs, .framework.yaml
  version pin, enforcement baseline) then write to that directory instead of the consumer.
  Proven live 2026-08-03: run exits 0, prints 'Upgrade Complete', consumer pin stays
  at its old value and receives no settings.json/.mcp.json/resume.md. Consumer appears
  permanently behind despite successful upgrades. Fires whenever ~/.local/bin/fw is
  a symlink whose target ends in /bin/fw and has no FRAMEWORK.md alongside.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh, tests/unit/lib_upgrade.bats, tests/unit/t2759_upgrade_target_dir_shadowing.bats]
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
created: 2026-08-03T10:34:32Z
last_update: 2026-08-03T11:45:57Z
date_finished: 2026-08-03T11:45:57Z
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
  - ts: '2026-08-03T10:35:43Z'
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
  - ts: '2026-08-03T10:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2759: fw upgrade silently redirects steps 5-10 to the wrong directory and still reports success

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `do_upgrade`'s `target_dir` is never rebound after entry. The shim-migration
      block at `lib/upgrade.sh:1305` uses a distinctly-named local.
      Renamed to `_shim_link_dir` (91bf98243).
- [x] Regression test reproduces the redirect end-to-end with a controlled `$HOME`
      (symlinked `~/.local/bin/fw` → a decoy `.../bin/fw` with no sibling FRAMEWORK.md)
      and asserts the consumer — not the decoy — receives `.claude/settings.json`,
      `.mcp.json` and `resume.md`, and that the consumer's `version:` pin advances.
      `tests/unit/t2759_upgrade_target_dir_shadowing.bats` (7868f4fa0), 6/6 green.
- [x] The test fails against the pre-fix code. A test that merely passes afterwards
      does not distinguish "fixed" from "never exercised that path".
      Verified in an isolated `git worktree` at HEAD~1 (pre-rename): 5 of 6 tests
      hang indefinitely (do_upgrade never returns once target_dir is corrupted —
      an even stronger failure signal than a clean red), the 6th (structural
      "declared once" guard) fails cleanly. Worktree removed after verification.
- [x] No other `local` re-declaration shadows an outer binding inside `do_upgrade`
      — checked as a set, since the defect class is the re-declaration, not this line.
      Audited programmatically: only `fw_version` (:883/:1861) and `upgrade_ts`
      (:1917/:1940) redeclare, both reassigning the identical value/meaning each
      time — harmless, unlike `target_dir` which meant something different at
      each site. See RCA "Prevention" #3.
- [x] `tests/unit/lib_upgrade.bats` tests 10-12 go green (they were red on this plus
      T-2758; both causes must be gone), and
      `tests/unit/upgrade_fresh_machine_simulation.bats` stays green.
      12/12 + 7/7 green. Tests 10-12's actual cause on this host was a THIRD,
      test-isolation gap (see Verification block below), not directly T-2758 or
      T-2759 — `setup()` never scoped `$HOME`, so the ambient host's real
      `~/.local/bin/fw` (which resolves into a self-vendored copy carrying its
      own FRAMEWORK.md) tripped the unrelated T-1278 guard and aborted the whole
      upgrade at step 4c, before steps 5-10 ran. Fixed in the same commit
      (7868f4fa0) by scoping `$HOME` per-test.

**Severity — this is a silent false-green, not a crash.** Live repro 2026-08-03 against
a bare consumer with a fake `$HOME`:

```
[9/10] Version tracking
[10/10] Enforcement baseline
=== Upgrade Complete ===          # exit 0
```

and afterwards the consumer had **no** `.claude/settings.json`, **no** `.mcp.json`, **no**
`resume.md`, and `version: 1.0.0` unchanged — while the decoy directory held all three.
A consumer in this state receives no hook updates and no governance refresh, and its pin
never advances, so it reads as permanently "behind" no matter how many times the operator
upgrades it. Every one of those upgrades reports success.

This is the same failure *direction* as L-534: the check is green about the wrong object.
A red step gets investigated at the next run; a green step that wrote to the wrong place
is indistinguishable from one that wrote to the right place, so nothing ever prompts a look.

**Relation to the 2026-08-03 operator downgrade report.** Their consumer printed
`Pinned: v1.6.354` against a framework at v1.6.8. A pin that will not advance is exactly
what this defect produces. Not asserted as *the* cause — that host is out of this session's
boundary and unverified — but it is a mechanism that produces the reported symptom, and it
is on the same command. T-2756 remains the task for the bootstrap-clone question.

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

out=$(bats tests/unit/t2759_upgrade_target_dir_shadowing.bats 2>&1); echo "$out" | grep -q '^1\.\.6' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/lib_upgrade.bats 2>&1); echo "$out" | grep -q '^1\.\.12' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^1\.\.7' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom.** `fw upgrade` prints every step, prints `=== Upgrade Complete ===`, exits 0 —
and the consumer receives none of steps 5-10. Measured on a controlled fixture: no
`.claude/settings.json`, no `.mcp.json`, no `.claude/commands/resume.md`, `version:` still
`1.0.0`; 30+ files (settings, mcp config, 11 scripts, 10 command docs, the `.context`
subdirectory tree) landed in the shim's symlink-target directory instead.

**Root cause.** `lib/upgrade.sh:1305` declared `local target_dir` inside `do_upgrade`,
which already binds `target_dir` to the consumer at `:566`. Bash does not open a new scope
for a second `local` in the same function — it rebinds the existing name. From that line
on, `target_dir` was `dirname(readlink -f ~/.local/bin/fw)`.

**Trigger.** `~/.local/bin/fw` is a symlink whose resolved path ends in `/bin/fw`, with no
`FRAMEWORK.md` beside its parent. The `FRAMEWORK.md` check is a *protective refusal* added
by T-1278; when it fires the upgrade aborts, which is loud. The bug lives in the path where
that refusal does **not** fire — i.e. exactly the machines the protection judged safe.

**Why structurally allowed.**
1. *Bash's `local` is not a scope.* The line reads like an ordinary temporary. Nothing in
   shell warns on it, `shellcheck` does not flag re-`local` in the same function, and the
   name collision is 739 lines from the original binding — far past what a reviewer holds.
2. *The failure direction hid it.* The run exits 0. A consumer in this state simply never
   changes: its pin does not advance, so it reads as "behind" forever and every upgrade
   reports success. There is no red step to investigate. This is the L-534 shape — the
   check was green about the wrong object — and the same reason T-2732's port-3000 class
   reached 371 instances rather than 3.
3. *No test drove the branch.* `upgrade_fresh_machine_simulation.bats` runs under `env -i`
   with a minimal PATH and no `~/.local/bin/fw` symlink, so the shim-migration path it was
   built to protect is the one path it does not enter. The suite covered the command; it
   did not cover this branch of it.

**Prevention.**
1. `tests/unit/t2759_upgrade_target_dir_shadowing.bats` — drives the real `bin/fw upgrade`
   with a controlled `$HOME` so the branch is genuinely taken, and asserts destination for
   three artefacts, the pin, and that *nothing* lands in the link directory. Verified to
   fail against the pre-fix code; a test that only passes afterwards cannot tell "fixed"
   from "never exercised".
2. A structural test asserting `target_dir` is bound exactly once inside `do_upgrade` —
   the defect class is the re-declaration, not this one line.
3. Audited every duplicate `local` in `do_upgrade` as a set rather than fixing the observed
   line: `fw_version` (`:883`, `:1861`) and `upgrade_ts` (`:1917`, `:1940`) are also
   re-declared, both assigning the identical value, so both are harmless. Stated here so
   the next reader does not have to re-derive that they are safe.

**Not claimed.** That this caused the 2026-08-03 operator downgrade. It produces a pin that
never advances, which matches the reported `Pinned: v1.6.354`; it does not move a version
backwards, which is what that host actually saw. Different mechanism, same command — see
T-2760 for the distinction and T-2756 for the bootstrap-clone question.

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

### 2026-08-03T10:34:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2759-fw-upgrade-silently-redirects-steps-5-10.md
- **Context:** Initial task creation

### 2026-08-03T10:35:42Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ebb9f2b1
- **Timestamp:** 2026-08-03T11:47:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/t2759_upgrade_target_dir_shadowing.bats 2>&1); echo "$out" | grep -q '^1\.\.6' && ! echo "$out" | grep -q '^not ok'`

### 2026-08-03T11:45:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
