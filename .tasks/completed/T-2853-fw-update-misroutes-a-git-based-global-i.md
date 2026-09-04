---
id: T-2853
name: "fw update misroutes a git-based global install into the vendored path and demands
  upstream_repo install.sh never writes"
description: >
  fw update misroutes a git-based global install into the vendored path and demands
  upstream_repo install.sh never writes

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw-router, lib/update.sh, lib/upgrade.sh, tests/unit/update_mode_routing.bats]
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
created: 2026-08-07T08:23:42Z
last_update: 2026-09-04T00:09:56Z
date_finished: 2026-09-04T00:09:56Z
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
  - ts: '2026-08-07T12:30:17Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-17T12:36:23Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=302,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:25:20Z'
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
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2853: fw update misroutes a git-based global install into the vendored path and demands upstream_repo install.sh never writes

## Context

Operator, 2026-08-07, in a freshly emptied `/opt/001-test-install`:

```
$ fw update
fw: no project found above /opt/001-test-install — using global install at /root/.agentic-framework
ERROR: No upstream_repo in .framework.yaml

Add to .framework.yaml:
  upstream_repo: https://github.com/USER/REPO.git
```

Run three times in a row, identically — the signature of an error that tells you
nothing you can act on.

**Mechanism.** `lib/update.sh:56-68` picks its mode in this order:

```bash
local project_root="${PROJECT_ROOT:-$PWD}"
local vendored_dir="$project_root/.agentic-framework"

if [ -d "$vendored_dir" ] && [ -f "$vendored_dir/VERSION" ]; then
    _do_update_vendored …          # ← needs upstream_repo
elif [ -d "$FRAMEWORK_ROOT/.git" ]; then
    _do_update_git …               # ← needs nothing; uses the clone's own origin
```

The global install lives at `~/.agentic-framework` — the **same layout** as a
consumer's vendored copy: a directory of that name beside a project root. It has
a `VERSION`. So the first branch matches, and the second is **unreachable for the
global install**. `_do_update_vendored` then looks for `upstream_repo` in
`$project_root/.framework.yaml` (here: `/root/.framework.yaml`) — a key
`install.sh` never writes, since it obtains the framework by `git clone`
(`install.sh:191,194`) and the clone's own `origin` is already the answer.

