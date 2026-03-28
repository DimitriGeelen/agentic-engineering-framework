# Onboarding Test Agent

> Interprets end-to-end onboarding test results — distinguishes real failures from expected day-1 noise, diagnoses partial failures, and assesses onboarding quality.

## Purpose

The deterministic script (`test-onboarding.sh`) reports PASS/WARN/FAIL per checkpoint but cannot:
- Distinguish expected warnings from real problems (e.g., audit warnings on a brand-new project)
- Diagnose *why* a checkpoint failed (only that it did)
- Assess quality of generated artifacts (CLAUDE.md completeness, hook correctness)
- Detect cascading failures (checkpoint 5 failed because checkpoint 3 silently produced wrong output)

This AGENT.md provides the interpretation criteria an AI agent needs to analyze test output meaningfully.

## When to Use

- **After `fw test-onboarding`** — Review output and provide diagnostic summary
- **After `fw init` changes** — Verify onboarding still works end-to-end
- **After `fw upgrade` changes** — Verify upgraded projects pass
- **When debugging onboarding issues** — Run with `--keep` and inspect the preserved project

## Invocation

```bash
# Run the test, preserve output for inspection
fw test-onboarding --keep 2>&1 | tee /tmp/onboarding-results.txt

# Agent interprets the results using this AGENT.md as guidance
```

## Checkpoint Interpretation Guide

### C1: Project Scaffold

**Expected state:** All 12 directories exist, CLAUDE.md + .framework.yaml + default.md created, no unsubstituted placeholders.

**Interpretation criteria:**
- Missing `.git` → test bug (test should `git init` first; `fw init` doesn't create repos)
- Missing `.tasks/` or `.context/` → `fw init` is broken — escalate immediately
- Unsubstituted `__FRAMEWORK_ROOT__` in CLAUDE.md → template generation bug in `lib/init.sh`
- Missing `.framework.yaml` → init didn't complete; check for early exit in output

**Day-1 noise (acceptable):**
- None — C1 failures are always real problems

### C2: Hook Installation

**Expected state:** settings.json with 10+ hooks (nested structure), all 3 git hooks executable.

**Interpretation criteria:**
- Hook count < 10 → `generate_claude_code_config()` in `lib/init.sh` is stale (T-313 class bug)
- Flat hook structure detected → Silent failure mode; hooks will be ignored by Claude Code
- Git hooks missing → init was run on non-git directory (check C1 for `.git`)
- Hook count = 0 → settings.json exists but hooks section is empty or malformed

**Day-1 noise (acceptable):**
- None — C2 failures indicate governance gaps

### C3: First Task

**Expected state:** `fw work-on` creates task file in `.tasks/active/`, sets focus in `.context/working/focus.yaml`.

**Interpretation criteria:**
- Task created but focus not set → `create-task.sh --start` doesn't call `context.sh focus` (O-008 class bug)
- Missing frontmatter fields → Task template is incomplete
- `fw work-on` exits non-zero but task exists → Non-fatal error in work-on flow (investigate stderr)
- No task file at all → `create-task.sh` failed or hung on stdin (O-007 class bug)

**Day-1 noise (acceptable):**
- Non-zero exit from `fw work-on` if task was still created successfully

### C4: Task Gate

**Expected state:** `check-active-task.sh` returns 0 (would allow Write/Edit), `budget-gate.sh` returns 0 (fail-open without transcript).

**Interpretation criteria:**
- Task gate blocks (exit 2) → focus.yaml missing or points to wrong task; check C3
- Budget gate blocks (exit 2) → Unexpected transcript found in test dir; should fail-open
- Task gate warns but allows → Acceptable; may indicate edge case in focus detection

**Day-1 noise (acceptable):**
- Budget gate warning about missing transcript (expected — no Claude session in test)

### C5: First Commit

**Expected state:** Commit succeeds with task reference (T-001) preserved by commit-msg hook.

**Interpretation criteria:**
- Commit fails → Git identity not configured, or commit-msg hook rejected the message
- Commit succeeds but message modified → Hook is rewriting messages (unexpected)
- `fatal: not in a git directory` → C1 didn't create `.git` (cascading from C1 failure)

**Day-1 noise (acceptable):**
- None — commits should work cleanly

### C6: Audit (Day-1 Project)

**Expected state:** `fw audit` passes or has only warnings (no failures).

**Interpretation criteria:**
- Audit FAIL on day-1 → False positive — audit expects artifacts that don't exist yet (O-009 class bug)
- Common false positives: missing handover, no episodic summaries, empty patterns.yaml
- Audit exit 2 → Real structural problem; check which specific check failed
- Audit hangs → Audit script may have stdin-blocking issue (like hook scripts)

**Day-1 noise (acceptable):**
- WARN about missing handover (no session has run yet)
- WARN about empty learnings/patterns (nothing captured yet)
- WARN about no recent commits (only test commit exists)

### C7: Self-Audit

**Expected state:** `fw self-audit` passes on the initialized project.

**Interpretation criteria:**
- FAIL on hook scripts → Framework hook scripts are missing or not executable
- FAIL on settings.json → Generated JSON is malformed (lib/init.sh bug)
- WARN about missing components → Expected — new project has no .fabric/ components
- WARN about project memory files → Expected if some files aren't seeded by init

**Day-1 noise (acceptable):**
- WARN about component fabric (not initialized on new projects)
- INFO about project memory files being created on first use

### C8: Handover

**Expected state:** Handover generates with YAML frontmatter and references the active task.

**Interpretation criteria:**
- Handover fails completely → `handover.sh` can't find required state files
- Handover succeeds but no task reference → Active task list is empty or focus lost since C3
- Missing frontmatter → Handover template is broken
- Non-zero exit but file exists → Acceptable; handover may warn about state issues

**Day-1 noise (acceptable):**
- Warnings about missing predecessor handover (first session)
- Warnings about unfilled TODO sections (expected — handover needs enrichment)

## Diagnostic Patterns

### Cascading Failures

When multiple checkpoints fail, look for the root cause:

| Root Cause | Cascade Pattern |
|-----------|----------------|
| `fw init` broken | C1 FAIL → C2-C8 all SKIP |
| No `.git` directory | C1 partial → C2 git hooks FAIL → C5 FAIL |
| `fw work-on` broken | C3 FAIL → C4-C5 SKIP, C8 no task reference |
| Hook generation bug | C2 FAIL → C4 may still pass (hooks not exercised) |

### Regression Detection

Compare current results against previous runs:
- New FAILs that were PASS → Regression in the changed component
- New WARNs that were PASS → Degradation (investigate before it becomes FAIL)
- FAIL→PASS → Fix confirmed working

## Quality Assessment

Beyond pass/fail, assess these quality signals:

1. **CLAUDE.md completeness** — Does it have all governance sections? (`--keep` + inspect)
2. **Hook count trajectory** — Should be 10; fewer means generator drift
3. **Task file quality** — Does created task have all frontmatter fields?
4. **Focus persistence** — Does focus survive across `fw work-on` → `fw git commit`?
5. **Execution time** — Should complete in <60 seconds; >120s indicates a hang or performance issue

## Output Format for Agent Reports

When summarizing test results, use this structure:

```
## Onboarding Test Report

**Result:** CLEAN / DEGRADED / BROKEN
**Checkpoints:** X/8 passed, Y warnings, Z failures
**Duration:** Ns

### Issues Found
1. [C#] Issue description — diagnosis — severity

### Day-1 Noise (Expected)
- [C#] Warning description (acceptable because...)

### Recommendation
[What to fix / investigate / accept]
```
