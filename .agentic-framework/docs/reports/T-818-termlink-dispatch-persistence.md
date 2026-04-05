# T-818: TermLink Dispatch Result Persistence

## Research Question

When TermLink workers complete their work but the parent session can't integrate results (budget exhaustion, compaction, crash), how do we prevent output loss?

## Root Cause Analysis

### The Incident (T-816, 2026-04-03)

1. Parent dispatched two TermLink workers: `t816-null-object` and `t817-three-tier`
2. Both workers followed the dispatch preamble: write to `/tmp/fw-agent-{name}.md`
3. T-817 completed first — parent integrated output to `docs/reports/T-817-three-tier-config.md` (367 lines)
4. T-816 completed second — parent was at ~192K/200K tokens, budget gate blocked Write/Edit
5. T-816 output sat in `/tmp/fw-agent-T-816-null-object-fallback.md` (307 lines) — recovered manually next session

### Why the Preamble Is Wrong for TermLink

The dispatch preamble (`agents/dispatch/preamble.md:15`) says:
```
Output file: /tmp/fw-agent-{describe-your-task-briefly}.md
```

This instruction exists to prevent **context explosion** (T-073: 9 agents returning full YAML spiked context by 30K+). It's correct for **Task tool agents** because:
- Task tool agents share the parent's context window
- The parent reads the `/tmp/` file immediately via Read tool
- The file is consumed in the same session it's produced

It's **wrong for TermLink workers** because:
- TermLink workers run in independent processes (zero context cost)
- The parent may NOT read the file immediately (budget gate, compaction)
- `/tmp/` is ephemeral — cleaned on reboot, not git-tracked
- There's no guarantee the parent session survives to integrate

### The Two Dispatch Mechanisms Have Different Lifecycles

| Property | Task tool agent | TermLink worker |
|----------|----------------|-----------------|
| Context cost | Shares parent budget | Zero |
| Output timing | Synchronous (parent waits) | Asynchronous (parent notified) |
| Integration window | Immediate | May be delayed or never |
| `/tmp/` risk | Low (consumed same session) | **High** (session may end before integration) |
| Process lifetime | Tied to parent | Independent |

## Options Evaluated

### Option A: Workers write directly to target files

TermLink workers write to `docs/reports/T-XXX-*.md` (or wherever the output belongs) instead of `/tmp/`.

- **Pro:** Output is in the repo from the start — survives any parent failure
- **Pro:** No integration step needed — the file IS the deliverable
- **Pro:** Zero infrastructure change — just different instructions in the dispatch prompt
- **Con:** Orchestrator must specify the target path in the prompt (already does this implicitly)
- **Con:** If worker crashes mid-write, partial file in repo (mitigated: git shows the partial)

### Option B: Workers use `fw bus post`

Worker runs `fw bus post --task T-XXX --blob /path/to/output` to register the result.

- **Pro:** Uses existing bus infrastructure, structured tracking
- **Pro:** Bus manifest in `.context/bus/` (allowed by budget gate)
- **Con:** Still writes blob to `.context/bus/blobs/` — not the final target location
- **Con:** Adds a step: worker must know `fw bus` and have framework sourced
- **Con:** Over-engineered for a problem that Option A solves with zero code

### Option C: Handover sweep for orphaned outputs

During `fw handover`, scan `/tmp/fw-agent-*` for files newer than session start that haven't been integrated.

- **Pro:** Catches all cases automatically, defense-in-depth
- **Pro:** Works for both Task tool and TermLink dispatch
- **Con:** Reactive — flags the problem, doesn't prevent it
- **Con:** Handover itself may be blocked by budget gate (chicken-and-egg)
- **Con:** Can't distinguish "orphaned" from "intentionally temporary"

### Option D: Separate TermLink preamble

Create `agents/dispatch/termlink-preamble.md` with different output instructions.

- **Pro:** Clean separation of dispatch mechanisms
- **Con:** Two preambles to maintain, easy to use the wrong one
- **Con:** The existing preamble's context explosion prevention doesn't apply to TermLink (no shared context)

## Recommendation

**GO — Option A (primary) + Option C (defense-in-depth)**

### Primary fix: TermLink workers write to target files directly

When dispatching via TermLink, the orchestrator should:
1. Specify the target output path in the dispatch prompt (e.g., `docs/reports/T-816-null-object-fallback.md`)
2. NOT include the `/tmp/fw-agent-*` preamble for TermLink workers
3. Instruct the worker to `git add` the output file before exiting (optional — parent can commit)

**Implementation:** Update `agents/dispatch/preamble.md` with a "TermLink workers" section:

```markdown
## TermLink Workers — Different Output Rules

TermLink workers are NOT sub-agents. They run in independent processes with their
own context budget. The /tmp/ convention does NOT apply.

For TermLink dispatch:
1. Write output directly to the TARGET file (the orchestrator specifies it)
2. The target file should be in the git repo (docs/reports/, .context/, etc.)
3. Run `git add <target-file>` after writing (optional, helps if parent can't)
4. Your final message to the orchestrator should still be ≤ 5 lines
```

### Defense-in-depth: Handover orphan check

Add to `agents/handover/handover.sh`:
```bash
# Check for orphaned TermLink worker outputs
ORPHANS=$(find /tmp -name "fw-agent-*.md" -newer "$SESSION_START_FILE" 2>/dev/null | wc -l)
if [ "$ORPHANS" -gt 0 ]; then
    echo "WARNING: $ORPHANS orphaned worker output(s) in /tmp/fw-agent-*.md" >> "$HANDOVER_FILE"
    find /tmp -name "fw-agent-*.md" -newer "$SESSION_START_FILE" -exec basename {} \; >> "$HANDOVER_FILE"
fi
```

### Scope

- Update preamble: 10 lines added
- Handover check: 5 lines added
- No code architecture changes, no new dependencies
- Backward compatible (Task tool agents keep using `/tmp/`)

## Evidence

- T-816 incident: 307 lines of analysis lost to `/tmp/`, recovered manually
- T-817 same session: integrated successfully because it completed before budget critical
- 53 TermLink sessions currently registered — this pattern will grow with adoption
