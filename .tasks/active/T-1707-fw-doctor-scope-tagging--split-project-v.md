---
id: T-1707
name: "fw doctor scope tagging — split project vs host findings (T-1702 Stream 2)"
description: >
  T-1702 deferred: every fw doctor finding gets a scope: tag (project | host). Host-scope findings include explanatory text. Closes G-065 alongside T-1702 Stream 1 (already shipped 91eeacdbb).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [arc:orchestrator-rethink]
components: []
related_tasks: [T-1702]
created: 2026-05-03T22:05:43Z
last_update: 2026-05-04T00:00:00Z
date_finished: null
---

# T-1707: fw doctor scope tagging — split project vs host findings (T-1702 Stream 2)

## Context

Stream 2 of T-1702. The original incident: an agent in a project session bundled
host-level `fw doctor` warnings (e.g. "git user identity not configured",
"bats not installed") into project housekeeping. Those findings can only be
fixed from a session at the host root (`~/.gitconfig`, system package install).
Tagging host findings makes the boundary unambiguous in the output.

**Design:**
- `project` is the default (most checks). No visual change for project findings.
- `host` findings get `[host]` prefix + explanatory suffix
  `(host-level — handle from a session at that root)`.
- Summary line breaks out host warning count if any.
- 10 host-level emits identified: mode=global, git user identity, bats/shellcheck
  not installed, orphaned MCP, global install stale symlink, duplicate hooks in
  user settings, TermLink/pi/node not installed.

Closes G-065 alongside T-1702 Pattern 4 (already shipped commit 91eeacdbb).

## Acceptance Criteria

### Agent
- [ ] `bin/fw do_doctor` defines `_doctor_warn_host` helper that emits `[host]` prefix
      + "(host-level — handle from a session at that root)" suffix, increments
      both `warnings` and `host_warnings` counters.
- [ ] All 10 identified host-scope WARN emits route through the helper:
      mode=global; git user identity; bats not installed; shellcheck not installed;
      orphaned MCP; global install stale; duplicate hooks in user settings;
      TermLink not installed; pi not installed; Node.js not found.
- [ ] Project-scope emits unchanged (no regression in normal output).
- [ ] Summary line shows host warning count when nonzero:
      `"$warnings warning(s) ($host_warnings host-level), no failures"`.
- [ ] `bash -n bin/fw` parses clean.
- [ ] `bin/fw doctor` runs without errors on this project.
- [ ] New bats unit test `tests/unit/test_doctor_scope_tags.bats` exercises at
      least 2 host-scope conditions and asserts `[host]` tag + summary breakdown.

### Human
- [ ] [REVIEW] Output reads correctly — host-level warnings unambiguous,
      project warnings still clean.
      **Steps:**
      1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw doctor 2>&1 | head -80`
      2. Look for `[host]` tags on findings that need attention from `/root` session
      3. Check summary line if host count > 0
      **Expected:** `[host]` only appears on machine-level findings (not project ones).
      **If not:** Note any miscategorized check and the right scope.

## Verification

bash -n bin/fw
bin/fw doctor 2>&1 > /dev/null
bats tests/unit/test_doctor_scope_tags.bats

## Updates

### 2026-05-03T22:05:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent

### 2026-05-04T00:00:00Z — ac-population
- Real ACs written; status started-work; horizon now.
