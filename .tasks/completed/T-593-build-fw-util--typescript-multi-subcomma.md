---
id: T-593
name: "Build fw-util — TypeScript multi-subcommand utility replacing inline Python"
description: >
  Build the fw-util TypeScript utility that replaces ~290 inline python3 -c blocks
  across 49 bash scripts. Subcommands: yaml-get (read YAML key), yaml-set (write YAML
  key), json-get (read JSON key), json-set (write JSON key), path-rel (relative path),
  path-resolve (absolute path), date-fmt (ISO date formatting), frontmatter-parse
  (YAML frontmatter extraction). Single esbuild bundle (~50KB). Called from bash as:
  node lib/ts/dist/fw-util.js <subcommand> <args>. Depends on T-592 (scaffold). Design
  source: docs/reports/T-586-migration-path.md section 2 Tier 2 + section 11.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [architecture, typescript, T-586]
components: []
related_tasks: [T-586, T-592, T-595]
created: 2026-03-23T22:50:30Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-24T06:32:37Z
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
---

# T-593: Build fw-util — TypeScript multi-subcommand utility replacing inline Python

## Context

The ~290 inline `python3 -c` blocks across 49 bash scripts are the framework's biggest fragility surface (T-586 Phase 1). This single TS binary replaces all of them with a safe stdin/argv-based interface that eliminates shell escaping vulnerabilities.

Design source: `docs/reports/T-586-migration-path.md` (section 2: Tier 2, section 5: fw-util pattern)
Evidence: `docs/reports/T-586-q4-shell-escaping.md` (84 unsafe invocations, 32 break on quotes)

Depends on: T-592 (scaffold must exist first)
Enables: T-595 (migration of highest-risk blocks)

## Acceptance Criteria

### Agent
- [x] `lib/ts/src/fw-util.ts` exists with subcommand dispatch
- [x] Subcommand `yaml-get <file> <key>` reads YAML key (supports dot-path: `a.b.c`)
- [x] Subcommand `yaml-set <file> <key> <value>` writes YAML key
- [x] Subcommand `json-get <file> <key>` reads JSON key (supports dot-path)
- [x] Subcommand `json-set <file> <key> <value>` writes JSON key
- [x] Subcommand `path-rel <from> <to>` computes relative path
- [x] Subcommand `path-resolve <base> <path>` resolves absolute path
- [x] Subcommand `date-fmt [--iso|--epoch|--human]` formats current time
- [x] Subcommand `frontmatter <file>` extracts YAML frontmatter as JSON
- [x] All subcommands read data from files/args (never shell interpolation)
- [x] `fw build` compiles to `lib/ts/dist/fw-util.js` (single bundle, 93KB)
- [x] `node lib/ts/dist/fw-util.js --help` lists all subcommands
- [x] Handles missing files gracefully (exit 1 + message, no stack trace)
- [x] Handles malformed YAML/JSON gracefully (exit 1 + message)
- [x] Execution time <30ms per invocation (benchmarked: 20-30ms)

## Verification

# Binary exists and runs
node lib/ts/dist/fw-util.js --help
# YAML operations
echo -e "name: test\nstatus: captured" > /tmp/fw-util-test.yaml
test "$(node lib/ts/dist/fw-util.js yaml-get /tmp/fw-util-test.yaml name)" = "test"
# JSON operations
echo '{"key":"value","nested":{"deep":"found"}}' > /tmp/fw-util-test.json
test "$(node lib/ts/dist/fw-util.js json-get /tmp/fw-util-test.json nested.deep)" = "found"
# Path operations
node lib/ts/dist/fw-util.js path-rel /opt/framework /opt/framework/lib/ts
# Frontmatter extraction (uses this task file)
node lib/ts/dist/fw-util.js frontmatter .tasks/active/T-593-build-fw-util--typescript-multi-subcomma.md
# Error handling: missing file exits 1
! node lib/ts/dist/fw-util.js yaml-get /nonexistent.yaml key 2>/dev/null
# Cleanup
rm -f /tmp/fw-util-test.yaml /tmp/fw-util-test.json

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

### 2026-03-23T22:50:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-593-build-fw-util--typescript-multi-subcomma.md
- **Context:** Initial task creation

### 2026-03-24T06:30:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-24T06:32:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d08e957c
- **Timestamp:** 2026-06-02T15:03:46Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** yes
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/ts/src/fw-util.ts` exists with subcommand dispatch
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/ts/src/fw-util.ts in: `lib/ts/src/fw-util.ts` exists with subcommand dispatch`

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 14
     - evidence: `! node lib/ts/dist/fw-util.js yaml-get /nonexistent.yaml key 2>/dev/null`

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `rm -f`
