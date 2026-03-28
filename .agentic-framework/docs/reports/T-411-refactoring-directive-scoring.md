# T-411: Refactoring Audit — Four Directive Scoring

## Dialogue Log

### Human request — "send 5 agents to explore refactoring opportunities"
- **Context:** After completing T-409 (chat RAG) and T-410 (health indicators), and running a clean audit (128 pass, 0 fail after fixing decisions.yaml), human asked to explore refactoring.
- **Agent action:** Dispatched 5 parallel Explore agents, each targeting a different layer (Python backend, JS frontend, shell scripts, HTML templates, architecture/data).
- **Constraint:** Max 5 parallel agents per dispatch protocol. Each wrote to /tmp/ and returned summary.

### Human request — "review all suggestions from all four framework directives and score"
- **Context:** After all 5 agents reported back (64 total findings), human requested directive-aligned scoring rather than raw priority ranking.
- **Agent action:** Scored each of 64 findings on 0-3 scale per directive. Applied verdict thresholds (DO ≥7, MAYBE 5-6, SKIP ≤4). Produced directive heat map and phased plan.
- **Key insight discovered:** D2 Reliability dominates across all layers (avg 1.9). Most "refactoring" is actually reliability improvement — eliminating behavioral variance where the same operation behaves differently depending on code path.

### Human request — "apply framework governance, document research, create rich tasks"
- **Context:** Human caught that the inception was producing analysis without proper governance. Task file was still a bare template. No dialogue log. No formal go/no-go.
- **Course correction:** Fill all inception sections, add dialogue log to research artifact, get formal go/no-go before creating build tasks.
- **Lesson:** Even when the human says "proceed", inception discipline still applies — research artifact first, then decision, then build tasks.

## Scoring Method

Each of the 64 findings scored 0–3 per constitutional directive:

| Score | Meaning |
|-------|---------|
| 0 | No impact on this directive |
| 1 | Minor positive impact |
| 2 | Moderate positive impact |
| 3 | Strong positive impact |

**Directives:** D1=Antifragility, D2=Reliability, D3=Usability, D4=Portability

**Composite** = D1 + D2 + D3 + D4 (max 12)

**Verdict thresholds:**
- **DO** (≥7): Strong multi-directive alignment — worth the effort
- **MAYBE** (5–6): Single-directive value or moderate cross-cutting — worth it if bundled
- **SKIP** (≤4): Low directive impact or cosmetic — not worth dedicated refactoring effort

---

## SHELL SCRIPTS (14 findings)

| # | Finding | D1 | D2 | D3 | D4 | Total | Verdict |
|---|---------|:--:|:--:|:--:|:--:|:-----:|---------|
| S1 | **Path resolution duplication** (25 files) | 2 | 3 | 2 | 3 | **10** | DO |
| S2 | Color variable duplication (19 files) | 1 | 1 | 2 | 1 | **5** | MAYBE |
| S3 | **Validation enum duplication** (6 files) | 2 | 3 | 1 | 1 | **7** | DO |
| S4 | Argument parsing duplication (8 files) | 1 | 2 | 2 | 1 | **6** | MAYBE |
| S5 | **_sed_i compat duplication** (5 files) | 1 | 2 | 1 | 3 | **7** | DO |
| S6 | Task file lookup duplication (4 files) | 1 | 3 | 1 | 1 | **6** | MAYBE |
| S7 | YAML field extraction duplication (10 files) | 1 | 3 | 1 | 1 | **6** | MAYBE |
| S8 | **Error handling inconsistency** (all files) | 2 | 3 | 2 | 1 | **8** | DO |
| S9 | Python inline template duplication (2 files) | 1 | 2 | 1 | 1 | **5** | SKIP |
| S10 | **Hardcoded status/type lists** (3 files) | 2 | 3 | 1 | 1 | **7** | DO |
| S11 | Directory initialization inconsistency (5 files) | 1 | 2 | 1 | 1 | **5** | SKIP |
| S12 | shopt nullglob duplication (2 files) | 0 | 1 | 1 | 0 | **2** | SKIP |
| S13 | **Long monolithic functions** (update-task.sh) | 2 | 2 | 2 | 1 | **7** | DO |
| S14 | Inconsistent help text formatting | 0 | 0 | 2 | 1 | **3** | SKIP |

