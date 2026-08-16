---
id: T-1613
name: "Pre-push YAML validation gate for .context/project/*.yaml (T-1610-build)"
description: >
  Pre-push YAML validation gate for .context/project/*.yaml (T-1610-build)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-30T07:46:30Z
last_update: '2026-08-16T22:24:38Z'
date_finished: 2026-04-30T07:49:22Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1613: Pre-push YAML validation gate for .context/project/*.yaml (T-1610-build)

## Context

T-1610 inception decided GO at 2026-04-30T07:24:58Z. Add `yaml.safe_load` block to pre-push hook so silent `.context/project/*.yaml` corruption (T-1599 shape) is caught before crossing fan-out to consumers. Research artifact: `docs/reports/T-1610-yaml-validation-gate.md`.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` pre-push HOOK_EOF block contains a YAML well-formedness gate: loops over `$PROJECT_ROOT/.context/project/*.yaml`, runs `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))"` per file, exits 1 with diagnostic message on any parse failure
- [x] Gate uses `sys.argv` not f-string interpolation (path-safety)
- [x] Gate runs BEFORE the audit invocation (faster failure feedback)
- [x] Bats coverage extended in `tests/governance/test_git_hooks.bats`: 2 new tests (block on T-1599-shape corruption, allow on well-formed YAML)
- [x] All existing tests in `tests/governance/test_git_hooks.bats` still pass (9/9 ok)
- [x] `bash -n agents/git/lib/hooks.sh` succeeds (syntax valid)

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

bash -n agents/git/lib/hooks.sh
bats tests/governance/test_git_hooks.bats

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

### 2026-04-30T07:46:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1613-pre-push-yaml-validation-gate-for-contex.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3e6447fd
- **Timestamp:** 2026-06-02T14:58:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-30T07:49:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
