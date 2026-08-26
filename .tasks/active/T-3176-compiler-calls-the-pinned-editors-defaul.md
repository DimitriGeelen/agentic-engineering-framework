---
id: T-3176
name: "compiler calls the pinned editors default lane state a typo - authority=none
  is an unset sentinel not an out-of-dialect value"
description: >
  Split from T-3172 / G-091 after 001-CashWeb supplied file-level evidence for the
  pinned
  editor's authority vocabulary. Both projects had been calling `none` "a fifth value
  the
  editor adds beyond the frozen standard's four". It is not a value in that sense:
  it is the
  editor's UNSET SENTINEL. vendor/designer/aef-workflow-designer-0.11.0.html (966087
  bytes,
  sha256 4f20b146def45626436e3b3c) initialises every new lane to authority:'none'
  (:8245),
  reads a lane with no aef:laneMeta authority attribute back as 'none' (:10142), and
  exports
  authority unconditionally with no filtering (:9894). So an untouched lane serialises
  as
  authority="none". tools/bpmn_to_tasks.py has no 'none' in AUTHORITY_DIALECT (:85),
  so it
  falls to the else-branch (:511-521) and reports "very likely a typo or an out-of-band
  value". Reproduced at HEAD. The DEFAULT authoring path of the editor we pin trips
  our typo
  accusation - unlike `external` (T-3172) which needs a deliberate dropdown selection,
  so this
  fires more often. Distinct root cause from T-3172: unset is not out-of-dialect,
  and the fix
  is an "authority not set on this lane" advisory, not dialect membership.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [bpmn, compiler, cross-project]
components: []
related_tasks: [T-3172, T-3173, T-2717, T-2567]
created: 2026-08-26T15:52:46Z
last_update: 2026-08-26T17:59:36Z
date_finished: 2026-08-26T17:59:36Z
cost_estimate_proposed:
  - ts: '2026-08-26T16:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=131,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-26T16:00:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3176: compiler calls the pinned editors default lane state a typo - authority=none is an unset sentinel not an out-of-dialect value

## Context

### Origin

Third inbound report from 001-CashWeb on 2026-08-26, answering our own request from the
previous round for proof of a fifth editor authority value. Their evidence was exact and is
verified byte-for-byte in T-3172. This task is the part of that evidence that turned out to be
**ours**, and that neither project had framed correctly.

### `none` is an unset sentinel, not a fifth authority

Five independent sites in the pinned bundle agree:

| Site | What it shows |
|---|---|
| `:1608` | `AUTHORITIES = ['sovereignty','authority','initiative','external','none']` — offered in the dropdown (`:5506`) |
| `:8245` | a newly created lane is initialised `authority: 'none'` |
| `:10142` | on import, a lane with **no** `aef:laneMeta authority` attribute reads back as `'none'` |
| `:9894` | the exporter writes `authority="${escAttr(lane.authority)}"` **unconditionally** — no filtering of `none` |
| `:1905` | the collapse map's own comment: "Returns `''` (no task / not derivable) for external/**none**/unknown" — the omission from `OWNER_FROM_AUTHORITY` is deliberate, not an oversight |

`.context/working/designer-rx/aef-workflow-designer-0.2.0.html:1323` already carried all five
values and has **no** `OWNER_FROM_AUTHORITY` at all — `none` predates the collapse map rather
than extending it. That is the strongest single argument that it was never intended as a peer
of the four ratified values.

So: draw a lane, do not touch the Authority dropdown, export. The diagram carries
`authority="none"`.

### What our compiler does with it — reproduced at HEAD

One-lane fixture, `<aef:laneMeta abbr="U" authority="none" height="130"/>`, one `serviceTask`:

```
WARN: lane 'Untouched' carries unrecognized aef:laneMeta authority='none' — not a value in
the AEF lane dialect (authority, initiative, sovereignty); this is very likely a typo or an
out-of-band value. … affected nodes fell back to name/type derivation: u-work-001→agent
```

rc=0, one skeleton emitted with `owner: agent`.

**The accusation is the defect.** `none` is not a typo and not out-of-band — it is the
documented default state of the editor we pin. The author who "forgot to set the authority" is
told they made a spelling mistake, and the valid-set list offered back to them
(`authority, initiative, sovereignty`) does not contain the value they would need in order to
express "unset" either.

