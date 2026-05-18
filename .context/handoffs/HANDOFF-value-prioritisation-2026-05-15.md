---
handoff_id: HANDOFF-value-prioritisation-2026-05-15
version: 1
supersedes: null
topic: "Business Value Points — directive-weighted prioritisation for tasks and arcs"
research_dates: 2026-05-15..2026-05-15
researcher: "Claude (Anthropic) + Dimitri Geelen"
intended_workflow: inception
intended_scope: "An inception that introduces directive-weighted scoring for both tasks and arcs, with a TermLink-based task estimator, primary-agent arc-scoped driver suggestion, the draft→in-progress driver-decision gate, and a Watchtower quadrant view."
blast_radius: project
decided_by_overall: jointly
human_decisions_pending: [Q1, Q2, Q3, Q4]
depends_on_handoffs: [HANDOFF-arc-grooming-2026-05-15]
related_handoffs: []
constraints:
  - "Cannot proceed until HANDOFF-arc-grooming-2026-05-15 has reached §5: GO AND its first deliverable (the arc-grooming inception decide-go transition, with arc_id field and four-state lifecycle landed) has shipped."
  - "Must preserve §ACD discipline (--demo on close, agent-gate under $CLAUDECODE=1) untouched. The new fw arc approve-driver verb must follow the same shape: required justification of minimum length, same agent-gate, same audit-log conventions."
  - "BVP is advisory, not gating. Scoring does not block task save, task promotion, or arc creation. The only gate this handoff introduces is the draft→in-progress driver-decision gate, which is itself satisfiable via --none --justification."
  - "Human-confirmed bvp_scores are sticky. The estimator never overwrites a confirmed score — it can only write a v2 delta into bvp_scores_proposed: for human review."
non_goals:
  - "Replacing fw arc close demo discipline. BVP is additive; --demo on close stays."
  - "Cost estimation from anything other than the composite of blast_radius + tier + historical effort. No new cost inputs."
  - "Cross-repo value drivers. Single-repo scope only."
  - "Making per-task BVP confirmation a Tier 1 block. BVP is advisory."
  - "Touching the arc lifecycle state machine itself — that work is owned by HANDOFF-arc-grooming-2026-05-15. This handoff only enforces what the draft state means (the driver-decision gate)."
related_tasks:
  - T-1641   # umbrella-task rethink (originating context for arcs, indirectly relevant)
  - T-1653   # arcs-as-first-class (the design anchor for arcs)
  - T-1668   # §ACD discipline (precedent for evidence-or-justified-absence gates)
  - T-1816   # audit YAML-parse hardening (relevant for new field acceptance)
related_files:
  - lib/arc.sh
  - web/blueprints/arcs.py
  - agents/audit/audit.sh
  - CLAUDE.md
  - FRAMEWORK.md
  - 005-DesignDirectives.md
  - .tasks/templates/default.md
  - .context/arcs/
  - policy/                                # new directory: value-drivers.yaml, bvp-scoring-rubric.md
  - .context/bvp-weight-history.yaml       # new
  - .context/audits/arc-scoped-driver-bypass.jsonl   # new
  - .context/audits/bvp-auto-promote-log.yaml        # new
  - agents/termlink/                       # new BVP estimator worker location (likely)
---

## 1. TL;DR

The four Constitutional Directives (Antifragility, Reliability, Usability, Portability) are referenced in CLAUDE.md and FRAMEWORK.md as priority-ordered values but have no machine-readable scoring layer — they cannot be used to drive prioritisation, promotion, or resource allocation decisions. This handoff recommends GO-WITH-MODIFICATIONS on an inception that introduces directive-weighted Business Value Points (BVP) scoring for both tasks and arcs, with a TermLink estimator for tasks and primary-agent suggestion for arc-scoped drivers, gated by HANDOFF-arc-grooming-2026-05-15 landing first. First deliverable: file the inception task once arc-grooming's first deliverable (inception decide-go) has shipped; the inception resolves Q1-Q4 with the human and produces the constituent build-task slices.

## 2. Problem framing

Today, prioritisation across tasks happens through horizon (now/next/later) and arc focus — neither of which scores work against the four Constitutional Directives. There is no mechanism to rank arcs against each other; `fw arc list` returns alpha-by-filename. Within an arc, global directive scoring would go flat because constituent tasks are internally homogeneous, so without arc-scoped drivers an arc with >5 tasks cannot order its own constituents. The four directives are referenced in CLAUDE.md prose and in some learning narratives, but have no machine-readable scoring layer — they cannot be used to drive prioritisation, promotion, or resource allocation decisions. The trigger to investigate now: the AEF self-assessment against the ACMM maturity model surfaced both the directive-scoring gap and the lack of arc-vs-arc ranking. A 2019 Geelen blog post on Business Value Points for backlog prioritisation provided a near-fit mechanic; this research adapts it to AEF's primitives and authority model.

## 3. Findings

### F1: AEF has four explicit Constitutional Directives, declared in priority order.

- **Evidence:** `FRAMEWORK.md` (fetched 2026-05-15) section "Four Constitutional Directives (Priority Order)" lists: 1. Antifragility, 2. Reliability, 3. Usability, 4. Portability. `README.md` repeats the same priority-ordering. `005-DesignDirectives.md` is the canonical home (per repository file tree).
- **Confidence:** high
- **Implication:** The four directives are the natural protected value drivers for any BVP scheme. They cannot be removed; their relative priority is part of the framework's constitution. Weights must reflect the declared priority order.
- **Polarity:** positive (substrate exists)

### F2: The directives have no machine-readable scoring scaffold today.

- **Evidence:** Confirmed via `grep -r "D1\|D2\|D3\|D4\|directive" policy/ .tasks/templates/ 2>/dev/null` returning no machine-readable enum, no scoring infrastructure, no per-task or per-arc directive field. Directives are referenced in CLAUDE.md prose and in some learning narratives, but never in frontmatter or YAML schemas.
- **Confidence:** high (the absence is comprehensive)
- **Implication:** BVP work is greenfield against this layer. There is no existing scoring data to migrate, no convention to break, no parallel mechanism to deprecate. The build creates the directives' first executable representation.
- **Polarity:** mixed (substrate is empty, which is good for greenfield work, but means the build creates a new abstraction the framework has to maintain)

### F3: Arc-vs-arc ranking is not addressed; current arc list is alpha-by-filename.

- **Evidence:** Per framework-agent briefing on Arc status: `fw arc list` produces an unsorted table (alpha-by-filename). There is no priority, weight, or comparison field on arcs today.
- **Confidence:** high
- **Implication:** Adding arc-level BVP is greenfield — no conflicting ordering scheme exists. Arc focus is single-pointer (`.context/working/arc-focus.yaml`), so a BVP system that wanted to suggest next-focus based on score would not collide with anything.
- **Polarity:** positive (clear runway)

### F4: Task BVP scoring and arc-scoped-driver suggestion differ on multiple dimensions, and benefit from different runtimes.

