# T-699: fw stats — Observability Instrumentation Research

## Problem Statement

The framework has no structured way to answer "what do agents actually use?" or aggregate operational telemetry across time. KCP pattern harvest (T-697 #10) proposed SQLite-based event logging, scored 18/20.

## Current Observability Inventory

The framework already has **5 independent observability stores**:

| Store | Format | Entries | Data |
|-------|--------|---------|------|
| `metrics-history.yaml` | YAML (append) | 607 | Task counts, status breakdown, traceability % — snapshot per session |
| Audit cron YAMLs | YAML (per-run) | 578 | 130+ compliance checks, pass/warn/fail — every 30 minutes |
| Episodic summaries | YAML (per-task) | 666 | Duration, outcomes, commits, LOC, artifacts per completed task |
| Handovers | Markdown (per-session) | 426 | Session narrative, work done, decisions, suggested next |
| Learnings | YAML entries | 132 | Failure patterns, practices, cross-task knowledge |

Additionally, **git log** contains:
- 1864 commits, 98% with task references
- Command usage frequency (derivable: `fw init` 33x, `fw upgrade` 10x, etc.)
- Task creation rate (derivable: 413 in Feb, 644 in Mar)
- Session count (derivable: 207 in Feb, 219 in Mar)

And **JSONL transcripts** (per Claude session) contain:
- Actual token usage per API call
- Tool types used per session
- API call duration

## Gap Analysis

### What nobody currently tracks
1. **fw command frequency in real-time** — derivable from git post-hoc, but not logged at execution time
2. **Hook execution counts** — volatile counters (`.tool-counter`, `.edit-counter`) reset each session
3. **Command failure rates** — errors are visible in terminal but not aggregated
4. **Cross-session trends** — no single query can span all 607 metrics snapshots efficiently

### Are these gaps painful?
- **Command frequency:** Never been asked. Git derivation takes <1 second.
- **Hook counts:** Used only for budget management within a session. No cross-session need.
- **Failure rates:** Audit catches structural failures. Ad-hoc failures are one-offs.
- **Cross-session trends:** `metrics-history.yaml` can be parsed with a Python one-liner when needed.

## Alternatives Evaluated

### A. SQLite Event Logging (proposed)

Every `fw` command logs an event to `$PROJECT_ROOT/.context/stats.db`:
```sql
CREATE TABLE events (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    command TEXT,
    subcommand TEXT,
    task_id TEXT,
    duration_ms INTEGER,
    exit_code INTEGER,
    session_id TEXT
);
```

`fw stats` queries the database:
```bash
fw stats                    # Summary dashboard
fw stats commands           # Command frequency
fw stats tasks --period 7d  # Task activity last week
fw stats sessions           # Session duration distribution
```

**Pros:**
- Fast, queryable aggregation
- Time-series without scanning files
- Single source for all operational data

**Cons:**
- New dependency: `sqlite3` CLI or `python3 sqlite3` module (already available, but new code path)
- Instrumentation: every `fw` command needs a logging wrapper (~30 commands)
- Migration system needed (pattern from ntfy deep-dive, but still effort)
- Maintenance: SQLite corruption, WAL mode, vacuum, backup — new failure surface
- File-based framework gains a stateful database — architectural shift from "everything is a readable file"
- 18/20 score reflects the pattern's value in KCP (Go server), not in this bash framework

### B. Structured Log File (append-only)

Append JSON lines to `.context/stats.log`:
```bash
echo '{"ts":"...","cmd":"audit","exit":0}' >> .context/stats.log
```

Query with `jq` or `python3`:
```bash
fw stats  # jq '.cmd' .context/stats.log | sort | uniq -c
```

**Pros:**
- No new dependency (jq or python3)
- Readable, greppable, git-diffable
- Consistent with file-based architecture

**Cons:**
- Still need instrumentation in every command
- No indexing — slow queries on large files
- Log rotation needed

### C. Enhance Existing metrics-history.yaml

Add a section to the existing per-session snapshot:
```yaml
- timestamp: ...
  commands_used: {audit: 3, task: 5, context: 2}
  hooks_fired: {budget-gate: 45, checkpoint: 45}
  session_duration_min: 120
```

**Pros:**
- Zero new files or dependencies
- Builds on 607 existing entries
- Already consumed by Watchtower metrics page

**Cons:**
- Still per-session (not per-event)
- Requires instrumenting commands to count themselves
- YAML file grows — 6067 lines already

### D. Do Nothing (status quo)

Rely on existing stores. When a specific question arises, write a one-off query:
```bash
# Command frequency
git log --oneline | grep -oP 'fw \w+' | sort | uniq -c | sort -rn

# Task creation rate
git log --oneline --format='%ai' -- '.tasks/*/T-*.md' | awk '{print $1}' | cut -d- -f1,2 | sort | uniq -c

# Session duration
python3 -c "import yaml; ..." < .context/project/metrics-history.yaml
```

**Pros:**
- Zero new code, zero maintenance
- Questions are answered when asked, not preemptively instrumented
- File-based architecture preserved

**Cons:**
- Ad-hoc queries are slower than pre-indexed data
- No real-time visibility (only post-hoc via git)
- Pattern loss: hook counts, command failures not captured at all

## Recommendation

**DEFER** — the framework already has 5 observability stores with 2,400+ data points. The "what do agents use?" question is answerable from git and episodic summaries. SQLite would be a significant architectural shift (file-based → stateful database) for hypothetical queries nobody has asked.

### Rationale

1. **607 metrics snapshots + 578 audit YAMLs + 666 episodic summaries** — the data exists, just in files instead of a database
2. **Git log answers the key question** — command frequency, task rates, session counts are all derivable in <1 second
3. **SQLite adds a new failure surface** — corruption, WAL mode, vacuum, migration — in a framework that deliberately chose "everything is a file"
4. **Instrumentation cost is high** — ~30 fw commands need logging wrappers, every hook needs event capture
5. **The 18/20 score** came from KCP's Go server context where SQLite backs a web API. This framework is CLI-first with file-based storage. The pattern doesn't transfer 1:1
6. **Zero demand** — no user, session, or audit has ever needed aggregated command frequency or failure rates

### If Revisited

Trigger: Watchtower needs sub-second queries across 1000+ metrics snapshots, or a user asks "which commands do I use most?" and can't wait for a git derivation. At that point, consider Option C first (enhance metrics-history.yaml) before jumping to SQLite.
