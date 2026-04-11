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

**Status:** Not started.

**Will update with:**
- Table of dispatch events (task ID, worker count, archetype, token cost if known, outcome)
- Empirical archetype list (3+ distinct roles)
- Anchoring examples — especially T-073 (9 agents → context explosion) and T-909 (current trigger)

---

## Phase 2 — CLAUDE.md audit (what's worker-relevant vs orchestrator-only)

**Goal:** Walk every H2 section of CLAUDE.md. Classify each as worker-relevant / orchestrator-only / constitutional-floor / conditional. Estimate token weight per bucket. Sketch a minimal worker payload.

**Status:** Not started.

**Will update with:**
- Classification table (section → bucket → token estimate → rationale)
- Bucket totals (how many tokens survive a minimal profile)
- Sample minimal payload sketch — NOT a real file, a conceptual map

---

## Phase 3 — Schema side-by-side (Path A vs Path B sketches)

**Goal:** Sketch both architectures for the same concrete example (risk-eval). Make what each path locks in and defers explicit. Do NOT choose yet.

**Status:** Not started.

**Will update with:**
- Path A sketch (build-first, `agents/dispatch/profiles/risk-eval/` inside framework)
- Path B sketch (schema-first, separate `agentic-profiles` repo from day 1)
- Divergence table — what's the same, what's different, where is the commitment cost concentrated in each path

---

## Phase 4 — Governance floor (what must never be stripped)

**Goal:** Enumerate the items that MUST ship to every worker regardless of profile. For each: state what breaks if stripped, cite a real incident that validates the need.

**Status:** Not started.

**Will update with:**
- Floor list with justification per item
- Flagged items where I'm uncertain ("this probably needs to stay but I can't cite a real failure")
- Explicit non-floor list — things that ARE in CLAUDE.md but are honestly not needed by any worker we've seen

---

## Phase 5 — Recommendation

**Goal:** Synthesize the above into a single recommendation with cited evidence.

**Status:** Not started.

**Will contain at completion:**
- **Recommendation:** GO Path A / GO Path B / NO-GO / DEFER
- **Rationale:** Why, citing evidence from phases 1-4
- **Evidence:** Bullet list referencing specific findings
- **Would change my mind if:** Conditions under which the recommendation flips

---

## Dialogue Log

Per C-001 extension, substantive exploratory conversations get logged here before the session ends. Structured findings capture WHAT was decided; this log captures HOW the reasoning evolved.

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
