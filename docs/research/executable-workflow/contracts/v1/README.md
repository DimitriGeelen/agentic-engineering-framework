# EWCR contracts v1 — frozen (T-3385, Arc 0 candidate 2)

Seven JSON Schema (draft 2020-12) documents freezing the runtime contract
objects named in `../../architecture-c9070637.md`. Each schema's root
`description` names the architecture section it freezes, so an operator can
pick any pilot invariant and find its contract (the Arc 0 headline mechanic).

| Schema | Freezes | Object |
|---|---|---|
| `procedure.schema.json` | §2.1, §6.1, §6.2, §7.1 | ratified, immutable, content-hashed institutional method |
| `instance.schema.json` | §2.3, §2.4, §7.3, §7.6 | one enactment, runner-owned, task-bound by hash |
| `transition-envelope.schema.json` | §7.3, §7.4 | append-only ledger entry; compare-and-append |
| `attempt.schema.json` | §2.5 step 4, §7.4, §7.5 | one execution attempt; outcome ≠ instance outcome |
| `evidence-reference.schema.json` | §6.6.1, §2.5 | typed artefact ref, hashed before validation, immutable once accepted |
| `refusal.schema.json` | §2.5, §7.4, §13 | durable refusal record, `side_effect: false` by construction |
| `deadline-event.schema.json` | §7.4, §13 #17 | absolute deadline admitted to the ledger; idempotent evaluation |

`examples/` holds one worked instance per schema — the §2.5 `verification-gate`
pilot (`wi-0142`) — plus the T-3388 human→script→human fixture
(`procedure-human-script-human.json`, `instance-human-script-human.json`) and
the T-3387 supersession example (`evidence-reference-superseding.json`:
`ev-0142-out4` superseding `ev-0142-out3`). `MANIFEST.yaml` carries each
schema's sha256.

**Contracts written against these schemas** (prose + Given/When/Then
scenarios, no runtime; each names its responsible Arc 1 component):

| Contract | Freezes | Arc 1 component |
|---|---|---|
| `task-lifecycle-contract.md` (T-3386) | §2.4, §7.2, §7.5 steps 1–2, 9–10; §13 #3, 5, 11, 13, 16, 18, 20 | cand 3 — task binding + revalidation |
| `evidence-and-idempotency.md` (T-3387) | §2.5, §6.6.1, §7.4, §7.5 steps 7–10; §13 #7, 9, 17, 18 | cand 7 — snapshot/hash/immutability; cand 8 — idempotent attempt/result/compensation |

**Trace surface (T-3393):** `traceability.yaml` is the machine-readable answer to
the Arc 0 headline mechanic — pick any invariant from architecture §13 and it
names the contract, section, refusal scenario, responsible Arc 1 component and
runnable fence. All **20** §13 scenarios appear; **11 are covered** by a frozen
contract (#3, 5, 7, 9, 10, 11, 13, 16, 17, 18, 20) and **9 are recorded as
explicit gaps** (#1, 2, 4, 6, 8, 12, 14, 15, 19), each with a reason and an
owning arc, so an uncovered invariant is stated rather than inferred from
silence. Two findings worth carrying: #6 has measured evidence (fence-1, T-3068's
`None`-not-zero blast radius) but no contract freezing it, and #14 has no
`reason_code` in the frozen enum at all — the refusal vocabulary may need an
entry before that invariant is contractable.

Its fence is `python3 tools/ewcr-trace-check.py` — exit 0 only when every row
resolves: statements match §13 verbatim, every named section exists in its
contract, every fence script is present, every `reason_code` is in
`refusal.schema.json`'s frozen enum, and every gap states a reason. Pinned by
`tests/unit/t3393_ewcr_traceability.bats` (10 tests, 7 of them control legs).

**Review surface (T-3389):** `refusal-threat-matrix.md` consolidates every blocker
finding from the **four** external reviews — Claude (`../../architecture-c9070637.md`
§17), Z.ai (§18), DeepSeek and Mistral (`../../reviews/`, sha256-pinned, provenance in
`../../reviews/PROVENANCE.md`) — into **19 rows**: finding id → source review → threat →
refusal scenario (`reason_code` + `scenario_refs` in `refusal.schema.json` terms) →
responsible component → verification fence or named gap. A "Not blockers" section lists
what was deliberately excluded and why, so the exclusions are visible too.

It also carries the measurement `../../questions-and-dispositions.md` §3 named as missing:
**14 of the 20 §13 scenarios would fail on the current AEF substrate**, 1 would pass (#6 —
T-3068's `None`-not-zero blast radius) and 5 have no analogue to fail yet, each classified
with the code or gate that decides it. Note that five of the fourteen are AEF's governance
plane working as designed — a deliberately bypassable plane fails a runner invariant
because it is a different plane; the two-plane reading (Q-04) stays operator-owned.

It agrees with `traceability.yaml` on every overlapping scenario (§5.2 tabulates the
check) and edits nothing ratified. Two **NEW scenarios** are proposed rather than numbered
— per-attempt task mutation (DS-1) and credential-scope excess (MS-3) — plus independent
corroboration that §13 #14 has no `reason_code` in the frozen enum at all.

**Fence:** `python3 tools/ewcr-contracts-check.py` — exit 0 only when every
schema is a valid 2020-12 document with the frozen root shape, every example
validates, and the manifest hashes match. A ratified contract is immutable:
change = new `contracts/v2/`, never an edit here.
`tests/unit/t3385_ewcr_contracts_v1.bats` pins the fence with control legs.

**Peer half (Q-10):** the Workflow Designer's round-trip of these schemas is a
paired task in that repository, same version/hash. Not asserted here.
