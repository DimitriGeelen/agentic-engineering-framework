# T-1092: Dispatch Payload Profiles — Research Artifact

**Status:** Research in progress (inception, no build authorized)
**Created:** 2026-04-11
**Task:** T-1092
**Predecessor:** Extended conversation during T-1087/T-1088/T-1091 session (2026-04-11), triggered by T-909 3-parallel dispatch cost estimate (100-300K tokens)

---

## Purpose of this document

This is a **thinking trail**, not a build spec. The research phases below populate incrementally as exploration progresses. The artifact IS the deliverable — per C-001, conversations are ephemeral, files are permanent. If a dialogue segment in session clarifies a finding, it gets logged here in the Dialogue Log section before the session ends.

Scope fence (re-stated from the task file): NO profiles built, NO schema locked, NO repo created. This document is evidence + sketches + a recommendation.

---

## Phase 1 — Evidence gathering (dispatch archetypes from real history)

**Goal:** Mine episodic memory and handovers for every parallel-dispatch event. Catalog worker role, token cost where recorded, output shape, success/failure. Identify archetypes empirically.

**Status:** Complete.

### 1.1 Dispatch Event Catalog

Sourced from: `.context/episodic/*.yaml` (grep: dispatch, parallel, termlink, Task tool), T-097 full catalog, task files.

#### Task Tool Agents (share parent context)

| Task | Workers | Role | Outcome | Token Cost | Notes |
|------|---------|------|---------|------------|-------|
| T-014 | 1 Plan | Critical review of audit | 8 findings | Low | Single agent |
| T-058 | Sequential | TDD fresh agents per impl | Caught missing git_log | Low | 1 agent at a time |
| T-059 | 3 parallel | Investigation — root cause | Success | ~10K ingested | Parallel investigation |
| T-061 | 4 parallel | Bypass vector scan | Comprehensive | ~10K ingested | Parallel investigation |
| T-072 | 3 parallel | Full project audit (3 domains) | Thorough | ~15K ingested | Parallel audit |
| T-073 | **9 parallel** | Enrich episodic skeletons | **Context explosion (177K)** | **~27K ingested** | Canonical failure |
| T-086 | 5 parallel | Feature evaluation | Informed decision | ~12K ingested | Parallel evaluation |
| T-054 | ~4 concurrent | File edits (same file) | Blueprint refactor needed | N/A | Anti-pattern |

T-097 catalog: 8 of 96 tasks (8.3%) used Task tool sub-agents (through 2026-02-17).

#### TermLink Dispatch (independent processes, zero parent context cost)

| Task | Workers | Role | Outcome | Notes |
|------|---------|------|---------|-------|
| T-698 | 1 | Observability evaluation (interactive vs headless) | GO decision | Inception research |
| T-792 | 1 | CWD fix in worker run.sh | Fixed | Bug fix dispatch |
| T-818 | 2 | Result persistence analysis | T-816 lost, T-817 ok | Triggered persistence rule |
| T-820 | 1 | Preamble fix | Success | Build fix |
| T-897 | **11 parallel** | Batch upgrade consumers to v1.4.603 | Success, 4 min | Batch fanout |
| T-962 | **7 parallel** | Web terminal research (7 vectors) | Success, 7 files | Parallel inception |
| T-968 | **5 parallel** | 3-tier test infra (5 vectors) | Success, 5 files | Parallel inception |
| T-1025 | Multiple | Playwright test generation (18 tests, 7 routes) | Success | Test generation |
| T-1071 | **11 parallel** | Batch upgrade consumers to v1.5.199 | Success, 11 min | Batch fanout |
| T-1088 | **11 parallel** | Batch upgrade with budget-gate fix | Success | Batch fanout |

Post-T-529, TermLink dispatch has overtaken Task tool agents. The growth trend is clear: T-897 (11), T-962 (7), T-968 (5), T-1025 (multiple), T-1071 (11), T-1088 (11).

#### Note on T-909 reference
The task description cites "T-909 3-parallel risk-eval dispatch was estimated at 100-300K tokens." T-909 in completed tasks is "Generate missing episodics for T-896, T-905..." — not a risk-eval dispatch. The 3-parallel risk-eval is a **hypothetical example** used in the triggering dialogue to illustrate the cost problem, not a real incident. The 100-300K estimate is inferential (3 workers × 30-45K per worker system context).

### 1.2 Dispatch Mechanism Analysis

Current TermLink dispatch runs:
```bash
cd "$PROJECT_DIR"
claude -p "$(cat "$WDIR/prompt.md")" $MODEL_FLAG --output-format text
```

Since `claude -p` runs from the project directory, it auto-loads the project's CLAUDE.md. Workers receive:
- CLAUDE.md (9,481 words ≈ **12,325 tokens**) — auto-loaded from `$PROJECT_DIR`
- FRAMEWORK.md (1,687 words ≈ 2,190 tokens) — may auto-load
- Claude Code base system prompt (estimated 5-15K tokens)
- MCP server instructions (context7 + playwright, ~1-2K tokens)
- Memory files (variable)
- **Total estimated: 25-35K tokens of system context per worker**

Note: The "45K" figure in the task problem statement may have been estimated at a time when CLAUDE.md was longer, or includes all loaded context combined.

No mechanism currently exists to strip or replace the auto-loaded CLAUDE.md content for workers.

### 1.3 Empirical Archetypes (A-5 Assessment)

**Six distinct worker archetypes identified from real history — A-5 validated:**

| # | Archetype | Examples | What Worker Actually Does |
|---|-----------|----------|--------------------------|
| **A1** | **Parallel Investigator** | T-059, T-061, T-086 | Read-only scan of codebase domain, return structured findings |
| **A2** | **Parallel Auditor** | T-072, T-014 | Review artifacts against criteria, return pass/warn/fail |
| **A3** | **Content Generator** | T-073, T-1025 | Write files from templates; return path + summary |
| **A4** | **Sequential Developer** | T-058 | TDD implementation cycle; needs commit and build discipline |
| **A5** | **Batch Fanout Worker** | T-897, T-1071, T-1088 | Same operation on N targets; each worker writes to target repo |
| **A6** | **Research Vector Worker** | T-962 (7v), T-968 (5v) | Deep-dive one inception aspect; write to docs/reports/T-XXX-vN.md |

### 1.4 Token Cost Analysis

| Archetype | Workers need | Workers get (current) | Overhead | Savings potential |
|-----------|-------------|----------------------|----------|-------------------|
| A1 Investigator | ~5K (behavioral + context) | ~30K | 83% | High |
| A2 Auditor | ~8K (format + rules) | ~30K | 73% | High |
| A3 Content Generator | ~3K (output rules + templates) | ~30K | 90% | Very high |
| A4 Developer | ~15K (build discipline + commit) | ~30K | 50% | Medium |
| A5 Batch Worker | ~3K (target path + output rules) | ~30K | 90% | Very high |
| A6 Research Vector | ~5K (C-001 + output rules) | ~30K | 83% | High |

For a 3-parallel dispatch (e.g., hypothetical risk-eval):
- Current: 3 × ~30K = **~90K tokens** (system context overhead)
- Profiled (A1/A6 profile): 3 × ~5K = **~15K tokens** → ~83% reduction
- Savings become meaningful at ≥3 parallel workers; trivial for single workers

---

## Phase 2 — CLAUDE.md audit (what's worker-relevant vs orchestrator-only)

**Goal:** Walk every H2 section of CLAUDE.md. Classify each as worker-relevant / orchestrator-only / constitutional-floor / conditional. Estimate token weight per bucket. Sketch a minimal worker payload.

**Status:** Complete.

CLAUDE.md is 1,141 lines / 9,481 words. At 1.3 tokens/word ≈ **12,325 tokens**.
Sections (24 H2 headings) — classified below.

### 2.1 Section-by-Section Classification

| Section | Words (est.) | Tokens (est.) | Bucket | Rationale |
|---------|-------------|---------------|--------|-----------|
| Project Overview | 100 | 130 | **Conditional** | Worker needs project identity; the "not a code library" context helps |
| Core Principle | 30 | 40 | **Constitutional floor** | "Nothing gets done without a task" — the governance axiom, minimal size |
| Four Constitutional Directives | 100 | 130 | **Constitutional floor** | Worker making trade-off decisions needs these |
| Authority Model | 150 | 195 | **Constitutional floor** | Defines what worker can/cannot decide unilaterally |
| Instruction Precedence | 200 | 260 | **Orchestrator-only** | About managing conflicting instructions from plugins/skills — not a worker concern |
| Task System | 600 | 780 | **Orchestrator-only** | Task creation, lifecycle, horizon — workers don't create/manage tasks |
| Task Sizing Rules | 150 | 195 | **Orchestrator-only** | Decomposition rules — workers don't decompose tasks |
| Enforcement Tiers | 100 | 130 | **Constitutional floor** | Tier 0 (destructive actions need human approval) applies to all workers |
| Working with Tasks | 300 | 390 | **Orchestrator-only** | Session init, task start, status update, healing — orchestrator governs |
| Context Integration | 50 | 65 | **Orchestrator-only** | Memory system — orchestrator manages |
| Error Escalation Ladder | 200 | 260 | **Conditional** | Relevant for developer workers (A4); not for one-shot researchers |
| fw CLI (Primary Interface) | 50 | 65 | **Orchestrator-only** | CLI commands are for orchestrator session management |
| Agents (all subsections) | 700 | 910 | **Orchestrator-only** | Describes agents the orchestrator invokes; workers don't invoke them |
| Component Fabric | 350 | 455 | **Conditional** | Relevant if worker modifies source files (A4, some A3); not for A1/A2/A5/A6 |
| Context Budget Management | 350 | 455 | **Orchestrator-only** | Session-level budget tracking; workers have independent budgets |
| Configuration | 350 | 455 | **Orchestrator-only** | `fw config` is orchestrator-level |
| Sub-Agent Dispatch Protocol | 600 | 780 | **Conditional** | Only relevant if worker itself dispatches further workers (rare; nested orchestration) |
| Agent Behavioral Rules | 2000 | 2600 | **MIXED** — see breakdown below | — |
| Plan Mode Prohibition | 100 | 130 | **Orchestrator-only** | Workers don't plan projects; they execute tasks |
| Session Start Protocol | 200 | 260 | **Orchestrator-only** | Workers don't init sessions |
| Quick Reference | 500 | 650 | **Orchestrator-only** | fw command table — orchestrator CLI reference |
| TermLink Integration | 500 | 650 | **Orchestrator-only** | TermLink operations are orchestrator-level |
| Auto-Restart | 200 | 260 | **Orchestrator-only** | `claude-fw` wrapper — orchestrator process management |
| Remote Session Access | 150 | 195 | **Orchestrator-only** | TermLink observation — orchestrator monitoring |
| Session End Protocol | 100 | 130 | **Orchestrator-only** | Handover, session capture — orchestrator responsibility |

#### Agent Behavioral Rules breakdown (2600 tokens total)

| Sub-rule | Tokens | Bucket | Rationale |
|----------|--------|--------|-----------|
| Choice Presentation (numbered options) | 80 | **Constitutional floor** | Worker presents options when relevant |
| Autonomous Mode Boundaries | 250 | **Orchestrator-only** | About "proceed as you see fit" — orchestrator interaction pattern |
| Pickup Message Handling | 300 | **Orchestrator-only** | About session handoffs — orchestrator only |
| Human Task Completion Rule | 250 | **Orchestrator-only** | About when to complete human tasks — orchestrator decides |
| AC Classification Guidance | 400 | **Conditional** | Relevant if worker writes ACs (A4 developer) |
| Human AC Format Requirements | 400 | **Conditional** | Relevant if worker writes ACs (A4 developer) |
| Verification Before Completion | 200 | **Worker-relevant** | If worker completes a task, this applies |
| Presenting Work for Human Review | 200 | **Orchestrator-only** | Watchtower review flow — orchestrator only |
| Hypothesis-Driven Debugging | 200 | **Worker-relevant** | Debugging behavioral rule — applies to all workers |
| Bug-Fix Learning Checkpoint | 150 | **Conditional** | Relevant for A4 developer workers |
| Post-Fix Root Cause Escalation | 150 | **Orchestrator-only** | Recording gaps in concerns.yaml — orchestrator responsibility |
| Commit Cadence | 100 | **Conditional** | Relevant only if worker commits (A4, some A5) |
| Copy-Pasteable Commands | 100 | **Worker-relevant** | When worker gives human commands to run |
| Inception Discipline | 300 | **Orchestrator-only** | Inception governance — orchestrator only |
| Web App Startup | 100 | **Conditional** | Relevant if worker builds web apps |
| Constraint Discovery | 80 | **Conditional** | Relevant for hardware API tasks |
| Agent/Human AC Split | 150 | **Conditional** | Relevant for A4 developer workers |

### 2.2 Bucket Totals

| Bucket | Approx. Tokens | % of Total |
|--------|---------------|------------|
| Constitutional floor | ~575 | 5% |
| Worker-relevant (always ship) | ~480 | 4% |
| Conditional (ship per archetype) | ~2,200 | 18% |
| Orchestrator-only (never ship to one-shot) | ~9,070 | 74% |
| **Total** | **~12,325** | **100%** |

**A-1 assessment (partial validation):** 74% of CLAUDE.md is definitively orchestrator-only. A minimal constitutional payload (floor + worker-relevant) is **~1,055 tokens** — 9% of the current CLAUDE.md.

