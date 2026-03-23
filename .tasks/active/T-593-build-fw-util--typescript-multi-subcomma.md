---
id: T-593
name: "Build fw-util — TypeScript multi-subcommand utility replacing inline Python"
description: >
  Build the fw-util TypeScript utility that replaces ~290 inline python3 -c blocks across 49 bash scripts. Subcommands: yaml-get (read YAML key), yaml-set (write YAML key), json-get (read JSON key), json-set (write JSON key), path-rel (relative path), path-resolve (absolute path), date-fmt (ISO date formatting), frontmatter-parse (YAML frontmatter extraction). Single esbuild bundle (~50KB). Called from bash as: node lib/ts/dist/fw-util.js <subcommand> <args>. Depends on T-592 (scaffold). Design source: docs/reports/T-586-migration-path.md section 2 Tier 2 + section 11.

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [architecture, typescript, T-586]
components: []
related_tasks: [T-586, T-592, T-595]
created: 2026-03-23T22:50:30Z
last_update: 2026-03-23T22:50:30Z
date_finished: null
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
- [ ] `lib/ts/src/fw-util.ts` exists with subcommand dispatch
- [ ] Subcommand `yaml-get <file> <key>` reads YAML key (supports dot-path: `a.b.c`)
- [ ] Subcommand `yaml-set <file> <key> <value>` writes YAML key
- [ ] Subcommand `json-get <file> <key>` reads JSON key (supports dot-path)
- [ ] Subcommand `json-set <file> <key> <value>` writes JSON key
- [ ] Subcommand `path-rel <from> <to>` computes relative path
- [ ] Subcommand `path-resolve <base> <path>` resolves absolute path
- [ ] Subcommand `date-fmt [--iso|--epoch|--human]` formats current time
- [ ] Subcommand `frontmatter <file>` extracts YAML frontmatter as JSON
- [ ] All subcommands read data from files/args (never shell interpolation)
- [ ] `fw build` compiles to `lib/ts/dist/fw-util.js` (single bundle, <100KB)
- [ ] `node lib/ts/dist/fw-util.js --help` lists all subcommands
- [ ] Handles missing files gracefully (exit 1 + message, no stack trace)
- [ ] Handles malformed YAML/JSON gracefully (exit 1 + message)
- [ ] Execution time <30ms per invocation (benchmarked)

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
# Frontmatter extraction (uses a real task file)
node lib/ts/dist/fw-util.js frontmatter .tasks/active/T-592-scaffold-libts--typescript-build-infrast.md
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
