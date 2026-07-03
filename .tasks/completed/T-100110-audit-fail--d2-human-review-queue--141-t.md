---
id: T-100110
name: "Audit FAIL — D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(..."
description: >
  Audit FAIL — D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(...

status: work-completed
workflow_type: build
audit_severity: fail
audit_finding_hash: 70092a0aad44cf4f2c4e7f20ee9d728aa5da9ef6
tags: [audit-finding, severity:fail, section:audit]
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-07-03T11:04:01Z
last_update: 2026-07-03T16:06:19Z
date_finished: 2026-07-03T16:06:19Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
---

# T-100110: Audit FAIL — D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(...
## Trigger

Audit run: 2026-07-03T11:04:01Z
Finding: D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(32d) T-1707(37d) T-1718(37d) T-1773(50d) T-1774(50d) T-1775(50d) T-1776(33d) T-1792(51d) T-1794(51d) T-1795(51d) T-1796(51d) T-1797(51d) T-1799(51d) T-1801(51d) T-1802(51d) T-1803(51d) T-1805(50d) T-1806(50d) T-1807(50d) T-1808(50d) T-1810(50d) T-1811(50d) T-1818(50d) T-1827(42d) T-1834(49d) T-1842(42d) T-1843(42d) T-1844(42d) T-1891(46d) T-1909(43d) T-1910(43d) T-1911(43d) T-1928(44d) T-1929(44d) T-1930(44d) T-1933(44d) T-1934(43d) T-1935(43d) T-1936(43d) T-1939(43d) T-1947(44d) T-1951(42d) T-1954(43d) T-1955(43d) T-1957(43d) T-1960(42d) T-1961(42d) T-1963(42d) T-1964(43d) T-1965(43d) T-1968(43d) T-1969(43d) T-1970(43d) T-1971(43d) T-1976(42d) T-1977(42d) T-1978(42d) T-1980(42d) T-1982(42d) T-1984(42d) T-1985(42d) T-1988(41d) T-1989(38d) T-1990(37d) T-1991(41d) T-1992(38d) T-1993(38d) T-1994(37d) T-1999(41d) T-2002(37d) T-2003(38d) T-2004(38d) T-2006(38d) T-2008(38d) T-2009(38d) T-2010(38d) T-2011(38d) T-2012(38d) T-2013(38d) T-2015(38d) T-2016(38d) T-2017(38d) T-2018(38d) T-2019(38d) T-2020(38d) T-2021(38d) T-2022(38d) T-2023(38d) T-2024(38d) T-2025(38d) T-2026(38d) T-2027(38d) T-2028(38d) T-2029(38d) T-2031(38d) T-2033(38d) T-2034(38d) T-2038(38d) T-2039(38d) T-2040(38d) T-2041(38d) T-2043(38d) T-2044(38d) T-2045(38d) T-2046(38d) T-2047(38d) T-2049(38d) T-2051(37d) T-2054(37d) T-2062(35d) T-2063(35d) T-2064(35d) T-2065(35d) T-2066(35d) T-2075(35d) T-2077(35d) T-2080(35d) T-2082(35d) T-2084(35d) T-2085(35d) T-2086(35d) T-2087(35d) T-2088(35d) T-2089(35d) T-2102(33d) T-2103(34d) T-2106(34d) T-2110(33d) T-2111(33d) T-2112(33d) T-2114(33d) T-2116(33d) T-2117(33d) T-2119(27d) T-2136(33d) T-2160(32d) T-2167(31d) T-2174(30d) T-2175(30d) T-2176(27d) T-2179(30d) T-2183(19d) T-2185(29d) T-2192(30d) T-2222(27d) T-2240(25d) T-2265(24d) T-2274(24d) T-2278(24d) T-2281(24d) T-2332(21d) T-2336(21d) T-2342(21d) T-2369(19d) T-2373(19d) T-2376(19d) T-2403(18d) T-2406(17d)

## Finding

```
D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(32d) T-1707(37d) T-1718(37d) T-1773(50d) T-1774(50d) T-1775(50d) T-1776(33d) T-1792(51d) T-1794(51d) T-1795(51d) T-1796(51d) T-1797(51d) T-1799(51d) T-1801(51d) T-1802(51d) T-1803(51d) T-1805(50d) T-1806(50d) T-1807(50d) T-1808(50d) T-1810(50d) T-1811(50d) T-1818(50d) T-1827(42d) T-1834(49d) T-1842(42d) T-1843(42d) T-1844(42d) T-1891(46d) T-1909(43d) T-1910(43d) T-1911(43d) T-1928(44d) T-1929(44d) T-1930(44d) T-1933(44d) T-1934(43d) T-1935(43d) T-1936(43d) T-1939(43d) T-1947(44d) T-1951(42d) T-1954(43d) T-1955(43d) T-1957(43d) T-1960(42d) T-1961(42d) T-1963(42d) T-1964(43d) T-1965(43d) T-1968(43d) T-1969(43d) T-1970(43d) T-1971(43d) T-1976(42d) T-1977(42d) T-1978(42d) T-1980(42d) T-1982(42d) T-1984(42d) T-1985(42d) T-1988(41d) T-1989(38d) T-1990(37d) T-1991(41d) T-1992(38d) T-1993(38d) T-1994(37d) T-1999(41d) T-2002(37d) T-2003(38d) T-2004(38d) T-2006(38d) T-2008(38d) T-2009(38d) T-2010(38d) T-2011(38d) T-2012(38d) T-2013(38d) T-2015(38d) T-2016(38d) T-2017(38d) T-2018(38d) T-2019(38d) T-2020(38d) T-2021(38d) T-2022(38d) T-2023(38d) T-2024(38d) T-2025(38d) T-2026(38d) T-2027(38d) T-2028(38d) T-2029(38d) T-2031(38d) T-2033(38d) T-2034(38d) T-2038(38d) T-2039(38d) T-2040(38d) T-2041(38d) T-2043(38d) T-2044(38d) T-2045(38d) T-2046(38d) T-2047(38d) T-2049(38d) T-2051(37d) T-2054(37d) T-2062(35d) T-2063(35d) T-2064(35d) T-2065(35d) T-2066(35d) T-2075(35d) T-2077(35d) T-2080(35d) T-2082(35d) T-2084(35d) T-2085(35d) T-2086(35d) T-2087(35d) T-2088(35d) T-2089(35d) T-2102(33d) T-2103(34d) T-2106(34d) T-2110(33d) T-2111(33d) T-2112(33d) T-2114(33d) T-2116(33d) T-2117(33d) T-2119(27d) T-2136(33d) T-2160(32d) T-2167(31d) T-2174(30d) T-2175(30d) T-2176(27d) T-2179(30d) T-2183(19d) T-2185(29d) T-2192(30d) T-2222(27d) T-2240(25d) T-2265(24d) T-2274(24d) T-2278(24d) T-2281(24d) T-2332(21d) T-2336(21d) T-2342(21d) T-2369(19d) T-2373(19d) T-2376(19d) T-2403(18d) T-2406(17d)
```

Mitigation: Review with: fw task verify (lists unchecked Human ACs)

## RCA

**Symptom:** D2 FAIL flagged 141 tasks in human review queue >30 days.

**Root cause:** DUPLICATE of T-100086. Same 141-task backlog, same finding - organizational capacity issue (human review bandwidth lower than task completion rate). Already documented in T-100086 with recommendation for human to batch-process via /approvals or `fw review-queue`.

**Why structurally allowed:** Audit ran multiple times and emitted duplicate findings with different hashes. No detector for duplicate audit findings across runs.

**Prevention:** Not applicable - T-100086 already covers this finding class. Future: audit could dedupe by finding text before emitting tasks.

## Acceptance Criteria

### Agent
- [x] Root cause identified: DUPLICATE of T-100086
- [x] Documented in RCA section
- [x] No fix needed - T-100086 is canonical task for this finding

## Verification

# Re-run audit - finding should be absent
bin/fw audit 2>&1 | grep -q "D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(32d) T-1707(37d) T-1718(37d) T-1773(50d) T-1774(50d) T-1775(50d) T-1776(33d) T-1792(51d) T-1794(51d) T-1795(51d) T-1796(51d) T-1797(51d) T-1799(51d) T-1801(51d) T-1802(51d) T-1803(51d) T-1805(50d) T-1806(50d) T-1807(50d) T-1808(50d) T-1810(50d) T-1811(50d) T-1818(50d) T-1827(42d) T-1834(49d) T-1842(42d) T-1843(42d) T-1844(42d) T-1891(46d) T-1909(43d) T-1910(43d) T-1911(43d) T-1928(44d) T-1929(44d) T-1930(44d) T-1933(44d) T-1934(43d) T-1935(43d) T-1936(43d) T-1939(43d) T-1947(44d) T-1951(42d) T-1954(43d) T-1955(43d) T-1957(43d) T-1960(42d) T-1961(42d) T-1963(42d) T-1964(43d) T-1965(43d) T-1968(43d) T-1969(43d) T-1970(43d) T-1971(43d) T-1976(42d) T-1977(42d) T-1978(42d) T-1980(42d) T-1982(42d) T-1984(42d) T-1985(42d) T-1988(41d) T-1989(38d) T-1990(37d) T-1991(41d) T-1992(38d) T-1993(38d) T-1994(37d) T-1999(41d) T-2002(37d) T-2003(38d) T-2004(38d) T-2006(38d) T-2008(38d) T-2009(38d) T-2010(38d) T-2011(38d) T-2012(38d) T-2013(38d) T-2015(38d) T-2016(38d) T-2017(38d) T-2018(38d) T-2019(38d) T-2020(38d) T-2021(38d) T-2022(38d) T-2023(38d) T-2024(38d) T-2025(38d) T-2026(38d) T-2027(38d) T-2028(38d) T-2029(38d) T-2031(38d) T-2033(38d) T-2034(38d) T-2038(38d) T-2039(38d) T-2040(38d) T-2041(38d) T-2043(38d) T-2044(38d) T-2045(38d) T-2046(38d) T-2047(38d) T-2049(38d) T-2051(37d) T-2054(37d) T-2062(35d) T-2063(35d) T-2064(35d) T-2065(35d) T-2066(35d) T-2075(35d) T-2077(35d) T-2080(35d) T-2082(35d) T-2084(35d) T-2085(35d) T-2086(35d) T-2087(35d) T-2088(35d) T-2089(35d) T-2102(33d) T-2103(34d) T-2106(34d) T-2110(33d) T-2111(33d) T-2112(33d) T-2114(33d) T-2116(33d) T-2117(33d) T-2119(27d) T-2136(33d) T-2160(32d) T-2167(31d) T-2174(30d) T-2175(30d) T-2176(27d) T-2179(30d) T-2183(19d) T-2185(29d) T-2192(30d) T-2222(27d) T-2240(25d) T-2265(24d) T-2274(24d) T-2278(24d) T-2281(24d) T-2332(21d) T-2336(21d) T-2342(21d) T-2369(19d) T-2373(19d) T-2376(19d) T-2403(18d) T-2406(17d)" && exit 1 || exit 0

## Updates

### 2026-07-03T11:04:01Z — audit-emit-task [audit-agent]
- **Action:** Created by audit --emit-tasks
- **Finding:** fail: D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(32d) T-1707(37d) T-1718(37d) T
- **Context:** Auto-generated task for audit finding hash 70092a0aad44cf4f2c4e7f20ee9d728aa5da9ef6


## Reviewer Verdict (v1.5)

- **Scan ID:** R-d585330e
- **Timestamp:** 2026-07-03T16:06:21Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `bin/fw audit 2>&1 | grep -q "D2: Human review queue — 141 task(s) waiting >30d: T-1701(37d) T-1702(32d) T-1707(37d) T-1718(37d) T-1773(50d) T-1774(50d) T-1775(50d) T-1776(33d) T-1792(51d) T-1794(51d) `

### 2026-07-03T16:06:19Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
