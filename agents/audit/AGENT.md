# Audit Agent

> Evaluates framework compliance and identifies gaps between specification and implementation.

## Purpose

Systematically check whether the framework is being applied correctly:
- Task system compliance
- Directives adherence
- Enforcement model gaps
- Learning capture completeness

## When to Use

- Periodically (weekly recommended)
- After significant work completion
- Before declaring a milestone complete
- When suspecting compliance drift

## Audit Dimensions

### 1. Task System Compliance
- Do all active tasks have required fields?
- Are status values valid?
- Do Updates follow the specified format?
- Are commits traceable to tasks?

### 2. Directives Compliance
- D1 Antifragility: Are failures producing learnings?
- D2 Reliability: Is enforcement working? Silent failures?
- D3 Usability: Is friction low? Errors actionable?
- D4 Portability: Any vendor lock-in?

### 3. Enforcement Compliance
- What % of commits have task references?
- Were any Tier 0 actions taken without tasks?
- Are bypasses being logged?

### 4. Learning Capture
- Are practices being extracted from tasks?
- Is the origin of practices traceable?
- Are learnings queryable?

## Output Format

```
=== AUDIT REPORT ===
Timestamp: [ISO timestamp]
Scope: [what was audited]

=== FINDINGS ===

[PASS/WARN/FAIL] Category: Finding description
  - Evidence: [what was observed]
  - Spec says: [reference to spec]
  - Mitigation: [suggested fix]

=== SUMMARY ===
Pass: X
Warn: Y
Fail: Z

=== PRIORITY ACTIONS ===
1. [Most critical action]
2. [Second priority]
...
```

## Checks Performed

### Structure Checks
| Check | Severity |
|-------|----------|
| .tasks/ directory exists | FAIL |
| Subdirectories (active/completed/templates) exist | WARN |
| Task template exists | WARN |

### Task Compliance Checks
| Check | Severity |
|-------|----------|
| Required frontmatter fields present | WARN |
| Status values are valid | WARN |
| Workflow type is valid | WARN |
| Updates section exists | WARN |

### Task Quality Checks (P-001, P-004)
| Check | Severity |
|-------|----------|
| Description >= 50 characters | WARN |
| Started-work tasks have updates | WARN |
| Tasks older than 7 days have >= 2 updates | WARN |

### Git Traceability Checks
| Check | Severity |
|-------|----------|
| >= 80% commits reference tasks | PASS/WARN/FAIL |
| Working directory clean | WARN |
| Commit task refs resolve to actual tasks | WARN |

### Enforcement Checks
| Check | Severity |
|-------|----------|
| Bypass log exists (if commits lack refs) | WARN |
| Commit-msg hook installed | WARN |

### Learning Capture Checks
| Check | Severity |
|-------|----------|
| Practices documented | WARN |
| Practices have origins | WARN |
| Practice origins resolve to actual tasks | WARN |

## Enforcement Integration

The audit is integrated with git hooks for structural enforcement:

```bash
# Install all hooks including pre-push audit
./agents/git/git.sh install-hooks
```

**Pre-push hook behavior:**
- Runs full audit before allowing push
- **FAIL (exit 2):** Push blocked
- **WARN (exit 1):** Push allowed with warning
- **PASS (exit 0):** Push allowed silently
- **Bypass:** `git push --no-verify` (emergency only)

This ensures compliance is checked before code leaves the local repository.

## Integration

- **Script:** `audit.sh` performs mechanical checks
- **Git hooks:** Pre-push hook runs audit automatically
- **Claude Code:** Can invoke for intelligent analysis beyond mechanical checks
- **Output:** Structured report + exit code (0=pass, 1=warnings, 2=failures)

## Example Usage

```bash
# Full audit
./agents/audit/audit.sh

# Specific dimension
./agents/audit/audit.sh --dimension tasks
./agents/audit/audit.sh --dimension enforcement

# Output to file
./agents/audit/audit.sh > audit-report-$(date +%Y%m%d).md
```

## Limitations

This agent performs **mechanical checks only**. For intelligent analysis (e.g., "is this task description meaningful?"), invoke Claude Code with:

> "Run the audit agent and then analyze the findings for deeper issues"
