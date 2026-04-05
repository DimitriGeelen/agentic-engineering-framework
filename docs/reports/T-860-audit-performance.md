# T-860: Audit Performance Research

## Research Artifact (C-001)

**Task:** T-860
**Created:** 2026-04-05
**Status:** Complete

---

## Measurement

**Actual runtime:** 3m56s (vs 90s stated in task — worse than expected)
- `real 3m55.991s`
- `user 1m21.156s`
- `sys 4m8.449s`

High `sys` time (4m8s > real 3m56s due to forking overhead) confirms the problem is process spawning, not computation.

## Root Cause Analysis

### Process spawning overhead

`audit.sh` (3274 lines) contains:
- **10 separate loops** iterating over task files
- **21 python3 invocations** (each ~50ms startup = ~1s just for Python startup)
- Multiple `grep`, `sed`, `head`, `wc` calls per iteration

### Loop inventory

| Loop | Line | Iterates over | Estimated iterations |
|------|------|--------------|---------------------|
| 1 | 615 | active/*.md | 132 |
| 2 | 690 | active/*.md | 132 |
| 3 | 1059 | completed/*.md | 740 |
| 4 | 1432 | completed/*.md | 740 |
| 5 | 1494 | active/*.md | 132 |
| 6 | 1790 | active + completed | 872 |
| 7 | 1856 | completed/*.md | 740 |
| 8 | 1901 | recent completed | ~50 |
| 9 | 1971 | active/T-*.md | 132 |
| 10 | 2063 | active/T-*.md | 132 |

**Total iterations: ~3802** — each spawning 2-5 subprocesses (grep, sed, etc.).
At ~5ms per subprocess, that's ~19s just for subshell overhead. The rest is I/O wait (reading 872 files repeatedly).

### Python embedded blocks

Several audit sections use Python heredocs for complex parsing (YAML validation, episodic analysis, pattern matching). Each `python3 -c` or `python3 - << 'EOF'` has ~50ms startup overhead.

## Options

### Option A: Merge loops (medium effort, ~60% speedup)
Combine the 10 loops into 2-3 passes (one over active, one over completed). Each pass extracts all needed data in a single read. Most loops extract 2-3 fields from frontmatter — this can be done in one `grep | sed` pipeline.

**Estimate:** 3802 iterations → ~1000 iterations. ~60% reduction.

### Option B: Single Python pass (high effort, ~90% speedup)
Replace the entire audit with a Python script that:
1. Reads all task files once into memory
2. Parses YAML frontmatter once per file
3. Runs all checks against in-memory data
4. Outputs results

**Estimate:** 3m56s → ~20-30s. One Python startup, one pass, no subprocess spawning.

### Option C: Cached task index (medium effort, ~70% speedup)
Build a task index file (`.context/working/task-index.json`) that caches frontmatter from all tasks. Regenerated on task create/update/complete. Audit reads index instead of parsing files.

**Estimate:** Index read <100ms. Checks run against cached data. ~70% reduction.
**Risk:** Index staleness if tasks are modified outside `fw task update`.

### Option D: Fast audit mode for cron (low effort, immediate)
Add `fw audit --fast` that skips expensive checks (completed task analysis, pattern matching, episodic coverage). Cron uses `--fast`, manual audit runs full.

**Estimate:** Skip loops 3, 4, 6, 7 (completed task iterations) → ~2130 iterations eliminated. ~55% reduction.
**Risk:** Reduced coverage in automated audits.

## Recommendation

**GO — Option D first (immediate relief), then Option A (structural fix)**

### Rationale
1. Option D is ~10 lines of code — skip 4 expensive loops behind `--fast` flag. Cron gets it immediately.
2. Option A can be done incrementally — merge one loop pair at a time, test after each.
3. Option B is the right long-term answer but requires rewriting 3274 lines.
4. Option C adds a caching layer that creates staleness risk.

### Phase plan
- **Phase 1 (30 min):** Add `--fast` flag, cron uses it. Immediate relief.
- **Phase 2 (2 hours):** Merge 10 loops into 3. Active-pass, completed-pass, cross-cutting-pass.
- **Phase 3 (future):** Consider full Python rewrite if still >30s after Phase 2.

### Evidence
- 3m56s actual measurement (reproducible)
- `sys 4m8s` confirms subprocess spawning is dominant cost
- 3802 loop iterations × 2-5 subprocesses each = thousands of fork+exec
- Cron runs every 15 minutes — a 4-minute audit blocks other cron jobs
