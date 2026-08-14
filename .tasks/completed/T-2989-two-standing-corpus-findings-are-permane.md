---
id: T-2989
name: "two standing corpus findings are permanently unactionable as filed"
description: >
  two standing corpus findings are permanently unactionable as filed

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
created: 2026-08-14T15:26:19Z
last_update: 2026-08-14T15:45:43Z
date_finished: 2026-08-14T15:45:43Z
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
  - ts: '2026-08-14T15:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-14T15:30:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2989: two standing corpus findings are permanently unactionable as filed

## Context

T-2985 routed corpus-lint findings into `fw audit`. The first daily run promoted both
standing findings to **PRIORITY ACTIONS** — and neither can be actioned as filed:

| finding | map | why it cannot be fixed |
|---|---|---|
| `legacy-ref` | `t2584-scratch@v1` | `targetWorkflow="t2584-ghost-target"` is a *deliberately* dangling ref. T-2584 was "off-page connectors not working in designer"; the ghost target **is** the reproduction. Fixing it destroys the artefact. |
| `emitterless-typed-event` | `aef-dispatch-loop@v3` | `agt_4_worker`'s typed catch has no in-corpus emitter because the emitter is TermLink, which is not modelled here. A real seam, not a defect. |

This is the failure mode T-2985's own header warned about, arriving one day later: *"an audit
that exits 2 on a correct corpus trains people to stop reading the exit code."* WARN tier
kept the exit code honest, but the priority-action list is a second surface with the same
property — a recommendation nobody can carry out teaches readers to skim the list.

The two need different resolutions, and only one has a marker affordance:

- `emitterless-typed-event` supports `aef:meta seamPending="..."` (`corpus_lint.py:258`).
  Recording the judgement is exactly what it is for.
- `legacy-ref` has **no** marker. So `t2584-scratch` must leave the scanned tier instead.
  The convention already exists: `corpus_lint.py:679` skips `draft-`-prefixed maps as "the
  cheap iteration tier — the standing baseline never moves for them". Six drafts are skipped
  today; a scratch debugging artefact belongs in exactly that tier and is only scanned
  because its name predates the convention.

Reclassify rather than delete: the map documents a real reproduction, and at draft tier it
costs nothing to keep.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `aef-dispatch-loop` `agt_4_worker` carries an `aef:meta seamPending="..."` marker whose
      text names the actual emitter (TermLink, out of corpus scope) — not a generic "known
      seam", which would record that someone silenced it rather than why.
- [x] `t2584-scratch` is reclassified into the existing draft tier, keeping the artefact:
      directory, `meta.json` id, and every in-repo reference move together, with no dangling
      pointer left in `.context/designer/registry.yaml`.
- [x] `fw corpus lint` reports **zero** findings, and the scanned count drops by exactly one
      (the reclassified map) — proving the finding left via the skip tier, not via a rule
      that stopped firing.
- [x] The drafts remain lintable on demand (`corpus_lint.py` accepts an explicit target), so
      reclassification hides the map from the standing baseline without making it unauditable.
- [x] `fw audit --section structure` emits the clean line and no `Corpus lint [` WARN, and
      the audit's PRIORITY ACTIONS no longer carry the two corpus entries.
- [x] A test pins that a seam marker suppresses `emitterless-typed-event` and that removing
      it brings the finding back — otherwise the marker is indistinguishable from a rule that
      silently stopped working.
- [x] The two corpus baseline tests left RED by earlier work today are green, and neither is
      re-pinned to a live defect: `test_live_corpus_current_findings` (stale since T-2984)
      and `test_fires_on_the_live_session_lifecycle_spill` (asserts a spill T-2984 repaired).
      The second moves to a fixture — a rule test that depends on a defect surviving fails
      the moment the defect is fixed.

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

out=$(python3 -m pytest tests/unit/test_corpus_lint.py tests/unit/test_corpus_lint_seam_marker.py tests/unit/test_corpus_lint_lane_overflow.py tests/unit/test_corpus_lint_lane_geometry.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
out=$(bats tests/unit/t2942_corpus_reachable_in_consumer.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
python3 tools/corpus_lint.py --json > /tmp/.t2989.json 2>/dev/null && python3 -c "import json;d=json.load(open('/tmp/.t2989.json'));assert d['findings']==[],d['findings'];assert len(d['scanned'])==8,d['scanned']"
out=$(bin/fw audit --section structure 2>&1); echo "$out" | grep -q "corpus map(s) lint clean" && ! echo "$out" | grep -q "Corpus lint \["

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

**Symptom:** T-2985 wired corpus-lint findings into `fw audit`. The very next daily run put
both standing findings in **PRIORITY ACTIONS** with the mitigation text *"Fix the map…"* —
and neither could be fixed. One is a deliberately dangling ghost ref that exists to reproduce
T-2584; the other's emitter is TermLink, which this corpus does not model.

**Root cause:** T-2985 routed findings to a reader without asking whether every finding was
*actionable* by that reader. The linter's own design already answers this — it has a
`seamPending` marker for judged-and-kept findings and a `draft-` skip tier for maps not held
to the standing baseline — but neither had been applied to the two long-standing entries,
because until T-2985 nothing consumed them and the cost of leaving them was zero.

**Why structurally allowed:** the cost only appears when a finding reaches a surface that
implies action. A detector nobody reads can carry permanent findings harmlessly; a priority
list cannot. T-2985's own header argued this for the exit code (*"an audit that exits 2 on a
correct corpus trains people to stop reading the exit code"*) and chose WARN tier to protect
it — then published the same findings to a second surface where the identical reasoning
applies. The tier was defended; the recommendation text was not.

Corroborating evidence that the naming, not the judgement, was the real gap: `bin/fw:455`
already excluded `t2584-scratch` from vendoring — sitting immediately below the `draft-*`
glob as a hard-coded special case. Two subsystems independently needed "not a published map"
and one had to name the file, purely because its name predated the convention. Renaming it
`draft-t2584-scratch` satisfied both and deleted the special case.

**Prevention:** `tests/unit/test_corpus_lint_seam_marker.py` asserts the marker in both
directions — including that `seamPending=""` does not buy silence — so a clean scan cannot be
confused with a rule that stopped firing. The live baseline (`test_live_corpus_current_findings`)
is now pinned **empty**, with a message telling the next author to fix the map rather than
re-pin the finding, which converts every future finding into a real signal.

**Second defect found while here (own goal).** Two corpus tests were red and unnoticed:

- `test_live_corpus_current_findings` — T-2984 (this morning, mine) changed the corpus and
  did not re-derive the pin. The census docstring already warned about exactly this lapse,
  quoting a previous occurrence at `a25497afe`. Written down, and repeated anyway.
- `test_fires_on_the_live_session_lifecycle_spill` — asserted the live map *has* a 6px spill;
  T-2984 repaired it. The deeper fault is the test's shape, not its number: a rule test
  pinned to a live DEFECT fails the moment the defect is fixed, so it punishes the repair.
  Rewritten against a fixture reproducing the same geometry, with a separate live assertion
  that the map is now clean.

The census pin (16 → 14) is moved with each dropped version named and justified, per the
discipline that file already sets — a count alone cannot distinguish "two fixed" from "two
fixed, one lost".

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

## Recommendation

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
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

### 2026-08-14T15:26:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2989-two-standing-corpus-findings-are-permane.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ceab86e6
- **Timestamp:** 2026-08-14T15:49:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-14T15:45:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
