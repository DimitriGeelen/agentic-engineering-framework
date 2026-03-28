# T-585: Skills Token Budget Management — Dynamic Prompt Compression

## Problem Statement

CLAUDE.md + memory files + settings consume prompt tokens at session start. After compaction, this is a significant fraction of the effective working context. As the framework grows (more skills, more CLAUDE.md sections), the overhead increases.

**OpenClaw reference:** At 150 skills, implemented `applySkillsPromptLimits()`: try full format, switch to compact (saves ~80%), binary-search largest prefix that fits. Budget cap 30K chars. Three-tier: bundled (always) > managed (if relevant) > workspace (if in scope).

## Current Prompt Overhead Measurement

| Component | Bytes | Estimated Tokens |
|-----------|-------|-----------------|
| CLAUDE.md | 53,655 | ~13K |
| Memory files (9 files) | 13,001 | ~3K |
| settings.json | 2,493 | ~0.6K |
| System prompt (Claude Code) | ~10K+ | ~3K+ |
| Skills (deferred tools list) | ~2K | ~0.5K |
| **Total at session start** | **~80K** | **~20K** |

**Context window:** 200K tokens (observed, T-596)
**Prompt overhead as % of context:** ~10% (20K / 200K)

## Key Finding: The Problem Is Smaller Than Expected

At 20K tokens, the prompt overhead is significant but not critical:
- 200K context × 10% = 20K overhead → 180K working context
- This is manageable with current budget-gate.sh monitoring
- OpenClaw hit the problem at 150 skills → our skill set is much smaller (deferred tools)

**However:** CLAUDE.md has grown continuously from ~5K tokens at project start to ~13K tokens now. If this trend continues, it will become a real problem. The framework has no mechanism to detect or respond to this growth.

## What Could Help

### Short-term: CLAUDE.md Size Monitoring

Add a check to `fw doctor` or audit: warn if CLAUDE.md exceeds a threshold (e.g., 60K bytes / 15K tokens). This detects the problem before it becomes acute.

**Effort:** ~20 LOC in audit.sh. Zero architectural impact.

### Medium-term: Section Relevance Tagging

Tag CLAUDE.md sections with relevance conditions. During startup, include full text for relevant sections, compact summaries for others.

```markdown
<!-- relevance: always -->
## Core Principle
...

<!-- relevance: workflow_type=inception -->
### Inception Discipline
...

<!-- relevance: has_termlink -->
## TermLink Integration
...
```

**Effort:** ~1 session to add tags + build a relevance filter. Requires changes to how CLAUDE.md is loaded (currently auto-loaded by Claude Code — we don't control the loading mechanism).

**Blocker:** Claude Code loads CLAUDE.md automatically. We can't filter sections pre-load. This only works if we move content from CLAUDE.md to skill files that are loaded on-demand.

### Long-term: Skill-Based CLAUDE.md Decomposition

Move sections from CLAUDE.md to individual skill files. Skills are deferred until invoked. This moves ~60% of CLAUDE.md content out of the base prompt.

**Effort:** Major refactoring (~3 sessions). Changes the fundamental structure of the framework's Claude Code integration.

## Recommendation: NO-GO on Full Implementation / GO on Monitoring

1. **GO: Add CLAUDE.md size monitoring** to audit — warn when approaching 60K bytes. Minimal effort, catches the trend.
2. **NO-GO on dynamic compression** — Claude Code loads CLAUDE.md automatically; we don't control the loading pipeline. OpenClaw's approach requires framework-controlled prompt assembly, which we don't have.
3. **DEFER: Skill decomposition** — when CLAUDE.md hits the size threshold, decompose into skill files. This is a natural evolution but not needed yet.

## Go/No-Go Assessment

**Partial GO:** Size monitoring (trivial, high value).
**NO-GO on compression:** Claude Code's auto-loading prevents section-level filtering.
**DEFER:** Skill decomposition for when the problem becomes acute.

## Dialogue Log

- Measured actual prompt overhead: ~20K tokens (10% of 200K context)
- Compared against OpenClaw's 150-skill threshold
- Key blocker identified: Claude Code auto-loads CLAUDE.md, no filtering possible