### Why this is not T-3172, and not T-3173

Three neighbouring defects on the same code path, three different root causes — kept separate
per one-bug-one-task:

| | value | class | defect |
|---|---|---|---|
| T-3172 / G-091 | `external` | ratified by the frozen standard | wrong message **and** wrong semantics (emits `owner: agent`; standard says no task) |
| T-3173 / G-093 | `overlrd` | in no vocabulary at all | dialect check unreachable for lanes with no task nodes — even a real typo passes silently |
| **T-3176 / G-095** | `none` | editor's unset sentinel | a typo accusation levelled at the editor's default state |

Ordering against T-3172: T-3172 adds a value to the dialect **and** a third emission branch;
this task adds a fourth message class that is not dialect membership. They touch the same
`unknown_auth` reporting loop (`:501-521`) and the same `AUTHORITY_*` constants, so whichever
lands second must not revert the other's fixture expectations — same constraint already
recorded between T-3172 and T-3173.

**`none` must not be folded into T-3172's fix.** Making it a dialect member would assert it is
a ratified authority, which the frozen standard does not say and the editor's own comment
contradicts. It is a fourth reporting class, not a fifth dialect entry.

### Open question for the fix (not for this task to settle unilaterally)

Whether `owner: agent` is the right fallback for an unset lane is a **separate** judgement from
the message. It is defensible (an unset lane is not an assertion of anything, and name/type
derivation is the documented fallback), and it is not what makes the current behaviour wrong.
Scope here is the message class. If the fix author concludes the fallback is also wrong, that
is a fourth ticket, not a widening of this one.

## Acceptance Criteria

### Agent
- [x] `tools/bpmn_to_tasks.py` reports `authority="none"` with a message that does **not**
      contain "typo" and does **not** call it "out-of-band" — it names it as the lane's
      authority being unset / not yet assigned, and says what to set it to.
- [x] `none` is **not** added to `AUTHORITY_DIALECT`, `AUTHORITY_OWNER`, or
      `AUTHORITY_NO_OWNER` — the fix is a reporting class, not dialect membership. Verified by
      grepping the constants after the change.
- [x] A genuine typo (`overlrd`) still produces the existing "very likely a typo" message —
      the new class does not swallow the accusing branch it was split from.
- [x] Fixture `tests/fixtures/bpmn/none-lane-sample.bpmn` (untouched-lane shape: one lane,
      `authority="none"`, one `serviceTask`) is committed and asserted on, so the editor's
      default authoring path has a permanent regression guard.
- [x] T-3172's fixture expectations still pass after this lands (and vice-versa) — the two
      tasks share the `unknown_auth` reporting loop.

