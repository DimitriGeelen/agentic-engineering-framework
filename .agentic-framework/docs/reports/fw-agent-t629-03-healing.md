# T-629 Agent 3: Self-Healing Gap Analysis

## What the Healing Loop CAN Handle

The healing agent (`agents/healing/`) has exactly **4 commands**: diagnose, resolve, patterns, suggest.

### Capabilities
1. **Classify** task failures into 5 types: code, dependency, environment, design, external
2. **Lookup** similar patterns via semantic search (Ollama) in `patterns.yaml`
3. **Suggest** recovery actions using the Error Escalation Ladder (A/B/C/D)
4. **Record** resolutions as patterns (FP-XXX) and learnings (L-XXX)

### What It Actually Does (Mechanically)
- `diagnose T-XXX`: Reads a task file, extracts `## Updates` section, runs keyword matching to classify failure type, searches patterns.yaml for similar issues, prints generic suggestions
- `resolve T-XXX`: Appends a new FP-XXX entry to patterns.yaml, appends a new L-XXX to learnings.yaml, appends an update to the task file
- `suggest`: Scans `.tasks/active/` for `status: issues` or `status: blocked`, lists them
- `patterns`: Pretty-prints all FP-XXX entries from patterns.yaml

### Current Pattern Database
11 failure patterns recorded (FP-001 through FP-011), covering:
- Timestamp update loops, sed integer parsing, dependency conflicts
- Context exhaustion, plugin authority overrides, premature task closure
- Silent error bypass, auto-handover loops, layout bugs
- Stale focus.yaml, TermLink dispatch failures

---

## What the Healing Loop CANNOT Handle

### Fundamental Architecture Problem

**The healing loop is entirely REACTIVE and MANUAL.** It requires:
1. A human or agent to notice a problem
2. Manually set the task to `status: issues`
3. Manually run `fw healing diagnose T-XXX`
4. Manually apply the fix
5. Manually run `fw healing resolve T-XXX --mitigation "..."`

There is **zero proactive detection**, **zero auto-recovery**, and **zero self-triggering**. The healing loop is a knowledge base with a CLI, not a self-healing system.

### Session Failures the Healing Loop Should Have Caught But Didn't

#### 1. Stale Global Scripts (3x this session)

**What happened:** Global `fw` at `/root/.agentic-framework/bin/fw` was outdated. Hook commands (via `fw hook <name>`) resolved to the global binary which referenced scripts that didn't exist or had old logic. All enforcement silently failed.

**Why healing didn't catch it:**
- The healing loop has no concept of "script staleness" or "binary version mismatch"
- It only knows about task-level issues (code/dependency/environment/design/external)
- No failure pattern exists for "global binary != project binary"
- `fw doctor` checks that hook paths resolve but does NOT compare global vs local fw versions
- `fw audit` does NOT scan for stale scripts or version mismatches in PATH

#### 2. Missing Hook Scripts (boundary, cadence, loop-detect)

**What happened:** Claude Code hooks referenced scripts that didn't exist on disk. Hooks silently failed (Claude Code skips broken hooks).

**Why healing didn't catch it:**
- The healing loop doesn't monitor hook health — it's task-scoped, not infrastructure-scoped
- `fw doctor` does check for expected hooks in settings.json (check-active-task, check-tier0, check-project-boundary, budget-gate, checkpoint, error-watchdog) but only validates they're configured, not that the script files actually execute successfully
- `fw doctor` check 6 validates paths resolve but doesn't do a dry-run execution test
- `fw audit` checks for commit-msg hook installation but doesn't check Claude Code hook scripts exist/run

#### 3. Broken Commit-Cadence Hook

**What happened:** The commit-cadence hook (one of the newer hooks from T-591) was missing from consumer projects and possibly broken in the framework itself.

**Why healing didn't catch it:**
- Healing is blind to hook execution failures — no hook failure telemetry exists
- `fw doctor` doesn't list commit-cadence in its expected hooks (line 703-710 of `bin/fw`): it only checks check-active-task, check-tier0, check-project-boundary, budget-gate, checkpoint, error-watchdog. **Commit-cadence is not in the expected set.**
- `fw audit` doesn't check hook execution status

#### 4. Task Gate Blocking Memory Writes

**What happened:** `check-active-task.sh` blocked Write/Edit to `.context/working/` files (session.yaml, focus.yaml) that need to be written BEFORE a task can be set as active — creating a deadlock.

