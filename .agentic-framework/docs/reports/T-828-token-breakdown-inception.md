# T-828: Input/Output Token Breakdown — Research Artifact

## Problem Statement

The timeline and handover frontmatter currently store a single `token_usage` string (e.g., "809.7M tokens, 6608 turns") — cumulative totals with no input/output differentiation. Since pricing varies ~50x across token categories (cache read at $0.30/MTok vs output at $15/MTok), the current aggregate hides the most actionable cost signal.

## Current State

### What we have
- **Handover frontmatter**: `token_usage: "809.7M tokens, 6608 turns"` — single string, cumulative
- **lib/costs.sh**: Already parses JSONL transcripts into 4 categories per session:
  - `input_tokens` (fresh input)
  - `cache_read` (cache hits — 10x cheaper)
  - `cache_create` (cache population)
  - `output_tokens` (5x more expensive)
- **handover.sh** (line 300-308): Already calls `costs_main current` and extracts Total/Turns/CacheHit — but only writes the single `token_usage` string to frontmatter

### What the timeline shows (T-826/T-827)
- Per-session delta (computed from consecutive cumulative totals)
- Cumulative total in parentheses
- No category breakdown

## Analysis

### Option A: Enrich handover frontmatter with breakdown fields

Add new fields to handover YAML frontmatter:
```yaml
token_usage: "809.7M tokens, 6608 turns"
token_input: 57200
token_cache_read: 800500000
token_cache_create: 14100000
token_output: 1100000
```

**Effort:** LOW
- handover.sh: Extract 4 more fields from `costs_main current` output (~8 lines)
- timeline.py: Read new fields, compute per-session deltas per category (~15 lines)
- timeline.html: Display breakdown (badge or tooltip) (~5 lines)

**Pros:** Self-contained in handover files, no runtime JSONL parsing needed
**Cons:** Only affects new sessions — historical handovers won't have the fields (graceful fallback needed)

### Option B: Timeline reads JSONL directly

Have timeline.py parse JSONL transcripts like `lib/costs.sh` does.

**Effort:** MEDIUM-HIGH
- Port Python JSONL parsing logic to timeline.py or import from shared module
- Session ID matching between handover files and JSONL filenames
- Performance concern: JSONL files are 0.1-67MB each, scanning all is slow

**Pros:** Works for historical sessions, no schema change
**Cons:** Slow at scale (67MB files), duplicates costs.sh logic, couples timeline to transcript storage

### Option C: Store breakdown in a separate costs YAML per session

Write `costs/S-XXXX.yaml` alongside handovers with full breakdown.

**Effort:** MEDIUM
- New file format, new directory
- handover.sh writes YAML after computing costs
- timeline.py reads from costs directory

**Pros:** Clean separation, extensible
**Cons:** Another file to maintain, overkill for 4 numbers

## Recommendation

**GO — Option A** (enrich handover frontmatter)

- Lowest effort (~30 lines across 3 files)
- Data source already available in handover.sh (it already calls `costs_main current`)
- Natural extension of existing `token_usage` field
- Graceful degradation: historical sessions show total-only, new sessions show breakdown
- Timeline already has delta computation logic (T-827) — extend to per-category deltas

### Implementation Plan
1. **handover.sh**: Extract input/cache_read/cache_create/output from `costs_main current` output, write as numeric frontmatter fields
2. **timeline.py**: Read new fields, compute per-session deltas per category, pass to template
3. **timeline.html**: Show breakdown as tooltip or secondary badges (input/output/cache)
4. **Fallback**: If fields missing (old handovers), show total-only as today

### Display suggestion
- Primary badge: per-session total (as now)
- Hover/tooltip: "Input: 2.1M | Cache: 35.2M | Output: 0.2M"
- Or small secondary text under the badge

## Assumptions
1. `costs_main current` output format is stable (it's framework-internal)
2. Numeric token counts fit in YAML integer fields (max observed: 800M — fine)
3. Timeline rendering won't be slowed by 4 extra fields per session