### Human
- [ ] [REVIEW] The replacement wording for an unset lane reads as a prompt to finish the
      diagram rather than as an error about the author's spelling.
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/none-lane-sample.bpmn 2>&1 | head -5`
      2. Read the WARN line as if you had just drawn your first lane in the designer.
      **Expected:** it tells you the lane has no authority set and which values are available,
      without implying you mistyped something.
      **If not:** note the phrasing that reads as an accusation and hand back for rewording.

## Verification

python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q 2>&1 | tail -1 | grep -qE "^67 passed"
# the unset sentinel is named as unset, and is not accused
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/none-lane-sample.bpmn 2>&1 | grep -q "has no authority set"
! python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/none-lane-sample.bpmn 2>&1 | grep -qiE "typo|out-of-band"
# behaviour unchanged: the node still compiles, owner still falls back
test "$(python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/none-lane-sample.bpmn 2>/dev/null | grep -c '^id: ')" = "1"
# `none` was NOT ratified into the dialect -- reporting class only
python3 -c "import sys; sys.path.insert(0,'tools'); import bpmn_to_tasks as b; assert 'none' not in b.AUTHORITY_DIALECT | b.AUTHORITY_NO_OWNER | b.AUTHORITY_OWNER.keys() | b.AUTHORITY_NO_TASK"
# the accusing branch survives the new class (T-2717 split intact)
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/out-of-dialect-lane-sample.bpmn 2>&1 | grep -q "very likely a typo"
# T-3172 still holds
python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>&1 | grep -q "emitted NO task skeleton"

## RCA

**Symptom.** Compiling a diagram straight out of the pinned reference editor accused the
author of a typo, on the editor's own default authoring path.

**Root cause.** `none` is the editor's UNSET SENTINEL — every new lane is initialised to
it, a lane with no `@authority` reads back as it, and the exporter writes it
unconditionally. The compiler had one bucket for "not a value I derive owner from" and
used the same accusing wording for a mistyped value and an unfinished one. Distinct from
T-3172: that was a *meaning* defect (wrong task emitted); this is a *reporting* defect
(right task, wrong message).

**Why it went unnoticed longer than `external` did.** Precisely because it is the default
path: it fired on essentially every first compile, so it read as background noise rather
than as a finding (L-527 — a signal that always fires stops meaning anything). `external`
needed a deliberate dropdown selection and still got reported by a consumer first.

**Prevention.** The fix is a reporting class, not dialect membership, and three
independent tests now have to be defeated to ratify `none` by accident:
`test_none_is_not_a_dialect_member`, `test_none_is_not_silently_ratified_by_this_change`,
and `test_lane_dialect_matches_the_frozen_standard` (which reads the standard's prose).
Verified by mutation: adding `none` to the dialect turns all three red.

## Recommendation

**Recommendation:** GO — close it.

**Rationale:** All five Agent ACs are met and mutation-verified. The one thing left is a
judgment I cannot make for you: whether the replacement wording reads as *finish your
diagram* rather than *you mistyped something*. That is a question about how the sentence
lands on a person who has just drawn their first lane, so it is genuinely yours — I can
tell you the word "typo" is gone (a grep proves that) but not that the tone is right.

**Evidence:**
- Old: `lane 'Untouched' carries unrecognized aef:laneMeta authority='none' — not a value
  in the AEF lane dialect (…); this is very likely a typo or an out-of-band value`
- New: `lane 'Untouched' has no authority set — aef:laneMeta authority='none' is the
  reference editor's unset sentinel, written on every lane you have not yet assigned.
  Owner could not be derived from the lane, so 1 node(s) fell back to name/type
  derivation: u-work-001→agent. Set the lane's Authority to one of: sovereignty (human
  owns), initiative (agent owns), authority (the framework executes), external (outside
  the boundary — no task authored)`
- Behaviour unchanged — reporting class only; the node still compiles, owner still falls
  back to name/type as before.
- `none` was NOT ratified into the dialect. Three independent tests must be defeated to
  do that by accident; mutation-tested, all three go red.
- A real typo (`overlord`) is still accused — the T-2717 two-channel split survives the
  third branch.
- 67 tests pass; T-3172's external-lane expectations still hold.

## Decisions

- **`none` is a reporting class, not a dialect member.** Adding it to `AUTHORITY_DIALECT`
  would assert it is a ratified authority. The frozen standard ratifies four values; the
  editor's own collapse-map comment (`:1905`) explicitly groups `none` with "not derivable".
  Alternative considered and rejected: fold into T-3172 and add both `external` and `none` to
  the dialect in one change — rejected because it conflates a ratified value with an unset
  marker and would make the compiler claim more than the standard says.
- **Split from T-3172 rather than widening it.** T-3172 is about the semantics of a ratified
  value; this is about a message class for an unset one. One bug = one task.

## Updates

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bde1e311
- **Timestamp:** 2026-08-26T18:04:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 5

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `python3 -m pytest tests/unit/test_bpmn_to_tasks.py -q 2>&1 | tail -1 | grep -qE "^67 passed"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/none-lane-sample.bpmn 2>&1 | grep -q "has no authority set"`
  3. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `! python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/none-lane-sample.bpmn 2>&1 | grep -qiE "typo|out-of-band"`
  4. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 10
     - evidence: `python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/out-of-dialect-lane-sample.bpmn 2>&1 | grep -q "very likely a typo"`
  5. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 12
     - evidence: `python3 tools/bpmn_to_tasks.py tests/fixtures/bpmn/external-lane-sample.bpmn 2>&1 | grep -q "emitted NO task skeleton"`
### 2026-08-26T17:59:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
