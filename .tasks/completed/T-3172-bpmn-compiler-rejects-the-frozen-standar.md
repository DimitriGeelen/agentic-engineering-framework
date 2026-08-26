---
id: T-3172
name: "BPMN compiler rejects the frozen-standard lane value external as a typo and
  emits a task the standard says must not exist"
description: >
  Inbound field report from 001-CashWeb (their G-055). policy/standards/aef-bpmn-mapping-v1-partI.md
  is 'Part I - Frozen (v1)'; SS3 line 68 ratifies a four-value collapse map: sovereignty->human,
  initiative->agent, authority->agent, external->no task. tools/bpmn_to_tasks.py knows
  three: AUTHORITY_OWNER (:71) has sovereignty+initiative, AUTHORITY_NO_OWNER (:83)
  has authority, AUTHORITY_DIALECT (:85) is their union. external is absent, so it
  falls to the else-branch (:511-521) and is reported as 'very likely a typo or an
  out-of-band value'. Reproduced at HEAD on a minimal external-laned diagram: besides
  the wrong message, the node COMPILES TO A TASK with owner: agent agent - the exact
  inverse of the ratified external->no task. The T-2717/OBS-118 split that gave 'authority'
  its own non-accusing message did not carry external with it. Vocabularies diverge
  three ways: standard 4, pinned editor 5 (adds none), compiler 3.

status: work-completed
workflow_type: build
owner:
horizon: null
tags: []
components: []
related_tasks: [T-3173, T-2717, T-2567]
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
created: 2026-08-26T15:00:51Z
last_update: 2026-08-26T17:55:32Z
date_finished: 2026-08-26T17:55:32Z
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
  - ts: '2026-08-26T15:15:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=219,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T15:15:13Z'
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

# T-3172: BPMN compiler rejects the frozen-standard lane value external as a typo and emits a task the standard says must not exist

## Context

### Repro narrowed by the reporter, 2026-08-26 — confirmed locally at HEAD

001-CashWeb returned the same day to narrow their own repro and withdraw a prediction.
Their correction is **correct**; re-measured here before accepting it.

The authority check runs only for task nodes. `for node in root.iter()` (:421) hits
`if ntype not in TASK_TAGS and not is_inception: continue` (:424) with
`TASK_TAGS = {userTask, serviceTask, scriptTask}` (:51). `unknown_auth` is populated at
:481, downstream of that guard, and the else-branch that emits "very likely a typo"
(:501-521) reads `unknown_auth` alone. Events and gateways never reach it.

**The repro for THIS task is therefore: a TASK in a lane with `authority="external"`** —
not an external lane in general. Measured on a two-lane fixture:

| external lane contains | rc | warning | skeletons |
|---|---|---|---|
| two `intermediateCatchEvent`s only | 0 | none | none — silent |
| one `serviceTask` | 0 | the "very likely a typo" WARN | `owner: agent` |

The second row is this task and is unchanged: both halves of the defect stand — the
message is wrong AND the node compiles to `owner: agent`, the exact inverse of
`external→no task`. So **no AC here needs to change**; the existing "ratified semantics
are implemented, not just the message" AC is what makes the fix behavioural rather than
cosmetic, which is precisely the reporter's first concern.

**The first row is NOT this task.** It is a separate defect — the dialect check is
unreachable for lanes with no task nodes, so even a plain misspelling (`overlrd`)
compiles with zero warnings. Split out as **T-3173 / G-093** per one-bug-one-task.

Ordering: T-3172 changes WHICH values the dialect contains; T-3173 changes WHETHER it is
consulted. Whichever lands second must not revert the other's fixture expectations.

### Reporter's editor evidence verified locally, 2026-08-26 — and one reversal REFUSED

001-CashWeb supplied file-level evidence for the fifth editor value after the last round
asked for it. **Their evidence is exact.** Verified here byte-for-byte:

| Claim | Verified |
|---|---|
| size 966.087 bytes | `stat -c%s` → 966087 ✓ |
| sha256 prefix `4f20b146def45626436e3b3c` | ✓ (identical at both vendored paths) |
| :1608 `AUTHORITIES = [... 'external', 'none']` | ✓ verbatim |
| :5506 `selectField('Authority', lane.authority, AUTHORITIES, …)` | ✓ — all five are one click away |
| :1906 `OWNER_FROM_AUTHORITY = {… external: ''}` | ✓ verbatim |

