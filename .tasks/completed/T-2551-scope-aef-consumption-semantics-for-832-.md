---
id: T-2551
name: "scope AEF consumption semantics for 832 typed BPMN events (error/timer/message)"
description: >
  Inception: scope AEF consumption semantics for 832 typed BPMN events (error/timer/message)

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [bin/fw, tests/fixtures/bpmn/typed-event-sample.bpmn, tools/bpmn_to_tasks.py, tools/corpus_lint.py, tools/corpus_spec.py]
related_tasks: []
created: 2026-07-19T18:30:00Z
last_update: 2026-07-22T19:56:38Z
date_finished: 2026-07-22T19:56:38Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-07-19T18:31:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-07-19T18:45:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-07-20T19:00:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 8
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2551: scope AEF consumption semantics for 832 typed BPMN events (error/timer/message)

## Problem Statement

832 shipped **typed BPMN events** (their T-204 Slice 1, rail offset 79): error/timer/message
encoded as `<aef:eventDef kind= binding=>` on a neutral `intermediateCatchEvent` (no native
`bpmn:*EventDefinition`; binding scalars `errorStatus`/`timerSpec`/`busTopic`). Their producer
side is done and byte-stable.

AEF's compile path (`tools/bpmn_to_tasks.py`) **transits these events cleanly today** —
`intermediateCatchEvent` is not in `TASK_TAGS {userTask,serviceTask,scriptTask}`, the parse is
namespace-agnostic by local-name, and `_nearest_task_preds` (line 279) explicitly transits
non-task nodes — so a typed-event diagram parses with no crash and the event contributes to
`related_tasks` edges (T-2532). **But the `<aef:eventDef>` annotation is silently dropped** — no
skeleton, no trigger annotation. That silent-drop is a reliability gap on the AEF side (the mirror
of the loud-drop 832 deliberately avoided in `KNOWN_AEF_KEYS`).

**The question:** should the AEF compile/promote path *consume* typed-event trigger annotations,
and if so, what does each kind (error/timer/message) map to in an AEF task? **Now** because 832
just shipped the producer side and asked directly (offset 79), and the encoding is stable enough
to build against.

## Assumptions

<!-- Register with: fw assumption add "Statement" --task T-2551 -->
- **A1:** AEF's task/orchestration model has (or can cheaply gain) a *live consumer* for a
  per-task trigger annotation — otherwise consuming typed events is write-only frontmatter noise
  nothing reads (violates D2/D3). **This is the load-bearing assumption; if false → NO-GO.**
- **A2:** The three kinds map to *existing* AEF concepts without new subsystem surface —
  error→`status: issues`/healing, timer→`horizon`/cron, message→bus/inbox/pause dispatch.
- **A3:** Preserving the diagram's control-flow *intent* (not just its task nodes) has value to
  the AEF task graph beyond the already-emitted `related_tasks` edges.

## Open Questions

- **IW-1: Does AEF's execution/orchestration model have any consumer for a per-task trigger
  annotation today, or would it be write-only metadata?**
  confidence: 3
  disposition: answered
  rationale: **Spike-1 complete (verified).** The resolver dispatch envelope reads exactly 6
  frontmatter fields — `id/name/workflow_type/owner/horizon/status` (`lib/resolver.py:1056-1061`);
  no dispatch/bus/pause/pending/spawn path reads any trigger/event/`on_error`/`eventDef` field
  (grep-verified empty). Only **timer→horizon** could feed a live consumer (resolver eligibility
  line 1176 + `_rank`), and horizon is ALREADY derived from flow-order (T-2532) → refinement, not a
  net-new consumer. **error** and **message** have NO consumer → consumption = write-only
  frontmatter (D2/D3 violation). Independent of the 832 fixture (that gates only the WARN's
  byte-exactness, shipped in T-2552).
- **IW-2: What is the honest per-kind mapping (error→?, timer→?, message→?), and does any map
  cleanly onto an existing AEF concept without inventing new subsystem surface?**
  confidence: 3
  disposition: answered
  rationale: error→(none: healing reads live `status: issues`, not a compile-time field);
  message→(none: dispatch keyed on runtime `inbox.queued`, no per-task field); timer→`horizon` is
  the only existing target and it OVERLAPS T-2532's flow-order derivation. No kind maps to a
  net-new value without new subsystem surface.
