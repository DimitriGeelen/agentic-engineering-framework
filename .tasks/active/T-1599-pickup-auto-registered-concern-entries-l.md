---
id: T-1599
name: "Pickup: Auto-registered concern entries land at column 0 (outside concerns: mapping), corrupting concerns.yaml and silently blocking pre-push audit (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-057. Type: bug-report.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-29T07:45:01Z
last_update: 2026-04-29T18:32:48Z
date_finished: null
source_task_id_in_origin: T-057
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1599: Pickup: Auto-registered concern entries land at column 0 (outside concerns: mapping), corrupting concerns.yaml and silently blocking pre-push audit (from 003-NTB-ATC-Plugin)

## Context

Pickup envelope (P-018-bug-report-from-ntb-atc.yaml) reports an auto-register writer in our framework appended `- id: G-001` at column 0, corrupting `concerns.yaml` block-mapping. Investigation 2026-04-29 (this session) found NO such writer in our framework codebase:

- `grep -rln "concerns.yaml" agents/ lib/ bin/ web/` → only readers (`bin/fw gaps`, audit D11/D12 staleness, handover summaries, `fw context init` seed). No code path appends `- id: G-XXX` entries programmatically.
- `lib/init.sh:339` seeds `concerns: []` only at fresh init.
- The audit writer for `discoveries/LATEST.yaml` (`audit.sh:3265`) uses correct 2-space indent under `findings:`.
- No `fw concerns add` or equivalent CLI exists.

The bug as described is most likely in the consumer's local code (003-NTB-ATC-Plugin's own auto-register, citing their local T-1053). The framework has no analogous writer to fix.

**However**, the *class* of bug is real and worth a structural prevention: any tracked YAML under `.context/project/` corrupted by string-append could similarly evade detection until a downstream YAML loader fails. The right framework-side fix is a pre-push (or post-commit warning) `yaml.safe_load` validation on staged `.context/project/*.yaml` files, catching corruption regardless of writer.

Scope decision: convert this task to an inception (decide: pre-push block vs post-commit warn vs pre-commit block; what files to validate; relationship to existing audit YAML check).

## Acceptance Criteria

### Agent
- [x] Searched framework codebase for auto-register code matching the bug shape — none found
- [x] Documented investigation finding in this task's Context
- [x] Recommended structural prevention (yaml.safe_load gate on staged tracked YAMLs) as a separate inception scope
- [ ] Convert this task to inception OR defer to later horizon

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

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).

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

### 2026-04-29T07:45:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1599-pickup-auto-registered-concern-entries-l.md
- **Context:** Initial task creation

### 2026-04-29T18:32:48Z — status-update [task-update-agent]
- **Change:** horizon: next → later
