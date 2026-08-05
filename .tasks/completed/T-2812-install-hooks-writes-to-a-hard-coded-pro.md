---
id: T-2812
name: "install-hooks writes to a hard-coded PROJECT_ROOT/.git/hooks and installs nothing
  when .git is elsewhere"
description: >
  install-hooks writes to a hard-coded PROJECT_ROOT/.git/hooks and installs nothing
  when .git is elsewhere

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
created: 2026-08-05T14:32:19Z
last_update: 2026-08-05T17:24:44Z
date_finished: 2026-08-05T17:24:44Z
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
  - ts: '2026-08-05T14:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-05T14:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-2812: install-hooks writes to a hard-coded PROJECT_ROOT/.git/hooks and installs nothing when .git is elsewhere

## Context

Found by running the operator's onboarding prompt to completion and then auditing
the resulting day-zero project (session 2026-08-05, after T-2809/T-2810/T-2811).

`agents/git/lib/hooks.sh` writes hooks to `$PROJECT_ROOT/.git/hooks/`. That path is
only correct when `.git` is a directory sitting directly at the project root. It is
wrong for at least three ordinary shapes:

1. **A project created inside an existing repo** (monorepo subdirectory). `fw init`
   deliberately does not nest a repo — `lib/init.sh:140` skips `git init` when
   `rev-parse --is-inside-work-tree` is true — so `$PROJECT_ROOT/.git` never exists
   and every hook write fails.
2. **A git worktree**, where `.git` is a *file* pointing elsewhere.
3. **A submodule**, where hooks live under the superproject's `.git/modules/…`.

Reproduced clean (not a contaminated fixture — the enclosing repo was created for
the test and the scratchpad's own stray `.git` was removed first):

```
$ fw init  <target inside an existing repo>     # no target/.git created, by design
$ fw git install-hooks
hooks.sh: line 53: <target>/.git/hooks/commit-msg: No such file or directory
chmod: cannot access '<target>/.git/hooks/commit-msg': No such file or directory
=== Hooks Installed ===
$ echo $?
0
```

Zero hooks land — not in the subdirectory, not in the enclosing repo. The project
runs with no commit-msg task-reference enforcement (P-002), no pre-commit secret
scan (T-1844), and no pre-push audit.

**Scope fence.** This task fixes *where* the hooks are written. The fact that the
command reported success while every write failed is a **separate** defect with its
own root cause and its own regression test — filed as T-2813. Do not fix both here.

Control case, for contrast: with no enclosing repo, `fw init` does run `git init` and
all four hooks install correctly. So this is specifically about `.git` not being at
`$PROJECT_ROOT`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The hooks directory is resolved by asking git (`git rev-parse --git-path hooks`, which is correct for a plain repo, a worktree, and a submodule alike) rather than by string-concatenating `$PROJECT_ROOT/.git/hooks`.
- [x] A project initialised inside an existing git repo gets its hooks installed into the repo that will actually run them, and a commit from that project is subject to the commit-msg task-reference check. Verified by making a real commit that should be rejected and observing the rejection — not by checking that files exist.
- [x] The plain-repo case (project owns its own `.git`) is unchanged: all four hooks still land in `<proj>/.git/hooks/`. Pinned by test, since this is the path everyone currently uses and the one a refactor is most likely to break silently.
- [x] Decide and record in `## Decisions` whether installing into an *enclosing* repo is correct at all, or whether `fw init` should instead refuse / warn when the target is inside someone else's repo. Writing hooks into a repo the operator did not point us at has its own blast radius — this AC exists so that choice is made deliberately rather than falling out of the path fix.
- [x] Regression coverage for the non-`$PROJECT_ROOT/.git` shape, mutation-checked — shown to go red against the current hard-coded path.
- [x] `bin/fw doctor`'s hook checks agree with the new resolution, so a correctly-installed project stops being reported as missing hooks (and an incorrectly-installed one still is).


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

bash -n agents/git/lib/hooks.sh
bash -n agents/git/lib/common.sh
bash -n bin/fw
out=$(bats tests/unit/git_install_hooks_git_path.bats 2>&1); echo "$out" | grep -q "^1..4" && ! echo "$out" | grep -q "^not ok"

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

**Symptom:** `fw git install-hooks` reported success and installed zero hooks
when run against a project created inside an existing repo (no local `.git`).

**Root cause:** `agents/git/lib/hooks.sh` computed the hooks directory by
string-concatenating `"$PROJECT_ROOT/.git/hooks"`. That expression assumes
`.git` is a directory sitting directly at `PROJECT_ROOT` — true only for the
plain, top-level-repo shape. It is false for a project nested inside an
enclosing repo (no local `.git` at all — `fw init` deliberately skips
`git init` there, `lib/init.sh:140`), a worktree (`.git` is a file pointing
at `<main>/.git/worktrees/<name>`, and hooks live in the *common* dir, not
that per-worktree dir), and a submodule (hooks live under the superproject's
`.git/modules/<name>/hooks`).

**Why structurally allowed:** the hard-coded path was written when the
plain-repo shape was the only shape ever exercised (dev machine, `fw init`
with no enclosing repo). Nothing checked the *assumption* that `.git` is a
directory at `PROJECT_ROOT` — no test exercised any other shape, and the
silent-failure-reports-success half of the symptom (filed separately as
T-2813) meant a wrong path never surfaced as an error either.

**Prevention:** `resolve_git_hooks_dir()` (`agents/git/lib/common.sh`) and
the equivalent inline resolution in `bin/fw doctor` now ask git itself
(`git rev-parse --git-path hooks`), which is correct for all three shapes by
construction — there is no second hard-coded path to drift. Regression
coverage: `tests/unit/git_install_hooks_git_path.bats` (4 tests: plain repo,
nested project + a real rejected commit, worktree) — mutation-checked, 3 of
4 go red against the pre-fix hard-coded path.

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

### 2026-08-05 — Install into the enclosing repo (don't refuse/warn) in this task; scope a warn separately

- **Chose:** When `PROJECT_ROOT` has no local `.git` and resolves to an
  enclosing repo's hooks dir, `install-hooks` still installs there — it does
  not refuse. This is what AC2 requires (a commit from the nested project
  must actually be subject to the commit-msg check), and matches `fw init`'s
  existing choice not to nest a repo (`lib/init.sh:140`): if the framework
  already decided this project shares the enclosing repo, hooks belong where
  commits are actually made.
- **Why:** Git hooks cannot be scoped to a subdirectory — the enclosing
  repo's `commit-msg`/`pre-push` hooks fire for *every* commit in that repo,
  not just ones touching the nested project's files. That's real blast
  radius (an operator's unrelated commits elsewhere in the enclosing repo
  would suddenly require a `T-XXX` reference), but it's inherent to git's
  design, not something a path fix can avoid — the only alternative to
  "install into the enclosing repo" is "don't install at all", which
  reproduces the original bug (silent no-op enforcement) under a different
  name.
- **Rejected:** Making `install-hooks` (or `fw init`) refuse/warn when the
  target is nested inside another repo. Left as a follow-up rather than
  folded into this task's scope fence — it's a UX/warning question about
  *whether a human should be told*, decoupled from *where the bytes land
  once they decide to proceed*, and doesn't need the path-resolution fix to
  land first. Not filed as a separate task since it's speculative (no
  operator has hit this shape and asked for a warning yet); if it recurs in
  practice, file then with a concrete case.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-05T14:32:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2812-install-hooks-writes-to-a-hard-coded-pro.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-802e4b90
- **Timestamp:** 2026-08-05T17:24:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-05T17:24:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
