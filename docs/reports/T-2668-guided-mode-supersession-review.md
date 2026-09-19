# T-2668 — guided-mode procedural enforcement (package Lock 6): supersession review

**Task:** T-2668 (inception, arc-014 designer-corpus)
**Question:** Should the framework build procedure-level enforcement — `fw workflow
bind/advance`, caged instance state (package Q10), human-gate protection at map
`userTask` nodes — inside the delivered mirror+rails architecture?
**Filed:** 2026-07-28 with `Recommendation: DEFER` pending T-2663 (SD-1) and
T-2664 (P4 falsifiability test). **Reviewed:** 2026-09-19 under the T-3391
autonomous run. Read-only research; no spikes, no build artefacts.

## 1. What the DEFER was waiting for, and what happened

| Dependency | Status on 2026-09-19 | What it says about T-2668 |
|---|---|---|
| T-2663 — SD-1 disposition | `work-completed` 2026-07-28T17:10Z, **GO** | Ratified mirror+rails (corpus + conformance rails + overlay) as the Process layer. Its GO criteria read: *"retire guided-mode/YAML-canonical form, **or park it as a named future arc**"*; T-2662 §4 SD-8 row records: *"guided/strict parked in T-2668"*. So SD-1 **parked** guided mode rather than retiring it — T-2668 was, on 2026-07-28, the named parking slot. |
| T-2664 — P4 falsifiability test | `work-completed` 2026-07-28T19:59Z; tier0-escalation map + conformance rail shipped | Set a falsifiable prediction (T-2664 §Falsifiability anchor): post-map, the enforcement point should show materially fewer Cluster-A regressions per unit time than the 2026-02→04 baseline (6 of 16 tier-0 tasks). Measured below. |
| **arc-019 — EWCR** (not named by the DEFER; opened after it) | In flight; operator GO 2026-08-20; Arc 0 contracts v1 frozen (T-3385–T-3388) | Takes up the question directly — see §3. |

## 2. P4 measurement (IW-2)

`git log --format=%h -- agents/context/check-tier0.sh`, three windows:

| Window | Commits touching the Tier-0 hook | Of which correctness regressions |
|---|---:|---|
| Baseline 2026-02-01 → 04-30 (T-2664's anchor) | 20 | 6 (Cluster A, per T-2664) |
| Interim 2026-05-01 → 07-27 — **before the map/rail existed** | 1 | — |
| Post-rail 2026-07-28 → 09-19 (53 days) | 3 | 0 (T-2742 documents the scope boundary; T-3086/T-3078 provenance) |

Reading: the prediction is **not disproven** — zero Cluster-A regressions post-rail.
But the regression rate had already collapsed to ~1 commit in 88 days *before* the
rail shipped. The baseline window was the hook's build-out phase (T-092 →
T-1508), so the drop is at least as well explained by maturity as by the map. The
test as designed cannot attribute the effect; it can only fail to falsify. That is
not a reason to build Lock 6, and it is not evidence against building it either.
It is an input for arc-019's own evidence programme, not for this inception.

## 3. arc-019 coverage (IW-3)

`docs/research/executable-workflow/architecture-c9070637.md` (operator-owned GO,
§18, 2026-08-20) against T-2668's three named mechanisms:

| T-2668 asks for | EWCR architecture | Where |
|---|---|---|
| `fw workflow bind/advance` | Routing and binding lifecycle: *intake → candidates → eligibility → recommendation → human decision or pre-authorised selection → **bind task → create instance***; per-node sequence with compare-and-append transitions | §7.2, §7.5, `transition-envelope.schema.json` (contracts v1) |
| Caged instance state (package Q10, autonomy-integrity) | Instance state machine, runner-owned; *"one privileged service runner … never an agent identity"*; mandatory second slice proves *"an agent user cannot edit ledger/state, launch registered actions, forge operator proposals, or bypass refusal"* | §7.3, §9, §11 slice 2, `instance.schema.json` |
| Human-gate protection at `userTask` nodes | First executable slice item 4: *"Human gate, one hash-pinned registered script, typed I/O, evidence, durable deadlines … compare-and-append conflict refusal"*; refusal `reason_code: human_gate_skipped` is a frozen enum value | §11 slice 1, `refusal.schema.json` |

The dossier is explicit about its lineage (line 322): *"The earlier Workflow
Process Layer proposal anticipated guided/strict modes, typed I/O, call-with-return,
human touchpoints, component links, gated instance advance, and a future strict
runner. Its formal disposition correctly records those as open. **This dossier
extends that thinking**."* The 2026-07-28 DISPOSITION is in its grounding record
(§15). The roadmap (`roadmap-5be23719.md`) sequences it: Arc 1 semantics-first
runtime kernel → Arc 2 boundary-isolation proof → … → Arc 5 guided agentic
execution (`questions-and-dispositions.md` row 5: DEFER, *"blocked by the isolation
gate"*).

**Conclusion:** the "named future arc" that SD-1's GO allowed for guided mode
exists, is operator-ratified, and has landed its Arc 0. T-2668 no longer holds a
decision; it holds a pointer.

## 4. Assumption ledger

| ID | Assumption | Verdict | Evidence |
|---|---|---|---|
| A-054 | SD-1 retired guided mode outright | **invalidated** | T-2663 GO criteria ("or park it as a named future arc"); T-2662 SD-8 row |
| A-055 | P4 test shows the rail reduced regressions | **invalidated** as stated | §2 — not disproven, but unattributable (interim window already ~0) |
| A-056 | arc-019 already specifies bind/advance, instance cage, human gates | **validated** | §3 — §7.2, §7.3, §9, §11; contracts v1 |

## 5. Go/No-Go evaluation

- **GO if** the three mechanisms are unowned and a bounded slice inside mirror+rails could deliver them — *not met*: all three are owned by arc-019 with a ratified architecture and a frozen contract set.
- **NO-GO if** authorising build slices here would duplicate or fork a ratified programme — *met*: any `fw workflow bind/advance` built under T-2668 would be a second runtime beside EWCR's, against the 2026-08-20 decision that sequences guided execution *after* the isolation proof.
- **DEFER if** a genuine evidence gap remained — *not met*: both named dependencies have landed and the successor arc is in flight. Further DEFER would be a hedge (T-2144 rule).

## 6. Recommendation

**NO-GO — dissolved by supersession.** No build slices from T-2668. The question
it asked is answered, in a different shape, by arc-019 EWCR; the answer's shape
(runtime + runner + ledger, sequenced behind an isolation proof) was a Sovereign
decision on 2026-08-20 and is not reopened here.

Two things transfer to arc-019 rather than close silently:

1. **Q10 (instance-state cage / autonomy-integrity)** — flagged highest-consequence in T-2662 and *"load-bearing the moment anything guided-mode-like is attempted"*. EWCR's Arc 2 boundary-isolation proof is where it is answered; the roadmap already gates Arc 5 on it.
2. **The P4 measurement (§2)** — a maturity-confounded non-falsification. If arc-019 wants a regression-reduction claim for executable procedures, it needs a design that can attribute, e.g. a process whose regression rate has *not* already collapsed.

Open item this review does not decide: whether arc-014 should carry T-2669
(audience lenses) and T-2670 (workflow fabric index) through the same
supersession check — T-2670's subject ("Workflow Fabric derived index") appears
verbatim in EWCR §8.3 and Arc 4/5. That is a separate question, one task each.

## 7. Dialogue log

None — no human dialogue occurred; this review was executed under an autonomous
mandate (T-3391) with the go/no-go explicitly reserved to the operator via
`fw task review T-2668`.
