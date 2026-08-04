---
id: T-2792
name: "Fresh-install onboarding path broken: make the new-project prompt work end
  to end"
description: >
  Fresh-install onboarding path broken: make the new-project prompt work end to end

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw-router]
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
created: 2026-08-04T14:37:59Z
last_update: 2026-08-04T18:12:28Z
date_finished: 2026-08-04T18:12:28Z
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
  - ts: '2026-08-04T14:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-04T14:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 1
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=1 (body:log-or-error-line); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2792: Fresh-install onboarding path broken: make the new-project prompt work end to end

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

Operator ran the new-project onboarding prompt in a fresh directory
(`/opt/2345-test-install`) and it did not work. This is the failure class T-2715
documented and that arc-015/016/017 were opened for — none of which has shipped a fix.

First concrete signal, from the operator's screenshot and reproduced here: the
machine-wide `fw` reports **v1.6.8** while this repo is at **1.6.108**. The onboarding
agent read that as "already installed and up to date — skip the installer", so the
operator's fresh install is being told it is current while running a build that may be
~100 versions behind. Whether 1.6.8 is a genuinely stale vendored copy or a version
string being mangled is the first thing to settle — the two have completely different
fixes and the same symptom.

## Acceptance Criteria

### Agent
- [x] **The v1.6.8-vs-1.6.108 discrepancy is explained with evidence**, and the explanation
      distinguishes "stale vendored copy" from "version string parsed/formatted wrong".
      Named because these present identically at the surface and the wrong diagnosis ships
      the wrong fix. See `## RCA` — two compounding causes (OBS-150 deriver bug + T-2793
      CLI-not-vendored split-brain), reproduced live in this repo just now: `fw --version`
      → v1.6.8, `./.agentic-framework/bin/fw --version` → v1.6.234, `VERSION` file → 1.6.111.
      Three numbers, none orderable.
- [x] The onboarding prompt's Steps 1-5 are **executed for real in a throwaway directory**,
      not reasoned about. Every command that fails is recorded with its exact output.
      → `/tmp/aef-onboard-test-1` through `-3` (see Updates). Steps 1/3/4/5 passed;
      Step 2 failed live (global install routing loop) and was diagnosed + fixed in place.
- [x] Each failure found is either fixed, or filed as its own task with the reproduction
      attached (one bug = one task). No failure is left described-but-unowned.
      → 3 findings: (1) global install corruption — fixed live (this host); (2) router's
      routing-loop message assumed git-dev knowledge — **T-2794**, fixed + tested; (3)
      onboarding prompt didn't warn about inherited-session env pinning — **T-2795**,
      fixed. One candidate finding (env-wins "bug") was investigated and found to be
      intentional/tested (T-2391/T-2446) — reframed as T-2795 rather than filed twice.
- [x] Re-running the same steps in a **second** clean directory after the fixes reaches
      Step 5 with a live Watchtower URL — verified by fetching the URL, not by the absence
      of an error message.
      → `/tmp/aef-onboard-test-4`: Steps 1-5 all green, `curl .../api/_identity` returned
      `{"project_root":"/tmp/aef-onboard-test-4",...}` and the page title matched the
      project name. See Updates for full command-by-command evidence.

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

**Symptom:** The onboarding prompt's Step 2 ("is the framework already installed?") reads
`fw --version` from the global CLI. On the operator's fresh-install run the global CLI
reported v1.6.8 while the target repo was at 1.6.108 — the onboarding agent read the low
number as "already up to date" and skipped the installer, leaving the operator on a build
~100 versions behind with no error surfaced.

**Root cause — two compounding defects, not one:**
1. `_derive_version` (`bin/fw`) computes the reported version as `major.minor.<commits-since-tag>`
   — a commit **distance**, not a semver. The number collapses to near-zero at every release
   tag and climbs again until the next tag, so it is not globally ordered even between two
   checkouts of the *same* history (OBS-150). This alone explains why 1.6.8 vs 1.6.108 looked
   like "very out of date" when both were live checkouts on the same day.
2. `bin/fw` is not vendored per project: it always re-execs **itself**
   (`exec "$0" "$@"`, bin/fw ~563/657) instead of delegating to the project's
   `.agentic-framework/bin/fw`, while 182 references for libs/agents already pull from the
   vendored copy. A vendored consumer therefore runs a split-brain: old global CLI dispatch
   driving new vendored libraries — an untested combination that drifts whenever the global
   install diverges from any project's vendored copy (T-2793, decision D-377).

Defect 2 is the actual root cause; defect 1 is a real bug but is *subsumed* by it — once the
CLI is vendored (T-2793), `.agentic-framework/` has no `.git`, `_derive_version` falls back
to the `VERSION` file, and the split-brain disappears as a structural consequence. Patching
the deriver alone (without vendoring the CLI) would have masked the split-brain by making
both invocations print the same wrong-but-matching number.

