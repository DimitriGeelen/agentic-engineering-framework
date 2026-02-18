# Sprechloop Project Governance Inventory

**Audit Date:** 2026-02-18  
**Project Root:** `/opt/001-sprechloop`  
**Framework Integration:** Full (uses Agentic Engineering Framework)

---

## 1. Practices (Project Practices)

**File:** `.context/project/practices.yaml`  
**Status:** EMPTY  
**Count:** 0 entries  
**Note:** This file exists but contains no graduated learnings. The framework allows practices to be promoted from learnings after 3+ applications. No practices have reached graduation threshold yet.

---

## 2. Decisions (Architectural Decisions)

**File:** `.context/project/decisions.yaml`  
**Status:** POPULATED  
**Count:** 8 decisions (D-001 through D-008)  

### Decision List:
- **D-001:** Use own typed async generator pipeline instead of Pipecat (57 LOC vs 427 LOC, T-010)
- **D-002:** Layered evaluation: DTW primary + phoneme diagnostic + text secondary (T-010)
- **D-003:** Piper TTS (CPU, zero VRAM) with espeak-ng fallback (T-017)
- **D-004:** Silero VAD (CPU-only, <10ms latency) for voice activity detection (T-016)
- **D-005:** Ollama local LLM for curriculum generation and feedback (T-018)
- **D-006:** SQLite with aiosqlite for user progress persistence (T-019)
- **D-007:** FastAPI + WebSocket for real-time audio streaming and state orchestration (T-021)
- **D-008:** Responsive web frontend (HTML+JS) instead of native mobile (T-021)

**Pattern:** All decisions trace back to spike/exploration tasks; none conflict; all document rationale with technical reasoning.

---

## 3. Learnings (Knowledge Acquired)

**File:** `.context/project/learnings.yaml`  
**Status:** POPULATED  
**Count:** 16 learnings (L-001 through L-016)  

### Summary by Category:
- **ML/Audio Technical:** L-002, L-003, L-004, L-007, L-010, L-014 (6 learnings on model behavior, metrics, optimization)
- **Architecture:** L-001, L-005, L-008, L-015 (4 learnings on pipeline design, async patterns, plugin architecture)
- **Dependencies:** L-006 (1 learning: Pipecat silent filtering issue)
- **Framework Governance:** L-016 (1 learning: agent discipline on task creation)
- **Unclassified/TBD:** L-009, L-011, L-012, L-013 (4 learnings on FastAPI, Config profiles, curriculum design)

**Status of All Learnings:** `application: TBD` (no learning has been promoted to practice yet)

---

## 4. Patterns (Learned from Experience)

**File:** `.context/project/patterns.yaml`  
**Status:** POPULATED  
**Count:** 5 patterns across 3 categories  

### Breakdown by Type:
- **Failure Patterns:** 2 (FP-001, FP-002)
  - FP-001: Pipecat no_speech_prob default silently drops valid speech (T-006)
  - FP-002: Espeak-ng TTS ceiling effect on phoneme eval (T-009)

- **Success Patterns:** 2 (SP-001, SP-002)
  - SP-001: Plugin architecture for eval modules enables clean swapping (T-015)
  - SP-002: Pull-based async generators match file-processing better (T-005)

- **Workflow Patterns:** 1 (WP-001)
  - WP-001: Config.yaml profile selection for model scaling across hardware (T-013)

---

## 5. Gaps (Spec-Reality Gaps)

**File:** `.context/project/gaps.yaml`  
**Status:** POPULATED  
**Count:** 4 gaps with mixed status  

### Gap Inventory:
- **G-001 (DECIDED-BUILD):** Budget hooks not auto-registered for new projects
  - Severity: HIGH
  - Evidence: sprechloop ran ~20 sessions without budget hooks until manual discovery

- **G-002 (DECIDED-BUILD):** Handover open questions not auto-registered as gaps
  - Severity: MEDIUM
  - Evidence: 1 confirmed instance (missing budget hooks noted but never tracked)

- **G-003 (WATCHING):** Testing bugs not caught by framework — no test enforcement gate
  - Severity: HIGH
  - Evidence: T-023 shipped 5 bugs found only by manual testing; zero unit tests for changed code

- **G-004 (WATCHING):** check-active-task hook checks existence, not scope
  - Severity: HIGH
  - Evidence: AGC change committed under T-027 (mic selector) without being part of scope

---

## 6. Assumptions

**File:** `.context/project/assumptions.yaml`  
**Status:** EMPTY  
**Count:** 0 entries  
**Note:** Framework supports assumption tracking via inception workflow (fw assumption add/validate). Sprechloop has not yet used this feature.

---

## 7. Directives (Constitutional Principles)

**File:** `.context/project/directives.yaml`  
**Status:** POPULATED  
**Count:** 4 directives (D1-D4)  

### Directive List:
1. **D1 - Antifragility:** System must get stronger under stress
2. **D2 - Reliability:** Predictable, consistent behavior under known conditions
3. **D3 - Usability:** Framework must be a joy to use, extend, and debug
4. **D4 - Portability:** No lock-in to any provider, language, or environment

**Source:** Inherited from Agentic Engineering Framework (CLAUDE.md §Four Constitutional Directives). Sprechloop's directives.yaml is a project-specific copy. Framework docs mention directives are "stable anchors" requiring human approval for changes.

---

## 8. Context Structure Inventory