- **Evidence:** Reasoning trail (captured in §10): task scoring is continuous (every newly-ready task), statistical-rubric-based (low temperature, fixed rubric), reused thousands of times across project life, and benefits from preload (the rubric is the reusable state). Arc-scoped-driver suggestion is rare (≤10 events per year for an active project at AEF's pace), one-shot per arc, interpretive (requires reading prose: problem statement, scope, mechanic), and benefits from being close to the arc-creation conversation context rather than preloaded.
- **Confidence:** medium-high (the dimensions are clear; the cost analysis is reasoned-from-principles, not benchmarked)
- **Implication:** Two different agent runtimes for two different jobs. Task scoring → TermLink worker (preload pays). Arc-scoped-driver suggestion → primary agent (no preload benefit; arc-creation context is free).
- **Polarity:** positive (clarifies architecture decision)

### F5: Arc YAML schema is open — adding new fields does not require schema-loader changes.

- **Evidence:** Inherited from HANDOFF-arc-grooming-2026-05-15 F7: `web/blueprints/arcs.py:_read_arc` reads arbitrary fields; T-1816 audit YAML-parse validates well-formed-YAML, not schema. No schema enforcement currently rejects unknown fields. This finding is load-bearing for both handoffs; restated here for completeness.
- **Confidence:** high
- **Implication:** Adding `bvp_scores:`, `scoped_drivers:`, `proposed_scoped_drivers:` to arc YAML does not require coordinated schema upgrades. Same applies to adding `bvp_scores:`, `bvp_scores_proposed:`, `cost_estimate:` to task frontmatter, assuming the same property holds there (A2 in this handoff verifies).
- **Polarity:** positive

### F6: §ACD enforcement (`--demo` required on close, agent-gate under $CLAUDECODE=1) is the existing pattern for evidence-or-justified-absence gates.

- **Evidence:** Inherited from HANDOFF-arc-grooming-2026-05-15 F8: `lib/arc.sh:473-492` refuses `arc_close` without `--demo` or `--demo none --justification "<≥30 chars>"`. `lib/arc.sh:430-468` refuses close under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`. T-1668 §ACD Layer A and Layer B.
- **Confidence:** high
- **Implication:** The new `draft → in-progress` driver-decision gate follows the same shape — `fw arc approve-driver <id> <name> [--weight N]` for the affirmative case, `fw arc approve-driver <id> --none --justification "<≥30 chars>"` for the justified-zero case. Same `--i-am-human`/`--from-watchtower` agent-gate. Same audit-log convention (`.context/audits/arc-scoped-driver-bypass.jsonl`, mirroring `arc-bypass.jsonl`).
- **Polarity:** positive (reusable pattern reduces both implementation and cognitive cost)

### F7: AEF authority model maps cleanly onto the BVP mechanic's component roles.

- **Evidence:** `FRAMEWORK.md` "Authority Model" section: Human → SOVEREIGNTY, Framework → AUTHORITY, Agent → INITIATIVE. The BVP mechanic decomposes naturally: agents (TermLink estimator, primary agent) *propose* scores and drivers (Initiative); humans *confirm or override* via `fw bvp confirm` and `fw arc approve-driver` (Sovereignty); framework *enforces* that promotion / state transitions require confirmed scores (Authority).
- **Confidence:** high
- **Implication:** No new authority pattern is introduced. The BVP mechanic respects the existing model; agents never auto-approve, humans always have final say, framework gates structurally.
- **Polarity:** positive

### F8: Cost signals already exist in AEF — three sources can be composited.

- **Evidence:** Three usable signals per AEF's existing surface:
  - `fw fabric blast-radius` produces a structural cost measure (number of downstream components, transitive impact). Production-ready, per the `README.md` Component Fabric section.
  - Tier classification (Tier 0 / 1 / 2 / 3) via `check-tier0` and `policy/escalation-patterns.yaml`. Tier 0 commands cost human approval; Tier 2 is free. This is approval-cost, not labour-cost, but it's a real cost component.
  - `fw metrics` includes effort prediction sourced from `.context/episodic/` task durations. Partial maturity — the data is collected, prediction quality depends on having prior similar tasks.
- **Confidence:** high (the signals exist) / medium (their combinability into a single number is design-decision, not engineering-fact)
- **Implication:** Composite cost = `0.6 × normalize(blast_radius) + 0.3 × tier_weight + 0.1 × effort_estimate`, clamped to 0–9, with T-shirt fallback (S=2, M=4, L=6, XL=8) when blast radius is not yet computable. Weighted toward blast radius because it's reliable, auto-computed, and reflects actual delivery cost.
- **Polarity:** positive (reuses what exists)

### F9: AEF has a `Captured → In Progress → Issues → Work Completed` kanban for tasks.

- **Evidence:** `010-TaskSystem.md` (fetched) "Task Statuses (Lifecycle)" section — four statuses, validated transitions, `Captured` is the entry point.
- **Confidence:** high
- **Implication:** The BVP quadrant `high-value / low-cost` maps naturally to "auto-eligible for promotion from Captured → In Progress." This is where Dimitri's 2019 blog's "reserved budget for low-risk, low-cost, high-value work" idea lands in the AEF surface. Promotion is a real lifecycle event; quadrant membership is the natural gate.
- **Polarity:** positive (clean mapping to existing primitive)

### F10: Watchtower has an existing `/arcs` and `/arcs/<id>` surface; extension is preferable to net-new view.

- **Evidence:** `web/blueprints/arcs.py` (287 lines per framework-agent briefing) renders both the index and detail page. Arc list, arc detail, task filter via `/tasks?arc=<id>` chip.
- **Confidence:** high
- **Implication:** Watchtower work for BVP is mostly extension: new `/bvp` tab for the quadrant scatter + global-driver-weight sliders; additions to `/arcs/<id>` for arc BVP display, coherence warning, and `proposed_scoped_drivers` rendering. Building a parallel view from scratch would duplicate work.
- **Polarity:** positive (reuses existing structure)

## 4. Decisions made during research

### D1: Directives priority is expressed through weights, not lexicographic ordering — weights 9/7/5/3 for D1/D2/D3/D4.

- **Chose:** Weighted-sum BVP. D1 (Antifragility) weight 9, D2 (Reliability) weight 7, D3 (Usability) weight 5, D4 (Portability) weight 3. Free drivers get user-chosen weight 0–9. Total cap 9 drivers (4 protected + up to 5 free); add-one-drop-one when free slots are full.
- **Rejected:**
  - Strict lexicographic (sort by D1 desc, then D2 desc, etc.) — would mean a weak D1 score is uncompensatable by stacking D2-D4, which removes the flexibility BVP is meant to provide. Also: lexicographic ordering can't be expressed as a single comparable number, breaking quadrant maths.
  - Hybrid (weighted-sum, with a lexicographic override at large D1 deltas) — complexity-tax for a rule that probably rarely fires. Two scoring regimes are harder to reason about than one.
- **Why:** Weighted-sum is the cleanest expression of "directives lead but compensation is possible." Even gaps (9/7/5/3) keep the ordering clear while still letting a 5 on D4 (15 points) outweigh a 2 on D1 (18 points) in close cases. Matches Dimitri's 2019 BVP blog mechanic exactly.
- **Decided-by:** human
- **Supports:** F1, F2
- **Reversibility:** cheap (weights are values in `policy/value-drivers.yaml`; changing 9/7/5/3 to other defaults is a config edit)

### D2: Arc-vs-arc ranking uses global drivers only. Arc-scoped drivers exist but only affect within-arc task ranking.

- **Chose:** Arcs are scored against the 4 protected drivers + up to 5 global free drivers (the global driver vocabulary, max 9). Arc-scoped drivers (up to 3 approved per arc, weight ≤ 6) are *separate* and only affect task ranking within their owning arc.
- **Rejected:**
  - Arc-vs-arc ranking using global + per-arc drivers — would break the comparability of arc rankings (each arc would be scored against a different driver set).
  - Aggregated child-task BVP as the arc's score (sum or mean) — sum rewards "cramming an arc with low-value tasks," mean dilutes high-value arcs that include some housekeeping. Neither tracks what the arc itself is for.
- **Why:** Two different jobs: (a) which arc deserves focus, (b) which task within an arc gets picked up next. Job (a) needs comparability across arcs, which requires identical driver vocabularies — globals only. Job (b) needs in-arc differentiation, which globals can't provide (constituent tasks score similarly on globals because they all serve the arc's goal). Arc-scoped drivers regain that dimension at exactly the level where it's needed.
- **Decided-by:** human (rejected the aggregation framing during research)
- **Supports:** F3, F4
- **Reversibility:** cheap (driver schema is YAML; widening or narrowing scope is a schema and audit-rule edit)

### D3: Coherence between arc and its constituent tasks is a per-driver audit warning, not an aggregation input.

- **Chose:** Audit check: if an arc claims a directive score (e.g. D1=5) but ≥70% of its constituent tasks score that same directive ≤1, emit warning. Per-driver, not aggregated. Surfaced in `fw audit` and Watchtower arc detail page. Never modifies the arc's BVP.
- **Rejected:**
  - Aggregation (mean of child BVPs) as part of the arc's score — see D2 rejection.
  - Threshold of 100% mismatch — too strict, single outlier would never trip it.
  - Single aggregate coherence score — loses the per-driver signal that lets the human see *which* claim isn't supported.
- **Why:** Coherence is a sanity check on the human's arc-level scoring, not a ranking input. The signal needs to be specific ("arc claims D1=5, tasks don't support it") to be actionable.
- **Decided-by:** jointly (the rejection of aggregation came from the human; the per-driver shape was an agent proposal)
- **Supports:** F4
- **Reversibility:** cheap (audit check thresholds are configurable)

### D4: Task BVP estimator runs as a TermLink worker. Arc-scoped-driver suggestion runs on the primary agent.

- **Chose:** Two estimator runtimes. Task estimator (bvp-estimator) on TermLink — continuous, statistical, rubric-driven (`policy/bvp-scoring-rubric.md`), low temperature, writes to `bvp_scores_proposed:` on task frontmatter. Arc-scoped-driver suggester is the primary agent acting at arc creation time, reading the arc body (problem statement, scope, mechanic) and writing to `proposed_scoped_drivers:` in arc YAML.
- **Rejected:**
  - Both on TermLink — arc-scoped-driver suggestion would need to reload arc-creation context per call, which gives no preload benefit. There's no reusable state between two different arcs' suggestion events. Spinning up a worker for ~10 events/year is wasted infrastructure.
  - Both on primary agent — task scoring at ~thousand-events/year scale would either bog the primary agent down or run into determinism issues. The rubric-driven low-temperature mode is exactly what worker preload optimises for.
- **Why:** Different reasoning kind, different scale, different stability needs (statistical vs interpretive), different preload payoff. The split mirrors a deeper distinction: classifier vs collaborator. Run each where it fits.
- **Decided-by:** human (proposed and reasoned through the split during research)
- **Supports:** F4, F7
- **Reversibility:** medium (changing runtime would mean rewriting the agent's harness; the rubric and prompt are portable but the runtime infrastructure is not)

### D5: Arc-scoped driver suggestion happens AFTER arc body is filled in, BEFORE driver approval. Not at `fw arc create` time.

- **Chose:** Arc creation flow: (1) `fw arc create --headline-mechanic "..."` creates arc in `draft` state, (2) human (or primary agent under human direction) fills in arc body — problem statement, scope, mechanic, (3) primary agent reads the body and proposes any number of genuine arc-scoped drivers with rationales to `proposed_scoped_drivers:`, (4) human approves via `fw arc approve-driver` (or `--none --justification`), (5) on first approval (or justified --none), state flips `draft → in-progress`.
- **Rejected:**
  - Suggestion at `fw arc create` time — agent only has the headline mechanic, which is one sentence. Not enough context for meaningful suggestions; would generate plausible-but-hallucinated drivers.
  - Suggestion at first task attach — too late; the arc is already running without drivers, and the very purpose of the gate is to force the decision before work starts.
- **Why:** The agent needs to read the arc's prose to suggest meaningfully. The prose only exists after step 2. The gate exists to force a deliberate choice before work attaches. Timing: "near mid, nearer to the end of arc creation."
- **Decided-by:** jointly
- **Supports:** F4, F6
- **Reversibility:** cheap (the workflow is documented in CLAUDE.md / AGENTS.md, not encoded in CLI mechanics)

### D6: Agent proposes uncapped, human approves capped at 3.

- **Chose:** No suggestion count target. Agent proposes as many genuine arc-scoped drivers as actually surface from the arc body — could be 0, could be 10. Quality criterion: the agent must be able to write a one-sentence rationale for each, explaining what it differentiates that globals don't. Approval cap remains 3 (max 3 entries in `scoped_drivers:`).
- **Rejected:**
  - Hard suggestion cap (e.g. "suggest exactly 3") — would force the agent to manufacture drivers to hit the target, which is the failure mode this whole gate is meant to prevent.
  - No approval cap — would let `scoped_drivers:` grow unbounded, defeating the "if you need more than 3 you're over-decomposing" principle.
- **Why:** Asymmetry — agent generates freely, human prunes to ≤3. Healthy creative/curatorial split. Manufacturing drivers to look thorough is worse than proposing zero and recommending `--none`.
- **Decided-by:** human
- **Supports:** F4
- **Reversibility:** cheap (the suggestion-count discipline is documented in the agent's instructions; the 3-cap is enforced in `fw arc approve-driver`)

### D7: `proposed_scoped_drivers:` persists for the life of the arc. Re-suggestions append; they don't overwrite.

- **Chose:** Once written, `proposed_scoped_drivers:` is never removed by the framework. If the primary agent generates a new batch of suggestions later in arc life (e.g. when focus shifts), the new batch appends with timestamps rather than overwriting. Only `scoped_drivers:` is authoritative for scoring; `proposed_scoped_drivers:` is reference material.
- **Rejected:**
  - Clear on approval — would lose the suggestion as reference material if the human later wants to revisit which dimensions the agent originally surfaced.
  - Overwrite on re-suggestion — loses the original framing, which is the very thing that would be useful when focus shifts.
- **Why:** Not for audit. For reuse. When an arc's focus shifts mid-life, the agent's original suggestions (or a new batch) are a cheap starting point for re-deciding which dimensions now matter. The cost of persistence is one YAML field; the value is making `fw arc show-suggestions` useful months after the initial suggestion event.
- **Decided-by:** human (reframed agent's audit-trail framing to reference-material framing during research)
- **Supports:** F7
- **Reversibility:** cheap (the field is additive and idempotent)

### D8: Auto-promote from Captured → In Progress is OFF by default, opt-in via policy file with strict thresholds.

- **Chose:** Default behaviour: BVP system *flags* high-value / low-cost tasks as auto-eligible; humans choose to promote. Opt-in `auto_promote.enabled: true` in `policy/value-drivers.yaml` with thresholds `bvp_norm_min: 0.85`, `cost_max: 1`, `max_concurrent: 1`. Every auto-promotion writes to `.context/bvp-auto-promote-log.yaml`.
- **Rejected:**
  - On by default — crosses the authority-model line. Framework would be choosing what to work on, not enforcing a rule. Human-Sovereignty principle in F7 forbids this.
  - No auto-promote mechanism at all — gives no escape valve for the legitimate "narrow band of trivial work that doesn't deserve human attention per item" case Dimitri's 2019 blog calls out.
- **Why:** The auto-promote policy is itself a pre-authorisation by the human (editing `policy/value-drivers.yaml` is a deliberate act). The framework then enforces the pre-authorised rule. Sovereignty is exercised at policy-edit time, not at each task. Same pattern as Tier 0 destructive-command pre-approvals.
- **Decided-by:** jointly
- **Supports:** F7, F9
- **Reversibility:** cheap (the policy field is a single boolean + 3 numeric thresholds)

### D9: Weight changes are global and reactive — BVP is always computed live from current weights, never stored frozen.

- **Chose:** Weights live in `policy/value-drivers.yaml`. Any weight change re-ranks all tasks and all arcs immediately (no stored BVP_norm anywhere). Weight change events are audit-trailed in `.context/bvp-weight-history.yaml` (same shape as `arc-bypass.jsonl`): who, when, from→to, rationale. CLI verb `fw bvp weight --set Dn=N --rationale "..."` writes the change; agent-gate refuses under `$CLAUDECODE=1`.
- **Rejected:**
  - Storing frozen BVP per task — would mean every weight change requires a rewrite-all-tasks migration. Slow, and divergent state during the migration.
  - Allowing weight changes without rationale — would lose the why behind ranking shifts, which would baffle anyone reading the project history three months later.
- **Why:** The point of weights is reactivity. "Q2 reliability focus" should be expressible as `fw bvp weight --set D2=8 --rationale "..."` and have all rankings update. Storing frozen scores would make this expensive. The rationale field makes ranking shifts auditable, not mysterious.
- **Decided-by:** jointly
- **Supports:** F2, F7
- **Reversibility:** cheap (weight history is append-only; reverting a weight is another weight change with its own rationale)

## 4a. Assumptions

### A1: HANDOFF-arc-grooming-2026-05-15 will reach §5: GO AND its first deliverable (arc-grooming inception decide-go transition, with `arc_id:` field and four-state lifecycle landed) will ship.

- **Why we believe it:** That handoff has §5: GO with no blocking dependencies. The work it proposes is internally coherent, and the constraints/non-goals are sharp.
- **What breaks if false:** This entire handoff. The BVP work depends on the `arc_id:` field for task frontmatter, the `draft` state for the driver-decision gate, and the `abandoned` state for the LV/HC quadrant recommendation. None of those exist without arc-grooming landing.
- **How to test:** Check `docs/reports/HANDOFF-arc-grooming-2026-05-15.md` for current §5 verdict. Check `.context/arcs/arc-grooming.yaml` for `decision:` field reflecting `go`. Check `.tasks/templates/default.md` for `arc_id:`. Check `lib/arc.sh` for four-state lifecycle. The §11.5 dual-condition check on `depends_on_handoffs:` enforces this automatically.
- **Confidence:** high (the dependency is intentional and well-scoped)

### A2: Adding new task-frontmatter fields (`bvp_scores`, `bvp_scores_proposed`, `cost_estimate`) and new arc-YAML fields (`bvp_scores`, `scoped_drivers`, `proposed_scoped_drivers`) does not break audit YAML-parse.

- **Why we believe it:** F5 — `web/blueprints/arcs.py:_read_arc` reads arbitrary fields; T-1816 audit YAML-parse validates well-formed-YAML, not schema. No known schema enforcement rejects unknown fields. The arc-grooming handoff makes the same assumption (A2 there) for `arc_id:` on tasks; if that holds, the same property covers BVP fields.
- **What breaks if false:** D1, D2, D6, D7, D9 all rely on adding fields. If the audit rejects unknown fields after arc-grooming's migration ships, BVP cannot proceed without a schema-update slice first.
- **How to test:** Re-verify by running `fw audit` on a hand-edited task that includes `bvp_scores:` plus an arc YAML that includes `bvp_scores:` and `scoped_drivers:`. If audit passes silently, the assumption holds.
- **Confidence:** high

### A3: TermLink can run a continuous low-temperature estimator worker (the `bvp-estimator`) at reasonable cost per task scored.

- **Why we believe it:** TermLink is a hub-and-spoke runtime designed for cross-terminal agent coordination (per the AEF README and RFC #45427 references). A long-running worker is its native use case. Low-temperature, fixed-rubric calls are the cheap end of LLM inference. Per-task cost should be small enough that scoring every newly-ready task is feasible at AEF's pace (~10 newly-ready tasks/week).
- **What breaks if false:** D4 collapses. If TermLink can't sustain the worker, task scoring would have to fall back to either (a) primary-agent scoring (with all the determinism / scale issues that D4 rejected), or (b) human manual scoring (with adoption-friction issues).
- **How to test:** Build a minimal `bvp-estimator` prototype, run it against 20 historical tasks from `.tasks/completed/`, measure per-task cost in seconds + tokens. Pass: <5s and <2k tokens per task. Fail: anything materially over that, and the design needs rework.
- **Confidence:** medium (TermLink is mature for this pattern; cost is the unknown that needs measurement)

### A4: At arc creation time, the primary agent has enough conversation context to propose meaningful arc-scoped drivers.

- **Why we believe it:** Arc creation in AEF is typically a back-and-forth conversation between human and primary agent — the problem statement, scope, mechanic are thrashed out in dialogue before being written to the arc YAML. By the time step (3) of D5 runs (suggestion), the primary agent has read all of that context.
- **What breaks if false:** D4 (split runtimes) and D5 (timing) both rest on this. If the primary agent's context is in fact insufficient at suggestion time, the suggestions would be plausible-but-hollow — exactly the failure mode D6's "manufacturing drivers" criterion is meant to filter against.
- **How to test:** During the first 3 arcs created under this system, evaluate whether the agent's suggestions are differentiating (D6 criterion: rationale explains what each driver distinguishes that globals don't). If ≥1 of those 3 produces only hollow suggestions and `--none` is the right call, the assumption needs revisiting and a heavier-context mechanism (e.g. structured arc-creation interview) may be needed.
- **Confidence:** medium

### A5: Humans will use `fw arc show-suggestions` when arc focus shifts.

- **Why we believe it:** D7 persists `proposed_scoped_drivers:` specifically to be reference material at focus-shift moments. The value of persistence depends on the verb being discoverable.
- **What breaks if false:** D7 produces dead data — fields persisted but never read. Cost is small (one YAML field) but it's still cost.
- **How to test:** Three months after first arc with persisted suggestions, check `git log` and `.context/handovers/` for evidence of `fw arc show-suggestions` invocations. If zero, the persistence didn't earn its keep and could be revisited.
- **Confidence:** medium (this is human-behavioural; only operational data tells us)

### A6: The composite cost formula (0.6 × blast_radius + 0.3 × tier + 0.1 × effort) produces useful quadrant placement.

- **Why we believe it:** F8 — the three signals all exist and have intuitive cost meaning. The 0.6/0.3/0.1 weighting reflects relative reliability (blast_radius is auto-computed and deterministic; tier is policy-driven; effort prediction has data-quality issues at low task counts).
- **What breaks if false:** If quadrant placement is systematically wrong (HV/LC tasks turn out to be expensive, or LV/HC tasks turn out to be cheap), the auto-promote policy (D8) and the abandonment recommendation (LV/HC → consider `fw arc abandon`) both surface bad recommendations.
- **How to test:** After 30 days of operation, manually review a sample of tasks per quadrant. For each, ask: was the quadrant placement correct in hindsight? If <70% accuracy, the formula needs reweighting.
- **Confidence:** medium

## 5. Recommendation

**GO-WITH-MODIFICATIONS.**

The modification is **external sequencing**: this handoff's recommendation cannot be acted on until HANDOFF-arc-grooming-2026-05-15 has reached §5: GO AND its first deliverable (the arc-grooming inception decide-go transition, with `arc_id:` field and four-state lifecycle landed) has shipped. This is enforced structurally via `depends_on_handoffs:` and §11.5 dual-condition check.

Supports: F1, F2, F3, F4, F7, F8, F9, F10, D1, D2, D4, D5, D8.
Modifications forced by: A1 (arc-grooming must ship), A2 (audit YAML-parse acceptance must hold after arc-grooming's migration).

**First deliverable (once unblocked):** file the inception task. Its scope is to resolve Q1-Q4 with the human, record decisions in the research artefact, and produce the constituent build-task slices. The inception is required (not bypassable via `fw work-on --type build`) because §12 triggers fire: more than 3 new files, multiple new CLI verbs, a new policy directory, a new TermLink worker, schema additions to task and arc frontmatter, a new canonical doc.

## 6. Open questions for the human

### Q1: Should free drivers be globally visible at all times, or campaign-scoped (e.g. a "Q2 reliability focus" driver active for 90 days then auto-expiring)?

- **Why it matters:** Free drivers persist in `policy/value-drivers.yaml` and influence every BVP score. A temporary focus could be expressed as either (a) a new free driver added when the focus starts and removed when it ends, or (b) a weight-change on an existing driver (set high during focus, zero after). Different shapes of audit log.
- **Default if unanswered:** Globally visible always. Temporal scoping handled as a weight-change pattern (weight → 0 when campaign ends, audit-trailed in `.context/bvp-weight-history.yaml`). No new mechanism.
- **What we assumed during research:** Globally visible. The weight-change pattern reuses D9's audit-trail.

### Q2: For tasks where blast_radius is not yet computable (e.g. brand-new task, no commits yet), should cost_estimate fall back to T-shirt sizing manually entered by the human, or be left blank and treated as "unknown"?

- **Why it matters:** Determines whether new tasks land in the quadrant scatter immediately (T-shirt fallback) or only after first commit (blast_radius live). Affects how quickly the auto-promote policy (D8) can see new HV/LC candidates.
- **Default if unanswered:** T-shirt fallback at task creation (S=2, M=4, L=6, XL=8); auto-recompute from real `blast_radius` once first commit lands.
- **What we assumed during research:** T-shirt fallback. Cost-as-unknown would defer quadrant placement, which seems unhelpful.

### Q3: Should `fw arc abandon` be auto-triggered as a recommendation for arcs that sit in the LV/HC quadrant for N consecutive audit runs, or only surfaced passively in Watchtower?

- **Why it matters:** Sovereignty boundary. Auto-recommending abandonment is a strong signal that crosses into "framework suggests what to do next," which is close to the authority-model line.
- **Default if unanswered:** No auto-trigger. Surface as recommendation in Watchtower with one-click suggested action (`fw arc abandon <id> --reason "..."` pre-filled with the LV/HC justification). Sovereignty stays with the human.
- **What we assumed during research:** No auto-trigger. Passive surface only.

### Q4: TermLink estimator falls back synchronously during `fw resume` — what's the SLA before the resume proceeds with an unscored task?

- **Why it matters:** `fw resume` is a hot-path operation (resuming a session). A long-running estimator call would slow it down. But too-short an SLA would mean newly-ready tasks resume unscored, missing quadrant placement until the async sweep catches them.
- **Default if unanswered:** 10s hard cap. If estimator hasn't returned in 10s, task resumes flagged as unscored in the handover (`unscored: true` field on the task), the async sweep picks it up later. Resume itself is not blocked.
- **What we assumed during research:** 10s hard cap. Faster than human-noticeable latency, slow enough that most estimator calls complete in time.

## 7. Proposed task breakdown

### T-NEW-1: Inception — Business Value Points

- **Workflow type:** inception
- **Scope:** Resolve Q1/Q2/Q3/Q4 with the human, record decisions in the research artefact, and produce the constituent build-task slices listed below as concrete `fw task create` actions. Pre-condition: arc-grooming's first deliverable (inception decide-go) has shipped.
- **Operationalises:** D1, D2, D4, D5, D8 (the macro design decisions); creates the runway for all other tasks in this breakdown.
- **Acceptance Criteria — Agent:**
  - [ ] Inception artefact exists at `docs/reports/T-<id>-bvp-inception.md` (covers D1-D9)
  - [ ] Research artefact records human's answers to Q1, Q2, Q3, Q4 with timestamps (covers Q1-Q4)
  - [ ] Inception artefact lists the constituent build tasks with their `fw task create` invocations as a runnable script-or-checklist
  - [ ] Inception decide-go transition is recorded in the arc YAML's `decision:` field at `.context/arcs/value-prioritisation.yaml`
  - [ ] HANDOFF-arc-grooming-2026-05-15 is confirmed at §5: GO with first deliverable shipped (§11.5 check passes before this task starts)
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] Q1, Q2, Q3, Q4 answers are recorded as final, not provisional
    - **Steps:** open the inception artefact; verify each Q has the human's answer, not just the agent's default.
    - **Expected:** all four questions have explicit human-chosen values.
    - **If not:** request answers before decide-go.
- **Verification:**
  - `test -f docs/reports/T-*-bvp-inception.md`
  - `test -f .context/arcs/value-prioritisation.yaml`
  - `grep -l 'decision:' .context/arcs/value-prioritisation.yaml`
  - `grep -E '^status:.*go|^decision:.*go' .context/arcs/arc-grooming.yaml`  (arc-grooming is at GO)
- **Sizing:**
  - files_touched: 2 (inception artefact, arc YAML)
  - new_components: 1 (the arc YAML for value-prioritisation itself)
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** HANDOFF-arc-grooming-2026-05-15 first deliverable shipped

### T-NEW-2: Schema and initial content for `policy/value-drivers.yaml`

- **Workflow type:** build
- **Scope:** Create the `policy/` directory if it doesn't exist; create `policy/value-drivers.yaml` with protected D1-D4 entries (weights 9/7/5/3), free-driver section (empty list, cap 5), and the `auto_promote` section (disabled by default per D8).
- **Operationalises:** D1, D8.
- **Acceptance Criteria — Agent:**
  - [ ] `policy/value-drivers.yaml` exists
  - [ ] File contains 4 protected entries (D1-D4) with weights 9, 7, 5, 3 respectively
  - [ ] File contains `free_drivers: []` with cap and weight range comments
  - [ ] File contains `auto_promote.enabled: false` with `bvp_norm_min: 0.85`, `cost_max: 1`, `max_concurrent: 1` defaults
  - [ ] `fw audit` passes on the new file (assumes A2 holds; verifies it for the policy directory)
- **Verification:**
  - `test -f policy/value-drivers.yaml`
  - `grep -c '^- id: D[1-4]' policy/value-drivers.yaml`  (should return 4)
  - `grep 'auto_promote' policy/value-drivers.yaml | grep -q 'enabled: false'`
  - `fw audit 2>&1 | grep -iv 'fail\|error'`
- **Sizing:**
  - files_touched: 2 (new directory, new file)
  - new_components: 1 (new policy directory)
  - novel_mechanism: no
  - est_hours: 1
  - verdict: fits-one-session
- **Dependencies:** T-NEW-1

### T-NEW-3: Task and arc frontmatter schema extensions

- **Workflow type:** build
- **Scope:** Add `bvp_scores:`, `bvp_scores_proposed:`, `cost_estimate:` to `.tasks/templates/default.md` task frontmatter. Add `bvp_scores:`, `scoped_drivers:` (max 3), `proposed_scoped_drivers:` (uncapped, persistent) to arc-YAML creation template (in `lib/arc.sh` `arc_create`). Document fields in CLAUDE.md.
- **Operationalises:** D2, D6, D7, D9.
- **Acceptance Criteria — Agent:**
  - [ ] `.tasks/templates/default.md` contains the three new fields with explanatory comments
  - [ ] `lib/arc.sh` `arc_create` writes the three new arc-YAML fields with appropriate defaults (empty scoped_drivers, empty proposed_scoped_drivers, empty bvp_scores)
  - [ ] `CLAUDE.md` task-system and arc-system sections document the new fields
  - [ ] `fw audit` passes on a hand-edited task and a newly-created arc that include the new fields
- **Verification:**
  - `grep -q 'bvp_scores:' .tasks/templates/default.md`
  - `grep -q 'cost_estimate:' .tasks/templates/default.md`
  - `fw arc create test-frontmatter --headline-mechanic "..." ; grep -E 'bvp_scores|scoped_drivers|proposed_scoped_drivers' .context/arcs/test-frontmatter.yaml`
  - `grep -q 'bvp_scores' CLAUDE.md`
- **Sizing:**
  - files_touched: 3 (default.md template, lib/arc.sh, CLAUDE.md)
  - new_components: 0
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** T-NEW-2, HANDOFF-arc-grooming-2026-05-15 T-NEW-2 (arc_id field landed)

### T-NEW-4: `fw bvp` read-only CLI verbs (rank, detail, arcs, quadrant filter)

- **Workflow type:** build
- **Scope:** Implement `fw bvp` (rank all tasks by current BVP), `fw bvp T-<id>` (detail per task showing per-driver scores), `fw bvp arcs` (rank arcs by their global-driver BVP), `fw bvp --quadrant <name>` (filter by quadrant — hv-lc, hv-hc, lv-lc, lv-hc). All read-only.
- **Operationalises:** D1, D2, F9 (quadrant mapping).
- **Acceptance Criteria — Agent:**
  - [ ] `fw bvp` outputs a ranked task list, sorted by BVP descending
  - [ ] `fw bvp T-<id>` outputs per-driver scores and current weighted BVP
  - [ ] `fw bvp arcs` outputs a ranked arc list, scored against global drivers only (D2)
  - [ ] `fw bvp --quadrant hv-lc` filters to high-value/low-cost tasks
  - [ ] All verbs are read-only — no file writes
- **Verification:**
  - `fw bvp | head -5`  (must produce ranked list)
  - `fw bvp arcs | head -5`  (must produce ranked arc list)
  - `fw bvp --quadrant hv-lc`  (must produce filtered list, possibly empty)
- **Sizing:**
  - files_touched: 1-2 (lib/bvp.sh or equivalent, bin/fw routing)
  - new_components: 1 (new lib module)
  - novel_mechanism: no (mirrors `fw task list` and `fw arc list` patterns)
  - est_hours: 3
  - verdict: fits-one-session
- **Dependencies:** T-NEW-3

### T-NEW-5: `fw bvp weight` and `fw bvp driver` mutating verbs + weight history audit

- **Workflow type:** build
- **Scope:** Implement `fw bvp weight --set Dn=N --rationale "..."` (changes a driver's weight, writes to `.context/bvp-weight-history.yaml`, enforces $CLAUDECODE=1 agent-gate). Implement `fw bvp driver --add "<name>" --weight N` and `fw bvp driver --remove <id>` (enforces 9-driver total cap, add-one-drop-one when full). Both verbs follow the §ACD agent-gate pattern.
- **Operationalises:** D9, F6.
- **Acceptance Criteria — Agent:**
  - [ ] `fw bvp weight --set D2=8 --rationale "Q2 reliability focus"` writes to `.context/bvp-weight-history.yaml` with timestamp, who, from-weight, to-weight, rationale
  - [ ] `fw bvp weight` refuses without `--rationale` or with rationale under 30 chars
  - [ ] `fw bvp weight` refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (F6)
  - [ ] `fw bvp driver --add` refuses when total active drivers (protected + free) >= 9
  - [ ] `fw bvp driver --remove` refuses on protected drivers (D1-D4)
  - [ ] Weight change is reactive: subsequent `fw bvp` re-ranks reflect the new weights immediately
- **Verification:**
  - `fw bvp weight --set D2=8`  (must fail — no rationale)
  - `fw bvp weight --set D2=8 --rationale "trial change with reason long enough"` (must succeed)
  - `tail -1 .context/bvp-weight-history.yaml | grep -q 'D2'`
  - `CLAUDECODE=1 fw bvp weight --set D2=7 --rationale "..."`  (must fail — agent gate)
  - `fw bvp driver --remove D1`  (must fail — protected)
- **Sizing:**
  - files_touched: 1-2 (lib/bvp.sh, possibly a new .context/bvp-weight-history.yaml on first invocation)
  - new_components: 1 (new audit log file)
  - novel_mechanism: no (mirrors fw arc close agent-gate)
  - est_hours: 3
  - verdict: fits-one-session
- **Dependencies:** T-NEW-2, T-NEW-4

### T-NEW-6: Scoring rubric document (`policy/bvp-scoring-rubric.md`)

- **Workflow type:** build
- **Scope:** Write the rubric the TermLink estimator follows. Must produce stable scores at low temperature. Includes: per-driver scoring criteria (what does D1=4 vs D1=2 actually mean?), worked examples drawn from `.context/episodic/` historical tasks, calibration cases.
- **Operationalises:** D4 (the rubric is the reusable state the worker preloads).
- **Acceptance Criteria — Agent:**
  - [ ] `policy/bvp-scoring-rubric.md` exists with sections for each protected driver (D1-D4) plus a "free drivers" general-criteria section
  - [ ] At least 3 worked examples per driver, drawn from real `.tasks/completed/` content
  - [ ] Determinism test: scoring the same task body twice (in separate sessions, low temp) produces scores within ±1 on every driver
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] Worked examples reflect AEF's actual values, not hallucinated framings
    - **Steps:** read each worked example; verify the framing matches how the human would have scored the same task.
    - **Expected:** no examples that systematically over- or under-score a driver.
    - **If not:** revise the rubric before T-NEW-7 starts (the estimator inherits the rubric's biases).
- **Verification:**
  - `test -f policy/bvp-scoring-rubric.md`
  - `wc -l policy/bvp-scoring-rubric.md`  (substantive — expect >200 lines)
- **Sizing:**
  - files_touched: 1
  - new_components: 1 (new doc)
  - novel_mechanism: no (it's a rubric, a writing task)
  - est_hours: 4
  - verdict: fits-one-session — but writing-heavy; the human review step may push to a second session
- **Dependencies:** T-NEW-1

### T-NEW-7: TermLink `bvp-estimator` worker

- **Workflow type:** build
- **Scope:** Implement the BVP estimator as a TermLink worker. Triggers: (a) task transitions to "ready" status, (b) scheduled sweep every N minutes for stale-scored tasks, (c) `fw resume` synchronous fallback with 10s SLA (Q4 default). Output: writes to `bvp_scores_proposed:` on task frontmatter. Never writes to `bvp_scores:` (that's reserved for human confirmation).
- **Operationalises:** D4, A3 (the assumption needs measurement during this slice).
- **Acceptance Criteria — Agent:**
  - [ ] Worker runs as a TermLink agent; can be started via `fw termlink start bvp-estimator`
  - [ ] On task transition to "ready", worker scores task within target SLA (<5s avg)
  - [ ] Score is written to `bvp_scores_proposed:` block, never to `bvp_scores:`
  - [ ] Re-running on the same task body produces scores within ±1 (determinism)
  - [ ] Confirmed `bvp_scores:` are sticky — worker reads them and either (a) leaves them alone, or (b) writes a v2 delta to `bvp_scores_proposed:` only if its score differs from confirmed by ≥2 on any driver
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] A3 holds — per-task cost is reasonable
    - **Steps:** run worker against 20 historical tasks from `.tasks/completed/`; record per-task latency and token usage.
    - **Expected:** <5s and <2k tokens per task.
    - **If not:** the design needs rework; estimator may need to fall back to primary agent, or rubric needs to compress.
- **Verification:**
  - `fw termlink start bvp-estimator`  (must succeed)
  - `fw termlink status bvp-estimator | grep -i running`
  - Run worker against a known task: verify `bvp_scores_proposed:` is populated within 10s
  - Run worker twice on the same task: scores within ±1 on every driver
- **Sizing:**
  - files_touched: 2-3 (new TermLink worker dir, possibly fw routing)
  - new_components: 1 (new worker)
  - novel_mechanism: yes — first BVP-flavoured TermLink worker; the harness is new even though the rubric is portable
  - est_hours: 6-8
  - verdict: needs-split — recommend splitting into (7a) worker harness + ready-status trigger, and (7b) scheduled sweep + fw resume fallback. Reasoning: `novel_mechanism: yes` forces split per v3 sizing rules.
- **Dependencies:** T-NEW-6 (rubric must exist), T-NEW-3 (frontmatter fields), A3 must hold

### T-NEW-8: `fw bvp confirm` verb

- **Workflow type:** build
- **Scope:** Implement `fw bvp confirm T-<id>` (accept all proposed scores as-is) and `fw bvp confirm T-<id> --override Dn=N [...]` (accept with per-driver modifications). Moves `bvp_scores_proposed:` content into `bvp_scores:` with timestamp and `confirmed_by:` field.
- **Operationalises:** D4 (confirmed scores are sticky), F7 (Sovereignty).
- **Acceptance Criteria — Agent:**
  - [ ] `fw bvp confirm T-<id>` copies `bvp_scores_proposed:` into `bvp_scores:`, adds `confirmed_by:` and `confirmed_at:` fields
  - [ ] `fw bvp confirm T-<id> --override D2=4` accepts proposed scores but overrides D2 to 4
  - [ ] After confirm, the worker (T-NEW-7) does not overwrite `bvp_scores:` on subsequent runs
  - [ ] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower` (confirmation is a Sovereignty act, F7)
- **Verification:**
  - `fw bvp confirm T-<known-task>`  (must succeed, writes bvp_scores)
  - `grep 'confirmed_by:' .tasks/active/T-<known-task>.md`
  - `CLAUDECODE=1 fw bvp confirm T-<other-task>`  (must fail — agent gate)
- **Sizing:**
  - files_touched: 1 (lib/bvp.sh)
  - new_components: 0 (extends existing module)
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** T-NEW-7

### T-NEW-9: Document primary-agent arc-scoped-driver suggestion workflow

- **Workflow type:** build
- **Scope:** Update CLAUDE.md and AGENTS.md with the arc-creation flow per D5: after arc body is filled in but before driver approval, the primary agent reads the body and proposes any number of genuine arc-scoped drivers with rationales to `proposed_scoped_drivers:` in the arc YAML. Includes the D6 quality criterion (rationale must explain what the driver differentiates that globals don't). No CLI verb for suggestion itself — it's a documented workflow.
- **Operationalises:** D5, D6.
- **Acceptance Criteria — Agent:**
  - [ ] CLAUDE.md has a new section under arc management documenting the suggestion workflow
  - [ ] AGENTS.md mirrors the workflow for non-Claude agents
  - [ ] Both docs include the "manufacturing drivers is worse than proposing zero" criterion verbatim
  - [ ] Worked example included: a hypothetical arc with 3 plausible scoped drivers + rationales
- **Verification:**
  - `grep -q 'proposed_scoped_drivers' CLAUDE.md`
  - `grep -q 'proposed_scoped_drivers' AGENTS.md`
  - `grep -c 'manufacturing\|manufactured' CLAUDE.md`  (should return ≥1)
- **Sizing:**
  - files_touched: 2
  - new_components: 0
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** T-NEW-3, HANDOFF-arc-grooming-2026-05-15 T-NEW-5 (draft state must exist)

### T-NEW-10: `fw arc approve-driver` verb + `fw arc show-suggestions` verb

- **Workflow type:** build
- **Scope:** Implement `fw arc approve-driver <arc> <driver-name> [--weight N]` (appends to `scoped_drivers:` with cap-3 check, flips `draft → in-progress` on first approval). Implement `fw arc approve-driver <arc> --none --justification "<≥30 chars>"` (bypass — logs to `.context/audits/arc-scoped-driver-bypass.jsonl`, also flips `draft → in-progress`). Implement `fw arc show-suggestions <arc>` (renders `proposed_scoped_drivers:` grouped by suggestion event timestamp, read-only). Both write-verbs follow §ACD agent-gate.
- **Operationalises:** D5, D6, D7, F6.
- **Acceptance Criteria — Agent:**
  - [ ] `fw arc approve-driver <arc> "<name>"` appends to `scoped_drivers:` and (on first approval) sets `status: in-progress`
  - [ ] Refuses when `scoped_drivers:` already has 3 entries
  - [ ] Refuses without `--justification` text under 30 chars (for `--none` case)
  - [ ] Refuses under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`
  - [ ] `--none --justification` writes to `.context/audits/arc-scoped-driver-bypass.jsonl` with arc_id, justification, ts
  - [ ] `fw arc show-suggestions <arc>` renders all entries in `proposed_scoped_drivers:`, grouped by event timestamp (D7)
- **Verification:**
  - `fw arc create test-approval --headline-mechanic "..."` (creates draft arc)
  - `fw arc approve-driver test-approval "Reduces latency" --weight 5`  (succeeds, arc flips to in-progress)
  - `grep -A2 'status:' .context/arcs/test-approval.yaml | grep -q 'in-progress'`
  - `fw arc approve-driver test-approval-2 --none --justification "small arc, scoped drivers do not surface"` (also flips)
  - `tail -1 .context/audits/arc-scoped-driver-bypass.jsonl | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); assert "arc_id" in d and "justification" in d'`
  - `CLAUDECODE=1 fw arc approve-driver test-approval "..."` (must fail — agent gate)
- **Sizing:**
  - files_touched: 1-2 (lib/arc.sh, possibly bin/fw routing)
  - new_components: 2 (two new verbs, one new audit log file)
  - novel_mechanism: no (mirrors §ACD shape exactly)
  - est_hours: 3
  - verdict: fits-one-session
- **Dependencies:** T-NEW-3, T-NEW-9, HANDOFF-arc-grooming-2026-05-15 T-NEW-5 (draft state)

### T-NEW-11: Per-driver coherence audit check

- **Workflow type:** build
- **Scope:** Add audit check to `agents/audit/audit.sh`: for each arc with confirmed `bvp_scores:`, check whether ≥70% of its constituent tasks (enumerated via `arc_id:`) score the same driver ≤1 when the arc claims ≥4. If so, emit per-driver warning. Surfaced in `fw audit` output and Watchtower arc detail page.
- **Operationalises:** D3.
- **Acceptance Criteria — Agent:**
  - [ ] `fw audit` emits `coherence: arc <id> claims D<n>=<x> but tasks don't support it` warning when applicable
  - [ ] Check is per-driver — separate warnings for each mismatched driver
  - [ ] Check is non-blocking — `fw audit` exit code unaffected
  - [ ] Threshold (70% mismatch, ≥4 claim, ≤1 task score) is configurable via constants
- **Verification:**
  - Construct a test arc with high D1 score and constituent tasks with low D1 scores; run `fw audit | grep -i 'coherence'`
- **Sizing:**
  - files_touched: 1
  - new_components: 1 (new audit check)
  - novel_mechanism: no
  - est_hours: 2
  - verdict: fits-one-session
- **Dependencies:** T-NEW-8 (needs confirmed scores), HANDOFF-arc-grooming-2026-05-15 T-NEW-3 (arc_id migration must have landed for reliable enumeration)

### T-NEW-12: Watchtower `/bvp` tab

- **Workflow type:** build
- **Scope:** New tab `/bvp` in Watchtower. Renders the quadrant scatter (arcs as larger dots, tasks as smaller, axes: BVP_norm × cost). Live weight sliders on the side — moving a slider previews re-rank without committing. A separate "Commit" button writes the change via `fw bvp weight --set ...` (preserves audit trail).
- **Operationalises:** D1, D9, F9 (quadrant), F10 (extension to Watchtower).
- **Acceptance Criteria — Agent:**
  - [ ] `/bvp` tab renders without error
  - [ ] Scatter plot shows current tasks and arcs in their quadrant positions
  - [ ] Weight sliders trigger live preview (client-side recompute, no server roundtrip per drag)
  - [ ] Commit button writes through `fw bvp weight` (audit-trail preserved per D9)
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] Quadrant placement is intuitive
    - **Steps:** open `/bvp`; pick 5 random tasks; for each, ask: does its quadrant placement match intuition?
    - **Expected:** ≥4/5 placements match.
    - **If not:** A6 (cost formula assumption) needs revisiting.