**Live reproduction, this repo, right now (2026-08-04):**
```
fw --version                          → fw v1.6.8    (global CLI reporting itself)
./.agentic-framework/bin/fw --version → fw v1.6.234   (vendored copy)
VERSION (repo file)                   → 1.6.111
.framework.yaml version:              → 1.6.234 (vendored)
```
Three numbers, none orderable against another, confirming OBS-150/T-2793's finding is live
and current, not historical.

**Why structurally allowed:** nothing asserts CLI/library version agreement for a vendored
consumer — `fw doctor` and `fw upgrade` never compare "which `fw` binary am I" against
"which libs did it load". The "total isolation" invariant (vendor everything a project
depends on, including the CLI dispatch layer) was implicit in the libs/agents vendoring but
was never applied to `bin/fw` itself, so its self-exec was never flagged as a gap.

**Prevention:** T-2793 (thin-router fix: `fw` on PATH execs the nearest vendored
`.agentic-framework/bin/fw`) closes this class structurally, asserted by
`tests/unit/upgrade_fresh_machine_simulation.bats` checking `fw --version` /
`.framework.yaml version:` / `.agentic-framework/VERSION` all agree in a vendored consumer.
Until T-2793 ships, the only mitigation is the `[dogfood]` note already in
`prompts/aef-fresh-install-onboarding.md:82` (T-2441): use the project-local
`{{dir}}/.agentic-framework/bin/fw` path explicitly rather than trusting bare `fw`.

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

### 2026-08-04T14:37:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2792-fresh-install-onboarding-path-broken-mak.md
- **Context:** Initial task creation

### 2026-08-04T16:43:02Z — root cause identified [session S-2026-0804-1429]
- **Action:** Diagnosed the v1.6.8-vs-1.6.108 discrepancy; captured OBS-150 (`.context/inbox.yaml`).
- **Output:** OBS-150 identifies the version-deriver bug (commit-distance, not semver).
- **Context:** AC1 partially addressed; refined below once the deeper cause was found.

