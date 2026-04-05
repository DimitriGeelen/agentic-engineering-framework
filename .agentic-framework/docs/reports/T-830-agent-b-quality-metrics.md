# T-830: Quality Metrics Design — Measurable Indicators & Instrumentation Plan

## Purpose

Design concrete, automatically-capturable metrics to evaluate whether proactive `/clear` (context reset at 100K tokens) improves agent output quality compared to natural sessions (run until budget gate at 190K).

## Data Sources Inventory

Before designing metrics, here's what the framework already captures per session:

| Source | Location | Data Available |
|--------|----------|----------------|
| JSONL transcript | `~/.claude/projects/<project>/*.jsonl` | Every API turn: tool calls, results, errors, token usage, timestamps |
| Handover frontmatter | `.context/handovers/*.md` | session_id, token_usage, token_input/output/cache, tasks_active/touched/completed |
| Budget status | `.context/working/.budget-status` | JSON: level (ok/warn/urgent/critical), tokens, timestamp |
| Edit counter | `.context/working/.edit-counter` | Source file edits since last commit (reset by post-commit hook) |
| Tool counter | `.context/working/.tool-counter` | Tool calls since last commit (reset by checkpoint.sh) |
| Loop detector | `.context/working/.loop-detect.json` | Recent tool call history (30 entries), pattern detection state |
| Compact log | `.context/working/.compact-log` | Timestamps of all handovers/compactions |
| Budget gate counter | `.context/working/.budget-gate-counter` | Number of budget-gate invocations this session |
| Session state | `.context/working/session.yaml` | Session ID, start time, active tasks, tasks touched |
| Metrics history | `.context/project/metrics-history.yaml` | Daily: pass/warn/fail, velocity, traceability %, episodic quality % |
| `fw costs session` | `lib/costs.sh` | Per-session: turns, input/cache_read/cache_create/output tokens |

### Baseline from Real Data (13 sessions, largest = 8,158 turns)

From the largest session (mega-session, 67.5MB JSONL):
- **277 commits** across 8,158 turns = **0.034 commits/turn**
- **369 tool errors** out of 5,047 tool calls = **7.3% error rate**
- **126 files** edited 3+ times (potential retries)
- **First commit at turn 42** (42 turns of setup/orientation)
- **Median turns between commits:** ~25 turns

---

## Metric Definitions

### Category A: Efficiency Metrics

#### A1. Commits Per Turn (CPT)
- **What it measures:** Productive output density — how much committed work per unit of agent activity.
- **Data source:** JSONL transcript. Count `Bash` tool calls where `command` contains `git commit`. Divide by total assistant turns.
- **Extraction:** `grep -c 'git commit' + count assistant entries` in JSONL (Python one-liner, already proven in costs.sh pattern).
- **Storage:** Handover frontmatter field: `commits_per_turn: 0.034`
- **Baseline:** 0.034 from mega-session. Short sessions (< 100 turns) have 0.00-0.07 range.
- **Threshold:** < 0.01 is unproductive (spinning). > 0.05 is highly efficient. Normal range: 0.02-0.04.
- **Why it matters for A/B:** If /clear breaks momentum, CPT drops post-clear. If stale context causes churn, CPT drops in late-session natural runs.

#### A2. Tasks Completed Per 100 Turns (TC100)
- **What it measures:** Goal-oriented productivity, not just code output.
- **Data source:** JSONL transcript. Count `Bash` calls containing `--status work-completed`. Normalize to per-100-turns.
- **Extraction:** Regex on JSONL Bash commands. Cross-check with `session.yaml` `tasks_completed` field.
- **Storage:** Handover frontmatter field: `tasks_completed_per_100_turns: 1.2`
- **Baseline:** From session.yaml `tasks_touched` vs turns. Typical: 0.5-2.0 tasks per 100 turns.
- **Threshold:** < 0.3 = low productivity. > 2.0 = high throughput (likely small tasks).
- **Why it matters:** /clear sessions may complete fewer tasks (overhead) but at higher quality (fewer rework cycles).

