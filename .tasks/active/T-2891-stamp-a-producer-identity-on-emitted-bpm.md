---
id: T-2891
name: "stamp a producer identity on emitted BPMN definitions (832 rail 492/493)"
description: >
  832 measured their side and shipped option 2: their emitter overwrites a foreign exporter with their own, and drops exporterVersion entirely -- same reconstruct-the-position mechanism T-2884 measured on ours. At 493 they added a consequence we did not have when the question was asked: their T-406 fix now gates doc-comment suppression on producer identity, so a peer document whose rationale opens with their trailer words survives import IF the document names its producer. We stamp nothing, so our documents are still destroyed on their import. Decide whether to stamp, and if so stamp the true producer of these bytes (tools/corpus_spec.py, not the designer). Also measure whether workflowRef uuids survive our round-trip, which 832 flagged as the unmeasured candidate for carrying origin as a separate fact from production.

status: started-work
workflow_type: build
owner: agent
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
created: 2026-08-09T10:47:41Z
last_update: 2026-08-09T10:47:41Z
date_finished: null
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

# T-2891: stamp a producer identity on emitted BPMN definitions (832 rail 492/493)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `workflowRef` round-trip survival is **measured** through our own
      round-trip, not asserted — 832 flagged it as the unmeasured candidate for
      carrying origin, and neither side should lean on it before someone checks
- [x] If we stamp, the stamped value names the **true producer of these bytes**
      (`tools/corpus_spec.py`), not the designer — stamping `aef-workflow-designer`
      would be the same false-authorship record this whole exchange is about,
      pointed at 832 instead of at us
- [x] The stamped value is verifiably **different** from 832's producer string,
      since their T-406 fix suppresses a doc comment unless the document names a
      DIFFERENT producer — a colliding string reintroduces the bug their fix closed
- [x] `exporterVersion` is stamped or deliberately omitted, with the choice
      argued rather than inherited (832 drops theirs; we currently emit neither)
- [x] The existing round-trip census
      (`tests/unit/test_importer_fidelity.py`) is updated, since T-2884 pinned
      "we stamp no exporter" as a measured fact with an obligation to go red and
      name us when that stops being true — that obligation must now fire
- [x] `tests/unit/test_importer_fidelity.py` is green afterwards, with the
      census table reflecting the new reality rather than the old one
- [x] The change is reversible in one edit and that is stated, since the seam
      commitment is the operator's call and not mine
- [x] The stamp's actual COVERAGE is established rather than assumed — which of
      our emitted documents carry it and which do not

## Measurements

**`workflowRef` survives our round-trip.** Positive control on the input, so the
verdict is not the trivial one:

```
IN : 1 ['e32a518c-01de-4243-aafc-691cc99caf0d']
OUT: 1 ['e32a518c-01de-4243-aafc-691cc99caf0d']
VERDICT: PRESERVED
```

Pinned as `test_workflow_ref_survives_the_round_trip`, not left as a rail claim —
832 would be leaning on "they survive", not "they survived once today".

**The fixture population had a hole.** None of the five existing `aef-bpmn`
fixtures carries a `workflowRef` — zero out of five. Every corpus fidelity
verdict measured to date was therefore measured on documents with no cross-map
links at all. Added `task-lifecycle-with-workflowref.bpmn`, a real document from
our own corpus rather than a synthesised one.

**The T-2884 obligation fired.** The previous census asserted `"exporter" not in
dst.attrib` with the message *"we now stamp an exporter — 832's authorship test
and the census table both need updating, and they must be told"*. It went red on
the first run after the stamp landed. That is the test working, and it is why the
census table and the rail post both got updated instead of only the code.

## Coverage — the part that is NOT closed

The stamp is on `emit_map`, which is the `corpus_spec` **generate** path.
`web/blueprints/designer_api.py:141` writes the designer's client bytes
**verbatim** (`(d / f"v{v}.bpmn").write_text(bpmn)`), deliberately, to match
832's reference contract exactly (T-2530).

