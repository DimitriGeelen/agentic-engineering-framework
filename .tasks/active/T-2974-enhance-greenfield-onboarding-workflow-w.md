---
id: T-2974
name: "Enhance greenfield onboarding workflow with detailed explanations"
description: >
  Enhance greenfield onboarding workflow with detailed explanations

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [designer-corpus, curriculum]
components: []
related_tasks: [T-2972, T-2720]
arc_id: onboarding-curriculum
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
created: 2026-08-13T23:25:24Z
last_update: '2026-08-13T23:30:13Z'
date_finished:
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
  - ts: '2026-08-13T23:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-13T23:30:13Z'
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

# T-2974: Enhance greenfield onboarding workflow with detailed explanations

## Context

T-2972 shipped `aef-greenfield-onboarding` v1 — a structurally correct BPMN map of the
T-001→T-005 prologue, but with one-sentence node descriptions. Operator feedback on the
rendered diagram: *"i have it but it pretty limited and also we still missing teh comment
or eplenations"*. The map showed **what** the sequence is; it did not carry **why each step
matters to the operator or what they can do while it runs** — which is the whole point of a
curriculum artefact, and is exactly the content the seed tasks' `## For the Operator`
sections already carry in prose.

v2 lifts that operator-facing prose onto the `<aef:meta note="…"/>` attribute channel — the
one both readers actually read — so `fw corpus explain aef-greenfield-onboarding` becomes a
self-contained teaching surface rather than a bare box-and-arrow sketch.

Source of truth for the prose: `lib/seeds/tasks/greenfield/T-00*.md` `## For the Operator`.

**Surface caveat (found during build, see Evolution):** the CLI reads the notes; the pinned
`/designer` build does **not**. `note` is absent from `AEF_FIELDS`
(`aef-workflow-designer-0.8.0.html:1771`), so the inspector panel never offers or displays
it — the designer only round-trips it through `metaKeys` on export. Making the prose visible
in `/designer` is upstream work in 832, not something AEF can fix (the blueprint is read-only
by contract, `policy/designer-pin.yaml`). This task delivers the CLI surface and reports the
designer gap upstream.

## Acceptance Criteria

### Agent
- [x] `v2.bpmn` exists with a `WHAT'S HAPPENING / WHY IT MATTERS / WHAT YOU CAN DO / KEY LEARNING / NEXT` explanation on every T-001…T-005 node
- [x] The prose is on a channel a reader actually reads — `<aef:meta note="…"/>` attributes, not `<aef:description>` child elements — and reaches `fw corpus explain` output
- [x] `meta.json` lists v2 and sets `latest: 2`, so `fw corpus explain aef-greenfield-onboarding` serves the enhanced version
- [x] Node/flow topology is unchanged from v1 (same 5 tasks, same 2 lanes, same agent/human authority split) — this task enriches content, not structure
- [x] `fw corpus lint` reports zero findings against `aef-greenfield-onboarding`
- [x] No hard-coded Watchtower port/host literal survives in the map (CLAUDE.md §Watchtower Port) — the T-002 node described the review link as `http://192.168.10.107:3000/…`
- [x] Regression test pins channel, multi-line survival, and explain's indentation (`tests/unit/t2974_greenfield_operator_prose.py`)

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

- [ ] [REVIEW] The node explanations answer the "limited / missing explanations" feedback
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw corpus explain aef-greenfield-onboarding`
  2. Read the `note:` block under T-001 (the first node) and under T-002 (your decision node)
  **Expected:** each node tells you what is happening, why it matters to you, what you can do
  meanwhile, and what you should take away — not just a one-line "the agent runs X".
  **If not:** name the node that still reads thin and the question it left unanswered; that
  becomes the next enrichment pass (the prose source is `lib/seeds/tasks/greenfield/T-00*.md`).
  **Note — why the CLI and not `/designer`:** the pinned designer build does not display
  `note` at all (`AEF_FIELDS` has no entry for it), so `/designer` will still show bare boxes
  no matter how good the prose is. That gap is upstream in 832 and is reported, not fixed
  here. Do not re-save this map from `/designer` in the meantime — the designer's `escAttr`
  does not encode newlines, so a round-trip collapses the five sections into one run-on line.

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

python3 -m pytest tests/unit/t2974_greenfield_operator_prose.py -q > /tmp/.t2974a 2>&1 && grep -q passed /tmp/.t2974a
bin/fw corpus explain aef-greenfield-onboarding > /tmp/.t2974b 2>&1 && grep -q "version v2" /tmp/.t2974b
# corpus lint exits 1 on findings in OTHER maps (aef-session-lifecycle geometry,
# t2584-scratch legacy-ref). The assertion here is scoped deliberately: no finding
# names OUR map. The trailing grep is the verdict by design, not by oversight.
bin/fw corpus lint > /tmp/.t2974c 2>&1 || true; ! grep -q "aef-greenfield-onboarding" /tmp/.t2974c
# corpus_explain.py gained a rendering branch — its own suite must stay green.
python3 -m pytest tests/unit/test_corpus_explain.py -q > /tmp/.t2974d 2>&1 && grep -q passed /tmp/.t2974d

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

### 2026-08-14 — the task was mis-scoped: the prose already existed, the channel was wrong

- **What changed:** the filing assumed v1's explanations were *thin* and needed writing.
  They were not thin — v1 carried them in `<aef:description>` **child elements**, and no
  reader reads that shape. `corpus_spec.py:_ext()` builds its dict from `dict(c.attrib)`,
  so a text-bearing child parses to `{}`; the pinned designer build's per-node vocabulary
  (`aef-workflow-designer-0.8.0.html:9025` `metaKeys`) is attributes too, and `description`
  exists there only as a map-level `workflowMeta` attribute. So the operator's "pretty
  limited / missing the explanations" was not an authoring complaint — it was an accurate
  report of a **silent data-visibility hole**. The prose was in the file and rendered
  nowhere, in both surfaces.
- **Plan impact:** "write richer descriptions" became "move the prose onto the canonical
  `<aef:meta note="…"/>` attribute channel and prove it reaches a reader." Writing more
  prose into the wrong channel would have produced the identical complaint again, with
  more words invisible. Newlines only survive attribute-value normalisation as `&#10;`
  character references (XML 1.0 §3.3.3) — pinned as an executable assertion in the test
  rather than a comment, because it is the reason the channel has a rule.