**Populated Subdirectories:**
- `.context/project/` — All governance YAML files (6 files: practices, decisions, learnings, patterns, gaps, directives, assumptions)
- `.context/episodic/` — 32 episodic memory files (T-001.yaml through T-034.yaml, missing T-032, T-033)
- `.context/working/` — Session state (focus.yaml, session.yaml, budget counters, checkpoint scripts)
- `.context/handovers/` — 10 handover documents (S-2026-0218-* sessions, latest: S-2026-0218-1425.md)
- `.context/audits/` — 1 audit file (2026-02-18.yaml, results: 17 PASS, 8 WARN, 0 FAIL)
- `.context/research/` — 3 research files (T-029, T-033, T-034 postmortem)
- `.context/bus/` — Result ledger (exists but unused)
- `.context/scans/` — Empty

**Gap in Context Structure:**
- No `.context/project/bypass-log.yaml` (audits note absence)
- `.context/scans/` is empty (pre-built scanner outputs not used)

---

## 9. Design & Specification Documents

**Location:** `/opt/001-sprechloop/docs/plans/`

Files:
- `2026-02-17-sprechloop-design.md` — Design document with state machine architecture
- `2026-02-17-sprechloop-inception-plan.md` — Inception plan for the project

**Status:** Two foundational design docs; both dated 2026-02-17 (project inception).

---

## 10. Task Inventory

**Active Tasks:** 2 files
- T-032: Audio calibration and device detection (in progress)
- T-033: Investigate AGC impact on silence detection (in progress)

**Completed Tasks:** 31 files (T-001 through T-031, plus others)
- T-001: Voice conversation loop app (inception)
- T-002 through T-011: Spikes and comparison (T-010 spike verdict)
- T-012: Session handover maintenance
- T-013 through T-021: Build tasks (models, STT, eval, VAD, TTS, LLM, storage, curriculum, WebAPI)
- T-022 through T-031: Subsequent builds and refinements

**Episodic Memory:** 32 task summaries (most tasks have episodic records)

---

## 11. Audit Status (2026-02-18)

**Summary:** 17 PASS, 8 WARN, 0 FAIL

**Key Passes:**
- All task directories exist and are valid
- 98% git traceability (84/85 commits reference tasks)
- No Tier 0 violations
- All active tasks meet quality thresholds

**Key Warnings:**
- Uncommitted changes present
- 5 commits reference non-existent T-124 (dead references)
- No bypass log found
- Practices file exists but empty

---

## 12. Framework Initialization & Artifacts

**Evidence of fw init:**
- `.tasks/` directory structure exists (active, completed, templates)
- `.context/` directory structure fully populated
- CLAUDE.md present in project root (30KB, full framework guide)
- `bin/fw` pattern used (PROJECT_ROOT pattern in place)

**Shared Tooling Mode:** Confirmed — sprechloop uses framework via `.framework.yaml` pointing to `/opt/999-Agentic-Engineering-Framework`

**Git Hooks Installed:** Confirmed (commit-msg hook active, post-commit, pre-push)

---

## 13. Current Session & Focus

**Current Focus Task:** T-034 (Research persistence postmortem)  
**Session ID:** S-2026-0218-1227  
**Active Tasks Touched:** T-030, T-032, T-033, T-034  
**Uncommitted Changes:** 0

---

## Summary Statistics

| Category | Count | Status |
|----------|-------|--------|
| Decisions | 8 | All documented with rationale |
| Learnings | 16 | All ready for promotion review |
| Patterns | 5 | 2 failure, 2 success, 1 workflow |
| Gaps | 4 | 2 decided-build, 2 watching |
| Practices | 0 | No learnings promoted yet |
| Assumptions | 0 | Not yet used in project |
| Directives | 4 | Inherited from framework |
| Episodic Records | 32 | 31 completed tasks documented |
| Handovers | 10 | Continuous session capture |
| Active Tasks | 2 | T-032, T-033 |
| Completed Tasks | 31 | T-001 through T-031 |
| Total Task Files | 33 | Across active + completed |

---

## Key Observations

1. **Governance Maturity:** High — all governance structures in place, populated with real data, patterns detected and gaps registered

2. **Practice Graduation Bottleneck:** No learnings promoted to practices (L-016 is most promotion-ready after 3+ framework discussions)

3. **Gap Discipline:** Strong — 4 gaps registered with severity, evidence, decision triggers, and action plans. G-003 and G-004 are high-priority but depend on framework-level changes

4. **Episodic Memory:** Rich — 32 task summaries (97% coverage of tasks), enabling pattern learning and future reference

5. **Audit Health:** Good overall (17/25 checks pass). Non-critical warnings (T-124 dead refs, no bypass log)

6. **Framework Integration:** Complete — PreToolUse/PostToolUse hooks, context budget tracking, verification gates, and all task workflows operational

7. **Handover Cadence:** Strong — 10 handovers in one day indicates consistent session-end discipline

---

## CLAUDE.md References to Directives

From the framework document (/opt/001-sprechloop/CLAUDE.md):

> "## Four Constitutional Directives (Priority Order)
> 
> All architectural decisions must trace back to these directives:
> 
> 1. **Antifragility** — System strengthens under stress; failures are learning events
> 2. **Reliability** — Predictable, observable, auditable execution; no silent failures
> 3. **Usability** — Joy to use/extend/debug; sensible defaults; actionable errors
> 4. **Portability** — No provider/language/environment lock-in; prefer standards (MCP, LSP, OpenAPI)"

The document specifies that directives are "stable anchors" that require human sovereignty approval for changes. Sprechloop has inherited all four from the framework and recorded them in `directives.yaml`.

---

**END OF INVENTORY**
