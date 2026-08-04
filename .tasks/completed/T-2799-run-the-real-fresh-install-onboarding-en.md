---
id: T-2799
name: "run the real fresh-install onboarding end to end from GitHub master in an isolated
  HOME; fix every break"
description: >
  run the real fresh-install onboarding end to end from GitHub master in an isolated
  HOME; fix every break

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/install_verify_no_cwd_init.bats]
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
created: 2026-08-04T20:26:45Z
last_update: 2026-08-04T21:15:39Z
date_finished: 2026-08-04T21:15:39Z
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
  - ts: '2026-08-04T20:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-04T20:30:12Z'
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
---

# T-2799: run the real fresh-install onboarding end to end from GitHub master in an isolated HOME; fix every break

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The installer is fetched from the **public GitHub master** a new user would hit and
      run under an isolated `HOME`, so the host's live `~/.local/bin/fw` and
      `/root/.agentic-framework` are never touched.
      → `env -i HOME=/tmp/t2799-run1-home PATH=... bash -c 'curl -fsSL
      https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh
      | bash'` run from `/tmp/t2799-run1-cwd`, entirely outside this host's real `$HOME`.
- [x] Every onboarding step (prereqs → install → init → session/health → Watchtower) is
      **executed** against that install, with each failure recorded verbatim.
      → See Updates for the full step-by-step log across two full end-to-end passes
      (pre-fix and post-fix), including the verbatim `curl | bash` install log and the
      live-cwd corruption evidence.
- [x] Every failure found is fixed, or filed with its reproduction. No failure left
      described-but-unowned.
      → One blocking failure found (installer's own verify step silently initialised a
      project in the caller's cwd) — fixed in `install.sh` (landed via T-2800's commit,
      see RCA and Updates). Two non-blocking findings from this same investigation
      thread (fw init non-atomic; `fw watchtower url` foreign-port fallback) filed as
      their own one-bug-one-task tickets: **T-2801**, **T-2802**.
- [x] After the fixes, a **second** clean run in a fresh isolated HOME reaches a live
      Watchtower whose `/api/_identity` names the new project — verified by fetching it,
      not by the absence of an error.
      → Final run fetched the real `install.sh` from **public GitHub master** (which by
      then carried the fix), isolated HOME, fresh cwd (confirmed empty afterward), ran
      init/context-init/doctor (0 failures), started Watchtower on port 3996, and
      `curl http://localhost:3996/api/_identity` returned
      `{"project_root":"/tmp/t2799-final-project",...}`. See Updates.
- [x] The operator is handed no commands to run as part of this task's verification.
      → All verification below is self-contained (bats regression test); nothing asks
      the operator to run anything.

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

grep -q 'cd "$INSTALL_DIR" && "$fw_path" doctor' install.sh
bats tests/unit/install_verify_no_cwd_init.bats > /tmp/.t2799-verify.out 2>&1 && grep -q '^ok 1 ' /tmp/.t2799-verify.out
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

**Symptom:** Running the documented one-liner
(`curl -fsSL https://raw.githubusercontent.com/.../master/install.sh | bash`) from an
otherwise-empty directory silently left that directory fully initialised as an AEF
project — `.agentic-framework/` (~90MB), `.git`, `.claude/`, `CLAUDE.md`, `.mcp.json`,
`policy/`, `.context/`, `.tasks/`, `.framework.yaml` — even though the installer's own
closing text tells the user the *next, separate* step is `cd /path/to/your/project && fw
init`. The installer printed nothing but green checkmarks, including
`Step 3/3: fw doctor passes ✓`.

**Root cause:** `install.sh`'s `verify()` Step 3 ran `"$fw_path" doctor &>/dev/null`
without changing directory, so `fw doctor` executed with the **caller's cwd** as its
working directory — the directory the user happened to be standing in when they ran the
curl one-liner, not the framework checkout `install.sh` had just created. A directory
with no `.framework.yaml` walks `bin/fw` into its auto-init-on-first-touch branch; run
under a pipe (`curl | bash`, no TTY), that branch initialises with defaults rather than
prompting. The `&>/dev/null` redirect on the `doctor` call swallowed the entire
narrative, so a highly consequential write was reported as a read-only health check
passing.