So documents an operator draws in the designer and saves do **not** carry the
stamp, and those are exactly the documents most likely to carry an authored
rationale worth protecting. Our generated maps are covered; our hand-authored
ones are not.

Extending the stamp to the save path would mean rewriting client bytes
server-side, which breaks the byte-fidelity contract T-2530 exists to hold. That
is a larger seam commitment than this task, and not one to make quietly while
answering a different question. Stated to 832 rather than left for them to
discover — they did the same for us at 493 rather than let "T-406 closed" read as
"peers are safe".

## Decisions

### 2026-08-09 — Stamp a producer identity, and which one

- **Chose:** `exporter="aef-corpus-spec"` on emitted `<definitions>`. No
  `exporterVersion`.
- **Why:** at 491 I argued absence beats false attribution, and that still holds
  for *preserving 832's* string. It does not settle *stamping our own*, which is
  a true statement rather than a false one. 832's objection-in-advance — that
  stamping erases that the process originated with them — they then answered
  themselves: origin is a different fact from production and wants a different
  field. `workflowRef` is that candidate and is now measured to survive. What
  tipped it from tidy to load-bearing was their 493: their T-406 fix suppresses
  an imported doc comment unless the document names a *different* producer, so
  our anonymous documents lose their authored rationale on import.
- **Rejected — `aef-workflow-designer`:** that is 832's tool, not the producer of
  these bytes. Stamping it would be the same false-authorship record this whole
  exchange is about, aimed at them instead of at us. It would also *collide* with
  the string their suppression check tests for difference against, silently
  reinstating the defect their fix closed.
- **Rejected — also stamping `exporterVersion`:** emitted maps are committed
  artifacts and VERSION moves on nearly every handover, so it would rewrite every
  corpus document on every release for a field no reader consumes. 832 drops
  theirs on import regardless.
- **Reversible:** one attribute line in `tools/corpus_spec.py:emit_map`, plus the
  two assertions in the census. If the operator says no, revert both and tell 832.

## Verification

out=$(python3 -m pytest tests/unit/test_importer_fidelity.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
python3 -c "import sys; sys.path.insert(0,'tools'); import corpus_spec as cs; x=cs.emit_map(cs.parse_map(open('tests/fixtures/aef-bpmn/session-handover.bpmn').read())); assert 'exporter=\"aef-corpus-spec\"' in x; assert 'aef-workflow-designer' not in x"
python3 -c "import sys; sys.path.insert(0,'tools'); import corpus_spec as cs; x=cs.emit_map(cs.parse_map(open('tests/fixtures/aef-bpmn/task-lifecycle-with-workflowref.bpmn').read())); assert 'e32a518c-01de-4243-aafc-691cc99caf0d' in x"

### Human
- [ ] [REVIEW] The seam commitment is yours to make, not the agent's
  **Steps:**
  1. Read `## Decisions` in this file — it states what was stamped and why.
  2. The trade: stamping makes a round-tripped document honestly ours AND stops
     832 destroying our authored rationale on import (their 493). Not stamping
     leaves our documents anonymous, which is true of a document that has been
     through both emitters, but costs us the rationale.
  3. 832's own operator has NOT yet ruled — their frozen mapping standard is
     silent on `exporter`, and they flagged it to their operator as an open item
     today. Their recommendation of option 2 is explicitly a recommendation:
     *"stamp it if you agree with the reasoning, not because I said so."*
  4. If you disagree: `git revert` the commit named in `## Updates`, or say so
     and the agent will revert and post the reversal to 832.

  **Expected:** you are content that a document AEF emits carries
  `exporter="aef-corpus-spec"` as a cross-project seam commitment, knowing 832's
  side of the convention is not yet ratified.

  **If not:** say which way and the agent reverts and tells 832 — they asked to
  be told either way, and said they would record it as a permanent seam limit
  rather than treat it as a gap.

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

### 2026-08-09T10:47:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2891-stamp-a-producer-identity-on-emitted-bpm.md
- **Context:** Initial task creation
