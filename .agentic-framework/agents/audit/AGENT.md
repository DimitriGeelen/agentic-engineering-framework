# Audit Agent

> Evaluates framework compliance and identifies gaps between specification and implementation.

## Purpose

Systematically check whether the framework is being applied correctly:
- Task system compliance (structure and quality)
- Git traceability and enforcement
- Tier 0 action protection
- Learning capture completeness
- Antifragile trend detection

## When to Use

- **Automatically:** Pre-push hook runs audit before every push
- **Periodically:** Weekly recommended for trend analysis
- **After significant work:** Before declaring milestone complete
- **When suspecting drift:** Manual compliance check

## Checks Performed

### Section 1: Structure Checks
| Check | Severity |
|-------|----------|
| .tasks/ directory exists | FAIL |
| Subdirectories (active/completed/templates) exist | WARN |
| Task template exists | WARN |

### Section 2: Task Compliance Checks
| Check | Severity |
|-------|----------|
| Required frontmatter fields present | WARN |
| Status values are valid | WARN |
| Workflow type is valid | WARN |
| Updates section exists | WARN |

### Section 2B: Task Quality Checks (P-001, P-004)
| Check | Severity |
|-------|----------|
| Description >= 50 characters | WARN |
| Started-work tasks have updates | WARN |
| Tasks older than 7 days have >= 2 updates | WARN |

### Section 3: Git Traceability Checks
| Check | Severity |
|-------|----------|
| >= 80% commits reference tasks | PASS (>=80%) / WARN (50-79%) / FAIL (<50%) |
| Working directory clean | WARN |
| Commit task refs resolve to actual tasks | WARN |

### Section 4: Enforcement Checks
| Check | Severity |
|-------|----------|
| Bypass log exists (if commits lack refs) | WARN |
| Commit-msg hook installed | WARN |
| No Tier 0 violations | FAIL if violated |

**Tier 0 Patterns (from 011-EnforcementConfig.md):**
- `deploy-to-production`
- `delete-*`
- `destroy-*`
- `modify-firewall-*`
- `modify-secrets-*`
- `database-migrate`

Tier 0 actions MUST have task refs and should NEVER appear in bypass log.

### Section 5: Learning Capture Checks
| Check | Severity |
|-------|----------|
| Practices documented | WARN |
| Practices have origins | WARN |
| Practice origins resolve to actual tasks | WARN |

### Section 6: Antifragile Learning (D1)
| Feature | Description |
|---------|-------------|
| Audit persistence | Results saved to `.context/audits/YYYY-MM-DD.yaml` |
| Trend detection | Compares with previous audits |
| Practice candidates | Issues appearing 3+ times flagged for practice creation |

## Output Format

```
=== AUDIT REPORT ===
Timestamp: [ISO timestamp]
Project: [path]

=== STRUCTURE CHECKS ===
[PASS/WARN/FAIL] Check description
       Evidence: [what was observed]
       Mitigation: [suggested fix]

[... more sections ...]

=== SUMMARY ===
Pass: X
Warn: Y
Fail: Z

=== PRIORITY ACTIONS ===
1. [Most critical action]
...

=== TREND ANALYSIS ===
[Repeated issues or "First audit recorded"]

Audit saved to: .context/audits/YYYY-MM-DD.yaml

=== END AUDIT ===
```

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

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks pass |
| 1 | Warnings present (no failures) |
| 2 | Failures present |

## Example Usage

```bash
# Full audit
./agents/audit/audit.sh

# Output to file (for archival)
./agents/audit/audit.sh > audit-report-$(date +%Y%m%d).md

# Check audit history
ls .context/audits/
cat .context/audits/2026-02-13.yaml
```

## Audit History

Audit results are automatically saved to `.context/audits/YYYY-MM-DD.yaml`:

```yaml
# Audit Results - 2026-02-13
timestamp: 2026-02-13T19:45:02Z
summary:
  pass: 16
  warn: 0
  fail: 0
findings:
  - level: PASS
    check: "Tasks directory exists"
  - level: WARN
    check: "Uncommitted changes present"
    mitigation: "Commit changes with task reference or stash"
```

## Anti-Gaming Features

The audit detects common gaming attempts:

| Gaming Vector | Detection |
|--------------|-----------|
| Placeholder descriptions ("TBD") | Description < 50 chars triggers WARN |
| Stale tasks | Tasks >7 days old with <2 updates trigger WARN |
| Fake task refs | Commit refs to non-existent tasks trigger WARN |
| Practice origin fabrication | Origins to non-existent tasks trigger WARN |
| Tier 0 bypass attempts | Any Tier 0 pattern without task ref triggers FAIL |

## Limitations

This agent performs **mechanical checks**. For intelligent analysis:

> "Run the audit agent and then analyze the findings for deeper issues"

**Not yet implemented:**
- D2-D4 directive compliance checking (D1 partially via trends)
- Interactive dimension filtering (--dimension flag)
- Automatic practice generation from repeated issues

## Related

- `agents/git/git.sh` — Installs hooks, enforces task refs
- `011-EnforcementConfig.md` — Tier 0 patterns, enforcement tiers
- `015-Practices.md` — Where to add practices from audit trends
- `.context/audits/` — Audit history for trend analysis
