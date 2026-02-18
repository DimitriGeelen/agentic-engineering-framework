# T-158 Audit: Hooks, Gates, and Historical Bugs

## PART 1: HOOKS AND GATES INVENTORY

### Git Hooks (Framework Enforcement)
Installed via `agents/git/git.sh install-hooks` (VERSION=1.4)

1. **commit-msg** — Task Reference Enforcement
   - Validates: Every commit must contain T-XXX task reference
   - Exceptions: Merge commits, rebase commits
   - Inception gate: Blocks 3+ exploration commits without GO/NO-GO decision
   - Failure mode: Exit 1 blocks commit; allows --no-verify bypass (logged as warning)
   - Tests: Not explicitly tested; patterns validated by project history (97% traceability via E-004)

2. **post-commit** — Bypass Detection + Context Checkpoint
   - Detects: Commits without task reference (bypass detection)
   - Resets: .tool-counter on each commit
   - Checks: Handover staleness (warns if LATEST.md has >3 [TODO] and is >60min old)
   - Failure mode: None (advisory only)
   - Tests: None

3. **pre-push** — Audit Enforcement
   - Runs: Audit script before push
   - Blocks: Exit code 2 (audit FAIL)
   - Warns: Exit code 1 (audit WARN) — push allowed
   - Allows: Exit code 0 (audit PASS) — push allowed
   - Failure mode: Path resolution can fail if .framework.yaml missing (script handles gracefully)
   - Tests: None

### Claude Code Hooks (PreToolUse/PostToolUse)
Configured in `.claude/settings.json` (matched and executed by Claude Code)

**PreToolUse Hooks:**

1. **check-active-task.sh** — Task-First Enforcement (P-002)
   - Matcher: Write|Edit
   - Checks: Current task in focus.yaml
   - Blocks: File modifications without active task (exit 2)
   - Exempt paths: .context/, .tasks/, .claude/, .git/
   - Inception awareness: Warns if active task is inception type with no decision
   - Failure mode: None (safe defaults if FOCUS_FILE missing)
   - Tests: Not explicitly; validated by 150+ completed tasks all passing through gate
   - Known issues: Bootstrap case — if .context/working doesn't exist, allows (correct)

2. **check-tier0.sh** — Destructive Command Prevention (T-092, T-094)
   - Matcher: Bash
   - Detects: 12 Tier 0 destructive patterns via regex
   - Fast path: Keyword pre-filter (bash grep) for 95%+ safe commands
   - Detailed path: Python pattern matching only if keywords found
   - Patterns tested: 47/47 pass (per test-tier0-patterns.py)
   - Approval: One-time 5-min expiry token, logged to bypass-log.yaml
   - Failure mode: None (safe to parse errors)
   - Tests: test-tier0-patterns.py (comprehensive, with false-positive prevention for heredocs/quotes)
   - Known issues: None detected

3. **budget-gate.sh** — Context Budget Enforcement (P-009)
   - Matcher: Write|Edit|Bash
   - Reads: .budget-status cache (fast path, <100ms if fresh)
   - Fallback: Re-reads JSONL transcript every 5th call (30ms)
   - Thresholds: ok (0-100K) → warn (100K-130K) → urgent (130K-150K) → critical (150K+)
   - Critical blocks: Exit 2 for non-allowed commands
   - Allowed commands: git commit, fw handover, Read/Glob/Grep tools, fw context init
   - Failure modes: 
     - (FIXED T-149) Transcript discovery was FRAMEWORK_ROOT-scoped, now PROJECT_ROOT-scoped
     - (FIXED T-149) Stale critical status would fail-open at critical, now blocks even if stale
   - Tests: None; validated by token-aware session monitoring across 96 tasks
   - Known issues: Lag between token reading and actual usage (~10-30K tokens)

**PostToolUse Hooks:**

1. **checkpoint.sh post-tool** — Token-Aware Budget Monitor (P-009)
   - Checks: Every 5th tool call (TOKEN_CHECK_INTERVAL=5)
   - Reads: Current JSONL transcript for real token usage
   - Detects: Compaction event (prev > 100K, current < 10K)
   - Warnings: Graduated (warn/urgent/critical)
   - Auto-action: Triggers emergency handover at critical (with 10min cooldown to prevent runaway)
   - Fallback: Tool-call counter if transcript unavailable
   - Failure mode: None (advisory)
   - Tests: None; validated by preventing 14-compaction cascade (T-148 fix)
   - Known issues:
     - (FIXED T-136) Auto-handover runaway loop — was firing every call once tokens > 150K
     - (FIXED L-014) Transcript cache was session-identity-blind, now finds most-recent file

