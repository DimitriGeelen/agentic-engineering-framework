---
id: T-2849
name: "greenfield consumer first commit carries 1011 framework-internal files"
description: >
  fw init vendors and git-commits 305 node_modules files, 688 of AEF's own docs/reports,
  and 18 screenshots into a brand-new consumer project: 1011 of 2731 tracked files,
  93MB vendored + 49MB git for an empty project. node_modules is not in .gitignore.
  fw doctor warns when the GLOBAL install exceeds 60MB but has no equivalent check
  for the per-project vendored copy, which D-377 made the default shape. Found in
  T-2846.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/fw]
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
created: 2026-08-07T05:17:56Z
last_update: 2026-08-07T12:29:12Z
date_finished: 2026-08-07T12:29:12Z
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
  - ts: '2026-08-07T05:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T05:30:11Z'
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

# T-2849: greenfield consumer first commit carries 1011 framework-internal files

## Context

`do_vendor` (`bin/fw:269-554`) declares eight exclude patterns. **Five of them have never
excluded anything.** The copy loop runs one `rsync` per include directory, so the transfer
root is `$src/lib/` — but the patterns are written relative to the repo root
(`lib/ts/node_modules`). An rsync pattern containing a `/` is anchored to the transfer
root, so `lib/ts/…` cannot match a path that rsync sees as `ts/…`.

The three patterns that *do* work (`__pycache__`, `*.pyc`, `.DS_Store`) contain no slash,
so rsync matches them as bare basenames at any depth. That is what makes the list look
functional: the visible effect of exclusion is real, and only the slash-bearing half is
inert.

Measured on the T-2846 evidence project (retained greenfield consumer):
- 2731 tracked files, of which **2704 are `.agentic-framework/`**
- **370** vendored files are files AEF's own `.gitignore` refuses to track
- **305** of those are `lib/ts/node_modules` — all under the exact path the exclude names
- project root has **no `.gitignore` at all**

Scope fence — this task fixes only the inert-predicate bug. Two adjacent questions are
deliberately **not** decided here and are filed separately: whether `docs/reports` (11M)
and `docs/screenshots` (4.8M) should ship to consumers at all, and whether `fw doctor`
should size-check the per-project vendored copy (today it checks only `$HOME`).

Third instance this week of the same class as T-2851 and T-2852: a comparison whose two
operands are not the same quantity, failing silently in the direction that reads as
success.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every `do_vendor` exclude pattern is expressed so it matches under the transfer root
      the copy loop actually uses (per-include, not repo-root), verified by a probe that
      shows the pre-fix pattern failing and the post-fix pattern succeeding on the same
      fixture
- [x] The `cp -r` fallback (taken when `rsync` is absent) honours the same exclude set —
      today it honours only the three slashless ones via post-hoc `find` deletes
- [x] A fresh vendor into a clean target copies **zero** files that AEF's own `.gitignore`
      excludes (predicate: `git check-ignore` against the source repo, not a hard-coded
      `node_modules` string)
- [x] Regression suite `tests/unit/vendor_exclude_anchoring.bats` covers: each declared
      exclude actually excludes; a **negative control** proving the assertion can fail;
      both the rsync and the `cp -r` branch; and an anti-vacuity anchor
- [x] Re-vendoring over a target that already contains the wrongly-shipped files removes
      them (self-healing for consumers created before this fix)

**Measured (same source, `--source` pinned so the only variable is the code):**

| | files | node_modules | png | lib/ts/src | size | gitignored-by-source |
|---|---|---|---|---|---|---|
| before (`HEAD:bin/fw`) | 2706 | 301 | 88 | 3 | 92M | **366** |
| after (rsync branch) | 2334 | 0 | 23 | 0 | 28M | **0** |
| after (`cp -r` branch) | 2334 | 0 | 23 | 0 | 28M | — |

Re-vendor over the polluted target: 301 → 0 node_modules, 92M → 28M (AC5).
`lib/ts/dist` (3 files, tracked build output) survives; the vendored `bin/fw` runs
(`fw v1.6.325`) and the vendored `loop-detect.sh` hook returns rc=0 identically with and
without `lib/ts/src` present — its only use of the source is a `[ -f ]`-guarded
stale-recompile, so consumers exec the shipped `dist/loop-detect.js` either way. The six
tracked files now absent from the vendored tree are exactly `lib/ts/{src/*,tsconfig.json,
package.json,package-lock.json}` — the set the exclude list has named since it was
written and never once dropped.

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

bash -n bin/fw
out=$(bats tests/unit/vendor_exclude_anchoring.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/vendor_gitignore.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom:** a brand-new consumer project's first commit tracks 2704 framework files,
including 305 `lib/ts/node_modules` files that AEF itself gitignores. 142MB for an empty
project.

**Root cause:** `do_vendor` copies each include directory with its own `rsync` call
(`bin/fw:413-436`), so the transfer root is `$src/<include>/`. The exclude patterns
(`bin/fw:362-371`) are written relative to the **repo root**. rsync anchors any pattern
containing a `/` to the transfer root, so `--exclude="lib/ts/node_modules"` is matched
against `ts/node_modules` and never fires. Five of the eight patterns are slash-bearing
and therefore inert; the three that work are slashless and match as bare basenames.

Probe (rsync 3.2.7), same fixture, three transfer roots:
- transfer root `src/lib/` + pattern `lib/ts/node_modules` → **file ships**
- transfer root `src/` + same pattern → excluded
- transfer root `src/lib/` + pattern `ts/node_modules` → excluded

**Why structurally allowed:** three compounding reasons.
1. *The failure direction is silent and safe.* A dead exclude ships extra files. Nothing
   errors, no gate fires, the copy succeeds. The only signal is a size nobody measures.
2. *The working half masks the broken half.* `__pycache__` really is absent from the
   vendored tree, so anyone spot-checking "do the excludes work?" gets a yes.
3. *Nothing downstream re-derives the boundary.* `fw init` writes no project-root
   `.gitignore` (`lib/init.sh:735` notes this explicitly) and then runs `git add -A`
   (`lib/init.sh:733`), so upstream's authoritative "this is not source" declaration is
   discarded at the vendor boundary and never reconstructed. `fw doctor`'s size check
   measures `$HOME/.agentic-framework` only (`bin/fw:2393`) — the shape D-377 made
   obsolete — so the per-project copy is unmeasured by construction.

**Prevention:** the regression test asserts the property, not the instance — *no vendored
file may be one the source repo gitignores* — so a future include that drags in a new
ignored tree fails the same test. Additionally each declared exclude is asserted to
actually exclude, with a negative control, across both the rsync and `cp -r` branches; a
pattern that silently stops matching is then a red test rather than a larger tarball.

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

### 2026-08-07T05:17:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2849-greenfield-consumer-first-commit-carries.md
- **Context:** Initial task creation

### 2026-08-07T12:15:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-76a7058a
- **Timestamp:** 2026-08-07T12:29:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-07T12:29:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