#### A3. First Commit Turn Number (FCT)
- **What it measures:** Session startup efficiency. How many turns are spent on orientation before productive work begins.
- **Data source:** JSONL transcript. Find first `git commit` Bash call, record the assistant turn number.
- **Extraction:** Sequential scan of JSONL until first commit.
- **Storage:** Handover frontmatter field: `first_commit_turn: 42`
- **Baseline:** 42 turns in mega-session. Expected: 15-30 for natural resume, 5-15 for /clear with good handover.
- **Threshold:** > 50 = poor session start. < 15 = excellent. > 80 = something is wrong.
- **Why it matters for A/B:** /clear sessions SHOULD have lower FCT (clean context, focused handover injection). If FCT is higher post-clear, handover fidelity is the problem.

#### A4. Productive Turns Ratio (PTR)
- **What it measures:** Fraction of turns that involve Write/Edit/Bash (productive) vs Read/Grep/Glob (research) vs no tool call (conversation).
- **Data source:** JSONL transcript. Classify each assistant turn by tool calls used.
- **Extraction:** For each assistant turn, check tool_use blocks. Classify as: `productive` (Write, Edit, Bash with non-git command), `research` (Read, Grep, Glob, Agent), `meta` (Bash with git/fw command), `conversation` (no tool use).
- **Storage:** Handover frontmatter field: `productive_turns_ratio: 0.45`
- **Baseline:** From mega-session tool distribution: ~48% Bash (mixed productive/meta), ~20% Read, ~12% Edit. Estimated 40-50% truly productive.
- **Threshold:** < 0.25 = too much research/spinning. > 0.60 = high productivity.
- **Why it matters for A/B:** Fresh context should increase PTR by reducing research turns (less need to re-read files already understood).

---

### Category B: Quality Signals

#### B1. Failed Tool Calls (FTC)
- **What it measures:** Agent confusion — failed tool calls indicate the agent is trying operations that don't work.
- **Data source:** JSONL transcript. Count `tool_result` blocks where `is_error: true`.
- **Extraction:** Direct JSON field check per entry.
- **Storage:** Handover frontmatter field: `failed_tool_calls: 369`
- **Baseline:** 7.3% error rate in mega-session (369/5047). Short sessions: 0-12%.
- **Threshold:** > 10% = degraded quality. > 15% = serious issues. < 5% = clean execution.
- **Why it matters for A/B:** The key hypothesis: FTC rate increases with context age. If /clear resets this, it proves stale context causes confusion.

#### B2. Edit Retry Rate (ERR)
- **What it measures:** Files edited 3+ times — a proxy for "getting it wrong and fixing it."
- **Data source:** JSONL transcript. Count Write/Edit tool calls per unique `file_path`. Flag files with 3+ edits.
- **Extraction:** Counter per file_path across all Write/Edit tool calls in session.
- **Storage:** Handover frontmatter field: `edit_retry_files: 12` (count of files with 3+ edits)
- **Baseline:** 126 files in mega-session (8,158 turns). Normalized: ~1.5 retry-files per 100 turns. But many are legitimate (fw, CLAUDE.md = iterative files). Need to exclude `.context/`, `.tasks/`, `CLAUDE.md` from counting.
- **Threshold:** > 3 retried source files per 100 turns = quality concern. Framework/config files excluded.
- **Nuance:** Some files legitimately get many edits (bin/fw = 37 edits across a mega-session is normal evolution). The signal is in SOURCE files being edited 3+ times within a SHORT window (e.g., 20 turns).

#### B3. Verification Gate Failures (VGF)
- **What it measures:** Tasks where the agent's work didn't pass verification on first attempt.
- **Data source:** JSONL transcript. Look for `fw task update` + `--status work-completed` Bash calls followed by error output containing "BLOCKED" or non-zero exit.
- **Extraction:** Scan Bash tool results for verification failure patterns.
- **Storage:** Handover frontmatter field: `verification_failures: 2`
- **Baseline:** Not currently tracked. Estimated 10-20% of task completions fail verification first try.
- **Threshold:** > 30% = quality problem. < 10% = good.

