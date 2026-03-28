---
title: "Zombie MCP Orphan Reaper — Design Research"
task: T-178-experiment
date: 2026-02-18
status: complete
tags: [mcp, zombie-processes, orphan-reaper, research]
---

# Zombie MCP Orphan Reaper — Design Research

## 1. Detection: Identifying Orphaned MCP Processes

### Process Anatomy of a Live Claude Code MCP Session

Observed on a running system (Linux Mint 22.1, systemd 255):

```
sudo (session leader, SID owner)
  └── claude (PPID=sudo)
       ├── npm exec @upstash/context7-mcp (PPID=claude, PGID=claude)
       │    └── sh -c context7-mcp
       │         └── node .../context7-mcp
       └── npm exec @playwright/mcp@latest --no-sandbox (PPID=claude, PGID=claude)
            └── sh -c playwright-mcp --no-sandbox
                 └── node .../playwright-mcp --no-sandbox
                      └── chromium (8 child processes: zygote, network, storage, renderer x2, gpu)
```

Each MCP server spawns a 4-level process tree: `npm exec` -> `sh -c` -> `node` (the actual server) -> optional children (e.g., chromium for Playwright).

**Key observation:** All processes in one MCP session share the same PGID (= the `claude` PID) and the same SID (= the `sudo` session leader). This is the critical fingerprint for detection.

### What Happens When Claude Dies

When the `claude` process exits (cleanly or via crash/SIGKILL):

1. **PPID reparenting:** All direct children (`npm exec` processes) get PPID=1 (adopted by systemd/init).
2. **PGID preserved:** The process group ID does NOT change. Orphans keep the dead claude's PID as their PGID.
3. **SID preserved:** Session ID stays the same (owned by the `sudo` session leader).
4. **TTY potentially preserved:** If the terminal stays open, the TTY assignment persists. If the terminal is closed, SIGHUP is sent to the session's foreground process group.
5. **No automatic SIGHUP from parent death:** Node.js MCP servers do NOT have `PR_SET_PDEATHSIG` configured (checked via `/proc/PID/status` — no death signal registered). When the `claude` parent dies, children receive NO signal.

### The PPID=1 + Age Heuristic: Assessment

**Reliability: HIGH for the orphan case, but needs refinement.**

The heuristic `PPID == 1 AND matches MCP pattern AND age > threshold` is sound because:

- **True positive rate is very high:** Legitimate MCP processes always have `claude` as their PPID (via `npm exec`). If PPID=1, the parent died.
- **False positive risk is LOW but nonzero:** A user could manually run `npm exec @playwright/mcp@latest` from a terminal, then background it and close the terminal. PPID would become 1 but the process is "intentional." This edge case is negligible in practice.

**Recommended detection criteria (ranked by specificity):**

| Check | Reliability | Notes |
|-------|-------------|-------|
| `PPID == 1` | Necessary condition | Filters to orphans only |
| Command matches `npm exec.*mcp` or `node.*mcp` | High specificity | Catches MCP servers, not random node processes |
| `age > 30 minutes` | Safe threshold | Active sessions rarely exceed 4 hours; 30 min eliminates race conditions during startup |
| PGID leader is dead | Definitive proof | If the process whose PID matches the orphan's PGID doesn't exist, the group is orphaned |
| No active `claude` process with matching PGID | Definitive | Cross-references running claude sessions |

**The PGID check is the gold standard.** If the PGID leader (which was the `claude` process) no longer exists, the entire process group is orphaned. This is more reliable than age alone.

### Zombie vs Orphan: Terminology Clarification

These are distinct process states:

- **Zombie (Z state):** Process has exited but its parent hasn't called `wait()`. Shows as `Z` or `Z+` in `ps` STAT column. Takes zero memory (just a process table entry). Cleaned up when parent reads exit status or parent dies (init inherits and reaps).
- **Orphan (S/R state, PPID=1):** Process is ALIVE and RUNNING but its parent died. Adopted by init/systemd. These consume real memory (50-270MB per MCP tree) and CPU.

