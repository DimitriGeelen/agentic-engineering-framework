---
title: "T-433: Cron Job Registry and Administration Page"
task: T-433
type: inception-research
created: 2026-03-12
---

# T-433: Cron Job Registry Inception

## Spike 1: Cron Infrastructure Inventory

### Current Jobs

Two cron files in `/etc/cron.d/`:

**1. `agentic-audit`** (T-184, T-196)
Installed by `fw audit schedule install`. 8 scheduled entries:

| Schedule | Section | Purpose |
|----------|---------|---------|
| `*/30 * * * *` | structure, compliance, quality | Task quality + structure integrity |
| `0 * * * *` | traceability, episodic | Git traceability + episodic completeness |
| `0 */6 * * *` | observations, gaps | Observations + gaps register |
| `15,45 * * * *` | oe-fast, oe-research | Fast OE checks (CTL-001,003,004,018) |
| `30 * * * *` | oe-hourly | Hourly OE checks (CTL-008,020) |
| `0 7 * * *` | oe-daily | Daily OE checks (14 controls) |
| `0 9 * * 1` | oe-weekly | Weekly OE checks (CTL-016) |
| `0 8 * * *` | (all) | Full audit — all sections |

Plus 1 maintenance entry:
| `0 9 * * *` | (cleanup) | Prune cron audit files older than 7 days |

**2. `agentic-onedev-sync`** (T-442, T-443)
LOCAL ONLY (in .gitignore). 1 scheduled entry:

| Schedule | Purpose |
|----------|---------|
| `*/15 * * * *` | Poll OneDev for new open PRs, create framework tasks |

### Metadata Available Per Job

From cron files:
- Schedule (cron expression)
- Command (full path)
- User (root)
- Task origin (T-xxx in comments)
- Purpose (in comments)

From output:
- Last run time (file timestamps in `.context/audits/cron/`)
- Output (YAML audit results)
- Pass/warn/fail counts

