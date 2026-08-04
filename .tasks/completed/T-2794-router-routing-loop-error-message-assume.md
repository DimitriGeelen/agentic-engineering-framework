---
id: T-2794
name: "Router routing-loop error message assumes framework-dev git knowledge a real
  onboarding user won't have"
description: >
  Router routing-loop error message assumes framework-dev git knowledge a real onboarding
  user won't have

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
created: 2026-08-04T17:58:43Z
last_update: 2026-08-04T18:03:35Z
date_finished: 2026-08-04T18:03:35Z
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
  - ts: '2026-08-04T18:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-04T18:00:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2794: Router routing-loop error message assumes framework-dev git knowledge a real onboarding user won't have

## Context

Found live during T-2792's real-directory onboarding rehearsal (T-2793's router deployed
today). A fresh `/tmp` directory with no vendored project falls back to the global install
at `$HOME/.agentic-framework`. On this host that install's `bin/fw` had been corrupted by
the pre-fix `cp`-through-symlink bug (install.sh's `link_fw`, fixed in the same T-2793
commit that added the router) — its content was the ~95-line router instead of the
7,836-line real CLI, so the router correctly self-detected a loop and refused with:

```
fw: routing loop — the fw found here is this router itself.
  Path: /root/.agentic-framework/bin/fw
  The real CLI is missing from that location. Known causes (T-1278):
    - bin/fw overwritten by an older 'fw upgrade' that wrote the router
      through the destination symlink into a framework repo's bin/fw
    - a manual mis-copy of the router over bin/fw
  Restore, from the affected framework repo:
    git checkout HEAD -- bin/fw
```

This message is correct and was genuinely how the on-host copy got fixed (confirmed via a
TermLink worker), but it assumes the reader already knows `~/.agentic-framework` is a git
clone with a restorable HEAD — true for a framework developer, not for the actual audience
of a fresh-install onboarding run (a brand-new user or agent following
`prompts/aef-fresh-install-onboarding.md`). That audience has no reason to know the global
install is a git checkout at all, and `git checkout HEAD -- bin/fw` run in the wrong
directory (e.g. their own project) is actively confusing/risky advice to hand to someone
who doesn't already understand the distinction.

The simpler, universally-correct remedy for this exact failure is: **re-run the installer**
(`install.sh`, piped or `--local`) — its existing update path does `git reset --hard`
against the pinned branch, which overwrites the corruption unconditionally, no git
knowledge required. `git checkout HEAD -- bin/fw` is a fine *secondary* one-liner for
someone who already knows they're in a framework git clone, not the primary instruction.

## Acceptance Criteria

### Agent
- [x] `bin/fw-router`'s routing-loop message leads with re-running the installer
      (piped `install.sh` one-liner, or `install.sh --local <path>` for a local checkout)
      as the primary remedy, before the `git checkout` line — with a one-line "why" so an
      agent/user without git-clone knowledge of the global install can still act on it.
      → `bin/fw-router`, routing-loop branch: primary line is the piped curl one-liner.
- [x] The message still tells a framework *developer* the `git checkout HEAD -- bin/fw`
      shortcut (secondary line), since that's genuinely faster when applicable.
      → labelled "Framework developer shortcut", `cd $(dirname $(dirname $_target)) && git
      checkout HEAD -- bin/fw` (computed from the resolved target, not hard-coded).
- [x] `tests/unit/fw_router.bats` gains a case asserting the new message contains the
      installer-based remedy text.
      → `refuses to exec itself (routing loop)` extended with two assertions
      (`install.sh` present, `git checkout HEAD -- bin/fw` present). 12/12 green.

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

out=$(bats tests/unit/fw_router.bats 2>&1); echo "$out" | grep -q '^ok 12 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 10 ' && ! echo "$out" | grep -q '^not ok'
bash -n bin/fw-router

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

**Symptom:** hitting the router's routing-loop refusal (a real, live event on this host,
see T-2792/T-2793) surfaces a one-liner remedy (`git checkout HEAD -- bin/fw`) that only
works for someone who already knows the failing path is inside a git checkout.

**Root cause:** the message was authored from the perspective of the person who wrote the
router (a framework developer, who knows `~/.agentic-framework` is `git clone`d by
`install.sh`) rather than the actual audience of a routing-loop failure — which, by
definition, fires for anyone whose `fw` resolution fell through to the global install,
including a brand-new onboarding user or agent who has never seen that directory's
internals.

**Why structurally allowed:** no review step checks whether an error message's remedy
matches the knowledge level of the population that can actually trigger the error path —
this is a general gap (error-message audience mismatch), not specific to the router.

**Prevention:** `tests/unit/fw_router.bats` now pins the message content (installer text
present), so a future edit that regresses to a git-only remedy fails CI. No broader
structural gate proposed here — the class is narrow (one message, one failure mode).

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

### 2026-08-04T18:05:00Z — fixed and verified [session S-2026-0804-1732]
- **Action:** Rewrote the routing-loop message in `bin/fw-router` to lead with the piped
  `install.sh` remedy (works with zero git knowledge, self-heals via the update path's
  existing `git reset --hard`), demoting `git checkout HEAD -- bin/fw` to a labelled
  "framework developer shortcut" secondary line, computed from `$_target` rather than
  hard-coded. Extended `tests/unit/fw_router.bats`'s existing routing-loop test with two
  assertions pinning both lines are present.
- **Output:** `bin/fw-router` updated; `fw_router.bats` 12/12 green;
  `upgrade_fresh_machine_simulation.bats` 10/10 green (no regression);
  `bin_executable_bits.bats` 4/4 green; `bash -n bin/fw-router` clean.
- **Context:** Found live during T-2792's real onboarding rehearsal — this host's global
  install had actually hit the routing-loop failure this message describes, and the
  original message's `git checkout` line was genuinely how it got fixed by hand, which is
  exactly what exposed the audience mismatch.

### 2026-08-04T17:58:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2794-router-routing-loop-error-message-assume.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-074cc03a
- **Timestamp:** 2026-08-04T18:04:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T18:03:35Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