### Shell Directive Analysis

- **D1 Antifragility (avg 1.2):** Duplication means bugs fixed in one place reappear elsewhere. S1 (path resolution) and S3/S10 (enum validation) are the biggest antifragility risks — a new workflow type added to one script but not others creates silent validation gaps.
- **D2 Reliability (avg 2.0):** Strongest directive hit. Inconsistent error handling (S8), task lookup (S6), and YAML extraction (S7) all create reliability variance — same operation behaves differently depending on which script runs it.
- **D3 Usability (avg 1.4):** Moderate impact. Long functions (S13) and inconsistent errors (S8) hurt developer onboarding and debugging. Color duplication (S2) is cosmetic.
- **D4 Portability (avg 1.1):** S1 scores highest — path resolution is the #1 portability concern. Shared-tooling mode (`PROJECT_ROOT != FRAMEWORK_ROOT`) already exposed this in T-406. S5 (_sed_i) is the classic macOS/Linux portability issue.

---

## JAVASCRIPT (12 findings)

| # | Finding | D1 | D2 | D3 | D4 | Total | Verdict |
|---|---------|:--:|:--:|:--:|:--:|:-----:|---------|
| J1 | Inline styles instead of CSS classes (218 attrs) | 0 | 1 | 3 | 1 | **5** | MAYBE |
| J2 | **Duplicated stream handling** (askQuestion/chatAsk) | 2 | 3 | 2 | 1 | **8** | DO |
| J3 | **Global mutable state** (11 globals) | 2 | 3 | 2 | 0 | **7** | DO |
| J4 | **Inconsistent error handling** | 2 | 3 | 2 | 0 | **7** | DO |
| J5 | Missing abort/cleanup on navigation | 1 | 2 | 1 | 0 | **4** | SKIP |
| J6 | Long functions (chatAsk 169 lines) | 1 | 2 | 2 | 0 | **5** | MAYBE |
| J7 | Hardcoded colors and status text | 0 | 1 | 2 | 1 | **4** | SKIP |
| J8 | Repeated DOM queries | 0 | 1 | 1 | 0 | **2** | SKIP |
| J9 | Inconsistent function naming convention | 0 | 1 | 2 | 0 | **3** | SKIP |
| J10 | Missing input validation/null checks | 1 | 2 | 1 | 0 | **4** | SKIP |
| J11 | Magic numbers in code | 0 | 1 | 2 | 1 | **4** | SKIP |
| J12 | addEventListener with inline functions | 0 | 1 | 1 | 0 | **2** | SKIP |

### JS Directive Analysis

- **D1 Antifragility (avg 0.8):** J2 (stream duplication) is the main risk — a protocol change or bug fix applied to one stream handler but not the other creates silent behavioral divergence. J3 (global state) enables hard-to-reproduce bugs from state leakage between conversations.
- **D2 Reliability (avg 1.8):** J2, J3, J4 are the reliability trio. Duplicated streams mean inconsistent behavior between Q&A and chat. Global state without encapsulation makes test isolation impossible. Inconsistent error handling means the same network failure shows different messages.
- **D3 Usability (avg 1.8):** JS has the highest usability impact. J1 (inline styles) is the biggest single usability concern — 218 inline styles make theming and visual consistency painful. But it scores low on other directives.
- **D4 Portability (avg 0.3):** JS is browser-only, portability impact is minimal. Only J1 (CSS) and J7 (hardcoded colors) have minor portability relevance (theming across deployments).

---

## PYTHON BACKEND (13 findings)

