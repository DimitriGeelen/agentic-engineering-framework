# Arc close-out pack — 2026-09-28

**Purpose:** let the operator rule per arc instead of excavating. **Nothing here closes an
arc** — `fw arc close` is agent-refused under `$CLAUDECODE=1` (T-1671, earned over four
incidents) and that refusal was respected.

## The finding this pack came from

| | |
|---|---|
| Arcs on file | 20 (18 in-progress, 2 draft) |
| Oldest created | 2026-05-01 — **five months ago** |
| Creation rate | ~4 / month |
| **Arcs ever closed** | **0** — `closed_at` is null for every arc that has ever existed |
| At or above the framework's own ≥80% close-ready threshold | **8** |
| At 100% | 2 — and **both are also on the stale-past-30-days list** |

The problem is not that too many arcs are opened. It is that **the arc lifecycle has an
entrance and no exit.** "Arc still open" is indistinguishable from "arc still being worked
on", so a closure rate of zero never surfaced as a failure.

**The gate history explains it, and each step was individually correct.** `fw arc close`
requires a wire-level `--demo`, requires the headline mechanic to have fired, defaults to
OPEN on unresolved pushback, and is agent-refused outright. Those came from T-1626, T-1633,
T-1641, then T-1667 and T-1670 after the third and fourth incidents. Every increment was
earned. **Nobody measured the aggregate**, and the aggregate is that nothing has ever passed.

**The decisive detail: four of the eight already have a captured demo** and are still open.
So the demo requirement is not the binding constraint — the missing step is simply that
nobody ever runs the close. That is worth knowing before anyone proposes relaxing a gate.

Membership resolved via `lib/arc_membership.py`, the canonical import (T-3516 / OBS-546
forbids re-deriving it locally — an earlier draft of this measurement did exactly that and
under-counted watchtower-redesign as 1 task against its real 70).

---

## Ready — demo captured, anchor recommendation present

### 1. `parallel-execution-aef` (arc-011) — 95.1%, 39/41

- **Headline mechanic:** two agents on disjoint-write-set tasks run concurrently against shared substrate, integrate through the hub's serialized integration queue, and the operator observes wire-evidence of parallelism (two dispatch IDs in flight at once in `dispatches.jsonl`) plus the absence of governance-plane interference.
- **Demo:** `agents/dispatch/single-host-parallel-demo.sh` (T-2341, exit 0) **+** `docs/reports/T-2371-arc-011-wire-evidence-demo.md` (captured run)
- **Anchor:** T-2303, completed, **GO**
- **Still open:** T-2323, T-2342
- **Judgement:** the strongest candidate in the set. Demo is wire-level and matches the headline mechanic directly. The two open tasks are the question — do they belong to this arc's claim, or are they follow-on work?

### 2. `continuous-run` (arc-012) — 88.7%, 47/53

- **Headline mechanic:** agent crosses the context-budget threshold without operator relay → `checkpoint.sh` self-triggers → handover + resume via `claude-fw` → operator observes a multi-cycle continuous session whose iteration counter, directive and bounded tier-ceiling are visible in `fw resume status`.
- **Demo:** `docs/reports/T-3239-continuous-loop-demo/REPORT.md`
- **Anchor:** T-2158, completed, **no Recommendation block**
- **Still open:** T-2369, T-2373, T-3204, T-3217, T-3240, T-3243
- **Blocker:** anchor has no `## Recommendation`. `fw arc close` needs it.
- **Caveat worth your attention:** today's audit reports this arc's wrapper as ARMED while the turn driver is not, and the Stop hook cycling on a stale terminate reason — G-099, the same drift class as two prior incidents. Closing an arc whose mechanism is currently drifting deserves a deliberate answer, not a default.

### 3. `orchestrator-rethink` (arc-003) — 85.4%, 105/123

- **Headline mechanic:** agent dispatches without specifying a model → orchestrator picks by task_type and historical success rates → user observes the routing decision live on `/orchestrator` and watches per-task-type preferences shift as the route_cache learns.
- **Demo:** `docs/reports/orchestrator-rethink-demo/README.md`
- **Anchor:** T-1641, completed, **GO**
- **Still open:** 18 tasks (T-1701, T-1702, T-1707, T-1737, T-1742, T-1773 … )
- **Judgement:** the largest arc in the corpus. 85% with 18 open is a different shape from 95% with 2 — this is a **scope question**, not a closure question. Ask whether the remaining 18 are this arc, or a second arc that was never split out.