- **Verification:**
  - `curl -s http://localhost:3000/bvp | grep -i 'quadrant\|scatter'`  (or equivalent for current serving)
- **Sizing:**
  - files_touched: 2-3 (web/blueprints/bvp.py new, templates, possibly route registration)
  - new_components: 1 (new Watchtower blueprint)
  - novel_mechanism: yes — first Watchtower view with live client-side weight preview
  - est_hours: 6
  - verdict: needs-split — recommend (12a) static scatter + read-only, then (12b) live sliders + commit
- **Dependencies:** T-NEW-4, T-NEW-5

### T-NEW-13: Watchtower `/arcs/<id>` extensions

- **Workflow type:** build
- **Scope:** Extend existing `/arcs/<id>` detail page with: arc-level BVP display, per-driver coherence warning surface (renders T-NEW-11 warnings), `proposed_scoped_drivers:` render (calls `fw arc show-suggestions` logic), approve-driver action UI (button per proposal).
- **Operationalises:** D3, D7, F10.
- **Acceptance Criteria — Agent:**
  - [ ] `/arcs/<id>` shows arc-level BVP near the top
  - [ ] Coherence warnings surface inline with the arc's metadata
  - [ ] `proposed_scoped_drivers:` are rendered with timestamps (D7) and approve buttons
  - [ ] Approve button calls `fw arc approve-driver` (preserves §ACD agent-gate)
