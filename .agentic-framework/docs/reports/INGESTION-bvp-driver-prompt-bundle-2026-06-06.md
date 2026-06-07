---
document_id: INGESTION-bvp-driver-prompt-bundle-2026-06-06
type: ingestion-document
artefact: BVP driver prompt bundle (handler-loaded prompt + reference material)
artefact_kind: prompt-bundle
artefact_status: forward-looking — depends on CLI verbs not yet implemented
governance_gate: inception required for CLI verb implementation (see §3); prompt bundle filing itself does not require inception
depends_on_handoffs: [HANDOFF-arc-grooming-2026-05-15, HANDOFF-value-prioritisation-2026-05-15]
related_handoffs: []
forces_handoff_revision: HANDOFF-value-prioritisation-2026-05-15 → v2 (see §5)
researcher: "Claude (Anthropic) + Dimitri Geelen"
created: 2026-06-06
supersedes: SKILL-INGESTION-aef-bvp-drivers-2026-06-06.md
session_dates: 2026-05-15..2026-06-06
trace_integrity_note: >
  The first version of this ingestion (filed under the SKILL-INGESTION name)
  packaged the artefact as an Anthropic Skill. The user surfaced two failures:
  (1) skill format is the wrong wrapper when invocation is a fw CLI verb,
  (2) the design dialogue was not captured anywhere in the produced files,
  despite the agent committing to do so. Both failures are addressed in this
  revision. A subsequent revision merged the design dialogue and the
  ingestion instructions into this single document (rather than maintaining
  two separate files) on the user's instruction. §6 of this document is
  the full design trail — it is not a reference to a separate file.
---

# Framework agent — please ingest this prompt bundle and incorporate it into AEF

This document does two jobs in one place:
- **§§0–5, 7, 8 — Instructions for ingestion.** What the bundle is, what to check before filing, where to file, what governance gate applies, what handoff revision is needed.
- **§6 — Design dialogue.** The full trail behind every choice in the bundle, captured turn-by-turn with course corrections marked and rejected paths preserved.

Both sections were initially produced as separate files; they were merged because they answer related questions from the same audience (the framework agent at ingestion time, plus any future reader trying to understand why the bundle looks the way it does).

---

## 0. What this is

A **prompt bundle** — files that live under `policy/prompts/` and are loaded by `fw bvp driver suggest` and `fw bvp driver create <topic>` handlers. The bundle encodes the discipline for **proposing and sharpening BVP value drivers** — both global free drivers (in `policy/value-drivers.yaml`) and arc-scoped drivers (in arc YAMLs).

This is **not** an Anthropic Skill. Earlier iteration wrapped this content as a skill; the user correctly identified that skills make sense when an agent discovers them via description-matching, but when invocation is a `fw` CLI verb the discovery layer is the CLI itself and skill wrapping adds packaging overhead without adding triggering value. The content has been reframed as the prompt asset the verb handler loads.

The bundle is **forward-looking**: it describes verbs and behaviours from HANDOFF-value-prioritisation-2026-05-15, several of which need to be added in a v2 revision (see §5). The bundle's design surfaced gaps in the handoff that need closing.

This document is **not a build mandate**. It is a structured ingestion instruction. You decide the gate and scope per AEF's normal governance discipline (G-020 inception triggers, §ACD, agent-gate patterns). Refuse to proceed if any check below fails.

## 1. The artefact

The prompt bundle consists of:

```
policy/prompts/
├── README.md                                   (~50 lines — what lives here, how handlers use it)
├── bvp-driver-session.md                       (~260 lines — the prompt loaded by both verbs)
└── bvp-references/
    ├── core-discipline.md                      (~70 lines — the differentiation test, isolated)
    ├── sharpening-script.md                    (~290 lines — R1-R2 required + O1-O4 optional drilling with worked dialogue)
    ├── global-driver-examples.md               (~150 lines — three worked global proposals)
    ├── arc-scoped-driver-examples.md           (~220 lines — three worked arc-scoped proposals)
    ├── discipline-failure-modes.md             (~160 lines — 8 failure modes with corrections)
    └── artefact-template.md                    (~190 lines — research artefact template + pointer to §6 of this document as canonical example)
```

This document itself is the design trail. It lands at `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` and persists alongside the bundle for permanent reference.

## 2. Pre-action checks (run BEFORE filing the bundle or creating any task)

Same discipline as handoff §11.5. Halt and surface to the human if any fail:

- [x] **HANDOFF-arc-grooming-2026-05-15 is at §5: GO AND its first deliverable has shipped** — verified: `.context/arcs/arc-grooming.yaml` exists with `status: in-progress` (four-state lifecycle landed).
- [x] **HANDOFF-value-prioritisation-2026-05-15 exists and is readable** — verified at `.context/handoffs/HANDOFF-value-prioritisation-2026-05-15.md`.
- [x] **`policy/` directory exists or can be created** — verified at PROJECT_ROOT.
- [x] **No newer ingestion document supersedes this one** — searched `docs/reports/`; only this one present.
- [x] **The previous skill-format artefact (`aef-bvp-drivers.skill`) is not currently installed** — verified absent.

## 3. Governance gate

**Filing the prompt bundle itself** (writing files into `policy/prompts/` and this document into `docs/reports/`) does not require an inception. The bundle is inert documentation until the dependent CLI verbs exist; an installed bundle whose handlers don't yet exist simply means the verbs aren't wired up. The files land under audit (git history), readable but unused.

**However**, the bundle's operational value depends on CLI verbs that don't yet exist in AEF. Building those verbs **does** trip §12 inception-required triggers:

