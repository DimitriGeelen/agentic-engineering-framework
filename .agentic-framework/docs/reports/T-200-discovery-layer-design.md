# T-200: Discovery Layer Design — Research Artifact

**Date:** 2026-02-22
**Participants:** Human + Claude (dialogue)
**Phase:** T-194 Phase 4 (follow-up inception)
**Prerequisite:** T-194 Phases 1-3 (risk landscape, control register, OE tests)

## Problem Statement

The framework has three assurance layers designed in T-194:
1. **Layer 1 (Hooks):** Real-time enforcement during sessions (11 blocking controls)
2. **Layer 2 (OE Tests):** Periodic verification that controls are working (20/23 automatable)
3. **Layer 3 (Discovery):** Pattern detection, omission finding, insight surfacing — **NOT YET DESIGNED**

Layer 3 is where the framework moves from "are controls working?" to "what are we missing?" This is the antifragility layer — it finds things no single check can see by analyzing patterns across time.

## Prior Art (from T-194 genesis discussion)

### Omission Detection Examples
| Discovery | Example |
|-----------|---------|
| Tasks stuck too long | T-190 "started-work" for 10h with 0 updates |
| Decisions made without dialogue | T-151 captured→completed in 2 min with owner: human |
| Specs completed without human review | Specification tasks completed by agent without human interaction |
| Stale handovers with unfilled TODOs | LATEST.md has `[TODO]` sections |
| Growing gaps register without action | G-004 "watching" for days with no trigger |
| Commits bunching (budget pressure) | 5 commits in 10 minutes = agent rushing |

### Insight Generation Examples
| Insight | Example |
|---------|---------|
| Pattern emerging across tasks | Same error type hit 3+ times → candidate for practice |
| Velocity change | Tasks taking 2x longer than average |
| Task quality degrading | Descriptions getting shorter, ACs vaguer over time |
| Agent bypassing governance | Bypass log growing, `--force` usage increasing |

## Data Sources Available

| Source | Volume | What it reveals |
|--------|--------|-----------------|
| Cron audits | 234 YAML files | Compliance trends over time |
| Episodic memory | 235 files | Task outcomes, patterns, decisions |
| Completed tasks | 230 files | Work patterns, lifecycle metrics |
| Active tasks | 6 files | Current state, stuck detection |
| Git history | 550+ commits | Velocity, commit patterns, bypasses |
| Risks register | 38 risks | Open risk tracking |
| Controls register | 23 controls | Control effectiveness |
| Issues register | 8 incidents | Resolution patterns |
| Learnings | 58+ entries | Knowledge accumulation |
| Patterns | 14+ entries | Failure/success patterns |
| Gaps register | 2 watching | Spec-reality drift |
| Bypass log | Variable | Governance circumvention |

## Research Questions

1. What discovery capabilities provide the highest value-to-effort ratio?
2. How should discoveries surface to the human? (cron reports? session-start? web UI? all three?)
3. What temporal analysis requires looking across audit history vs point-in-time?
4. Should discoveries be prescriptive ("fix this") or observational ("look at this")?
5. What's the right frequency for each discovery type?
6. How do we avoid false positives that erode trust?

## Phase 1a: Discovery Capability Catalog

### What Already Exists (to avoid redundancy)

Watchtower `rules.py` already has 10 point-in-time checks:
- `check_stale_tasks` — tasks not updated in N days
- `check_unresolved_healing` — tasks stuck in "issues"
- `check_traceability_drift` — commits without task refs
- `check_audit_regression` — audit results worsening
- `check_gap_triggers` — gap trigger conditions met
- `check_novel_failures` — new failure types
- `check_graduation_candidates` — learnings ready for promotion
- `check_dead_letter_practices` — practices with no evidence
- `check_pattern_consolidation` — similar patterns to merge
- `check_escalation_advancement` — patterns at step threshold
- `check_mitigation_ineffectiveness` — mitigations that didn't work

**These are all point-in-time.** The discovery layer adds **temporal analysis** — patterns only visible across multiple data points over time.

### Candidate Discoveries

Scored: Value (1-5, how much the human cares) x Feasibility (1-5, how easy to implement with existing data).

