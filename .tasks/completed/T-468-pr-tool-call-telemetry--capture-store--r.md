---
id: T-468
name: "Inception: Tool call telemetry — scope capture store + Watchtower reporting"
description: >
  Inception: Scope the tool call telemetry feature from 010-termlink. Source files exist
  (extractor, hook, stats, error analyzer) but Watchtower page, CLI routing, hook
  registration, and handover integration are new build work requiring design.

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-12T18:36:18Z
last_update: 2026-03-12T20:50:17Z
date_finished: 2026-03-12T20:50:17Z
---

# T-468: PR: Tool call telemetry — capture store + reporting from 010-termlink

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Scope assessment completed (copy vs build)
- [x] Build tasks decomposed (4 tasks)
- [x] GO decision recorded

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

## Decisions

**Decision**: GO

**Rationale**: Capture layer is copy-ready (4 files, 2 path fixes). Build decomposes into 4 tasks: copy+CLI, PreCompact hook, handover integration, Watchtower page. Total ~4-5h.

**Date**: 2026-03-12T19:30:32Z

## Updates

### 2026-03-12T18:36:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-468-pr-tool-call-telemetry--capture-store--r.md
- **Context:** Initial task creation

### 2026-03-12T18:40:53Z — status-update [task-update-agent]
- **Change:** status: started-work → issues
- **Reason:** Jumped to building without inception. Need to scope: source files exist in termlink (copy), but Watchtower page + CLI routing + hook registration + handover integration = new build work requiring inception.

### 2026-03-12T19:30:32Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Capture layer is copy-ready (4 files, 2 path fixes). Build decomposes into 4 tasks: copy+CLI, PreCompact hook, handover integration, Watchtower page. Total ~4-5h.

### 2026-03-12T20:50:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
