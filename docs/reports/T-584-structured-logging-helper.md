# T-584: Structured Logging Helper — Research Artifact

## Problem Statement

**For whom:** Framework developers debugging hook failures, audit issues, and agent behavior.
**Why now:** 339 `echo ... >&2` calls across framework scripts produce undifferentiated text. No subsystem tags, severity levels, timestamps, or filtering. Debugging requires reading a wall of text and mentally correlating which script produced which line. OpenClaw's per-module loggers with color coding and dual-sink (console + file) demonstrated the value of structured logging.

## Current State

### Logging patterns in the framework
- **339 stderr echo calls** across `agents/` and `lib/`
- No consistent format — some use color variables, some don't
- No subsystem identification — impossible to filter by origin
- No severity levels — warnings and errors look identical
- No timestamps — temporal ordering requires cross-referencing git or cron
- No log file — output goes to stderr (seen by Claude Code, not persisted)
- `lib/colors.sh` provides TTY-aware color variables (sourced by ~35 scripts)

### Existing infrastructure to build on
- `lib/colors.sh` — color variables, double-source guard, NO_COLOR support
- `lib/paths.sh` — framework root resolution, sourced by most scripts
- `lib/errors.sh` — error handling utilities
- `.context/working/watchtower.log` — Watchtower already has a log file (but for web UI only)

## Spike 1: Design Options

### Option A: log.sh library (recommended)
New `lib/log.sh` sourced by all scripts. Provides:
```bash
log_info  "SUBSYSTEM" "message"   # Green, informational
log_warn  "SUBSYSTEM" "message"   # Yellow, potential issue
log_error "SUBSYSTEM" "message"   # Red, failure
log_debug "SUBSYSTEM" "message"   # Dim, only when FW_DEBUG=1
```

Output format: `[2026-03-28T10:15:01Z] [INFO] [budget-gate] Context at 82%`

Dual sink: stderr (for Claude Code to see) + `.context/working/framework.log` (for human grep).

**Pros:** Simple, familiar pattern. Builds on colors.sh. Incremental migration — new scripts use it, old scripts migrate over time.
**Cons:** 339 echo calls to migrate (can be done incrementally). File log grows without rotation.

### Option B: Wrapper functions in each script
Each script defines its own `_log()` with hardcoded subsystem:
```bash
_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [budget-gate] $*" >&2; }
```

**Pros:** Zero new dependencies. Each script self-contained.
**Cons:** No centralized control. No log file. No severity filtering. Duplicated logic.

### Option C: External logger (syslog/journald)
Route framework logs to syslog:
```bash
logger -t "fw-budget-gate" -p user.warn "Context at 82%"
```

**Pros:** Proper log management, rotation, remote shipping.
**Cons:** Requires syslog configured correctly. Not portable (macOS vs Linux differences). Overkill for current scale.

## Spike 2: Migration Effort

- **New scripts:** Source `lib/log.sh`, use `log_info/warn/error` immediately
- **Existing scripts:** Replace `echo "message" >&2` with `log_info "SUBSYSTEM" "message"` — mechanical sed transformation
- **Critical path scripts** (budget-gate, check-active-task, check-tier0, checkpoint): Migrate first — these produce the most output and are hardest to debug
- **Estimated effort:** 2-3 hours for lib/log.sh + migration of top 10 scripts

## Spike 3: Log Rotation

`.context/working/framework.log` needs rotation to avoid unbounded growth.

Options:
1. **Truncate on session init** — `fw context init` clears the log. Simplest.
2. **Size-based rotation** — `log.sh` checks file size, rotates at 1MB. Medium complexity.
3. **Date-based rotation** — cron job or `fw audit` rotates daily. Leverages existing cron infrastructure.

**Recommendation:** Start with option 1 (truncate on init) — framework sessions are the natural log boundary. Add size-based rotation later if needed.

## Assumption Testing

- **A1:** Structured logging improves debugging. **VALIDATED** — 339 undifferentiated echo calls make debugging hooks extremely difficult. Even adding subsystem tags would cut triage time significantly.
- **A2:** Migration is feasible incrementally. **VALIDATED** — `source lib/log.sh` + function calls is compatible with existing echo patterns. Scripts not yet migrated continue working unchanged.
- **A3:** Log file is valuable. **PARTIALLY VALIDATED** — stderr goes to Claude Code's display but isn't persisted. A log file enables post-session analysis. But current debugging is done by the agent in-session, not by humans after the fact.
- **A4:** Performance impact is acceptable. **VALIDATED** — adding a date call and file append per log line is negligible. Budget-gate runs in <50ms already.

## Recommendation: GO

**Rationale:**
1. Clear problem with measurable impact (339 unstructured echo calls)
2. Simple implementation (one new file, well-understood pattern)
3. Builds on existing infrastructure (colors.sh, paths.sh)
4. Incremental migration (no big-bang rewrite)
5. Low risk — log.sh is additive, breaks nothing

**Build scope:**
1. Create `lib/log.sh` with log_info/warn/error/debug + dual sink + subsystem tag
2. Migrate top 10 critical scripts (budget-gate, check-active-task, check-tier0, checkpoint, context.sh, audit.sh)
3. Add `framework.log` truncation to `fw context init`
4. Document in CLAUDE.md (logging section)

**Estimated effort:** 1 build session (~3 hours)
