# T-2619: Designer authority model — operationalise as live mirror

**Inception research artifact (C-001).** Created 2026-07-25 at the start of exploration; updated incrementally as the dialogue produces findings.

Arc: arc-014 (designer-corpus). Related: T-2618 (task-lifecycle v4), T-2617 (0.4.0 pull-at-tag intake), T-2616 (--from-tag tooling).

## Origin

Operator prompt (2026-07-25, verbatim intent): *critically review the workflows we made and evaluate the purpose and goals of the workflow designer — to be a supporting tool for agent and operator to build, develop, maintain, troubleshoot, iterate functionality and features; reflect and discuss.*

## Current state (grounded inventory)

- **Corpus:** 5 real AEF maps in `.context/designer/projects/`: aef-task-lifecycle (v4), aef-dispatch-loop (v3), aef-inception-flow (v4), aef-session-lifecycle (v3), aef-audit-cron (v3). Plus 3 scratch/verify projects.
- **Toolchain:** `fw corpus derive/generate/canon/diff/prove`, corpus lint (2-finding steady baseline), single stored representation (T-2608), uuid permanence, cross-map handoff jumps (T-2613), typed events, lane→owner semantics (O-1/O-3).
- **Editor:** 832's single-file bundle, pinned 0.4.0, served verbatim at /designer/app; pull-at-tag supply chain (T-247/D-335, T-2616/T-2617).
- **Generative seam:** BPMN promote — inception nodes → gated task creation (T-2531/T-2542/T-2543). Inception-only, barely used since shipping.

## Critical review — goals scored verb by verb

| Goal | Verdict | Evidence |
|------|---------|----------|
| Build | Partially served | Promote path exists (map → gated tasks) but inception-only, low usage |
| Develop/consult | Weak | Agents never read the maps; CLAUDE.md remains sole workflow authority; corpus is write-mostly |
| Maintain | **Most critical gap** | Maps document code, synced by hand. Corpus-internal drift defended (lint/prove/uuid); map-vs-reality divergence undetected → double maintenance |
| Troubleshoot | **Unserved** | No live state on maps. Designer = static render; Watchtower = live state; not joined. Behavioral fact: agent greps code/logs, never opens /designer when something breaks |
| Iterate | Heavy | Each map version is a full task + e2e ceremony (v3→v4 = a session); no draft mode |

**Plumbing:use ratio ~80:20.** Sessions went predominantly to supply-chain/tool plumbing (pin/sha/tag intake, round-trip determinism, parse strictness, seam negotiation). That work is genuinely strong engineering (T-2614 strict-parse catch, T-2608 single-representation, pull-at-tag) — but it is a delivery pipeline for a tool whose operational pull is still mostly hypothetical.

**What is genuinely right (keep):** uuid permanence, cross-map jumps, lane→owner governance-in-the-diagram (O-3 Human-authority veto), typed events, the 832 rail collaboration protocol. This is exactly the substrate an operational surface needs — the question is whether we now make it one.

## The keystone question

**Which direction does authority flow between map and reality?**

1. **Map-as-spec** — diagram authoritative; audit checks code/behavior conforms (e.g. task-status transitions in update-task.sh must match map edges or audit flags). Maintenance inverts: change map first.
2. **Map-as-live-mirror** — live state projected onto map uids (.tasks/active, focus.yaml, dispatches.jsonl → g[data-id] nodes via gallery API). The only option that serves *troubleshoot*; would make both agent and operator open the designer **during** work.
3. **Map-as-docs** — accept documentation; optimise read-value (link maps from gate refusals, review pages, CLAUDE.md); stop investing in heavier machinery.

Current implicit position: doing 3 while paying the infrastructure cost of 1+2.

**Agent recommendation (filed at creation):** GO — mirror-first (option 2) + selective spec-conformance (option 1 applied to task-lifecycle only, where transitions are already mechanically enforced and conformance is checkable). Rationale: option 2 is the only move that creates operational pull; option 1 everywhere would invert maintenance burden onto maps that have no single enforcement point; option 3 wastes the substrate already built.

## Constituent slices filed under arc-014

| Task | Type | Horizon | Goal served |
|------|------|---------|-------------|
| T-2619 (this) | inception | now | keystone authority decision |
| T-2620 | inception | next | Troubleshoot — live-state overlay seam (DEFER: depends on T-2619 + 832 seam consultation + spike) |
| T-2621 | build | next | Maintain — map-conformance audit leg (task-lifecycle edges vs update-task.sh transitions) |
| T-2622 | build | next | Develop/consult — fw corpus explain + corpus in ask/recall index |
| T-2623 | build | later | Iterate — draft mode / cheap iteration tier |
| T-2624 | build | later | Docs read-value — gate messages + review pages deep-link to map nodes |

## Dialogue Log

