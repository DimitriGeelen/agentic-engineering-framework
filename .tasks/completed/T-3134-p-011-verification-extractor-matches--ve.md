---
id: T-3134
name: "P-011 verification extractor matches ## Verification as a prefix, so the task
  template's own comment injects prose into the executed block"
description: >
  lib/verification-port.sh:extract_verification_block uses sed -n '/^## Verification/,/^##
  /p' — unanchored start pattern, and sed ranges repeat. The shipped task template
  contains a line starting '## Verification' at column 0 inside the Human-AC HTML
  comment, so EVERY task from that template opens a second range whose prose is handed
  to the loop that evals verification commands. Only T-2991's parseable-check stands
  between that and execution. lib/reviewer/static_scan.py:extract_section does the
  same job correctly.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/verification-port.sh]
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
created: 2026-08-25T08:55:11Z
last_update: 2026-08-25T09:28:07Z
date_finished: 2026-08-25T09:28:07Z
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
  - ts: '2026-08-25T09:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=226,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-25T09:00:20Z'
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

# T-3134: P-011 verification extractor matches ## Verification as a prefix, so the task template's own comment injects prose into the executed block

## Context

`lib/verification-port.sh:extract_verification_block` is the P-011 gate's eye. It
used `sed -n '/^## Verification/,/^## /p'` — a start pattern that matches as a
PREFIX, in a range construct that RE-OPENS every time the start pattern matches
again. Two failure modes fall out, and the second is the one that actually bit.

INJECTION: a later heading that merely begins with those words
(`## Verification Provenance`) opens a second range whose prose is handed to the
loop in `update-task.sh` that evals verification commands.

SUPPRESSION: the shipped task template carries a line beginning `## Verification`
at column 0 *inside* the Human-AC HTML comment, and that comment sits BEFORE the
real heading. sed opens on the comment line and closes on the next `^## ` line —
which is the real `## Verification` heading. The heading is eaten as a
terminator, never opens a range of its own, and the commands below it are never
extracted. `extract_verification_block` returns empty, P-011 hits
`[ -z "$verify_cmds" ] && return 0`, and the gate reports success having run
nothing.

Origin: OBS-343, filed after adding a `## Verification Provenance` section to
T-3132 caused the gate to try to execute that section's prose. The corpus scan
that followed showed injection was the *rarer* mode.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] AC1 — `extract_verification_block` matches `## Verification` only as a
      complete heading. A section whose heading merely *begins* with those words
      (`## Verification Provenance`, `## Verification Notes`) does not open a
      block.
- [x] AC2 — Only the FIRST matching section is extracted. A second `## Verification`
      heading anywhere in the file contributes nothing, so the repeating-range
      behaviour cannot return.
- [x] AC3 — The shipped task template no longer injects. Extracting from a task
      built from the template yields **zero** lines out of the Human-AC comment
      block. This is the case that makes it a live hazard rather than a naming
      footgun: the template itself carries `## Verification` at column 0 inside
      an HTML comment, so every task inherits it.
- [x] AC4 — Command extraction is UNCHANGED for well-formed tasks. Measured over
      the real corpus: report how many task files yield a different command set
      before vs after, and account for every difference. A silent change in the
      population the gate runs over is the same class as the bug being fixed.
- [x] AC5 — The control fails against pre-change code. Fixtures only (L-599) —
      no assertion pinned to a live task id or to the live corpus. Report
      "N of M fail against pre-change code" and name regression guards separately.
- [x] AC6 — The divergence is closed, not just this instance.
      `lib/reviewer/static_scan.py:extract_section` already did this correctly and
      nothing compared the two. Add a check that both extractors agree on the same
      inputs, so the next fix to one cannot silently leave the other behind.
- [x] AC7 — T-2991's parseable-check still fires. This fix removes the *cause*; it
      must not remove the *last line of defence* that caught it twice. A test
      asserts a genuinely unparseable block is still refused.

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

# The extractor itself
bash -n lib/verification-port.sh

# Assert on the FUNCTION BODY, not the file. The file also carries a comment that
# quotes the defective sed expression verbatim, so a whole-file grep answers a
# different question than the one being asked.
awk '/^extract_verification_block\(\)/,/^}/' lib/verification-port.sh > /tmp/.t3134c
grep -qF 'awk' /tmp/.t3134c
grep -qF '^## Verification[[:space:]]*$' /tmp/.t3134c
! grep -qF 'sed -n' /tmp/.t3134c

