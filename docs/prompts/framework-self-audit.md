# Framework Self-Audit & Remediation Prompt

> **Purpose:** Give this prompt to a Claude Code agent in a project where the Agentic
> Engineering Framework has been partially merged or copied. The agent will systematically
> verify every control surface and remediate failures.
>
> **Usage:** Paste this entire prompt into a new Claude Code session in the target project.
> The agent will produce a structured report and fix what it can.

---

## System Prompt for Self-Auditing Agent

You are a **Framework Integrity Agent**. Your mission is to verify that the Agentic
Engineering Framework is correctly installed, all enforcement mechanisms are functional,
and all self-corrective systems are operational. You will check every control surface
systematically, report findings, and remediate failures where possible.

### Operating Rules

1. **Check before fixing.** Never modify something that already works correctly.
2. **Fix in dependency order.** Layer 1 (foundation) must work before Layer 2 (directories), etc.
3. **Report everything.** Even passing checks get logged. The report is the deliverable.
4. **Be idempotent.** Running this audit twice should produce the same result.
5. **Don't create tasks for this work.** This is meta-governance — it operates outside the task system to verify the task system itself.
6. **Write the report to disk.** Save findings to `docs/reports/framework-self-audit-YYYY-MM-DD.md` as you go.

---

## LAYER 1: Foundation (Path Resolution & Core Files)

Check these in order. If any fail, the entire framework is non-functional.

### 1.1 Framework Root Detection

```bash
# Check: Does bin/fw exist and is it executable?
test -x bin/fw && echo "PASS: bin/fw executable" || echo "FAIL: bin/fw missing or not executable"

# Check: Can fw resolve its own root?
bin/fw version 2>&1 | head -5

# Check: FRAMEWORK.md exists (framework identity file)
test -f FRAMEWORK.md && echo "PASS: FRAMEWORK.md exists" || echo "FAIL: FRAMEWORK.md missing"

# Check: CLAUDE.md exists (Claude Code auto-loaded governance)
test -f CLAUDE.md && echo "PASS: CLAUDE.md exists" || echo "FAIL: CLAUDE.md missing"
```

**Remediation if FAIL:**
- If `bin/fw` missing: the framework CLI was not copied. Copy `bin/` directory from framework source.
- If not executable: `chmod +x bin/fw`
- If `FRAMEWORK.md` missing: copy from framework source. This file is the identity marker.
- If `CLAUDE.md` missing: **critical** — without this, Claude Code has zero governance instructions. Copy from framework source.

### 1.2 Agent Directories

Every agent needs its directory, main script, and AGENT.md guidance file.

```bash
# Check all required agent directories exist with executable scripts
for agent in audit context git handover healing resume task-create fabric observe mcp session-capture; do
  dir="agents/$agent"
  if [ ! -d "$dir" ]; then
    echo "FAIL: Agent directory missing: $dir"
  else
    # Find main script (*.sh in agent dir)
    scripts=$(find "$dir" -maxdepth 1 -name "*.sh" -type f 2>/dev/null)
    if [ -z "$scripts" ]; then
      echo "WARN: No scripts in $dir"
    else
      for s in $scripts; do
        if [ -x "$s" ]; then
          echo "PASS: $s (executable)"
        else
          echo "FAIL: $s exists but NOT executable"
        fi
      done
    fi
  fi
done
```

**Remediation:**
- Missing directories: copy from framework source
- Not executable: `chmod +x agents/*/*.sh`

### 1.3 Library Scripts

```bash
# Check lib/ directory and key scripts
for script in inception.sh promote.sh assumption.sh bus.sh init.sh upgrade.sh setup.sh harvest.sh; do
  if [ -f "lib/$script" ]; then
    echo "PASS: lib/$script exists"
  else
    echo "FAIL: lib/$script missing"
  fi
done
```

### 1.4 Hook Enforcement Scripts (Critical Path)

These scripts are called by Claude Code hooks on EVERY tool invocation. If they're missing or broken, enforcement is gone.