| # | Name | Type | Description | Data Source | Value | Feasibility | Score | Redundant? |
|---|------|------|-------------|-------------|-------|-------------|-------|------------|
| D1 | **Episodic quality decay** | Omission | 135/234 episodics (58%) have [TODO] placeholders — detect when new completions produce stale episodics | episodic YAML files | 5 | 5 | 25 | No |
| D2 | **Human review queue aging** | Omission | 4 tasks waiting on human ACs, oldest 32h. Alert when human review items age past threshold | active tasks with owner:human | 4 | 5 | 20 | Partial (stale_tasks checks all, not human-specific) |
| D3 | **Commit velocity anomalies** | Insight | 19-153 commits/day range. Detect unusual spikes (agent rushing) or drops (agent stuck) | git log | 4 | 4 | 16 | No |
| D4 | **Audit trend regression** | Trend | Track warn/fail counts across cron audits over time — detect upward trends | cron audit YAML history | 4 | 5 | 20 | Partial (audit_regression is point-in-time) |
| D5 | **Task lifecycle anomalies** | Insight | Detect tasks that go captured→completed in <5 min (T-151 pattern — agent overreach) | task files (created vs date_finished) | 5 | 4 | 20 | No |
| D6 | **Completion velocity trends** | Trend | 7-45 tasks/day range. Detect sustained drops (systemic issue) vs normal variation | completed task dates | 3 | 5 | 15 | No |
| D7 | **Commit bunching detection** | Omission | 5+ commits in 10 minutes = budget pressure signal | git log timestamps | 4 | 4 | 16 | No |
| D8 | **Handover quality decay** | Omission | Detect handovers with unfilled [TODO] sections (pre-compact skeletons) | handover files | 4 | 5 | 20 | No |
| D9 | **Control effectiveness drift** | Trend | Track which controls fire (warn/block) over time — detect controls that never fire (dead) or always fire (too sensitive) | audit + OE data | 3 | 3 | 9 | No |
| D10 | **Decision-without-dialogue** | Omission | Tasks with owner:human + workflow_type:specification/inception completed without human AC checks | task files + git timestamps | 5 | 3 | 15 | No |
| D11 | **Gap register staleness** | Omission | Gaps in "watching" status for >7 days with no trigger check | gaps.yaml dates | 3 | 5 | 15 | Partial (gap_triggers) |
| D12 | **Bypass log growth** | Trend | Track --no-verify usage and bypass log entries over time | bypass-log.yaml + git | 3 | 4 | 12 | No |

### Priority Ranking (by score)

1. **D1 (25)** — Episodic quality decay — **highest signal, immediate value**
2. **D2 (20)** — Human review queue aging
3. **D4 (20)** — Audit trend regression
4. **D5 (20)** — Task lifecycle anomalies (T-151 pattern)
5. **D8 (20)** — Handover quality decay
6. **D3 (16)** — Commit velocity anomalies
7. **D7 (16)** — Commit bunching detection
8. **D6 (15)** — Completion velocity trends
9. **D10 (15)** — Decision-without-dialogue
10. **D11 (15)** — Gap register staleness
11. **D12 (12)** — Bypass log growth
12. **D9 (9)** — Control effectiveness drift

### Real Data Validation

Evidence that these discoveries would have caught real problems:

- **D1 (episodic decay):** 58% stale NOW — this has been invisible for weeks
- **D5 (lifecycle anomaly):** T-151 went captured→completed in 2 min — triggered the entire T-194 assurance model inception
- **D8 (handover decay):** LATEST.md (S-2026-0222-0011) had all [TODO] sections — just fixed this session
- **D7 (commit bunching):** Feb 18 had 153 commits — clear pressure signal
- **D2 (review queue):** T-227 human ACs pending since Feb 21 13:20 — 34h and counting
- **D10 (decision-without-dialogue):** T-151 is the canonical example, but untested whether it has recurred

### Classification

| Type | Candidates | Cron frequency |
|------|-----------|----------------|
| **Omission detection** | D1, D2, D7, D8, D10 | Every 30 min (fast) |
| **Trend analysis** | D4, D6, D9, D12 | Daily (needs history) |
| **Insight generation** | D3, D5, D11 | Hourly (moderate) |

## Phase 1a-ext: Temporal Infrastructure Gap Analysis

Two sub-agent investigations conducted in parallel. Full reports at:
- `/tmp/fw-agent-discovery-data.md` — Framework data mining (10 analyses)
- `/tmp/fw-agent-discovery-gaps.md` — Audit infrastructure gap analysis (10 gaps)

### Current State Snapshot (from data mining agent)

| Metric | Value | Signal |
|--------|-------|--------|
| Active tasks | 6 (2 started-work, 4 work-completed) | Healthy WIP |
| Stale task | T-220 (last update Feb 20, >48h) | Needs attention |
| Human review queue | 4 tasks, oldest 34h (T-227) | Potential bottleneck |
| Commit frequency | 19-153/day (avg ~72) | High variance |
| Completion velocity | 7-45/day (avg ~25), declining | Downward trend |
| Episodic quality | 135/234 (58%) have [TODO] | Major quality gap |
| Task sizing | Nearly all <1h creation-to-completion | Well-sized |
| Bypass log | Empty | Clean compliance |
| Audit health | 0 failures, warnings trending 2→0 | Healthy |
| Gaps tracked | 13 (G-001 through G-013) | Active register |

