---
id: T-2807
name: "claude-fw on PATH must be a copy, not a symlink into the global install"
description: >
  claude-fw on PATH must be a copy, not a symlink into the global install

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
created: 2026-08-05T12:05:25Z
last_update: 2026-08-05T12:21:28Z
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
  - ts: '2026-08-05T12:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-05T12:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2807: claude-fw on PATH must be a copy, not a symlink into the global install

## Context

First build slice of T-2800 (operator GO, 2026-08-04: remove the framework from
`$HOME`, keep only the router). T-2803's survey found the ordering constraint that
gates every later slice:

> `install.sh` installs two things on PATH and treats them differently — the router
> is **copied**, `claude-fw` is **symlinked** into `$INSTALL_DIR` (`install.sh:259`,
> `:280`). Remove the global and `~/.local/bin/claude-fw` becomes a dangling symlink.

That takes T-179 auto-restart — the budget-critical recovery loop — with it, on every
host that migrates. `claude-fw` is a wrapper, not project-specific, so the symlink was
correct while `$INSTALL_DIR` was permanent. It stops being correct the moment
`$INSTALL_DIR` is temporary, which is the whole of T-2800.

How it fails is worse than a clean break, and measured rather than assumed — see
`## RCA`: a dangling symlink is skipped by `command -v`, so on a host with a second
`claude-fw` further down PATH the operator silently runs a *different* wrapper.

This slice does that one thing. The global still exists afterwards; nothing about
resolution changes. It is safe to land alone and it is a prerequisite for the
installer slice, not a consequence of it.

Second, smaller leg: `bin/fw:1801` tells the operator to refresh a drifted
`claude-fw` with `bash ~/.agentic-framework/install.sh`. That instruction is already
fragile (it assumes a git checkout in `$HOME`) and becomes false under T-2800. The
curl one-liner is correct under both models.

Design: `docs/reports/T-2803-global-install-dependency-survey.md` §"Finding the
design doc missed".

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Both branches of `link_fw` in `install.sh` install `claude-fw` by copy, not symlink: `rm -f` before `cp`, then `chmod +x`. No `ln -s` targeting `claude-fw` remains in `install.sh`.
- [x] The `rm -f`-before-`cp` guard is present on the claude-fw copy for the same reason it is on the router (T-1278/T-2793): a plain `cp` onto an existing symlink writes THROUGH it and overwrites the file in the global install.
- [x] `bin/fw` doctor's claude-fw drift remediation no longer instructs `bash ~/.agentic-framework/install.sh`; it names a path that works with no global checkout present.
- [x] Regression test `tests/unit/claude_fw_copy_not_symlink.bats` covers: (a) the installed claude-fw is a regular file, not a symlink; (b) it survives deletion of `$INSTALL_DIR`; (c) installing over a pre-existing symlink does not modify the symlink's target. Mutation-checked — each assertion shown to go red against the pre-fix code.
- [x] `tests/unit/bin_executable_bits.bats` and `tests/unit/upgrade_fresh_machine_simulation.bats` stay green (consumer-facing command hygiene).
- [x] The T-2501 drift detector (`bin/fw:1790-1805`) still reports OK for a freshly-copied claude-fw — a copy makes that check load-bearing rather than cosmetic, so it must not regress.