**Why structurally allowed:** `bin/fw`'s auto-init-on-first-touch is deliberate and
correct for its own contract (`fw <realcmd>` in a genuinely new project should "just
work" rather than error) — T-2798 confirmed this must keep firing for real commands, and
only exempted `--help`. `install.sh`'s verify step was written assuming `fw doctor` is
read-only, which is only true when invoked from a directory `fw` has already seen. Two
independently-correct pieces of code combined into a bug at the interaction: nothing in
either codebase's test coverage exercised "the installer's own self-check, run from a
directory that isn't a project yet."

**Prevention:** `install.sh` Step 3 now runs `fw doctor` scoped to `$INSTALL_DIR` (the
freshly-cloned framework checkout, which already carries its own tracked
`.framework.yaml` and is a legitimate project) instead of the caller's cwd —
`tests/unit/install_verify_no_cwd_init.bats` pins this structurally: it runs the real
`install.sh --local` end to end in an isolated `HOME` with an empty, isolated cwd and
asserts the cwd holds zero entries afterward. Before/after evidence for the underlying
mechanism (not the bats file itself, which by the time it was written already only had
the fixed script available in this checkout — see Updates for why): the pre-fix run
against the real, then-unpatched public master left 10 entries in the cwd; the post-fix
runs against a patched local copy and, later, the genuinely re-fetched patched public
master both left 0.

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

### 2026-08-04T20:26:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2799-run-the-real-fresh-install-onboarding-en.md
- **Context:** Initial task creation

### 2026-08-04T21:10:00Z — full end-to-end verified, fix confirmed live on master, regression test added
- **Action:** Confirmed `github/master` had all of T-2792–T-2798's fixes (`f324aa5fd`,
  matching this repo's tip) — the reconciliation T-2792 flagged as outstanding (master
  730+ commits behind) had already landed by session start. **Run 1 (pre-fix
  reproduction):** real `curl -fsSL .../master/install.sh | bash`, isolated
  `HOME=/tmp/t2799-run1-home`, isolated cwd `/tmp/t2799-run1-cwd`, minimal `env -i` PATH
  (no inherited session env, per T-2795). Install reported all-green
  (`Step 3/3: fw doctor passes ✓`) but left 10 entries in the cwd — `.agentic-framework/`,
  `.git`, `.claude/`, `CLAUDE.md`, `.context/`, `.framework.yaml`, `.mcp.json`, `policy/`,
  `.tasks/` — a full, silent project init in the user's working directory. Diagnosed root
  cause: `install.sh` verify() Step 3 ran `fw doctor` in the caller's cwd; found an
  **already-drafted, uncommitted fix** in the working tree from earlier exploration this
  session (`install.sh:358` comment block explicitly named T-2799), confirming this exact
  bug had already been found and fixed in-session before this pass began — verified the
  fix logic myself rather than trusting it blind.
  **Run 2 (post-fix, local):** same isolation, `install.sh --local` (patched copy) —
  cwd left with **0** entries. Continued through the rest of the pipeline in this run:
  `fw init --provider claude --no-first-run` (42/43 checks, 1 skipped as expected),
  `fw context init` (clean), `fw doctor` (0 failures, 3 project warnings — all the same
  benign fresh-project class T-2792 already characterised: path ambiguity, cron registry
  not generated, untracked task file), `fw serve --port 3997` +
  `curl .../api/_identity` → `{"project_root":"/tmp/t2799-run2-project",...}`, page
  `<title>` matched. Stopped Watchtower via `fw watchtower stop` (not `--stop`, which
  isn't a valid flag — noted for future handoffs).
  Confirmed running the doctor call scoped to `$INSTALL_DIR` doesn't corrupt the global
  install itself either — `git -C $INSTALL_DIR status --short` after the run showed only
  harmless tracked working-memory counter churn, no untracked debris.
- **Concurrent-session note:** mid-verification, discovered this checkout is being
  actively edited by at least one other concurrent session (commit `1570e1d9a`,
  "T-2800: $HOME framework install architecture", landed while this task was in
  progress) — it independently folded in the *same* install.sh fix already sitting in
  the tree (identical diff) as part of its own commit. `origin/master` and
  `github/master` had already moved to `1570e1d9a` by the time I checked. No action
  needed on my part to land the fix — it's already on public master. Also discovered a
  **stale, unrelated `git stash pop` I attempted was a mistake** on a shared working
  tree with 13 pre-existing stash entries from other in-flight work — the pop aborted
  safely on conflict (git's atomic guarantee) without touching any files; confirmed via
  `git status`/`git stash list` immediately after. No `git stash` used for the remainder
  of this task.
- **Filed two sibling findings** from this same investigation as their own tasks (one
  bug = one task): **T-2801** (`fw init` not atomic — interrupted init leaves
  unrecoverable debris, from OBS-157) and **T-2802** (`fw watchtower url` silently
  falls back to the well-known `:3000` from a non-project directory — a false-green
  hazard on multi-project hosts, from OBS-158). Both promoted via `fw note promote`,
  owner: human (need scoping, not blockers to the onboarding happy path).
- **Added `tests/unit/install_verify_no_cwd_init.bats`** — runs the real `install.sh
  --local` end to end in a fresh isolated HOME + cwd and asserts the cwd holds zero
  entries afterward; ~49s (full local git clone, consistent with the existing
  `upgrade_fresh_machine_simulation.bats` heavy-simulation pattern). Green.
- **Run 3 / final (post-fix, genuinely live public master, AC4):** fresh
  `HOME=/tmp/t2799-final-home`, fresh cwd `/tmp/t2799-final-cwd`, real
  `curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh
  | bash` (master now carries the fix via `1570e1d9a`) → `fw v1.6.136`, all 3 verify
  steps green, cwd confirmed **0** entries. Then `fw init --provider claude
  --no-first-run` (42/43), `fw context init`, `fw doctor` (0 failures, 3 warnings, same
  benign class), `fw serve --port 3996`,
  `curl http://localhost:3996/api/_identity` →
  `{"project_root":"/tmp/t2799-final-project","service":"watchtower",...}`. Stopped
  Watchtower, deleted all `/tmp/t2799-*` scratch directories.
- **Output:** All 5 Agent ACs ticked. RCA written. Regression test added and green.
  T-2801/T-2802 filed. Fix already live on `github/master` (not pushed by me — landed
  by a concurrent session's commit that happened to include the same diff).
- **Context:** Not re-tested here: genuinely missing-prerequisite conditions (no git/
  python3/node on the machine) — this host has all three, so Step 1's failure branches
  are unexercised. That gap is pre-existing to this task and not newly introduced.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-df0f3103
- **Timestamp:** 2026-08-04T21:16:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `bats tests/unit/install_verify_no_cwd_init.bats > /tmp/.t2799-verify.out 2>&1 && grep -q '^ok 1 ' /tmp/.t2799-verify.out`

### 2026-08-04T21:15:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
