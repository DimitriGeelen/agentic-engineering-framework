# T-432: SKIP Refactoring Reassessment — Research Artifact

## Problem Statement

T-411 identified 64 refactoring findings, of which 27 scored ≤4 ("SKIP"). After 3 months of active development and 650+ tasks, reassess: which SKIPs are moot, which upgraded, and which deserve reconsideration?

## Reassessment Results

### Summary
| Status | Count | Findings |
|--------|-------|----------|
| MOOT (no longer exists) | 8 | S9, J7, P5, H5, H6, A1, A4, A10 |
| UPGRADED (fixed by other work) | 2 | J5, A1 |
| STILL RELEVANT (unchanged) | 14 | S11, S12, S14, J8-J12, P2, P6, P10, P12, P13 |
| LOW PRIORITY (template patterns) | 3 | H8, H9, H12-H14 |

### Moot Findings (8) — No Action Needed
- **S9** (Python inline templates in shell): Pattern no longer exists
- **J7** (hardcoded hex colors in JS): Colors managed via CSS, no JS hex codes found
- **P5** (handover parsing duplication): Refactored into shared.py wrapper (T-403/T-420)
- **H5** (page header macro): Headers inlined, insufficient duplication for macro
- **H6** (data table macro): Only 1 instance — no duplication to consolidate
- **A1** (scanner load_yaml wrapper): Already delegates to shared.py
- **A4** (stale backup file): File no longer exists
- **A10** (directives.yaml drift): Currently matches CLAUDE.md exactly

### Upgraded Findings (2) — Fixed by Other Work
- **J5** (missing abort/cleanup): AbortController implemented in utils.js streamSSE()
- **A1** (scanner wrapper): load_yaml delegated to web.shared

### Still Relevant Findings — Reassessment

| Finding | Orig. Score | New Score | Change | Rationale |
|---------|:-----------:|:---------:|--------|-----------|
| S11: mkdir -p inconsistency | 5 | 5 | = | 64 files, still inconsistent |
| S12: shopt nullglob (5 files) | 2 | 2 | = | Still 5-6 files, low impact |
| S14: help text formatting | 3 | 3 | = | Still inconsistent across 20+ locations |
| J8: repeated DOM queries | 2 | 2 | = | 4 files, low impact |
| J9: naming convention | 3 | 3 | = | Mixed camelCase/snake_case |
| J10: null checks | 4 | 3 | ↓ | Less severe than estimated |
| J11: magic numbers | 4 | 4 | = | Still scattered |
| J12: addEventListener inline | 2 | 2 | = | 5 instances, no cleanup |
| P2: logger naming | 3 | 3 | = | 11 files, inconsistent |
| P6: task globbing no cache | 3 | 4 | ↑ | More blueprints now (16 files glob) |
| P10: Python magic numbers | 4 | 4 | = | Timeouts, retries not configured |
| P12: regex not precompiled | 1 | 1 | = | Performance non-issue |
| P13: error context inconsistency | 4 | 4 | = | Exception handlers vary |
| H8: htmx boilerplate | 3 | 4 | ↑ | 190 hx-attributes across 29 templates |

**Score changes:**
- P6 upgraded 3→4 (more glob callers now)
- H8 upgraded 3→4 (htmx usage grew significantly)
- J10 downgraded 4→3 (less severe than estimated)

**No findings crossed the ≥7 "DO" threshold.** Two (P6, H8) are now at the SKIP/MAYBE boundary (score 4-5).

## Pattern Analysis

The remaining 14 SKIP findings cluster into 3 categories:

1. **Cosmetic consistency** (S14, J9, P2): Naming/formatting differences that don't affect behavior. Score 2-3, no functional risk.

2. **Minor duplication** (S12, J8, J12, P12): Small-scale duplication in <6 files. Not worth dedicated refactoring effort — fix opportunistically when editing those files.

3. **Structural debt** (S11, P6, P10, P13, H8): Growing complexity that might eventually justify dedicated cleanup. P6 and H8 are approaching MAYBE territory.

## Recommendation: NO-GO (Close Task)

**Rationale:**
1. 8 of 27 findings are moot — natural codebase evolution eliminated them
2. 2 were fixed by other work (J5, A1)
3. Remaining 14 haven't crossed the DO threshold (≥7)
4. No new evidence upgrades any SKIP to DO
5. Two findings (P6, H8) are at the boundary but don't justify dedicated refactoring — capture as patterns for opportunistic improvement

**Disposition:**
- Close T-432 as NO-GO — dedicated re-evaluation found no actionable upgrades
- Note P6 (task globbing) and H8 (htmx boilerplate) as opportunistic improvements
- Original T-411 DO and MAYBE findings remain the priority