#### B4. Same-File Edit Burst (SEB)
- **What it measures:** Rapid re-editing of the same file within a short turn window — the clearest signal of "trying and failing."
- **Data source:** JSONL transcript. For each file, find consecutive Edit/Write calls within a 10-turn window.
- **Extraction:** Sliding window analysis: for each Edit/Write, check if the same file was edited within the previous 10 turns.
- **Storage:** Handover frontmatter field: `edit_bursts: 5` (number of burst incidents)
- **Baseline:** Needs measurement. Expected: 2-5 per 100 turns in normal sessions.
- **Threshold:** > 8 per 100 turns = quality degradation.
- **Why it matters for A/B:** This is the most direct quality signal. If stale context causes the agent to write wrong code, it will edit-retry within a tight window.

---

### Category C: Context Health

#### C1. Loop Detector Triggers (LDT)
- **What it measures:** Repetitive tool call patterns detected by the PostToolUse loop detector.
- **Data source:** `.context/working/.loop-detect.json` (current session state). Also detectable from JSONL by replaying the detection algorithm.
- **Extraction:** Count loop detector warnings/blocks from JSONL (look for `loop_detect` in stderr output or additionalContext).
- **Storage:** Handover frontmatter field: `loop_triggers: 0`
- **Baseline:** Rare in normal operation. The detector has warning (5 repeats) and critical (10 repeats) thresholds.
- **Threshold:** > 0 = noteworthy. > 3 per session = context health problem.
- **Why it matters for A/B:** Loop triggers should correlate with context age. More loops in late-session = evidence for /clear.

#### C2. Budget Gate Blocks (BGB)
- **What it measures:** How many times the budget gate blocked a tool call — the hardest enforcement of context exhaustion.
- **Data source:** `.context/working/.budget-gate-counter` (tracks invocations). Also `.budget-status` for current level.
- **Extraction:** Read counter value at session end.
- **Storage:** Handover frontmatter field: `budget_gate_blocks: 0`
- **Baseline:** 0 for healthy sessions. Non-zero means session hit critical budget.
- **Threshold:** > 0 = session exceeded safe context window.
- **Why it matters for A/B:** Group A (natural) will have more blocks by design. But the metric matters because blocks mean work was ATTEMPTED that couldn't be completed.

#### C3. Human Corrections (HC)
- **What it measures:** How often the human redirects or corrects the agent's approach.
- **Data source:** JSONL transcript. Count `user` type entries that contain correction signals.
- **Extraction:** Heuristic: Count user messages containing negative/correction patterns: "no", "don't", "stop", "wrong", "not that", "instead", "I said", "that's not". Requires NLP classification — start with keyword matching.
- **Storage:** Handover frontmatter field: `human_corrections: 3`
- **Baseline:** Highly variable. Typical: 1-5 per 100 turns of active interaction.
- **Threshold:** > 5 per 100 interactive turns = agent quality concern.
- **Limitation:** Noisy metric. "no" could be in code context. Best supplemented by manual tagging.

#### C4. Context Utilization at Commit (CUC)
- **What it measures:** What percentage of the context window is used when each commit happens.
- **Data source:** JSONL transcript. For each commit turn, find the nearest `usage.input_tokens` reading.
- **Extraction:** Match commit turns to token usage readings (already tracked in JSONL `usage` blocks).
- **Storage:** Per-commit data too granular for frontmatter. Store as summary: `avg_context_at_commit: 145000`
- **Baseline:** Unknown. Expected: commits cluster at all context levels for mega-sessions, lower levels for /clear sessions.
- **Threshold:** Average > 170K = committing under pressure (bad). Average < 100K = healthy headroom.
- **Why it matters for A/B:** /clear sessions should have lower CUC (commits happen with more headroom).

---

### Category D: Session Shape