**The discriminator that was available and unused:** a global install is a git
clone and carries `.git`; a vendored copy is a file copy and does not (verified:
this repo's own `.agentic-framework/` has `VERSION` and no `.git`). The
information needed to route correctly was present in both branches' conditions
the whole time — only the order was wrong.

**Severity amplifier:** the message names `.framework.yaml` with **no path**. The
file it means is `/root/.framework.yaml`; the operator was standing in
`/opt/001-test-install`. Following the instruction literally — creating
`.framework.yaml` in the cwd — would not have helped.

Onboarding-relevant: `prompts/aef-fresh-install-onboarding.md` STEP 2 explicitly
recommends `fw update` as "usually the right move" for refreshing a global
install. The prompt recommends a command that cannot succeed on a
default-installed host.

## Acceptance Criteria

### Agent
- [x] `fw update` routes a **git-based** install (`.agentic-framework/.git` present)
      to `_do_update_git`, regardless of whether it also looks vendored.
      → Before/after on the same global-install-shaped fixture:
      `ROUTE=vendored` (pre-fix, `git show HEAD:lib/update.sh`) → `ROUTE=git` (current).
      The pre-fix run also reproduces the operator's exact text:
      `ERROR: No upstream_repo in .framework.yaml`.
- [x] `fw update` still routes a genuine **vendored consumer** (`.agentic-framework/`
      with `VERSION`, no `.git`) to `_do_update_vendored`. Negative control — a fix
      that simply preferred the git path would break every consumer.
      → Suite test 3.
- [x] The `No upstream_repo` error names the **absolute path** of the file to edit,
      so it is actionable from any cwd.
      → Live in this repo: `ERROR: No upstream_repo in
      /opt/999-Agentic-Engineering-Framework/.framework.yaml`. Pinned by test 5.
- [x] `tests/unit/update_mode_routing.bats` pins both routing directions against
      fixtures and is green. → 5/5, EXIT=0.

**Scope honesty:** verified against a faithful fixture (`.agentic-framework/`
containing `VERSION` + `.git`), **not** against the operator's actual
`/root/.agentic-framework` — the T-559 project-boundary hook blocks reading it,
correctly.

**Chicken-and-egg, stated rather than papered over:** this fix cannot deliver
itself. The operator's global install runs the *old* `update.sh`, so `fw update`
there will still misroute until the clone is refreshed by other means
(`git -C /root/.agentic-framework pull`, or re-running `install.sh`). Filed as a
known limitation rather than pretending the push resolves their immediate error.

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

bash -n lib/update.sh
out=$(bats tests/unit/update_mode_routing.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
grep -q '! -d "$vendored_dir/.git"' lib/update.sh
out=$(bin/fw update --check 2>&1); echo "$out" | grep -q "$PWD/.framework.yaml"

## RCA

**Symptom:** `fw update` on a default-installed host, run from an empty
directory, fails with `ERROR: No upstream_repo in .framework.yaml`. The operator
ran it three times unchanged.

**Root cause:** mode detection in `do_update` (`lib/update.sh:56-68`) tested the
*vendored* shape first — "a directory named `.agentic-framework` beside the
project root, containing a `VERSION`" — and a global install satisfies that
description exactly, because it lives at `~/.agentic-framework`. The
`elif [ -d "$FRAMEWORK_ROOT/.git" ]` branch that handles git-based installs was
therefore **unreachable for the very case it was written for**. Routed into the
vendored path, `fw update` demanded `upstream_repo` from `~/.framework.yaml` — a
key `install.sh` never writes, and never needs to, because it acquires the
framework by `git clone` (`install.sh:191,194`) and the clone's own `origin`
already is the upstream.

**Why structurally allowed:** two things that share a *layout* were distinguished
by *order of testing* rather than by a property. Nothing was wrong with either
branch in isolation; the defect existed only in their sequence, which is
invisible to any test that exercises one branch at a time. The discriminating
property was available in both conditions the whole time — a clone carries
`.git`, a file-copy vendor does not — and simply was not asked about. Compounding
it, the failure surfaces only on a *global* install, while all development and
CI happen in the framework repo or in vendored consumers, so no local workflow
ever traversed the broken path.

**Amplifier — the error was unactionable:** it named `.framework.yaml` with no
path. The file meant was `/root/.framework.yaml`; the operator was in
`/opt/001-test-install`. Obeying the instruction literally would have created a
file that changes nothing. An error that cannot be acted on gets retried
verbatim, which is exactly what happened — three times.

**Prevention:** `tests/unit/update_mode_routing.bats` asserts the routing
*decision* for all three shapes (git clone → git, vendored copy → vendored,
framework repo → vendored) by stubbing the terminal handlers, so the branch
sequence itself is under test rather than either branch's behaviour. Plus an
assertion that the error text carries an absolute path.

**Caught during the fix, worth recording:** my first edit keyed the discriminator
on `[ -d "$FRAMEWORK_ROOT/.git" ]`. In the framework repo `FRAMEWORK_ROOT` *is*
the checkout and does have `.git`, so that version routed **this repo** into
`_do_update_git`, which runs `git reset --hard origin/master` over a live working
tree. Caught by reasoning through the three shapes before running anything; the
regression guard (test 4) now pins it. The right question was never "is there a
git repo somewhere nearby" but "is the framework copy *this project uses* a
clone" — and only `$vendored_dir/.git` answers that.

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

### 2026-08-07T08:23:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2853-fw-update-misroutes-a-git-based-global-i.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-26c664ba
- **Timestamp:** 2026-09-04T00:09:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-04T00:09:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