### Existing Temporal Mechanisms (6 partial, all insufficient)

| Mechanism | Location | What it does | Limitation |
|-----------|----------|-------------|------------|
| Trend analysis | audit.sh:1820 | Counts recurring WARN/FAIL across past audits | Binary recurrence only, no directionality |
| Audit regression | rules.py:195 | Two-point comparison (current vs previous) | Only N vs N-1, no moving average |
| Compute delta | scanner.py:297 | Two-point scan delta (task counts) | Never stored, not a time series |
| Velocity | scanner.py:400 | Single tasks-per-week scalar | No trend, no comparison |
| Cron schedule | /etc/cron.d/agentic-audit | Generates data every 15-30 min | Nothing aggregates across time |
| metrics.sh | Framework CLI | Point-in-time snapshot | No persistence, no delta |

**Core finding: Strong point-in-time compliance, zero temporal intelligence.** Data exists (234 cron files, 230 tasks, 550+ commits) but nothing aggregates, trends, or surfaces cross-time patterns.

### Temporal Infrastructure Gaps (from gap analysis agent)

| Gap | Severity | Summary |
|-----|----------|---------|
| GAP-T1 | **High** | No time-series storage — audit files are isolated islands |
| GAP-T2 | **High** | No trend direction detection — cannot distinguish resolving vs emerging issues |
| GAP-T7 | **High** | No session-start surfacing — resume/context agents blind to trends |
| GAP-T3 | Medium | No velocity trend — single scalar, no acceleration/deceleration |
| GAP-T4 | Medium | No lead time/cycle time computation despite timestamps existing |
| GAP-T5 | Medium | No cross-check correlation — related symptoms appear as separate findings |
| GAP-T6 | Medium | No normalized health score — only raw pass/warn/fail counts |
| GAP-T8 | Medium | No visual trend display in Watchtower — snapshot tables only |
| GAP-T9 | Low | No graduated issue aging / SLA tracking |
| GAP-T10 | Low | No meta-audit to detect silently broken checks |

### Gap-to-Discovery Mapping

| Gap | Addressed by Discovery |
|-----|----------------------|
| GAP-T1 (no time-series) | Foundation for D4, D6, D9, D12 |
| GAP-T2 (no direction) | D4 (audit trends), D6 (velocity trends) |
| GAP-T3 (no velocity trend) | D6 (completion velocity trends) |
| GAP-T4 (no cycle time) | D5 (lifecycle anomalies) |
| GAP-T5 (no correlation) | D3+D7 (commit patterns correlate with budget pressure) |
| GAP-T6 (no health score) | Could be added as D13 (composite health index) |
| GAP-T7 (no session surfacing) | Surfacing model design (Phase 2) |
| GAP-T8 (no charts) | Watchtower integration (build task) |
| GAP-T9 (no aging) | D2 (human review queue aging) |
| GAP-T10 (no meta-audit) | D9 (control effectiveness drift) |

### Additional Data Findings

**OE daily/weekly tiers not scheduled:** T-194 Phase 3 designed OE-daily (18 checks) and OE-weekly tiers, but they only exist in audit.sh code — not actually being run on schedule. The cron job runs `oe-fast,oe-research` only. This is a separate gap (not discovery layer, but OE infrastructure).

**13 gaps tracked (not 2):** The gaps register has G-001 through G-013. The handover only mentioned 2 "watching" — the rest have different statuses (closed, accepted-risk, etc.).

## Phase 2: Surfacing Model Design

Designed during T-241 implementation. Three surfacing channels:

### Channel 1: Session-Start Injection (T-241)
- `post-compact-resume.sh` reads `LATEST.yaml`, filters WARN/FAIL only
- Injects 2-3 line summary into session context on resume/compact
- `resume.sh` shows "Discovery Findings" section in `cmd_status()` with colored severity

### Channel 2: Watchtower Discoveries Page (T-241)
- New blueprint `web/blueprints/discoveries.py` at `:3000/discoveries`
- 4 summary cards, inline SVG sparkline charts from `metrics-history.yaml`
- Color-coded findings table with severity badges (green/yellow/red)

### Channel 3: Cron Output (T-240)
- Discovery findings written to `.context/audits/discoveries/LATEST.yaml`
- Structured YAML: id, level (PASS/WARN/FAIL), check description, mitigation
- Summary counts (pass/warn/fail/total) for quick parsing