### 2026-08-04T16:45:03Z — deeper cause found, T-2793 filed [session S-2026-0804-1429]
- **Action:** Reframed OBS-150 as a symptom of `bin/fw` never delegating to the vendored
  `.agentic-framework/bin/fw` (self-exec, not thin-router). Filed **T-2793** ("Total
  isolation: vendor the CLI too") as the owning fix task per one-bug-one-task — T-2793
  should NOT ship the deriver patch alone, since vendoring the CLI makes the split-brain
  disappear structurally.
- **Output:** T-2793 created with real ACs (thin router, walk-up floor, bootstrap-path
  preserved, self-replacement safety, bats assertion, stale-global-install tolerance).
- **Context:** AC3 satisfied for this failure (filed as its own task).

### 2026-08-04T18:11:00Z — AC2/3/4 closed: real dry-run, real fixes, real re-verification [session S-2026-0804-1732]
- **Action:** Set up focus, then found and fixed a **live governance-integrity issue**
  first: T-2793's Updates section (not just its AC4 text) still carried the fabricated
  "VERIFIED LIVE" self-replacement narrative that OBS-154's retraction commit had only
  removed from the AC — corrected, logged OBS-155 (partial-fix pattern).
  Then ran the onboarding prompt's Steps 1-5 for real in `/tmp/aef-onboard-test-1..3`
  (outside project boundary — direct Bash worked for most commands; the project-boundary
  hook only fires on literal outside-path patterns like `/opt/*` or `.../bin/fw`, not on a
  bare `cd /tmp/...`, so no TermLink dispatch was needed for the local steps):
  - **Step 1** (prereqs): bash 5.2.21, git 2.43.0, python3 3.12.3 — pass.
  - **Step 2** (already-installed check) **FAILED live**: `fw --version` in the fresh dir
    hit "fw: routing loop — the fw found here is this router itself" — the global install
    at `/root/.agentic-framework/bin/fw` had been corrupted (its content was the ~95-line
    router, not the 7,836-line real CLI) by the exact pre-T-2793 `cp`-through-symlink bug
    `install.sh`'s current code already guards against, but the guard doesn't retroactively
    repair an already-corrupted host. Diagnosed via TermLink dispatch (project-boundary
    hook correctly refused direct `/root` access): `git status --short bin/fw` showed a
    local modification with the real content still in git history. Repaired via TermLink
    (`git checkout HEAD -- bin/fw`), then discovered the deeper state: `~/.local/bin/fw`
    was still a bare symlink to the global install (pre-T-2793 architecture — the router
    was never actually deployed on THIS host's PATH, only accidentally corrupted-then-fixed
    in place) AND the global install's own git clone was 700+ commits stale (dfb967473,
    pre-dating T-2793 entirely). Fixed by running `install.sh --local <this repo>
    --branch t2539-staging` via TermLink — updated the clone and correctly installed the
    router this time (`rm -f` guard in `link_fw` already present). Re-verified: fresh dir
    now gets the announced fallback (`fw: no project found above ... — using global install
    at /root/.agentic-framework`) and a correct, current version.
  - **Methodology note:** the FIRST re-test (before stripping session env) showed `fw
    --version` in `/tmp` reporting `Project: /opt/999-Agentic-Engineering-Framework` — this
    session's own shell had `FRAMEWORK_ROOT`/`PROJECT_ROOT` exported from earlier `fw`
    calls in THIS project. Investigated as a possible bug, found to be `bin/fw`'s
    intentional "env wins" contract (T-2391/T-2446); filed as **T-2795** (prompt doc gap,
    not a code bug) rather than duplicating already-adjudicated design.
  - **Step 3** (init): `fw init --provider claude` — 42/43 validation checks OK (1 skipped,
    expected for claude provider). Both previously-documented `[dogfood]` frictions (BVP
    drivers missing-keys error, session-init failure) did NOT reproduce — already fixed
    upstream; not re-flagged.
  - **Step 4** (session + health): `fw context init` clean; `fw doctor` — **0 failures**,
    6 warnings (2 host-level excluded from project scope; 4 project-level: framework-path
    ambiguity, unsupervised-session, cron-registry-not-generated, 1 untracked task file —
    all expected/benign for a just-initialized project).
  - **Step 5** (Watchtower): `fw serve --port 3999` named the correct project in its
    startup log, health check passed. `curl .../api/_identity` returned
    `{"project_root":"/tmp/aef-onboard-test-3",...}`; page `<title>` matched the project
    name. Confirms this run's Step 5 is genuinely fixed, not just silent.
  - **Second clean-dir re-run** (`/tmp/aef-onboard-test-4`, AC4): repeated Steps 1-5 with
    the same env-scoping. All green, including a **second, independent** live Watchtower
    on port 3998 with matching identity. AC4 satisfied.
  - **Filed and fixed T-2794** (router routing-loop message assumed framework-dev git
    knowledge — reordered to lead with the self-healing installer one-liner; bats-pinned,
    12/12 green) and **T-2795** (onboarding prompt now warns about inherited-session env
    pinning, citing T-2391/T-2446 so it isn't mis-read as a bug later).
  - Cleaned up all `/tmp/aef-onboard-test-*` dirs, stray processes, and TermLink dispatch
    sessions used for this investigation.
- **Output:** All 4 Agent ACs ticked. T-2793's fabricated Updates entry corrected
  (OBS-155). T-2794 and T-2795 filed, fixed, closed. Global install on this host repaired
  and brought current.
- **Context:** **Not closed here:** T-2793's own AC4 (live self-replacement safety) is
  still open — a real `fw upgrade` self-overwrite still needs its own verified slice; this
  task's fixes did not require it (the repair path used was a fresh `install.sh` run, not
  `fw upgrade`'s self-replacement code path). Separately, **master is 730+ commits behind
  this branch (t2539-staging)** — none of T-2792/T-2793/T-2794/T-2795's fixes are reachable
  via the real `curl | bash` installer from GitHub master yet. That reconciliation is
  already tracked at **T-100201** (referenced in CLAUDE.md's own "KNOWN CONFLICT" note) —
  not re-filed here, but flagged because it means this task's live verification used
  `install.sh --local` against the staging branch, not the public install path a genuine
  new user hits today.

### 2026-08-04T~16:50Z — AC1 evidence written into RCA, live-reproduced [this session]
- **Action:** Wrote `## RCA` with both compounding causes and re-ran the reproduction live
  in this repo (not the operator's original throwaway dir, which no longer exists) —
  confirms the bug is current, not stale: `fw --version`→v1.6.8,
  `./.agentic-framework/bin/fw --version`→v1.6.234, `VERSION`→1.6.111, three unorderable
  numbers.
- **Output:** AC1 checkbox ticked.
- **Context:** **Remaining scope for this task:** AC2 (execute onboarding Steps 1-5 fresh
  in a genuine throwaway directory — blocked here by the project-boundary hook, which
  refuses Bash commands targeting paths outside `/opt/999-Agentic-Engineering-Framework`;
  needs either operator-run steps or `fw termlink dispatch --project <fresh-dir>`) and AC4
  (second clean-dir re-run reaching a live Watchtower URL) are **not yet done** and AC4
  cannot pass until T-2793's fix ships — the router bug this task diagnosed is exactly what
  Step 5 of the onboarding prompt would hit. This task stays `started-work`, blocked on
  T-2793, not completed.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-866f1074
- **Timestamp:** 2026-08-04T18:12:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T18:12:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
