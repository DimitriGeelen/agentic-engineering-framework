---
id: T-2809
name: "installer fetches framework bytes into the target project instead of $HOME
  (T-2800 slice 2)"
description: >
  installer fetches framework bytes into the target project instead of $HOME (T-2800
  slice 2)

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
created: 2026-08-05T12:56:09Z
last_update: 2026-08-05T13:43:08Z
date_finished: 2026-08-05T13:43:08Z
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
  - ts: '2026-08-05T13:00:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-05T13:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 5
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=5 (body:class-neutral); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2809: installer fetches framework bytes into the target project instead of $HOME (T-2800 slice 2)

## Context

**This is the operator-visible slice of T-2800 and the only remaining blocker in the
onboarding prompt.** Everything else in that prompt now works; STEP 2 does not.

The failure the operator keeps hitting, three sessions running: their onboarding
agent runs STEP 2, finds a framework already in `$HOME`, and stops to ask whether to
skip the installer. It asks because a global install exists to be confused by. D-377
(total isolation) says it should not exist. T-2800 GO'd removing it on 2026-08-04.

**Do not re-derive the design.** It is settled across T-2800's four dialogue rounds
and T-2803's survey:

- Keep the ~100-line `bin/fw-router` as the **only** machine-wide artifact.
- The installer **fetches framework bytes into the target project**, not `$HOME`.
- The router **refuses with instructions** instead of falling back to a global.
- Install and init become **one command per project** — forced, not chosen: on a
  fresh machine nothing can execute `fw init` (it is framework code) unless the
  standalone installer does. See T-2800 IW-3.
- Offline / air-gap is covered by `--from <url|path|tarball>` plus the existing
  `upstream_repo:` in `.framework.yaml`, not by keeping bytes in `$HOME` (IW-1,
  dissolved).

**Ordering (T-2803, non-negotiable):** the router's global fallback is the only thing
that makes `fw init` work in a bare directory. `install.sh` must be able to create a
project *before* anything about the global is removed. Deleting the global first is
not a smaller first step — it removes the ability to make new projects.

**Prerequisite already landed:** T-2807 made `claude-fw` a copy rather than a symlink
into `$INSTALL_DIR`. That had to precede this, because once `$INSTALL_DIR` is
temporary a symlink into it dangles and takes T-179 auto-restart with it.

Sites to change, from `docs/reports/T-2803-global-install-dependency-survey.md`
(6 must-migrate, 3 compat-shim, 3 can-delete — all but one inside `install.sh`):

| # | Site | Change |
|---|------|--------|
| 2 | `install.sh:16` `INSTALL_DIR` | becomes the project target |
| 3 | `install.sh:134-190` `do_install` | git clone → tarball fetch to a temp path |
| 4 | `install.sh` `link_fw` | router source moves to the fetched temp dir |
| 6 | `install.sh` `verify` | self-test runs the project's vendored copy |
| 10 | `bin/fw:1768` | refresh advice must not assume a `$HOME` checkout |
| 1 | `bin/fw-router:99` | global fallback — change **LAST**, and consider keeping it |