- New CLI routes (`fw bvp driver suggest`, `fw bvp driver create`, `fw bvp recompute`, `fw bvp init`)
- New subsystem behaviour (auto-recompute on driver approval; init bootstrapping)
- New audit log file (`.context/bvp-recompute-log.jsonl`)
- Schema patches to task and arc templates (already covered by HANDOFF-value-prioritisation T-NEW-3)

Therefore the recommended sequence is:

1. **File the bundle and this document now** — `policy/prompts/` files plus this ingestion document into `docs/reports/`. This is reversible (single git revert) and provides forward-looking documentation.
2. **Revise HANDOFF-value-prioritisation-2026-05-15 to v2** with the new verbs as additional constituent slices (see §5).
3. **File the value-prioritisation inception** per the handoff's §7 — that inception's decide-go transition produces the build tasks that make the bundle operational.

Steps 2 and 3 are gated on the arc-grooming first-deliverable check above.

## 4. Bundle installation

Once pre-action checks pass:

1. Create `policy/prompts/` directory if absent
2. Copy `README.md`, `bvp-driver-session.md`, and `bvp-references/*.md` into place
3. Copy this ingestion document into `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` (or assign a real T-ID per AEF's task-ID allocation and rename accordingly)
4. Verify cross-references — `policy/prompts/README.md` links to `bvp-driver-session.md`; `bvp-driver-session.md` links to `bvp-references/*`; `artefact-template.md` references §6 of this document as the canonical example
5. No other configuration required — the bundle is inert until the verb handlers are built

If the previous skill-format artefact (`aef-bvp-drivers.skill`) was installed: uninstall it as part of this filing. The skill and bundle would duplicate triggering surface.

## 5. HANDOFF-value-prioritisation-2026-05-15 needs revision to v2

The bundle design surfaced five additions that the current handoff doesn't cover. These need to land as new constituent slices in a v2 revision (`supersedes: HANDOFF-value-prioritisation-2026-05-15`):

### 5.1 `fw bvp driver suggest` verb

Handler invokes the primary agent with `policy/prompts/bvp-driver-session.md` loaded and `mode = suggest`. Captures the resulting candidates, surfaces them to the human, runs sharpening on the picked one, writes the driver to `policy/value-drivers.yaml` (or arc YAML for arc-scoped) and writes the research artefact to `docs/reports/T-XXXX-bvp-driver-<slug>.md`.

### 5.2 `fw bvp driver create <topic>` verb

Same as 5.1 but with `mode = create` and the topic argument passed through. Skips the discovery step.

### 5.3 `fw bvp recompute [--scope global | --scope arc:<id>]` verb

Triggers recomputation of BVP scores via the TermLink bvp-estimator worker. Two invocation modes:

- **Auto** — invoked by framework as consequence of `fw arc approve-driver` (arc-scoped scope, no human prompt needed)
- **Prompted** — invoked by human after `fw bvp driver --add` (global scope), with human-confirmation prompt before execution

Writes audit entry to `.context/bvp-recompute-log.jsonl` per invocation: `{ts, scope, trigger, driver, tasks_rescored, arcs_rescored, summary_delta}`.

The "auto on arc-scoped, prompt on global" asymmetry is a real design decision — documented in §6.4.6 below. Asymmetry justified: automate the cheap, prompt for the expensive.

### 5.4 `fw bvp init` verb (idempotent)

Idempotent first-time-setup. Detects current state and acts additively:

- Creates `policy/value-drivers.yaml` with default D1-D4 if absent
- Creates `policy/bvp-scoring-rubric.md` skeleton if absent
- Patches task/arc templates with BVP fields if missing
- Creates audit log files (`.context/bvp-weight-history.yaml`, `.context/bvp-recompute-log.jsonl`, `.context/audits/arc-scoped-driver-bypass.jsonl`, `.context/audits/bvp-auto-promote-log.yaml`)
- Starts the bvp-estimator TermLink worker (or surfaces start instructions)
- Triggers initial scoring of all existing tasks and arcs (writes to `bvp_scores_proposed:`; nothing confirmed until `fw bvp confirm`)
- Surfaces existing in-progress arcs that have no arc-scoped driver decision (recommendation, not gate — they're grandfathered per arc-grooming D3)

Idempotency means: running it twice is safe; only does work that hasn't been done.

### 5.5 Auto-recompute on `fw arc approve-driver`

Framework behaviour change: after `fw arc approve-driver <arc> "<name>" --weight N` lands (or `--none --justification`), framework auto-triggers `fw bvp recompute --scope arc:<arc>`. Bounded to that arc's tasks. No human prompt — the approval *is* the human's consent to the consequence.

For batch-propose with multiple approvals in a session, the auto-trigger runs **once after the last approval in the batch**, not once per approval. Single rescore.

For `--none --justification`, no driver landed means nothing to rescore — auto-trigger skipped, but the abandonment-log entry is still written.

### 5.6 Suggested handoff revision approach

Single bump v1 → v2 with `supersedes: HANDOFF-value-prioritisation-2026-05-15`. Don't incrementally amend; the additions are coherent enough to land as one revision. The v2 should:

- Add the five new slices (T-NEW-16 through T-NEW-20 in §7) — or renumber if preferred
- Update §3 (Findings) to reference this document as evidence that the operational shape was worked through
- Add to §11 (Artifacts) — link to the bundle and to this document
- Update §4 (Decisions) — the auto-vs-prompt recompute asymmetry deserves D10 (or wherever it lands)
- Update §4a (Assumptions) — the bundle assumes the verbs ship; this is now circular (handoff drives bundle, bundle drives handoff revision) — call this out honestly
- §11.5 — add the dependency on the bundle being filed before the value-prioritisation inception decide-go transitions

---

## 6. Design dialogue — the trail behind every choice in the bundle

The bundle's design was worked out across approximately 50 conversational turns spanning 2026-05-15 to 2026-06-06. This section captures the load-bearing moves — what was proposed, what was rejected, where the agent was wrong and was corrected, what the human's pushbacks were.

This is the canonical model for what driver-session artefacts should look like. The bundle's `artefact-template.md` points back here.

### 6.0 Why this section exists

The prompt bundle being shipped is the operational mechanism for two new framework verbs: `fw bvp driver suggest` and `fw bvp driver create <topic>`. The verbs invoke the primary agent with the prompt loaded, the agent runs a sharpening session with the human, the framework writes the resulting driver and a research artefact.

Without this section, future readers see the final prompt with no record of *why* it looks the way it does — what was considered and rejected, where the agent's initial proposals were wrong and got corrected, what discipline emerged from the conversation rather than being assumed.

The section covers the full design arc, not just the bundle's construction. The bundle rests on the BVP system design (HANDOFF-value-prioritisation-2026-05-15), which rests on the Arc primitive grooming work (HANDOFF-arc-grooming-2026-05-15). The full sequence is captured here in summary, with the bundle-design segment given the densest treatment because that's where the most active back-and-forth occurred.

### 6.1 Origin context

The conversation began with the human asking the agent to read Dimitri Geelen's 2019 blog post on Business Value Points for backlog prioritisation. The blog described a mechanism: define value drivers, weight them, score features 0–5 per driver, sum to get BVP, plot against cost in a quadrant view, reserve budget for high-value/low-cost work that workstreams could pull without governance overhead.

The human's goal was to adapt this mechanic to AEF, using the four Constitutional Directives (Antifragility, Reliability, Usability, Portability) as base value drivers, with the ability to add and delete additional drivers, and with the same mechanism operating at both arc and task level.

That framing — "adapt this 2019 mechanic to a 2026 framework" — set the design problem. Everything downstream is the negotiation of how the adaptation lands.

### 6.2 Phase 1 — BVP system design (May 15)

This phase is summarised here. The detailed design dialogue from this phase is captured in HANDOFF-value-prioritisation-2026-05-15 §10 (Dialogue log). What follows is the load-bearing moves from that phase, kept brief because the handoff carries the detail.

#### 6.2.1 Directive priority — lexicographic vs weighted-sum

The agent initially presented three options for expressing directive priority:
- **A.** Strict lexicographic — D1 always wins ties, then D2, etc. Loses the ability to compensate. Can't be expressed as a single comparable number.
- **B.** Weighted-sum with priority-respecting weights (default 9/7/5/3). Preserves BVP as comparable. Allows compensation when lower-priority support is high.
- **C.** Hybrid — weighted-sum with lexicographic override at large D1 deltas. Complexity-tax for a rule that probably rarely fires.

**Human's response:** "weighted sum, the directives priority will be translated in weighting."

**[DECISION]** Option B (weights 9/7/5/3 for D1–D4). Even gaps keep ordering visible. Free drivers cap at 9. The handoff's D1.

**[REJECTED]** Options A and C — the human's intuition was clear; the agent had offered three options but only one was actually viable.

#### 6.2.2 Arc model — aggregation vs independent scoring

The agent presented two options:
- **Model A.** Arc value = aggregation of child task BVPs (sum or mean).
- **Model B.** Arc gets its own BVP, scored independently; child-task aggregate shown as sanity check.

The agent initially leaned Model B but kept Model A on the table.

**Human's pushback:** "somethings doesn't click with me yet, it would mean cramming the arc with a lot of tasks would mean the arc is more valuable then an arc with little tasks."

**[CORRECTION — agent]** The human's pushback was sharper than the agent's framing. Sum-aggregation has the perverse-incentive problem they named; mean-aggregation has the dilution problem. The right resolution is: don't aggregate at all for ranking. Score arcs independently against globals; check coherence per-driver against constituent tasks; never use child aggregates as a ranking input.

**[DECISION]** Model B refined — arc has its own BVP for arc-vs-arc ranking; coherence diagnostic (per-driver, not aggregated) flags arcs that claim a directive score their tasks don't support. The handoff's D2 and D3.

#### 6.2.3 Arc-scoped drivers — separate from globals

The human introduced the concept: "we could have another prioritisation mechanism going, e.g. arc tasks get one or more additional drivers that reflect arc purpose and goals, so within the arc prioritisation also can take place."

The agent worked through the cap issue. Arc-scoped drivers in addition to 9 globals would mean 12 active drivers in some contexts.

**[DECISION]** Arc-scoped drivers exist separately. Global drivers (≤9) used for arc-vs-arc ranking. Arc-scoped (≤3 approved per arc, weight ≤6) only affect task ranking *within* that arc. The 9-cap stays meaningful because it bounds the *global* vocabulary; arc-scoped drivers are local concerns and don't compete for global slots. The handoff's D2 (extended).

#### 6.2.4 Task estimator runtime — TermLink vs primary agent

The human raised the question: "could be executed through a specialized 'task BVP estimator agent that permanently runs on TermLink' with fallback on every resume."

The agent worked through the differences between task scoring (continuous, statistical, rubric-driven, preload-friendly) and arc-scoped-driver suggestion (rare, interpretive, no preload benefit). The conclusion fell out: split runtimes.

**[DECISION]** Task BVP estimator runs as a TermLink worker; arc-scoped-driver suggester runs on the primary agent. Different reasoning kinds, different scales, different preload payoffs. The handoff's D4. This decision later became load-bearing for the prompt bundle work — the primary-agent half is what the prompt operationalises.

#### 6.2.5 Cost composite — using existing AEF signals

The human asked: "what do we have at current that we can sensibly apply to estimate costs?"

The agent surfaced three signals already in AEF: blast_radius (from `fw fabric`), tier (from check-tier0), historical effort (from `fw metrics`).

**[DECISION]** Composite cost = `0.6 × normalize(blast_radius) + 0.3 × tier_weight + 0.1 × effort_estimate`. T-shirt fallback when blast radius not yet computable. The handoff's A6.

#### 6.2.6 Free-driver cap and add-one-drop-one

The human: "max 9, adding one means dropping one."

**[DECISION]** Total cap 9 (4 protected + 5 free). At cap, adding requires removing. The handoff's D1 (cap component).

#### 6.2.7 Phase 1 summary

Phase 1 produced two handoffs (HANDOFF-arc-grooming-2026-05-15 and HANDOFF-value-prioritisation-2026-05-15) and four artefacts in the project knowledge base. The BVP system itself was designed; what remained was the operational mechanism for proposing drivers — which is what Phase 3 addressed.

### 6.3 Phase 2 — Handoff format negotiation (May 15, parallel to Phase 1)

While Phase 1's design was being worked out, the handoff format itself became a topic. The framework agent had provided a structured handoff template; the human and the agent worked through whether the format actually served research handoffs well.

#### 6.3.1 The §7 overreach

The format's §7 required the research side to produce task breakdowns with verification commands, slice IDs, dependency expressions. The agent drafted toward that.

**Human's pushback:** "are we being asked for providing a complete work package, because that is actually the scope of the framework agent? We will not create tasks (we can suggest), the framework agent is the specialist for this also format, workflow etc. We should be able to provide enough structure and information for the framework agent to ingest it and we should provide a clear 'prompt/instruction' on how to process and structure it."

**[CORRECTION — agent]** The human was right. The format conflated research output (problem framing, findings, decisions, dialogue) with work-package output (task slices, verification commands, sizing). The research side shouldn't be drafting tasks for the framework agent to rubber-stamp.

The agent drafted a critique note to send back to the framework agent.

**[DECISION]** Format revised by framework agent (v2 then v3). Key changes:
- "Research is not authorization" became a top-level binding
- `Operationalises: F<x>, D<y>` per task — §7 became "which findings/decisions need operationalising," not "draft tasks"
- §11.5 pre-action checks added
- `depends_on_handoffs:` and `related_handoffs:` frontmatter fields for chains

#### 6.3.2 The depends_on_handoffs design

The agent initially proposed `depends_on_handoffs:` as a single field. The framework agent and the human iterated:

- **Minimal form:** flat list `depends_on_handoffs: [HANDOFF-X]`. Single field, dual semantic check in §11.5 (must be GO and first-deliverable shipped).
- **Explicit form:** list of `{id, requires}` pairs with closed-set `requires:` values.

The framework agent recommended minimal-form-with-rescue-valve: ship `depends_on_handoffs:` (blocking) alongside `related_handoffs:` (informational), tight semantic, §11.5 enforces.

**[DECISION]** v3 shipped this shape. Misuse caught by the validator failing closed and surfacing to human.

#### 6.3.3 Phase 2 summary

The handoff format itself was refined during research — a meta-correction that affected how the BVP work was structured for handoff. The relevance to Phase 3 (prompt bundle) is that the same "research-not-authorization" discipline carries through: a prompt bundle for proposing drivers is research output; the framework agent decides how to file it.

### 6.4 Phase 3 — Skill / prompt bundle design (June 6)

This phase is the densest. It's also where the agent made the most errors. The detail here is the model the user asked the agent to apply when it failed to apply it the first time.

#### 6.4.1 The ambiguous initial ask

**Human:** "/skill-creator please create a skill that can be used to create the 5 additional global skill and arc specific skill"

The phrasing was ambiguous. "Skill" was being introduced as a new word and didn't map cleanly to anything previously discussed. "5 additional global skill" could mean either drivers or skills or something else.

**[CORRECTION — agent, by way of asking]** Rather than guessing, the agent listed three interpretations:
- (1) A skill (Anthropic Skills folder) that helps create value drivers
- (2) "Skill" meaning "driver" — i.e. "create 5 candidate drivers right now"
- (3) Something else being missed

**Human clarification:** "please read the contents of this chat then you will understand, you will be use in projects and you need to create value drivers for project and / or arcs in projects."

**[LOCKED INTERPRETATION]** Interpretation (1). The artefact is for future agents to do driver-creation work. Not a one-shot generator, not a meta-tool.

#### 6.4.2 v1 — batch-propose-shaped skill

The agent read the `/mnt/skills/examples/skill-creator/SKILL.md` to understand the skill format, then built a skill folder with:
- `SKILL.md` (169 lines) — two workflows: global free drivers and arc-scoped drivers
- `references/global-driver-examples.md`
- `references/arc-scoped-driver-examples.md`
- `references/discipline-failure-modes.md`

Packaged as `aef-bvp-drivers.skill`, validated, ~15KB.

The shape was **batch-propose only.** Workflow A from the later v2 — write multiple proposals to `proposed_scoped_drivers:` at arc-draft time.

#### 6.4.3 The two-path push

**Human:** "so two paths /bvp-drivers-suggest --> skill scan project and suggest a number of possible drivers, user pick a driver, skill then helps user to sharpen the driver by interactive grilling and consultative conversation and also suggest the 5 scoring levels (0–5). or /bvp-driver-create same but then about a particular topic user provides after the /command in brackets ()"

**[CORRECTION — agent]** The v1 skill was the wrong shape. Batch-propose covers arc-draft state but misses the interactive single-driver case entirely. Also missing: the 0–5 scoring rubric per driver — v1 produced drivers with rationale and weight, no per-level scoring criteria. That was a meaningful gap.

The agent mapped the proposal to three workflows:
- A. Batch propose (existing v1 shape — kept)
- B. Discover + sharpen (new — `/bvp-drivers-suggest`)
- C. Sharpen named topic (new — `/bvp-driver-create(<topic>)`)

Workflows B and C share a sharpening subroutine.

#### 6.4.4 Three design questions on the rebuild

The agent raised three questions:

1. **Slash commands or natural-language triggers?** Skills don't natively have slash-command syntax. The agent proposed treating "/bvp-drivers-suggest" as memorable shorthand the skill recognises alongside natural language phrasing.

2. **Sharpening rubric depth — light vs heavy.** The agent proposed light by default (one sentence per level), drill deeper when the human engages.

3. **Where does the sharpening output land?** The agent proposed: skill produces paste-ready content in chat, human copies to the right path and commits.

#### 6.4.5 Human's responses on the three questions

**(1) Slash commands vs fw verbs:**

**Human:** "so we could also just add a fw cli command that does the same?? btw we are now also wrapping cli in mcp does that make any difference?"

**[CORRECTION — agent]** The right answer was the human's reframe. `/bvp-drivers-suggest` shouldn't be a slash-prefix the skill recognises — it should be `fw bvp driver suggest`, a real CLI verb. The skill (or whatever it became) is what the verb's handler invokes.

The agent worked through the MCP wrapping question: MCP doesn't fundamentally change the design, but it adds a downstream affordance — the same verb becomes both a CLI invocation and a Watchtower UI action.

**[DECISION]** Make it `fw bvp driver suggest` and `fw bvp driver create <topic>`. The skill is the prompt the verb handler loads. This was a small but real scope addition to HANDOFF-value-prioritisation-2026-05-15 — the original handoff's T-NEW-5 covered `fw bvp driver --add/--remove` only.

**(2) Where outputs land:**

**Human:** "huh outlands in console and is recorded in research & task artefact not?? as per framework directive ?? please investigate and reflect on what makes sense from a usability, reliability and low friction perspective."

The agent investigated AEF's existing patterns: inception writes to `docs/reports/T-XXXX-*.md` and to `.tasks/` files; audit-trailed governance events go to `.context/audits/*.jsonl`; conversation outputs currently land in console (ephemeral). The pattern: outputs that matter get permanent paths under audit; ephemeral outputs are an anti-pattern.

**[CORRECTION — agent]** The agent's initial framing missed this entirely. The skill's outputs (the driver spec, the sharpening dialogue, the consequences) should produce a research artefact at `docs/reports/T-XXXX-bvp-driver-<name>.md` — same pattern as inception artefacts. Not paste-ready content for the human to copy; a properly-filed artefact under the framework's traceability discipline.

**[DECISION]** Every driver session produces a research artefact. The skill should explicitly write the artefact content as part of its output.

(This decision had a follow-up correction — see 6.4.7 below.)

**(3) Sharpening depth:**

**Human:** "hybrid suggest, drill skip if indicated, if we can get more depth that's great but if not we need to work with what we have."

**[DECISION]** R1 differentiation + R2 weight calibration are required. O1 edge cases, O2 scope test, O3 overlap test, O4 scoring rubric are optional — drill when the human engages, ship-with-what-you-have when answers flatten.

#### 6.4.6 The additional considerations

**Human:** "additional consideration: should it end with one or more tasks to add the skill and recalculate BVP scores for tasks and arcs?"

The agent worked through three after-action cases:
- Batch propose (workflow A): rescore tasks in this arc
- Suggest (workflow B) for global driver: rescore everything (project-wide)
- Suggest (workflow B) for arc-scoped: rescore this arc's tasks
- Create (workflow C) for global: rescore everything
- Create (workflow C) for arc-scoped: rescore this arc's tasks

The agent raised two sub-questions:
1. Is rescoring a `fw task create` event or a `fw bvp recompute` invocation?
2. Should rescoring be automatic at session end, or human-confirmed?

The agent proposed: `fw bvp recompute` as a verb (not a task); automatic for arc-scoped, prompt-confirmed for global.

**[REJECTED]** Filing rescoring as a `fw task create` event — rescoring is mechanical follow-up, not work with acceptance criteria. Task lifecycle would be bureaucratic overhead.

**Human's response:** "on 1 auto run indeed, and agree with the nuance of hint 2."

**[DECISION]** `fw bvp recompute [--scope global | --scope arc:<id>]` verb. Auto-trigger on arc-scoped driver approval (cheap, bounded, obvious consequence). Prompt-confirm on global driver addition (expensive, project-wide, might want bundling).

Audit entries to `.context/bvp-recompute-log.jsonl`.

**Human:** "should we also have a bvp initialize (first time setup for framework upgrades or fresh install on existing codebase)?"

**[CORRECTION — agent]** The agent had missed this entirely. A fresh install of BVP on an existing codebase has 50–500 unscored tasks; without an init verb, every BVP feature is dark until the user manually triggers scoring per task.

**[DECISION]** `fw bvp init` verb. Idempotent (detects state, acts additively). Creates policy files, patches templates, creates audit logs, starts the bvp-estimator worker, triggers initial scoring of existing tasks/arcs (writes to `bvp_scores_proposed:`, nothing confirmed). Surfaces existing in-progress arcs that lack arc-scoped driver decisions (recommendation, not gate — grandfathered per arc-grooming D3).

#### 6.4.7 The artefact-pattern correction

This is the moment most worth capturing honestly, because the agent missed it twice — once in the original draft and once in the explanation.

In response to "where do outputs land," the agent had proposed: skill produces paste-ready content in chat, human copies to file path.

**Human's pushback:** "this does not make sense, please check how we do inception at the moment, I would guess it maybe a similar workflow."

**[CORRECTION — agent — load-bearing]** The agent had defaulted claude.ai-mode behaviour ("agent produces content in chat, human handles file write") as the canonical mode. But AEF's whole point is structural enforcement — agents work *through* `fw` verbs, which write to the right places under governance. `fw inception start` writes files directly. `fw arc create` does too. Manual file paths are the failure mode the framework was built to prevent.

The correct model:
- The skill's *output* is what gets written
- The *write itself* is done by `fw` verbs (the new `fw bvp driver suggest|create` handlers, which would write the artefact and update the driver files)
- Claude.ai-mode (no `fw` available) is a *degraded fallback*, not canonical

The agent apologised for the misread and acknowledged it should redesign the skill's output to be what the `fw` handler writes, not what the human pastes.

**[DECISION]** Two output streams from each session:
- Driver spec → written into `policy/value-drivers.yaml` (free) or `proposed_scoped_drivers:` (arc-scoped) by the `fw` handler
- Research artefact → written to `docs/reports/T-XXXX-bvp-driver-<name>.md` by the `fw` handler

Both happen as part of the verb's execution. Human role: invoke verb, engage in dialogue, commit changes.

#### 6.4.8 The hedge on missing verbs

The agent had hedged on whether the skill should describe `fw bvp recompute` behaviour when the verb didn't yet exist.

**Human:** "why would we wait?"

**[CORRECTION — agent]** The hedge was unnecessary. The skill describes the canonical workflow; missing verbs in the environment are surfaced as degraded-mode behaviour ("verb not implemented in this AEF version; ..."), not design-time omissions.

**[DECISION]** Build the skill against the full forward-looking design — `fw bvp recompute`, `fw bvp init`, `fw bvp driver suggest`, `fw bvp driver create <topic>` all assumed to exist. Environmental gaps surfaced honestly when hit.

#### 6.4.9 v2 build

The agent rebuilt the skill with:
- Three workflows (batch / suggest / create) sharing the sharpening subroutine
- Sharpening subroutine (R1, R2 required; O1–O4 optional with skip-when-stuck)
- Session-close recompute integration (auto for arc-scoped, prompt for global)
- `fw bvp init` detection (refuses to run normal workflows on uninitialised project)
- Research artefact production with §10-style dialogue log

Packaged as `aef-bvp-drivers.skill` v2, ~30KB, 1388 lines across six files.

#### 6.4.10 The ingestion prompt

**Human:** "now add a prompt on top for the framework agent to ingest this, inception this and incorporate in the framework."

The agent wrote `SKILL-INGESTION-aef-bvp-drivers-2026-06-06.md` — 170 lines describing how the framework agent should file the skill, what pre-action checks to run, what governance gate applies, what handoff revision was needed.

#### 6.4.11 The double correction — what triggered the rebuild

After delivery, the human surfaced two failures:

**Failure 1:** "is it really still a skill as we are using the FW cli command?"

**[CORRECTION — agent — load-bearing]** No, it isn't. If the human invokes `fw bvp driver suggest` and the verb's handler does the work, the artefact is a CLI command with a prompt. The "skill" shape (SKILL.md + references in Anthropic Skills format) is a wrapper around content that mostly belongs as the handler's prompt assets. Skills make sense when an *agent* discovers and invokes them via description-matching. When invocation is `fw bvp driver suggest`, the discovery layer is the CLI; the skill format adds packaging overhead without adding triggering value.

The agent should have caught this two turns earlier when the human said "we could also just add a fw cli command that does the same?" The implication was clear; the agent confirmed the CLI-verb route but kept building toward a skill-format package anyway. The correction should have happened then.

**Failure 2:** "we said to include our dialogue, our options explored, our decisions for and against. You reflected on the importance of this, AND NONE!!! of what we have agreed or this traceability is in the document!!!"

**[CORRECTION — agent — load-bearing]** Worse failure. The agent explicitly committed in an earlier turn (§3c of a response) to capturing the dialogue as the artefact's shape. It then wrote artefact files that described *how future sessions should capture their dialogue* without capturing *the actual* dialogue. The `artefact-template.md` had a fabricated V_SECURITY_POSTURE worked example instead of real design history. SKILL-INGESTION §6 listed topic-names without preserving the back-and-forth.

The agent documented the *theory* of capture and skipped the *practice* of it. The human's response was correct calibration: "BAD AGENT SHAME ON YOU."

**[DECISION]** Rebuild:
- Drop the skill-format wrapper. Ship as prompt bundle that fits `fw bvp driver suggest|create` handler invocation.
- Write a real design dialogue document capturing the actual conversation, with [CORRECTION] markers, rejected paths, and decisions for and against.

#### 6.4.12 The fragmentation correction (this revision)

After the rebuild, the human noted that the output was now three separate documents (ingestion prompt, design dialogue, and the bundle itself).

**Human:** "ok why doi i now have three seperate documents?"

**[CORRECTION — agent]** The split was wrong. The ingestion document and the design-dialogue document were answering related questions from the same audience and belonged in one document. The agent had separated them because of over-correcting for having missed the dialogue last time — creating a new standalone artefact instead of folding the dialogue into the ingestion. This is the document that resulted from merging them.

**[DECISION]** Merge the ingestion content and the design dialogue into a single document at `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md`. Update the bundle's `README.md` and `artefact-template.md` to reference §6 of this document rather than a separate file. Two documents total: this one, and the bundle (`policy/prompts/`).

### 6.5 Decisions ledger

All load-bearing decisions from the full arc, in one place. Phase indicators trace back to subsections above.

| ID | Decision | Decided-by | Phase | Reversibility |
|---|---|---|---|---|
| D-P1-1 | Weights 9/7/5/3 for D1–D4; weighted-sum BVP, no lexicographic | human | 6.2.1 | cheap |
| D-P1-2 | Arc scored independently; per-driver coherence check vs constituent tasks; no aggregation | jointly | 6.2.2 | cheap |
| D-P1-3 | Arc-scoped drivers separate from globals; cap 3 approved per arc, weight ≤6 | human | 6.2.3 | cheap |
| D-P1-4 | Task estimator on TermLink; arc-scoped suggester on primary agent | human | 6.2.4 | medium |
| D-P1-5 | Composite cost formula 0.6/0.3/0.1 (blast_radius/tier/effort) | jointly | 6.2.5 | cheap |
| D-P1-6 | Global driver cap 9 (4 protected + 5 free); add-one-drop-one | human | 6.2.6 | cheap |
| D-P1-7 | Auto-promote off by default; opt-in via policy file | jointly | (HANDOFF-vp D8) | cheap |
| D-P2-1 | Handoff format §7 is proposal, not work-package; framework agent owns task shaping | jointly | 6.3.1 | n/a |
| D-P2-2 | `depends_on_handoffs:` blocking; `related_handoffs:` informational; §11.5 dual-condition check | jointly | 6.3.2 | n/a |
| D-P3-1 | Three workflows: batch propose (A) + suggest (B) + create (C); B and C share sharpening subroutine | jointly | 6.4.3 | cheap |
| D-P3-2 | Sharpening: R1+R2 required (differentiation, weight); O1–O4 optional drilling; skip-when-stuck | human | 6.4.5 | cheap |
| D-P3-3 | Invocation via `fw bvp driver suggest` and `fw bvp driver create <topic>` — real CLI verbs | human | 6.4.5 | medium |
| D-P3-4 | Outputs land as research artefacts via `fw` handler writes, not chat-paste | human | 6.4.7 | cheap |
| D-P3-5 | Auto-recompute on arc-scoped driver approval; prompt-confirm on global driver addition | human | 6.4.6 | cheap |
| D-P3-6 | `fw bvp init` verb — idempotent, detects state, acts additively | human | 6.4.6 | cheap |
| D-P3-7 | Build skill against forward-looking design; surface degraded-mode honestly when verbs absent | human | 6.4.8 | cheap |
| D-P3-8 | Ship as prompt bundle (`policy/prompts/bvp-driver-session.md` + references), not skill-format package | human | 6.4.11 | cheap |
| D-P3-9 | Every session produces a research artefact with §10-style dialogue log | jointly | 6.4.5 | cheap |
| D-P3-10 | Suggestion count uncapped, approval capped at 3 — asymmetric (agent generates freely, human prunes) | human | (HANDOFF-vp D6) | cheap |
| D-P3-11 | `proposed_scoped_drivers:` persists for arc lifetime; reference material for focus-shifts, not audit | human | (HANDOFF-vp D7) | cheap |
| D-P3-12 | Merge ingestion document and design dialogue into one document; do not fragment | human | 6.4.12 | cheap |

### 6.6 Rejected paths preserved

Things considered and dismissed, with reasoning. These are kept because future revisits will rediscover them and need the original reasoning.

#### 6.6.1 Lexicographic directive ordering
**Why rejected:** Loses compensation flexibility. Can't be expressed as comparable BVP number. Quadrant maths breaks.

#### 6.6.2 Hybrid lexicographic with weighted-sum override
**Why rejected:** Complexity-tax for rare rule. Two scoring regimes harder to reason about than one.

#### 6.6.3 Aggregation of child task BVPs as arc value
**Why rejected:** Perverse incentive (sum: cramming arc with low-value tasks makes it "more valuable"). Dilution (mean: high-value arcs with some housekeeping dilute to average). Neither tracks what the arc itself is for.

#### 6.6.4 Strict suggestion cap (e.g. "agent must propose exactly 3 drivers")
**Why rejected:** Forces manufacturing drivers when fewer surface. The whole discipline is "don't manufacture." Asymmetric caps (uncapped suggestions, capped approval) preserve discipline.

#### 6.6.5 Audit-trail framing of `proposed_scoped_drivers:`
**Why rejected (by human reframing):** The persistence isn't for audit — it's for reuse when focus shifts. Misframing as "audit material" misses the actual value (reference for re-deciding).

#### 6.6.6 Both estimators on TermLink
**Why rejected:** Arc-scoped-driver suggestion is one-shot interpretive work with no reusable state between arcs. Preload buys nothing. Primary agent has arc-creation context for free.

#### 6.6.7 Both estimators on primary agent
**Why rejected:** Task scoring at ~thousand-events/year scale would bog down primary agent or hit determinism issues. Rubric-driven low-temperature mode is exactly what worker preload optimises for.

#### 6.6.8 Auto-run global recompute without prompt
**Why rejected:** Global recompute is project-wide, expensive. Bundling multiple global driver changes in one session before rescoring is reasonable. Human should choose timing.

#### 6.6.9 Skill format (Anthropic Skills folder with SKILL.md frontmatter)
**Why rejected (Phase 3 correction):** Skills make sense when discovered by description-matching. When invocation is `fw bvp driver suggest`, the discovery layer is the CLI; skill wrapper adds packaging overhead without adding triggering value. The content belongs as the handler's prompt asset.

#### 6.6.10 Slash-command syntax (`/bvp-drivers-suggest`)
**Why rejected:** AEF doesn't natively have slash-command syntax. `fw` verbs are the canonical command surface. Make it a real verb (D-P3-3) rather than a slash-prefix the skill recognises.

#### 6.6.11 Task creation for rescoring events
**Why rejected:** Rescoring is mechanical follow-up to a governance event (driver landing), not work with acceptance criteria. `fw bvp recompute` verb with audit log is the right shape.

#### 6.6.12 Chat-paste output (skill produces content in chat, human copies to path)
**Why rejected (Phase 3 correction):** Inverts AEF's structural-enforcement discipline. Manual file paths are the failure mode the framework was built to prevent. `fw` writes through, like inception does.

#### 6.6.13 Separate design-dialogue document
**Why rejected (this revision):** Fragmentation. The dialogue and the ingestion instructions are read together by the same audience. Splitting them creates the very fragmentation the user identified as the problem.

### 6.7 Open questions and follow-ups

Things parked for later:

- **Behavioural validation of HANDOFF-vp A4** (primary agent has enough context at arc-creation suggestion time). Unverifiable until first 3 arcs use the workflow.
- **HANDOFF-vp A6 (cost-formula) validation.** Unverifiable until 30 days of operational data.
- **HANDOFF-vp A3 (estimator cost) validation.** Needs measurement during HANDOFF-vp T-NEW-7 build.
- **HANDOFF-vp A5 (use of `fw arc show-suggestions`).** Operational data only.
- **`fw bvp driver suggest` and `fw bvp driver create` need to be added as constituent slices** to HANDOFF-value-prioritisation-2026-05-15 v2 revision. Also `fw bvp recompute`, `fw bvp init`, and the auto-recompute behaviour. Currently the handoff's T-NEW-5 covers `fw bvp driver --add/--remove` only.

### 6.8 What this dialogue teaches about the prompt bundle's discipline

This section is itself a model of what the prompt bundle requires future driver sessions to produce — a §10-style dialogue log with [CORRECTION] markers, rejected paths preserved, decisions traceable.

Three things the dialogue here demonstrates that the prompt bundle's discipline asks for:

1. **Course corrections are load-bearing.** D-P3-4 (artefact pattern), D-P3-8 (prompt bundle vs skill), D-P3-12 (merge fragmentation), and D-P1-2 (no aggregation) all came from human pushback against initial proposals. Without capturing those, the final shapes look arbitrary. With them, the rationale is locatable.

2. **Rejected paths matter.** The 13 entries in §6.6 are paths someone will rediscover and re-propose months later. Without this record, the reasoning gets re-derived (or re-missed) each time.

3. **The discipline filters the dialogue.** Not every turn in the conversation is captured here. Conversational filler is omitted. What's captured are the moments that moved the position — the same rule applied to driver-creation sessions.

The prompt bundle's `artefact-template.md` describes how to do this for future driver sessions. This section is how the agent should have done it for the bundle itself. The user's correction surfaced the gap; this section (and this document's existence in its merged form) closes it.

---

## 7. What to do now (concrete)

In order:

1. Run pre-action checks (§2). Halt and surface to human if any fail.
2. If checks pass: file the bundle into `policy/prompts/` and this document into `docs/reports/` (§4). This is reversible.
3. If the previous skill-format artefact (`aef-bvp-drivers.skill`) was installed: uninstall it.
4. Surface to the human: "BVP driver prompt bundle is filed at `policy/prompts/`. Ingestion document with design dialogue at `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md`. Operational value pending value-prioritisation-v2 build. Recommend: revise HANDOFF-value-prioritisation-2026-05-15 to v2 incorporating §5 of this document, then file the value-prioritisation inception per the v2 handoff's §7."
5. **Do not auto-build the v2 handoff or the inception.** That requires human direction.
6. Confirm to human with a one-line summary: bundle filed, document at known path, current operational status, pending dependencies.

## 8. Pickup safety markers

> **This is a prompt bundle ingestion document, not a build mandate.** The bundle itself is inert documentation until its dependent CLI verbs exist; filing it is low-risk. The CLI verbs the bundle assumes are build work that requires the value-prioritisation inception per HANDOFF-value-prioritisation-2026-05-15's existing §12 inception triggers. Do not file build tasks for the new verbs (§5) without the v2 handoff revision and the inception's decide-go transition.

If §7 step 1 reveals that arc-grooming hasn't shipped: halt entirely. The bundle is forward-looking even relative to arc-grooming (it uses `arc_id:` and `draft` state). Filing it before arc-grooming lands is acceptable but the surface area for confusion is larger; flag clearly to the human.

If the previous skill-format artefact is still installed when this bundle is being filed: this is not a hard error but creates triggering ambiguity. Uninstall the skill as part of bundle filing per §7 step 3.

---

*End of document. One-line summary on delivery: bundle filed at `policy/prompts/`; this document at `docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` contains both ingestion instructions (§§0–5, 7, 8) and the full design dialogue (§6); governance gate inception required for §5 build work; HANDOFF-value-prioritisation-2026-05-15 revision to v2 recommended; supersedes SKILL-INGESTION-aef-bvp-drivers-2026-06-06.md.*

---

## Ingestion record (filed by framework agent T-2245)

**Filed:** 2026-06-08 by framework agent (Claude Opus 4.7) at operator direction (mid-session pivot to "focus on bvp driver prompt bundle").

**Task:** T-2245 — `ingest BVP driver prompt bundle from upstream pickup (2026-06-06)` (inception, captured → started-work, horizon: later, recommendation: DEFER).

**Pre-action check results (§2):** all 5 PASS — see boxes above.

**Bundle file CONTENTS not provided in the pickup message.** §1 describes 8 files totaling ~1490 LoC (`policy/prompts/README.md` + `bvp-driver-session.md` + 6× `bvp-references/*.md`), but the file bodies were not pasted. Filing of `policy/prompts/*` therefore HELD per T-2245 IW-1, pending operator direction:
- Path A: operator pastes the bundle file contents from the upstream session
- Path B: framework agent authors the bundle files from the §6 design specs (~1490 LoC of derived content)

**§5 CLI verb build work** captured under T-2245 IW-3 with recommendation `DEFER` per the doc's own §7 step 5 + §8 + G-020 + Authority Model. Operator direction required for: (a) v2 handoff revision (IW-2), (b) value-prioritisation inception with decide-go transition (IW-3).