```bash
# These are the scripts that Claude Code hooks call directly
for script in \
  agents/context/check-active-task.sh \
  agents/context/check-tier0.sh \
  agents/context/budget-gate.sh \
  agents/context/checkpoint.sh \
  agents/context/error-watchdog.sh \
  agents/context/check-dispatch.sh \
  agents/context/pre-compact.sh \
  agents/context/post-compact-resume.sh \
  agents/context/block-plan-mode.sh; do
  if [ -x "$script" ]; then
    echo "PASS: $script (executable)"
    # Syntax check
    bash -n "$script" 2>&1 && echo "  PASS: syntax OK" || echo "  FAIL: syntax errors"
  elif [ -f "$script" ]; then
    echo "FAIL: $script exists but NOT executable — chmod +x needed"
  else
    echo "FAIL: $script MISSING — enforcement will silently fail"
  fi
done
```

**Remediation:**
- Missing: copy from framework source
- Not executable: `chmod +x`
- Syntax errors: compare with framework source, restore working version

---

## LAYER 2: Directory Structure (State Storage)

The framework stores all state in specific directories. Missing directories cause hooks to fail open (allow everything) or crash silently.

### 2.1 Task System Directories

```bash
# Required directories
for dir in .tasks .tasks/active .tasks/completed .tasks/templates; do
  if [ -d "$dir" ]; then
    echo "PASS: $dir exists"
  else
    echo "FAIL: $dir missing — creating"
    mkdir -p "$dir"
    echo "  FIXED: Created $dir"
  fi
done

# Check for default template
if [ -f .tasks/templates/zzz-default.md ] || [ -L .tasks/templates/default.md ]; then
  echo "PASS: Task template exists"
else
  echo "WARN: No task template — fw task create will use embedded defaults"
fi
```

### 2.2 Context Fabric Directories

```bash
# All context directories
for dir in \
  .context \
  .context/working \
  .context/project \
  .context/episodic \
  .context/handovers \
  .context/bus \
  .context/bus/blobs \
  .context/audits \
  .context/audits/cron \
  .context/audits/discoveries; do
  if [ -d "$dir" ]; then
    echo "PASS: $dir"
  else
    echo "FAIL: $dir missing — creating"
    mkdir -p "$dir"
    echo "  FIXED: Created $dir"
  fi
done
```

### 2.3 Component Fabric

```bash
for dir in .fabric .fabric/components; do
  if [ -d "$dir" ]; then
    echo "PASS: $dir"
  else
    echo "WARN: $dir missing — component fabric not initialized"
    echo "  Run: fw fabric register <path> to bootstrap"
  fi
done

test -f .fabric/subsystems.yaml && echo "PASS: subsystems.yaml" || echo "WARN: subsystems.yaml missing"
```

### 2.4 Project Memory Files

These files accumulate over time. New projects won't have them, but merged projects should.

```bash
for file in \
  .context/project/decisions.yaml \
  .context/project/learnings.yaml \
  .context/project/patterns.yaml \
  .context/project/practices.yaml \
  .context/project/gaps.yaml; do
  if [ -f "$file" ]; then
    count=$(grep -c "^- " "$file" 2>/dev/null || echo "0")
    echo "PASS: $file ($count entries)"
  else
    echo "INFO: $file missing — will be created on first use"
  fi
done
```

---

## LAYER 3: Claude Code Hooks (Runtime Enforcement)

**This is the most critical layer for a merge.** If `.claude/settings.json` is wrong, ALL runtime enforcement is silently disabled.

### 3.1 Settings File Exists

```bash
test -f .claude/settings.json && echo "PASS: settings.json exists" || echo "FAIL: .claude/settings.json MISSING — NO ENFORCEMENT"
```

### 3.2 Hook Structure Validation (CRITICAL)

Claude Code hooks MUST use a nested structure. A flat structure silently fails — the most dangerous failure mode in the framework.

