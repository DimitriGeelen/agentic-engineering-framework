---
id: T-2901
name: "learnings application field is born populated so filled and unfilled are indistinguishable (832 rail-491)"
description: >
  learnings application field is born populated so filled and unfilled are indistinguishable (832 rail-491)

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: [C-002, agents/healing/lib/resolve.sh, bin/fw, lib/harvest.sh, tests/unit/learning_application_birth.bats]
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
created: 2026-08-09T15:50:06Z
last_update: 2026-08-09T15:59:22Z
date_finished: 2026-08-09T15:59:22Z
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
---

# T-2901: learnings application field is born populated so filled and unfilled are indistinguishable (832 rail-491)

## Context

832 raised this at rail 491 §1, measured 2.3% on their side, and explicitly left
the remedy to us — correctly, since per L-559 it belongs at the site of
generation and the generation sites are ours. I acknowledged the debt at rail
501 (*"still owed you from 491, still not counted, and I will not guess at it"*)
and did not pay it until now.

### Measured

    total learnings ......................................  604
    literal "TBD" (generator-written) ....................  572   94.70%
    repeated drift-rotation template .....................   11    1.82%
    genuinely hand-written ...............................   21    3.48%

832 measured 2.3% on the same field shape in a different codebase. Same
magnitude, arrived at independently.

The count itself needed the discipline it is about: `agents/healing/lib/resolve.sh`
wrote a **varying** template (`"Apply when encountering similar $pattern_name
issues"`), and every variant would have counted as hand-written under a naive
distinct-value tally. Classified against the literal generator strings instead
(it contributes 0 rows, so the 21 is clean).

### Four sites, not two

832 named two. Enumerating rather than assuming found a third and a fourth:

| Site | Value written at birth |
|------|------------------------|
| `agents/context/lib/learning.sh:100` | `TBD` |
| `agents/context/lib/learning.sh:112` | `TBD` (the `END{}` fallback branch) |
| `lib/harvest.sh:316` | `[Review and refine]` |
| `agents/healing/lib/resolve.sh:137` | `Apply when encountering similar X issues` |

AC-2 was written to force this check precisely because a report naming N sites
reads as *the* set. It named half.

### There is a consumer

Checked before touching the emitter, because T-2899's IW-2 is the same shape —
a field written by an emitter whose consumers were never enumerated.
`agents/context/lib/memory-recall.py:117` folds `application` into the search
corpus (`f"{text} {context} {application}"`), so all 572 rows contribute a
literal `tbd` token to `fw recall` relevance. Absence is safe there — the reader
already uses `.get("application", "")`.

### Decision

Stop writing the field at birth, at all four sites. Absence is the honest signal.

**Existing rows are NOT rewritten.** 572 `TBD` values are a record of what was
actually written; blanking them would destroy the evidence for the measurement
above. `fw learnings --unfilled` therefore reads both shapes — absent and legacy
placeholder — and says so in-source.

### Found on the way out

The property leg of the new test failed on `L-007`, which turned out to be two
different learnings sharing one id. **learnings.yaml holds 24 duplicate ids.**
Filed as T-2902, not fixed here (one bug, one task). L-009's own text is
*"Removed duplicate L-013 entry and filled TBD application field"* — so this was
hand-patched once in T-075 and the allocator was never fixed, which is L-559's
generalise-vs-remedy split showing up a third time.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The real fill rate is measured and recorded: total learnings, how many carry
      a birth-written boilerplate `application:` value, how many carry a distinct
      hand-written one. Boilerplate must be identified by comparing against the
      literal strings the generation sites write, not by eyeballing
- [x] Every site that writes `application:` at birth is enumerated (832 named
      `agents/context/lib/learning.sh` and `agents/healing/lib/resolve.sh`;
      confirm those two are the complete set rather than assuming it)
- [x] Decided and implemented: either the field stops being written at birth, or
      it keeps being written and the reason a born-populated field is acceptable
      here is stated in-source at each site. Not left as "measured, unresolved"
- [x] Whatever is decided, an unfilled learning is distinguishable from a filled
      one by a deterministic check — demonstrated by a command whose output
      differs between the two cases
- [x] Existing learnings are not silently rewritten: any backfill or blanking of
      the ~N already-born-populated entries is either done explicitly with the
      count reported, or explicitly not done with the reason recorded

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

out=$(bats tests/unit/learning_application_birth.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n agents/context/lib/learning.sh && bash -n lib/harvest.sh && bash -n agents/healing/lib/resolve.sh && bash -n bin/fw
# no generation site writes a placeholder (excludes vendored copy, worktrees, and this task's own tests)
[ -z "$(grep -rn 'application: *"\?\(TBD\|\[Review and refine\]\|Apply when encountering similar\)' --include='*.sh' --include='*.py' . 2>/dev/null | grep -v '^\./\.git' | grep -v '^\./\.agentic-framework/' | grep -v '^\./\.claude/worktrees/' | grep -v '^\./tests/')" ]
# the reader surface exists and reports a count
out=$(bin/fw learnings --unfilled 2>&1); echo "$out" | grep -qE 'Learnings with no application recorded.*[0-9]+/[0-9]+'
# and the newest learning is born without the key
python3 -c "import yaml,sys; ls=yaml.safe_load(open('.context/project/learnings.yaml'))['learnings']; sys.exit(0 if 'application' not in ls[-1] else 1)"

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

### 2026-08-09T15:50:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2901-learnings-application-field-is-born-popu.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c450d73b
- **Timestamp:** 2026-08-09T15:59:32Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-09T15:59:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