#### D1. Turn Distribution by Context Phase
- **What it measures:** How many productive turns happen at each context level.
- **Data source:** JSONL transcript. For each turn, correlate with the most recent token reading.
- **Extraction:** Bucket turns into phases: 0-25% (0-50K), 25-50% (50-100K), 50-75% (100-150K), 75-100% (150-200K). Count productive turns per phase.
- **Storage:** Handover frontmatter fields: `turns_phase_0_25: 15, turns_phase_25_50: 40, turns_phase_50_75: 80, turns_phase_75_100: 65`
- **Baseline:** Mega-sessions: most turns at 75-100% (context fills fast, stays full). /clear sessions: more turns at 0-50%.
- **Why it matters for A/B:** If quality degrades at high context, we should see higher FTC and ERR rates in the 75-100% phase.

#### D2. Error Rate by Context Phase (ERCP)
- **What it measures:** The correlation between context fullness and error rate — the smoking gun for quality degradation.
- **Data source:** JSONL transcript. Cross-reference D1 phase buckets with B1 (failed tool calls).
- **Extraction:** For each phase bucket, calculate FTC rate (errors / total tool calls in that phase).
- **Storage:** Handover frontmatter or separate YAML: `error_rate_phase_0_25: 0.03, error_rate_phase_75_100: 0.12`
- **Baseline:** Unknown — this is the key experiment measurement.
- **Threshold:** If error_rate_phase_75_100 > 2x error_rate_phase_0_25, that's strong evidence context age degrades quality.
- **This is the most important metric for the A/B experiment.**

---

## Instrumentation Plan

### Phase 1: Capture Infrastructure (build task)

Add a post-session metrics extraction script: `agents/context/session-metrics.sh`

**What it does:**
1. Reads the current session's JSONL transcript (same `find_transcript` pattern as checkpoint.sh)
2. Runs a single Python pass extracting ALL metrics (A1-D2)
3. Writes results to `.context/working/.session-metrics.yaml`
4. Handover agent reads this file and injects fields into frontmatter

**Implementation sketch:**

```bash
#!/bin/bash
# session-metrics.sh — Extract quality metrics from JSONL transcript
# Called by: handover.sh (before writing frontmatter)
# Output: .context/working/.session-metrics.yaml

TRANSCRIPT=$(find_transcript)  # reuse checkpoint.sh pattern
python3 << 'PYEOF' "$TRANSCRIPT"
import sys, json, os, re
from collections import Counter, defaultdict

transcript = sys.argv[1]
# ... single-pass JSONL analysis ...
# Output YAML with all metrics
PYEOF
```

**Why a separate script (not inline in handover.sh):**
- Handover.sh is already 720 lines — separation of concerns
- Metrics extraction can be called independently (e.g., mid-session health check)
- Script can be tested in isolation

### Phase 2: Handover Integration

Add these fields to handover frontmatter (handover.sh Step 1.8 area):

```yaml
# Efficiency (Category A)
commits_per_turn: 0.034
tasks_completed_per_100_turns: 1.2
first_commit_turn: 42
productive_turns_ratio: 0.45

# Quality (Category B)
failed_tool_calls: 369
failed_tool_call_rate: 0.073
edit_retry_files: 12
edit_bursts: 5
verification_failures: 2

# Context health (Category C)
loop_triggers: 0
budget_gate_blocks: 0
human_corrections: 3
avg_context_at_commit: 145000

# Session shape (Category D)
turns_phase_0_25: 15
turns_phase_25_50: 40
turns_phase_50_75: 80
turns_phase_75_100: 65
error_rate_phase_0_25: 0.03
error_rate_phase_75_100: 0.12

# Experiment metadata
session_clear_policy: "natural"  # or "proactive-100K"
```

### Phase 3: Timeline Visualization

Add metrics to the `/timeline` Watchtower page:
- Per-session card shows: CPT, FTC rate, edit retries, first commit turn
- Trend line across sessions for each metric
- Color coding: green (good), yellow (warning), red (threshold exceeded)

### Phase 4: A/B Automation

Add to session init:
- `FW_CLEAR_POLICY=natural|proactive-100K` env var
- checkpoint.sh triggers `/clear` at 100K when policy is `proactive-100K`
- Handover captures which policy was active

---

## A/B Experiment Design

### Groups

