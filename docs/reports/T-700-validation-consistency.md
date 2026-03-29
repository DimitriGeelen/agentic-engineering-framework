# T-700: 3-Tier Validation Consistency Research

## Problem Statement

The framework uses `[PASS]/[FAIL]/[WARN]` or `OK/FAIL/WARN` output patterns inconsistently across commands. Some commands have structured result collection (audit.sh with `pass/warn/fail` functions), others inline `echo` with ad-hoc formatting, and some have no validation output at all.

**Inspiration:** KCP pattern harvest (T-697 #6) — scored 19/20 for "3-tier validation" as a consistent DX pattern.

## Current State Inventory

### Commands WITH structured validation

| Command | Pattern | Functions | Counters | Exit Codes | Notes |
|---------|---------|-----------|----------|------------|-------|
| `fw audit` | `[PASS]/[FAIL]/[WARN]` with evidence | `pass()`, `warn()`, `fail()`, `info()` | PASS_COUNT, WARN_COUNT, FAIL_COUNT | 0/1/2 | Gold standard. FINDINGS array, YAML output, history tracking |
| `fw doctor` | `OK/FAIL/WARN/SKIP` | Inline echo | issues, warnings | 0/1 | Close to structured but no functions — inline per-check |
| `fw preflight` | `OK/FAIL/WARN` | Inline echo | fail_count | 0/1 | Similar to doctor pattern |

### Commands WITH partial validation

| Command | Pattern | Notes |
|---------|---------|-------|
| `fw upgrade` | `OK/UPDATED/CREATED/SKIP/WARN` | Per-step status but no aggregate counters. Changes count but no pass/fail |
| `fw init` | `✓/⚠/SKIP` | Checkmarks, no structured pass/fail/warn |
| `fw validate-init` | `PASS/FAIL/WARN/SKIP` | Has pass/fail functions but not identical to audit |

### Commands WITHOUT validation output

| Command | Notes |
|---------|-------|
| `fw context init` | Silent success, error on failure |
| `fw fabric drift` | Has findings but custom output format |
| `fw fabric blast-radius` | Lists impacts, no pass/fail |
| `fw healing diagnose` | Custom diagnostic output |
| `fw metrics` | Statistics display, no validation |
| `fw version` | Info display only |
| `fw help` | Help text only |

## Analysis

### What "Consistent 3-Tier Validation" Would Mean

A shared library (`lib/validate.sh`) that provides:

```bash
source "$FRAMEWORK_ROOT/lib/validate.sh"

validate_init    # Reset counters
validate_pass "Check description"
validate_warn "Check description" "evidence" "mitigation"
validate_fail "Check description" "evidence" "mitigation"
validate_summary  # Print totals, set exit code
```

Every `fw` command that checks things would use these functions instead of inline `echo` with colors.

### Benefits of Consistency

1. **Machine-readable output** — consistent format enables parsing (Watchtower, CI, scripts)
2. **Aggregate reporting** — every command can report "X pass, Y warn, Z fail"
3. **Exit code contract** — 0=clean, 1=warnings, 2=failures across all commands
4. **Reduced duplication** — audit.sh has 4 functions that doctor/preflight/validate-init each reinvent
5. **Watchtower integration** — structured output can feed web UI dashboards

### Costs of Consistency

1. **Retrofit effort** — doctor has 15+ checks, preflight has 8+, upgrade has 10+ steps. Each needs conversion to function calls
2. **Not all commands are validators** — `fw version`, `fw help`, `fw metrics` display information, not validation. Forcing pass/fail on them is wrong
3. **Audit.sh's functions have audit-specific logic** — they write to FINDINGS array, track PRIORITY_ACTIONS, output YAML. A generic library would need to be either (a) simpler (losing audit features) or (b) configurable (complex)
4. **Low pain frequency** — the inconsistency is noticeable but not causing bugs. It's a DX polish issue, not a reliability issue
5. **Colors and formatting differ intentionally** — audit uses `[PASS]` with brackets, doctor uses `OK` without brackets, init uses `✓` checkmarks. Each fits its context

### The Real Question

Is the inconsistency a problem worth solving?

**Evidence for YES:**
- A new contributor reading `fw audit` output, then `fw doctor` output, then `fw upgrade` output would see 3 different formatting conventions. Confusing
- Parsing output for CI/automation requires per-command regex
- 83 instances in bin/fw alone — significant surface area

**Evidence for NO:**
- Zero user complaints about output inconsistency (T-104, T-107 onboarding)
- Each command's output format fits its use case (audit=detailed forensics, doctor=quick health check, init=setup progress)
- Audit is the only command that needs machine-readable output (for Watchtower, cron, history). Others are human-read

### Practical Middle Ground

Rather than a full library, standardize just the **exit code contract** and **aggregate summary format**:

1. **Exit codes:** All validation-type commands use 0=clean, 1=warnings, 2=failures (audit already does this, doctor close)
2. **Summary line:** Commands that check things end with a summary: `"N pass, N warn, N fail"` or `"N checks passed"` — consistent format
3. **No format change:** Let each command keep its visual style (brackets, checkmarks, colors). The summary line is the machine-readable anchor

This is ~30 lines of changes across 4 commands (doctor, preflight, upgrade, validate-init) — not a new library.

## Recommendation

**DEFER** — low priority, low pain. The KCP pattern score (19/20) reflects the pattern's theoretical value, not the urgency of implementing it in this framework.

### Rationale

1. **Zero user complaints** — onboarding cycles didn't surface this as friction
2. **Audit is the only high-frequency validator** — it runs on cron every 30 minutes. Doctor and preflight run occasionally. The ROI of standardizing occasional commands is low
3. **The practical middle ground (exit codes + summary) is cheap** — if we ever need machine-readable output from doctor/preflight, add a `--json` flag rather than restructuring text output
4. **The full library approach is over-engineered** — audit.sh's functions have audit-specific features (FINDINGS array, YAML output, history) that don't generalize cleanly

### If Revisited

The trigger would be: CI/automation needs to parse output from `fw doctor` or `fw preflight`. At that point, add `--json` flag to those commands (like `fw audit` has YAML output for cron). Don't restructure text output — add a structured output mode alongside it.