| # | Finding | D1 | D2 | D3 | D4 | Total | Verdict |
|---|---------|:--:|:--:|:--:|:--:|:-----:|---------|
| P1 | **Duplicated YAML loading** (6+ occurrences) | 2 | 3 | 2 | 1 | **8** | DO |
| P2 | Inconsistent logger naming (logger vs log) | 0 | 1 | 2 | 0 | **3** | SKIP |
| P3 | **Context file loading repetition** (10+) | 2 | 3 | 2 | 1 | **8** | DO |
| P4 | Task frontmatter parsing duplication (4x) | 1 | 3 | 1 | 1 | **6** | MAYBE |
| P5 | Session/handover parsing duplication | 1 | 2 | 1 | 0 | **4** | SKIP |
| P6 | Task globbing without caching | 1 | 1 | 1 | 0 | **3** | SKIP |
| P7 | **Subprocess error handling inconsistency** | 2 | 3 | 1 | 1 | **7** | DO |
| P8 | Complex search routing (70+ lines) | 1 | 2 | 2 | 0 | **5** | MAYBE |
| P9 | SSE/streaming duplication (2 generators) | 1 | 2 | 1 | 1 | **5** | MAYBE |
| P10 | Magic numbers scattered | 0 | 1 | 2 | 1 | **4** | SKIP |
| P11 | Error message inconsistency | 1 | 2 | 2 | 0 | **5** | MAYBE |
| P12 | Regex patterns not precompiled | 0 | 1 | 0 | 0 | **1** | SKIP |
| P13 | Inconsistent error context in handlers | 1 | 2 | 1 | 0 | **4** | SKIP |

### Python Directive Analysis

- **D1 Antifragility (avg 1.0):** P1/P3 are the antifragility core — YAML loading bugs fixed in shared.py don't propagate to the 6+ blueprint-local copies. P7 (subprocess inconsistency) means some endpoints hang indefinitely while others timeout gracefully.
- **D2 Reliability (avg 2.0):** Strongest hit, same as shell. P1/P3/P7 are reliability fundamentals — consistent data loading and consistent error behavior are prerequisites for a reliable system.
- **D3 Usability (avg 1.4):** P8 (search complexity) and P11 (error messages) affect developer experience and end-user clarity. P2 (logger naming) is a minor annoyance.
- **D4 Portability (avg 0.5):** Low impact. Python code is framework-internal. P1/P3 have minor portability value (centralized path resolution makes shared-tooling easier).

---

## HTML TEMPLATES (14 findings)

| # | Finding | D1 | D2 | D3 | D4 | Total | Verdict |
|---|---------|:--:|:--:|:--:|:--:|:-----:|---------|
| H1 | Inline styles → CSS classes (218 attrs) | 0 | 1 | 3 | 1 | **5** | MAYBE |
| H2 | **Reusable status badge component** | 1 | 2 | 3 | 1 | **7** | DO |
| H3 | onclick → event listeners/htmx | 1 | 2 | 2 | 0 | **5** | MAYBE |
| H4 | Shared form macro (5+ instances) | 1 | 2 | 2 | 1 | **6** | MAYBE |
| H5 | Consolidate page header structure (20+) | 0 | 1 | 2 | 0 | **3** | SKIP |
| H6 | Data table component macro | 0 | 1 | 2 | 0 | **3** | SKIP |
| H7 | Detail page metadata table component | 1 | 2 | 2 | 0 | **5** | MAYBE |
| H8 | htmx boilerplate (61 instances) | 0 | 1 | 2 | 0 | **3** | SKIP |
| H9 | Badge styling consolidation | 0 | 1 | 2 | 0 | **3** | SKIP |
| H10 | Nested conditional logic in templates | 1 | 2 | 2 | 0 | **5** | MAYBE |
| H11 | Accessibility attributes | 0 | 1 | 3 | 1 | **5** | MAYBE |
| H12 | Responsive grid utility classes | 0 | 0 | 2 | 0 | **2** | SKIP |
| H13 | Search results snippet rendering | 0 | 1 | 1 | 0 | **2** | SKIP |
| H14 | Form row layout consolidation | 0 | 0 | 2 | 0 | **2** | SKIP |

### Template Directive Analysis

- **D1 Antifragility (avg 0.4):** Templates are the least antifragile concern — they don't affect system recovery or learning from failure. H2 (badge component) has minor antifragility value (consistent status display reduces misinterpretation).
- **D2 Reliability (avg 1.2):** Moderate. H2/H4/H10 affect data display correctness. Duplicated badge logic means status colors can diverge between pages.
- **D3 Usability (avg 2.1):** Highest usability impact of any layer. H1 (218 inline styles) and H11 (accessibility) are pure usability plays. This is the UI layer — usability IS the directive.
- **D4 Portability (avg 0.3):** Templates are framework-specific. Only H1/H2/H11 have minor value (consistent CSS enables custom theming for deployers).

