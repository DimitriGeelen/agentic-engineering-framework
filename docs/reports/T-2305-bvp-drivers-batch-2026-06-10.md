---
artefact_id: bvp-drivers-batch-2026-06-10
task: T-2305
type: driver-session-artefact + pickup-prompt
drivers: [V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC]
session_date: 2026-06-10
session_workflow: create (multi-driver batch — three global free drivers in one session)
session_outcome: shipped-pending-implementation
initiated_by: human
participants: claude-primary + dgeelen
status: forward-looking
recompute_scope: global
recompute_status: pending-implementation
depends_on_handoffs:
  - HANDOFF-arc-grooming-2026-05-15
  - HANDOFF-value-prioritisation-2026-05-15
related_handoffs:
  - docs/reports/INGESTION-bvp-driver-prompt-bundle-2026-06-06.md
related_arcs: []
related_tasks: []
trace_integrity_note: >
  This is a multi-driver batch session — unusual shape relative to the
  standard single-driver template at policy/prompts/bvp-references/artefact-template.md.
  The user requested three drivers be designed in one session. The artefact
  template was adapted to handle multiple drivers in sections 2, 5, and 6
  (which become per-driver subsections) while keeping sections 1, 7, 8, 9,
  10 single (they apply to the session as a whole). The pickup prompt
  (§9) is embedded rather than separated to avoid the fragmentation
  pattern caught earlier in this work.
---

# BVP driver batch session — 2026-06-10

> **CORRIGENDUM at filing time (T-2305, 2026-06-10):** The artefact below was authored against the assumption that `fw bvp driver --add`, `fw bvp recompute`, and `fw bvp init` are forward-looking verbs pending HANDOFF-value-prioritisation v2 implementation. **Live state at filing:** `fw bvp driver --add "name" --weight N --rationale "..."` already exists in the current CLI (`bin/fw bvp driver` help output confirms). Free-driver pool is at 2 of 5 (`F-RECALL`, `F-ORCH`) — **3 slots open**, exact fit for this batch. `fw bvp init` (initialiser) and `fw bvp driver --init` (bootstrap) are also shipped. `fw bvp recompute` verb status: not yet confirmed at filing-time; see §9 pre-action check on this. The artefact's design walk (R1, R2, O1, O2, O3, O4 per driver) stands unchanged; only the deployment-readiness preamble shifts from "pending implementation" to "ready to deploy as soon as operator confirms via Watchtower decision-go on T-2305." Per CLAUDE.md §Inception Discipline #6/#7, this corrigendum is preserved alongside the original analysis to capture the reasoning trail.

Three global free drivers proposed for AEF's initial driver pool. Each tested against the differentiation discipline (`policy/prompts/bvp-references/core-discipline.md`); each sharpened through R1, R2, O1, O2, O4-light-pass per the sharpening subroutine (`policy/prompts/bvp-references/sharpening-script.md`).

This document is both the **session artefact** (§§1–8, 10) and the **pickup prompt** for the framework agent (§9). Single document; no fragmentation.

## 1. Trigger and project state

**Trigger:** human directly requested three drivers be designed for AEF — V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC — plus a pickup prompt for implementation and recompute.

**Project state at session start (as described in original artefact — see corrigendum above for live-state delta):**
- BVP system: designed in HANDOFF-value-prioritisation-2026-05-15 but not yet implemented. The CLI verbs (`fw bvp driver --add`, `fw bvp recompute`, `fw bvp init`) are forward-looking — they will exist after the v2 handoff revision and its inception decide-go transition.
- Driver pool when implemented: D1 Antifragility (w=9), D2 Reliability (w=7), D3 Usability (w=5), D4 Portability (w=3) — protected, fixed. Free pool will be empty (0 of 5) at first init.
- Adding three drivers to an empty pool: 3 of 5 occupied after this batch lands. Plenty of headroom; no swaps needed.

**Why now:** Pre-committing the initial free-driver pool as part of the BVP system's design. Identifying the drivers ahead of implementation lets the framework agent set them up at first init, rather than leaving the pool empty and forcing post-hoc additions when BVP goes live.

## 2. Candidates considered

Three candidates, all proposed by the human. All passed the differentiation test (§3 below). None rejected.

