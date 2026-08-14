---
id: T-2979
name: "existing-project onboarding has no corpus map — the commoner adoption path
  routes nowhere"
description: >
  existing-project onboarding has no corpus map — the commoner adoption path routes
  nowhere

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:onboarding-curriculum, designer-corpus]
arc_id: onboarding-curriculum
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
created: 2026-08-14T07:26:50Z
last_update: '2026-08-14T07:30:13Z'
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
  - ts: '2026-08-14T07:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-14T07:30:13Z'
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

# T-2979: existing-project onboarding has no corpus map — the commoner adoption path routes nowhere

## Context

arc-017's design principle is that the curriculum **routes to corpus maps rather than
embedding content**. The greenfield path honours that: `greenfield/T-001` line 44 offers
`fw corpus explain aef-greenfield-onboarding` — "see the full T-001→T-005 onboarding
prologue as a workflow diagram" (built by T-2972, made legible by T-2974).

The existing-project path has no such map and no such line. Its six seeded tasks route to
four *general* maps (`aef-session-lifecycle`, `aef-task-lifecycle`, `aef-inception-flow`,
`aef-audit-cron`) — each explaining a framework concept, none explaining **the path the
operator is currently walking**. So the operator adopting the framework into an existing
repo — arguably the commoner case, and the one with more to lose — gets strictly less
orientation than the greenfield operator.

This is not a broken thing; it is an absent one, which is why nothing caught it. The eleven
`## For the Operator` sections all exist, and all eleven corpus references resolve. The
asymmetry is only visible when you read both paths side by side, which is exactly what
T-2720's first Human AC asks the operator to do — so it would have surfaced as review
friction on the arc keystone rather than as a finding anyone could act on.