### False-Positive Mitigation Strategy
- **Severity levels:** INFO (logged only), WARN (surfaced), FAIL (surfaced + priority action)
- **Only WARN/FAIL surfaced at session-start** — INFO suppressed to avoid noise
- **Per-discovery thresholds:** D1 episodic quality >5% = WARN, >15% = FAIL; D2 human review >48h = WARN, >72h = FAIL; D3 velocity <0.3x or >3x = WARN; D5 lifecycle <5min = flag; D7 bunching 5+ commits in 10min; D8 handover >0 TODOs = WARN
- **Known FP source:** D5 (lifecycle anomalies) flags legitimate fast human admin tasks at ~50% FP rate. Needs refinement: filter by `workflow_type` or add `owner: human` + `<5min` as expected pattern
- **Acknowledgment/suppression:** Not yet implemented. Repeat findings show every cron cycle. Future: add `acknowledged_findings:` list to suppress known-acceptable items

## Phase 3: Technical Spike Results

Spikes exceeded scope — went from "prototype 2-3" to "implement 8 production discoveries."

### Runtime Measurement (2026-02-22)
```
All 7 discovery jobs (discovery + discovery-trends sections):
  real  1.702s
  user  0.856s
  sys   1.088s
```
**Result: 1.7s — well under 5s target.** Runs via cron every 15-30 min without issues.

### False Positive Assessment (2026-02-22)
| Discovery | Current FP Rate | Notes |
|-----------|----------------|-------|
| D1 (episodic quality) | ~0% | Clean — [TODO] detection is precise after T-239 comment fix |
| D2 (human review queue) | ~0% | Threshold-based, clear signal |
| D3 (commit velocity) | Low | Ratio-based (0.3x-3x band), appropriate sensitivity |
| D4 (audit trends) | N/A | Insufficient history yet (<3 entries) |
| D5 (lifecycle anomalies) | ~50% | Flags legitimate human admin tasks — needs refinement |
| D7 (commit bunching) | Low | INFO level only, not surfaced |
| D8 (handover quality) | ~0% | [TODO] detection is binary, accurate |

**Aggregate: ~7/8 findings are true positives.** D5 is the outlier. Overall FP rate well under 20% excluding D5. D5 alone exceeds threshold — flagged for refinement.

### Accuracy by Type
- **Omission detection (D1, D2, D8):** High accuracy, low FP
- **Trend analysis (D4):** Not yet evaluable (needs history accumulation)
- **Insight generation (D3, D5, D7):** D3/D7 good, D5 needs tuning

## Phase 4: Decision Synthesis

### Architecture Delivered
```
Cron (every 15-30 min)
  └→ audit.sh --section discovery,discovery-trends
      ├→ D1-D8 discovery jobs (bash, <2s total)
      ├→ Writes .context/audits/discoveries/LATEST.yaml
      └→ Writes .context/audits/cron/*.yaml

Session Start
  └→ post-compact-resume.sh / resume.sh
      └→ Reads LATEST.yaml, shows WARN/FAIL only

Watchtower
  └→ /discoveries page
      ├→ Summary cards + sparkline charts
      └→ Color-coded findings table
```

### Build Tasks Completed
| Task | Deliverable | Status |
|------|------------|--------|
| T-238 | Time-series storage (metrics-history.yaml) | Completed |
| T-239 | Episodic decay + omission discovery jobs (D1, D2, D5, D8) | Completed |
| T-240 | Audit trends + velocity discovery jobs (D3, D4, D7) | Completed |
| T-241 | 3 surfacing channels (session-start, Watchtower, cron) | Completed |

### Remaining Discoveries (not yet built)
5 of 12 cataloged discoveries were not implemented. Need backlog tasks:

| Discovery | Score | Why Deferred |
|-----------|-------|-------------|
| D6 (completion velocity trends) | 15 | Overlaps with D3; lower priority |
| D9 (control effectiveness drift) | 9 | Lowest score; needs longer history |
| D10 (decision-without-dialogue) | 15 | T-151 pattern; needs task+git correlation |
| D11 (gap register staleness) | 15 | Partially covered by existing gap trigger checks |
| D12 (bypass log growth) | 12 | Bypass log currently empty; low signal |

## Dialogue Log

Dialogue occurred across multiple sessions but was not captured contemporaneously (C-001 violation — acknowledged). Key decisions reconstructed from git history and task files:

### 2026-02-21 — Phase 1 discovery catalog
- Human reviewed 12 candidates, agreed with Value x Feasibility scoring
- Course correction: human prioritized D1 (episodic decay) as immediate proof-of-value
- Decision: implement top 8 discoveries (D1-D5, D7, D8 + D4 trends), defer D6/D9-D12

### 2026-02-21 — GO decision
- Evidence presented: 12 capabilities cataloged, 10 temporal infrastructure gaps found, 58% episodic decay validates D1
- Human approved GO with build task decomposition into T-238/239/240/241

### 2026-02-22 — Surfacing model review
- Human verified Watchtower discoveries page at :3000/discoveries
- Human verified session-start injection (concise, actionable)
- Both channels approved via T-241 human AC sign-off