**The premise of our last reply was wrong, and that is the finding worth keeping.** We told
them editor 0.11.0 "is not in this repo" and asked them to prove it. It IS in this repo —
`vendor/designer/aef-workflow-designer-0.11.0.html` and the vendored copy under
`.agentic-framework/`, same size, same sha. The reference artifact §6 says the meta-key list
is machine-checked against was sitting at a known path the whole time. That removes the last
excuse for the lane dialect not being machine-checked (G-091 root enabler): this is not a
remote artifact we lack, it is a pinned file we ship.

**The reversal does NOT hold — and adopting it would have produced a false green.** They read
`external: ''` as "the editor already implements `external → no task`; your compiler is the
only one of the three that does not; adopting `external: ''` is enough." Refused on evidence:

1. The **sole consumer** of `ownerFromAuthority` is `:5790`, a **read-only property-panel
   readout** that renders "— none —" (`:5787` `OWNER_BEARING_TYPES`). The editor has no
   task-emission surface at all, so it cannot implement "no task" — there is nothing there to
   suppress. `''` is an empty *owner string in a display field*, not a suppressed task.
2. The editor's own comment at `:1902-1905` claims the mapping mirrors the standard's
   `external→no task`. The **comment** agrees with the standard; the **code** implements
   no-owner. The gap is invisible in the editor precisely because nothing downstream of it
   emits tasks — and load-bearing in our compiler, which does.
3. Mapped into our compiler, "adopt `external: ''`" means adding `external` to
   `AUTHORITY_NO_OWNER`. Per T-2567/T-2717 that class **still emits the task** and falls back
   to name/type derivation → `owner: agent`. That is today's broken behaviour with a politer
   message: it satisfies the cosmetic half of this task and silently fails the load-bearing
   AC ("nodes in an `external` lane emit NO task skeleton at all").

So the third-branch requirement already recorded in G-091 `what_remains` stands unchanged and
is now the specific thing that protects this task from the reporter's suggestion. Four
semantics are in play, not three vocabularies: no-owner-but-task (compiler `authority`),
no-owner-in-a-readout (editor `external`), no-task (the frozen standard), and unset (below).

### `none` is not a fifth authority — it is the editor's unset sentinel. Split out.

Both projects have been calling `none` "a fifth value the editor adds". It is not a value in
that sense; it is the **default/unset marker**, which changes who must fix what:

- `:8245` a newly created lane is initialised `authority: 'none'`
- `:10142` on import, a lane with **no** `aef:laneMeta authority` attribute reads back as `'none'`
- `:9894` the exporter writes `authority="${escAttr(lane.authority)}"` **unconditionally** — no
  filtering — so an untouched lane is serialised as `authority="none"`
- `.context/working/designer-rx/…-0.2.0.html:1323` already carried all five, and has no
  `OWNER_FROM_AUTHORITY` at all — `none` predates the collapse map rather than extending it

Consequence, reproduced at HEAD on a one-lane fixture (`authority="none"` + one `serviceTask`):

```
WARN: lane 'Untouched' carries unrecognized aef:laneMeta authority='none' — … this is very
likely a typo or an out-of-band value
```

**The default authoring path of the pinned editor trips our typo accusation.** `external`
requires a deliberate dropdown selection; `none` is what you get by drawing a lane and not
touching it — so the false accusation fires *more* often than the ratified-value one. Distinct
root cause (unset ≠ out-of-dialect), distinct fix (an "authority not set on this lane"
advisory, not dialect membership), so per one-bug-one-task it is **not** folded into this
task — it is split out as **T-3176 / G-095**. G-091's existing "`none` must not be folded into
this fix" instruction is upheld; what changes is that `none` now has a home rather than a
warning.

This also corrects the reporter's point 1: they read `none`'s absence from
`OWNER_FROM_AUTHORITY` as an editor defect to file upstream. The comment directly above the
map (`:1905`) says "Returns '' (no task / not derivable) for external/**none**/unknown" — the
fallthrough is deliberate and documented. A defect report framed that way will bounce.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `external` is a recognised member of the AEF lane dialect in
      `tools/bpmn_to_tasks.py` — compiling a diagram with
      `<aef:laneMeta authority="external">` no longer emits the "unrecognized …
      very likely a typo or an out-of-band value" warning
