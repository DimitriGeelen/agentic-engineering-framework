---
title: T-2785 Height Guard Investigation
date: 2026-08-04
status: complete
---

# Height Guard Investigation — T-2785

## Summary

All 4 failing routes genuinely exceed the 8000px `scrollHeight` cap. The guard is working correctly; these are PAGE-OVER-BOUND cases, not measurement artifacts or guard drift. All pages have properly collapsed `<details>` elements (closed, not contributing to scrollHeight), but the main content is unbounded and lacks max-height constraints or scroll containers.

## Route-by-Route Analysis

### Route: `/`

**Measured Height:** 16394px  
**Guard Bound:** 8000px  
**Excess:** 8394px (105% over bound)

**Structure:**
- Main content area: `<article>` with 314 child elements
- No `max-height` style
- No `overflow` property
- No scroll container parent
- Closed `<details>` elements: 4 (confirmed not contributing to height when opened)

**Classification:** **PAGE-OVER-BOUND**

**Evidence:** The `<article>` element occupies 16133px of the 16394px total body height. It is unbounded both by CSS constraint and by layout mechanism. Opening all closed `<details>` elements does not increase scrollHeight, confirming they are already excluded from the measurement.

---

### Route: `/metrics`

**Measured Height:** 10364px  
**Guard Bound:** 8000px  
**Excess:** 2364px (30% over bound)

**Structure:**
- Main content area: `<div class="metrics-wide">` at 9764px
- No `max-height` style
- No `overflow` property
- No scroll container parent
- Closed `<details>` elements: 4 (confirmed not contributing to height when opened)

**Classification:** **PAGE-OVER-BOUND**

**Evidence:** The `metrics-wide` div is the primary contributor. It contains 2 child elements but renders at 9764px with no height constraint. Opening all closed `<details>` elements does not change scrollHeight, confirming they do not contribute to the overflow.

---

### Route: `/inception/T-2715`

**Measured Height:** 11104px  
**Guard Bound:** 8000px  
**Excess:** 3104px (39% over bound)

**Task Existence:** ✓ Task T-2715 exists in `.tasks/active/` (file: `T-2715-first-run-experience-why-four-green-inst.md`)

**Structure:**
- Main content area: `<article class="section-card">` at 8061px
- No `max-height` style
- No `overflow` property
- No scroll container parent
- Closed `<details>` elements: 6 (not contributing to height)

**Classification:** **PAGE-OVER-BOUND**

**Evidence:** The largest section-card article alone is 8061px, which is already at the bound. Additional smaller elements push the total to 11104px. The closed details are not contributing to the overflow.

---

### Route: `/review/T-2715`

**Measured Height:** 11104px  
**Guard Bound:** 8000px  
**Excess:** 3104px (39% over bound)

**Task Existence:** ✓ Task T-2715 exists in `.tasks/active/`

**Structure:**
- Main content area: `<article class="section-card">` at 8061px
- No `max-height` style
- No `overflow` property
- No scroll container parent
- Closed `<details>` elements: 6 (not contributing to height)

**Classification:** **PAGE-OVER-BOUND**

**Evidence:** Identical structure and dimensions to `/inception/T-2715`. The large section-card article is unbounded, causing the overflow.

---

## Key Findings

### Details Elements Are Not the Problem
All 4 routes have properly collapsed `<details>` elements (0 open, 4-6 closed respectively). Programmatically opening all of them produces **zero change** in scrollHeight, confirming they are already excluded from the measurement per CSS display semantics. The collapsed details are functioning correctly as an overflow-containment mechanism.

### The Real Problem: Unbounded Content Areas
Each route has a primary content element with no height constraint:
- `/`: `<article>` with 314 children, no max-height
- `/metrics`: `<div class="metrics-wide">`, no max-height
- `/inception/T-2715` & `/review/T-2715`: `<article class="section-card">`, no max-height

These elements are the source of the overflow. They are not hidden in collapsed details; they are fully visible and contributive to scrollHeight.

### Measurement Integrity
Heights were measured via `document.documentElement.scrollHeight` in a fresh browser context (Playwright Python), matching the test's measurement method. The Watchtower server (http://192.168.10.107:3001) was reachable and responsive. No proxy effects or caching artifacts detected.

---

## Recommendation

All four failures are **structural issues**, not artifacts:
- The guard correctly identifies unbounded pages
- The pages should be fixed via max-height + scroll containers (for tabular data) or collapsed details (for card lists)
- See T-2048, T-2087, T-2775 for the established fix patterns