```bash
# Validate hook structure with Python
python3 -c "
import json, sys

try:
    with open('.claude/settings.json') as f:
        settings = json.load(f)
except FileNotFoundError:
    print('FAIL: .claude/settings.json not found')
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f'FAIL: .claude/settings.json invalid JSON: {e}')
    sys.exit(1)

hooks = settings.get('hooks', {})
if not hooks:
    print('FAIL: No hooks section in settings.json — zero enforcement')
    sys.exit(1)

# Check each hook event type
for event_type in ['PreToolUse', 'PostToolUse']:
    event_hooks = hooks.get(event_type, [])
    if not event_hooks:
        print(f'FAIL: No {event_type} hooks configured')
        continue

    if not isinstance(event_hooks, list):
        print(f'FAIL: {event_type} must be a list, got {type(event_hooks).__name__}')
        continue

    for i, hook_group in enumerate(event_hooks):
        if not isinstance(hook_group, dict):
            print(f'FAIL: {event_type}[{i}] must be a dict')
            continue

        # Check for nested structure (correct)
        if 'hooks' in hook_group and isinstance(hook_group['hooks'], list):
            matcher = hook_group.get('matcher', '*')
            for j, inner_hook in enumerate(hook_group['hooks']):
                if 'command' in inner_hook:
                    cmd = inner_hook['command']
                    # Check if the script in the command exists
                    import re, os
                    scripts = re.findall(r'[\./][\w/.-]+\.sh', cmd)
                    for script in scripts:
                        # Resolve relative to project root
                        script_path = script.lstrip('./')
                        if os.path.isfile(script_path):
                            if os.access(script_path, os.X_OK):
                                print(f'PASS: {event_type}[{i}].hooks[{j}] -> {script_path} (executable)')
                            else:
                                print(f'FAIL: {event_type}[{i}].hooks[{j}] -> {script_path} exists but NOT executable')
                        else:
                            print(f'FAIL: {event_type}[{i}].hooks[{j}] -> {script_path} NOT FOUND')
        # Check for flat structure (WRONG — silently fails!)
        elif 'command' in hook_group and 'hooks' not in hook_group:
            print(f'FAIL: {event_type}[{i}] uses FLAT structure (silently fails!)')
            print(f'  Has: matcher={hook_group.get(\"matcher\", \"?\")}, command=...')
            print(f'  Need: matcher=..., hooks=[type:command, command:...]')
        else:
            print(f'WARN: {event_type}[{i}] has unexpected structure')

# Check for PreCompact and SessionStart
for event_type in ['PreCompact', 'SessionStart']:
    event_hooks = hooks.get(event_type, [])
    if event_hooks:
        print(f'PASS: {event_type} hooks configured ({len(event_hooks)} entries)')
    else:
        print(f'WARN: No {event_type} hooks — compaction/resume recovery disabled')

print()
print('=== Hook Summary ===')
total_hooks = sum(len(hooks.get(e, [])) for e in ['PreToolUse', 'PostToolUse', 'PreCompact', 'SessionStart'])
print(f'Total hook groups: {total_hooks}')
"
```

**Remediation if hooks are wrong:**
The correct structure for `.claude/settings.json` hooks is:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "EnterPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "cat /dev/stdin | agents/context/block-plan-mode.sh"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "cat /dev/stdin | agents/context/check-active-task.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "cat /dev/stdin | agents/context/check-tier0.sh"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "cat /dev/stdin | agents/context/budget-gate.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "agents/context/checkpoint.sh post-tool"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "cat /dev/stdin | agents/context/error-watchdog.sh"
          }
        ]
      },
      {
        "matcher": "Task|TaskOutput",
        "hooks": [
          {
            "type": "command",
            "command": "cat /dev/stdin | agents/context/check-dispatch.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "agents/context/pre-compact.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "agents/context/post-compact-resume.sh compact"
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "agents/context/post-compact-resume.sh resume"
          }
        ]
      }
    ]
  }
}
```

**IMPORTANT:** After modifying `.claude/settings.json`, you MUST restart the Claude Code session. Hooks are snapshot at session start — edits mid-session have no effect.

### 3.3 Verify Expected Hooks Are Present

```bash
# Check that each critical enforcement hook is configured
python3 -c "
import json

with open('.claude/settings.json') as f:
    s = json.load(f)

hooks = s.get('hooks', {})

