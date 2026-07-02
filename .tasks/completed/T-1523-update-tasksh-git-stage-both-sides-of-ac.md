---
id: T-1523
name: "update-task.sh: git stage both sides of active→completed move so close commits
  don't need cleanup follow-ups"
description: >
  update-task.sh: git stage both sides of active→completed move so close commits don't
  need cleanup follow-ups

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-26T21:55:32Z
last_update: '2026-06-11T22:23:50Z'
date_finished: 2026-04-26T21:58:43Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:50Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1523: update-task.sh: git stage both sides of active→completed move so close commits don't need cleanup follow-ups

## Context

`agents/task-create/update-task.sh:391` uses `mv` to move active→completed at filesystem level. Git tracks the rename as delete + add, but neither side is staged. Close commits add only the explicit `git add` paths the caller listed; the active/* deletion lingers as a working-tree change. Every close requires a follow-up cleanup commit to stage it (e.g. T-1520/T-1521/T-1522 closes today required commit `03def51cc`).

Fix: use `git mv` when the file is tracked (auto-stages both rename sides); fall back to plain `mv` for untracked files (e.g., scratch tasks before first commit).

## Acceptance Criteria

### Agent
- [x] After `update-task.sh T-XXX --status work-completed` on a tracked task, both active deletion AND completed addition are staged (`git status` shows R rename instead of D+??)
- [x] Untracked task files still move correctly via fallback to plain `mv` (ls-files --error-unmatch gates the git path)
- [x] No spurious git output (2>/dev/null suppresses git mv chatter)

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

### 2026-04-26T21:55:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1523-update-tasksh-git-stage-both-sides-of-ac.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f5462090
- **Timestamp:** 2026-06-02T14:58:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T21:58:43Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
