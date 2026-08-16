---
id: T-2942
name: "Vendor the corpus reader and aef maps so the onboarding curriculum's routes
  resolve in consumers"
description: >
  Vendor the corpus reader and aef maps so the onboarding curriculum's routes resolve
  in consumers

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-08-12T12:18:44Z
last_update: '2026-08-16T22:25:24Z'
date_finished: 2026-08-12T12:26:05Z
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
  - ts: '2026-08-16T22:25:24Z'
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

# T-2942: Vendor the corpus reader and aef maps so the onboarding curriculum's routes resolve in consumers

## Context

Fix for **OBS-235**, found by T-2941's rehearsal of the arc-017 operator trial.

The onboarding curriculum's defining design decision — *route to corpus maps rather than
embed content* — is inert in every consumer. The eleven `## For the Operator` sections
carry 10 `fw corpus explain` invocations across 4 maps; all 10 fail with rc=2 in a fresh
`fw init` project because neither the reader nor the maps are vendored:

    python3: can't open file '<proj>/.agentic-framework/tools/corpus_explain.py'

`do_vendor`'s canonical includes list (`bin/fw:372`) carries `bin lib agents web docs
policy .tasks/templates` + four loose files. `tools/` has never been in it, and neither
has the corpus store. This is the same class as two entries already in that list:
**T-2656** (secret-scan pattern data — scanner shipped, catalogue didn't, so consumers ran
patternless) and **T-2674** (`status-transitions.yaml` — consumers' `FRAMEWORK_ROOT` is
`.agentic-framework/`, so an omitted file freezes them at vendor-seed time). Each was
"the script ships but the thing it reads does not".

No code change is needed for path resolution: `tools/corpus_explain.py:32` sets
`REPO_ROOT = Path(__file__).resolve().parents[1]` and the store is `REPO_ROOT/.context/
designer/projects`. Vendored into `.agentic-framework/tools/`, that resolves to
`.agentic-framework/.context/designer/projects/` — framework-relative by construction,
which is the direction the T-2648 audit check requires for framework-owned assets.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tools/` is in `do_vendor`'s includes list with an origin comment in the style of
      its siblings (T-2656 / T-2674 name the failure they prevent, not just the addition)
- [x] The framework's published `aef-*` corpus maps are vendored; `draft-*` and scratch
      maps are NOT — consumers get the framework's own lifecycle maps, not our WIP
- [x] A fresh `fw init` project resolves all four routed map ids: `aef-task-lifecycle`,
      `aef-session-lifecycle`, `aef-audit-cron`, `aef-inception-flow` — measured by
      running them in the consumer, not by checking the files landed
- [x] Drift guard: a test asserts every `aef-*` map in the store is reachable from a
      consumer, so adding a seventh map without vendoring it fails rather than silently
      re-creating this bug (the includes list is explicit, so additions can drift)
- [x] The guard is proven able to fail, not merely observed green — a guard seen only
      green is indistinguishable from one that cannot go red

## Evidence

**Before** (fresh `fw init`, vendor set `agents bin docs lib policy web`):

    .agentic-framework/bin/fw corpus explain aef-task-lifecycle   → rc=2  (4/4 maps)
    python3: can't open file '<proj>/.agentic-framework/tools/corpus_explain.py'

**After** (same procedure, re-inited from scratch):

    aef-task-lifecycle      OK (73 lines)
    aef-session-lifecycle   OK (54 lines)
    aef-audit-cron          OK (50 lines)
    aef-inception-flow      OK (47 lines)
    draft-*/scratch leaked to consumer: 0

**Guard falsified, not just observed green.** Stripping the two added include lines from
a copy of `bin/fw` and running the same extraction the tests use:

    leg1 (tools vendored)  on FIXED   : PASS
    leg1 (tools vendored)  on STRIPPED: FAIL   ← goes red
    leg2 (store vendored)  on STRIPPED: FAIL   ← goes red

Size: +356K reader, +196K maps; 636K of drafts deliberately excluded.

## Decisions

### 2026-08-12 — wholesale include minus drafts, not an explicit aef-* list

- **Chose:** include `.context/designer/projects` entirely and exclude
  `draft-*` + `t2584-scratch`.
- **Why:** an explicit six-entry `aef-*` list is silently wrong the first time a seventh
  map is added — which is *precisely the failure shape this task is fixing*. Naming the
  drafts instead makes new published maps vendor themselves, so the default is correct
  and the exception is the thing you have to remember. AC #4's drift guard then asserts
  that property rather than a snapshot of today's six.
- **Rejected:** enumerating the six current maps (drifts, and re-creates this bug);
  vendoring the store wholesale including drafts (ships our WIP design artefacts into
  every consumer for no benefit, and 636K of it).

### 2026-08-12 — no code change to path resolution

- **Chose:** rely on `corpus_explain.py`'s existing `Path(__file__).parents[1]` root.
- **Why:** vendored to `.agentic-framework/tools/`, that already resolves the store to
  `.agentic-framework/.context/designer/projects/` — framework-relative, which is the
  direction audit's T-2648 check requires for framework-owned assets. The `aef-*` maps
  describe the *framework's* lifecycles; a consumer's own maps live in its own
  `.context/` and are untouched.
- **Rejected:** adding a PROJECT_ROOT fallback — it would make a consumer's own map
  shadow a framework map of the same id, and T-2648 exists to prevent exactly that.

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

out=$(bats tests/unit/t2942_corpus_reachable_in_consumer.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'

# The maps must still resolve here too — vendoring must not have moved the store
# out from under the framework's own reader.
for id in aef-task-lifecycle aef-session-lifecycle aef-audit-cron aef-inception-flow; do bin/fw corpus explain "$id" > /tmp/.t2942-ce.out 2>&1 || exit 1; done

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-12T12:18:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2942-vendor-the-corpus-reader-and-aef-maps-so.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5183755c
- **Timestamp:** 2026-08-12T12:26:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T12:26:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