- **Verification:**
  - Open `/arcs/<id>` for an arc with proposed drivers; confirm rendering
  - Click approve; verify `scoped_drivers:` is updated and arc flips to in-progress
- **Sizing:**
  - files_touched: 2 (web/blueprints/arcs.py extension, template)
  - new_components: 0 (extends existing)
  - novel_mechanism: no
  - est_hours: 3
  - verdict: fits-one-session
- **Dependencies:** T-NEW-10, T-NEW-11

### T-NEW-14: Opt-in auto-promote policy gate

- **Workflow type:** build
- **Scope:** Implement the auto-promote logic — read `auto_promote.*` from `policy/value-drivers.yaml`. If `enabled: true` and a task is in HV/LC quadrant (`bvp_norm ≥ bvp_norm_min` and `cost ≤ cost_max`), promote from Captured to In Progress. Respect `max_concurrent`. Log every auto-promotion to `.context/bvp-auto-promote-log.yaml`.
- **Operationalises:** D8, F7.
- **Acceptance Criteria — Agent:**
  - [ ] When `auto_promote.enabled: false` (default), no auto-promotion occurs
  - [ ] When enabled, HV/LC tasks satisfying both thresholds are promoted automatically
  - [ ] `max_concurrent` is respected — never promotes >N at once
  - [ ] Every auto-promotion writes to `.context/bvp-auto-promote-log.yaml` with task_id, bvp_norm, cost, ts
  - [ ] No promotion of tasks with unconfirmed `bvp_scores_proposed:` only (must have confirmed `bvp_scores:`)
