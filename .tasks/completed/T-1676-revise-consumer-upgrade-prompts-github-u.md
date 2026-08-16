---
id: T-1676
name: "revise consumer-upgrade prompts: github upstream + shape-aware mitigation +
  structured failure envelope"
description: >
  revise consumer-upgrade prompts: github upstream + shape-aware mitigation + structured
  failure envelope

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-05-02T10:51:35Z
last_update: '2026-08-16T22:24:40Z'
date_finished: 2026-05-02T10:54:52Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=1 (body/components:prompt-incidental); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1676: revise consumer-upgrade prompts: github upstream + shape-aware mitigation + structured failure envelope

## Context

Revise `prompts/consumer-upgrade-and-test.md` and `prompts/consumer-upgrade-test-fix-report.md` so cross-fleet upgrade dispatches (a) target GitHub as the canonical upstream during the OneDev migration window, (b) detect project shape and BRANCH (not abort) into the right mitigation per shape — feeds T-1675/G-063, (c) capture structured failure metadata when upgrade crashes — feeds T-1675/T-1542 evidence loop. No source-code changes; prompt-content only.

## Acceptance Criteria

### Agent
- [x] Both prompts pin upstream to `https://github.com/DimitriGeelen/agentic-engineering-framework.git` and explicitly note OneDev migration. `grep -l "github.com/DimitriGeelen/agentic-engineering-framework" prompts/consumer-upgrade-and-test.md prompts/consumer-upgrade-test-fix-report.md` returns both files.
- [x] Both prompts contain a Step-1 shape-detection block that branches into 4 cases (`consumer-initialized`, `consumer-vendored-skewed`, `consumer-uninitialized`, `framework-repo`) with mitigation per case — no abort-on-mismatch. `grep -c "consumer-vendored-skewed\|consumer-uninitialized\|framework-repo" prompts/consumer-upgrade-and-test.md` ≥ 3.
- [x] Both prompts include a structured failure envelope schema with `project_shape`, `fw_version_before`, `configured_upstream`, `step_that_failed`, `stderr_excerpt`, `reproduction`. `grep -q "step_that_failed" prompts/consumer-upgrade-and-test.md && grep -q "step_that_failed" prompts/consumer-upgrade-test-fix-report.md`.
- [x] Both prompts include pre/post `fw version` capture and a verify-bump check.
- [x] YAML frontmatter parses on both files. `python3 -c "import yaml,sys; [yaml.safe_load(open(p).read().split('---',2)[1]) for p in ['prompts/consumer-upgrade-and-test.md','prompts/consumer-upgrade-test-fix-report.md']]"`.

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
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
grep -q "github.com/DimitriGeelen/agentic-engineering-framework" prompts/consumer-upgrade-and-test.md
grep -q "github.com/DimitriGeelen/agentic-engineering-framework" prompts/consumer-upgrade-test-fix-report.md
grep -q "step_that_failed" prompts/consumer-upgrade-and-test.md
grep -q "step_that_failed" prompts/consumer-upgrade-test-fix-report.md
grep -q "consumer-vendored-skewed" prompts/consumer-upgrade-and-test.md
grep -q "consumer-vendored-skewed" prompts/consumer-upgrade-test-fix-report.md
python3 -c "import yaml; [yaml.safe_load(open(p).read().split('---',2)[1]) for p in ['prompts/consumer-upgrade-and-test.md','prompts/consumer-upgrade-test-fix-report.md']]"

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

### 2026-05-02T10:51:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1676-revise-consumer-upgrade-prompts-github-u.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9ce3d7ba
- **Timestamp:** 2026-06-02T14:59:03Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#1 (Agent)** — Both prompts pin upstream to `https://github.com/DimitriGeelen/agentic-engineering-framework.git` and explicitly note OneDev migration. `grep -l "github.com/DimitriGeelen/agentic-engineering-framework
  - **AC-verify-mismatch** (narrow, heuristic) — `path=github.com/DimitriGeelen/agentic-engineering-framework.git in: Both prompts pin upstream to `https://github.com/DimitriGeelen/agentic-engineering-framework.git` and explicitly note OneDev migration. `grep -l "gith`
### 2026-05-02T10:54:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
