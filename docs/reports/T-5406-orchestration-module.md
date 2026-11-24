# T-5406 — Ring20's orchestration: separate module or integral to AEF?

Status: exploring (operator request 2026-11-24). Research artifact (C-001).

## The question

Ring20 Manager built orchestration on its own estate (arc-009). Should it come into AEF as a separate module that
plugs in, the way the workflow designer (832), TermLink and the ontology work do, or become an integral part of AEF?

## What ring20 shows today (its /orchestration page, read 2026-11-24)

- **Registry entries** (`policy/orchestration-registry/`): worker types with a capability class. 2 admitted:
  `analyst-readonly`, `writer-lowrisk`. **Candidates** are proposed; admission is operator-only.
- **Routes**: which harness runs a worker (`rt-claude-sub`, `rt-codex-sub`), each with a tool policy
  (`enforces_tool_policy=readonly` refuses a write-capable entry).
- **Commissions** ledger (`.context/orchestration/commissions.jsonl`, 586 rows): 41 commissions (16 work, 25 review),
  80.5 % success, 14.6 % retried, per-entry × route pass rates and launch→hand-back times.
- **Gates** that refuse a commission before launch: 4.3 route (policy mismatch), 4.6 caps (commissions per hour).
  7 refusals, 16 review rejections.
- **Supervisor runs** (13, 3 halted) and **halts**.
- Most recent rows are from 2026-10-20: the page reads, it is not obviously in daily use since then (to confirm).

## What AEF has (first pass)

| Ring20 piece | AEF today | Gap |
|---|---|---|
| dispatch of a worker | `fw termlink dispatch`, run.sh supervisor-writer (shared contract T-4435, wc v0.3.4) | shared, already agreed three-way |
| route (which harness/model) | review panel registry `policy/review-backends.yaml` (seats, kinds, vendors) — reviews only | no routes for work dispatch |
| worker-type registry + admission | none (prompt templates, task types) | missing |
| pre-launch gates (route policy, caps) | budget/spawn reserve, worker cap 5, paid-backend gate | no per-entry/route policy or rate caps |
| commission ledger + success/retry stats | `.context/dispatches.jsonl` + outcomes, `fw orchestrator status` | partly; no entry×route view |
| supervisor halts | none beyond worker timeout | missing |

## Options (to discuss with ring20 and decide with the operator)

1. **Separate module** (own repo and release, AEF pins a version, like the designer): clean ownership, generic by
   construction, ring20 stays the producer; AEF integrates through the shared worker contract and an adapter.
2. **Integral to AEF**: one place, one release train; AEF must take over maintenance and strip ring20 specifics.
3. **Split**: the generic contract and ledger in AEF (it already co-owns the contract), the registry/gates/supervisor
   as a module.

First lean (to test, not a decision): 1, because today's T-5392 review showed what happens when one estate's
specifics land in the framework, and because the designer/TermLink pattern already works.

## Ring20's inventory (T-2868, http://192.168.10.122:3000/file/docs/reports/T-2868-arc009-orchestration-inventory.md, read 2026-11-24)

- Engine ~4,900 lines in ring20 `scripts/` (orch-supervisor.py 2686, orch-registry.py, orch_candidates.py, orch_pool.py, orch_view.py) + ~4,700 lines of tests.
- **Parked:** arc-009 closed by the operator 2026-11-21 (ring20 T-2449); newest commission 2026-10-20T21:43Z; no timer runs the supervisor; the page shows a frozen ledger.
- **Live successor:** ring20's pool (pool-relay + poold), jobs not commissions; reuses only orch_pool's uid pool and containment. AEF already uses it (node1 nightly, T-5392).
- **Generic core:** supervisor state machine + ledger + gates 4.1-4.11 + halt verbs; registry/candidates/admission schema; view data layer + blueprint; contract S-1 + conformance tests. **Ring20 adapters:** uid/containment, preflight host list, routes/vendor logins, entries, role chain. Hard-coded values to move into config first.
- **Ring20's view:** adopting now = adopting dormant code; a separate module is worth it once AEF has a second consumer.

## Options after the inventory

1. Do not port now; keep the inventory as reference; lift generic pieces into AEF dispatch when a concrete need appears (registry/admission, pre-launch gates and caps, halts). **Agent recommendation.**
2. Separate module now (ring20 moves hard-coded values to config; generic core becomes a versioned repo AEF pins).
3. Integral to AEF now.
Open question for the operator: was closing arc-009 "done for ring20" or "good idea, wrong home"?

## Dialogue log

- 2026-11-24 ring20 (msg 99e0448b): claimed as ring20 inception T-2868. It will answer with a document: a real inventory (paths, size, generic vs ring20-specific: hosts, pools, uids, entries), whether it is in daily use (it suspects the commission ledger went quiet after 10-20 because the pool took over the work), then its view with a module-boundary sketch. It calls our separate-module lean a reasonable starting hypothesis.

- 2026-11-24 operator: "we've got really nice orchestration capability that Ring20 Manager has developed ... I'm still
  a little bit unclear about how much you have incorporated ... go in close collaboration with Ring20 Manager to get
  this in as a separate module, and maybe discuss together if we should make it a separate module like workflow design
  and termlink and ontology ... or make it an integral part of AEF".