| Group | Policy | Trigger |
|-------|--------|---------|
| A (Control) | Natural | Run until budget gate fires at 190K |
| B (Treatment) | Proactive /clear | Clear at 100K tokens, resume with handover |

### Sample Size

Statistical power analysis for detecting a meaningful difference:
- **Primary metric:** Failed tool call rate (FTC rate)
- **Baseline FTC rate:** ~7% (from mega-session)
- **Minimum detectable effect:** 30% relative reduction (7% -> 5%)
- **Significance level:** alpha = 0.05
- **Power:** 0.80
- **Required sample size:** ~15 sessions per group (30 total)

Rationale: With 7% baseline error rate and expecting /clear to reduce it to ~5%, a two-proportion z-test needs ~15 sessions per group at 80% power. However, sessions vary enormously in length (17 to 8,158 turns), so we should:
- Normalize metrics per-100-turns
- Exclude sessions < 50 turns (too short for meaningful measurement)
- Aim for 10 sessions per group minimum, 15 ideal
- Run for 4-6 weeks to accumulate sufficient sessions

### Duration Estimate

Current session creation rate: ~13 sessions exist for this project (some are very short).
Assuming 2-3 substantive sessions per day:
- **Minimum (10/group):** 7-10 days (alternating natural/proactive)
- **Ideal (15/group):** 10-15 days
- **With session length filtering:** 3-4 weeks

### Assignment Protocol

Alternating assignment (not random — too few sessions for randomization to balance):
- Odd-numbered sessions: Group A (natural)
- Even-numbered sessions: Group B (proactive /clear at 100K)
- Session number tracked in `session.yaml`

### Primary Endpoints

1. **Failed tool call rate** (B1) — The headline metric
2. **Edit burst count** (B4) — Direct quality signal
3. **Commits per turn** (A1) — Efficiency tradeoff
4. **Error rate by context phase** (D2) — Mechanism confirmation

### Secondary Endpoints

5. First commit turn (A3) — Startup overhead
6. Productive turns ratio (A4) — Flow impact
7. Human corrections (C3) — Subjective quality proxy
8. Loop triggers (C1) — Repetition impact

### Success Criteria

The experiment is a GO for proactive /clear if:
- FTC rate in Group B is >= 20% lower than Group A (primary)
- AND edit burst count in Group B is lower (quality confirmation)
- AND commits per turn in Group B is not > 30% lower (acceptable efficiency cost)

The experiment is NO-GO if:
- FTC rate difference < 10% (not enough quality improvement to justify overhead)
- OR commits per turn drops > 50% (too much productivity loss)

---

## Implementation Priority

| Priority | Metric | Effort | Value | Dependency |
|----------|--------|--------|-------|------------|
| P0 | A1 (commits/turn), A3 (first commit) | Low | High | JSONL only |
| P0 | B1 (failed tool calls) | Low | Critical | JSONL only |
| P0 | B4 (edit bursts) | Medium | Critical | JSONL only |
| P1 | A2 (tasks/100 turns), A4 (productive ratio) | Low | Medium | JSONL only |
| P1 | D1/D2 (phase distribution, error by phase) | Medium | Critical | JSONL + token correlation |
| P2 | B2 (edit retry files), B3 (verification failures) | Low | Medium | JSONL only |
| P2 | C1-C4 (context health) | Medium | Medium | Mixed sources |
| P3 | Handover frontmatter integration | Medium | High | session-metrics.sh ready |
| P3 | Timeline visualization | High | High | All metrics captured |

**Recommended build order:**
1. `session-metrics.sh` script extracting P0 metrics from JSONL (1 task)
2. Handover integration — inject metrics into frontmatter (1 task)
3. Add D2 (error rate by context phase) — this is the mechanism confirmation (1 task)
4. `/timeline` visualization (1 task, depends on data being captured)
5. A/B automation in checkpoint.sh (1 task, after baseline established)

---

## Appendix: Extraction Code Sketch