### What We Cannot Get Without Extra Work
- Whether the job is currently running (no PID tracking)
- Next run time (cron doesn't expose this natively — need to calculate from expression)
- Exit code of last run (cron output goes to /dev/null)
- Error logs (stderr suppressed with `2>/dev/null`)

---

## Spike 2: Control Safety Model

### What is safe to expose

| Control | Risk | Assessment |
|---------|------|------------|
| View schedule | None | Safe — read-only |
| View last run output | None | Safe — read audit YAML |
| Calculate next run | None | Safe — parse cron expression |
| Pause a job (comment out in cron file) | Low | Safe with confirmation — reversible |
| Resume a job (uncomment in cron file) | Low | Safe — restores original schedule |
| Change frequency | Medium | Safe with validation — must be valid cron expression |
| Run job now (manual trigger) | Medium | Safe for audit jobs — they are idempotent |
| Delete a job | High | Needs confirmation + logging |
| Create new arbitrary job | Very High | OUT OF SCOPE — too dangerous |

### Proposed Safety Model

**Tier A (no confirmation):** View, last run, next run, output inspection
**Tier B (confirmation dialog):** Pause, resume, change frequency, run now
**Tier C (blocked or admin-only):** Delete, create new

### Implementation Approaches

**Option A: Direct cron file editing**
- Read/write `/etc/cron.d/agentic-*`
- Requires root or appropriate permissions
- Risk: malformed cron file breaks all jobs
- Mitigation: validate syntax before writing, keep backup

**Option B: Registry file + cron file is generated**
- Jobs defined in `.context/cron-registry.yaml`
- A script generates `/etc/cron.d/agentic-*` from registry
- UI edits the registry, regenerates cron file
- Risk: registry and cron file can get out of sync
- Mitigation: always regenerate, never edit cron directly

**Option C: Read-only display + manual controls via CLI**
- Page displays all jobs, status, output — read-only
- Controls via CLI: `fw cron pause audit-structural`, `fw cron run audit-full`
- CLI modifies cron files, page refreshes to show state
- Risk: lower than direct web editing
- Mitigation: CLI validates everything

**Recommendation: Option C** (read-only page + CLI controls) for initial build.
- Lowest risk
- Fastest to build (display page is pure read)
- CLI controls can be added incrementally
- Upgrade to Option B later if demand warrants

---

## Spike 3: LLM Documentation Assessment

### What the LLM would generate from

Each cron job has:
- The cron expression (schedule)
- The command (e.g., `fw audit --section oe-fast,oe-research --cron`)
- Comments in the cron file (task refs, purpose notes)
- The script source code (e.g., `agents/audit/audit.sh`)

### Assessment

For **audit jobs**: the `--section` flag maps to specific check categories. The LLM could generate a description like: "Runs fast operational effectiveness checks every 30 minutes: verifies active task focus (CTL-001), budget status freshness (CTL-003), tool counter (CTL-004), and budget JSON validity (CTL-018). Also checks research artifact persistence (CTL-014, 021-023)."

For **onedev-sync**: the script is self-contained Python. The LLM could describe: "Polls OneDev API for open pull requests every 15 minutes. Creates framework tasks (horizon: next) for new PRs not previously seen. Tracks seen PRs in `.context/working/.onedev-pr-seen`."

### Verdict

LLM docs are useful but not essential for v1. Two reasons:
1. Only 2 cron files with 10 total entries — manual descriptions are feasible
2. Adding Ollama dependency to a display page adds latency and complexity

**Recommendation:** v1 uses static descriptions from cron file comments. v2 adds LLM-generated descriptions as an enhancement.

---

## Spike 4: Page Design

### Data Model (per job)

```yaml
# .context/cron-registry.yaml (or derived from /etc/cron.d/)
jobs:
  - id: audit-structural
    name: "Structural audit"
    schedule: "*/30 * * * *"
    command: "fw audit --section structure,compliance,quality --cron"
    source_file: "/etc/cron.d/agentic-audit"
    origin_task: T-184
    status: active  # active | paused
    last_run: 2026-03-12T06:30:00Z
    last_result: { pass: 12, warn: 2, fail: 0 }
    description: "Task quality and structure integrity checks"
```

### Page Layout

```
┌──────────────────────────────────────────────────┐
│ Scheduled Jobs                           [Refresh]│
├──────────────────────────────────────────────────┤
│ ● Structural audit          */30 * * * *         │
│   Last: 2 min ago (12 pass, 2 warn)   [Run Now] │
│                                                   │
│ ● Git traceability          0 * * * *            │
│   Last: 32 min ago (5 pass, 1 warn)   [Run Now] │
│                                                   │
│ ● OE fast checks            15,45 * * * *        │
│   Last: 18 min ago (8 pass, 0 warn)   [Run Now] │
│                                                   │
│ ○ OneDev PR sync            */15 * * * *         │
│   Last: 8 min ago (silent — no new PRs)          │
│   ⚠ LOCAL ONLY                                   │
├──────────────────────────────────────────────────┤
│ Legend: ● active  ○ local-only  ◌ paused         │
└──────────────────────────────────────────────────┘
```

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/cron/jobs` | List all jobs with status |
| GET | `/api/cron/jobs/{id}/output` | Last run output |
| POST | `/api/cron/jobs/{id}/run` | Trigger manual run (Tier B) |
| POST | `/api/cron/jobs/{id}/pause` | Pause job (Tier B) |
| POST | `/api/cron/jobs/{id}/resume` | Resume job (Tier B) |

### Watchtower Integration

- New blueprint: `web/blueprints/cron.py`
- New template: `web/templates/cron.html`
- Nav entry between "Metrics" and "Settings"
- Dashboard widget: "Scheduled Jobs: N active, last run M min ago"

---

## Design Options Summary

| Aspect | Option A (v1 recommended) | Option B (future) |
|--------|--------------------------|-------------------|
| Display | Read all from `/etc/cron.d/agentic-*` | Registry YAML + generated cron |
| Controls | Read-only page, CLI for management | Web UI controls with confirmation |
| Documentation | Static from cron comments | LLM-generated from script source |
| Effort | ~3-4h (1 blueprint, 1 template, parsing) | ~8-10h (registry, CLI, generation) |
| Risk | Low (read-only) | Medium (file editing) |

---

## Dialogue Log

### 2026-03-12 — Inception started
- Human chose T-433 over T-434
- 4 spikes completed: inventory (10 jobs across 2 files), safety model (3 tiers), LLM assessment (defer to v2), page design (read-only with CLI controls)