**MCP orphans are NOT zombies.** They are fully alive, consuming resources, doing nothing useful. The term "zombie" is colloquially used but technically incorrect. The real problem is orphaned processes, not zombies. Zombies are harmless (just a PID slot); orphans waste real memory.

Checked the current system: **zero zombie processes** (confirmed via `ps -eo stat | grep Z`). All MCP processes were in state `S` (sleeping) or `Sl` (sleeping, multi-threaded) — alive and well.

### Memory Footprint Per MCP Session (Observed)

| Component | Count | RSS per process | Subtotal |
|-----------|-------|-----------------|----------|
| npm exec | 2 | 12-37 MB | ~50 MB |
| sh wrapper | 2 | <1 MB | ~1 MB |
| node MCP server | 2 | 14-66 MB | ~80 MB |
| chromium (Playwright) | 8 | 14-68 MB | ~270 MB |
| **Total per session** | **14** | — | **~400 MB** |

Without Playwright/chromium: ~130 MB per session.
With Playwright/chromium: ~400 MB per session.

**12 orphan sessions (the reported scenario) = 1.5-4.8 GB wasted memory.**

## 2. Cleanup Approaches: Comparison

### Option A: Shell Script with `ps` + `kill`

```bash
# Pros:
# - Zero dependencies, works everywhere
# - Easy to understand and modify
# - Can be run ad-hoc or from cron/fw doctor

# Cons:
# - Race conditions between detection and kill (PID reuse, though very unlikely with modern 32-bit PIDs)
# - No persistent state (can't track "warned but not yet killed")
# - Must be explicitly invoked

# Verdict: RECOMMENDED as primary approach
# Simplicity wins. Race conditions are theoretical at these timescales.
```

### Option B: Systemd User Unit with Timer

```ini
# ~/.config/systemd/user/mcp-reaper.service
[Unit]
Description=Reap orphaned MCP processes

[Service]
Type=oneshot
ExecStart=/path/to/mcp-reaper.sh

# ~/.config/systemd/user/mcp-reaper.timer
[Unit]
Description=Run MCP orphan reaper every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
```

```
Pros:
- Automatic, no manual invocation
- Systemd journal logging for free
- Timer survives user session restarts

Cons:
- Requires systemd (not available on macOS)
- User-level systemd may not be enabled (needs loginctl enable-linger)
- Overkill for most users — adds system complexity for a niche problem
- Root processes (as observed) need system-level units, not user-level

Verdict: OPTIONAL enhancement for heavy users
Good for servers/workstations with many daily Claude sessions.
```

### Option C: Cron Job

```crontab
# Every 30 minutes
*/30 * * * * /path/to/mcp-reaper.sh --quiet >> /var/log/mcp-reaper.log 2>&1
```

```
Pros:
- Universal (works on Linux, macOS, BSDs)
- Simple to set up
- Well-understood by sysadmins

Cons:
- No dependency on framework (could be a pro or con)
- Separate from fw workflow — user must remember to install it
- Less visibility than fw doctor integration

Verdict: GOOD ALTERNATIVE to systemd timer
Better for macOS users or those who prefer cron.
```

### Option D: Integration with `fw doctor`

```
Pros:
- Discovered during routine health checks
- No additional setup (already part of framework workflow)
- Can report without killing (--dry-run is natural)
- Aligns with "antifragility" directive — system self-monitors

Cons:
- Only runs when user explicitly calls fw doctor
- Won't catch orphans between sessions if user forgets
- Detection-only (reporting) is safer; killing during doctor feels aggressive

Verdict: RECOMMENDED as detection/reporting layer
fw doctor should DETECT and REPORT orphans; separate command should KILL them.
```

### Recommended Architecture

```
fw doctor          →  DETECT + REPORT (passive, always safe)
fw mcp reap        →  DETECT + KILL (active, requires confirmation or --force)
fw mcp reap --dry  →  DETECT + REPORT (same as doctor check, standalone)
cron/systemd       →  OPTIONAL automation of fw mcp reap --force --quiet
```

## 3. Safety: Avoiding Killing Legitimate Processes

### Signal Strategy

