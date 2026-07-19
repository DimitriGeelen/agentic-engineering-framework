---
id: T-2551
name: "scope AEF consumption semantics for 832 typed BPMN events (error/timer/message)"
description: >
  Inception: scope AEF consumption semantics for 832 typed BPMN events (error/timer/message)

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-07-19T18:30:00Z
last_update: 2026-07-19T18:31:15Z
date_finished:
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
  confidence: 2
  disposition: deferred
  rationale: Spike-1 done (docs/reports/T-2551-*.md) — only **timer→horizon** has a live consumer
  (resolver.py:1176 eligibility + `_rank`), and it overlaps T-2532's existing horizon derivation;
  **error** (healing reads live status, not compile-time) and **message** (dispatch keyed on
  runtime events) have NO compile-time consumer. Trends NO-GO; deferred pending Spike-3 matrix +
  832 fixture before ratifying.
- **IW-2: What is the honest per-kind mapping (error→?, timer→?, message→?), and does any map
  cleanly onto an existing AEF concept without inventing new subsystem surface?**
  confidence: 1
  disposition: deferred
  rationale: pending Spike-3 candidate-mapping matrix
- **IW-3: Is the right first step "surface the drop (compile WARN)" only — deferring semantics
  indefinitely — or is there a bounded consumption worth building now?**
  confidence: 1
  disposition: deferred
  rationale: the WARN is already committed as separate work (rail offset 80); this asks whether to
  go further
- **IW-4: Does consumption belong in the compile path (`bpmn_to_tasks.py` → skeleton frontmatter),
  the promote path (`bpmn_promote.py` → materialization), or neither?**
  confidence: 1
  disposition: deferred
  rationale: pending IW-1/IW-2 resolution

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
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** DEFER

**Rationale:**

Genuine evidence gap at filing: no candidate-mapping analysis done yet, and it depends on 832's forthcoming typed-event fixture (encoding cross-validation) plus a human go/no-go on whether AEF should consume typed-event annotations at all. Not a confidence hedge — the exploration (does AEF's execution model use triggers? what does each event kind map to?) has not been conducted. DEFER pending the research artifact + fixture.

**Evidence:**

- Spike-1 (read-only, `docs/reports/T-2551-typed-event-consumption-semantics.md`): only
  **timer→horizon** maps to a live AEF consumer (`lib/resolver.py:1176` eligibility + `_rank`
  ranking), and it overlaps T-2532's existing sequenceFlow→horizon derivation. **error** and
  **message** have no compile-time consumer (healing reads live `status: issues`; dispatch is keyed
  on runtime `inbox.queued`, not a per-task field). Trends NO-GO (consumption of error/message =
  write-only frontmatter noise).
- Current compile behavior grounded in `tools/bpmn_to_tasks.py:51,279`: typed-event diagram
  compiles clean (no crash) but `<aef:eventDef>` is silently dropped — the visible-drop compile
  WARN (committed separately, rail offset 80) preserves the no-silent-loss guarantee without
  inventing a consumer.
- **DEFER (not NO-GO yet)** because two genuine external gaps remain: (1) 832's typed-event fixture
  for byte-exact encoding cross-validation, (2) human go/no-go on whether the AEF task model should
  carry producer-trigger vocabulary at all (sovereignty call).

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-07-19T18:31:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