---

## ARCHITECTURE & DATA (11 findings)

| # | Finding | D1 | D2 | D3 | D4 | Total | Verdict |
|---|---------|:--:|:--:|:--:|:--:|:-----:|---------|
| A1 | Duplicate load_yaml wrapper (scanner.py) | 0 | 2 | 1 | 0 | **3** | SKIP |
| A2 | Inconsistent blueprint import patterns | 1 | 2 | 2 | 1 | **6** | MAYBE |
| A3 | Metrics-history.yaml unbounded growth (1684 lines) | 2 | 3 | 1 | 0 | **6** | MAYBE |
| A4 | Stale backup file (learnings.yaml.backup) | 1 | 1 | 1 | 0 | **3** | SKIP |
| A5 | **Blueprint circular dependency** (core→cockpit) | 2 | 3 | 1 | 1 | **7** | DO |
| A6 | **Incomplete migration** (gaps.yaml fallback) | 2 | 3 | 1 | 1 | **7** | DO |
| A7 | Duplicated audit loading helpers | 1 | 2 | 2 | 0 | **5** | MAYBE |
| A8 | Monolithic discovery.py (711 lines) | 1 | 2 | 2 | 0 | **5** | MAYBE |
| A9 | Subprocess timeout inconsistency | 1 | 3 | 1 | 0 | **5** | MAYBE |
| A10 | directives.yaml drift from docs | 1 | 2 | 0 | 1 | **4** | SKIP |
| A11 | Fabric component drift detection | 2 | 2 | 1 | 0 | **5** | MAYBE |

### Architecture Directive Analysis

- **D1 Antifragility (avg 1.3):** A3 (unbounded growth) is a time bomb — metrics-history.yaml at 1684 lines and growing. A5/A6 are structural fragility — circular deps and incomplete migrations create surprising failures. A11 (drift detection) is antifragility infrastructure.
- **D2 Reliability (avg 2.3):** Highest reliability impact of any layer. A5/A6 are reliability fundamentals — circular imports cause import errors under certain load orders, and fallback to deleted files masks data loss. A3/A9 affect operational reliability.
- **D3 Usability (avg 1.1):** Architecture changes are developer-facing. A2 (import patterns) and A8 (discovery.py size) affect dev onboarding.
- **D4 Portability (avg 0.4):** A2/A5/A6 have minor portability value (clean architecture is easier to extract/adapt).

---

## CONSOLIDATED: ALL "DO" FINDINGS (Score ≥ 7)

Ranked by composite score:

| Rank | ID | Finding | D1 | D2 | D3 | D4 | Total | Est. Hours |
|------|----|---------|----|----|----|----|----|-----------|
| 1 | S1 | Shell path resolution lib (25 files) | 2 | 3 | 2 | 3 | **10** | 4h |
| 2 | J2 | JS stream handler dedup (2 files) | 2 | 3 | 2 | 1 | **8** | 6h |
| 3 | P1 | Python YAML loading consolidation | 2 | 3 | 2 | 1 | **8** | 3h |
| 4 | P3 | Python context file loader module | 2 | 3 | 2 | 1 | **8** | 4h |
| 5 | S8 | Shell error handling standardization | 2 | 3 | 2 | 1 | **8** | 6h |
| 6 | S3 | Shell validation enum lib | 2 | 3 | 1 | 1 | **7** | 2h |
| 7 | S5 | Shell _sed_i compat consolidation | 1 | 2 | 1 | 3 | **7** | 1h |
| 8 | S10 | Shell hardcoded status/type lists | 2 | 3 | 1 | 1 | **7** | 2h |
| 9 | S13 | Shell long function decomposition | 2 | 2 | 2 | 1 | **7** | 8h |
| 10 | J3 | JS global state encapsulation | 2 | 3 | 2 | 0 | **7** | 6h |
| 11 | J4 | JS error handling standardization | 2 | 3 | 2 | 0 | **7** | 4h |
| 12 | P7 | Python subprocess consistency | 2 | 3 | 1 | 1 | **7** | 3h |
| 13 | H2 | Template badge component | 1 | 2 | 3 | 1 | **7** | 3h |
| 14 | A5 | Blueprint circular dep fix | 2 | 3 | 1 | 1 | **7** | 2h |
| 15 | A6 | Migration cleanup (gaps.yaml fallback) | 2 | 3 | 1 | 1 | **7** | 1h |