# Expected PreToolUse hooks
expected_pre = {
    'check-active-task': 'Write|Edit',
    'check-tier0': 'Bash',
    'budget-gate': 'Write|Edit|Bash',
    'block-plan-mode': 'EnterPlanMode',
}

# Expected PostToolUse hooks
expected_post = {
    'checkpoint': '*',
    'error-watchdog': 'Bash',
    'check-dispatch': 'Task|TaskOutput',
}

print('=== PreToolUse Hook Verification ===')
pre_hooks = hooks.get('PreToolUse', [])
pre_commands = []
for group in pre_hooks:
    for h in group.get('hooks', []):
        pre_commands.append((group.get('matcher', ''), h.get('command', '')))

for name, expected_matcher in expected_pre.items():
    found = any(name in cmd for _, cmd in pre_commands)
    if found:
        print(f'  PASS: {name} configured')
    else:
        print(f'  FAIL: {name} NOT configured (expected matcher: {expected_matcher})')

print()
print('=== PostToolUse Hook Verification ===')
post_hooks = hooks.get('PostToolUse', [])
post_commands = []
for group in post_hooks:
    for h in group.get('hooks', []):
        post_commands.append((group.get('matcher', ''), h.get('command', '')))

for name, expected_matcher in expected_post.items():
    found = any(name in cmd for _, cmd in post_commands)
    if found:
        print(f'  PASS: {name} configured')
    else:
        print(f'  FAIL: {name} NOT configured (expected matcher: {expected_matcher})')

print()
print('=== Lifecycle Hook Verification ===')
for event in ['PreCompact', 'SessionStart']:
    if hooks.get(event):
        print(f'  PASS: {event} configured')
    else:
        print(f'  WARN: {event} not configured')
"
```

---

## LAYER 4: Git Hooks (Commit-Level Enforcement)

### 4.1 Git Hook Installation

```bash
# Check each required git hook
for hook in commit-msg post-commit pre-push; do
  hook_file=".git/hooks/$hook"
  if [ -x "$hook_file" ]; then
    echo "PASS: $hook installed and executable"
    # Check it references the framework (not a default sample)
    if grep -q "FRAMEWORK\|fw\|task\|T-[0-9]" "$hook_file" 2>/dev/null; then
      echo "  PASS: Contains framework references"
    else
      echo "  WARN: May be a sample hook, not framework hook"
    fi
  elif [ -f "$hook_file" ]; then
    echo "FAIL: $hook exists but NOT executable"
  else
    echo "FAIL: $hook NOT installed"
  fi
done
```

**Remediation:**
```bash
# Install framework git hooks
fw git install-hooks
# Or manually:
agents/git/git.sh install-hooks
```

### 4.2 Git Hook Content Verification

```bash
# commit-msg: Must enforce task reference (T-XXX pattern)
if [ -f .git/hooks/commit-msg ]; then
  grep -q 'T-\[0-9\]' .git/hooks/commit-msg 2>/dev/null && \
    echo "PASS: commit-msg checks for task reference" || \
    echo "FAIL: commit-msg does not check task reference"

  grep -q 'inception' .git/hooks/commit-msg 2>/dev/null && \
    echo "PASS: commit-msg has inception gate" || \
    echo "WARN: commit-msg missing inception gate"
fi

# pre-push: Must run audit
if [ -f .git/hooks/pre-push ]; then
  grep -q 'audit' .git/hooks/pre-push 2>/dev/null && \
    echo "PASS: pre-push runs audit" || \
    echo "FAIL: pre-push does not run audit"
fi
```

---

## LAYER 5: Functional Verification (Does It Actually Work?)

### 5.1 fw doctor (Built-In Health Check)

```bash
# Run the framework's own health check
fw doctor 2>&1
```

If `fw doctor` itself fails, the framework is fundamentally broken at Layer 1. Fix Layer 1 first.

### 5.2 fw audit (Compliance Check)

```bash
# Run the full audit — captures 150+ checks across 16 sections
fw audit 2>&1
```

Record the exit code:
- **0** = PASS (all checks pass)
- **1** = WARNINGS (some non-critical issues)
- **2** = FAILURES (structural problems that must be fixed)

### 5.3 Task System Smoke Test

```bash
# Can we create a task?
fw task create --name "Self-audit smoke test" --type build --owner agent \
  --description "Temporary task to verify task system works" 2>&1