- **Verification:**
  - Set `enabled: false`; verify no auto-promote occurs
  - Set `enabled: true`; create a HV/LC task with confirmed scores; verify promotion happens
  - Verify log entry: `tail -1 .context/bvp-auto-promote-log.yaml | grep -q task_id`
- **Sizing:**
  - files_touched: 2 (lib/bvp.sh, possibly a cron registration)
  - new_components: 1 (new audit log file)
  - novel_mechanism: yes — first framework-driven status transition without per-event human approval
  - est_hours: 4
  - verdict: needs-split — recommend (14a) the promotion logic + log, off by default, and (14b) `policy/value-drivers.yaml` enabling and any required cron/trigger wiring
- **Dependencies:** T-NEW-2, T-NEW-8

### T-NEW-15: Canonical doc — `040-ValueDrivers.md`

- **Workflow type:** build
- **Scope:** New canonical doc at `040-ValueDrivers.md`, mirroring the structure of `010-TaskSystem.md` and (post-arc-grooming) `012-ArcSystem.md`. Updates to `FRAMEWORK.md`: glossary entries for BVP, value driver, free driver, arc-scoped driver, directive scoring, quadrant; Quick Reference table additions for `fw bvp` and `fw arc approve-driver` commands.
- **Operationalises:** F1 (makes directives' scoring layer canonical), F2 (closes the directive-scoring doc gap).
- **Acceptance Criteria — Agent:**
  - [ ] `040-ValueDrivers.md` exists with sections: Overview, The Four Constitutional Directives, Free Drivers, Arc-Scoped Drivers, Scoring (0-5 × 0-9 weight), Quadrants, Cost Composite, BVP Estimator, Driver Decision Gate, fw bvp CLI, fw arc approve-driver CLI, Relation to Authority Model
  - [ ] `FRAMEWORK.md` glossary has entries for BVP, value driver, free driver, arc-scoped driver, directive scoring, quadrant
  - [ ] `FRAMEWORK.md` Quick Reference has `fw bvp`, `fw bvp weight`, `fw bvp confirm`, `fw arc approve-driver`, `fw arc show-suggestions` rows
- **Acceptance Criteria — Human:**
  - [ ] [REVIEW] `040-ValueDrivers.md` content is technically accurate and matches the implementation after T-NEW-2 through T-NEW-14
    - **Steps:** read 040-ValueDrivers.md end-to-end; verify each claim against `lib/bvp.sh`, `policy/value-drivers.yaml`, and `policy/bvp-scoring-rubric.md`.
    - **Expected:** no discrepancies.
    - **If not:** edit before merging.
- **Verification:**
  - `test -f 040-ValueDrivers.md`
  - `grep -q 'Business Value Points\|BVP' FRAMEWORK.md`
  - `grep -q 'fw bvp' FRAMEWORK.md`
- **Sizing:**
  - files_touched: 2
  - new_components: 1 (new doc)
  - novel_mechanism: no
  - est_hours: 3
  - verdict: fits-one-session
- **Dependencies:** T-NEW-2, T-NEW-5, T-NEW-8, T-NEW-10, T-NEW-14 (doc must describe post-implementation state)

## 8. Constraints, non-goals, blast radius

**Must respect:**

- HANDOFF-arc-grooming-2026-05-15 must reach §5: GO AND its first deliverable (the inception decide-go transition with `arc_id:` field and four-state lifecycle landed) must ship before this work can be filed. §11.5 enforces this via the `depends_on_handoffs:` dual-condition check.
- The §ACD agent-gate pattern is the established shape for evidence-or-justified-absence gates. Both `fw bvp weight` and `fw arc approve-driver` must follow it: refuse under `$CLAUDECODE=1` unless `--i-am-human` or `--from-watchtower`, refuse without required justification text, log bypass invocations to `.context/audits/`.
- Human-confirmed scores are sticky. The TermLink estimator must never overwrite `bvp_scores:`. It can write to `bvp_scores_proposed:` as a v2 delta if its score differs ≥2 from confirmed, surfaced for human review.
- The four directives (D1-D4) remain protected — never removable. Removal verbs must refuse on D1-D4.
- Auto-promote is OFF by default. Per D8, the human's act of editing `auto_promote.enabled: true` in the policy file is the Sovereignty exercise. Framework then enforces the pre-authorised rule.

**Must not do:**

- Do not replace `fw arc close --demo`. BVP is additive. The demo discipline stays.
- Do not introduce cost inputs beyond F8's three signals (blast_radius, tier, historical effort). The composite formula in A6 is the cost model; that's the entire surface.
- Do not introduce cross-repo drivers or scoring. Single-repo only.
- Do not make BVP confirmation a Tier-1 block on task save. BVP is advisory.
- Do not touch the arc lifecycle state machine. The four states (draft, in-progress, closed, abandoned) are owned by HANDOFF-arc-grooming-2026-05-15. This handoff only enforces what `draft` means via the driver-decision gate.
- Do not let the auto-promote gate (T-NEW-14) promote tasks with only proposed (unconfirmed) scores. Confirmation is the Sovereignty boundary.

**Affected if it ships:**

- Every task and every arc in the repo gains BVP scores over time (estimator scores tasks as they're newly-ready; arcs are scored at creation or retroactively).
- `policy/` directory is created with two new files: `value-drivers.yaml` and `bvp-scoring-rubric.md`.
- New CLI verbs: `fw bvp` (with subcommands rank, detail, arcs, --quadrant, weight, driver, confirm), `fw arc approve-driver`, `fw arc show-suggestions`.
- New audit logs: `.context/bvp-weight-history.yaml`, `.context/audits/arc-scoped-driver-bypass.jsonl`, `.context/bvp-auto-promote-log.yaml`.
- New TermLink worker: `bvp-estimator`.
- Watchtower gains `/bvp` tab and extends `/arcs/<id>`.
- New canonical doc `040-ValueDrivers.md`; FRAMEWORK.md gains glossary entries and Quick Reference rows.

**Affected if it breaks:**

- A bad scoring rubric (T-NEW-6) propagates into every task scored by the estimator. Mitigation: human review of rubric before T-NEW-7 ships; determinism test in T-NEW-7 ACs catches instability.
- A wrong cost formula (A6) systematically mis-places tasks in quadrants. Mitigation: Q4 30-day review window; T-NEW-12's human AC catches this in spot-check.
- A `fw bvp weight` change with no rationale (or bad agent-gate) could re-rank everything silently. Mitigation: §ACD shape forces rationale; agent-gate forces human invocation; weight history is auditable.
- The `bvp-estimator` worker producing unstable scores (A3 fails) pollutes audit. Mitigation: T-NEW-7 determinism AC + A3 measurement step.

## 9. Risks and prevention

| Risk | Likelihood | Mitigation | Detection |
|---|---|---|---|
| HANDOFF-arc-grooming-2026-05-15 stalls or its first deliverable doesn't ship — this whole handoff stays blocked indefinitely | medium | §11.5 dual-condition check on `depends_on_handoffs:` halts task creation until the dependency is satisfied; the human surfaces the blockage rather than letting it linger | `.context/handovers/` mentions repeated "BVP handoff blocked on arc-grooming" |
| Scoring rubric (T-NEW-6) encodes hidden biases — e.g. systematically over-scores D2 because the examples were drawn from a reliability-heavy period | medium | Human review AC on T-NEW-6 (must verify worked examples reflect actual values); determinism is necessary but not sufficient | Coherence audit (T-NEW-11) starts firing systematically on one driver — pattern indicates rubric bias |
| TermLink estimator unstable across runs (same task, different scores) — A3 fails | medium | T-NEW-7 determinism AC blocks merge until ±1 stability is shown; rubric tightening is a fallback | Determinism test failure during T-NEW-7 acceptance |
| Cost formula (A6) systematically wrong — HV/LC tasks turn out expensive in practice | medium | T-NEW-12 human AC includes spot-check; 30-day review period | Auto-promote (T-NEW-14) regularly hits tasks that turn out hard to complete |
| Agent manufactures arc-scoped drivers to look thorough (D6 failure) | medium | D6 quality criterion documented verbatim in T-NEW-9; observation pattern: if `--none` is rare and `scoped_drivers:` always has 3 entries with vague rationales, that's the failure | Audit pattern review: arcs with 3 scoped_drivers whose rationales repeat or are generic |
| `fw bvp weight` change with insufficient rationale pollutes the audit log | low | §ACD agent-gate (30-char minimum, refuses without `--rationale`) | Weight history review: any entries with thin rationale prompt follow-up |
| Auto-promote (T-NEW-14, opt-in) escalates: human enables it once, then forgets, eventually framework promotes work the human wouldn't have approved | medium-low | `max_concurrent: 1` default; auto-promote log is reviewable; the policy is one config edit to disable | Auto-promote log shows tasks the human wouldn't have prioritised — surfaced in periodic review |
| `proposed_scoped_drivers:` field grows unbounded (re-suggestions append per D7) — arc YAMLs become noisy | low | Re-suggestions are rare (one-shot at major focus shifts); each is a small YAML structure | Arc YAML size monitoring; if any arc exceeds N KB, investigate |
| **Reversibility risk:** the scoring rubric, once published, may be hard to walk back if it's wrong — agents trained against it carry the bias | medium | Rubric is versioned in git; bad versions can be replaced. Determinism property means a rubric update re-scores all tasks consistently | Per-driver score distribution should be roughly stable over time; sudden shifts indicate rubric impact |

No one-way doors in this handoff. The BVP system is additive — every mechanic can be disabled (auto-promote OFF, estimator stopped, weights reset to neutral) and the framework continues to function as before.

## 10. Dialogue log

- **Q (human):** Translate the Dimitri Geelen 2019 BVP blog into something AEF can use, with the four architectural directives as base value drivers, weights that can change over time, the four quadrants, and the same mechanism at arc level.
- **A (agent):** Initial sketch mapped BVP onto AEF primitives — four directives = protected drivers, weights mutable in `policy/value-drivers.yaml`, BVP × cost quadrant scatter. Open question on whether priority is lexicographic or weighted.
- **Outcome:** F1 (directives as substrate) and F2 (no scoring scaffold exists) emerged. Initial framing locked in.

- **Q (agent):** Directives priority — lexicographic (D1 always wins), strict weighted-sum, or hybrid?
- **A (human):** Weighted sum. Directive priority is translated through weighting.
- **Outcome:** D1 emerged with weights 9/7/5/3. Hybrid and lexicographic rejected with explicit reasons.

- **Q (agent):** For arcs, do we score arcs themselves, or just aggregate their child tasks?
- **A (human):** Prioritise arcs; child-task aggregation feels wrong because more tasks would mean more arc value, which is incentive-incompatible.
- **Outcome:** D2 emerged — arcs scored independently. The aggregation model was explicitly rejected when the human pointed out the perverse incentive. Original framing of "Model A vs Model B" simplified to "Arc has its own score, child-task aggregation is a per-driver coherence check (D3), not a ranking input."

- **Q (agent):** Should the suggestion of arc-scoped drivers run on TermLink (like the task estimator) or on the primary agent?
- **A (human):** Primary agent. Task scoring is statistical-rubric work that benefits from preload; arc-scoped-driver suggestion is interpretive one-shot work, no preload benefit, and the primary agent has the arc-creation conversation context for free.
- **Outcome:** D4 emerged. F4 captured the underlying axes (continuous vs one-shot, statistical vs interpretive, preload-friendly vs not). The split made implementation cleaner.

- **Q (agent):** Should the agent's driver suggestions be capped (e.g. exactly 3) to match the approval cap?
- **A (human):** No cap on suggestion. Agent should propose as many as genuinely surface, but exhaust itself to define drivers if they aren't meaningful — manufacturing drivers to hit a target is worse than proposing zero.
- **Outcome:** D6 emerged with asymmetric caps: agent generates freely, human prunes to ≤3. Quality criterion explicit: rationale must explain what each driver distinguishes that globals don't.

- **Q (agent):** Should `proposed_scoped_drivers:` be cleared after approval? My initial framing was audit-trail.
- **A (human):** Not for audit — for future reference. If arc focus shifts, the original suggestions are a starting point for re-deciding.
- **Outcome:** D7 emerged with the corrected framing: reference material, not audit material. Persistence is the right shape; the audit framing was a near-miss that would have built the wrong thing.

- **Q (agent):** Auto-promote from Captured to In Progress for high-value / low-cost tasks — should it be on by default?
- **A (human):** No. Sovereignty is the human's. Auto-promote is an opt-in escape hatch.
- **Outcome:** D8 emerged. The policy file's `auto_promote.enabled: false` default is the Authority-respecting shape; turning it on is itself a Sovereignty exercise.

- **Q (human):** Are we being asked to provide a complete work package? That's the framework agent's scope; we should provide research and let them convert.
- **A (agent):** Correct — original handoff format overreached. Format was iterated to v2 then v3 with explicit "Research is not authorization" binding, `Operationalises:` per task, and `depends_on_handoffs:` for chains.
- **Outcome:** The handoff format itself was refined during research. v3 governs both handoffs in this session. §7 task breakdowns are explicitly proposal-shaped, with `T-NEW-<n>` placeholders.

- **Q (agent):** Should `draft` state live in arc-grooming or here?
- **A (human):** It's a state on the arc primitive, so it lives in arc-grooming. This handoff only adds the gate enforcement (what `draft → in-progress` requires).
- **Outcome:** Clean separation of concerns: arc-grooming owns the state machine (D2 there), this handoff owns the gate meaning (D5, D6 here). Cross-references in §8 Constraints make the boundary visible.

## 11. Artifacts and links

- `005-DesignDirectives.md` — canonical home of the four Constitutional Directives. The protected drivers' source-of-truth.
- `FRAMEWORK.md` — Four Constitutional Directives section + Authority Model section. Both load-bearing for D1, D8, F7.
- `010-TaskSystem.md` — Task lifecycle (Captured → In Progress → Issues → Work Completed). Reference for the BVP quadrant → Captured → In Progress auto-promote mapping (F9).
- `lib/arc.sh` — Arc primitive implementation. F6 references the §ACD agent-gate pattern at lines 430-468 and 473-492 (per framework-agent briefing).
- `web/blueprints/arcs.py` — Watchtower arc rendering. F10 referenced for the extension pattern; F5 referenced for `_read_arc` accepting arbitrary fields.
- `agents/audit/audit.sh` — Audit infrastructure. F5 references YAML-parse validation (T-1816 hardening).
- `.context/arcs/` — Current arc storage. F3 references that arc list is alpha-by-filename.
- `.context/working/arc-focus.yaml` — Single-pointer focus, where BVP-driven next-focus suggestions could surface.
- Geelen blog post, "Using Business Value Points for Backlog Prioritisation" (2019) — `https://blog.dimitrigeelen.com/2019/10/using-business-value-points-for-backlog-prioritisation/` — Source of the BVP mechanic; D1 (weights 9/7/5/3 schema) and F9 (HV/LC quadrant as auto-promote eligibility) both trace back to this post.
- HANDOFF-arc-grooming-2026-05-15.md — Prerequisite handoff. A1 depends on its §5: GO + first deliverable shipped.
- Prior tasks (per framework-agent briefing): T-1641 (originating context for arcs), T-1653 (arc design anchor), T-1668 (§ACD discipline), T-1816 (audit YAML-parse hardening).

## 11.5. Pre-action checks (for the receiving agent)

Before acting on this handoff, the receiving agent should verify:

- [ ] **`depends_on_handoffs:` dual-condition check.** HANDOFF-arc-grooming-2026-05-15 has reached §5: GO AND its first deliverable (arc-grooming inception decide-go, with `arc_id:` field migration and four-state lifecycle landed) has shipped. If §5 is not GO (still DEFER, NO-GO, or unresolved), halt and surface — dependency may never materialise. If GO but first deliverable not yet shipped, halt and surface — work cannot proceed until the dependency lands.
- [ ] Every path cited in §3 / §11 still exists at the cited location. Specifically: `005-DesignDirectives.md`, `010-TaskSystem.md`, `FRAMEWORK.md`, `lib/arc.sh`, `web/blueprints/arcs.py`, `agents/audit/audit.sh`. Stale references = stale handoff.
- [ ] No newer handoff supersedes this one. Search `prompts/`, `docs/reports/` for `supersedes: HANDOFF-value-prioritisation-2026-05-15`.
- [ ] Every tool / command cited in §7 Verification is installed and on PATH (`fw`, `git`, `grep`, `python3`, `bash`, `curl`).
- [ ] Every Assumption in §4a still holds:
  - A1 (arc-grooming shipped): see first bullet above — this is the load-bearing dependency check.
  - A2 (audit YAML-parse accepts unknown fields): run `fw audit` on a hand-edited task with `bvp_scores:` field. If audit passes, holds.
  - A3 (TermLink can run estimator at reasonable cost): unverifiable until T-NEW-7 measurement step. Flag as "to be tested during build" rather than gating ingestion.
  - A4 (primary agent has enough context at arc-creation suggestion time): unverifiable until first 3 arcs use the workflow. Flag as "to be reviewed after first 3 uses."
  - A5 (`fw arc show-suggestions` will be used): unverifiable until 3 months of operation. Flag as "review at next handover cycle."
  - A6 (composite cost formula produces useful quadrant placement): unverifiable until 30 days of data. Flag as "review at Q4 default unanswered-window."

If the dependency check fails: post a one-line summary back to the human and do not proceed to task creation.

## 12. Pickup safety markers (REQUIRED)

> **This is a research handoff, not a build mandate.** The receiving agent should create tasks per §7, set focus, write real ACs (replacing any placeholder I wrote), and proceed only after the appropriate governance gate (inception decide / task gate) is satisfied. The imperative tone of §7 is a PROPOSAL, not an instruction to skip scoping.

**Inception-required triggers fire on this handoff.** §7 describes:

- More than 3 new files (`policy/value-drivers.yaml`, `policy/bvp-scoring-rubric.md`, several new audit logs, `040-ValueDrivers.md`, a new Watchtower blueprint, a new TermLink worker dir, new lib modules)
- A new subsystem (`policy/` directory; the BVP estimator worker; the Watchtower `/bvp` tab)
- Multiple new CLI verbs (`fw bvp` with subcommands, `fw arc approve-driver`, `fw arc show-suggestions`)
- Schema additions to task frontmatter and arc YAML
- A new policy-as-code gate (the auto-promote policy reads `policy/value-drivers.yaml` and conditionally promotes tasks — this is framework-driven status transition without per-event human approval, which is novel)
- A new canonical doc

Therefore: the first task (T-NEW-1) is and must be an inception task. Subsequent build tasks (T-NEW-2 through T-NEW-15) can be filed via `fw work-on --type build` only after the inception's `decide go` transition AND after HANDOFF-arc-grooming-2026-05-15 first deliverable has shipped.

---

*End of handoff. One-line summary on delivery: filename `HANDOFF-value-prioritisation-2026-05-15.md`, §5 verdict GO-WITH-MODIFICATIONS, 4 open Q items (Q1, Q2, Q3, Q4), 1 dependency (HANDOFF-arc-grooming-2026-05-15).*