| Candidate | One-line rationale | Outcome |
|---|---|---|
| V_PROMPT_QUALITY | Discriminates prompt-craft work from work that doesn't touch LLM instructions. Core to AEF's value proposition as an agentic framework. | shipped |
| V_CONTEXT_FABRIC | Discriminates work on the memory layer (working/project/episodic memory, semantic search) from non-memory work. Load-bearing for cross-session continuity. | shipped |
| V_COMPONENT_FABRIC | Discriminates work on the topology layer (dependency mapping, blast-radius, drift detection) from work elsewhere. Load-bearing for BVP cost composite and audit. | shipped |

**Considered but not pursued in this session:**

- **Splitting V_CONTEXT_FABRIC and V_COMPONENT_FABRIC into separate "quality / reliability / speed" drivers each.** Rejected: would consume 6 of 5 free slots for what is essentially "fabric-improvement work" (single concept per fabric). Most fabric work touches multiple aspects together; split drivers would correlate strongly. The discipline's "differentiation" test wants drivers that discriminate meaningfully, not drivers that decompose a single concern into sub-concerns.
- **V_AGENT_BEHAVIOUR or V_AGENT_DISCIPLINE.** Not proposed by the user but considered analytically — work that improves how agents follow framework discipline (e.g. §ACD enforcement, agent-gate patterns). Rejected for this session: would overlap heavily with D1 Antifragility (failures-as-learning is a kind of agent-discipline improvement) and V_PROMPT_QUALITY (prompts often encode agent discipline). Worth revisiting in a future session if the overlap can be sharpened.

## 3. Sharpening dialogue — per driver

### 3.1 V_PROMPT_QUALITY

**R1 — Differentiation:**

> "Discriminates work that improves the quality of LLM prompts (templates, instructions, rubrics, prompt-handler design) from work that improves other aspects of the system."