- **IW-3: Is the right first step "surface the drop (compile WARN)" only — deferring semantics
  indefinitely — or is there a bounded consumption worth building now?**
  confidence: 3
  disposition: answered
  rationale: WARN-only is correct — shipped in T-2552 (landed master). It closes the reliability gap
  (no silent loss) without inventing a consumer. No bounded consumption is worth building now given
  IW-1/IW-2.
- **IW-4: Does consumption belong in the compile path (`bpmn_to_tasks.py` → skeleton frontmatter),
  the promote path (`bpmn_promote.py` → materialization), or neither?**
  confidence: 3
  disposition: dissolved
  rationale: moot under the NO-GO recommendation — with no consumer, there is no consumption to
  place. Revisit only if AEF grows a trigger-consuming execution engine (then compile-path
  frontmatter is the natural first home).

## Exploration Plan

- **Spike 1 (read-only, ~30m):** map AEF's trigger-adjacent concepts — healing (`status: issues`),
  cron/`horizon`, bus/inbox/pause — and determine whether any is a *live consumer* for a
  compile-time annotation. Grounds IW-1. **Load-bearing: if no consumer exists, the inception is
  NO-GO regardless of encoding.**
- **Spike 2 (on 832 fixture arrival):** byte-exact cross-validate 832's real `aef:eventDef`
  encoding parses clean; confirm the current silent-drop empirically; prototype a compile WARN.
  Grounds IW-3/IW-4. (Overlaps the separate visible-drop build task committed on offset 80 — that
  work proceeds independently of this go/no-go.)
- **Spike 3:** candidate-mapping matrix, per kind, with an explicit "does a live consumer exist"
  column. Grounds IW-2.

## Technical Constraints

- Encoding is 832's `aef:`-extension form (`<aef:eventDef kind= binding=>`), NOT native
  `bpmn:*EventDefinition` — the compiler's namespace-agnostic local-name matching already handles
  it, but any consumer must read the extension, not a standard BPMN event tag.
- Must not regress the T-2532 `related_tasks` flow-walk (events are transited today; any consumer
  is additive, not a replacement).
- Portability (D4): mapping must not hard-code 832-specific binding vocabulary into AEF's core if
  it would lock the task model to one producer's schema.

## Scope Fence

**IN:** the *semantics* decision — should AEF consume typed events, and the honest mapping per
kind; the go/no-go on building consumption.

**OUT:**
- Encoding cross-validation + the compile-time **visible-drop WARN** — separate test/build task,
  committed to 832 on rail offset 80; does **not** wait on this inception.
- 832's producer/editor side (their T-204).
- Any new orchestration/execution engine — if a mapping needs one, that is a NO-GO signal, not
  in-scope build.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- At least one event kind (error/timer/message) maps onto an **existing** AEF consumer (not new
  subsystem surface) via a bounded, testable compile/promote change, AND
- Preserving that trigger intent has demonstrated value beyond the existing `related_tasks` edges.

**NO-GO if:**
- No existing AEF consumer reads a per-task trigger annotation → consumption would be write-only
  frontmatter noise (the visible-drop WARN alone is the right answer), OR
- Each honest mapping requires a new orchestration/execution engine whose cost exceeds the value.

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** NO-GO (on building typed-event *consumption*) — with a revisit condition.

**Rationale:**

Spike-1 completed and answered the load-bearing question (IW-1, confidence 3): **AEF has no
consumer for a per-task trigger annotation.** The resolver dispatch envelope reads exactly six
frontmatter fields (`id/name/workflow_type/owner/horizon/status`, `lib/resolver.py:1056-1061`), and
no dispatch/bus/pause/pending/spawn path reads any trigger/event field. So consuming error/message
annotations would write frontmatter that nothing reads — the D2/D3 anti-pattern the framework
exists to prevent. The only kind with a live target (timer→`horizon`) overlaps the existing
T-2532 flow-order derivation, so even it adds no net-new value. Meanwhile the actual *reliability*
need — never silently drop the annotation — is already met by the shipped WARN (T-2552). There is
no bounded consumption worth building. This is a confident NO-GO on evidence, **not** a DEFER: the
decision does not depend on 832's fixture (that gates only the WARN's byte-exactness), and the
sovereignty question ("should the task model carry producer-trigger vocab?") is answerable now —
the answer is "not until something reads it."

