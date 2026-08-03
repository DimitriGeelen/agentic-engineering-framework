---
id: T-2763
name: "sweep verification blocks for G-015-shaped assertions on always-moving globals
  (832 RAIL-409 tip)"
description: >
  sweep verification blocks for G-015-shaped assertions on always-moving globals (832
  RAIL-409 tip)

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
created: 2026-08-03T12:10:28Z
last_update: 2026-08-03T12:18:00Z
date_finished: 2026-08-03T12:18:00Z
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
  - ts: '2026-08-03T12:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-03T12:15:12Z'
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

# T-2763: sweep verification blocks for G-015-shaped assertions on always-moving globals (832 RAIL-409 tip)

## Context

832 hit the G-015 shape three times in one verification block (their RAIL-409, T-354)
and explicitly passed the hypothesis over:

> Worth grepping your side for release-task gates that pin `latest`/`VERSION`/current-sha
> rather than the artifact they actually produced.

The shape: a verification line that asserts *"the project's current release state is X"*.
True at the instant it is written, false forever after the next release — and it fails in
the **blocking** direction, so a later, unrelated task is refused at close for a reason
that has nothing to do with what it shipped.

Two denominators must be reported with any count here, both from 832's own corrections:
- **RAIL-410:** a count quoted without the size of the unexamined region is doing the work
  of a point estimate. Report shaped/unshaped split, not just hits.
- **RAIL-408:** any bucket whose members carry a per-member verdict must report the
  *distribution* of those verdicts, not its cardinality.

And **RAIL-410's second trap applies to this task directly**: adding this task's own
`## Verification` lines changes the corpus being measured. The measurement must be taken
at a stated commit, and this file's own lines must be excluded or accounted for.

## Acceptance Criteria

### Agent
- [x] Corpus measured and reported with its denominator: total verification lines, and
      the shaped/unshaped split, at a named commit sha
- [x] Candidate moving-global assertions enumerated (`VERSION`, `latest:`, current-sha,
      `rev-parse HEAD`), each classified per-member rather than counted in bulk
- [x] Each candidate classified **wrong** (asserted a property the task never durably
      held → repairable) vs **correctly failing** (reports a real regression → must NOT
      be "repaired"). 832's distinction; only the first may be touched
- [x] Every candidate actually executed, not read — the classification states the observed
      exit code, not an inference from the line's text
- [x] Any line found red AND wrong is repaired to assert the artifact the task produced,
      with the baseline being the literal recorded at the time, never re-derived from the
      subject today
- [x] The measurement's own self-inclusion is stated (this task's verification lines are
      part of the corpus it counts)
- [x] Findings reported to 832 on the rail with the denominator attached

## Findings

**Measured at `d0c1e1a2731d6492cae65e907f2888c5f52e11eb`.**

```
task files with ## Verification : 2617
verification lines, total       : 9100   100%
  SHAPED   (top-level ';')      : 1982    21.8%
  UNSHAPED                      : 7118    78.2%
```

832's 24.7/75.3 split reproduces almost exactly here at 21.8/78.2 — on a corpus 6.8×
larger. Whatever the shaped-only scans have covered, roughly the same three-quarters is
unexamined on this side too.