**Total "DO" effort: ~55 hours across 15 findings**

## CONSOLIDATED: ALL "MAYBE" FINDINGS (Score 5–6)

| ID | Finding | Total | Est. Hours |
|----|---------|-------|-----------|
| S2 | Shell color variable lib | 5 | 2h |
| S4 | Shell argument parsing lib | 6 | 4h |
| S6 | Shell task file lookup lib | 6 | 2h |
| S7 | Shell YAML field extraction lib | 6 | 3h |
| J1 | JS inline styles → CSS | 5 | 12h |
| J6 | JS long function decomposition | 5 | 4h |
| P4 | Python task frontmatter parser | 6 | 2h |
| P8 | Python search routing simplification | 5 | 3h |
| P9 | Python SSE dedup | 5 | 3h |
| P11 | Python error message consistency | 5 | 2h |
| H1 | Template inline styles → CSS | 5 | 12h |
| H3 | Template onclick → event listeners | 5 | 4h |
| H4 | Template shared form macro | 6 | 3h |
| H7 | Template metadata table component | 5 | 3h |
| H10 | Template conditional logic cleanup | 5 | 2h |
| H11 | Template accessibility | 5 | 4h |
| A2 | Blueprint import standardization | 6 | 3h |
| A3 | Metrics-history retention policy | 6 | 2h |
| A7 | Audit loading helper consolidation | 5 | 2h |
| A8 | Discovery.py split | 5 | 6h |
| A9 | Subprocess timeout standardization | 5 | 2h |
| A11 | Fabric drift detection | 5 | 2h |

**Total "MAYBE" effort: ~80 hours across 22 findings**

## DIRECTIVE HEAT MAP (Average Score by Layer)

| Layer | D1 Antifragility | D2 Reliability | D3 Usability | D4 Portability | Avg |
|-------|:-:|:-:|:-:|:-:|:-:|
| Shell | 1.2 | **2.0** | 1.4 | 1.1 | 1.4 |
| JavaScript | 0.8 | 1.8 | **1.8** | 0.3 | 1.2 |
| Python | 1.0 | **2.0** | 1.4 | 0.5 | 1.2 |
| Templates | 0.4 | 1.2 | **2.1** | 0.3 | 1.0 |
| Architecture | 1.3 | **2.3** | 1.1 | 0.4 | 1.3 |

**Key insight:** D2 (Reliability) dominates across all layers. D3 (Usability) dominates templates/JS. D4 (Portability) is concentrated in shell scripts. D1 (Antifragility) is spread thinly — most refactoring improves reliability, not antifragility.

## RECOMMENDED REFACTORING PHASES

### Phase 1: Quick Wins (8h, score ≥ 7, effort ≤ 2h each)
- A6: Remove gaps.yaml fallback (1h)
- A5: Move load_scan to shared.py (2h)
- S5: Consolidate _sed_i compat (1h)
- S3+S10: Create lib/enums.sh (2h combined — same deliverable)
- S1: Create lib/paths.sh (partial — extract, start sourcing in key scripts)

### Phase 2: Core Libraries (16h, highest cross-cutting impact)
- S1: Complete lib/paths.sh rollout (4h)
- P1+P3: Create web/context_loader.py (4h combined)
- S8: Create lib/errors.sh (6h)
- P7: Create web/subprocess_utils.py (2h)

### Phase 3: JS Modernization (16h, user-facing quality)
- J2: Extract StreamFetcher utility (6h)
- J3: Encapsulate conversation state (6h)
- J4: Standardize error handling (4h)

### Phase 4: Template Polish (6h, visual consistency)
- H2: Create badge macro (3h)
- H4: Create form macro (3h)

### Phase 5: Structural (8h, long-term maintenance)
- S13: Decompose update-task.sh (8h)