**SIGTERM first, SIGKILL after grace period.** This is the standard Unix pattern.

```
1. Send SIGTERM to process group (-PGID)     ← tells all processes to shut down
2. Wait 5 seconds                             ← grace period for cleanup
3. Check if still alive                       ← some processes ignore SIGTERM
4. Send SIGKILL to survivors (-PGID)          ← force kill (unblockable)
```

**Why process group kill (`kill -PGID`) is better than individual PID kill:**
- Catches ALL processes in the orphaned tree (npm, sh, node, chromium)
- Single operation instead of walking the tree
- Prevents child processes from surviving parent kill

**Why SIGTERM first:**
- Node.js handles SIGTERM by default (exits cleanly)
- Chromium handles SIGTERM (closes tabs, releases lock files)
- Playwright MCP can clean up its user data directory
- SIGKILL leaves lock files, shared memory segments, and temp files behind

### Safety Checks (Must-Pass Before Killing)

1. **Is there a living `claude` process with this PGID?** If yes, DO NOT KILL — this is an active session.
2. **Is the PPID == 1?** If no, the process still has a parent — don't kill it.
3. **Does the command match MCP patterns?** Only kill processes matching `npm exec.*mcp`, `node.*mcp`, `sh -c.*mcp`, or chromium processes whose PGID traces to an MCP group.
4. **Is the process older than the threshold?** Default 30 minutes. This prevents killing processes during normal startup/shutdown transitions.
5. **Is there a PID lock file that's still valid?** Check `/root/.claude/tasks/*/lock` — though these map to Claude task UUIDs, not PIDs (so limited use).

### Edge Cases

| Scenario | Risk | Mitigation |
|----------|------|------------|
| User manually runs MCP server | Low: manual invocations don't use `npm exec` pattern | Pattern matching specificity |
| Two Claude sessions share a terminal | Medium: both have same SID | PGID check distinguishes them |
| Process just started (< 30 min) | Medium: might be a new session | Age threshold |
| Containerized MCP (Docker) | Low: container PID namespace isolates | Container has its own PID 1 |
| PID wraparound (PGID reuse) | Extremely low: 32-bit PIDs, would take millions of processes | Age check catches stale references |

### Grace Period Recommendation

- **30 minutes** for detection threshold (when was parent last alive?)
- **5 seconds** between SIGTERM and SIGKILL
- **Interactive confirmation** by default; `--force` flag for automated use

## 4. Implementation Sketch