**Self-inclusion (RAIL-410's trap, which applies to this task):** the 9100 includes this
task's own verification lines and T-2632's repaired ones. The count moved while being
taken. That is why the sha is quoted; without it the figure is unreproducible.

### Candidates: 44, and the bulk count is the wrong unit

Per RAIL-408, the distribution rather than the cardinality — because the 44 splits into
two classes that fail in opposite directions:

| class | n | verdict |
|-------|---|---------|
| **Durable** — pins a specific immutable artifact (`sha256sum vendor/…-0.5.0.html`, fixture shas) | 38 | correct, leave alone |
| **Moving** — pins an always-current global (live `/designer/app` sha, `meta.json.latest`) | 6 | G-015 |

A count of "44 G-015 candidates" would have been wrong by 7×. The grep finds the
*vocabulary*; only execution finds the *defect*.

### Moving class, executed (not read)

Live `/designer/app` now serves `cab3c751…` (the 0.8.0 pin):

```
GREEN  T-2673 (0.8.0)   <- the current pin, true today, false at the next re-pin
RED    T-2632 (0.7.0)   <- ACTIVE, owner: human, in the review queue
RED    T-2611 (0.3.1)   archived, inert
RED    T-2617 (0.4.0)   archived, inert
RED    T-2626 (0.5.0)   archived, inert
RED    T-2627 (0.6.0)   archived, inert
```

**T-2632 is our T-178.** `status: work-completed`, `owner: human`, sitting in `active/`.
When the operator ticks its Human AC, P-011 runs the block and refuses — for a property
unrelated to what T-2632 shipped.

Note T-2673 is green *only because it happens to be the current pin*. It is the same
defect in its true-for-now phase, and re-pinning to 0.9.0 turns it red. Green is not
evidence of correctness here; it is evidence of timing.

### Classification: wrong, not correctly-failing

All five reds asserted *"the live server currently serves version X"*. The artifact each
task actually produced — the vendored HTML — is asserted on a **separate, adjacent line**
that is **still green**: T-2632's `vendor/…-0.7.0.html` hashes to `472d6a5d…`, exactly
the literal it recorded. Nothing regressed; the assertions expired. Repairable.

### Repairs (T-2632 only)

Two G-015 lines in that one block — 832 found three in one block, same clustering:

1. **served-sha line** → now asserts the durable invariant *the server serves the build
   the pin names*, with the baseline read from `policy/designer-pin.yaml`, never
   re-derived from the server (re-deriving the expectation from the subject is a
   tolerance answerable only to itself). Proven both directions: green today, red against
   a wrong pin.
2. **`meta.json.latest = 3`** → `-ge 3` (actual is now 6). What the task durably
   established is that the revision it created exists and was not rolled back — the floor,
   not the moment.

Block after repair: **5/6 green**, one deliberately red.

### Deliberately NOT repaired

The `/api/overlay` line expects `"annotations"` + `"tone"`; the endpoint is healthy but
returns `{"type":"aef:annotate","nodes":[…]}`. That is a **contract** change, not an
expired global — either wrong (superseded by the T-2634 wire-shape convergence) or
correctly failing (real payload regression). Those need opposite responses, and the
evidence to choose was not in hand. Left red and filed as **T-2764**. Editing it to green
would be the bypass-wearing-a-repair-costume 832 named at RAIL-409.

### Archived four: not touched

`T-2611/2617/2626/2627` are in `completed/` — inert, never re-run. Repairing them edits
closed records for zero live benefit. Same call 832 made on their archived corpus, and
same reasoning. Recorded here so the decision is visible rather than an omission.

### Structural note

The class is stronger than "release tasks pin the wrong thing". Every instance here has
the durable assertion and the expiring one **on adjacent lines of the same block**,
written in the same sitting. At authoring time "the artifact I shipped" and "what the
server currently serves" are indistinguishable — they separate only on the next release.
The task author cannot see the difference at the moment they are most confident.

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

# Measurement is reproducible at a stated sha (RAIL-410: a corpus figure needs its commit).
test -f .tasks/active/T-2632-designer-070-adoption--re-pin--annotatio.md
# The repaired T-2632 lines must be green.
grep -q 'pinned=$(python3 -c "import yaml' .tasks/active/T-2632-designer-070-adoption--re-pin--annotatio.md
grep -q "'latest'\])\")\" -ge 3" .tasks/active/T-2632-designer-070-adoption--re-pin--annotatio.md
# The server must serve the build the pin names (the durable invariant that replaced the expiring one).
served=$(curl -sf "$(bin/fw watchtower url)/designer/app" | sha256sum | cut -d' ' -f1); pinned=$(python3 -c "import yaml;print(yaml.safe_load(open('policy/designer-pin.yaml'))['sha256'])"); [ -n "$pinned" ] && [ "$served" = "$pinned" ]
# The deliberately-unrepaired line must still be tracked, not quietly dropped.
grep -q 'T-2764' .tasks/active/T-2632-designer-070-adoption--re-pin--annotatio.md

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

### 2026-08-03T12:10:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2763-sweep-verification-blocks-for-g-015-shap.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-910dd634
- **Timestamp:** 2026-08-03T12:18:01Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-03T12:18:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
