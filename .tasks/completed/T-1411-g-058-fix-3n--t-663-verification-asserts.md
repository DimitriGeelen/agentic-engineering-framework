---
id: T-1411
name: "G-058 fix 3/N — T-663 verification asserts 'bin/fw ' prefix but hooks use absolute
  paths"
description: >
  G-058 fix 3/N — T-663 verification asserts 'bin/fw ' prefix but hooks use absolute
  paths

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-23T19:50:06Z
last_update: '2026-08-16T22:24:31Z'
date_finished: 2026-04-23T19:52:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:47Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=0
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1411: G-058 fix 3/N — T-663 verification asserts 'bin/fw ' prefix but hooks use absolute paths

## Context

T-663's verification asserts every hook command in `.claude/settings.json`
starts with `bin/fw `. This was correct when written but is now wrong:
hooks correctly use absolute paths like
`/opt/999-Agentic-Engineering-Framework/bin/fw hook ...` (verified in
current settings.json — 15+ hook commands, all absolute). The
`startswith("bin/fw ")` check fails, blocking T-663 from closing.

G-058 finding 4/6.

Fix: relax the assertion to "all hook commands route through bin/fw"
i.e. `'bin/fw ' in c` (works for both relative and absolute paths).
The intent of T-663's verification — "no bare `fw`" — is preserved.

## Acceptance Criteria

### Agent
- [x] T-663's python verification rewritten to accept absolute /bin/fw paths
- [x] Assertion: `all('bin/fw ' in c for c in cmds)` (preserves no-bare-fw intent)
- [x] Stale `fw_prefix="bin/fw"` literal grep relaxed to `grep -qE 'fw_prefix=.*bin/fw'` (init.sh now uses framework-aware path)
- [x] All verification commands pass against current source

## Verification

python3 -c "import json; d=json.load(open('.claude/settings.json')); cmds=[h['command'] for g in d['hooks'].values() for e in g for h in e['hooks']]; assert all('bin/fw ' in c for c in cmds), f'Found bare-fw command: {[c for c in cmds if \"bin/fw \" not in c]}'"
grep -qE 'fw_prefix=.*bin/fw' lib/init.sh

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

### 2026-04-23T19:50:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1411-g-058-fix-3n--t-663-verification-asserts.md
- **Context:** Initial task creation

### 2026-04-23T19:52:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a04466d8
- **Timestamp:** 2026-06-02T14:57:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
