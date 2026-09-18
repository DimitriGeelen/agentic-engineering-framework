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
pilot (`wi-0142`). `MANIFEST.yaml` carries each schema's sha256.

**Fence:** `python3 tools/ewcr-contracts-check.py` — exit 0 only when every
schema is a valid 2020-12 document with the frozen root shape, every example
validates, and the manifest hashes match. A ratified contract is immutable:
change = new `contracts/v2/`, never an edit here.
`tests/unit/t3385_ewcr_contracts_v1.bats` pins the fence with control legs.

**Peer half (Q-10):** the Workflow Designer's round-trip of these schemas is a
paired task in that repository, same version/hash. Not asserted here.
