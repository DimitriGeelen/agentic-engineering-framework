# T-882: TermLink-Based Cron Dispatch — Research Artifact

## Spike 1: Dispatch Mechanism Comparison

### Option A: `claude -p` directly from cron (simplest)

```bash
# In crontab:
*/30 * * * * cd /opt/project && claude -p "Run fw audit, interpret results, suggest fixes" \
    --output-format text > .context/cron/ai-audit-$(date +%Y%m%d-%H%M).md 2>&1
```

**Pros:** Simple, no TermLink dependency, output captured directly.
**Cons:** No observability, no kill mechanism on timeout, no task tagging, no governance.

### Option B: `termlink run` wrapping `claude -p`

```bash
# In crontab:
*/30 * * * * termlink run --name "cron-audit-$(date +%s)" \
    --timeout 300 -- claude -p "..." --output-format text
```

**Pros:** Observable (`termlink list`), timeout enforcement, session metadata.
**Cons:** T-577 timeout orphan warning — `termlink run --timeout` deregisters but doesn't kill. Need custom watchdog.

### Option C: `fw termlink dispatch` from cron (recommended)

```bash
# In crontab:
*/30 * * * * cd /opt/project && bin/fw termlink dispatch \
    --name "cron-audit" --task T-012 \
    --prompt "Run fw audit, interpret WARN/FAIL results, write remediation to docs/reports/cron-audit-latest.md"
```

**Pros:** Full governance (task-tagged), kill watchdog built-in (T-577 fix), PROJECT_ROOT properly set, output to `result.md`.
**Cons:** Requires TermLink, spawns tmux session (needs tmux in cron env).

### Option D: PTY injection into standing session

```bash
# Long-running tmux session:
termlink spawn --name "cron-worker" --backend background --shell

# In crontab:
*/30 * * * * termlink pty inject "cron-worker" "claude -p '...' > /tmp/result.md" --enter
```

**Pros:** Single persistent session, no startup overhead.
**Cons:** Complex, fragile, output management difficult, session state pollution.

### **Recommendation: Option C** (`fw termlink dispatch`)

It has the right balance: governance, observability, kill watchdog, proper CWD. The only concern is tmux in cron env — needs `PATH` set correctly.

## Spike 2: Use Case Value Assessment

### Current bash cron tasks

| Task | Current (bash) | AI-interpreted value |
|------|---------------|---------------------|
| `fw audit` (every 15-30 min) | Mechanical checks, PASS/WARN/FAIL counts | **HIGH** — interpret WHY failures happen, suggest specific fixes, track trends |
| Cron audit YAML output | Raw data, no synthesis | **HIGH** — summarize patterns across multiple audit runs |
| Fleet health (`fw doctor` on consumers) | Version check, structural checks | **MEDIUM** — could auto-remediate simple issues |
| Stale task detection | Count stale tasks | **HIGH** — could triage stale tasks, suggest closures with evidence |
| Episodic gap detection | List missing summaries | **LOW** — straightforward to fix mechanically |

### New scheduled tasks (only possible with AI)

1. **Audit interpretation + auto-remediation** — Weekly: run `fw audit`, interpret all WARN/FAILs, file issues for systemic ones, auto-fix simple ones
2. **Stale task triage** — Daily: scan work-completed tasks with unchecked Human ACs, gather evidence, suggest closures
3. **Pattern mining** — Weekly: scan episodic memory for recurring failure patterns, propose learnings/practices
4. **Cross-project learning** — Weekly: compare practices across consumer projects, identify divergence
5. **Code quality sweep** — Weekly: run shellcheck, test suite, check for known bug patterns (like `((x++))` under `set -e`)

### Cost estimate

Using Claude Sonnet (cheaper for scheduled tasks):
- Per session: ~$0.01-0.05 (depends on context loaded)
- 30-min interval audit: ~$0.50-2.50/day
- Daily triage: ~$0.05-0.10/day
- Weekly mining: ~$0.05-0.20/week

**Total: ~$1-3/day for full scheduled AI suite.**

Using local Ollama (on .107):
- Per session: $0 (but slower, less capable)
- Good for: simple triage, file listing, mechanical summaries
- Bad for: nuanced interpretation, code analysis, multi-file reasoning

**Hybrid approach:** Local LLM for frequent simple checks, API for weekly deep analysis.

## Spike 3: Determinism and Safety

### Safety model

1. **Read-only by default** — Scheduled sessions should use `--bare` mode (no hooks, no governance overhead) and only READ, not WRITE. Output goes to a report file.
2. **Action separation** — The scheduled session writes recommendations to a report. A human or interactive session acts on them.
3. **Structured output** — Use `--json-schema` to enforce deterministic output format (findings, severity, suggested actions).
4. **Budget cap** — Set `FW_CONTEXT_WINDOW=50000` for scheduled sessions (small window = fast, cheap, focused).
5. **Token limit** — `--max-tokens 2000` to prevent runaway output.

### Integration with cron registry

The existing cron registry (T-448) at `.context/cron-registry.yaml` can be extended:

```yaml
jobs:
  - id: ai-audit-interpret
    name: AI Audit Interpretation
    schedule: "0 */6 * * *"  # Every 6 hours
    command: bin/fw termlink dispatch --name cron-audit --task T-012 --prompt-file .context/cron/prompts/audit-interpret.md
    enabled: true
    type: ai  # New type: ai vs bash
```

### Output management

Scheduled AI sessions write to:
- `.context/cron/reports/YYYY-MM-DD-HHMM-<job-id>.md` — per-run report
- `.context/cron/reports/LATEST-<job-id>.md` — symlink to latest

## Recommendation: GO

**5 high-value use cases** identified. Token cost is $1-3/day — negligible for the value of automated interpretation and triage. The `fw termlink dispatch` mechanism already works. Safety model (read-only + structured output + action separation) prevents unintended mutations.

### Implementation plan (build task)

1. Add `type: ai` support to cron registry
2. Create prompt templates in `.context/cron/prompts/`
3. Add `fw cron dispatch` command wrapping `fw termlink dispatch` for scheduled AI tasks
4. Structured output schema for audit interpretation
5. Report storage in `.context/cron/reports/`
6. Watchtower page for AI cron reports

## Dialogue Log

- **User asked:** Can we spawn cron TermLink sessions using Claude? Value of using TermLink for scheduled deterministic-but-interpreted tasks.
- **Key insight:** The value isn't replacing bash cron — it's augmenting it. Bash handles mechanical checks (fast, free). AI handles interpretation and triage (slower, costs tokens, but adds intelligence).