```python
"""
Single-pass JSONL analyzer for session quality metrics.
Called by session-metrics.sh, outputs YAML.
"""
import sys, json, os, re
from collections import Counter, defaultdict

def analyze_session(transcript_path):
    metrics = {
        'turns': 0, 'tool_calls': 0, 'tool_errors': 0,
        'commits': 0, 'first_commit_turn': None,
        'edits_per_file': Counter(), 'edit_bursts': 0,
        'phase_turns': {k: 0 for k in ['0_25', '25_50', '50_75', '75_100']},
        'phase_errors': {k: 0 for k in ['0_25', '25_50', '50_75', '75_100']},
        'phase_tools': {k: 0 for k in ['0_25', '25_50', '50_75', '75_100']},
        'productive_turns': 0, 'research_turns': 0,
        'recent_file_edits': [],  # (turn, filepath) for burst detection
        'last_token_reading': 0,
        'context_at_commits': [],
    }

    with open(transcript_path) as f:
        for line in f:
            try:
                entry = json.loads(line)
            except:
                continue

            msg = entry.get('message', {})
            if not isinstance(msg, dict):
                continue

            # Track token readings
            usage = msg.get('usage')
            if usage and 'input_tokens' in usage:
                model = msg.get('model', '')
                if not model.startswith('<'):
                    metrics['last_token_reading'] = (
                        usage['input_tokens']
                        + usage.get('cache_read_input_tokens', 0)
                        + usage.get('cache_creation_input_tokens', 0)
                    )

            content = msg.get('content', [])
            if not isinstance(content, list):
                continue

            role = msg.get('role', '')
            if role == 'assistant':
                metrics['turns'] += 1

            turn_has_productive = False
            turn_has_research = False

            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get('type', '')

                if btype == 'tool_use':
                    metrics['tool_calls'] += 1
                    name = block.get('name', '')
                    inp = block.get('input', {})

                    # Classify tool as productive or research
                    if name in ('Write', 'Edit'):
                        turn_has_productive = True
                        fp = inp.get('file_path', '')
                        metrics['edits_per_file'][fp] += 1
                        metrics['recent_file_edits'].append(
                            (metrics['turns'], fp))
                    elif name == 'Bash':
                        cmd = inp.get('command', '')
                        if 'git commit' in cmd:
                            metrics['commits'] += 1
                            if metrics['first_commit_turn'] is None:
                                metrics['first_commit_turn'] = metrics['turns']
                            metrics['context_at_commits'].append(
                                metrics['last_token_reading'])
                        elif cmd.startswith(('git ', 'fw ')):
                            pass  # meta
                        else:
                            turn_has_productive = True
                    elif name in ('Read', 'Grep', 'Glob', 'Agent'):
                        turn_has_research = True

                    # Phase tracking
                    tokens = metrics['last_token_reading']
                    pct = tokens * 100 // 200000 if tokens > 0 else 0
                    if pct < 25: phase = '0_25'
                    elif pct < 50: phase = '25_50'
                    elif pct < 75: phase = '50_75'
                    else: phase = '75_100'
                    metrics['phase_tools'][phase] += 1

                elif btype == 'tool_result' and block.get('is_error'):
                    metrics['tool_errors'] += 1
                    # Phase error tracking
                    tokens = metrics['last_token_reading']
                    pct = tokens * 100 // 200000 if tokens > 0 else 0
                    if pct < 25: phase = '0_25'
                    elif pct < 50: phase = '25_50'
                    elif pct < 75: phase = '50_75'
                    else: phase = '75_100'
                    metrics['phase_errors'][phase] += 1

            if turn_has_productive:
                metrics['productive_turns'] += 1
            elif turn_has_research:
                metrics['research_turns'] += 1

    # Post-processing: edit burst detection (same file within 10 turns)
    edits = metrics['recent_file_edits']
    bursts = 0
    for i, (turn_i, fp_i) in enumerate(edits):
        for j in range(max(0, i-20), i):
            turn_j, fp_j = edits[j]
            if fp_j == fp_i and turn_i - turn_j <= 10:
                bursts += 1
                break
    metrics['edit_bursts'] = bursts

    return metrics
```

This sketch processes a 67MB JSONL file in a single pass (~2-3 seconds). Production version would output YAML.
