---
id: T-663
name: "Fix framework hooks — replace bare fw with bin/fw in settings.json"
description: >
  Phase 1 of T-662: Change the framework project's own .claude/settings.json hooks
  from bare fw (PATH-dependent, resolves to global install) to bin/fw (project-relative).
  Consumer projects already use .agentic-framework/bin/fw. This is the only project
  using bare fw. Related: T-662, T-625.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [T-662, hooks, isolation]
components: []
related_tasks: []
created: 2026-03-28T17:06:45Z
last_update: '2026-06-11T22:24:26Z'
date_finished: 2026-03-28T17:11:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:26Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-663: Fix framework hooks — replace bare fw with bin/fw in settings.json

## Context

Phase 1 of T-662 (GO). Framework's `.claude/settings.json` uses bare `fw` for all 13 hooks, resolving via PATH to `$HOME/.agentic-framework/bin/fw` (the global install). Consumer projects already use `.agentic-framework/bin/fw` (vendored relative path). This fix makes the framework project consistent with consumers. Research: `docs/reports/T-662-eliminate-global-install.md`.

## Acceptance Criteria

### Agent
- [x] All hook commands in `.claude/settings.json` use `bin/fw hook` instead of bare `fw hook`
- [x] `bin/fw hook check-active-task` responds correctly when piped test JSON
- [x] `lib/init.sh` template for framework-mode hooks uses `bin/fw` (not bare `fw`)
- [x] Vendored copy `.agentic-framework/lib/init.sh` synced

<!-- T-1462: rubber-stamp converted. The "hooks fire" outcome is already proven structurally
     by the existing verification (no bare-fw in settings.json, init.sh uses bin/fw) plus the
     fact that .context/working/.tool-counter is non-zero in any active framework session
     (PostToolUse hook increments it on every Write/Edit/Bash). Added the counter check below. -->

## Verification

# T-1411: relaxed startswith → contains. Hooks correctly use absolute
# /opt/.../bin/fw paths (no bare fw). The intent of T-663 — "no bare fw" —
# is preserved by checking that every hook routes through bin/fw, regardless
# of whether the path is relative or absolute.
python3 -c "import json; d=json.load(open('.claude/settings.json')); cmds=[h['command'] for g in d['hooks'].values() for e in g for h in e['hooks']]; assert all('bin/fw ' in c for c in cmds), f'Found bare-fw command: {[c for c in cmds if \"bin/fw \" not in c]}'"
# T-1411: init.sh now uses framework-aware path (.agentic-framework/bin/fw or $dir/bin/fw); accept any bin/fw assignment
grep -qE 'fw_prefix=.*bin/fw' lib/init.sh
# T-1462: PostToolUse hook fires structurally — counter is incremented in any live session.
test -f .context/working/.tool-counter && [ "$(cat .context/working/.tool-counter 2>/dev/null || echo 0)" -gt 0 ]

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

### 2026-03-28T17:06:45Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-663-fix-framework-hooks--replace-bare-fw-wit.md
- **Context:** Initial task creation

### 2026-03-28T17:11:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

### 2026-04-06T22:29:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a0ae140a
- **Timestamp:** 2026-06-02T15:04:12Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#4 (Agent)** — Vendored copy `.agentic-framework/lib/init.sh` synced
  - **AC-verify-mismatch** (narrow, heuristic) — `path=agentic-framework/lib/init.sh in: Vendored copy `.agentic-framework/lib/init.sh` synced`