Scope fence: this task ships the missing map plus its routing line. It does **not** rewrite
the six operator sections (their prose is T-2720's review) and does not touch the greenfield
map.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Map ships at `.context/designer/projects/aef-existing-project-onboarding/v1.bpmn`
      with a `meta.json` whose `latest:` points at 1; the BPMN parses and
      `fw corpus explain aef-existing-project-onboarding` renders it without error
- [x] Topology covers the whole seeded path, not a sample: one node per seeded task
      T-001…T-006, plus a start and an end, in agent/human lanes, wired in order by
      sequence flows whose `name=` carries the transition condition
- [x] Every task node carries operator-facing prose on the `aef:meta note` **attribute**
      channel with `&#10;` newlines — zero `aef:description` or other text-bearing
      extension children. T-2974's channel lesson applied at author time rather than
      retrofitted after the prose turns out to be invisible
- [x] `fw corpus lint` reports zero findings against this map — `unread-node-prose`
      (T-2976) included, which is the rule that would fire on the v1 shape T-2972 shipped
- [x] `existing-project/T-001` routes to the map, mirroring the greenfield line, and the
      vendored seed copy is resynced so the T-2240 pre-push self-vendor check stays clean
- [x] A regression test pins node coverage and the prose channel for this map, so a later
      author cannot reintroduce the invisible-prose shape without a red test

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

- [ ] [REVIEW] The map explains the existing-project path rather than describing it

  Same judgement T-2974 asked for on the greenfield map, on its counterpart. The agent can
  check that prose exists, reaches a reader, and covers all six steps — it cannot check
  whether the prose is any good, and this map makes one claim that is a modelling opinion
  rather than a fact: that the operator's role on this path is continuous and advisory
  rather than a gate. If that reads wrong to you, the shape is wrong, not the wording.

  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw corpus explain aef-existing-project-onboarding | less`
  2. Read it as someone who has just pointed `fw init` at a codebase they already own.
  3. Then read the last node, `You: reading alongside…`, and decide whether its claim is
     true — that nothing in this prologue waits for you, and that your authority here is
     exercised by speaking up rather than by the system stopping.
  4. Optionally open Watchtower `/designer` and look at the rendered diagram, where the
     unwired human band is a visual claim rather than a paragraph.

  **Expected:** each step tells you what is happening, why it matters to *your* existing
  codebase specifically, and what is worth your attention — with T-003 (fabric
  registration) clearly flagged as the step most worth your time. The human band reads as
  a deliberate statement about how this path works, not as a disconnected box.

  **If not:** note the node and what it should have said. If the disagreement is with the
  *shape* — you want a blocking human gate somewhere in this prologue — say so plainly:
  that is an arc-017 invariant change and belongs on T-2720, not as a prose fix here.

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

# Map + meta parse at all (the cheapest failure to catch, and the one that hides the rest)
python3 -c "import xml.etree.ElementTree as ET; ET.parse('.context/designer/projects/aef-existing-project-onboarding/v1.bpmn')"
python3 -c "import json,sys; d=json.load(open('.context/designer/projects/aef-existing-project-onboarding/meta.json')); sys.exit(0 if d['latest']==1 else 1)"

# The map renders, and renders the prose — not just the boxes. Both clauses matter:
# T-2972 v1 rendered perfectly with every note invisible, which is the defect T-2974 found.
bin/fw corpus explain aef-existing-project-onboarding > /tmp/.t2979-explain.out 2>&1 && grep -q "note: ═══ WHAT'S HAPPENING" /tmp/.t2979-explain.out

# All nine nodes reach the walkthrough, including the unwired human one
out=$(grep -c "^- \[" /tmp/.t2979-explain.out); test "$out" -eq 9

# Lint clean on this map specifically — unread-node-prose (T-2976) included
out=$(bin/fw corpus lint aef-existing-project-onboarding 2>&1); echo "$out" | grep -q "CLEAN"

# Regression suite green, with the T-2738 guard (pass marker alone survives partial failure)
out=$(python3 -m pytest tests/unit/t2979_existing_project_onboarding_map.py -q 2>&1); echo "$out" | grep -q "9 passed" && ! echo "$out" | grep -q "failed"

# The sibling greenfield pins must stay green — this task shares their reader and renderer
out=$(python3 -m pytest tests/unit/t2974_greenfield_operator_prose.py -q 2>&1); echo "$out" | grep -q "6 passed" && ! echo "$out" | grep -q "failed"

# The seed actually routes to the map — an unreferenced map is one nobody opens
grep -q "corpus explain aef-existing-project-onboarding" lib/seeds/tasks/existing-project/T-001-orientation-and-framework-health.md

# Vendored seed copy is in step, so the T-2240 pre-push self-vendor check stays clean
diff -q lib/seeds/tasks/existing-project/T-001-orientation-and-framework-health.md .agentic-framework/lib/seeds/tasks/existing-project/T-001-orientation-and-framework-health.md

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

### 2026-08-14 — the map turned out to say something the seeds could not

- **What changed:** the task was filed as "port the greenfield map to the other path" — a
  symmetry fix. Reading the six seed sections end to end changed that. The existing-project
  path is not the greenfield path minus an inception; it has a *different operator shape*.
  Greenfield has one blocking human node (T-002, decide what the project is for) and is
  otherwise agent-only. Existing-project has **no** blocking node at all, but five of its
  six steps end by inviting the operator to look and push back — and none of them wait.
  That is arc-017's headline mechanic ("readable alongside, never blocking") stated in the
  seeds without ever being named. A diagram can say it in a way prose cannot: as a lane
  that runs the width of the map and touches no arrow.
- **Plan impact:** the map gained a node the plan did not have (`hum_alongside`) and an
  authored claim rather than only a summary. That is also the reason this task carries a
  `[REVIEW]` Human AC framed around the *shape* being right, not just the wording — the
  agent invented a modelling opinion here and should not be the one to ratify it.
- **Triggered:** no new task. One integration question went to 832 on the chat-arc
  (does an unwired lane node render sensibly in their build) — an answer changes the
  drawing, not the claim.

### 2026-08-14 — the parser refused instead of dropping

- **What changed:** the first draft used `bpmn:manualTask`, which is not in
  `corpus_spec.TYPE_TO_TAG`. The parser **refused the map with a named reason** ("cannot
  round-trip this tag; silently dropping it would lose the node while keeping its flows")
  rather than parsing around it. That is T-2614's data-loss lesson working as designed —
  the same class that destroyed `aef-inception-flow`'s subProcess node during the T-2609
  recreate, caught this time at author time and at zero cost.
- **Plan impact:** none. `userTask` was both supported and semantically the better fit.
- **Triggered:** nothing. Recorded because a gate firing correctly is evidence too, and
  the corpus lint work in this arc has mostly been about the opposite case — the shape
  that fails *silently*.

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

**Rationale:** The gap was real and one-sided — the greenfield operator has had a diagram
of their own path since T-2972, and the existing-project operator, adopting the framework
into a codebase with history and more to lose, had none. The map now exists, covers all six
seeded steps, renders its prose (which is the failure mode T-2974 exists to prevent, and
the one that makes a map look finished while teaching nothing), lints clean, and is routed
to from the seed the operator reads first. Six Agent ACs verified mechanically.

The one thing I cannot self-certify is the modelling claim: that the operator's role on
this path is continuous and advisory rather than a gate. I believe it — it is what the
seeds say five times and never name — but it is an opinion about how the framework should
be understood, and ratifying my own opinion is not verification. That is the single
`[REVIEW]` AC, and it is a shape question, not a proofreading one.

**Evidence:**
- `fw corpus lint aef-existing-project-onboarding` → CLEAN; full corpus scan shows 4
  findings, all pre-existing on other maps (`aef-session-lifecycle`, `t2584-scratch`,
  `aef-dispatch-loop`), none introduced here
- `fw corpus explain aef-existing-project-onboarding` → 9 nodes / 7 flows, every node
  rendering multi-line operator prose under its heading
- `tests/unit/t2979_existing_project_onboarding_map.py` → 9 passed; sibling
  `t2974_greenfield_operator_prose.py` → 6 passed (shared reader/renderer unregressed)
- Node coverage is derived from `lib/seeds/tasks/existing-project/` on disk, not a
  hard-coded list — a seventh seeded task with no node turns the suite red
- `hum_alongside` being unwired is pinned as deliberate with the reason attached, so the
  next author "fixing the disconnected node" gets a red test instead of a silent inversion
  of the arc invariant
- `bin/fw vendor self` run; vendored seed copy diff-clean against the framework original

## Decisions

### 2026-08-14 — how to draw an operator who never blocks

- **Chose:** one `userTask` in the human lane with no incoming or outgoing sequence flows,
  plus a note explaining why it has no arrows.
- **Why:** it is the honest shape. The operator is present at five of six steps and gates
  none of them; any wiring would draw a stop that does not exist, and arc-017's invariant
  is specifically that the curriculum never blocks. Confirmed lint-safe by reading the
  rules rather than assuming: `dangling-flow-ref` flags flows naming absent *nodes*, not
  nodes named by no *flow*, and no rule requires connectivity.
- **Rejected:** (a) *no human lane at all* — accurate about the flow, but silently drops
  the most useful thing the map has to say, and would have made this a strictly worse
  sibling of the greenfield map; (b) *wire the human node into the chain* — draws a
  blocking gate that contradicts the arc invariant, and is the reading a future author is
  most likely to "restore", which is why a test now pins against it; (c) *`textAnnotation`
  + `association`* — the textbook-correct BPMN construct for non-flow commentary, rejected
  because neither `corpus_spec.TYPE_TO_TAG` nor the pinned designer build handles it, so
  it would have been a third silent-drop risk in an arc whose whole subject is content
  that vanishes without a red test.

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

### 2026-08-14T07:26:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2979-existing-project-onboarding-has-no-corpu.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1f6f5961
- **Timestamp:** 2026-08-14T07:36:33Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