### Human
- [ ] [REVIEW] On your own host, `claude-fw` still launches and supervises a session after the change
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && ls -l ~/.local/bin/claude-fw` — note whether it is currently a symlink
  2. Re-run the installer one-liner, or by hand: `rm -f ~/.local/bin/claude-fw && cp /opt/999-Agentic-Engineering-Framework/bin/claude-fw ~/.local/bin/claude-fw && chmod +x ~/.local/bin/claude-fw` — the `rm -f` matters, a bare `cp` onto the current symlink would write through it into the global install
  3. `ls -l ~/.local/bin/claude-fw` — confirm it is now a regular file
  4. Start a session with `claude-fw` and run `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | grep -i supervis`
  **Expected:** step 3 shows a regular file (no `->`); step 4 prints `OK  Session supervised by claude-fw — budget auto-restart armed`
  **If not:** paste the `ls -l` output and the doctor line; the wrapper may predate the `FW_CLAUDE_FW_SUPERVISED` export, which the T-2501 drift check will also flag

## Verification

# --- T-2807 ---
# install.sh parses, and has no executable ln -s onto claude-fw left in either branch.
bash -n install.sh
! grep -qE '^[^#]*ln -s.*claude-fw' install.sh
# The copy helper exists and carries the rm-f-before-cp guard (T-1278/T-2793 class).
grep -q '^install_claude_fw()' install.sh
out=$(sed -n '/^install_claude_fw()/,/^}/p' install.sh); echo "$out" | grep -q 'rm -f "$local_bin/claude-fw"'
# Doctor's drift remediation no longer sends the operator to a $HOME git checkout.
! grep -q 'Refresh: bash ~/.agentic-framework/install.sh' bin/fw
# Regression suite (5) — judged on the pass marker AND the absence of a fail marker (T-2738).
out=$(bats tests/unit/claude_fw_copy_not_symlink.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# Sibling install suites stay green — consumer-facing command hygiene (T-1633).
out=$(bats tests/unit/bin_executable_bits.bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

**Symptom:** none yet — this is a latent defect, fixed before it fires. Under T-2800
the framework leaves `$HOME`, `~/.local/bin/claude-fw` becomes a dangling symlink, and
the T-179 auto-restart wrapper stops working. Confirmed live on this host 2026-08-05:
`/root/.local/bin/claude-fw -> /root/.agentic-framework/bin/claude-fw`.

**Root cause:** `install.sh` treated its two PATH artifacts differently — the router
copied, `claude-fw` symlinked — on a reason that was true at the time and stops being
true under T-2800: *"claude-fw still symlinks (it's a wrapper, not project-specific)"*.
Correct while `$INSTALL_DIR` is permanent. T-2800 makes it temporary, and the comment
records the wrong premise (project-specificity) for the right conclusion, so re-reading
it during the migration would have re-confirmed the symlink rather than questioned it.

**Why structurally allowed:** a dangling symlink is not executable, so `command -v`
skips it rather than resolving to it (verified 2026-08-05 in an isolated `env -i`
PATH — the first attempt at this measurement was contaminated by the host's own
`claude-fw` sitting later on PATH, which is the wrong-object class this session keeps
meeting). Two consequences, and neither surfaces as the failure it is:

- **Where another `claude-fw` exists on PATH, the operator silently runs that one.**
  This host has three: `~/.local/bin/claude-fw` (symlink → global), `/usr/bin/claude-fw`
  (a copy), and the repo's `bin/claude-fw`. Remove the global and the shell falls
  through to `/usr/bin` with no notice. Today that copy happens to be identical to
  repo source and carries the `FW_CLAUDE_FW_SUPERVISED` export — a stale one would
  have produced an unsupervised session with everything appearing to work.
- **Where none exists, `claude-fw` is command-not-found** — visible, but the natural
  response is to run plain `claude`, and *that* is the quiet part: an unsupervised
  session loses auto-restart at budget-critical with nothing to read.

The check that should notice (T-2501 claude-fw drift, `bin/fw:1790`) cannot: it is
reached only when `command -v` resolves, so it reports on whichever file won the PATH
fall-through, and reports `SKIP  claude-fw not on PATH` when none does. A SKIP reads
as "not applicable", not "the thing you rely on is gone".

**Prevention:** `tests/unit/claude_fw_copy_not_symlink.bats` (5 tests, mutation-checked
1/2/3/5 red against the pre-fix `ln -sf`). Test 5 greps `install.sh` itself, so a
future refactor that reintroduces a symlink in *either* branch of `link_fw` fails —
the two-branch shape is exactly how the first one gets fixed and the second survives.
Test 3 pins the `rm -f`-before-`cp` guard, which is the same defect class as T-2793's
router corruption in this same function; without it, "make it a copy" silently
overwrites the global's own wrapper on every migrating host.

**Not fixed here:** the PATH fall-through blind spot above. `fw doctor` still cannot
distinguish "operator never installed claude-fw", "claude-fw dangled", and "a second
claude-fw further down PATH is the one actually running". Filed as OBS-165 rather than
folded in — it is a detector change, not this slice.

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

### 2026-08-05T12:05:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2807-claude-fw-on-path-must-be-a-copy-not-a-s.md
- **Context:** Initial task creation