**Revisit condition:** flip to GO only if AEF grows a trigger-consuming execution engine (a live
consumer for compile-time triggers). At that point timer→horizon-refinement is the first candidate,
and consumption belongs in the compile path (`bpmn_to_tasks.py` → skeleton frontmatter).

**Evidence:**

- **IW-1 (verified):** `lib/resolver.py:1056-1061` — dispatch reads only 6 fields; grep of
  resolver/outcome/pause/pending/spawn for any trigger/event/`on_error`/`eventDef` consumer returns
  empty. Only `horizon` (of those 6) is trigger-adjacent, and it's already flow-derived (T-2532).
- **error → no target:** healing triggers on *live* `status: issues`, not a compile-time field
  (setting `status: issues` at birth is semantically wrong). **message → no target:** dispatch is
  keyed on runtime `inbox.queued`, not a per-task annotation.
- **Reliability already covered:** the silent-drop→WARN (T-2552, landed master) preserves the
  no-silent-loss guarantee without inventing a consumer. Research artifact:
  `docs/reports/T-2551-typed-event-consumption-semantics.md`.
- **Independent of the fixture:** 832's inbound fixture gates only the WARN's byte-exact
  cross-validation (a separate confirm on already-shipped code), not this consumption go/no-go.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: NO-GO

**Rationale**: Spike-1 completed and answered the load-bearing question (IW-1, confidence 3): **AEF has no
consumer for a per-task trigger annotation.** The resolver dispatch envelope reads exactly six
frontmatter fields (`id/name/workflow_type/owner/horizon/status`, `lib/resolver.py:1056-1061`), and
no dispatch/bus/pause/pending/spawn path reads any trigger/event field. So consuming error/message
annotations would write frontmatter that nothing reads — the D2/D3 anti-pattern the framework
exists to prevent. The only kind with a live target (timer→`horizon`) overlaps the existing
T-2532 flow-order derivation, so even it adds no net-new value. Meanwhile the actual *reliability*
need — never silently drop the annotation — is already met by the shipped WARN (T-2552). There is
no bounded consumption worth building. This is a confident NO-GO on evidence, **not** a DEFER: the
decision does not depend on 832's fixture (that gates only the WARN's byte-exactness), and the
sovereignty question ("should the task model carry producer-trigger vocab?") is answerable now —
the answer is "not until something reads it."

**Date**: 2026-07-22T19:56:38Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-19T18:31:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-07-22T19:56:38Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Spike-1 completed and answered the load-bearing question (IW-1, confidence 3): **AEF has no
consumer for a per-task trigger annotation.** The resolver dispatch envelope reads exactly six
frontmatter fields (`id/name/workflow_type/owner/horizon/status`, `lib/resolver.py:1056-1061`), and
no dispatch/bus/pause/pending/spawn path reads any trigger/event field. So consuming error/message
annotations would write frontmatter that nothing reads — the D2/D3 anti-pattern the framework
exists to prevent. The only kind with a live target (timer→`horizon`) overlaps the existing
T-2532 flow-order derivation, so even it adds no net-new value. Meanwhile the actual *reliability*
need — never silently drop the annotation — is already met by the shipped WARN (T-2552). There is
no bounded consumption worth building. This is a confident NO-GO on evidence, **not** a DEFER: the
decision does not depend on 832's fixture (that gates only the WARN's byte-exactness), and the
sovereignty question ("should the task model carry producer-trigger vocab?") is answerable now —
the answer is "not until something reads it."

## Reviewer Verdict (v1.5)

- **Scan ID:** R-400e28d6
- **Timestamp:** 2026-07-22T19:56:39Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-e5c81c14
- **Timestamp:** 2026-07-22T19:56:39Z
- **Overall:** CONTRADICTED
- **Claims:** 5

| Claim | Type | Status |
|-------|------|--------|
| `lib/resolver.py:1056-1061` | file | ✗ fail — file not found at PROJECT_ROOT |
| `inbox.queued` | module | ✓ pass |
| `docs/reports/T-2551-typed-event-consumption-semantics.md` | file | ✓ pass |
| `T-2532` | task | ✓ pass |
| `T-2552` | task | ✓ pass |

### 2026-07-22T19:56:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO
