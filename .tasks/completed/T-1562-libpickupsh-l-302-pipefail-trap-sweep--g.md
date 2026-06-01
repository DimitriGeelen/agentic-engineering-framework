---
id: T-1562
name: "lib/pickup.sh L-302 pipefail-trap sweep — guard 24 bare grep|head|sed|tr inlines"
description: >
  lib/pickup.sh L-302 pipefail-trap sweep — guard 24 bare grep|head|sed|tr inlines

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-27T20:31:41Z
last_update: 2026-04-27T20:33:00Z
date_finished: 2026-04-27T20:33:00Z
---

# T-1562: lib/pickup.sh L-302 pipefail-trap sweep — guard 24 bare grep|head|sed|tr inlines

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] All 24 `grep "^...:" "$file" [2>/dev/null] | head -1 | sed | tr` inlines in `lib/pickup.sh` wrapped with `{ grep ... 2>/dev/null || true; }` to neutralise the L-302 pipefail trap (matching the recipe proven in T-1557 / T-1560).
- [x] Existing pickup test suite (7 files, 64 tests) green with the guarded code. yaml_pipefail.bats (5 cases) also green — confirms the foundation invariant + the contagion fix continue to hold.
- [x] No semantic change: only adds a defensive guard around grep to prevent set-e-pipefail from killing the caller when a field is absent (the surrounding pipeline already handled empty input correctly).

### Human
<!-- All ACs are agent-verifiable. -->

## Verification

bats tests/unit/lib_pickup.bats tests/unit/lib_pickup_triple_dedup.bats tests/unit/pickup_origin_frontmatter.bats tests/unit/pickup_self_deferred.bats tests/unit/pickup_send_remote_session.bats tests/unit/pickup_type_routing.bats tests/unit/yaml_pipefail.bats

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

### 2026-04-27T20:31:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1562-libpickupsh-l-302-pipefail-trap-sweep--g.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-77040e9a
- **Timestamp:** 2026-04-27T20:33:05Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-27T20:33:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