2. **error-watchdog.sh** — Bash Error Detection (L-037)
   - Matcher: Bash
   - Checks: Exit code and stderr/stdout patterns
   - Critical codes: 126 (not executable), 127 (not found), 137 (killed), 139 (segfault)
   - Pattern detection: 9 high-confidence error patterns (ERROR:, FATAL:, Traceback, etc.)
   - Output: JSON additionalContext reminding agent to investigate root cause
   - Failure mode: None (advisory)
   - Tests: None
   - Purpose: Enforce CLAUDE.md §Error Investigation Protocol (structural enforcement of L-037)

## Enforcement Scripts (Outside Hook System)

1. **pre-compact.sh** — PreCompact hook
   - Generates: Emergency handover before compaction
   - Deduplicates: Skips commit if last commit was emergency handover within 5min
   - Resets: Budget counter + status file for fresh session
   - Failure mode: None (fire-and-forget)
   - Tests: None
   - Known issues: (FIXED T-149) Used FRAMEWORK_ROOT instead of PROJECT_ROOT

2. **post-compact-resume.sh** — SessionStart hook (matcher: "compact")
   - Outputs: Structured context recovery to additionalContext
   - Sources: LATEST.md handover, focus.yaml, active tasks, git state
   - Failure mode: Partial data if files missing (safe)
   - Tests: None
   - Known issues: (FIXED T-149) Used FRAMEWORK_ROOT for all path reads

3. **test-tier0-patterns.py** — Pattern Testing
   - Coverage: 46 test cases (29 SHOULD_BLOCK, 3 BLOCK_HEREDOC, 18 SHOULD_ALLOW)
   - False-positive prevention: 3 tests verify quoted string and heredoc patterns don't trigger
   - Functionality: Validates regex patterns match destructive commands, allow safe ones
   - Exit code: 0 (pass), 1 (fail)
   - Status: All 47/47 tests pass
   - Missing: No integration tests (test in isolation, not via PreToolUse hook)

## Test Coverage Summary

| Component | Unit Tests | Integration Tests | Validation Method |
|-----------|-----------|------------------|-------------------|
| Git hooks | None | Project history (97% traceability E-004) | E-004: disable + measure |
| check-active-task.sh | None | 150+ completed tasks | All tasks forced through gate |
| check-tier0.sh | 47/47 pass | 0 | test-tier0-patterns.py only |
| budget-gate.sh | None | 96 tasks, token monitoring | Real-world session data |
| checkpoint.sh | None | 96 tasks, compaction detection | Prevented 14-cascade |
| error-watchdog.sh | None | 0 | Advisory only |
| pre-compact.sh | None | 2 uses (compactions) | Emergency handover generation |
| post-compact-resume.sh | None | 0 | SessionStart recovery |

## PART 2: HISTORICAL BUGS ANALYSIS

### Bug Summary Statistics
- **Total completed tasks**: 148 (as of 2026-02-18)
- **Total commits**: 408
- **Commits with "fix"/"bug"/"regression"**: 53
- **Bug-fix tasks (workflow_type: build)**: ~30 estimated
- **Known bugs documented in gaps.yaml**: 8 historical, 2 active

### Major Bugs Found (from patterns.yaml, learnings.yaml, gaps.yaml)

#### FP-001: Timestamp Update Loop (T-013)
- **What**: Git agent updating completed task timestamps caused endless uncommitted changes
- **Prevention**: Tests would need to check: task status before update, no re-modification of completed tasks
- **Preventable**: YES — simple status check + pre-condition testing

#### FP-002: sed Returns Malformed Integers (T-014)
- **What**: Complex sed for counting returns newlines, breaking integer comparisons
- **Prevention**: Bash-specific test: `var=$(grep -c ...) || var=0` produces correct output
- **Preventable**: YES — shell script unit testing

#### FP-003: Package Dependency Conflicts (T-026)
- **What**: yaml_validator dependency conflicts prevented installation
- **Prevention**: Test environment with pinned deps; use built-in PyYAML instead
- **Preventable**: YES — dependency resolution testing + integration tests