D1 Antifragility covers learning-from-failure (broader than prompt quality — a system can become antifragile without any prompt changes). D2 Reliability covers no-silent-failures (a low-quality prompt isn't a "silent failure" — it produces output, just lower-quality output). D3 Usability covers human-facing UX (prompts are agent-facing). D4 Portability is unrelated.

The dimension is real and not currently captured. Differentiation: confirmed.

**R2 — Weight:**

Proposed weight: **7**. Same tier as D2 Reliability.

Rationale: prompt quality is core to AEF's value proposition. AEF is a framework for agentic engineering; the quality of agent output directly depends on prompt quality. Below D1 because D1 is more general (system improves under any stress, not just from prompt iteration). Level with D2 because prompt quality is a major component of system reliability (a well-crafted prompt produces more reliable output) — but not above D2, because reliability covers more failure modes than prompt-induced ones. Above D3 because prompts are not user-facing.

**[CORRECTION — agent during analysis]** Initially considered weight 8, putting it above D2. Rejected: would imply prompt quality is more important than general system reliability, which is a strong claim. AEF can have excellent prompts and still fail on non-prompt reliability concerns; the reverse is also true. They're peers, not nested.

**O1 — Edge cases:**

| Level | Example task |
|---|---|
| 5 | Designing a new prompt-bundle pattern (like the BVP driver session prompt we just built) — foundational prompt-quality work that becomes a reusable pattern |
| 0 | Refactoring `lib/arc.sh` state machine — pure infrastructure, no prompts involved |
| Borderline 2/3 | Adding one worked example to an existing prompt — meaningful if the example fills a gap that was misdirecting agents; minor if it's redundant with existing examples |

**O2 — Scope test:**

Apply to a random task from each existing arc:
- `orchestrator-rethink`: "improve route_cache learning prompt" → V_PROMPT_QUALITY=4
- `embeddings-strategy`: "design retrieval-quality rubric" → V_PROMPT_QUALITY=3 (rubric is prompt-adjacent)
- `arc-grooming`: "write 012-ArcSystem.md" → V_PROMPT_QUALITY=0 (documentation, not a prompt)
- `dispatch-safety`: "design uncertainty-handling instruction patterns" → V_PROMPT_QUALITY=4

Scores meaningfully across multiple arcs. **Global confirmed.**

**O3 — Overlap test (analytical, not dialogued):**

- With D2 Reliability: mild overlap. A higher-quality prompt is more reliable in producing the desired output. But the dimensions are distinguishable: a prompt can be high-quality (well-crafted, clear, examples-rich) but unreliable due to environmental factors (model variance, context-window limits). Conversely, a poorly-crafted prompt can be reliable in producing consistently-poor output. They move together but not in lockstep.
- With D1 Antifragility: weak overlap. Improving prompts based on failure analysis is a form of antifragility, but D1 is broader.
- No strong overlap with D3 or D4.

Not a shadow dimension. Real driver.

**O4 — 0–5 scoring rubric (light pass):**

| Level | Definition |
|---|---|
| 0 | No prompt-related work — pure infrastructure, refactor, or unrelated feature |
| 1 | Touches a prompt incidentally (changes a string that happens to be a prompt) but no quality improvement intent |
| 2 | Minor prompt improvement — clarification of wording, fixing a typo in an instruction, small structural cleanup |
| 3 | Meaningful prompt improvement — adds a worked example, refines an instruction, improves a rubric |
| 4 | Material prompt improvement — new prompt-handler design, restructured instruction patterns, multi-section refinement |
| 5 | Foundational prompt-quality work — new prompt-creation system, framework-level prompt-template patterns, prompt-bundle that becomes pattern for other prompts |

**Borderline notes:** Rate-limiting borderline cases will likely surface in first-use. Light pass; expect refinement.

### 3.2 V_CONTEXT_FABRIC

**R1 — Differentiation:**

> "Discriminates work that improves the quality, reliability, or speed of the Context Fabric (working/project/episodic memory, semantic search via `fw recall`) from work that touches other subsystems."

D1, D2, D3, D4 cover reliability and antifragility generally, but don't isolate the memory layer specifically. Context Fabric is load-bearing for cross-session continuity — without it, AEF agents start cold every session and lose all context. Discriminating "is this work on the memory layer?" is meaningful.

**[CORRECTION — agent during analysis]** Initially considered splitting into V_CF_QUALITY, V_CF_RELIABILITY, V_CF_SPEED. Rejected because most context-fabric improvement work touches multiple aspects simultaneously (a speed improvement often improves reliability via reduced timeout; a quality improvement often touches structure that affects speed). Three separate drivers would correlate strongly and burn 3 free slots on one concern. One driver per fabric is the right granularity.

**R2 — Weight:**

Proposed weight: **7**. Same tier as D2 Reliability.

Rationale: Context Fabric is the substrate for cross-session continuity, which is one of AEF's three pillars (per README: task management, session memory, component topology). Improving it directly improves AEF's "memory" value proposition. Below D1 (broader). Level with D2 (Context Fabric reliability is a major subset of system reliability). Above D3.

**O1 — Edge cases:**

| Level | Example task |
|---|---|
| 5 | New memory architecture — `embeddings-strategy` arc's potential outcome (replacing ada-002 with local embedder + fine-tuning) is exactly this |
| 0 | `arc-grooming` lifecycle refactor — touches arcs, not memory |
| Borderline 2/3 | Adding a new field to handover documents — score 3 if it materially improves cross-session continuity, score 2 if cosmetic |

**O2 — Scope test:**

- `orchestrator-rethink`: "design route_cache memory representation" → V_CONTEXT_FABRIC=3 (cache is memory-adjacent)
- `embeddings-strategy`: "measure retrieval quality baseline" → V_CONTEXT_FABRIC=5 (foundational)
- `arc-grooming`: "migrate tags:[arc:*] → arc_id:" → V_CONTEXT_FABRIC=1 (touches task storage but not memory layer)
- `dispatch-safety`: "store dispatch decisions in episodic memory" → V_CONTEXT_FABRIC=4

Scores meaningfully across arcs, with variance. **Global confirmed.**

**O3 — Overlap test (analytical, not dialogued):**

- With D2 Reliability: when Context Fabric becomes more reliable, D2 also benefits. But D2 covers reliability of all subsystems; this driver isolates Context Fabric specifically. A task can score V_CONTEXT_FABRIC=5 (foundational memory work) and D2=3 (some reliability gain but not load-bearing).
- With V_PROMPT_QUALITY: low overlap. Memory is a substrate; prompts are an interface to LLMs. Some intersection (prompts can be cached in memory, retrieved via `fw recall`) but the driver categories are distinct.
- With V_COMPONENT_FABRIC: very low — different subsystems entirely.

Not a shadow dimension. Real driver.

**O4 — 0–5 scoring rubric (light pass):**

| Level | Definition |
|---|---|
| 0 | No Context Fabric work — pure code in other subsystems |
| 1 | Incidental touch — calls a Context Fabric API but doesn't improve it (e.g. uses `fw recall` for diagnostics) |
| 2 | Minor improvement — bug fix in handover, small reliability fix in `fw recall`, doc improvement |
| 3 | Meaningful improvement — new memory feature, performance optimization, new audit check for Context Fabric correctness |
| 4 | Material improvement — new memory layer addition, retrieval-quality baseline measurement, structural Context Fabric enhancement |
| 5 | Foundational change — new memory architecture, embedder replacement with measured quality improvement, new memory primitive |

### 3.3 V_COMPONENT_FABRIC

**R1 — Differentiation:**

> "Discriminates work that improves the quality, reliability, or speed of the Component Fabric (dependency mapping via `fw fabric deps`, blast-radius computation via `fw fabric blast-radius`, drift detection via `fw fabric drift`) from work that touches other subsystems."

Component Fabric is load-bearing for BVP cost-composite computation (the `0.6 × blast_radius` term in the cost formula per HANDOFF-value-prioritisation D5 / A6) and for audit checks. Discriminating "is this work on the topology layer?" is meaningful.

**R2 — Weight:**

Proposed weight: **6**. Between D2 (7) and D3 (5).

Rationale: Component Fabric is one specific subsystem, not the whole reliability story — so below D2. But it's structural and load-bearing for many downstream features (BVP cost composite, blast-radius decisions, audit drift checks) — so above D3 Usability. Weight 6 sits in the "important infrastructure, but not as critical as general reliability" tier.

**[CORRECTION — agent during analysis]** Initially considered weight 7 (same as V_CONTEXT_FABRIC and D2). Rejected after walking through the actual code paths: Component Fabric is consulted at cost-estimation time and at audit time, but Context Fabric is consulted at every cross-session event. Context Fabric is more load-bearing. Asymmetric weights (V_CONTEXT_FABRIC=7, V_COMPONENT_FABRIC=6) better reflect the asymmetric dependency.

**O1 — Edge cases:**

| Level | Example task |
|---|---|
| 5 | Restructuring dependency representation (e.g. flat → graph topology), or implementing accurate blast-radius where it was previously absent |
| 0 | Work entirely outside Component Fabric (prompt work, memory work, arc work) |
| Borderline 2/3 | Adding a new audit check that depends on `fw fabric blast-radius` — score 2 if it just uses, score 3 if it improves accuracy in the consuming code |

**O2 — Scope test:**

- `orchestrator-rethink`: "compute routing-decision blast-radius" → V_COMPONENT_FABRIC=3
- `embeddings-strategy`: "no Component Fabric touch" → V_COMPONENT_FABRIC=0
- `arc-grooming`: "anchor-task existence audit check" → V_COMPONENT_FABRIC=2 (touches dependency-style logic)
- `dispatch-safety`: "compute worker-error blast-radius" → V_COMPONENT_FABRIC=4

Variance across arcs. **Global confirmed.**

**O3 — Overlap test (analytical, not dialogued):**

- With D2 Reliability: Component Fabric reliability is a subset of D2.
- With V_CONTEXT_FABRIC: very low — different subsystems entirely (memory vs topology).
- With V_PROMPT_QUALITY: near-zero overlap.

Not a shadow dimension. Real driver.

**O4 — 0–5 scoring rubric (light pass):**

| Level | Definition |
|---|---|
| 0 | No Component Fabric work |
| 1 | Incidental touch — runs `fw fabric` for diagnostic purposes |
| 2 | Minor improvement — bug fix in dependency detection, small speed improvement |
| 3 | Meaningful improvement — new fabric check, accuracy improvement, drift-detection enhancement |
| 4 | Material improvement — major restructuring of dependency representation, comprehensive blast-radius accuracy work |
| 5 | Foundational change — new topology primitive, fundamentally improved drift detection, structural Component Fabric overhaul |

## 4. Decisions made

### Cross-cutting (apply to all three drivers)

**[DECISION D-1]** All three are global drivers, not arc-scoped. *Decided by:* jointly. *Rationale:* each applies to work across multiple arcs (verified by O2 scope test on each). *Reversibility:* cheap — could be converted to arc-scoped via re-issuance if any turn out to be project-narrow.

**[DECISION D-2]** Combined "quality / reliability / speed" framing per fabric, not split. *Decided by:* agent (with rationale). *Rationale:* split would correlate strongly and burn slots; combined captures the meaningful discrimination (fabric work vs non-fabric work). *Reversibility:* costly — splitting later requires re-scoring all existing scores against new dimensions.

**[DECISION D-3]** All three add at first init (or as soon as `fw bvp driver --add` exists), in the order V_PROMPT_QUALITY → V_CONTEXT_FABRIC → V_COMPONENT_FABRIC. *Decided by:* agent (with rationale). *Rationale:* alphabetical/logical ordering for the weight-history audit trail; matches the order in which they were proposed. *Reversibility:* cheap (order doesn't affect functionality, only the audit log presentation).

**[DECISION D-4]** Single bundled recompute after all three drivers land, not three separate recomputes. *Decided by:* jointly (per HANDOFF-value-prioritisation D5 + auto-vs-prompt asymmetry). *Rationale:* global recompute is expensive; bundling three driver additions before triggering recompute saves two redundant project-wide rescores. *Reversibility:* n/a — single-event decision.

### Per-driver

| Driver | Weight | Decided-by | Rejected alternative | Reversibility |
|---|---|---|---|---|
| V_PROMPT_QUALITY | 7 | agent (analytical) | Weight 8 (rejected — would imply > D2 Reliability) | cheap |
| V_CONTEXT_FABRIC | 7 | agent (analytical) | Split into 3 sub-drivers (rejected — correlation + slot burn) | costly (weight cheap; combined framing costly to undo) |
| V_COMPONENT_FABRIC | 6 | agent (analytical) | Weight 7 (rejected — Context Fabric is more load-bearing; asymmetry reflects asymmetric dependency) | cheap |

## 5. Final driver specs

### 5.1 V_PROMPT_QUALITY

```yaml
V_PROMPT_QUALITY:
  scope: global
  weight: 7
  rationale: "Discriminates work that improves the quality of LLM prompts (templates, instructions, rubrics, prompt-handler design) from work that improves other aspects of the system. Core to AEF's value proposition as an agentic framework."
  scoring_levels:
    0: "No prompt-related work — pure infrastructure, refactor, or unrelated feature"
    1: "Touches a prompt incidentally (changes a string that happens to be a prompt) but no quality improvement intent"
    2: "Minor prompt improvement — clarification of wording, fixing a typo in an instruction, small structural cleanup"
    3: "Meaningful prompt improvement — adds a worked example, refines an instruction, improves a rubric"
    4: "Material prompt improvement — new prompt-handler design, restructured instruction patterns, multi-section refinement"
    5: "Foundational prompt-quality work — new prompt-creation system, framework-level prompt-template patterns, prompt-bundle that becomes pattern for other prompts"
```

### 5.2 V_CONTEXT_FABRIC

```yaml
V_CONTEXT_FABRIC:
  scope: global
  weight: 7
  rationale: "Discriminates work that improves the quality, reliability, or speed of the Context Fabric (working/project/episodic memory, semantic search via fw recall) from work that touches other subsystems. Load-bearing for cross-session continuity."
  scoring_levels:
    0: "No Context Fabric work — pure code in other subsystems"
    1: "Incidental touch — calls a Context Fabric API but doesn't improve it (e.g. uses fw recall for diagnostics)"
    2: "Minor improvement — bug fix in handover, small reliability fix in fw recall, doc improvement"
    3: "Meaningful improvement — new memory feature, performance optimization, new audit check for Context Fabric correctness"
    4: "Material improvement — new memory layer addition, retrieval-quality baseline measurement, structural Context Fabric enhancement"
    5: "Foundational change — new memory architecture, embedder replacement with measured quality improvement, new memory primitive"
```

### 5.3 V_COMPONENT_FABRIC

```yaml
V_COMPONENT_FABRIC:
  scope: global
  weight: 6
  rationale: "Discriminates work that improves the quality, reliability, or speed of the Component Fabric (dependency mapping via fw fabric deps, blast-radius computation via fw fabric blast-radius, drift detection via fw fabric drift) from work that touches other subsystems. Load-bearing for BVP cost composite and audit checks."
  scoring_levels:
    0: "No Component Fabric work"
    1: "Incidental touch — runs fw fabric for diagnostic purposes"
    2: "Minor improvement — bug fix in dependency detection, small speed improvement"
    3: "Meaningful improvement — new fabric check, accuracy improvement, drift-detection enhancement"
    4: "Material improvement — major restructuring of dependency representation, comprehensive blast-radius accuracy work"
    5: "Foundational change — new topology primitive, fundamentally improved drift detection, structural Component Fabric overhaul"
```

## 6. Drill depth achieved (per driver)

| Step | V_PROMPT_QUALITY | V_CONTEXT_FABRIC | V_COMPONENT_FABRIC |
|---|---|---|---|
| R1 differentiation | ✓ | ✓ | ✓ |
| R2 weight | ✓ | ✓ | ✓ |
| O1 edge cases | ✓ | ✓ | ✓ |
| O2 scope test | ✓ (global) | ✓ (global) | ✓ (global) |
| O3 overlap test | analytical, not dialogued | analytical, not dialogued | analytical, not dialogued |
| O4 scoring rubric | light pass | light pass | light pass |

**Session-level note on drill depth:** This was a batch one-shot session — the human provided three driver concepts in a single message without interactive sharpening. Per the discipline (`policy/prompts/bvp-references/sharpening-script.md` "When to stop drilling"), the agent ships at the depth confirmable from the one-shot input plus analytical reasoning. **All three drivers ship at minimum-viable-plus-light depth.** Borderline cases will surface in first-use; rubric refinement expected after the drivers see ~30 days of operation. Deeper drilling available on request — particularly the borderline rules between scoring levels 2/3 and 3/4 across all three.

## 7. Consequences

**Drivers added (global):** 3 — V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC
**Free-driver pool after additions:** **5 of 5 occupied** (was 2/5 with F-RECALL + F-ORCH at filing — corrigendum reconciliation). At cap. Future driver additions will require add-one-drop-one discipline per `policy/value-drivers.yaml` header rule.
**BVP recompute scope:** global
**Tasks affected:** all tasks with confirmed or proposed `bvp_scores:` — count depends on project state at implementation time
**Arcs affected:** all arcs with confirmed `bvp_scores:` — currently in-progress arcs would be re-scored once they have arc-level scores
**Recompute triggered:** **pending implementation.** Cannot run until `fw bvp recompute` verb exists (HANDOFF-vp v2 / T-NEW-X — per INGESTION-bvp-driver-prompt-bundle-2026-06-06 §5.3). *Corrigendum note:* `fw bvp recompute` verb existence not yet confirmed at filing-time; framework agent verifies in §9.1 pre-action check before invoking.

**Ranking changes expected:**
- Tasks that touch prompts (e.g. `bvp-driver-session.md` improvements) will rank higher
- Tasks in `embeddings-strategy` arc will mostly score high on V_CONTEXT_FABRIC, lifting that arc's task BVPs
- Tasks involving `fw fabric` improvements will rank higher on V_COMPONENT_FABRIC
- Tasks that touch none of the three new dimensions will see their `BVP_norm` decrease slightly (the denominator grows when new drivers are added, while their numerator stays the same)

## 8. CLI commands to execute (when implementation is ready)

Sequenced; the framework agent runs these in order after the BVP system is initialised:

```bash
# Pre-check: confirm BVP is initialised
test -f policy/value-drivers.yaml || (echo "BVP not initialised; run fw bvp init first" && exit 1)

# Pre-check: confirm free-driver pool has room (need 3 slots)
# (framework verifies via fw bvp driver --list and counts free entries; aborts if <3 slots)

# Add the three drivers
fw bvp driver --add "V_PROMPT_QUALITY" --weight 7 \
  --rationale "Discriminates LLM prompt-quality work from work on other aspects. Core to AEF's value as an agentic framework. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"

fw bvp driver --add "V_CONTEXT_FABRIC" --weight 7 \
  --rationale "Discriminates memory-layer work (Context Fabric: working/project/episodic memory, semantic search) from work elsewhere. Load-bearing for cross-session continuity. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"

fw bvp driver --add "V_COMPONENT_FABRIC" --weight 6 \
  --rationale "Discriminates topology-layer work (Component Fabric: dependency mapping, blast-radius, drift detection) from work elsewhere. Load-bearing for BVP cost composite and audit. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"

# Trigger bundled global recompute (one event, not three)
fw bvp recompute --scope global \
  --trigger "batch-driver-add" \
  --rationale "Three global drivers added: V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC. Source: docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md"
```

Each `fw bvp driver --add` writes a weight-history entry to `.context/bvp-weight-history.yaml`. The recompute writes a single entry to `.context/bvp-recompute-log.jsonl`.

## 9. Pickup prompt for the framework agent

This section is the **direct instruction** for the framework agent. Pre-action checks first; then execution; then surface.

### 9.1 Pre-action checks

Before executing anything, verify:

- [ ] **T-2305 has reached `fw inception decide go` via Watchtower.** Operator-only Sovereign gate. Filing-time recommendation: GO. If not yet decided, halt and surface: "T-2305 awaiting operator decide-go; pickup prompt deferred."
- [ ] **HANDOFF-arc-grooming-2026-05-15 has reached §5: GO AND its first deliverable has shipped.** Same precondition as the bundle ingestion (`INGESTION-bvp-driver-prompt-bundle-2026-06-06.md` §2). Without arc-grooming, BVP cannot run.
- [ ] **HANDOFF-value-prioritisation-2026-05-15 v2 has been filed AND its inception has reached decide-go.** This is the gate that makes `fw bvp driver --add`, `fw bvp recompute`, and `fw bvp init` real verbs. **Live-state delta (corrigendum at filing):** `fw bvp driver --add` is already live in the current CLI. `fw bvp init` is also live. `fw bvp recompute` status — verify before invoking; if absent, halt at the recompute step (drivers can still land; recompute deferred).
- [ ] **`fw bvp init` has been run on this project.** Required precondition for `fw bvp driver --add`. **Live-state delta:** at filing, `policy/value-drivers.yaml` v3 is shipped with F-RECALL + F-ORCH in the free pool — BVP is already initialised. Skip the `fw bvp init` step.
- [ ] **Free-driver pool has ≥3 slots available.** Check via `fw bvp driver --list`; count entries with `protected: false`. **Live-state delta at filing:** 2/5 free slots used (F-RECALL, F-ORCH); 3 slots open — exact fit. If consumed since filing (other driver work in-flight), halt and surface — adding 3 requires swaps the human must approve via `fw bvp driver --remove` first.
- [ ] **None of V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC already exist in `policy/value-drivers.yaml`.** If any are present, halt and surface: re-running this artefact's pickup is a no-op for already-present drivers, but the human should confirm before partial-add proceeds.

If any check fails: surface a one-line summary to the human and **do not proceed** with any `fw bvp driver --add` invocation.

### 9.2 Execution

If all pre-action checks pass, execute the CLI commands in §8 in the listed order. Three driver additions, followed by one bundled recompute.

**During execution:**
- Each `fw bvp driver --add` should land cleanly. If any fails, halt; do not continue with the remaining additions. Surface the failure with the driver name and reason.
- After all three additions succeed, the framework should **prompt the human** for the global recompute (per HANDOFF-value-prioritisation D5 — prompt-confirm on global): "Adding 3 global drivers re-scores N tasks, M arcs. Run now?" Only on human Y does `fw bvp recompute --scope global` execute.
- If the human declines the recompute (N), the additions still land — but `.context/bvp-recompute-log.jsonl` should record a "pending recompute" entry so the next handover surfaces the un-rescored state.

### 9.3 Post-execution surface

After execution, surface to the human:

> "Three global free drivers landed: V_PROMPT_QUALITY (w=7), V_CONTEXT_FABRIC (w=7), V_COMPONENT_FABRIC (w=6). Free-driver pool now at 5/5 (at cap; future adds require add-one-drop-one). Global BVP recompute [completed | pending human confirmation | declined]. Recompute audit entry at `.context/bvp-recompute-log.jsonl#<entry-id>` [if completed]. Existing arcs may benefit from re-running `fw bvp driver suggest` to evaluate whether arc-scoped drivers in light of new globals."

### 9.4 What this pickup prompt does NOT do

- **Does not override scoring rubric customisation.** The 0–5 scoring rubrics in §5 are project defaults. Once a driver is in use, the human can edit `policy/value-drivers.yaml` directly to refine level definitions (e.g. after the "borderline notes after first use" refinement period). The pickup prompt sets the initial state; ongoing refinement is normal human-edited policy work.
- **Does not pre-score existing tasks.** That's the bvp-estimator worker's job (per HANDOFF-value-prioritisation D4). After recompute, the estimator will work through existing tasks proposing scores on the three new drivers; humans confirm via `fw bvp confirm` per-task.
- **Does not touch arc-scoped drivers.** Adding global drivers may make some arcs want to revisit their arc-scoped driver decisions (e.g. an arc that previously declined arc-scoped drivers via `--none --justification` because globals "covered the territory" may now find that the new globals shift the picture). Surface this as a recommendation in §9.3 — humans can opt to re-run `fw bvp driver suggest` per arc.
- **Does not auto-promote tasks.** Per HANDOFF-value-prioritisation D8, auto-promote stays off by default. New drivers may shift quadrant placements; human reviews via Watchtower `/bvp` tab.

## 10. Follow-ups and open questions

- **First-use refinement.** All three rubrics are light-pass. Expect the first 30 days of operation to surface borderline cases. Plan a follow-up session to refine the level definitions (particularly 2/3 and 3/4 boundaries) after observing real scoring patterns.
- **V_PROMPT_QUALITY borderline rate-limiting.** The rate-limiting case (mentioned in O1 for V_SECURITY_POSTURE example in the worked dialogue in `sharpening-script.md`) is also potentially borderline here — a task that improves both a prompt's clarity AND the system's security posture might score significantly on multiple drivers. Watch for unintended high-BVP outliers.
- **V_CONTEXT_FABRIC and V_COMPONENT_FABRIC split candidates.** Each was kept as one combined driver (D-2). If first-use shows that "fabric quality" and "fabric speed" diverge significantly in practice (e.g. tasks consistently score high on speed but low on quality, suggesting two real dimensions hidden in one), revisit and consider splitting. This would require the discipline of "is the dimension genuine?" applied to the split — manufacturing split for theoretical elegance is the failure mode.
- **V_AGENT_BEHAVIOUR / V_AGENT_DISCIPLINE as a future fourth global.** Considered but not pursued in this session (see §2). If the existing 3+4=7 driver set starts producing inadequate discrimination on tasks that improve agent behaviour specifically (e.g. §ACD enforcement work), revisit. The free pool has room for 2 more drivers; this is a candidate. **Live-state delta:** at filing, free pool will reach 5/5 after this batch lands (F-RECALL, F-ORCH, V_PROMPT_QUALITY, V_CONTEXT_FABRIC, V_COMPONENT_FABRIC) — at cap. V_AGENT_BEHAVIOUR consideration requires add-one-drop-one.
- **Weight recalibration.** V_PROMPT_QUALITY at 7 (level with D2 Reliability) is defensible but not the only defensible choice. After ~60 days of operation, review whether V_PROMPT_QUALITY-heavy tasks are systematically over- or under-ranked relative to project intuition. Adjust weight via `fw bvp weight --set V_PROMPT_QUALITY=N --rationale "..."` if needed.

---

## Dialogue Log

### 2026-06-10 — Artefact filed (T-2305 origination)

**Operator:** *pasted complete BVP driver batch artefact with three driver designs (V_PROMPT_QUALITY w=7, V_CONTEXT_FABRIC w=7, V_COMPONENT_FABRIC w=6), full R1/R2/O1/O2/O3/O4 sharpening per driver, decisions D-1..D-4, pickup prompt with pre-action checks + execution + surface*

**Operator instruction:** *"creat einception and add as reserach document"*

**Agent response — live-state check:**
- Verified `policy/value-drivers.yaml` v3 is shipped with D1-D4 protected + F-RECALL + F-ORCH free (2/5 slots used).
- Verified `fw bvp driver` help confirms `--init`, `--add`, `--remove` all available.
- `fw bvp recompute` verb status not confirmed in this session.

**Reconciliation:** The artefact's "pending implementation" framing (HANDOFF-vp v2 not yet filed) is **stale** — most of the BVP infrastructure shipped between the artefact's authoring and filing time. The three driver designs themselves stand unchanged; the deployment-readiness language shifts from "forward-looking pending v2" to "ready for operator decide-go on T-2305 with one open verb question (recompute)."

**Agent action:**
1. Filed T-2305 as `workflow_type: inception` with `Recommendation: GO` and rationale citing the design's evidence-walk + live-state fit (3 free slots, 3 drivers — exact match).
2. Saved this artefact verbatim with corrigendum preamble + per-section live-state delta notes (§7 pool count, §9 pre-action checks). Original analysis preserved intact per CLAUDE.md §Inception Discipline #6/#7.
3. Surfaced via `fw task review T-2305` → Watchtower for Sovereign decide-go.

**Outcome:** Inception filed, research artefact persisted, awaiting operator decide-go. Pickup prompt at §9 will fire automatically (per its own pre-action checks) once T-2305 decision lands.

---

*End of artefact. One-line summary on delivery: three global free drivers (V_PROMPT_QUALITY w=7, V_CONTEXT_FABRIC w=7, V_COMPONENT_FABRIC w=6) designed and ready for implementation; pickup prompt at §9 instructs framework agent on pre-action checks, execution sequence, and post-execution surfacing; recompute status pending implementation (depends on HANDOFF-value-prioritisation v2).*
