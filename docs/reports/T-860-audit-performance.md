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

## Value Analysis: What Each Loop Actually Catches

Before optimizing, we need to know which checks are load-bearing. Analysis of ~50 cron audit snapshots (2026-03-28 through 2026-04-06):

### Loop-by-loop value assessment

| Loop | Purpose | Warnings fired? | Acted on? | Value verdict |
|------|---------|-----------------|-----------|---------------|
| 1 (L615) | Active task structure validation | **0 warnings** in sample | N/A | **Low-yield** — tasks are valid by construction (create-task.sh enforces format). Safety net, rarely fires. |
| 2 (L690) | Active task quality (desc length, staleness, ACs) | 28 warnings (T-807 short desc, T-548 stale) | **Not acted on** — same warnings persist across all 50 snapshots | **Low-yield** — warnings are noise if nobody acts on them. May indicate thresholds are miscalibrated. |
| 3 (L1059) | Episodic coverage for completed tasks | 33 warnings (T-936/937/938, T-754–759) | **Yes — explicitly fixed** (T-949, earlier sessions) | **High-yield** — catches real gaps, agent acts on them. 740 completed task iterations. |
| 4 (L1432) | Research artifacts for completed inceptions | 3 warnings (T-567/568/569 missing artifacts) | **Yes — fixed in T-941** | **High-yield** — catches real C-001 compliance gaps. But only fires for inception tasks (~10% of completed). |
| 5 (L1494) | C-001: Research artifacts for active inceptions | 26 warnings (T-837 missing reference) | **Yes — fixed in T-941** | **High-yield** — most frequently fired warning. Active feedback loop. |
| 6 (L1790) | CTL-009: Inception commit gate tracking | **0 warnings** | N/A | **Deterrent value** — the check's existence enforces behavior. Removing it would remove the deterrent. |
| 7 (L1856) | CTL-012: Unchecked ACs in completed tasks | 4 warnings (T-534, T-451) | **Structural signal** — flags tasks that bypassed completion gate | **High-yield** — catches governance leaks. Iterates 740 completed tasks. |
| 8 (L1901) | CTL-013: Verification re-run (3 most recent) | **0 warnings** | N/A | **Environmental drift detector** — only 3 iterations, minimal cost, high value when it fires. |
| 9 (L1971) | CTL-025: Partial-complete ownership | **0 warnings** | N/A | **Safety net** — validates human/agent AC split. Low cost (active only). |
| 10 (L2063) | D2: Human review queue aging | 14 warnings + D5 lifecycle + D10 dialogue | **Awareness signal** — surfaces to human in cron output | **High-yield** — primary mechanism for human to notice aging review queue. |

### Key findings

1. **Loops 3, 4, 7 iterate over 740 completed tasks** — these are the expensive ones. But loops 3 and 7 catch real issues that get fixed. Loop 4 only applies to inception tasks (small subset).

2. **Loop 2 fires warnings nobody acts on** — "short description" and "stale task" warnings persist for weeks. This is either (a) the thresholds are wrong, or (b) these warnings need a different escalation path. Either way, the current loop isn't driving behavior change.

3. **Loops 1, 6, 8, 9 rarely fire but serve as deterrents/safety nets** — their value is in *existing*, not in *finding things*. These are cheap (active-only iterations) and should not be cut.

4. **The "never fires" loops are cheap** — Loops 1, 6, 8, 9 iterate over active tasks only (132 iterations each) or 3 items. Total: ~400 iterations. Not worth optimizing.

5. **The expensive loops (3, 4, 7) are also the most valuable** — they iterate over 740 completed tasks but catch real compliance gaps. A `--fast` flag that skips these would skip the checks that actually catch things.

### Revised risk assessment of Option D (--fast flag)

The original proposal said: "skip completed task analysis (loops 3, 4, 6, 7)."

**Problem:** Loops 3, 4, 7 are the loops that actually catch real issues (missing episodics, missing research artifacts, bypassed AC gates). Skipping them saves ~2200 iterations but creates a blind spot for exactly the compliance issues the audit exists to detect.

**Safe to skip in --fast:** Loop 2 (quality warnings nobody acts on — 132 iterations, saves little). Loop 1 structure checks (rarely fires, but also cheap).

**Not safe to skip:** Loops 3, 4, 7 (catch real issues), Loop 10/D2 (human awareness).

### What actually needs to happen

The expensive loops (3, 4, 7) iterate over 740 completed tasks to check simple things (file exists, grep for unchecked AC). The cost isn't the check — it's reading 740 files in a bash loop with subprocess spawning. The right fix is making completed-task iteration cheaper, not skipping it.

## Recommendation

**GO — but revised approach: Phase 1 is loop merge (Option A), not --fast flag (Option D)**

### Rationale
The original recommendation (Option D first — `--fast` flag) would skip the very checks that catch real issues. Value analysis of 50 audit snapshots shows loops 3, 4, 7 (completed task analysis) are the most actionable checks in the audit — they've driven 6+ real fixes. Skipping them for speed defeats the purpose.

The right fix is making the expensive iterations cheaper (merge loops, reduce subprocess spawning), not removing them.

### Revised phase plan
- **Phase 1 (2-3 hours):** Merge loops — combine the 4 completed-task loops (3, 4, 6, 7) into a single pass that reads each file once and extracts all needed data. Similarly merge active-task loops (1, 2, 5, 9, 10) into one pass. Target: 10 loops → 3 passes (active, completed, cross-cutting).
- **Phase 2 (1 hour):** Fix Loop 2 noise — either recalibrate thresholds (description length, staleness) so warnings are actionable, or escalate stale warnings to the human review queue instead of repeating in every audit.
- **Phase 3 (future):** Consider Python single-pass if still >60s after Phase 1.

### What NOT to do
- Do NOT add `--fast` flag that skips completed-task loops — those are the highest-value checks
- Do NOT remove Loop 6 (inception commit gate) even though it never fires — it's a deterrent

### Evidence
- 3m56s actual measurement (reproducible)
- `sys 4m8s` confirms subprocess spawning is dominant cost
- 3802 loop iterations × 2-5 subprocesses each = thousands of fork+exec
- Cron runs every 15 minutes — a 4-minute audit blocks other cron jobs
- **Value data (50 audit snapshots):** Loops 3/4/5/7 produced warnings that were acted on 6+ times. Loop 2 produced warnings that persisted for weeks without action.