# The control. Guard form per L-387/T-2738: redirect, then grep the file, so the
# producing command's exit code stays in the verdict and a partial failure cannot
# satisfy a pass marker.
bats tests/unit/verification_extractor_anchoring.bats > /tmp/.t3134a 2>&1 && grep -q '^ok 10 ' /tmp/.t3134a && ! grep -q '^not ok' /tmp/.t3134a

# AC6 — the sibling extractor this one had silently diverged from still imports
python3 -c "import sys; sys.path.insert(0,'.'); from lib.reviewer.static_scan import extract_section; assert extract_section('## Verification\nX\n\n## Next\n','Verification').strip()=='X'"

# AC7 — T-2991's parseable-check, the last line of defence, is still wired
grep -q 'check_verification_parseable' lib/verification-port.sh
grep -q 'check_verification_parseable' agents/task-create/update-task.sh

# The pre-existing suite over this same file must stay green
bats tests/unit/verification_port_hardcode.bats > /tmp/.t3134b 2>&1 && grep -q '^ok 1 ' /tmp/.t3134b && ! grep -q '^not ok' /tmp/.t3134b

## RCA

**Symptom:** Adding a `## Verification Provenance` section to T-3132 made the
P-011 close gate try to execute that section's English prose. Investigating that
turned up the larger case: two *completed* tasks had their verification gate run
zero commands and report no problem.

**Root cause:** `sed -n '/^## Verification/,/^## /p'`. The start address is an
unanchored prefix match, and a sed range re-opens every time its start address
matches again. The shipped task template contains `## Verification` at column 0
inside the Human-AC HTML comment, positioned before the real heading, so the
range opens on the comment and closes ON the real heading — consuming it.

**Why structurally allowed:** the failure is a *false green*. A suppressed block
is indistinguishable from a task that legitimately has no verification commands:
both reach `[ -z "$verify_cmds" ] && return 0` and both print nothing. A red gate
gets looked at; a green gate that asserted nothing never prompts anyone. The
second enabler is a silent divergence — `lib/reviewer/static_scan.py:extract_section`
has always anchored correctly, and nothing ever compared the two, so one stayed
wrong for as long as nobody hit it.

**Prevention** (distinct from the fix):
1. `tests/unit/verification_extractor_anchoring.bats` — 6 of 10 tests fail
   against the pre-change extractor; the 4 that do not are labelled regression
   guards.
2. AC6's cross-extractor agreement test, so the next fix to either side cannot
   silently leave the other behind.
3. T-2991's `check_verification_parseable` is retained and asserted: this fix
   removes the cause, not the last line of defence.

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

### 2026-08-25 — awk with an explicit first-range flag, not a tighter sed address
- **Chose:** replace the sed range with awk that anchors the heading
  (`/^## Verification[[:space:]]*$/`) and carries a `seen` flag so only the FIRST
  matching section is ever extracted.
- **Why:** anchoring alone fixes injection but leaves the repeating-range
  behaviour, which is the part that is hard to reason about and easy to
  reintroduce. An explicit flag makes "first block only" a stated property rather
  than an emergent one.
- **Rejected:** `sed -n '/^## Verification$/,/^## /p'` — one character, but sed
  ranges still repeat, so a second exact heading would still contribute.
- **Rejected:** calling `static_scan.extract_section` from shell — correct, but
  it puts a python import on the hot path of a gate that must work when the
  python side is broken.

### 2026-08-25 — the control's negative assertions are `[[ ]]`, not `! ... | grep`
- **Chose:** every "must not contain" assertion is `[[ "$output" != *x* ]]`.
- **Why:** bash exempts from errexit any command whose return value is inverted
  with `!`, so a non-final `! echo "$output" | grep -q x` inside a bats test can
  never fail it. This file's first draft used that form, and test 3 was GREEN
  against the unfixed extractor while the prose it asserted absent was
  demonstrably in the output. Proven with a three-line bats fixture:
  non-final `! true` passes, final `! true` fails, non-final `[[ a != a ]]` fails.
- **Impact:** the switch moved this file from 5/10 to 6/10 discriminating.
- **Wider:** the same dead-assertion shape exists in 106 places across 66 bats
  files in this repo. Out of scope here (one bug, one task) — filed separately.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-25T08:55:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3134-p-011-verification-extractor-matches--ve.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2cf9fa41
- **Timestamp:** 2026-08-25T09:28:50Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-25T09:28:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
