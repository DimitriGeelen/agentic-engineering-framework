# T-2572 — Drafting-instincts diff: 832's dispatch-loop vs AEF's D4

**Companion doc for the operator review pass** (D4 at `/review/T-2563`). Two agents independently drew "the dispatch loop" for the arc-014 corpus — 832's pair-draft #2 (`tests/fixtures/aef-bpmn/dispatch-loop.bpmn`, rail offsets 99+101, sha-pinned) and AEF's D4 (`.context/designer/projects/aef-dispatch-loop/v2.bpmn`, T-2563). The drafts barely overlap — and the *disagreement is the finding*: it exposes each agent's default modeling instincts. Every 832-side claim below traces to diagram content or a cited rail offset; intent is not inferred beyond that.

## The two drafts at a glance

| | 832 pair-draft #2 | AEF D4 (T-2563) |
|---|---|---|
| Nodes / flows / lanes | 17 / 20 / **3** | 9 / 9 / **2** |
| Lanes | Human·Sovereignty, **Framework·Authority**, Agent·Initiative | Agent·Initiative, Human·Sovereignty |
| Subject | Sub-Agent Dispatch **Protocol** (scope → fan-out ≤5 → collect → synthesize → loop) | Resolver dispatch **substrate** (`fw resolver dispatch` → `termlink dispatch` → bus result → outcome backprop) |
| Concurrency | Explicit `agt_5_fan`/`agt_10_join` parallel fork/join, 3 named workers + sequential alternative | None — one dispatch envelope per pass; concurrency = run the process N times |
| Human role | Recurring loop gate: `hum_15_checkin` "Review & continue?" every cycle; end event `hum_16_done` lives in the **human** lane | Exception handler only: `hum_3_pause` fires solely on the `agt_gw_paused` branch (`fw pause resolve`) |
| Termination | Human decides ("Session continues elsewhere") | Data closes (`agt_5_outcome` outcome row joined → `agt_6_done` "dispatch + outcome queryable") |
| Eventing | Pure control flow | Message event `agt_msg_result` ("worker result on bus") |

## Instinct 1 — altitude: policy vs mechanism

832 drew the **normative protocol**: what a well-behaved orchestrator does (`agt_2_scope` "1 task = 1 deliverable", fan-out "≤5", `agt_11_collect` "fw bus manifest"). It is CLAUDE.md's §Sub-Agent Dispatch Protocol rendered as BPMN. AEF drew the **descriptive mechanism**: what the shipped tooling actually executes, one envelope at a time, named by its real verbs (`fw resolver dispatch`, `fw termlink dispatch` w/ T-577 watchdog, `fw outcome evaluate`). Same title, different layer of the same system — the corpus is richer for holding both, but a reviewer comparing them one-to-one would wrongly conclude one is "incomplete."

## Instinct 2 — governance: reified as a lane vs delegated to hooks

832's most distinctive move: a **Framework·Authority lane with governance steps as first-class nodes** — `frw_3_headroom` ("Reserve context headroom ≥40K") and `frw_14_checkpoint` ("Commit checkpoint, P-009 cadence"). The invisible enforcement layer (hooks, budget gate) is drawn *into* the process. D4 has **no framework lane at all**: enforcement is left implicit because in the real system it lives in PreToolUse hooks and gates, not in the agent's control flow. Consequence already observed live: 832's lane carried `aef:laneMeta authority='authority'`, which AEF owner-derivation doesn't map — both frw nodes fell back to `owner: agent` skeletons under the T-2567 aggregated WARN (first live firing, T-2568 report §Bonus). Lane vocabulary is not decoration; it changes compiled ownership.

## Instinct 3 — human-in-the-loop vs human-on-exception

832 routes **every cycle** through a human check-in (`hum_15_checkin` back-edge to `agt_2_scope`) and ends the process in the human's lane. D4 involves the human **only when the worker raises** (`pause_requested` → `hum_3_pause`), then flows back through retry. Both match real framework behavior at their own altitude — the check-in mirrors §Commit Cadence and Check-In; the pause gate mirrors the dispatch-safety arc's pause/resolve chain — but they encode opposite defaults about where sovereignty sits in the *happy path*.

## Instinct 4 — termination

832: the loop is done when the **human says so**. D4: the loop is done when the **data closes** (outcome row joined to dispatch row, queryable). This is the same split as instinct 3 projected onto the end event, and it is the sharpest single-question contrast for the operator: *which termination instinct should the canonical corpus process carry?*

## What this means for the D4 review (`/review/T-2563`)

1. D4 is deliberately substrate-level; if the operator wants the protocol level too, 832's pair-draft #2 already covers it — the pair should be cross-referenced, not merged.
2. The open design question worth an operator steer: should AEF corpus diagrams adopt 832's Framework-lane convention (governance visible, but needs an owner-mapping story per T-2567) or D4's hook-delegation convention (diagrams stay agent-flow-only)? Currently the corpus contains both with no stated rule.
3. Both drafts survived compile with the fork/join, multi-back-edge, and authority-lane behavior pinned in tests (54/54; T-2568 report has the verbatim WARN set).
