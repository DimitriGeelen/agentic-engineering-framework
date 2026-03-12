---
id: T-446
name: "Rewrite README: sharp positioning, evidence-first, 5-min demo, honest gradient"
description: >
  Rewrite README: sharp positioning, evidence-first, 5-min demo, honest gradient

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T00:36:10Z
last_update: 2026-03-12T00:41:32Z
date_finished: null
---

# T-446: Rewrite README: sharp positioning, evidence-first, 5-min demo, honest gradient

## Context

Inception T-445 GO. See `docs/reports/T-445-readme-overhaul.md` for research (positioning, evidence, voice guide).

## Acceptance Criteria

### Agent
- [x] README rewritten with sharp positioning in first 3 lines
- [x] "What this has actually stopped" section with real enforcement output
- [x] 5-minute demo section (5 commands → visible value)
- [x] Honest enforcement gradient (Claude Code tested, others untested)
- [x] Architecture/complexity moved into collapsibles
- [x] Voice matches author tone (no hype, no emojis, cross-domain analogies, specific evidence)
- [x] README ≤ 400 lines (316)
- [x] Screenshots reduced from 8 to 3 (dashboard, task board, dependency graph)

### Human
- [ ] [REVIEW] Positioning reads as "governance layer" not "assistant runtime"
  **Steps:**
  1. Read the first 5 lines of README.md
  2. Ask: "Would a visitor immediately understand this is NOT another OpenClaw?"
  **Expected:** Clear differentiation in first 3 seconds
  **If not:** Note which lines feel ambiguous

## Verification

# README exists and is valid markdown
test -f README.md
# Under 400 lines
python3 -c "lines=len(open('README.md').readlines()); assert lines <= 400, f'Too long: {lines}'; print(f'OK: {lines} lines')"
# 3 key screenshots present
grep -q "watchtower-dashboard.png" README.md
grep -q "watchtower-tasks-board.png" README.md
grep -q "watchtower-fabric-graph.png" README.md
# No more than 3 screenshots total
python3 -c "import re; t=open('README.md').read(); count=len(re.findall(r'!\[', t)); assert count <= 3, f'{count} screenshots'; print(f'OK: {count} screenshots')"
# No hype words
python3 -c "t=open('README.md').read().lower(); bad=[w for w in ['revolutionary','game-changing','cutting-edge','ai-powered'] if w in t]; assert not bad, f'Hype words found: {bad}'; print('OK: no hype')"
# No exclamation marks (outside code blocks)
python3 -c "import re; t=open('README.md').read(); clean=re.sub(r'```.*?```','',t,flags=re.DOTALL); count=clean.count('!'); assert count==0, f'{count} exclamation marks'; print('OK: no exclamation marks')"

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

### 2026-03-12T00:36:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-446-rewrite-readme-sharp-positioning-evidenc.md
- **Context:** Initial task creation
