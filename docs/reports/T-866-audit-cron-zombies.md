# T-866: Audit Cron Zombie Accumulation — Research Artifact

## Problem Statement

136 `fw audit` processes accumulated over 41 days uptime, consuming all CPU (load 158) and forcing 22GB swap thrashing. Root cause: cron schedules ~9 audit invocations per cycle. Audit processes get stuck (>90s runtime with 124+ tasks) and pile up because there is no: (1) singleton guard, (2) execution timeout, (3) stale process reaper.

**Current state (2026-04-04):** 18+ zombie audit processes still running despite earlier cleanup.

## Spike A: flock-based singleton guard

### Findings

- `flock` available at `/usr/bin/flock` on this Linux system
- macOS does NOT ship flock (available via `brew install util-linux` but not default)
- audit.sh has NO existing process guard — no flock, no pidfile, no lock check
- `.context/locks/` directory exists (keylock system from T-587) but audit.sh doesn't use it
- Lock files should be per-project to allow parallel audits across different projects

### Approach

Wrap `--cron` mode invocations with flock at the entry point of audit.sh:

```bash
# Near the top of audit.sh, after --cron flag is parsed:
if [ "$CRON_MODE" = true ]; then
    LOCKFILE="$PROJECT_ROOT/.context/locks/audit-cron.lock"
    mkdir -p "$(dirname "$LOCKFILE")"
    exec 9>"$LOCKFILE"
    if ! flock -n 9; then
        # Another audit is already running — exit silently
        exit 0
    fi
    # Lock acquired — fd 9 stays open for duration of script
fi
```

**macOS compatibility:** flock not available by default. Options:
1. Use `mkdir`-based lock (POSIX, atomic) — less robust but portable
2. Require `brew install util-linux` — adds dependency
3. Check for flock, fall back to mkdir lock

**Recommendation:** Check for flock availability, fall back to mkdir-based lock:
```bash
if command -v flock >/dev/null 2>&1; then
    # Use flock (Linux, macOS with brew)
    exec 9>"$LOCKFILE"
    if ! flock -n 9; then exit 0; fi
else
    # POSIX fallback: mkdir is atomic
    if ! mkdir "$LOCKFILE.d" 2>/dev/null; then exit 0; fi
    trap 'rmdir "$LOCKFILE.d" 2>/dev/null' EXIT
fi
```

### Verdict: GO — straightforward, well-understood pattern

## Spike B: timeout wrapper

### Findings

- `timeout` command available on Linux (`/usr/bin/timeout`)
- macOS does NOT ship `timeout` (available via `brew install coreutils` as `gtimeout`)
- audit.sh has internal subprocess timeouts (5-10s) but no overall timeout
- Current audit runtime: 90s+ with 124 tasks (7 loops × 15 Python calls)
- Cron interval: 15 minutes minimum → 5-minute timeout is conservative and safe

### Approach

Two options:
1. **External timeout:** Wrap entire script with `timeout` in cron command
2. **Internal timeout:** Add self-timeout at script start

Internal timeout is better — portable, self-documenting:

```bash
if [ "$CRON_MODE" = true ]; then
    AUDIT_TIMEOUT="${FW_AUDIT_TIMEOUT:-300}"  # 5 minutes default
    # Self-timeout: re-exec with timeout if not already wrapped
    if [ -z "${_AUDIT_TIMEOUT_SET:-}" ]; then
        export _AUDIT_TIMEOUT_SET=1
        if command -v timeout >/dev/null 2>&1; then
            exec timeout "$AUDIT_TIMEOUT" "$0" "$@"
        fi
        # No timeout command available — proceed without (macOS fallback)
    fi
fi
```

### Verdict: GO — 5-minute default, configurable via FW_AUDIT_TIMEOUT

## Spike C: stale process detection

### Findings

- 18+ audit processes currently running, some 4+ hours old
- No existing stale process detection in audit.sh
- `pgrep` available for process detection
- Stale = running longer than 2× timeout (10 minutes default)

### Approach

Add stale process reaper to `--cron` mode, runs before lock acquisition:

```bash
if [ "$CRON_MODE" = true ]; then
    # Kill audit processes running longer than 10 minutes
    STALE_MINUTES="${FW_AUDIT_STALE_MINUTES:-10}"
    pgrep -f "audit.sh.*--cron" | while read pid; do
        [ "$pid" = "$$" ] && continue  # Don't kill self
        elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$elapsed" ] && [ "$elapsed" -gt $((STALE_MINUTES * 60)) ]; then
            kill "$pid" 2>/dev/null
            logger -t "fw-audit" "Killed stale audit process $pid (${elapsed}s old)"
        fi
    done
fi
```

**macOS note:** `ps -o etimes=` may not work on macOS. Alternative: `ps -o etime=` with parsing.

### Verdict: GO — defensive, logs kills, skips self

## Recommendation

**GO** — All three spikes are feasible and well-scoped:

1. **flock guard** prevents concurrent runs (root cause fix)
2. **timeout wrapper** prevents individual runs from hanging (defense in depth)
3. **stale reaper** cleans up any processes that escaped previous guards (cleanup)

**Implementation order:** Guard → Timeout → Reaper (each layer adds protection)

**Complexity:** Low — all changes are in the first 50 lines of audit.sh, cron-mode only.

**Risk:** Minimal — only affects `--cron` mode. Manual `fw audit` runs are unguarded (interactive, user can Ctrl-C).

**Evidence:**
- flock available: `/usr/bin/flock` ✓
- Lock directory exists: `.context/locks/` ✓
- Configurable via existing pattern: `FW_AUDIT_TIMEOUT` env var ✓
- 18+ zombie processes confirmed right now ✓
- macOS fallback patterns identified for all three mechanisms ✓

**Additional finding (2026-04-05):** `fw doctor` does not detect zombie audit processes. Consider adding process health check as follow-up build task after GO.