- **Triggered:**
  - `tests/unit/t2974_greenfield_operator_prose.py` — pins channel, five-section coverage,
    multi-line survival, explain's indentation, and v1↔v2 topology parity.
  - `tools/corpus_explain.py` — multi-line notes now indent their continuation lines;
    flush-left prose dissolved the walkthrough structure at exactly the length where the
    prose becomes worth reading.
  - Two defects the coverage test caught that reading would not have: the T-002 node — the
    **one node where the operator has something to do** — was the only node missing its
    `WHAT YOU CAN DO` section (it was headed `WHAT YOU'LL DO`), and its worked example
    hard-coded `http://192.168.10.107:3000/inception/T-002`, the exact §Watchtower Port
    anti-pattern, inside the artefact that teaches new operators the framework.
  - **Upstream (needs 832) — two defects, both verified against the pinned build, not inferred:**
    1. **`note` is never displayed.** `AEF_FIELDS` (line 1771) lists no `note` entry for any
       node type, and the inspector's Extensions panel iterates exactly that list
       (line 5493). The build round-trips `note` through `metaKeys` on export but offers no
       way to read or author it. So `/designer` shows bare boxes for this map regardless of
       how much prose the file carries — which is very likely what the operator was actually
       looking at when they said "pretty limited". The CLI surface is fixed here; the
       designer surface cannot be fixed from AEF (read-only vendored build by contract,
       `policy/designer-pin.yaml`).
    2. **`escAttr` collapses multi-line values.** Line 8969 escapes `& < > "` but not `\n`.
       A designer re-save writes literal newlines into `note=`, which the next parse
       normalises to spaces — the five sections become one run-on line, silently. Same
       silent-fidelity-loss class as T-2614/T-2682.

    Until both land, edit this map's prose in the file and read it via `fw corpus explain`.

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

**Recommendation:** GO

**Rationale:** Your feedback turned out to be a bug report, not a content note. The
explanations were already written in v1 — they were in `<aef:description>` child
elements, which neither reader reads, so the diagram rendered as bare boxes in both
Watchtower and the CLI. Moving the prose to the `<aef:meta note>` attribute channel makes
it visible without rewriting it. Two further defects surfaced from the coverage test, both
in the T-002 node specifically: the section telling you what to do was missing, and the
review link was hard-coded to this host's IP and port. Everything mechanical is verified;
what's left is whether the explanations now read as genuinely explanatory to you, which is
the one thing I can't check for you.

**Evidence:**
- `fw corpus explain aef-greenfield-onboarding` now serves v2 and prints 589–1794 chars of
  operator prose per node; v1 printed none.
- `tests/unit/t2974_greenfield_operator_prose.py` — 6/6 pass; pins the channel, the
  five-section coverage, multi-line survival, and v1↔v2 topology parity.
- `fw corpus lint` — zero findings against this map (the 4 findings it reports are
  pre-existing, on `aef-session-lifecycle` and `t2584-scratch`).
- Topology is byte-for-byte equivalent to T-2972 v1: same 7 nodes, same 6 flows, same 2
  lanes with the same authority split. This changed what the map says, not what it claims.
- Known limitation, honest version: **`/designer` still shows bare boxes.** The pinned build
  has no `note` field in `AEF_FIELDS`, so it never displays the prose — and re-saving from it
  would collapse the multi-line text (`escAttr` does not encode newlines). Both are upstream
  832 defects, reported, not fixable from AEF. Read the map via `fw corpus explain` until
  they land. If the designer surface specifically is what you need, that is a separate task
  gated on an 832 release, not something this one can close.

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

### 2026-08-13T23:25:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2974-enhance-greenfield-onboarding-workflow-w.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6807608b
- **Timestamp:** 2026-08-13T23:44:30Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