**Why healing didn't catch it:**
- This is a **circular dependency** (writing focus requires a task, but setting a task requires writing focus)
- The healing loop has no concept of deadlock detection
- Pattern database has no entry for "enforcement gate blocks its own prerequisite"
- `fw doctor` doesn't test for write-ability of exempt paths
- `fw audit` doesn't simulate the task creation flow to detect deadlocks

---

## What fw doctor Checks (Complete List)

| # | Check | Detects Session Failures? |
|---|-------|--------------------------|
| 1 | Framework installation (agents/ + FRAMEWORK.md) | No |
| 2 | .framework.yaml (consumer projects) | No |
| 3 | Task directories exist | No |
| 4 | Context directory exists | No |
| 5 | Git commit-msg + pre-push hooks | Partial (checks existence, not function) |
| 6 | Claude Code hook path validation | Partial (checks paths resolve, not execution) |
| 7 | Agent scripts executable | No |
| 8 | Plugin task-awareness | No |
| 9 | Test infrastructure (bats, shellcheck) | No |
| N | Orphaned MCP processes | No |
| N | Hook configuration structure (nested format) | Partial |
| N | Watchtower smoke test (if running) | No |
| N | TermLink installation | No |
| N | TypeScript build health | No |
| N | Enforcement baseline integrity | No |
| N | Consumer project versions | Partial (version mismatch, missing hooks) |

**Critical blind spots in fw doctor:**
- Does NOT check global `fw` vs project `fw` version consistency
- Does NOT dry-run hooks to verify they execute
- Does NOT check for circular dependencies in enforcement
- Does NOT verify exempt paths in check-active-task.sh are writable
- Does NOT check commit-cadence hook (not in expected set)
- Does NOT detect stale scripts in PATH

## What fw audit Checks (Complete List)

| Section | Checks | Detects Session Failures? |
|---------|--------|--------------------------|
| Structure | Task dirs, YAML parsing, fabric registration, fabric drift | No |
| Task Compliance | Frontmatter validation on all active tasks | No |
| Task Quality | Stale tasks, missing updates | No |
| Git Traceability | T-XXX in commits, uncommitted changes | No |
| Enforcement | Bypass log, commit-msg hook, Tier 0 violations | Partial (commit-msg only) |
| Learning Capture | Practices, origins, bugfix-learning ratio | No |
| Episodic Memory | Missing summaries, quality content, orphans | No |
| Observation Inbox | Pending observations | No |
| Concerns Register | Gap triggers | No |
| Handover Quality | Open questions | No |
| Graduation Pipeline | Learning promotion candidates | No |
| Inception Research | Research artifacts, C-001/C-002/C-003 | No |
| OE-FAST 30-min | Focus, budget, tool counter, budget JSON | Partial (budget only) |

**Critical blind spots in fw audit:**
- Does NOT check hook execution health
- Does NOT detect stale binaries or version mismatches
- Does NOT detect enforcement deadlocks
- Does NOT check for missing hook scripts on disk
- Does NOT verify that exempt paths actually work
- Does NOT check PATH resolution for `fw` binary

---

## Known Gaps in concerns.yaml

Checking all 23 concern entries against this session's failures:

| Session Failure | Known Concern? | Details |
|----------------|---------------|---------|
| Stale global scripts | **Partially: G-021, G-023** | G-021 covers hardcoded paths (resolved). G-023 covers consumer governance decay. Neither covers global binary staleness specifically. |
| Missing hook scripts | **Partially: G-023** | G-023 notes consumers missing hooks. But no gap for "hook references non-existent script" in the framework itself. |
| Broken commit-cadence | **No** | Not mentioned in any concern. |
| Task gate deadlock | **No** | No concern covers enforcement-blocks-its-own-prerequisite. |
| Command line breaks | **No** | T-628 task exists but no concern registered. |

**Verdict:** 0 of 5 session failures have a fully matching concern. 2 have partial coverage from related concerns. 3 have zero coverage.

---

## Why the Healing Loop Doesn't Handle These

### Root Cause 1: Task-Scoped, Not Infrastructure-Scoped

The healing loop operates at the **task level**: a task hits an issue, you diagnose it, you resolve it. It has no concept of:
- Hook health monitoring
- Binary version consistency
- Enforcement deadlock detection
- PATH resolution validation
- Script existence verification

These are **infrastructure-level concerns** that exist independent of any task.

### Root Cause 2: No Proactive Detection