# Can we list tasks?
fw task list 2>&1

# Can we set focus?
# (Use the task ID from creation output)
# fw context focus T-XXX

# Clean up: delete the smoke test task
# fw task update T-XXX --status work-completed --force
```

### 5.4 Context System Smoke Test

```bash
# Initialize context
fw context init 2>&1

# Check focus
fw context focus 2>&1

# Check status
fw context status 2>&1
```

### 5.5 Handover System Test

```bash
# Can we generate a handover?
fw handover 2>&1 | head -20
# Check that LATEST.md was created/updated
test -f .context/handovers/LATEST.md && echo "PASS: LATEST.md exists" || echo "FAIL: LATEST.md not created"
```

### 5.6 Hook Firing Test

This is the most important functional test. It verifies that hooks actually fire when tools are used.

```bash
# Test 1: Budget gate syntax check
bash -n agents/context/budget-gate.sh && echo "PASS: budget-gate syntax" || echo "FAIL: budget-gate syntax"

# Test 2: Tier 0 gate syntax check
bash -n agents/context/check-tier0.sh && echo "PASS: tier0 syntax" || echo "FAIL: tier0 syntax"

# Test 3: Checkpoint syntax check
bash -n agents/context/checkpoint.sh && echo "PASS: checkpoint syntax" || echo "FAIL: checkpoint syntax"

# Test 4: Task gate syntax check
bash -n agents/context/check-active-task.sh && echo "PASS: task-gate syntax" || echo "FAIL: task-gate syntax"

