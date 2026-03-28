# Resume Agent

## Purpose

Recovers context after compaction or session breaks. Synthesizes current state from multiple sources into actionable guidance.

## When to Use

**Always use after:**
- Context compaction (conversation got too long)
- Returning from a break
- Starting a new session (complement to reading handover)
- Feeling lost about current state

**Commands:**

| Command | Use When |
|---------|----------|
| `status` | Full state synthesis — use after compaction |
| `sync` | Working memory is stale — update from actual task state |
| `quick` | Need one-line summary |

## How It Works

The resume agent reads from multiple sources and synthesizes:

1. **Handover** (`.context/handovers/LATEST.md`)
   - "Where We Are" summary
   - Suggested first action

2. **Working Memory** (`session.yaml`, `focus.yaml`)
   - Current session ID
   - Current focus task
   - May be stale — use `sync` to fix

3. **Git State**
   - Uncommitted changes
   - Recent commits
   - Current branch

4. **Task State** (`.tasks/active/`)
   - Active tasks with status
   - Cross-referenced with focus

## Post-Compaction Protocol

After context compaction, run:

```bash
# 1. See where you are
./agents/resume/resume.sh status

# 2. Fix stale working memory
./agents/resume/resume.sh sync

# 3. Set focus if needed
./agents/context/context.sh focus T-XXX
```

## Integration with Other Agents

| Agent | Resume Complements By |
|-------|----------------------|
| Handover | Handover captures end state; Resume synthesizes current state |
| Context | Context manages memory; Resume reads and presents it |
| Audit | Audit checks compliance; Resume shows actionable state |

## Recommendations Logic

The agent provides recommendations based on:
- If no active tasks → suggest creating one
- If focus is set → suggest continuing that task
- If no focus but tasks exist → suggest setting focus
- If uncommitted changes → remind to commit

## Quick Reference

```bash
# Full synthesis (use after compaction)
./agents/resume/resume.sh status

# Fix stale working memory
./agents/resume/resume.sh sync

# One-line summary
./agents/resume/resume.sh quick
```
