---
id: T-1438
name: "Add hook/hook-enable/patterns/preflight/setup to CLAUDE.md Quick Reference (close fw doctor doc drift warning)"
description: >
  Add hook/hook-enable/patterns/preflight/setup to CLAUDE.md Quick Reference (close fw doctor doc drift warning)

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-24T16:46:06Z
last_update: 2026-04-24T16:48:30Z
date_finished: 2026-04-24T16:48:30Z
---

# T-1438: Add hook/hook-enable/patterns/preflight/setup to CLAUDE.md Quick Reference (close fw doctor doc drift warning)

## Context

`fw doctor` emits `WARN Doc drift: 5 fw subcommand(s) missing from CLAUDE.md
Quick Reference` for: `hook`, `hook-enable`, `patterns`, `preflight`, `setup`.

The check (bin/fw:1507-1541, T-1421) parses `fw VERB` backtick occurrences +
the "rarely-used commands (...)" prose list, then diffs against top-level
routed subcommands from the main case/esac in `bin/fw`.

Minimal fix: extend the prose list at CLAUDE.md:824 to include these 5 verbs.
This is the same remediation pattern already used for harvest/promote/release/
self-test/validate-init/plugin-audit/upstream/enforcement/deploy/prompt/note/
scan/mcp/build/fix-learned/onboarding/self-audit/test-onboarding/traceability.

Note: `setup` is deprecated (alias for `init`) but is routed, so the drift
check still flags it. Including it closes the warning without implying
recommendation.

## Acceptance Criteria

### Agent
- [x] CLAUDE.md "rarely-used commands" paragraph includes all 5 verbs
- [x] `fw doctor` no longer emits "Doc drift: 5 fw subcommand(s) missing"
- [x] `fw doctor` emits "Quick Reference coverage" PASS line

## Verification

grep -q "rarely-used commands.*hook.*hook-enable.*patterns.*preflight.*setup" CLAUDE.md
DOC_OUT=$(bin/fw doctor 2>&1); echo "$DOC_OUT" | grep -q "Quick Reference coverage"
DOC_OUT=$(bin/fw doctor 2>&1); ! echo "$DOC_OUT" | grep -q "Doc drift:"

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

### 2026-04-24T16:46:06Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1438-add-hookhook-enablepatternspreflightsetu.md
- **Context:** Initial task creation

### 2026-04-24T16:48:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-11c59200
- **Timestamp:** 2026-06-02T14:57:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `DOC_OUT=$(bin/fw doctor 2>&1); ! echo "$DOC_OUT" | grep -q "Doc drift:"`
