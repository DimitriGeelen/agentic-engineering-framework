---
id: T-1413
name: "G-058 fix 5/N — T-446 verification falsely flags markdown image syntax '![alt](url)' as exclamation mark"
description: >
  G-058 fix 5/N — T-446 verification falsely flags markdown image syntax '![alt](url)' as exclamation mark

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-23T19:55:09Z
last_update: 2026-04-23T19:56:47Z
date_finished: 2026-04-23T19:56:47Z
---

# T-1413: G-058 fix 5/N — T-446 verification falsely flags markdown image syntax '![alt](url)' as exclamation mark

## Context

T-446's verification block contains a "no exclamation marks in prose"
check. After stripping fenced code blocks, the check fails on `1
exclamation mark`. Investigation: the offending `!` is in
`![agentic-engeneering-framework](header.svg)` — markdown image syntax,
not prose. The intent of the check is "no exclamation marks in narrative
text", but the regex doesn't account for markdown image refs.

G-058 finding 6/6.

Fix: strip `![alt](url)` markdown image refs as well as fenced code
blocks before counting exclamation marks. Same intent, no false positive.

## Acceptance Criteria

### Agent
- [x] T-446 verification's exclamation check strips `![...]` markdown image refs
- [x] After fix, check exits 0 against current README.md (was failing on `![header](header.svg)`)
- [x] Other 6 verification commands in T-446 unchanged
- [x] Intent preserved: "no exclamation marks in prose" (still detects bare `!`)

## Verification

test -f README.md
python3 -c "lines=len(open('README.md').readlines()); assert lines <= 400"
grep -q "watchtower-tasks-board.png" README.md
grep -q "watchtower-fabric-graph.png" README.md
grep -q "watchtower-timeline.png" README.md
python3 -c "import re; t=open('README.md').read(); imgs=re.findall(r'<img[^>]+>', t); assert all('width=' in i for i in imgs)"
python3 -c "import re; t=open('README.md').read(); clean=re.sub(r'\`\`\`.*?\`\`\`','',t,flags=re.DOTALL); clean=re.sub(r'!\[[^\]]*\]\([^)]*\)','',clean); assert clean.count('!')==0"

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

### 2026-04-23T19:55:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1413-g-058-fix-5n--t-446-verification-falsely.md
- **Context:** Initial task creation

### 2026-04-23T19:56:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-209a6a2e
- **Timestamp:** 2026-06-02T14:57:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