```bash
#!/usr/bin/env bash
# mcp-reaper.sh — Detect and kill orphaned MCP processes
# Usage: mcp-reaper.sh [--dry-run] [--force] [--age MINUTES] [--quiet]
#
# Exit codes:
#   0 = no orphans found (or all reaped successfully)
#   1 = orphans found (dry-run) or reap failed
#   2 = usage error

set -euo pipefail

# Defaults
DRY_RUN=false
FORCE=false
AGE_THRESHOLD=30  # minutes
QUIET=false

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --force)   FORCE=true; shift ;;
        --age)     AGE_THRESHOLD="$2"; shift 2 ;;
        --quiet)   QUIET=true; shift ;;
        *)         echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

log() { $QUIET || echo "$@"; }
warn() { echo "WARNING: $@" >&2; }

# --- Detection ---

# Find all MCP-related processes with PPID=1 (orphaned)
# Columns: PID, PPID, PGID, ETIMES (elapsed seconds), RSS (KB), ARGS
detect_orphans() {
    local age_seconds=$((AGE_THRESHOLD * 60))
    local orphan_pgids=()

    # Find npm exec MCP processes where PPID=1
    while IFS= read -r line; do
        local pid ppid pgid etimes rss args
        read -r pid ppid pgid etimes rss args <<< "$line"

        # Safety check 1: Must be orphaned (PPID=1)
        [[ "$ppid" -eq 1 ]] || continue

        # Safety check 2: Must be old enough
        [[ "$etimes" -ge "$age_seconds" ]] || continue

        # Safety check 3: No living claude process owns this PGID
        if ps -p "$pgid" -o comm= 2>/dev/null | grep -q "claude"; then
            continue  # Active session — skip
        fi

        # This PGID group is orphaned
        orphan_pgids+=("$pgid")

    done < <(ps -eo pid,ppid,pgid,etimes,rss,args 2>/dev/null | \
             grep -E "npm exec.*(mcp|context7|playwright)" | \
             grep -v grep || true)

    # Deduplicate PGIDs
    local unique_pgids=($(printf '%s\n' "${orphan_pgids[@]}" 2>/dev/null | sort -u))

    if [[ ${#unique_pgids[@]} -eq 0 ]]; then
        log "No orphaned MCP process groups found."
        return 0
    fi

    # Report findings
    log "Found ${#unique_pgids[@]} orphaned MCP process group(s):"
    local total_rss=0
    for pgid in "${unique_pgids[@]}"; do
        local count rss_sum
        count=$(ps -eo pgid 2>/dev/null | awk -v g="$pgid" '$1 == g' | wc -l)
        rss_sum=$(ps -eo pgid,rss 2>/dev/null | awk -v g="$pgid" '$1 == g {sum+=$2} END {print sum+0}')
        total_rss=$((total_rss + rss_sum))
        log "  PGID $pgid: $count processes, $((rss_sum / 1024))MB RSS"

        if ! $QUIET; then
            ps -eo pid,ppid,pgid,etimes,rss,comm 2>/dev/null | \
                awk -v g="$pgid" 'NR==1 || $3 == g' | head -20
            echo ""
        fi
    done

    log "Total orphaned memory: $((total_rss / 1024))MB across ${#unique_pgids[@]} group(s)"

    if $DRY_RUN; then
        log "(dry-run mode — no processes killed)"
        return 1  # Signal: orphans exist
    fi

    # --- Reap ---
    if ! $FORCE; then
        echo ""
        read -p "Kill these orphaned process groups? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy] ]] || { log "Aborted."; return 1; }
    fi

    for pgid in "${unique_pgids[@]}"; do
        log "Sending SIGTERM to process group $pgid..."
        kill -TERM "-$pgid" 2>/dev/null || true
    done

    log "Waiting 5 seconds for graceful shutdown..."
    sleep 5

    # Check for survivors and SIGKILL them
    local survivors=0
    for pgid in "${unique_pgids[@]}"; do
        if ps -eo pgid 2>/dev/null | awk -v g="$pgid" '$1 == g' | grep -q .; then
            warn "PGID $pgid survived SIGTERM — sending SIGKILL"
            kill -KILL "-$pgid" 2>/dev/null || true
            survivors=$((survivors + 1))
        fi
    done

    if [[ $survivors -gt 0 ]]; then
        sleep 1  # Brief wait after SIGKILL
    fi

    log "Reap complete. Freed ~$((total_rss / 1024))MB."
    return 0
}

detect_orphans
```

### Integration Points

**For `fw doctor`:**
```bash
# Add to doctor health checks:
check_mcp_orphans() {
    local orphan_count
    orphan_count=$(ps -eo pid,ppid,args 2>/dev/null | \
                   awk '$2 == 1' | \
                   grep -cE "npm exec.*(mcp|context7|playwright)" || echo 0)

    if [[ "$orphan_count" -gt 0 ]]; then
        echo "WARNING: $orphan_count orphaned MCP processes detected"
        echo "  Run 'fw mcp reap' to clean up"
        return 1
    fi
    return 0
}
```

**For `fw mcp reap`:**
```bash
# In lib/ or as a fw subcommand:
# fw mcp reap [--dry-run] [--force] [--age MINUTES]
# Delegates to the mcp-reaper.sh script above
```

## 5. Platform Considerations

### Linux

- **Full support.** `/proc` filesystem provides rich process metadata (status, environ, cgroup, etc.).
- PGID-based group kill works perfectly.
- `ps -eo etimes` gives elapsed time in seconds (ideal for age comparison).
- `systemd` timer is available for automated scheduling.
- Container note: If Claude Code runs inside a container, PID 1 inside the container is the container's init, not the host's systemd. The reaper must run in the same PID namespace as the orphans.