### 2.3 Minimal Worker Payload Sketch (conceptual — NOT a build artifact)

```
SECTION 1: Constitutional Floor (~575 tokens)
  - Core Principle (1 sentence)
  - Four Constitutional Directives (4 bullet points)
  - Authority Model (authority table + 2 sentences)
  - Enforcement Tiers (table only — Tier 0 matters for all)

SECTION 2: Worker Behavioral Rules (~480 tokens)
  - Choice Presentation (rule + example)
  - Hypothesis-Driven Debugging (rule + 7 steps)
  - Copy-Pasteable Commands (rule + example)
  - Verification Before Completion (rule + steps, condensed)

SECTION 3: Output Rules (~300 tokens — from preamble.md, not CLAUDE.md)
  - Write to disk, return ≤5 lines
  - Never return file contents, YAML, long lists

SECTION 4: Archetype-specific addition (~200-2000 tokens depending on type)
  - A1/A2/A6 one-shot: none
  - A3 content generator: output template format
  - A4 developer: Component Fabric (deps check), Error Escalation, Commit Cadence, AC rules
  - A5 batch worker: target output path conventions
```

**Estimated minimal payload: ~1,355-3,355 tokens** vs. current ~30,000+ total system context — **88-95% reduction**.

---

## Phase 3 — Schema side-by-side (Path A vs Path B sketches)

**Goal:** Sketch both architectures for the same concrete example (risk-eval). Make what each path locks in and defers explicit. Do NOT choose yet.

**Status:** Complete.

### 3.0 Critical Prerequisite: Mechanism for Profile Delivery

**Before either path can work, there must be a mechanism to deliver a reduced context to workers instead of (or replacing) the auto-loaded CLAUDE.md.**

Current dispatch: `claude -p "$(prompt)" --output-format text` run from `$PROJECT_DIR`.
Claude Code auto-loads the project's CLAUDE.md. No current mechanism exists to suppress or replace it.

**Three candidate delivery mechanisms:**

| Mechanism | How | Complexity | Risk |
|-----------|-----|-----------|------|
| **M1: Profile worktree** | Dispatch from a subdirectory with minimal CLAUDE.md | Medium | Worktree setup per dispatch |
| **M2: --system-prompt override flag** | `claude -p --system-prompt profile.md` replaces CLAUDE.md | Low (if flag exists) | Depends on undocumented flag |
| **M3: Prompt injection** | Add "IGNORE GOVERNANCE SECTIONS, FOLLOW ONLY:" to prompt | None (code change) | Fragile, adversarial pattern |

This is **Load-Bearing Unknown #1** (LBU-1) — which mechanism(s) actually work must be validated before building profiles. See Phase 4.

### 3.1 Path A — Build-First (profile lives in framework repo)

**Philosophy:** Write the first real profile (one-shot-researcher or risk-eval) using the most convenient delivery mechanism. Let the schema emerge from 2-3 real profiles before extracting it.

**File layout (sketch):**
```
agents/dispatch/
  preamble.md              ← existing (Task tool agent preamble)
  termlink-preamble.md     ← existing (TermLink worker rules)
  profiles/
    README.md              ← which profile to use for which archetype
    one-shot-researcher/
      system-prompt.md     ← the actual reduced context (replaces/supplements CLAUDE.md)
      meta.yaml            ← profile metadata (id, version, intended-archetypes, token-estimate)
    developer/
      system-prompt.md
      meta.yaml
```

**Usage:**
```bash
# Dispatch with profile
fw termlink dispatch --task T-XXX --name worker --profile one-shot-researcher --prompt "Analyze..."

# Under the hood (if M2 works):
claude -p "$(prompt)" --system-prompt agents/dispatch/profiles/one-shot-researcher/system-prompt.md

# Under the hood (if M1 works):
cd /tmp/profile-dispatch-workdir/  # has symlink to actual project files + minimal CLAUDE.md
claude -p "$(prompt)"
```

**What Path A locks in:**
- Profile storage location: `agents/dispatch/profiles/`
- The `fw termlink dispatch --profile` flag surface
- The first profile's content (will be evolved)

**What Path A defers:**
- Schema for profile metadata
- Portability/cross-framework consumption
- Semantic vs. declarative split (just write what works, extract the pattern later)
- Mechanism specifics (resolve LBU-1 first)

