---
id: T-416
name: "Create web/context_loader.py — centralized YAML and context file loading (P1+P3)"
description: >
  Create web/context_loader.py with load_learnings(), load_patterns(), load_decisions(), load_concerns(). Replaces 6+ duplicated try/except YAML blocks in discovery.py and 10+ context file loads across core.py, quality.py. shared.py load_yaml() exists but adoption is partial. Directive score: P1=8, P3=8. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: captured
workflow_type: refactor
owner: agent
horizon: now
tags: [refactoring, python, watchtower, reliability]
components: [web/context_loader.py, web/blueprints/discovery.py, web/blueprints/core.py, web/blueprints/quality.py]
related_tasks: [T-404, T-397, T-411]
created: 2026-03-10T21:03:16Z
last_update: 2026-03-10T21:03:16Z
date_finished: null
---

# T-416: Create web/context_loader.py — centralized YAML and context file loading (P1+P3)

## Context

Refactoring finding P1 (score 8) + P3 (score 8) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**P1 — Duplicated YAML loading (6+ occurrences):**
discovery.py has 6+ identical try/except YAML loading blocks despite shared.py:138-158
providing load_yaml(). See research artifact § "PYTHON BACKEND" rows P1, P3.

**P3 — Context file loading repetition (10+):**
Each context file (learnings, patterns, decisions, concerns) loaded independently with
separate path resolution and fallback logic in core.py (4 loads), discovery.py (5 loads),
quality.py (2 loads). Includes the gaps.yaml→concerns.yaml fallback (T-397 migration).

## Acceptance Criteria

### Agent
- [ ] web/context_loader.py created with load_learnings(), load_patterns(), load_decisions(), load_concerns()
- [ ] All blueprint YAML loading replaced with context_loader calls
- [ ] Fallback logic (gaps.yaml→concerns.yaml) centralized in one place
- [ ] Error handling consistent (uses shared.py load_yaml internally)
- [ ] All Watchtower pages still render correctly

### Human
- [ ] [RUBBER-STAMP] Watchtower pages load without errors
  **Steps:**
  1. Start Flask: `python3 -m web.app`
  2. Open http://localhost:3000/
  3. Click through: Dashboard, Learnings, Patterns, Decisions, Risks
  4. Check browser console for errors
  **Expected:** All pages render, no 500 errors
  **If not:** Note which page fails and check Flask logs

## Verification

test -f web/context_loader.py
python3 -c "from web.context_loader import load_learnings; print(type(load_learnings()))"
! grep -r 'yaml.safe_load' web/blueprints/discovery.py | grep -v 'import' | grep -q .
curl -sf http://localhost:3000/learnings > /dev/null || echo 'Flask not running — manual check needed'

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

### 2026-03-10T21:03:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-416-create-webcontextloaderpy--centralized-y.md
- **Context:** Initial task creation