### macOS

- **Mostly compatible** with adaptations:
  - No `/proc` filesystem. Use `ps` and `sysctl` instead.
  - `ps -eo etimes` is **not available** on macOS `ps`. Must parse `etime` (format: `[[dd-]hh:]mm:ss`) and convert to seconds.
  - `pgrep` and `pkill` work (available via default install).
  - Process group kill (`kill -TERM -PGID`) works identically.
  - Use `launchd` plist instead of systemd timer for scheduling.
  - `launchctl` replaces `systemctl`.

**macOS etime parser:**
```bash
# Convert macOS etime format to seconds
parse_etime() {
    local etime="$1"
    local days=0 hours=0 mins=0 secs=0

    if [[ "$etime" == *-* ]]; then
        days="${etime%%-*}"
        etime="${etime#*-}"
    fi

    IFS=: read -ra parts <<< "$etime"
    case ${#parts[@]} in
        3) hours="${parts[0]}"; mins="${parts[1]}"; secs="${parts[2]}" ;;
        2) mins="${parts[0]}"; secs="${parts[1]}" ;;
        1) secs="${parts[0]}" ;;
    esac

    echo $(( days*86400 + hours*3600 + mins*60 + secs ))
}
```

**macOS launchd plist (equivalent of systemd timer):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mcp-reaper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/mcp-reaper.sh</string>
        <string>--force</string>
        <string>--quiet</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>StandardOutPath</key>
    <string>/tmp/mcp-reaper.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/mcp-reaper.log</string>
</dict>
</plist>
```

### Container Environments (Docker, Podman)

- **PID namespace isolation:** Each container has its own PID 1. Orphans inside the container are adopted by the container's init, not the host's systemd.
- **Tini/dumb-init:** If the container uses a proper init (tini, dumb-init), orphans are reaped automatically when the init exits. This largely eliminates the problem.
- **Without init:** If the container runs `claude` as PID 1 directly, zombie processes can accumulate (PID 1 must explicitly reap children). Orphans may persist until the container stops.
- **Recommendation:** If running Claude Code in containers, use `--init` flag (`docker run --init`) to get automatic orphan reaping.

### WSL (Windows Subsystem for Linux)

- Behaves like Linux. `/proc` is available. `ps` works normally.
- WSL2 uses a real Linux kernel, so all detection methods work.
- Systemd may or may not be enabled (WSL2 supports it via `[boot] systemd=true` in `wsl.conf`).
- Cron is the safer choice for WSL automation.

## 6. Recommendations Summary

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Primary detection | PGID leader alive check + PPID=1 | Most reliable; zero false positives |
| Fallback detection | PPID=1 + MCP pattern + age > 30 min | Works without PGID analysis |
| Kill strategy | SIGTERM -> 5s wait -> SIGKILL on survivors | Standard graceful shutdown |
| Kill granularity | Process group (`kill -PGID`) | Catches entire tree (npm, sh, node, chromium) |
| Integration | `fw doctor` (detect) + `fw mcp reap` (kill) | Passive detection + explicit action |
| Automation | Optional cron/systemd timer | For heavy users; not default |
| Default age threshold | 30 minutes | Eliminates startup race conditions |
| Confirmation | Interactive by default; `--force` for automation | Safety first |
| Cross-platform | Bash with `ps` (POSIX), etime parser for macOS | Covers Linux + macOS |

## 7. Open Questions for Implementation

1. **Should `fw mcp reap` be automatic at session start?** Adding it to `fw context init` would clean up before each session. Risk: adds latency to session start (~0.5s).
2. **Should we track which sessions spawned which PGIDs?** A `.context/working/.mcp-pids` file could record active MCP PGIDs, making orphan detection instant (check file, verify PGIDs still alive).
3. **Chromium user-data-dir cleanup:** Orphaned Playwright MCP leaves behind `/root/.cache/ms-playwright/mcp-chrome-*` directories. Should the reaper clean those too?
4. **Notification vs auto-kill:** Should `fw doctor` just report, or should it offer to kill in-line? Current recommendation: report + suggest command.
