---
id: T-1599
name: "Pickup: Auto-registered concern entries land at column 0 (outside concerns:
  mapping), corrupting concerns.yaml and silently blocking pre-push audit (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-057. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [pickup, bug-report]
components: []
related_tasks: []
created: 2026-04-29T07:45:01Z
last_update: '2026-08-16T22:24:38Z'
date_finished: 2026-04-29T22:32:31Z
source_task_id_in_origin: T-057
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 5
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=5 (body:class-neutral); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 5
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=5 (body:class-neutral); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] Deferred to later horizon (2026-04-29) — separate inception will own the prevention work; no code change needed in this task

## Recommendation

- **Recommendation:** GO (close as investigation-only, no framework fix)
- **Rationale:** Pickup arrived from 003-NTB-ATC-Plugin describing a writer that corrupts `concerns.yaml`. Codebase search found no analog in the framework — no agent or library appends to `concerns.yaml` programmatically; only readers exist. The originating bug lives in the consumer project's local code (their T-1053). This task captured the investigation; the structural prevention work (`yaml.safe_load` gate on staged .context/project/*.yaml) is deferred to a separate inception so it isn't conflated with this pickup's resolution.
- **Evidence:**
  - `grep -rln "concerns.yaml" agents/ lib/ bin/ web/` → only readers, no writers
  - `lib/init.sh:339` seeds `concerns: []` at fresh init — no incremental append
  - No `fw concerns add` CLI exists
  - Framework's own `concerns.yaml` has consistent block-mapping indentation (verified 2026-04-29)

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

**Symptom:** Cross-project pickup envelope reported `concerns.yaml` corruption (a `- id: G-XXX` line landing at column 0 outside the `concerns:` mapping), silently breaking pre-push audit on the consumer project's side.

**Root cause:** Not in the framework codebase. Investigation 2026-04-29 found no framework code path that programmatically appends to `concerns.yaml` — only readers (`bin/fw gaps`, audit D11/D12, handover summary, `fw context init` seed). The corrupting writer lives in the consumer project (003-NTB-ATC-Plugin's local T-1053 territory), not in framework-shared tooling.

**Why structurally allowed (framework-side):** The framework has no schema-validation gate on staged `.context/project/*.yaml` files. If a writer (consumer-local OR framework-local, in any future agent) ever emits malformed YAML, nothing catches it before push — pre-push audit reads the corrupted file but doesn't currently `yaml.safe_load` it as a structural check. The bug shape would have escaped detection in the framework too if the writer had been ours.

**Prevention:** A separate inception is queued (deferred to `horizon: later`) to design the right gate: pre-push block vs post-commit warn vs pre-commit block, scope (just concerns.yaml? all .context/project/*.yaml? all tracked YAMLs?), and overlap with existing audit `D7` YAML-parse check. Not bundled here because the right shape is a decision-task, not a build-task — different sizing, different inception arc.

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

### 2026-04-29T22:32:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: later → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2fb9830e
- **Timestamp:** 2026-06-02T14:58:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-29T22:32:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
