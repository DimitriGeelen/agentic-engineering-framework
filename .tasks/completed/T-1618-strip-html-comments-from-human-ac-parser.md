---
id: T-1618
name: "Strip HTML comments from Human AC parser — kill phantom ACs"
description: >
  Strip HTML comments from Human AC parser — kill phantom ACs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-30T14:42:40Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-04-30T16:42:32Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1618: Strip HTML comments from Human AC parser — kill phantom ACs

## Context

Build follow-up to T-1616 inception (GO 2026-04-30). The handover scanner at
`agents/handover/handover.sh:689` counted `^\s*-\s*\[ \]` patterns in each
`### Human` section without first stripping `<!-- ... -->` blocks. The default
task template includes an Example AC inside a comment
(`- [ ] [REVIEW] Dashboard renders correctly`), so any task that never replaced
the Human section template (canonical witness: T-1274) was pinned in
"Awaiting Your Action" forever — nothing the human could do to clear it.

The fix mirrors the same pattern used in `bin/fw verify-acs` (G-047): apply
`re.sub(r'<!--.*?-->', '', human_section, flags=re.DOTALL)` before counting.

## Acceptance Criteria

### Agent
- [x] `agents/handover/handover.sh` strips `<!-- ... -->` blocks from `human_section` before counting unchecked ACs
- [x] Regression test added: `tests/unit/handover_phantom_human_ac.bats` (6 cases — source-level invariant + behavioural pin)
- [x] All new tests pass (6/6)
- [x] `bash -n agents/handover/handover.sh` parses cleanly
- [x] Live re-scan against `.tasks/active/` confirms T-1274 (canonical phantom) no longer surfaces; the 10 tasks with real unchecked Human ACs still surface

## Verification

bash -n agents/handover/handover.sh
bats tests/unit/handover_phantom_human_ac.bats
grep -Fq "T-1618: strip" agents/handover/handover.sh

## RCA

**Symptom:** "Awaiting Your Action (Human)" handover section permanently listed
template-only tasks (T-1274 was canonical) with the example preview
"[REVIEW] Dashboard renders correctly". No human action could clear them — the
phantom was structural noise.

**Root cause:** `agents/handover/handover.sh:689` ran `re.findall(r'^\s*-\s*\[ \]')`
directly on the raw `### Human` section. The default task template's Example
block lives inside `<!-- ... -->` and ends with that exact pattern, so the
scanner always counted it as a real unchecked AC.

**Why structurally allowed:** No shared parser. `bin/fw verify-acs` (line 2106)
had already been fixed for the same bug (G-047) using the same regex strip,
but the fix never propagated to `agents/handover/handover.sh`. Two other
call-sites have the same shape (`lib/inception.sh:642`, `lib/verify-acs.sh:224`)
— see "Follow-up" below.

**Prevention:**
1. `tests/unit/handover_phantom_human_ac.bats` — 4 behavioural tests pin the
   regex behavior + 1 source-level invariant guards the strip line itself.
2. Live phantom witness (T-1274) drops from the partial-complete list on
   re-scan. Future regressions would re-introduce the noise visibly.

**Follow-up:** Two other call-sites count Human ACs without stripping comments
(`lib/inception.sh:642`, `lib/verify-acs.sh:224`). They share the same bug
class but were not in T-1616's scope. Whether they exhibit the symptom in
practice depends on workflow paths — worth a separate scan task (per "one bug =
one task"). Not filed here to keep T-1618 scope-tight.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-30T14:42:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1618-strip-html-comments-from-human-ac-parser.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2ea12332
- **Timestamp:** 2026-06-02T14:58:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T16:42:32Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