The healing loop is **entirely pull-based**. Nothing triggers it automatically. Compare:
- `budget-gate.sh` runs on every tool call (proactive)
- `checkpoint.sh` runs on every tool call (proactive)
- `error-watchdog.sh` runs on every tool call (proactive)
- `healing.sh` runs... never, unless manually invoked (reactive)

### Root Cause 3: No Infrastructure Failure Patterns

The 11 patterns in `patterns.yaml` are all application-level:
- Timestamp loops, sed parsing, dependency conflicts
- Context exhaustion, plugin overrides, layout bugs

Zero patterns for:
- Hook execution failure
- Binary version mismatch
- Enforcement deadlock
- PATH resolution failure
- Script staleness

### Root Cause 4: Classification Is Too Narrow

The 5 failure types (code, dependency, environment, design, external) don't cover:
- **Infrastructure**: Hook health, binary freshness, script existence
- **Governance**: Deadlocks, circular enforcement, gate conflicts
- **Tooling**: PATH issues, version mismatches, stale caches

---

## Proposed Minimum Viable Self-Healing

### Tier 1: Proactive Detection (Should Auto-Detect)

These should be detected without human intervention — either as part of `fw doctor` or as a new `fw healthcheck` that runs at session start:

| What to Detect | How | Where to Add |
|----------------|-----|-------------|
| Global `fw` version != project version | Compare `fw version` output from PATH vs `bin/fw version` | `fw doctor` check or `context init` |
| Hook scripts missing on disk | For each hook command, verify the script file exists and is executable | `fw doctor` check 6 (extend) |
| Hook scripts fail to execute | Dry-run each hook with `--check` flag (no side effects) | New: `fw doctor --deep` |
| Enforcement deadlock (exempt path writability) | Attempt to write a test file to each exempt path without a task | New: `fw doctor` check |
| Commit-cadence hook missing from expected set | Add to line 703-710 expected hooks list | `fw doctor` fix (trivial) |
| Stale `fw` binary in PATH after framework update | Compare hash of global vs local `bin/fw` | `fw doctor` check |

### Tier 2: Auto-Recovery (Should Auto-Fix)

These should fix themselves without human intervention:

| What to Fix | How | Trigger |
|-------------|-----|---------|
| Missing hook scripts | Copy from framework to project (like `fw upgrade`) | `fw doctor --fix` or `context init` |
| Stale global `fw` | Offer to update symlink or copy | `fw doctor --fix` (with user approval for global writes) |
| Stale budget status blocking tools | Already implemented (stale critical still blocks — could degrade to warn) | Existing in budget-gate.sh |
| Focus.yaml pointing to completed task | Clear focus and inform agent | `context init` (partially exists) |

### Tier 3: Infrastructure Failure Patterns (Should Learn)

Add new failure types to the healing classifier:

| Type | Keywords | Typical Causes |
|------|----------|----------------|
| infrastructure | hook, binary, script, path, stale, version, missing | Missing scripts, version mismatch, PATH issues |
| governance | deadlock, circular, gate, block, enforce, exempt | Enforcement deadlocks, circular dependencies |
| tooling | cli, command, output, parse, format | CLI output issues, format problems |

### Tier 4: Continuous Hook Health Monitoring

The most impactful long-term fix: make hooks self-reporting.

1. Each hook writes a heartbeat to `.context/working/.hook-health.json` on successful execution
2. `fw doctor` checks the heartbeat file — if a hook hasn't fired in >30 minutes during an active session, it's likely broken
3. `context init` validates all hooks fire at session start (dry-run mode)

This catches the exact failure pattern from this session: hooks that exist in configuration but silently fail to execute.

---

## Summary Assessment

The healing loop is a **passive knowledge base**, not a self-healing system. It records what went wrong and suggests what to do, but it:
- Never detects problems on its own
- Never fixes anything automatically
- Never monitors infrastructure health
- Has zero coverage for the infrastructure failures that actually deadlock sessions

The gap is fundamental: the framework has **strong enforcement** (gates that block) but **no resilience** (recovery when enforcement itself fails). When enforcement breaks, there's no fallback — the framework becomes a total blocker with no self-awareness that it's broken.

### The minimum viable improvement is threefold:
1. **Extend `fw doctor`** to detect all 5 session failures (detection)
2. **Add `fw doctor --fix`** to auto-repair common issues (recovery)
3. **Add hook heartbeat monitoring** to detect silent hook failures (continuous)

None of these require changing the healing agent architecture — they're new detection and recovery mechanisms that fill the infrastructure blindness gap.