**Path A profile content sketch for "one-shot-researcher"** (conceptual content only):
```markdown
# One-Shot Research Worker — Context Profile

You are a one-shot research worker spawned by an orchestrator session.
You are executing a single research task and returning your findings.

## Your Authority
- Read files, run commands, write output to your assigned output file
- You do NOT create tasks, modify governance, or make architectural decisions
- If you encounter something requiring human approval, note it in your output and stop

## Core Principles
[4 directives — 130 tokens]
[Tier 0 definition — 50 tokens]

## Behavioral Rules
[Hypothesis-driven debugging — 200 tokens]
[Choice presentation — 80 tokens]

## Output Rules
[Write to assigned path, return ≤5 lines — 300 tokens]
```

Estimated size: ~760-1,000 tokens (vs. ~30K current) — ~97% reduction for A1/A6 archetypes.

### 3.2 Path B — Schema-First (separate `agentic-profiles` portable repo)

**Philosophy:** Design the profile schema before writing the first profile. Publish as standalone artifact for cross-framework consumption from day 1. Profiles are declarative YAML; materialization is a separate tool.

**Repository structure (sketch):**
```
agentic-profiles/
  schema/
    profile.schema.json      ← JSON Schema for profile YAML
  profiles/
    one-shot-researcher/
      profile.yaml           ← Declarative: purpose, constraints, capabilities
      intent.md              ← Semantic layer: why this profile exists, what it's optimized for
    developer/
      profile.yaml
      intent.md
  tools/
    materialize.sh           ← Given profile.yaml + target framework, emit system-prompt.md
    validate.sh              ← Check profile against schema
  README.md
```

**Profile schema (sketch):**
```yaml
# profile.yaml for one-shot-researcher
id: one-shot-researcher
version: 1.0.0
description: "Read-only research worker; returns findings to orchestrator"
intended-archetypes: [investigator, auditor, research-vector]

capabilities:
  - read-files
  - run-read-only-commands
  - write-output-file

constraints:
  - no-task-creation
  - no-commits
  - no-governance-modifications
  - no-subdispatch

governance-floor:
  - constitutional-directives
  - authority-model
  - tier-0-enforcement

behavioral-rules:
  - hypothesis-driven-debugging
  - choice-presentation
  - output-budget-rules
```

**Materialization tool** converts profile.yaml → system-prompt.md by:
1. Reading the profile's `governance-floor` list
2. Extracting those sections from a source CLAUDE.md (or canonical section library)
3. Adding capability/constraint preamble
4. Writing to `agents/dispatch/profiles/one-shot-researcher/system-prompt.md`

**What Path B locks in:**
- Profile YAML schema (now, before evidence)
- Semantic/declarative split (semantic = intent.md, declarative = profile.yaml)
- Materialization tool interface
- Cross-framework portability requirement