- [x] The ratified semantics are implemented, not just the message: nodes in an
      `external` lane emit NO task skeleton at all (§3 line 68, `external→no task`).
      This is a third branch — `AUTHORITY_OWNER` and `AUTHORITY_NO_OWNER` both still
      emit a task, so neither existing set is the right home for it
- [x] A genuinely out-of-dialect value (e.g. `authority="overlord"`) still produces the
      typo-suspecting warning, and the "valid set" it prints now lists all four ratified
      values — the T-2717/OBS-118 split stays intact and does not regress to one channel
- [x] `none` is explicitly NOT added — it appears in the pinned reference editor (0.11.0)
      but not in the frozen standard, so it is an editor deviation and belongs in its own
      task; folding it in here would ratify it by implementation
- [x] A regression test compiles a fixture with an `external` lane and asserts both halves:
      zero task skeletons emitted for that lane's nodes, and no "unrecognized" warning
- [x] The `external` case is covered by whatever check §6 of the standard uses for the
      frozen meta-key list, so the lane dialect can no longer drift from the standard
      silently — this is the leg that stops the next value from diverging

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

python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q 2>&1 | tail -1 | grep -qE "^62 passed"
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>&1 | grep -q "emitted NO task skeleton"
! python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>&1 | grep -qi "typo"
# the external lane's two nodes emit nothing; the control lane's one node still does
test "$(python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>/dev/null | grep -c '^id: ')" = "1"
# an out-of-dialect value is still accused -- the T-2717 two-channel split holds
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/out-of-dialect-lane-sample.bpmn 2>&1 | grep -q "very likely a typo"
# `none` was not ratified by implementation (T-3176 territory)
! grep -q '"none"' tools/bpmn_to_tasks.py

## RCA

**Symptom.** A diagram lane carrying the ratified value `authority="external"` compiled
to a task with `owner: agent` — the exact inverse of the standard's `external->no task`
— and the compiler additionally called the value "very likely a typo".

**Root cause.** `AUTHORITY_DIALECT` was built as `AUTHORITY_OWNER | AUTHORITY_NO_OWNER`,
i.e. as the union of the two sets that answer *where does owner come from*. `external`
is not an owner question at all, so it had no set to belong to and fell to the
out-of-dialect else-branch. The wording defect and the wrong-owner defect are the same
line of code.

**Why the framework did not detect it for four months.** Part I §6 names
`tests/test_mapping_standard_conformance.py` as the machine check for standard-vs-
implementation parity. **That file does not exist in this repo.** The standard asserts it
is machine-checked; nothing checks it. A three-value compiler therefore sat against a
four-value frozen standard with every test green, because every test restated the
compiler's own vocabulary back to itself. This is the session's recurring shape: a check
whose population cannot exercise the thing it claims to cover reports the same result as
one that looked and was satisfied.

Two independent parties found it before we did — 001-CashWeb hit it in the field
(their G-055) and 832, the contract owner, confirmed the diagnosis unprompted on
agent-chat-arc @535.

**Prevention, not mitigation.** `test_lane_dialect_matches_the_frozen_standard` parses
the collapse map out of §3's prose and compares it to the compiler's constants. It reads
the standard rather than restating it, so adding a fifth value to the standard turns this
test red instead of leaving the gap for a consumer to find. That is the lane-dialect half
of the check §6 promised; the frozen meta-key half is still missing and is filed
separately.

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

### 2026-08-26T15:00:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3172-bpmn-compiler-rejects-the-frozen-standar.md
- **Context:** Initial task creation

### 2026-08-26T15:51:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-921d2462
- **Timestamp:** 2026-08-26T17:55:35Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 4

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q 2>&1 | tail -1 | grep -qE "^62 passed"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>&1 | grep -q "emitted NO task skeleton"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `! python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>&1 | grep -qi "typo"`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 7
     - evidence: `python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/out-of-dialect-lane-sample.bpmn 2>&1 | grep -q "very likely a typo"`

### 2026-08-26T17:55:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
