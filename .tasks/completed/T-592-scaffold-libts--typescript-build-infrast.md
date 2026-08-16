---
id: T-592
name: "Scaffold lib/ts/ — TypeScript build infrastructure for framework"
description: >
  Create the TypeScript build infrastructure decided in T-586 (GO). Set up lib/ts/src/,
  lib/ts/dist/, package.json (dev deps only: typescript, @types/node, esbuild), tsconfig.json
  (ES2022, Node16, strict), build.sh with stale-guard, fw build command, .gitattributes
  for dist/ linguist-generated. Add TS build health check to fw doctor. Add Node.js
  check (WARN) to install.sh. Add TS excludes to vendoring rsync. Add tsc --noEmit
  to CI workflow. Create lib/runtime.sh with fw_run_ts() fallback pattern.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [architecture, typescript, T-586]
components: []
related_tasks: [T-586, T-593, T-594]
created: 2026-03-23T22:49:40Z
last_update: '2026-08-16T22:25:34Z'
date_finished: 2026-03-24T06:24:33Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-592: Scaffold lib/ts/ — TypeScript build infrastructure for framework

## Context

T-586 (Language Strategy inception) reached GO decision across all 5 phases. This task implements the foundational build infrastructure so subsequent tasks (T-593 fw-util, T-594 loop detector) can build on it.

Design source: `docs/reports/T-586-migration-path.md` (Phase 3)

## Acceptance Criteria

### Agent
- [x] `lib/ts/src/` and `lib/ts/dist/` directories exist
- [x] `lib/ts/package.json` with devDependencies: typescript, @types/node, esbuild (no runtime deps)
- [x] `lib/ts/tsconfig.json` with target ES2022, module Node16, strict true
- [x] `lib/build.sh` compiles all `.ts` in `lib/ts/src/` to `lib/ts/dist/` via esbuild with stale-guard
- [x] `fw build` command routes to `lib/build.sh`
- [x] `lib/runtime.sh` exports `fw_run_ts()` function (tries node, falls back to python)
- [x] `.gitattributes` marks `lib/ts/dist/*.js` as `linguist-generated`
- [x] `fw doctor` includes TypeScript build health check (stale detection, node presence)
- [x] `install.sh` includes Node.js check (WARN level, not FAIL)
- [x] Vendoring rsync excludes: `lib/ts/src`, `tsconfig.json`, `lib/ts/package.json`, `lib/ts/node_modules`
- [x] `.github/workflows/test.yml` adds Node.js setup + `tsc --noEmit` step
- [x] `.gitignore` includes `lib/ts/node_modules/`
- [x] `npm install` in `lib/ts/` succeeds (tsc --noEmit guarded by .ts file check in CI — tsc errors on empty includes by design)
- [x] `fw build` is a no-op when no `.ts` sources exist (exit 0)

## Verification

# Directory structure
test -d lib/ts/src
test -d lib/ts/dist
# Package files parse
node -e "JSON.parse(require('fs').readFileSync('lib/ts/package.json'))"
node -e "JSON.parse(require('fs').readFileSync('lib/ts/tsconfig.json'))"
# Build script exists and is executable
test -x lib/build.sh
# Runtime helper exists
test -f lib/runtime.sh
# fw build works (no-op with no sources)
bash lib/build.sh
# Doctor TS check outputs expected message
bin/fw doctor 2>&1 | grep "TypeScript build" >/dev/null

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

### 2026-03-23T22:49:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-592-scaffold-libts--typescript-build-infrast.md
- **Context:** Initial task creation

### 2026-03-23T23:03:06Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-03-24T06:20:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T06:24:33Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e9002918
- **Timestamp:** 2026-06-02T15:03:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#11 (Agent)** — `.github/workflows/test.yml` adds Node.js setup + `tsc --noEmit` step
  - **AC-verify-mismatch** (narrow, heuristic) — `path=github/workflows/test.yml in: `.github/workflows/test.yml` adds Node.js setup + `tsc --noEmit` step`

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 14
     - evidence: `bin/fw doctor 2>&1 | grep "TypeScript build" >/dev/null`
