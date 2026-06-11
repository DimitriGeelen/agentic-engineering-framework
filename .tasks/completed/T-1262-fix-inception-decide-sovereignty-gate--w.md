---
id: T-1262
name: "Fix inception decide sovereignty gate — Watchtower CLAUDECODE inheritance (R-033
  downstream)"
description: >
  Watchtower /inception/T-XXX/decide POST inherits CLAUDECODE=1 from parent shell.
  Cross-project bug report from 003-NTB-ATC-Plugin T-012.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [bugfix, inception, sovereignty, watchtower]
components: [lib/inception.sh, tests/unit/lib_inception.bats, 
      web/blueprints/inception.py, web/subprocess_utils.py]
related_tasks: [T-1260, T-1259, T-1223]
created: 2026-04-15T13:41:48Z
last_update: '2026-06-11T22:23:44Z'
date_finished: 2026-04-15T17:11:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:44Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1262: Fix inception decide sovereignty gate — Watchtower CLAUDECODE inheritance (R-033 downstream)

## Context

Cross-project bug report from 003-NTB-ATC-Plugin (T-012). Watchtower decide flow broken
because Flask inherits CLAUDECODE=1. RCA in T-1260. Design note: docs/reports/T-1262-inception-decide-sovereignty-bug.md

## Acceptance Criteria

### Agent
- [x] lib/inception.sh accepts --from-watchtower flag that exempts the CLAUDECODE guard (line 190 parser, line 204 condition)
- [x] web/blueprints/inception.py passes --from-watchtower when calling fw inception decide (line 412)
- [x] web/subprocess_utils.py strips CLAUDECODE from env when running fw commands (defense in depth, lines 50-51)
- [x] Decision block writer in lib/inception.sh is idempotent — detects and swallows duplicate ## Decision sections (lines 295-325)
- [x] Design note committed at docs/reports/T-1262-inception-decide-sovereignty-bug.md
- [x] Existing tests pass: 16/16 bats tests/unit/lib_inception.bats (including new T-1262 test at position 16)



## Verification

grep -q "from-watchtower" lib/inception.sh
grep -q "from.watchtower" web/blueprints/inception.py
test -f docs/reports/T-1262-inception-decide-sovereignty-bug.md

## Decisions

### 2026-04-15 — Solution approach
- **Chose:** Option 1 — --from-watchtower flag pass-through
- **Why:** Keeps the decide flow atomic. Option 2 risks stranded tasks.
- **Rejected:** Option 2 (separate CLI command) — adds friction, contradicts one-click UX

## Updates

### 2026-04-15T13:41:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1262-fix-inception-decide-sovereignty-gate--w.md
- **Context:** Initial task creation

### 2026-04-15T17:11:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** All 6 Agent ACs met. 16/16 bats pass. Design note written. Watchtower decide path restored.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f5090edc
- **Timestamp:** 2026-06-02T14:56:18Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#3 (Agent)** — web/subprocess_utils.py strips CLAUDECODE from env when running fw commands (defense in depth, lines 50-51)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/subprocess_utils.py in: web/subprocess_utils.py strips CLAUDECODE from env when running fw commands (defense in depth, lines 50-51)`
- **AC#6 (Agent)** — Existing tests pass: 16/16 bats tests/unit/lib_inception.bats (including new T-1262 test at position 16)
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/lib_inception.bats in: Existing tests pass: 16/16 bats tests/unit/lib_inception.bats (including new T-1262 test at position 16)`