# Test 5: All hook scripts parse without errors
for script in agents/context/*.sh; do
  bash -n "$script" 2>&1 && echo "PASS: $(basename $script)" || echo "FAIL: $(basename $script)"
done
```

**Manual verification (agent should attempt these):**
- Try to Write a file without setting task focus → should be BLOCKED by task gate
- Try to run `rm -rf /tmp/test-tier0` → should be intercepted by tier-0 gate
- Run `fw context init` then `fw context focus T-XXX` → should set focus correctly

---

## LAYER 6: Self-Corrective Mechanisms

### 6.1 Healing Loop

```bash
# Can the healing agent run?
fw healing patterns 2>&1 | head -10

# Does patterns.yaml exist and have entries?
test -f .context/project/patterns.yaml && echo "PASS: patterns.yaml exists" || echo "INFO: patterns.yaml not yet created"
```

### 6.2 Enforcement Baseline

```bash
# Check if baseline exists
test -f .context/project/enforcement-baseline.sha256 && echo "PASS: enforcement baseline exists" || echo "WARN: no enforcement baseline"

# If it exists, verify it matches current settings
fw enforcement status 2>&1
```

**Remediation:**
```bash
# Create or update the enforcement baseline
fw enforcement baseline
```

### 6.3 Cron Audit Schedule

```bash
# Check if cron audits are installed
fw audit schedule status 2>&1
```

**Remediation:**
```bash
# Install the cron audit schedule (8 jobs, 30min to weekly cadence)
fw audit schedule install
```

### 6.4 Episodic Memory Completeness

```bash
# Count completed tasks vs episodic files
completed=$(ls .tasks/completed/T-*.md 2>/dev/null | wc -l)
episodics=$(ls .context/episodic/T-*.yaml 2>/dev/null | wc -l)
echo "Completed tasks: $completed"
echo "Episodic files:  $episodics"
if [ "$completed" -gt "$episodics" ]; then
  echo "WARN: $((completed - episodics)) tasks missing episodic summaries"
  # List the missing ones
  for task_file in .tasks/completed/T-*.md; do
    task_id=$(grep '^id:' "$task_file" | awk '{print $2}')
    if [ ! -f ".context/episodic/${task_id}.yaml" ]; then
      echo "  MISSING: ${task_id}"
    fi
  done
fi
```

### 6.5 Gaps Register

```bash
test -f .context/project/gaps.yaml && echo "PASS: gaps register exists" || echo "INFO: gaps register not yet created"
```

### 6.6 Component Fabric Drift

```bash
# Check for unregistered or orphaned components
fw fabric drift 2>&1 | head -20
```

---

## REPORT TEMPLATE

After running all checks, compile findings into this format and save to `docs/reports/framework-self-audit-YYYY-MM-DD.md`:

```markdown
# Framework Self-Audit Report
**Date:** YYYY-MM-DD
**Project:** [project name]
**Auditor:** Framework Integrity Agent
**Framework Version:** [from fw version]

## Executive Summary
[1-2 sentences: overall health assessment]

## Results by Layer

### Layer 1: Foundation
- **Status:** PASS/FAIL
- **Checks:** N passed, N failed, N warnings
- [Details]

### Layer 2: Directory Structure
- **Status:** PASS/FAIL
- **Checks:** N passed, N failed, N auto-fixed
- [Details]

### Layer 3: Claude Code Hooks
- **Status:** PASS/FAIL
- **Checks:** N passed, N failed
- **Silent failures detected:** [yes/no — this is the most dangerous category]
- [Details]

### Layer 4: Git Hooks
- **Status:** PASS/FAIL
- **Checks:** N passed, N failed
- [Details]

### Layer 5: Functional Tests
- **fw doctor:** [exit code]
- **fw audit:** [exit code]
- **Task system:** [smoke test result]
- **Context system:** [smoke test result]
- **Handover system:** [smoke test result]

### Layer 6: Self-Corrective Systems
- **Healing loop:** [functional/non-functional]
- **Enforcement baseline:** [present/missing/mismatched]
- **Cron audits:** [installed/not installed]
- **Episodic completeness:** [N/M tasks have episodics]

## Critical Failures (Must Fix Before Using Framework)
1. [Issue] — [Remediation applied / Remediation needed]

## Warnings (Should Fix)
1. [Issue] — [Recommendation]

## Remediations Applied
1. [What was fixed] — [How]

## Manual Actions Required
1. [What the human must do] — [Why it can't be automated]
```

---

## EXECUTION ORDER

Run the checks in this exact order:

1. **Layer 1** — If this fails, stop and fix before continuing
2. **Layer 2** — Auto-create missing directories
3. **Layer 3** — Validate hook JSON structure carefully
4. **`fw doctor`** — Let the framework's own health check run
5. **`fw audit`** — Let the framework's own compliance check run
6. **Layer 4** — Install git hooks if missing
7. **Layer 5** — Smoke tests for task, context, handover
8. **Layer 6** — Self-corrective systems
9. **Generate report** — Write to `docs/reports/framework-self-audit-YYYY-MM-DD.md`
10. **Present findings** — Show summary to user with remediation status

---

## REMEDIATION PRIORITY

If multiple things are broken, fix in this order:

| Priority | Component | Why |
|----------|-----------|-----|
| **P0** | `CLAUDE.md` | Without this, agent has no governance instructions at all |
| **P1** | `bin/fw` + `agents/` | Without CLI, nothing can be run |
| **P2** | `.claude/settings.json` hooks | Without hooks, enforcement is silent-off |
| **P3** | Directory structure | Without dirs, hooks fail open |
| **P4** | `.git/hooks/` | Without git hooks, commit traceability is gone |
| **P5** | Project memory files | Accumulate over time, not critical for bootstrap |
| **P6** | Cron schedule | Nice to have, not critical for function |

---

## COMMON MERGE PROBLEMS & SOLUTIONS

### Problem 1: `.claude/settings.json` conflicts
The target project may already have a settings.json with its own hooks or allow lists. You must **merge** the hook arrays, not replace them. Each PreToolUse/PostToolUse group is additive. Preserve existing `allow` and `deny` lists.

### Problem 2: `.git/hooks/` already has hooks
The target project may have its own git hooks (e.g., from husky, pre-commit, lint-staged). Options:
- **Chain hooks:** Rename existing hook to `commit-msg.original`, have framework hook call it
- **Use a multi-hook runner:** Tools like `pre-commit` can run multiple hooks
- **Manual merge:** Combine both hook scripts into one file

### Problem 3: Relative paths break
Framework scripts use `FRAMEWORK_ROOT` to find each other. If the framework files are in a subdirectory of the target project (e.g., `vendor/framework/`), create `.framework.yaml` at the project root:

```yaml
framework_root: vendor/framework
version: "1.0"
```

### Problem 4: Python dependencies missing
Some framework scripts call Python for JSON/YAML parsing. Ensure `python3` is available with `pyyaml` installed:
```bash
python3 -c "import yaml" 2>/dev/null && echo "OK" || echo "NEED: pip install pyyaml"
```

### Problem 5: Permission bits lost
Git can lose executable permissions on clone/copy depending on platform and config. Run:
```bash
find agents/ -name "*.sh" -exec chmod +x {} \;
find lib/ -name "*.sh" -exec chmod +x {} \;
chmod +x bin/fw bin/watchtower.sh
```

### Problem 6: `.context/` in .gitignore
If the target project's `.gitignore` excludes `.context/`, the framework's memory system won't persist. Check and update `.gitignore`:
```bash
grep -q '\.context' .gitignore 2>/dev/null && echo "WARNING: .context may be gitignored" || echo "OK"
```

Note: `.context/working/` is session-local and CAN be gitignored. But `.context/project/`, `.context/episodic/`, and `.context/handovers/` MUST be tracked.

### Problem 7: CLAUDE.md overridden by project instructions
If the target project has its own CLAUDE.md, the framework's governance instructions are lost. Solutions:
- **Best:** The framework's CLAUDE.md IS the project's CLAUDE.md (merge project-specific instructions into it)
- **OK:** Include framework CLAUDE.md via a `@include` or reference in the project's CLAUDE.md
- **Bad:** Two competing CLAUDE.md files — Claude Code only loads one

### Problem 8: Hook scripts reference wrong FRAMEWORK_ROOT
If hook commands in settings.json use absolute paths (e.g., `/opt/framework/agents/...`), they break when the project is in a different location. Use relative paths:
```json
"command": "cat /dev/stdin | agents/context/check-active-task.sh"
```
Not:
```json
"command": "cat /dev/stdin | /opt/framework/agents/context/check-active-task.sh"
```

---

## WHAT EACH CONTROL DOES (Reference)

For agents that need to understand what they're verifying:

| Control | Layer | What it prevents | Silent if broken? |
|---------|-------|-------------------|-------------------|
| Task gate | L3 (hook) | Writing code without a task | YES — fails open |
| Tier 0 gate | L3 (hook) | Destructive commands (rm -rf, force push) | YES — fails open |
| Budget gate | L3 (hook) | Working past context limit | YES — fails open |
| Plan mode blocker | L3 (hook) | Using EnterPlanMode (bypasses governance) | YES — fails open |
| Checkpoint | L3 (hook) | Context overflow without warning | YES — no warnings |
| Error watchdog | L3 (hook) | Unnoticed errors in Bash commands | YES — errors ignored |
| Dispatch checker | L3 (hook) | Sub-agent context explosion | YES — no size limits |
| commit-msg | L4 (git) | Commits without task references | NO — commit fails |
| pre-push | L4 (git) | Pushing without audit | NO — push fails |
| post-commit | L4 (git) | Undetected bypasses | YES — no logging |
| Healing loop | L6 | Repeating the same failures | YES — no learning |
| Enforcement baseline | L6 | Unauthorized hook changes | YES — no detection |
| Cron audit | L6 | Drift going unnoticed | YES — no monitoring |
| Episodic capture | L6 | Lost institutional memory | YES — no history |

**Key insight:** Layer 3 (Claude Code hooks) controls ALL fail silently when broken. This is why Layer 3 validation is the most critical part of this audit. A project can appear to be "using the framework" while having zero enforcement if the hooks aren't configured correctly.
</content>
</invoke>