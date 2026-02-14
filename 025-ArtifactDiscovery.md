# Artifact Discovery & Human Access — Design Document

> This document captures the design thinking for making framework artifacts discoverable
> and accessible to human users. It evolves through dialogue before any building begins.

---

## The Problem

The framework generates rich artifacts across 8+ categories (tasks, episodic memory,
handovers, project memory, specs, agent docs, audits, observations, gaps). But a human
user cannot easily:

- **Find** what exists without knowing the file structure
- **Browse** artifacts by topic, timeline, or relationship
- **Search** across artifact types for a concept or decision
- **Understand** the big picture without reading dozens of files
- **Navigate** from high-level goals down to implementation details

The artifacts exist. The knowledge is captured. But **access is locked behind
filesystem knowledge** — the opposite of the Usability directive.

---

## Why This Matters

This is not a cosmetic enhancement. It's instrumental to human-AI collaboration:

1. **Human sovereignty requires visibility** — You can't govern what you can't see
2. **Learning loops need human input** — Patterns and decisions need human review to
   graduate, but humans can't review what they can't find
3. **Cross-session continuity** — Handovers help the AI continue; nothing helps the
   human re-orient
4. **Trust through transparency** — The framework tracks everything, but if the human
   can't access it, tracking is theater

---

## Artifact Taxonomy

### Current Artifacts

