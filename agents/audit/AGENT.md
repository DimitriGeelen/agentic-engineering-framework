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

| Check | Source | Severity if Failed |
|-------|--------|-------------------|
| .tasks/ directory exists | File system | FAIL |
| Active tasks have required fields | Task files + 010-TaskSystem.md | WARN |
| Status values are valid | Task files | WARN |
| Commits reference tasks | Git log | WARN |
| No uncommitted changes without task | Git status | WARN |
| Practices have origin references | 015-Practices.md | WARN |
| Bypass log exists (if bypasses claimed) | .context/bypass-log.yaml | FAIL |

## Integration

- **Script:** `audit.sh` performs mechanical checks
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
