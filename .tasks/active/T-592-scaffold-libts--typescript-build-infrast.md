---
id: T-592
name: "Scaffold lib/ts/ — TypeScript build infrastructure for framework"
description: >
  Create the TypeScript build infrastructure decided in T-586 (GO). Set up lib/ts/src/, lib/ts/dist/, package.json (dev deps only: typescript, @types/node, esbuild), tsconfig.json (ES2022, Node16, strict), build.sh with stale-guard, fw build command, .gitattributes for dist/ linguist-generated. Add TS build health check to fw doctor. Add Node.js check (WARN) to install.sh. Add TS excludes to vendoring rsync. Add tsc --noEmit to CI workflow. Create lib/runtime.sh with fw_run_ts() fallback pattern.

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [architecture, typescript, T-586]
components: []
related_tasks: [T-586, T-593, T-594]
created: 2026-03-23T22:49:40Z
last_update: 2026-03-23T23:03:06Z
date_finished: null
---

# T-592: Scaffold lib/ts/ — TypeScript build infrastructure for framework

## Context

T-586 (Language Strategy inception) reached GO decision across all 5 phases. This task implements the foundational build infrastructure so subsequent tasks (T-593 fw-util, T-594 loop detector) can build on it.

Design source: `docs/reports/T-586-migration-path.md` (Phase 3)

## Acceptance Criteria

### Agent
- [ ] `lib/ts/src/` and `lib/ts/dist/` directories exist
- [ ] `lib/ts/package.json` with devDependencies: typescript, @types/node, esbuild (no runtime deps)
- [ ] `lib/ts/tsconfig.json` with target ES2022, module Node16, strict true
- [ ] `lib/build.sh` compiles all `.ts` in `lib/ts/src/` to `lib/ts/dist/` via esbuild with stale-guard
- [ ] `fw build` command routes to `lib/build.sh`
- [ ] `lib/runtime.sh` exports `fw_run_ts()` function (tries node, falls back to python)
- [ ] `.gitattributes` marks `lib/ts/dist/*.js` as `linguist-generated`
- [ ] `fw doctor` includes TypeScript build health check (stale detection, node presence)
- [ ] `install.sh` includes Node.js check (WARN level, not FAIL)
- [ ] Vendoring rsync excludes: `lib/ts/src`, `tsconfig.json`, `lib/ts/package.json`, `lib/ts/node_modules`
- [ ] `.github/workflows/test.yml` adds Node.js setup + `tsc --noEmit` step
- [ ] `.gitignore` includes `lib/ts/node_modules/`
- [ ] `npm install` in `lib/ts/` succeeds and `npx tsc --noEmit` returns 0 (no TS sources yet = clean)
- [ ] `fw build` is a no-op when no `.ts` sources exist (exit 0)

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
# Doctor doesn't crash
fw doctor

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