### 4. `horizon-axis-hardening` (arc-009) — 80.0%, 4/5

- **Headline mechanic:** an agent reads the handover "Work in Progress" section and sees zero work-completed tasks in the now/next buckets; partial-complete tasks appear in an explicit "Partial-Complete — awaiting human" footer; completed tasks render `horizon=past` on Watchtower without a stored horizon.
- **Demo:** `docs/reports/arc-009-demo-evidence.md`
- **Anchor:** T-2159, completed, **DEFER**
- **Still open:** T-2160
- **Blocker:** anchor recommends DEFER. Per CLAUDE.md, DEFER is for evidence gaps, not confidence gaps — worth re-reading it, because an 80%-complete arc with a captured demo may have outgrown the DEFER it was filed under.

---

## Not ready — named rather than omitted

### 5. `onboarding-shape-detection` (arc-015) — **100%**, 3/3

- **Anchor:** T-2718, completed, **no Recommendation**
- **Demo:** none captured
- **Blocker:** both. Every constituent task is done and stale >30 days; what is missing is only the closing ceremony. Cheapest genuine close in the set if a demo can be pointed at — the headline mechanic (`fw init` reporting what it found in a .NET/Ruby/PHP/Make/Gradle project and seeding a task set) is directly demonstrable by running it.

### 6. `readme-first-run` (arc-016) — **100%**, 2/2

- **Anchor:** T-2719, completed, **GO**
- **Demo:** none captured
- **Blocker:** demo only. Headline mechanic is a by-hand five-minute README walkthrough with a persona test that fails loudly if it regresses — so the persona test *is* the demo candidate, if it exists and passes.

### 7. `capability-overlay` (arc-010) — 80.0%, 12/15

- **Anchor:** T-2209, completed, **DEFER**
- **Demo:** none captured
- **Still open:** T-2265, T-2268, T-2269 — T-2268 is the HM-A demo agent task, i.e. **the demo itself is one of the open tasks**
- **Blocker:** the demo is unbuilt by construction. Not close-ready; it needs T-2268 or an explicit `--demo none --justification`.

### 8. `ewcr-arc0-contract-evidence` (arc-019) — 90.0%, 18/20

- **Anchor:** T-3147 — **still open, and is itself one of the two incomplete tasks**
- **Demo:** none captured
- **Blocker:** an arc cannot close on an anchor that has not closed. Sequence is T-3147 first.

---

## Summary for a ruling session

| Arc | % | Demo | Anchor rec | What it needs |
|---|---|---|---|---|
| parallel-execution-aef | 95.1 | ✅ | GO | **Ready** — rule on 2 open tasks |
| orchestrator-rethink | 85.4 | ✅ | GO | **Ready** — but answer the 18-open scope question |
| continuous-run | 88.7 | ✅ | — | Anchor Recommendation; plus the G-099 drift caveat |
| horizon-axis-hardening | 80.0 | ✅ | DEFER | Re-read the DEFER |
| readme-first-run | 100 | ✗ | GO | A demo — persona test is the candidate |
| onboarding-shape-detection | 100 | ✗ | — | Demo + anchor Recommendation |
| capability-overlay | 80.0 | ✗ | DEFER | T-2268 (the demo IS an open task) |
| ewcr-arc0 | 90.0 | ✗ | GO | T-3147 (the anchor is open) |

**Two are ready to rule on today. Two need one artefact each. Four need real work first.**

## Surfaces

Per CLAUDE.md §Arc Action Handoffs the URL is the primary affordance and CLI the headless
fallback:

- `http://192.168.10.107:3002/arcs/<slug>` — arc detail, driver verdicts, close button when eligible
- `http://192.168.10.107:3002/arcs/<slug>/close` — the close form, §ACD prompt and demo modes
- `http://192.168.10.107:3002/approvals` — the Arc Closure section

## What this pack does not settle

Clearing eight arcs does not fix a closure rate of zero — it empties the backlog that rate
produced. The structural finding is registered separately in `.context/concerns.yaml` so it
survives the backlog being cleared, which is precisely when it would otherwise stop being
visible.