Steps 3-5 of the survey's safe order (deprecate `fw upgrade` step 4c, `_do_update_git`,
invert the doctor checks into migration detectors) are **hygiene on already-migrated
hosts and are OUT of scope here** — they are no-ops when the global is absent.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `install.sh` can fetch framework bytes to a temp path and vendor them into a named target project, without writing a framework into `$HOME`. Router + `claude-fw` still land on PATH (both copies, per T-2807).
- [x] Running the installer against a fresh empty directory produces a working project end to end: `fw init` equivalent completes, `.framework.yaml` exists, `.agentic-framework/FRAMEWORK.md` exists (T-2805's completeness sentinel), and `fw` in that directory reports `Mode: vendored`.
- [x] Verified with **no framework bytes in `$HOME`** — run under an isolated `HOME` (`env HOME=<tmp>`), not merely on a host that happens to have one. A pass on a host with a global install proves nothing about the path being fixed.
- [x] An existing vendored project is untouched: it still resolves to its own copy and its version pin does not move. Pinned by test, not by inspection.
- [x] `tests/unit/upgrade_fresh_machine_simulation.bats` and `tests/unit/claude_fw_copy_not_symlink.bats` stay green (consumer-facing command hygiene, T-1633).
- [x] New regression coverage for the fetch-into-project path, mutation-checked — shown to go red against the current `$HOME`-installing code.
- [x] `bin/fw:1768` refresh advice no longer assumes a git checkout in `$HOME`.
- [x] The router's global fallback (`bin/fw-router:99`) is left in place in this slice, or its removal is justified in `## Decisions` against the T-2803 ordering constraint.

### Human
- [ ] [REVIEW] The onboarding prompt's STEP 2 no longer asks whether to skip
  This is the whole point of the slice and only you can judge it: it is your prompt,
  run by your agent, and the question is whether the confusion is gone — not whether
  a command exits 0.
  **Steps:**
  1. Pick a brand-new directory (not `/opt/2345-test-install` — it is already initialised, and the prompt's own STEP 3 self-heal will correctly stop there)
  2. Run your onboarding prompt from the top, under `claude-fw`
  3. Watch STEP 2 specifically
  **Expected:** the agent installs and initialises without stopping to ask whether a global install makes the step a no-op, and without reporting a version it cannot compare against the project's.
  **If not:** paste what STEP 2 printed and what the agent asked. The likely residue is a `$HOME` framework left over from an earlier install — this slice stops *creating* one, it does not remove an existing one.

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

bash -n install.sh
out=$(bats tests/unit/install_target_project.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/install_verify_no_cwd_init.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/claude_fw_copy_not_symlink.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/install_scan.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/bin_executable_bits.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

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

### 2026-08-05 — router's global fallback (`bin/fw-router:99`)
- **Chose:** left untouched in this slice.
- **Why:** T-2803's ordering constraint is explicit — `install.sh` must be able to
  create a project *before* the router's global fallback is removed, because that
  fallback is what makes `fw init` reachable in a bare directory today. This slice
  makes the global unnecessary (install.sh no longer reads or writes it), but the
  fallback code itself is inert once the global is absent — a no-op, not a hazard —
  and its removal is explicitly staged as T-2803's step 5, gated on the router-side
  cleanup at steps 3-4 first. Removing it here would be doing two slices at once.
- **Rejected:** removing the fallback now. Not chosen because nothing in this slice
  regresses if it stays — `install.sh` never populates `$HOME/.agentic-framework`
  anymore, so the fallback branch simply never fires for a project created by the
  new installer. Removing dead-in-practice code is real work with its own blast
  radius (bin/fw-router.bats coverage, doctor's global-install checks) and belongs
  in the step T-2803 already named for it.

### 2026-08-05 — target directory is optional, not forced-$PWD
- **Chose:** `install.sh` takes an optional positional `target-dir`. Given, it
  fetches + vendors + inits that directory in one step. Omitted, it installs/
  refreshes the router + `claude-fw` on PATH only — no project is created anywhere.
- **Why:** two structural reasons. (1) T-2799's existing regression test
  (`tests/unit/install_verify_no_cwd_init.bats`) pins that `install.sh` run with no
  target must never write into the caller's cwd — auto-defaulting the target to
  `$PWD` would break that contract and reintroduce the exact silent-cwd-init class
  T-2799 was filed to prevent. (2) `bin/fw:1809-1816`'s claude-fw drift-refresh
  advice already tells operators to run the bare `curl … | bash` one-liner to
  refresh PATH tooling after drift — that call site has no project directory in
  scope and must keep working as a no-project refresh, not become an accidental
  `fw init` of whatever directory the operator happened to be standing in.
- **Rejected:** defaulting `target-dir` to `$PWD` (matches the bootstrap spike's
  literal wording most closely, but fails both constraints above); requiring
  `target-dir` unconditionally (breaks the refresh-only call site with no
  graceful no-op path).

### 2026-08-05 — fetch via shallow `git clone`, not a tarball
- **Chose:** `git clone --depth 1 --single-branch` into a `mktemp -d` temp
  directory, deleted at the end of the run.
- **Why:** T-2800's design doc floats "fetch as a tarball, not a clone" as a
  size optimisation for a *persistent* `$HOME` install (352 MB full clone vs a
  smaller release-asset tarball). That rationale doesn't apply here — the fetch
  directory is temporary and deleted by `cleanup_fetch()` before the run ends, so
  its on-disk size only matters for the seconds it exists. Building a tarball
  publishing pipeline (`fw release` asset) is real, separate scope: T-2803 lists
  it under the ordering survey's later steps, not this slice's "sites to change"
  table.
- **Rejected:** tarball fetch — deferred as future work, not required for the
  "temp path, not `$HOME`" outcome this task's ACs ask for.

## Recommendation

**Recommendation:** GO

**Rationale:**

All 8 Agent ACs pass with live evidence, not just green tests. `install.sh` now
fetches framework bytes to a `mktemp -d` temp path, vendors them into a named
target project, installs the router + `claude-fw` (copies, per T-2807) on PATH,
and deletes the temp fetch — matching T-2800's GO'd design and T-2803's ordering
constraint (global fallback left in place, justified in `## Decisions`). The
remaining Human AC is a `[REVIEW]` — "does STEP 2 of the operator's own onboarding
prompt still ask to skip a global install" — which only the operator can judge by
running their own prompt end to end; it is not something the agent can self-certify.

**Evidence:**

- **Live end-to-end run** (not just bats): `install.sh <target> --local <this repo>`
  under `env -i HOME=<isolated tmp>` produced a fully initialised project
  (`.framework.yaml`, `.agentic-framework/FRAMEWORK.md`, 5 onboarding tasks,
  43/44 init validation checks) with `fw version` inside it reporting
  `Mode:      vendored` and `Framework: <target>/.agentic-framework`.
- **No bytes in `$HOME`**, checked by listing, not by absence-of-error: after the
  run, `$HOME` contained only `.local/bin/fw` and `.local/bin/claude-fw` — no
  `.agentic-framework` directory. Confirmed both live and in
  `tests/unit/install_target_project.bats`.
- **Existing project untouched**: re-running `install.sh` against the same
  target left `.framework.yaml` byte-identical (`md5sum` match) and the vendored
  `VERSION` pin unchanged — checked live and pinned by test 4 in the new suite.
- **Mutation-checked regression coverage**: `tests/unit/install_target_project.bats`
  (5 tests) confirmed RED against the pre-fix `install.sh` (`git stash push --
  install.sh` then re-run — all 5 failed, mostly "Unknown option" since the old
  parser had no target-dir argument), then GREEN after the fix, restored via
  `git stash pop`.
- **No regressions**: `tests/unit/upgrade_fresh_machine_simulation.bats` (11/11),
  `tests/unit/claude_fw_copy_not_symlink.bats` (6/6), `install_scan.bats` (6/6),
  `bin_executable_bits.bats` (4/4) all green — none of these files were edited,
  confirming the change doesn't disturb adjacent contracts. (`fw_router.bats`
  has 6 pre-existing failures unrelated to this task — confirmed present via
  `git stash` on unmodified `install.sh`/`bin/fw-router`, neither of which this
  task's diff touches for that file.)
- **`bin/fw:1768`'s refresh advice** was already fixed under T-2807 (no
  `bash ~/.agentic-framework/install.sh` literal remains) — verified by grep,
  not re-changed.
- **README onboarding prompts A and B** were updated to merge "install" and
  "initialise" into one `curl … | bash -s -- <dir> --provider <choice>` step,
  which is the actual operator-facing fix the Human AC tests — STEP 2 no longer
  has a separate global-install phase to be confused by, because `install.sh`
  itself no longer reads or writes `$HOME/.agentic-framework`.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-05T12:56:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2809-installer-fetches-framework-bytes-into-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-46e4f5ce
- **Timestamp:** 2026-08-05T13:45:06Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/install_target_project.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'`

### 2026-08-05T13:43:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