**What Path B defers:**
- Which frameworks consume the profiles
- Whether the schema is correct (won't know until 2-3 profiles exist)

### 3.3 Path Divergence Table

| Dimension | Path A (build-first) | Path B (schema-first) |
|-----------|---------------------|----------------------|
| First artifact | A `system-prompt.md` for one-shot-researcher | A `profile.yaml` schema + one-shot-researcher example |
| Schema commitment | Emerges from 2-3 profiles (probably ~3 months) | Locked before first profile (today) |
| Portability | Profiles in framework repo (not portable) | Separate repo, consumable by any framework |
| Token cost of building | Low — write a markdown file | Medium — design schema, build materializer |
| When it could break | If LBU-1 mechanism fails to deliver profile | If schema is wrong AND materialization is built around it |
| History of similar designs | A-3 validated: schema-first designs get rewritten in this project | A-3 validated: emergent schemas stabilize faster here |
| Reverting if wrong | High — just edit a markdown file | Low — schema rewrite + tool rewrite |
| Evidence from project history | Dispatch protocol emerged from real use (T-073, T-097, T-098) | No precedent for portable profile schemas in this project |
| Path to cross-framework | Separate the `profiles/` directory into its own repo later (easy) | Done from day 1 (no migration needed) |

### 3.4 Key Observation (not a choice)

Path A and Path B are not fundamentally different in END STATE — both result in a profile YAML + system-prompt.md pair living in a (possibly separate) repo. They differ in **when the schema is committed** and **where the profiles initially live**.

The user's own hypothesis (from dialogue log, 2026-04-11): "both paths end in the same place; they differ in whether the schema is designed or emergent." This research confirms that hypothesis: the end state is the same, the cost difference is in the current commitment level.

---

## Phase 4 — Governance floor (what must never be stripped)

**Goal:** Enumerate the items that MUST ship to every worker regardless of profile. For each: state what breaks if stripped, cite a real incident that validates the need.

**Status:** Complete.

### 4.1 Floor Items (MUST be in every worker payload)

| Item | What breaks if stripped | Real incident |
|------|------------------------|---------------|
| **Core Principle: "Nothing gets done without a task"** | Worker might treat itself as a standalone agent, start making decisions outside the delegated task scope | T-469 (pickup message handling): agent treated a handoff as authorization without verifying task context |
| **Four Constitutional Directives** | Worker makes trade-off decisions without a value hierarchy — no way to resolve "build fast vs build right" or "orchestrator-only vs portable" conflicts | T-097: only because Antifragility > Reliability could the team choose 96% enrichment savings over perfect safety |
| **Authority Model** (the SOVEREIGNTY/AUTHORITY/INITIATIVE table) | Worker attempts to make architectural decisions or approve its own boundary-crossing actions, citing "broad directive" | T-469 (G-020 origin): agent internalized a pickup spec as authorization and bypassed scoping |
| **Tier 0 Enforcement** (destructive actions require human approval) | Worker executes `rm -rf`, `git reset --hard`, `DROP TABLE` without human gate | Enforced by `check-tier0.sh` — structural gate exists precisely because LLMs can misclassify destructive consequences |
| **Choice Presentation** (numbered options) | Worker presents walls of prose when alternatives exist; user can't reply "2" | T-679 (3× human correction session): agent repeatedly presented prose options requiring rephrase before human could respond |
| **Output Rules** (write to disk, return ≤5 lines) | Context explosion — return of full content to orchestrator spikes context | T-073: 9 agents returning full YAML → 177K token spike → session crash |
| **Hypothesis-Driven Debugging** | Worker shotguns debug attempts without forming hypotheses; applies random fixes, doesn't learn | Multiple sessions (unnamed) — CLAUDE.md rule added because agents repeat "try a different approach" without root cause investigation |

### 4.2 Load-Bearing Unknowns

Items where I'm uncertain whether stripping breaks things:

**LBU-1: Profile Delivery Mechanism (HIGH PRIORITY)**
- Whether any of M1/M2/M3 actually work for profile delivery
- If `claude -p --system-prompt profile.md` doesn't exist as a flag: the entire profile system is blocked on a new delivery mechanism (worktree-based dispatch)
- **What to test:** `claude -p "what is your system prompt?" --system-prompt /dev/null` — if this overrides CLAUDE.md, M2 works
- **Impact:** If M2 doesn't work, profiles can only ADD tokens (via `--append-system-prompt`), not reduce them. Profile system becomes a token-addition system, not a token-reduction system.

**LBU-2: Worker Token Measurement (MEDIUM PRIORITY)**
- No measured data on actual per-worker token cost in real dispatches (A-4 explicitly deferred)
- The 30-45K estimate is inferential from CLAUDE.md word count + base system prompt estimate
- **What to test:** Dispatch a worker with `--output-format json` and read the usage stats from the output
- **Impact:** If actual system context is <15K (not 30-45K), the savings are real but smaller than estimated; still worth doing for 11-parallel batch dispatches

**LBU-3: Worker Governance Compliance Without Full CLAUDE.md (LOW PRIORITY)**
- If workers currently implicitly rely on some orchestrator-only rule (e.g., error escalation ladder) without being asked to — and stripping it causes silent quality degradation
- **What to test:** Compare worker output quality on a benchmark task with full CLAUDE.md vs. minimal profile
- **Impact:** If governance-only sections have positive quality side effects beyond their stated purpose, the stripped profile might produce lower-quality output

### 4.3 Explicit Non-Floor List (confirmed OK to strip from one-shot workers)

These are in CLAUDE.md but are definitively not needed for A1/A2/A5/A6 one-shot workers:

- Task lifecycle management (create, update, complete, handover, healing) — orchestrator-owned
- Session start/end protocol — orchestrator-owned  
- Context budget management — workers have independent budgets
- Handover, resume, and session capture agents — orchestrator-owned
- Plan Mode Prohibition — workers don't enter plan mode
- Human Task Completion Rule — workers don't complete human-owned tasks
- Post-Fix Root Cause Escalation — workers don't register gaps
- Inception Discipline — workers don't make inception decisions
- Auto-Restart and TermLink integration — orchestrator process management
- Quick Reference table — orchestrator CLI commands
- Configuration section — orchestrator configuration management

---

## Phase 5 — Recommendation

**Goal:** Synthesize the above into a single recommendation with cited evidence.

**Status:** Complete.

---

### Recommendation: **GO Path A** — with prerequisite: validate LBU-1 first

---

### Rationale

The evidence supports building profiles, and Path A (build-first) is the correct approach for this project's history with schema-first designs. However, building before validating LBU-1 (profile delivery mechanism) risks creating profiles that can't be delivered at reduced cost — making the entire effort a token-addition system rather than a token-reduction system.

**The sequence:**
1. **This week:** Validate LBU-1 — test whether `claude -p` supports `--system-prompt override` flag
2. **If LBU-1 resolves to M2 (or M1):** Build first profile (one-shot-researcher) under Path A
3. **After 2-3 profiles exist:** Extract the schema naturally for potential Path B migration

### Evidence

**A-5 validated:** 6 distinct archetypes from real dispatch history — the portfolio is large enough to justify a profile system:
- A1 Investigator (T-059, T-061, T-086), A2 Auditor (T-072), A3 Generator (T-073, T-1025)
- A4 Developer (T-058), A5 Batch Fanout (T-897, T-1071, T-1088 — 11-parallel, growing), A6 Research Vector (T-962 7v, T-968 5v)

**Cost is real and growing:** T-897/T-1071/T-1088 show 11-parallel batch dispatches becoming routine. At 11 workers × ~30K system context = **~330K tokens of overhead per batch upgrade**. The savings potential is not marginal.

**A-1 validated:** 74% of CLAUDE.md is orchestrator-only. Constitutional floor + worker-relevant rules is **~1,055 tokens** (9% of CLAUDE.md alone). This is a ~90% reduction in CLAUDE.md payload for one-shot workers.

**A-3 validated (against Path B):** Schema-first designs in this project have been rewritten: result bus (T-098 → `fw bus` evolution), component fabric (multiple schema revisions), learnings.yaml (format revised twice), inception taxonomy (re-classified). No schema designed up-front has survived unchanged. Building the schema before 2-3 real profiles would produce a schema that gets rewritten on first contact with reality.

**A-6 not validated (no urgency for separate repo):** No evidence of another framework that would consume profiles within 2026. The portability benefit of Path B is real but hypothetical. Path A can evolve to Path B by extracting `agents/dispatch/profiles/` into its own repo later — this is a low-cost migration once profiles exist.

**Preamble pattern precedent:** The existing `agents/dispatch/preamble.md` and `agents/dispatch/termlink-preamble.md` show exactly the Path A evolution: preamble started as inline text, got extracted to a file, then split when TermLink had different rules. Profile files would follow the same natural evolution.

### What Would Change My Recommendation

| Signal | Would change to |
|--------|----------------|
| LBU-1 shows NO mechanism to strip/replace CLAUDE.md for workers | DEFER Path A — build the delivery mechanism (M1 worktree dispatch) first as a separate task |
| LBU-2 measurement shows actual worker system context is <10K tokens (not ~30K) | Maintain GO but lower urgency — savings exist but payback is smaller |
| Another framework team expresses concrete need for portable profiles | Move to Path B immediately — extract to separate repo, invest in schema |
| LBU-1 resolves to M2 AND `--system-prompt` flag is undocumented / unstable | Path A with M1 worktree approach — more complex but stable |

### Next Steps (if GO is confirmed by human)

1. **T-next-1:** Validate LBU-1 — `claude -p "echo test" --system-prompt /dev/null` or check Claude Code CLI docs for system-prompt override flag
2. **T-next-2:** Write one-shot-researcher profile (`agents/dispatch/profiles/one-shot-researcher.md`) using confirmed delivery mechanism
3. **T-next-3:** Update `fw termlink dispatch` to accept `--profile` flag
4. **T-next-4:** Test on a real batch dispatch (next A5 batch worker) and measure actual token savings (validates A-4)

---

## Dialogue Log

Per C-001 extension, substantive exploratory conversations get logged here before the session ends. Structured findings capture WHAT was decided; this log captures HOW the reasoning evolved.

### 2026-04-11 — Research execution (this session)

**Trigger:** Parent session dispatched this agent to execute Phases 1-5 of the research plan.

**Course corrections and discovery moments during research:**

1. **T-909 reference was hypothetical, not a real incident.** The task description says "T-909 3-parallel risk-eval dispatch" but T-909 in the completed tasks is "Generate missing episodics for T-896, T-905..." The risk-eval example is illustrative, not a real dispatch. Flagged in Phase 1. Impact: the cost evidence is inferred, not measured. LBU-2 exists to address this.

2. **Discovery: TermLink dispatch volume has grown substantially since T-097.** T-097 (2026-02-17) cataloged 8 Task tool agent dispatches across 96 tasks. By 2026-04-11, we have 10+ TermLink dispatch events, with T-897/T-1071/T-1088 at 11 workers each. The framework has shifted from Task tool agents to TermLink as primary parallelism. This strengthens the case: TermLink dispatch at 11-parallel makes the token overhead a real operational concern, not hypothetical.

3. **I would ask the human if they were here:** "Does `claude -p` support a `--system-prompt` flag that overrides auto-loaded CLAUDE.md?" This is LBU-1, and it completely determines whether profiles work as token reducers or just as token adders. Without this, profiles can only add context (via `--append-system-prompt`), not remove the base ~12K CLAUDE.md. If the answer is no, the go/no-go changes to DEFER.

4. **Path A and Path B converge faster than expected.** Once you write 2-3 Path A profiles, the "separate repo" migration is just `git mv agents/dispatch/profiles/ ../agentic-profiles/`. The schema-first vs. build-first difference is really about when you commit to the schema, not what you build. A-3 evidence (prior schema-first rewrites) strongly favors Path A here.

5. **Governance floor is smaller than expected.** The task framing suggested "most of CLAUDE.md might be floor." Evidence: only ~575 tokens out of ~12,325 are true constitutional floor (Core Principle + Directives + Authority Model + Tier 0 + Choice Presentation). The rest is operational protocol for orchestrator sessions. One-shot workers don't need any of it except the output rules.

6. **The "45K" estimate in the problem statement is probably wrong.** CLAUDE.md is 9,481 words ≈ 12,325 tokens. Total system context including Claude Code base prompt + MCPs + memory might be 25-35K. The 45K may have been estimated at a time CLAUDE.md was larger, or is counting something that's not just CLAUDE.md. Impact: savings are still very real for 11-parallel batch dispatches, but the absolute numbers are different from the problem statement.

---

### 2026-04-11 — Task inception (pre-research reflection)

**Trigger:** Extended dialogue during T-1087/T-1088/T-1091 session. User saw T-909 3-parallel dispatch cost estimate (100-300K tokens) and asked whether orchestrator could tailor TermLink payload (CLAUDE.md + MCP) per task to balance cost against quality.

**Course corrections in the pre-research reflection:**

1. **User asked for reflection + playback before task creation.** Agent's first pass offered a single inception framed around a yes/no ("should we build profiles"). User pushed back: "where do we start deconstructing this, what are our options and considerations" — signalling that the question wasn't whether to build but how to think about the architecture space.

2. **User introduced the semantic/declarative split and the separate-repo framing unprompted.** Agent had been thinking about it as a framework-internal optimization. User reframed it as a portable artifact with semantic (purpose-level) and declarative (tool-name-level) layers, citing real-world precedent patterns (LSP, MCP, Ansible roles, GitHub shared workflows).

3. **Agent offered a three-way choice (coupled-first / schema-first / research-first).** User replied "not sure what i would be deciding for" — signalling the choice framing was under-articulated.

4. **Agent re-articulated the choice as "when do you commit to a schema — before or after you've built one."** This is the crux: both paths end in a portable profile repo; they differ in whether the schema is designed or emergent. User accepted this framing and picked Option 3 (research-first inception).

**Outcome:** T-1092 created as a research-only inception with explicit scope fence. Research artifact (this file) seeded with Phase 1-5 structure. No build work authorized under this task. Build tasks will be created as descendants if the Phase 5 recommendation is GO.

**Unresolved questions entering Phase 1:**
- Is the T-909 cost estimate representative or an outlier? Phase 1 evidence should tell us.
- Is the separate-repo portability constraint a real 2026 concern or a 2027+ aspiration? User asserted it but didn't cite a use case. Phase 3 should surface this.
- Is there a prerequisite (T-1064 orchestrator routing?) that blocks profile work? Phase 1 should catch this.

---

## References

- **T-909** — the 3-parallel risk-eval dispatch that triggered this research
- **T-1064** — orchestrator.route with task-type routing & model-aware specialist selection (potential upstream dependency)
- **T-818** — dispatch result persistence (related cost-control work)
- **T-503** — TermLink integration (the dispatch mechanism)
- **T-073** — 9-agent context explosion (canonical cost incident)
- **T-1087/T-1088** — session-concurrent work on budget-gate regression class (adjacent cost concern)
- **C-001** — research artifact first rule (source of this document's pattern)
- **CLAUDE.md §Sub-Agent Dispatch Protocol** — current dispatch discipline
- **`agents/dispatch/preamble.md`** — existing preamble hook, likely profile materialization point