#### FP-004: Context Exhaustion (T-059)
- **What**: 72 tool calls consumed 200K context before warning; handover was skeleton with [TODO]
- **Prevention**: Token monitoring + graduated warnings (NOW IMPLEMENTED via budget-gate.sh)
- **Preventable**: YES — would have caught if token monitoring existed then
- **Prevention status**: FIXED via T-059 → T-138 → T-139 (budget-gate.sh)

#### FP-005: Plugin Authority Override (T-061)
- **What**: Third-party plugins claimed absolute authority, bypassed framework rules (0/20 were task-aware)
- **Prevention**: Structural enforcement PreToolUse hook (check-active-task.sh)
- **Preventable**: YES — would need integration test of plugin + framework interaction
- **Prevention status**: FIXED via T-063 (PreToolUse hook)

#### FP-006: Premature Task Closure (T-112)
- **What**: Task marked complete at 11:22, but 6 commits + 173 min of work followed; episodic snapshot froze at closure
- **Prevention**: Acceptance criteria gate (verify before marking complete) + warning on commits to closed tasks
- **Preventable**: YES — P-011 verification gate now prevents completion without AC validation
- **Prevention status**: FIXED via T-122 (verification gate)

#### FP-007: Silent Error Bypass (T-118)
- **What**: Agent encountered 3 errors in one session, silently worked around them (fw not found, sibling tool errors, format bug)
- **Prevention**: PostToolUse hook that reminds on any detected error pattern
- **Preventable**: Partially — error-watchdog.sh detects patterns, but behavioral change requires CLAUDE.md instruction
- **Prevention status**: FIXED via T-118 (CLAUDE.md error protocol) + error-watchdog.sh (advisory)

#### FP-008: Auto-Handover Runaway Loop (T-136)
- **What**: Auto-handover at critical token level fired on every subsequent tool call (once > 150K), creating 25 commits in 10min
- **Prevention**: Cooldown timer between auto-actions
- **Preventable**: YES — would need test of auto-action under persistent condition
- **Prevention status**: FIXED via T-136 (10min cooldown in checkpoint.sh)

### Critical Bugs Fixed (from gaps.yaml)

#### G-001: Enforcement Tier 0 (T-092, T-094)
- **Issue**: Tier 0 (destructive commands) was spec-only
- **Root cause**: No Bash pattern detection
- **Tests**: 47/47 patterns pass in test-tier0-patterns.py
- **Status**: CLOSED — check-tier0.sh deployed

#### G-007: Budget Gate Scope (T-149)
- **Issue**: Budget gate used FRAMEWORK_ROOT instead of PROJECT_ROOT in shared-tooling mode
- **Root cause**: Transcript discovery, pre-compact reset, post-compact resume all scoped wrong
- **Bugs fixed**: 4 independent bugs in 3 scripts
- **Tests**: None — would need multi-project test harness
- **Status**: CLOSED via T-149

### Bugs Preventable by Automated Tests

| Bug | Test Type | Coverage |
|-----|-----------|----------|
| FP-001 (timestamp loop) | Unit: task status before update | HIGH |
| FP-002 (sed malformed) | Unit: shell script integer handling | HIGH |
| FP-003 (deps) | Integration: install with pinned deps | MEDIUM |
| FP-004 (context exhaustion) | Integration: session token monitoring | MEDIUM |
| FP-005 (plugin override) | Integration: plugin + framework hook | HARD |
| FP-006 (premature closure) | Unit: acceptance criteria gate | HIGH |
| FP-007 (silent error) | Unit: error pattern detection | MEDIUM |
| FP-008 (runaway loop) | Unit: cooldown logic, timing | MEDIUM |
| G-001 (Tier 0) | Unit: pattern matching (47/47 passing) | HIGH |
| G-007 (budget scope) | Integration: PROJECT_ROOT scoping | HARD |

## RECOMMENDATIONS

1. **Immediate**: Promote test-tier0-patterns.py from standalone to CI/CD gate
2. **High priority**: Add unit tests for shell scripts (timestamp, counting, status checks)
3. **High priority**: Add integration tests for budget-gate.sh with mock JSONL transcripts
4. **Medium priority**: Add multi-project test harness for PROJECT_ROOT scoping bugs
5. **Medium priority**: Test plugin + framework interaction (simulate third-party plugin loading)
6. **Low priority**: Test auto-action cooldown logic with fake time advancement