| Category | Purpose | Format | Count | Discovery Path |
|----------|---------|--------|-------|----------------|
| Tasks | Work units with full history | MD + YAML frontmatter | 42 | `fw task list` (doesn't exist) |
| Episodic Memory | Condensed task summaries | YAML | 42 | None — raw file access |
| Handovers | Session continuity docs | MD | 14 | `cat .context/handovers/LATEST.md` |
| Decisions | Architectural choices | YAML | In decisions.yaml | None — raw file access |
| Learnings | Reusable knowledge | YAML | In learnings.yaml | None — raw file access |
| Patterns | Failure/success patterns | YAML | In patterns.yaml | `fw healing patterns` |
| Practices | Graduated principles | YAML | In practices.yaml | None — raw file access |
| Gaps | Deferred decisions | YAML | 6 | `fw gaps` |
| Specs | Philosophy & design | MD | 6 | None — know the filenames |
| Agent Docs | Agent capabilities | MD + bash | 9 | None — know the paths |
| Audits | Compliance snapshots | YAML | 2 | `fw audit` (runs new one) |
| Observations | Quick notes | YAML | inbox.yaml | `fw note list` |

### Emerging / Missing Artifacts

| Potential | Purpose | Exists? |
|-----------|---------|---------|
| Epics / Features | Group related tasks into higher-level goals | No |
| Roadmap | Where are we going? | Implicit in handovers |
| Changelog | What changed when? | Git log only |
| Architecture map | How components relate | No |
| Index / TOC | Entry point to everything | No |

---

## Discovery Modes

### A. Browse — "Let me scan what exists"

A human wants to open one thing and see the landscape. Options:
- Table of contents / index file
- Dashboard (terminal or web)
- `fw status` with rich output
- Tree view of artifacts with descriptions

### B. Search — "Find me things about X"

A human has a question and wants to find relevant artifacts across types:
- "What did we decide about enforcement?" → decisions.yaml + task logs + specs
- "What went wrong with the pre-push hook?" → patterns, episodic, handovers
- Keyword search vs. semantic search vs. structured query

### C. Summarize — "Give me the big picture"

A human wants synthesis, not raw data:
- Project health dashboard
- Timeline of decisions and milestones
- "Where are we?" narrative

### D. Navigate — "Show me the hierarchy"

A human wants to understand structure and relationships:
- Goals → Features → Tasks → Decisions
- Spec → Implementation → Tests → Learnings
- Session → Handover → Next session

---

## The Asymmetric Access Problem

The AI can grep/read/traverse all artifacts in seconds. The human cannot. This
asymmetry is not a bug — it's the fundamental design constraint.

**Current state:** A question like "why did we choose commit-msg hooks?" takes
the AI ~3 seconds (search decisions.yaml, cross-reference T-013, check patterns).
For the human: 5+ file opens, requires knowing the filesystem layout.

**Implication:** Human sovereignty diminishes as artifacts accumulate, unless
discovery keeps pace. At 42 tasks this is manageable with memorization. At 200
tasks on a real project, it's impossible.

### Three Access Layers (All Required)

| Layer | Purpose | Works Without AI? | Example |
|-------|---------|-------------------|---------|
| **AI as interface** | Natural language queries, cross-referencing, narrative synthesis | No | "Why did we choose commit-msg hooks?" |
| **CLI commands** | Structured, predictable, browsable views | Yes | `fw decisions`, `fw timeline` |
| **Raw files** | Full sovereignty backstop, forensics | Yes | `.context/project/decisions.yaml` |

**Core principle: CLI handles structured/finite queries. AI handles open-ended/cross-cutting ones. Neither replaces the other.**

---

## Three-Layer Discovery Model (Initial Analysis → evolved to Four-Layer Architecture below)

### Layer 1: Dashboard (EXISTS)
> "Is everything okay? What's the current state?"

One-screen overview. Numbers, status, health.
- `fw metrics` — project statistics
- `fw resume quick` — one-liner state
- `fw audit` — compliance check

**Verdict:** Adequate. No changes needed.

### Layer 2: Structured Summaries (MISSING — this is the gap)
> "What decisions have we made? What have we learned? What's the project story?"

Topical views. Each command shows one dimension in human-readable form.
- `fw decisions` — all decisions with rationale
- `fw learnings` — accumulated knowledge
- `fw patterns` — failure/success patterns
- `fw practices` — graduated principles
- `fw task list` — all tasks, filterable
- `fw task show T-XXX` — episodic summary for a task
- `fw timeline` — chronological project narrative
- `fw search <keyword>` — cross-artifact keyword search

**Verdict: This is where all investment should go.** It's the critical missing
piece between "everything is fine" (Layer 1) and "here are 180 files" (Layer 3).

### Layer 3: Raw Files (EXISTS)
> "Show me absolutely everything about T-033."

Full detail. Every field, timestamp, update log.
- `.tasks/completed/T-033-*.md`
- `.context/project/decisions.yaml`
- `.context/episodic/T-033.yaml`

**Verdict:** Exists for free. No tooling needed.

---

## Design Decision: Task Hierarchy

### Analysis of Options

| Option | Description | Verdict |
|--------|-------------|---------|
| **Flat + controlled tags** | Keep flat, add tag vocabulary | **Recommended** |
| **Two-level (epics/tasks)** | Group under ~10 epics | Rejected — forces false single-parent |
| **Full hierarchy** | Epics → Features → Tasks | Rejected — severe over-engineering |
| **Relationship graph** | Flat + typed edges | **Recommended (complement to tags)** |

### Why Not Hierarchy?

The actual data disproves hierarchy:
- T-014 (improve audit) is simultaneously about enforcement, quality, audit, and antifragility
- T-016 (episodic quality checks) is both Context Fabric and Enforcement
- T-020 (resume agent) is both Core Agents and Context Fabric
- Any single-parent hierarchy would be a lie

42 tasks with a single owner is comfortably navigable without hierarchy. Even at
100 tasks, well-tagged flat lists with relationships are more flexible than forced
trees. Hierarchy becomes necessary at ~200+ tasks or multiple human contributors.

### Recommended: Flat + Controlled Tags + Relationship Graph

**Controlled Tag Vocabulary (4 dimensions):**
- **Component:** context-fabric, audit, git-agent, healing-loop, cli, observation, handover, resume, metrics
- **Directive:** D1-antifragility, D2-reliability, D3-usability, D4-portability
- **Activity:** bootstrap, experiment, fix, refactor, specification, integration
- **Practice:** P-001 through P-007

**Relationship Types (5, from episodic data):**
- `spawned` — parent created child task (T-001 → T-002, T-003, T-004, T-005)
- `blocked` — prerequisite relationship (T-005 blocked T-006, T-007)
- `absorbed` — merged into larger task (T-013 absorbed T-003, T-004)
- `fix-for` — NEW: test→fix relationship (T-028 fixes T-025 findings)
- `informed-by` — NEW: learning transfer (T-014 informed by L-002 from T-013)

**Themes (Computed, Not Stored):**

Instead of storing epics, compute them from tags on demand:
```
fw task list --component context-fabric
```

The 42 tasks naturally cluster into ~8 themes:
1. Foundation & Vision (T-001, T-009, T-010, T-011, T-038)
2. Task Traceability & Enforcement (T-003, T-004, T-013, T-014, T-024, T-031)
3. Context Fabric & Memory (T-005, T-006, T-015, T-016, T-017, T-018)
4. Agents & CLI (T-002, T-012, T-020, T-023, T-033, T-034, T-035, T-037)
5. Healing & Learning (T-007, T-025, T-026, T-027, T-028)
6. Experiments & Validation (T-021, T-022, T-029, T-030, T-008)
7. Operational Improvements (T-032, T-036, T-039, T-040, T-041)
8. Governance Meta (T-042)

---

## Design Decision: Episodic Memory as Primary Discovery Layer

### Finding: Episodics Are Richer Than Tasks

| Field | In Episodic | In Task File |
|-------|-------------|-------------|
| Structured summary | Yes (narrative) | Brief description only |
| Outcomes list | Yes (bullet points) | Acceptance criteria only |
| Challenges with resolution | Yes | Buried in Updates log |
| Decisions with rationale | Yes (structured) | Buried in Updates log |
| Alternatives rejected | Yes | No |
| Artifacts created/modified | Yes (file lists) | No |
| Related tasks (typed) | Yes (blocked/absorbed/spawned) | No |
| Tags (retrieval-optimized) | Yes (richer than task tags) | Partial |

**Decision: The episodic layer should be the primary data source for discovery
commands.** Task files remain the operational record; episodics are the discovery
interface.

### Missing: Episodic Index

Each episodic file is standalone. No aggregate view exists. A generated
`episodic-index.yaml` would enable all discovery queries without reading 42 files:

```yaml
- id: T-005
  name: "Implement Context Fabric foundation"
  component: context-fabric
  tags: [infrastructure, context-fabric, D1, D2]
  outcome: success
  blocked: [T-006, T-007]
  decisions: 4
  challenges: 1
  artifacts_created: 17
  completed: 2026-02-13
```

---

## Design Decision: Human Oversight Tiers

### Tier 1: Must See (Sovereignty Requires It)
- **Decisions** — Constrain future work. Human must review independently.
- **Current state** — LATEST.md + fw resume. Already works.
- **Gaps** — Deferred decisions with triggers. `fw gaps` exists.
- **Audit results** — Already produces human-readable output.

### Tier 2: Should See (Trust But Verify)
- **Learnings** — What the system "learned." Human should validate.
- **Patterns** — Operational intelligence. Periodic review.
- **Task history by area** — "What work on enforcement?"
- **Episodic summaries** — Condensed task histories.

### Tier 3: Available But Not Routine
- Raw task files, individual handovers, working memory, bypass log.
- No tooling needed — filesystem access suffices.

---

## Missing Cross-References (Discovered)

| Link | Current State | Gap |
|------|--------------|-----|
| Decisions → Directives | `005-DesignDirectives.md` has directive refs; `decisions.yaml` does NOT | Add `directives_served` field |
| Gaps → Directives | `gaps.yaml` has `spec_reference` but no directive reference | Add `directive` field |
| Tasks → Specs | No `implements` field in task frontmatter | Consider adding |
| Practices → Applications | `applications: 0` everywhere | Track when practices are cited |
| Two decision stores | 12 architectural (in 005) + 8 operational (decisions.yaml) | Reconcile or cross-reference |
| Open questions → Resolutions | Free-text in Vision.md, not machine-readable | Structured registry or links |

---

## Web UI Pages (Full Set)

### Navigation Structure

Top-down: Project → Directives → Specs → Decisions → Tasks → Outcomes

```
/                    Dashboard (project health, success stage, stats)
/project             Foundational documents hub
/project/:doc        Single document (rendered markdown + related artifacts)
/directives          The 4 directives — traceability hub
/timeline            Session narrative + expandable tasks
/tasks               Filterable task list (browse, groom)
/tasks/:id           Task detail (episodic + raw task)
/decisions           Unified decision log (architectural + operational)
/learnings           Knowledge base (learnings, patterns, practices)
/gaps                Gap register with trigger status
/search              Cross-artifact keyword search
```

### Page Details

| Page | Purpose | Data Source | Read/Write |
|------|---------|-------------|------------|
| `/` | Project overview: vision summary, success stage, active work, key stats | Vision.md, metrics, working memory | Read |
| `/project` | List all foundational docs with description and status | `0XX-*.md`, `FRAMEWORK.md` | Read |
| `/project/:doc` | Rendered markdown + sidebar: related decisions, tasks, gaps for this spec | Spec file + cross-references | Read |
| `/directives` | Each directive → practices, decisions, experiments, gaps that serve it | directives.yaml + cross-refs | Read |
| `/timeline` | Session-by-session: narrative prose + expandable task list + episodic detail | Handover session_narrative + episodics | Read |
| `/tasks` | Filterable by component, directive, type, status. Sortable. | Episodic files (on-the-fly) | Read + edit (priority, tags) |
| `/tasks/:id` | Full episodic summary + raw task content | episodic/T-XXX.yaml + task file | Read + status via fw CLI |
| `/decisions` | All decisions (architectural + operational) linked to directives | decisions.yaml + 005 decision log | Read |
| `/learnings` | Learnings, patterns, practices — tabbed or sectioned | learnings.yaml, patterns.yaml, practices.yaml | Read |
| `/gaps` | Gap register with severity, trigger status, evidence | gaps.yaml | Read + edit severity, evidence |
| `/search?q=` | Keyword search across all YAML + MD artifacts | All files | Read |

### The Directives Page — Traceability Hub

This is the strategic entry point. For each directive:

```
D1: Antifragility — "System strengthens under stress"
  ├── Practices: P-001, P-003, P-005, P-007
  ├── Decisions: AD-003, AD-005, D-003, D-006
  ├── Experiments: E-003 (PASS), E-005 (PASS)
  ├── Gaps: G-005 (watching)
  └── Tasks: T-001, T-007, T-025, T-036... (tagged D1)
```

One click from a directive → everything that serves it.

### Foundational Documents

| Document | Content |
|----------|---------|
| `001-Vision.md` | Problem, vision, success criteria, open questions |
| `005-DesignDirectives.md` | The 4 directives, design principles, decision log |
| `010-TaskSystem.md` | Task lifecycle, statuses, enforcement tiers |
| `011-EnforcementConfig.md` | Tier definitions, bypass model |
| `015-Practices.md` | Practice system, graduation pipeline |
| `020-Experiments.md` | Experiment protocol, results |
| `025-ArtifactDiscovery.md` | This design document |
| `FRAMEWORK.md` | Provider-neutral operating guide |

---

## fw CLI Commands (Complement to Web UI)

CLI commands serve as data layer, automation interface, and sovereignty backstop.

### Priority 1: Must Have

| Command | What It Does |
|---------|-------------|
| `fw serve` | Start web UI server on localhost |
| `fw task list` | All tasks, filterable |
| `fw decisions` | All decisions with rationale |
| `fw timeline` | Structured timeline (CLI equivalent of web timeline) |

### Priority 2: Should Have

| Command | What It Does |
|---------|-------------|
| `fw learnings` | All learnings with context |
| `fw patterns` | Failure/success/workflow patterns |
| `fw practices` | Graduated principles |
| `fw task show T-XXX` | Episodic summary for a task |
| `fw search <keyword>` | Cross-artifact keyword search |

### Priority 3: Nice to Have

| Command | What It Does |
|---------|-------------|
| `fw audit --trend` | Pass/fail trend over recent audits |
| `fw handover list` | All handovers with summaries |
| `fw trace T-XXX` | All artifacts connected to an entity |

---

## Design Principles

1. **Progressive disclosure** — Overview first, drill down on demand
2. **No dead ends** — Every artifact links to related artifacts
3. **Files are the source of truth** — Web UI reads/writes YAML/MD, no separate database
4. **Agent-generated, human-consumed** — AI creates artifacts; human browses via web UI
5. **Zero-config discovery** — `fw serve` is the only command needed for web access
6. **AI-independent** — Web UI works without AI running
7. **Simple things simple, complex things possible** — Web UI for browse/groom, AI for open-ended queries
8. **Writes respect the pipeline** — Safe fields (priority, tags) can be written directly; dangerous fields (status) must route through `fw` CLI

---

## Four-Layer Architecture (Revised)

```
AI conversation  →  open-ended queries ("why did we...?")
Web UI           →  browse, filter, groom (human oversight mode)
CLI commands     →  structured queries, automation, write operations
Raw files        →  sovereignty backstop, forensics
```

### Human Workflow Split

| Mode | Interface | Activities |
|------|-----------|------------|
| Working | CLI + AI | Building, executing, progressing through sessions |
| Oversight | Web browser | Monitoring, reviewing, grooming, stepping back |

### Write-Back Safety Model

| Field | Write Method | Risk |
|-------|-------------|------|
| `priority`, `tags`, `owner` | Direct YAML edit | Safe — nothing reads programmatically |
| `status` | Must call `fw task update` | Triggers healing, file moves, episodic generation |
| `description`, `name` | Direct YAML edit | Low risk — audit checks description length |
| Episodic files | Read-only from web UI | YAML serializers strip comments |
| Gaps `severity`, `evidence_collected` | Direct YAML edit | Safe |
| Gaps `trigger_check.check` | Read-only | Contains executable shell commands |
| Observation `status` | Direct for dismiss; `fw note promote` for promotion | Promotion creates tasks |

---

## Technology Decision: Python + htmx

**Decision:** Lightweight web UI using Python (Flask/FastAPI) backend with htmx frontend.

**Rationale:**
- Python already in the stack (audit, handover use it) — no new language dependency
- htmx is a single 14kb JS file — no build step, no npm, no node_modules
- Server-rendered HTML — all logic in Python, htmx handles interactivity
- Interactive filtering, inline editing, live partial updates — zero JS framework
- Single entry point: `fw serve` starts everything
- Aligns with D4 (portability) — Python + one small JS file

**Architecture:**
```
fw serve  →  Python server on localhost:3000
              ├── /                      → dashboard (project health, active work)
              ├── /tasks                 → task list (filterable, sortable)
              ├── /tasks/:id             → task detail (episodic summary + raw task)
              ├── /decisions             → decision log (both stores, unified)
              ├── /learnings             → learnings + patterns + practices
              ├── /gaps                  → gap register with trigger status
              ├── /timeline              → chronological project narrative
              ├── /search?q=keyword      → cross-artifact search
              ├── PATCH /api/task/:id    → safe field edits (priority, tags, owner)
              ├── POST /api/task/:id/status → routes through fw task update
              └── static/htmx.min.js     → single JS dependency
```

**Alternatives rejected:**
- Pure CLI commands — not frictionless for browse/groom workflows
- Single HTML file — no write-back, static snapshot
- Node.js — adds language dependency
- Full SPA (React/Vue) — over-engineering, build toolchain, violates simplicity

---

## What NOT to Build

1. **Separate database** — YAML/MD files ARE the database. No sync problem.
2. **Auto-generated documentation files** — Creates sync drift. Read on demand.
3. **Query DSL** — `--type build` flags are sufficient. Complex queries go to the AI.
4. **AI-dependent features** — Web UI must work without AI running.
5. **Heavy frontend framework** — Keep it lightweight. The data is small.

---

## Human Personas

### Persona A: The Returning Owner
> "I left for a week. What is the shape of what we built?"

Needs: `fw timeline`, `fw decisions`, LATEST.md
Currently served: Only LATEST.md

### Persona B: The Evaluator
> "Should I adopt this framework? What actually works vs. what's aspirational?"

Needs: `fw timeline`, `fw decisions`, `fw gaps`, Vision.md
Currently served: Must know which files to read

### Persona C: The Inheritor
> "I'm taking over this project. What do I need to know?"

Needs: `fw timeline`, `fw decisions`, `fw learnings`, `fw patterns`
Currently served: Not at all — most critical gap

---

## Collaboration Mode Matrix

| Mode | Human Need | Current State | Gap |
|------|-----------|---------------|-----|
| Human directs, AI executes | See existing tasks, avoid contradicting decisions | Must browse filesystem | `fw task list`, `fw decisions` |
| Human reviews, AI proposes | Understand audit findings, healing suggestions | Terminal output works | Adequate |
| Human explores, AI assists | "Why did we...?" questions | Works when AI is running | `fw search` as fallback |
| AI-only between sessions | Verify what happened | Handover docs | Adequate |
| Human returns after absence | Full re-orientation | Only LATEST.md | `fw timeline` |

---

## Open Design Questions (For Discussion)

### Q1: Episodic Index — Generated Once or Recomputed? — DECIDED

**Decision: Computed on-the-fly. No index file.**

42 files is trivial to parse. Even at 200 tasks, YAML parsing takes <2s.
Don't build infrastructure for scale we don't have (P-001). If it becomes
slow, add caching then.

### Q2: Should `fw timeline` Be Narrative or Structured? — DECIDED

**Decision: Both — structured with expandable summaries + session narrative.**

The web timeline has three levels of progressive disclosure:

1. **Collapsed** — Session date + task count (scan all sessions at a glance)
2. **Expanded session** — Session narrative (2-3 para prose) + task list with tags
3. **Expanded task** — Full episodic summary (outcomes, decisions, challenges)

Session narratives are generated at session end (Approach B) — stored in handover
as `session_narrative` field. Generated once by AI while context is fresh, read
forever. No AI needed at view time.

For handovers created before this feature, fallback to stitching existing
fragments (handover "Where We Are" + episodic summaries).

CLI equivalent: `fw timeline` shows structured list (level 1+2 without narrative).
The web UI is the primary narrative experience.

### Q3: How to Reconcile the Two Decision Stores? — DECIDED

**Decision: Cross-reference. Unified view in web UI, separate files underneath.**

Conceptual hierarchy:
```
DIRECTIVES (constitutional, foundational — D1-D4)
  │ inform / constrain
  ▼
DECISIONS (operational interpretations of directives)
  ├── Design-time decisions (the 12 in 005-DesignDirectives.md)
  └── Task-time decisions (D-001 to D-008 in decisions.yaml)
```

All decisions are interpretations of directives applied to specific contexts.
The distinction is *when* they were made, not *what level* they operate at.

New directives CAN emerge from operational work — promoted up to 005 as a
graduation event (e.g., D5). This is rare, not routine.

**Changes needed:**
1. Formalize directive IDs in structured YAML (directives.yaml or in 005):
   ```yaml
   directives:
     - id: D1
       name: Antifragility
       statement: "System strengthens under stress"
       last_reviewed: 2026-02-14
   ```
2. Add `directives_served: [D1, D2]` field to decisions.yaml entries
3. Add IDs to the 12 architectural decisions in 005 (AD-001 through AD-012)
4. Web UI renders both stores as one unified view with type label
5. No changelog for directives — git history suffices for 4 items
6. `last_reviewed` date on each directive for governance

### Q4: Tag Backfill Scope — DECIDED

**Decision: Backfill episodic files only. Leave task frontmatter as-is.**

- Episodics are the primary discovery data source — web UI reads these
- The `tags` field already exists on all 42 episodic files
- Normalize to controlled vocabulary (component, directive, activity, practice)
  in one automated agent pass
- Task frontmatter is the operational record — don't touch retroactively
- Future tasks: controlled tags applied at episodic generation time

### Q5: What Triggers `fw timeline` Freshness? — DECIDED

**Decision: No trigger needed. Always fresh by definition.**

Timeline reads episodic summaries + handover session_narratives. Both are
write-once artifacts — created when work completes, never modified after.
New task → new episodic file → timeline includes it on next view.

Build-time change needed: handover process generates `session_narrative` field.

---

## Security Model

### Network Binding
- `fw serve` binds to `127.0.0.1` only (localhost). Never `0.0.0.0`.
- No authentication required for localhost-only access.
- If remote access is ever needed, it would require a reverse proxy with auth (not in scope).

### Input Validation (Critical)
- `POST /api/task/:id/status` invokes `fw task update` as a subprocess.
  The status value MUST be validated against an allowlist before shell execution:
  `[captured, refined, started-work, issues, blocked, work-completed]`
  **No user input is passed to the shell unvalidated.** This prevents command injection.
- `PATCH /api/task/:id` field values are sanitized: no shell metacharacters in
  tags, priority must be from allowlist `[low, medium, high, critical]`.
- Task IDs must match pattern `T-\d{3}` before any file path construction.

### CSRF Protection
- All write endpoints (PATCH, POST) require CSRF tokens.
- Flask-WTF or manual token in htmx headers (`hx-headers`).

### Markdown Rendering
- Rendered markdown is sanitized to prevent XSS (strip raw HTML tags).
- Use a safe markdown renderer or explicit HTML sanitization.

---

## Error Handling

### YAML Parse Errors
- If a YAML file is malformed, the page shows a warning banner with the
  file path and error message. Other artifacts on the page render normally.
- Never crash the server on bad input data.

### Missing Files
- If an expected file doesn't exist (e.g., `gaps.yaml`, empty `.context/episodic/`),
  show an empty state with explanation ("No gaps registered yet").
- The dashboard degrades gracefully: missing data shows "—" not an error.

### Write-Back Failures
- If a YAML write fails (permissions, locked file), show error to user
  with the specific failure reason. Do not leave a partially-written file.
- Use write-to-temp-then-rename pattern for atomic writes.

### Subprocess Failures
- If `fw task update` fails, show stderr output to the user in an error banner.
- Do not silently swallow failures.

### Concurrent Access
- No file locking at this scale. Browser refresh is the update mechanism.
- If an agent modifies a file while the web UI is open, the next page
  load/htmx request picks up the change automatically (on-the-fly parsing).
- Explicit statement: **browser refresh is the live-update mechanism.** No
  WebSocket, no polling, no file watching.

---

## Dependencies (Pinned)

| Dependency | Purpose | Version Constraint |
|-----------|---------|-------------------|
| Python | Runtime | 3.8+ (matches existing framework usage) |
| Flask | Web framework | 3.x |
| PyYAML | YAML reading | 6.x |
| ruamel.yaml | Comment-preserving YAML writes | 0.18+ |
| markdown2 or Python-Markdown | Markdown → HTML rendering | Latest stable |
| Bleach or nh3 | HTML sanitization (XSS prevention) | Latest stable |
| htmx | Frontend interactivity | 2.x (single JS file, vendored) |
| Pico CSS or similar | Classless/minimal CSS | Latest (single CSS file, vendored) |

No npm. No build step. Dependencies installed via `pip install flask pyyaml ruamel.yaml markdown2 bleach`.

---

## htmx Patterns

### Partial vs. Full Page Rendering
- Flask checks for `HX-Request` header to distinguish htmx requests from full page loads.
- Full page request → renders base template with nav + page content.
- htmx request → renders only the HTML fragment (partial).
- This is established in T-045 (web foundation) as a base pattern all pages use.

### Expand/Collapse Pattern
```html
<!-- Collapsed session -->
<div hx-get="/timeline/session/S-2026-0213-1926"
     hx-target="this"
     hx-swap="outerHTML">
  ▸ 2026-02-13  Session S-2026-0213-1926  (8 tasks)
</div>

<!-- Server returns expanded HTML fragment with narrative + task list -->
```

### Inline Edit Pattern
```html
<!-- Display mode -->
<span hx-get="/api/task/T-043/edit/priority"
      hx-target="this"
      hx-swap="outerHTML">medium</span>

<!-- Edit mode (returned by server) -->
<select hx-patch="/api/task/T-043"
        hx-target="this"
        hx-swap="outerHTML"
        name="priority">
  <option>low</option>
  <option selected>medium</option>
  <option>high</option>
</select>
```

---

## Observations (Deferred Scope)

The observation inbox (`.context/inbox.yaml`) is included in the artifact taxonomy
and write-back safety model but is NOT included in the initial web UI page set.

**Rationale:** The inbox is currently small (2 dismissed observations) and has
working CLI support (`fw note list`, `fw note "text"`). Adding a web page for
observations is low-value until the inbox is actively used on a real project.

**Decision:** Defer. Add to T-049 scope if inbox grows, or create a follow-up task.
The search page (/search) WILL include inbox.yaml in its search scope.

---

## Relationship Visualization (Included in T-048)

The 5 relationship types (spawned, blocked, absorbed, fix-for, informed-by)
from episodic `related_tasks` data will be rendered on the `/tasks/:id` detail
page as a "Related Tasks" section with typed edges. No separate graph
visualization page — relationships are shown in context on each task's detail.

---

## Non-Functional Requirements

| NFR | Target | Applies To |
|-----|--------|-----------|
| Page load time | <2s at current scale (42 tasks, 14 sessions) | All pages |
| Graceful degradation | Pages work at 200 tasks (may be slower) | All pages |
| Search response | <3s across all artifacts | /search |
| Startup time | <2s to serving first request | fw serve |
| Error recovery | No server crash on malformed data | All pages |

---

## Practice P-008: Tasks Must Carry Executable Context

**Discovered during this design process.** The contrast between old tasks
(empty Design Record, no acceptance criteria) and new tasks (design authority,
key decisions, concrete criteria) revealed a critical pattern.

A task assigned to an agent must contain:
1. Link to authoritative design document
2. Specific relevant section references
3. Key decisions extracted (not just linked)
4. Concrete acceptance criteria as checkboxes
5. Explicit dependencies

**Enforcement:** Audit WARN (not FAIL) for build/spec tasks in started-work+
status that have empty Design Record or no acceptance criteria.

**Template:** `default.md` updated with guided prompts in HTML comments.

---

*This is a design document. No building until explicit human instruction.*