- **2026-07-25 — Operator:** asked for critical review of the workflows and evaluation of the designer's purpose (supporting tool for agent+operator: build, develop, maintain, troubleshoot, iterate). Asked to reflect and discuss.
- **2026-07-25 — Agent:** delivered the verb-by-verb review above; named the keystone authority question; recommended mirror-first + selective spec; offered 4 discussion directions (authority question / challenge scoring / overlay deep-dive / other).
- **2026-07-25 — Operator:** *"please identify and add the inception / tasks to the arc that helps us to achieve the goals & objectives"* — i.e. skip further debate, file the work. Interpreted as: implicit endorsement of pursuing the operational direction; arc = arc-014 (its charter is an accumulator: gaps discovered while documenting are filed as constituent tasks). Formal IW-1/IW-2 confirmation still owed at decide time via /inception/T-2619.
- **2026-07-25 — Agent:** filed T-2619 (keystone, GO recommendation), T-2620 (overlay inception, DEFER pending keystone + 832 seam answer), T-2621–T-2624 (build slices per goal). Open: operator decide on T-2619; rail question to 832 on overlay seam placement queued behind that decide.
- **2026-07-25 17:13Z — Operator:** **GO recorded** via /inception/T-2619 — commits to mirror-first (live-state overlay) + selective spec-conformance (task-lifecycle only). IW-1 answered by the decision; IW-2 dissolved (GO commits to creating pull; current-usage measurement moot); IW-5 deferred to T-2622 (precedence declaration is that slice's first AC). T-2619 completed and archived.
- **2026-07-25 — Operator:** *"lets add what do we need to discuss?"* → agent handed back the remaining operator-input agenda: (1) which live state first + wrapper-v0 vs 832-hook sequencing (T-2620 IW-1/IW-2), (2) arc-014 headline stretch vs new arc for the operational phase, (3) corpus-subordinate precedence proposal (T-2622), (4) draft-tier ceremony line (T-2623), (5) T-2621 vs T-2622 sequencing.
- **2026-07-25 — Operator (agenda round 1):** item 2 **decided: ask 832 first** (annotation-seam proposal posted rail offset 196; T-2620 IW-2 answered); item 6 **decided: T-2621 (conformance) before T-2622 (retrieval)**; items 1, 3, 4, 5 — elaboration requested, delivered in chat (state-candidates a/b/c with recommendation task-status-first; arc option (a) widen arc-014 vs (b) new operationalisation arc with crisp headline, agent leans (b); three-part precedence rule — declaration/enforcement/per-map-revocable promotion; draft-tier exemption list with promotion-only operator sign-off). Awaiting operator picks.
- **2026-07-25 — Operator (agenda round 2):** item 1 — overlay idea endorsed BUT challenged against purpose: *"what does this have to do with the purpose and goals of the workflow designer? reflect what are purpose and goals"* → agent reframe: overlay must be **process-level** (WIP concentration, gate friction — the process misbehaving on the map you can then redesign in the same surface), not a task-lookup duplicate of Watchtower; observe→diagnose→redesign→ratify→conformance loop is the purpose fulfilled. Item 3 **decided: option (b)** — close arc-014 on its documentation win when constituents drain, open a designer-operationalisation arc, re-home T-2620..T-2624. Item 4 — operator **rejects MD-as-permanent-authority**: *"why would a workflow live in md if it's also described in a workflow map? would we not want a reference from claude.md to the workflow map at best, cascading levels of detail?"* → target architecture flipped: CLAUDE.md thins to principles + pointers, maps hold process detail (cascading detail levels), subordination is only a TRANSITIONAL safety until per-map conformance rails are green; T-2622's precedence AC to be rewritten to encode the cascade + transition, IW-5 disposition revised. Item 5 — explanation didn't land ("?????"), plain-language re-explain owed.
- **2026-07-25 — Operator (agenda round 3):** item 1 **settled with a navigation rule**: observe-and-drilldown confirmed, but drill-down descends to **generalized sub-workflows** (cascading maps — subProcess expansion / cross-map jumps), *never* to individual task pages; individual task data is the **observation layer** — it feeds aggregates and fires **triggers to be actioned** (threshold breaches surfacing as actionable signals). Item 5 **endorsed**: draft mode as the *joint iteration + testing surface* — "we can also jointly iterate it and test it before releasing it fully in production"; promotion = production release. Still open: item 4's per-map graduation rule (conformance-green → map replaces CLAUDE.md prose) awaits explicit operator confirmation.

## Findings (updated as spikes run)

- **IW-3 answered (2026-07-25 spike):** the 0.4.0 bundle has zero `postMessage` hooks (grep = 0) — no in-bundle extension point exists. However, the bundle and all APIs are served **same-origin** under Watchtower, so a wrapper page can iframe `/designer/app?load=…` and reach `contentDocument` to annotate `g[data-id]` (uid-keyed) nodes externally: CSS classes, badges, counts. **No fork of the pinned artifact, no 832-side change required for a v0 overlay.** A designer-side annotation hook remains the cleaner long-term shape — that's the rail question queued in T-2620. Live iframe-reach test = T-2620's first act.
- **IW-4 answered (2026-07-25 spike):** the status-transition table is centralized in `lib/enums.sh:68-77` (`VALID_TRANSITIONS`, 8 pairs, YAML-loadable with inline fallback); `update-task.sh:1303` enforces via `is_valid_transition`. `fw corpus derive aef-task-lifecycle` emits machine-readable uuid-stable nodes/edges (the map's own doc block names update-task.sh as its source of truth). Map-vs-code comparison is **fully mechanical** — T-2621 is small and well-bounded. Other maps have no single enforcement point; conformance stays task-lifecycle-only, as recommended.
- **Open for operator at decide:** IW-1 (commit to mirror-first + selective spec?), IW-2 (does the operator pull on the maps today, and for what?), IW-5 (precedence declaration for corpus-as-read-surface).
