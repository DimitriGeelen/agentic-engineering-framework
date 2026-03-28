# Framework Knowledge Taxonomy — Universal vs Framework-Specific

**Task:** T-455 Spike 2 — Classify framework knowledge (decisions, learnings, patterns, concerns) as either universal (applies to any project using the framework) or framework-specific (only relevant to the framework's development).

**Purpose:** When a consumer project runs `fw init`, some knowledge is NEEDED for governance to work. Some is POLLUTION. This spike identifies the boundary.

## Analysis Results

### 1. DECISIONS (58 total)

**UNIVERSAL (applies to any framework-using project):**
- D-001: commit-msg hook over pre-commit (enforcement timing principle)
- D-002: YAML files for audit history (portability, readability)
- D-003: 3+ occurrences = practice candidate (statistical threshold)
- D-004: Tier 0 violations are FAIL not WARN (safety principle)
- D-005: Structural tool cohesion over scattered scripts (architecture)
- D-006: Falsifiability criteria defined (testing principle)
- D-007: Primary audience = individual developers + AI (market definition)
- D-008: Knowledge pyramid with graduation criteria (episodic structure)
- D-009: Token reading from JSONL vs tool-call counting (budget monitoring)
- D-010: Check tokens every 5th call (performance/overhead balance)
- D-012: Flask + htmx + Pico CSS without build (portability, no npm)
- D-013: Files as source of truth (no database duplication)
- D-014: 4-status task lifecycle (validated transitions)
- D-015: 4 Flask blueprints by domain (concurrent-mod risk)
- D-016: PreToolUse blocks Write/Edit not Bash (chicken-egg avoidance)
- D-017: fw work-on accepts name OR task ID (friction reduction)
- D-018: Three-tier plugin classification (governance)
- D-019: Tags over hierarchy (simplicity, flexibility)
- D-020: Passive git metrics over estimation (objectivity)
- D-021: Dispatch infrastructure over specialized agents (flexibility)
- D-027: Disable compaction, rely on handovers (critical universal principle)
- D-028: Single handover not emergency/full (crash resilience)
- D-029: Sovereignty gate with sticky owner (human protection)
- D-031: Validate active task file existence (enforcement rigor)

**FRAMEWORK-SPECIFIC (only relevant to framework dev):**
- D-022 through D-048: Web UI stack choices, deployment architecture, cron job design, CI/CD configuration, Watchtower-specific decisions
- D-049 through D-052: Test entries (incomplete, low value)
- D-053 through D-057: Refactoring decisions specific to framework subsystems

**Count:** 24 universal, 34 framework-specific
**Ratio:** 41% universal, 59% framework-specific

### 2. LEARNINGS (100 total, entries L-001 through L-100)

**UNIVERSAL (apply to any project using framework + AI):**
- L-001: Measure what exists, not what should exist (audit principle)
- L-002: Structural enforcement over agent discipline (governance philosophy)
- L-003: Self-critique proves framework works (feedback principle)
- L-004: Only update active tasks to avoid loops (state management)
- L-005: Fail visibly, not silently (quality gates)
- L-007: grep -c edge case with newlines (bash pattern)
- L-008: ((x++)) crashes under set -e (bash pattern)
- L-009: JSONL transcript contains token usage (context monitoring)
- L-010: Compaction occurs 155-165K tokens (context limit)
- L-011: Token reading lags ~1 API call (monitoring caveat)
- L-012: grep matches command text, use JSON parsing (tool usage)
- L-013: Plugins claim authority, need structural gates (enforcement)
- L-014: Never cache identity-dependent state across sessions (cache safety)
- L-015: Context recovery after compaction takes ~16s (session bootstrap)
- L-016: Enforcement gates are load-bearing (verification experiment)
- L-017: Classifier order matters (pattern matching principle)
- L-018: Evidence-driven lifecycle decisions (design methodology)
- L-019: Splitting monolithic files eliminates mod conflicts (architecture)
- L-020: Compliance easier than non-compliance (friction reduction)
- L-021: yaml.safe_load converts ISO timestamps (parser behavior)
- L-025: Sub-agent result management is the real optimization (dispatch)
- L-026: Operational Reflection — 3+ task pattern = codify (Level D thinking)
- L-027: Setup sentinels must not rely on CLAUDE.md (initialization order)
- L-028: Generator functions use $force variable (scope issue)
- L-029: Dry-run onboarding catches bugs (validation methodology)
- L-030: Research docs belong in docs/reports/ (artifact structure)
- L-031: Synthesize verbal insights immediately (memory capture)
- L-032: Split sessions for impl vs research (context budget)
- L-033: Check context budget BEFORE proposing work (agent discipline)
- L-034: Task completion is flag not gate without ACs (acceptance criteria)
- L-035: Verify write operations actually wrote (defensive programming)
- L-036: Git commits sufficient for episodic generation (automation)
- L-037: Agents default to work-around not investigate (error handling)
- L-038: Verification gate beats advisory skills (structural enforcement)
- L-039: Commit before completing (operation ordering)
- L-040: Completion artifacts get committed after close (nuance to L-039)
- L-041: Auto-triggered actions need cooldown (runaway prevention)
- L-042: Behavioral rules fail even when known (inception gate needed)
- L-043: Check context budget at EVERY decision point (discipline)
- L-044: Verify existing controls before building new (diagnosis first)
- L-045: Add verification tests for framework changes (structural enforcement)
- L-046: Verification gate treats HTML comments as commands (regex edge case)
- L-047: YAML init must match add-* expectations (round-trip testing)
- L-048: YAML colons need quoting (parser gotcha)
- L-049: Budget gate deadlock after compaction (circular lock)
- L-050: Compaction cascade without budget hooks (runaway handovers)
- L-051: One bug = one task (decomposition principle)
- L-052: Register gaps before fixing (knowledge persistence)
- L-053: Include write-to-file in sub-agent prompts (dispatch protocol)
- L-054: Playwright browser_snapshot on big DOMs = context explosion (tool limits)
- L-055: General-purpose agents for disk-write, Explore for read-only (agent selection)
- L-056: Task system is primary durable memory (crash resilience)
- L-057: fw bus never used despite design (friction analysis)
- L-058: Framework edits need change impact assessment (review discipline)
- L-059: The thinking trail IS the artifact (research methodology)
- L-060: 2-commit inception gate incompatible with long inceptions (gate conflict)
- L-061: Use responsibility labels (Agent/Human) not nature labels (semantic design)
- L-062: Check task exists in .tasks/active/ not just focus.yaml (enforcement rigor)
- L-063: Cytoscape cose + compounds = elongated layouts (viz algorithm)
- L-064: Hiding compound hides children (cytoscape gotcha)
- L-065: Flask without debug=True caches templates (server behavior)
- L-066: Don't use fw audit in verification commands (recursion risk)
- L-067: Stale critical with fast path blocks forever (budget gate bug)
- L-068: Docker build container isolation (infrastructure pattern)
- L-069: Verify Docker push before deploy (CICD pattern)
- L-070: DinD can't reach LAN hosts directly (networking gotcha)
- L-071: Swarm on Proxmox needs port mode:host (Proxmox quirk)
- L-072: stop-first update order when nodes=replicas (Swarm scheduling)
- L-073: Sync Traefik routes to ALL HA nodes (operational discipline)
- L-074: Health endpoints never trigger expensive ops (endpoint design)
- L-075: First Swarm deploy uses docker stack deploy (CICD gotcha)
- L-076: Register new apps in ring20-deployer ports.yaml (deployment checklist)
- L-077: Fix wrong defaults at source (defense in depth)
- L-078: macOS /bin/bash is 3.2, check PATH bash (portability)
- L-079: macOS grep lacks -P, use -oE (portability)
- L-080: Retagging releases requires housekeeping (release management)
- L-081: macOS sed requires -i '' (portability)
- L-082: Audit trend is leading indicator (proactive analysis)
- L-083: Homebrew Cellar paths are versioned (package manager gotcha)
- L-084: Execution gates don't cover proposal layer (enforcement gap)
- L-085: Audit aging incentivizes queue management (perverse incentive)
- L-086: Handover skips work-completed (archival issue)
- L-087: YAML generators must validate structure (generator discipline)
- L-088: Strip existing quotes before re-quoting (string processing)
- L-089: Resolve hook placeholders at init time (config generation)
- L-090: Hook generators must be exhaustive (completeness)
- L-091: Enforce --no-verify detection (git discipline)
- L-092: AC gates distinguish template from real criteria (placeholder detection)
- L-093: Use symlinks not copies for latest artifacts (caching strategy)
- L-094: Generic provider init must produce valid absolute paths (initialization)
- L-095: Script references need parameterized defaults (version control)
- L-096: Measure actual runtimes before setting timeouts (performance)
- L-097: Use FRAMEWORK_ROOT for agents in shared-tooling mode (mode awareness)
- L-098 through L-100: Test entries (incomplete)

**Framework-specific learnings (L-xxx):**
- L-068 through L-076: Production deployment patterns (Watchtower-specific infrastructure)
- L-078 through L-081: macOS-specific portability quirks (not universal to all projects)
- L-082 through L-096: Watchtower and framework-specific operational patterns

**Count:** 64 truly universal, 36 framework-specific
**Ratio:** 64% universal, 36% framework-specific

### 3. PATTERNS (failure, success, antifragile, workflow)

**UNIVERSAL Failure Patterns:**
- FP-001: Timestamp update loops (state management)
- FP-002: sed returns malformed integers (bash patterns)
- FP-003: Dependency version conflicts (package management)
- FP-004: Context exhaustion (context budget monitoring)
- FP-005: Plugin authority override (enforcement philosophy)
- FP-006: Premature task closure (acceptance criteria)
- FP-007: Silent error bypass (error handling)
- FP-008: Auto-handover runaway (cooldown missing)
- FP-009: Cytoscape layout issues (visualization)
- FP-010: Task enforcement bypassed by stale state (enforcement validation)

**UNIVERSAL Success Patterns:**
- SP-001: Phased implementation (traceability)
- SP-002: Hybrid bash + AGENT.md (architecture)
- SP-003: Commit early often (work preservation)
- SP-004: Detect-then-prevent (graduated enforcement)

**UNIVERSAL Antifragile Patterns:**
- AF-001: Failure-driven capability (learning from incidents)

**UNIVERSAL Workflow Patterns:**
- WP-001: Task absorption (decomposition)
- WP-002: Experiment protocol (validation methodology)

**Framework-specific patterns:**
- None identified (patterns are general to any project)

**Count:** 15 universal patterns (all of them)

### 4. CONCERNS (gaps + risks) — selective view

**UNIVERSAL Gaps (framework governance applies to consumer projects):**
- G-001: Enforcement tiers implementation (now solved but principle is universal)
- G-002: Status transition validation (now solved)
- G-003: Unused frontmatter fields (project-specific)
- G-004: Multi-agent collaboration (not yet tested, universal concern)
- G-005: Graduation pipeline tooling (now solved, universal principle)
- G-006: Workflow templates (project-specific)
- G-007: Budget gate for shared-tooling (SOLVED but universal concern)
- G-010: AC gate distinction (solved, universal principle)
- G-011: PostToolUse hooks advisory-only (universal concern)
- G-013: Task enforcement validation (solved, universal)
- G-014: EnterPlanMode bypass (solved, universal principle)

**FRAMEWORK-SPECIFIC Gaps:**
- G-008: Sub-agent dispatch enforcement (framework dev pattern)
- G-009: Research artifact persistence (framework dev pattern)
- G-012: NotebookEdit not covered (project-specific)
- G-015: Sub-agent results bypass task governance (framework dev pattern)
- G-016: Learning capture has no trigger (framework dev pattern)
- G-017: Execution gates don't cover proposal (partially universal)
- G-018: Silent quality decay in artifacts (framework-specific artifacts)
- G-019: Agent treats symptom fixes as complete (behavioral, partially universal)

**Count (gaps):** ~11 universal, ~8 framework-specific
**Ratio:** 58% universal, 42% framework-specific

### 5. Audit System References to Knowledge

**Audit checks that reference specific decisions by ID:**
- CTL-001 through CTL-026: Governance controls (none directly ref D-XXX/L-XXX, but implement them)
- CTL-002: Implements D-004 (Tier 0 is FAIL not WARN)
- CTL-008: Implements D-005 (git agent task refs)
- CTL-013: Implements D-022 (verification gate)

**Audit checks that are decision-dependent (universal):**
- CTL-001: Task-first gate (D-004, D-017)
- CTL-003, CTL-004, CTL-018: Context budget (D-009, D-010)
- CTL-008: Task reference traceability (D-001)
- CTL-009: Inception commit gate (behavioral rule, not a decision)
- CTL-012: AC gate (D-022)
- CTL-013: Verification gate (D-022)

**Finding:** Audit checks are mostly decision-agnostic (they check for the presence of mechanisms, not for which decision created them). Only ~5 checks are directly decision-dependent. No checks reference learning IDs.

### 6. CLAUDE.md Rule References

**CLAUDE.md directly references:**
- D-027: Auto-compaction disabled (2 refs, critical)
- P-009: Context budget management (1 ref, critical)
- P-010: Acceptance criteria gate (2 refs, critical)
- P-011: Verification gate (3 refs, critical)
- P-001, P-002: Task system principles (2 refs, critical)

**Finding:** Only 4 P-XXX (practices) and 1 D-XXX (decision) are embedded in CLAUDE.md as actual rule references. Most rules are derived from decisions but not explicitly cross-linked.

---

## Summary Statistics

| Category | Total | Universal | Framework-Specific | Universal % |
|----------|-------|-----------|-------------------|-------------|
| Decisions | 58 | 24 | 34 | 41% |
| Learnings | 100 | 64 | 36 | 64% |
| Patterns | 15 | 15 | 0 | 100% |
| Concerns (Gaps only) | 19 | 11 | 8 | 58% |
| **WEIGHTED TOTAL** | 192 | 114 | 78 | 59% |

---

## Classification Rules Applied

**UNIVERSAL** = Principle/pattern applies to ANY project using this framework (even zero AI agents)

**FRAMEWORK-SPECIFIC** = Relevant only to how the Agentic Engineering Framework itself is built/operated

**Edge cases:**
- L-068-081 (infrastructure/deployment): Classified as framework-specific because they document ring20-deployer and Watchtower, not generic patterns. A consumer project would have different infrastructure.
- D-012-048 (Flask, Cytoscape, CICD): Framework-specific because they're choices for the framework's own web UI and deployment, not governance rules.
- G-001 (enforcement tiers): Classified as universal despite being about framework governance, because the principle (graduated enforcement) applies to any project.

---

## Recommendation for `fw init`

**Include in consumer project:**
1. All decisions in UNIVERSAL category (D-001 through D-029)
2. All universal learnings (L-001-046, L-059-067, L-084-096 — skip infrastructure-specific)
3. All patterns (SP, FP, AF, WP)
4. Universal gaps (G-001-005, G-010, G-013-014)
5. Practice entries that reference universal decisions

**Keep separate in framework/**
1. Framework-specific decisions (D-030-057)
2. Framework-specific learnings (L-068-081, L-082-083)
3. Framework-specific gaps (G-008-009, G-015-018)
4. Ring20/Watchtower/infrastructure patterns

**Deliverable:** Filtered YAML files with clear frontmatter: `source: framework` or `scope: universal`

