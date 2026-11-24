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

## Dialogue log

- 2026-11-24 operator: "we've got really nice orchestration capability that Ring20 Manager has developed ... I'm still
  a little bit unclear about how much you have incorporated ... go in close collaboration with Ring20 Manager to get
  this in as a separate module, and maybe discuss together if we should make it a separate module like workflow design
  and termlink and ontology ... or make it an integral part of AEF".
