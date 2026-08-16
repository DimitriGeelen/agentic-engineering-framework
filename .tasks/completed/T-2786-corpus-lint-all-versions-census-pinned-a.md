---
id: T-2786
name: "corpus-lint all-versions census pinned at 28, live store now 32"
description: >
  corpus-lint all-versions census pinned at 28, live store now 32

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
created: 2026-08-04T12:52:08Z
last_update: '2026-08-16T22:25:17Z'
date_finished: 2026-08-04T12:57:12Z
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
  - ts: '2026-08-16T22:25:17Z'
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

# T-2786: corpus-lint all-versions census pinned at 28, live store now 32

## Context

`tests/unit/test_corpus_lint.py::test_live_corpus_all_versions_census` pins three
numbers over the live designer store: **28** stored versions, **14** carrying
findings, and the exact rule triple for `draft-knowledge-leveling@v3`. The store
has since grown to **32** versions (the `draft-trigger-handling` pair-draft work),
so the first assert fails and the other two never execute.

Its docstring says *"Update deliberately when the store grows or a rule changes."*
So this is a tripwire behaving correctly — corpus growth is supposed to require a
human-or-agent decision, not pass silently. The deliverable is the **deliberate
update**, not a mechanical bump: re-derive all three numbers, name which versions
were added, and confirm the findings movement is explained by those additions and
not by a rule change nobody noticed.

Independently corroborated during T-2784: a `find`-based census of the same store
returned 32 `.bpmn` files, matching `collect_all_versions`.

## Acceptance Criteria

### Agent
- [x] All three pinned values re-derived from the live store and recorded in
      `## Findings` below with the measured numbers, before the test is edited.
- [x] The version delta is enumerated by name (which versions took the count from
      28 to 32), not merely counted.
- [x] The findings-count movement is attributed: each newly-flagged version is
      named with its rule(s), so the new pin is explained rather than accepted.
      If a previously-flagged version stopped being flagged, that is called out
      explicitly — a *drop* means a rule changed and is not a corpus-growth story.
      **Result: count did not move (14 → 14), and the set is provably identical —
      inputs append-only, no rule predicate changed. No drops.**
- [x] `draft-knowledge-leveling@v3` still yields exactly
      `["lane-geometry", "lane-overflow", "lane-overflow"]`. If it does not, this
      task stops and files a separate one — that triple is the T-2694/832-rail
      headline witness and its movement is a different investigation.
- [x] The updated docstring states the new numbers AND the date/reason for the
      move, matching the existing T-2689-style provenance comments in this file.
- [x] `test_live_corpus_all_versions_census` passes.
- [x] No other test in `tests/unit/test_corpus_lint.py` regresses (whole-file run
      compared against its pre-edit result, both recorded in `## Findings`).

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
python3 -m pytest tests/unit/test_corpus_lint.py -q > /tmp/.t2786.out 2>&1 && grep -q "27 passed" /tmp/.t2786.out
python3 -m pytest tests/unit/test_corpus_lint.py::test_live_corpus_all_versions_census -q > /tmp/.t2786b.out 2>&1 && grep -q "1 passed" /tmp/.t2786b.out

# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## Findings

### Re-derived values (measured before editing the test)

| Pinned value | At pin (T-2694) | Now | Moved? |
|---|---|---|---|
| stored versions | 28 | **32** | yes, +4 |
| versions carrying findings | 14 | **14** | no |
| `draft-knowledge-leveling@v3` rules | `lane-geometry, lane-overflow, lane-overflow` | identical | no |

### The version delta, by name

Pin commit `731abc5dd` (2026-07-31). `git ls-tree` at that commit lists exactly
**28** `.bpmn` under the store, matching the pin. `git diff --name-status PIN HEAD`
returns **four additions and nothing else**:

```
A  .context/designer/projects/draft-arc-lifecycle/v1.bpmn
A  .context/designer/projects/draft-arc-lifecycle/v2.bpmn
A  .context/designer/projects/draft-arc-lifecycle/v3.bpmn
A  .context/designer/projects/draft-arc-lifecycle/v4.bpmn
```

None of `draft-arc-lifecycle@v1..v4` appears in the flagged set — all four lint
clean. That is the whole explanation for "+4 versions, +0 findings".

### Why the findings count holding at 14 needed proving, not asserting

"14 then, 14 now" is consistent with the same 14 **and** with two independent
changes that cancelled. `tools/corpus_lint.py` had changed (+72/−4) over the same
range, so a rule-driven swap was a live hypothesis rather than a paranoid one.

Ruled out on two independent legs:

1. **Inputs are append-only.** Every `.bpmn` change under the store in that range
   is an `A`. No `M`, no `D` — the bytes of the pre-existing 28 are untouched.
2. **The rule set did not change.** The `corpus_lint.py` diff is entirely
   additive *reporting* surface — `census_rows()`, `_print_census()`, a
   `--summary` argument, and one docstring correction. No rule predicate
   (`lane-geometry`, `lane-overflow`, `emitterless-typed-event`, `legacy-ref`)
   is touched.

Same bytes through the same rules produce the same verdicts, so the pre-existing
28 cannot have moved and the 14 is provably the same 14. No version dropped out
of the flagged set.

### Current flagged set (14)

```
aef-dispatch-loop@v1           emitterless-typed-event
aef-dispatch-loop@v2           emitterless-typed-event
aef-session-lifecycle@v1       lane-geometry, lane-overflow
draft-exception-handling@v2    lane-geometry
draft-knowledge-leveling@v2    lane-geometry, lane-overflow, lane-overflow
draft-knowledge-leveling@v3    lane-geometry, lane-overflow, lane-overflow
draft-knowledge-leveling@v4    lane-geometry
draft-knowledge-leveling@v5    lane-geometry
draft-knowledge-leveling@v6    lane-geometry, lane-overflow, lane-overflow
draft-knowledge-leveling@v7    lane-geometry, lane-overflow, lane-overflow
draft-knowledge-leveling@v8    lane-geometry, lane-overflow, lane-overflow
draft-task-creation@v2         lane-geometry
draft-trigger-handling@v1      lane-overflow
t2584-scratch@v1               legacy-ref
```

The v4/v5 → v6 repair-then-regress shape that motivated T-2695 is still visible
and unchanged.

### Whole-file regression check

| | result |
|---|---|
| before edit | `1 failed, 26 passed` (the census test) |
| after edit | `27 passed` |

No other test in the file changed state.

### Corroboration

Independently during T-2784, a `find`-based census of the same store returned 32
`.bpmn` files — agreeing with `collect_all_versions()` from a different code path.
Relevant because that census's *first* form read only 19 files (L-545:
`glob('**')` skips dot-directories), so the agreement here is between two
methods that have already been shown capable of disagreeing.

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

### 2026-08-04T12:52:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2786-corpus-lint-all-versions-census-pinned-a.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7e5a4c07
- **Timestamp:** 2026-08-04T12:57:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-04T12:57:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
