# T-5144 — EWCR R7: the designer contract inventory reconciled with ratified SD-1

**Task:** T-5144 · **For:** 832 (their T-732, msg 4398bbf5, ask R7 of envelope
`EWCR-ARC0-ATTEST-832`) · **Date:** 2026-11-16 · **Repo state read:** `bleeding-edge` @ `d431ce279`

## Summary for 832 (plain language)

1. SD-1 says the AEF Process layer is maps + conformance rails + a live overlay. Code runs; maps describe it and must match it ("mirror direction").
2. The EWCR contract set (contracts v2, 12 files) describes something SD-1 put on hold: a runner that executes ratified procedures and keeps instance state.
3. That is allowed. SD-1's GO let guided mode be "parked as a named future arc", and T-2668 later named EWCR (arc-019) as that arc. But nothing went back and updated the SD register or D-344, and the EWCR documents never cite T-2663.
4. Results: 0 of 12 v2 contracts conflict with SD-1 without a sanction. 4 conflict with SD-1's wording but are covered by the parking clause. 8 are simply outside SD-1. Of the five shared Designer↔AEF contracts, 2 conform, 1 conflicts in the same sanctioned way, and 2 are not covered.
5. Gaps: the SD register needs an amendment (operator), the five shared contracts still have no paired tasks, and the pinned designer 0.43.0 validator still calls YAML "AEF-canonical", which SD-1's register retired. Owners are proposed in §5.

## 1. SD-1, verbatim

| Field | Value |
|---|---|
| Text | `SD-1 \| Core concepts identity \| **GO** — Governance / Value / Process confirmed; Process = corpus + conformance rails + overlay, mirror-direction` |
| Source | `docs/reports/T-2662-workflow-process-layer-package-review.md:165`, in §7 "SD register — FORMALLY DISPOSED (T-2663 GO, operator via Watchtower, 2026-07-28T17:10Z)" (line 157) |
| Ratifying task | T-2663, inception, Decision **GO**, `.tasks/completed/T-2663-dispose-workflow-process-layer-sd-regist.md` (§Decision, dated 2026-07-28T17:10:41Z) |
| Decision id | **D-344**, `.context/project/decisions.yaml:2393-2397`, date 2026-07-28: *"Process layer ratified as mirror+rails: corpus maps + conformance rails + live overlay ARE the AEF Process layer; code is the enforced machine and maps must conform (reverse of the 2026-07-02 package's guided-mode direction). SD-1..15 register disposed per … §7. Guided mode parked (T-2668), lenses NO-GO-rec (T-2669), fabric index deferred (T-2670)."* |
| GO criterion (scope of the ratification) | T-2663 §Go/No-Go: *"retire guided-mode/YAML-canonical form, **or park it as a named future arc**"* |

The SD rows that inherit from SD-1 and matter here (same file):

- **SD-3** (line 167): task↔workflow binding — *"Parked — mirror direction has no instance semantics; revives only with T-2668"*.
- **SD-4** (line 168): *"code is normative, maps are descriptive-must-conform"*.
- **SD-5** (line 169): YAML/`workflows/` retired; *"single stored representation (T-2608)"*.
- **SD-6** (line 170): ratified immutability = *"gated promote + version bump + uuid permanence + sha pinning"*.
- **SD-8** (line 172): guided/strict enforcement *"parked in T-2668"*.
- **SD-10** (line 174): instance state home + cage — *"Parked with T-2668"*.

What happened to the parking slot: T-2668 closed on 2026-09-19 as **"dissolved by
supersession"** (D-575). Its review says arc-019 EWCR is the "named future arc" that
SD-1's GO allowed (`docs/reports/T-2668-guided-mode-supersession-review.md:15`, `:58-60`).

## 2. The inventory

832's exact wording of "the designer contract inventory" could not be read here. The
2026-11-15 message is known only by id (`.context/sidecar/direct-ack.jsonl`), and
`agent-chat-arc` no longer holds offset 643. So I picked from three candidates:

| # | Candidate | Path | Version / hash | Count | Used? |
|---|---|---|---|---|---|
| A | **EWCR contracts v2** | `docs/research/executable-workflow/contracts/v2/MANIFEST.yaml` | `contracts_version: 2`, frozen by T-5179, last commit `f25f16618`; MANIFEST sha256 `24f0dc6ee3a0d2f4…` | 12 (7 schemas + 5 documents) | **Primary (§3).** It is the only versioned, hash-frozen contract set, and R7 came in the EWCR-ARC0 envelope. |
| B | The five shared Designer↔AEF contracts | `docs/research/executable-workflow/architecture-c9070637.md:346-357`; paired-task register `questions-and-dispositions.md:103-107` | all "v1 (unset)" | 5 | **Also assessed (§3.2).** These are the contracts between the Designer and AEF in the literal sense. |
| C | Designer data API contracts AEF serves | 832 `docs/reports/T-1300-designer-data-api-contract.md` (not in this repo); local digest `docs/reports/T-4737-designer-data-apis.md`; code `web/blueprints/designer_api.py`, `web/blueprints/designer.py:269` | none recorded | 11 routes + `/api/overlay` | Listed only, with a short verdict (§3.3). They are HTTP plumbing, not EWCR contracts. |

Contracts v1 (`contracts/v1/`) is not a separate inventory. v2 carries 11 of its 12 files
byte-identical and changes only `refusal.schema.json` and the trace/matrix documents
(`v2/MANIFEST.yaml:37-49`).

The pinned designer is 0.43.0 (`policy/designer-pin.yaml:19-21`, sha256
`85119747…287f`). It ships no contract list into AEF. Its validator
(`vendor/designer/validate-workflow-0.43.0.py:4-15`) points at 832's
`docs/designer/schema.md`, which is not in this repo.

## 3. Contract-by-contract verdicts

Verdict key:
- **conforms** — consistent with SD-1 as worded.
- **conflicts (sanctioned)** — goes against SD-1's mirror direction or a parked SD row, but sits inside the "park as a named future arc" clause, which T-2668 handed to arc-019. Nothing records the handover in the SD register itself.
- **not covered** — SD-1 says nothing about this subject.

No contract was found that conflicts with SD-1 **without** that sanction.

### 3.1 Inventory A — EWCR contracts v2 (12 rows)

| Contract | What it asserts | SD-1 verdict | Evidence | Gap |
|---|---|---|---|---|
| `procedure.schema.json` | A ratified procedure is an immutable, versioned method the runner executes | **conflicts (sanctioned)** | Schema description (§2.1, §7.1); SD-4 at T-2662:168 says maps are descriptive. Here a ratified definition drives execution. | G1 |
| `instance.schema.json` | One live, runner-owned enactment of a pinned procedure, bound to a task | **conflicts (sanctioned)** | Schema description (§2.3, §2.4, §7.3); SD-10 parked at T-2662:174, SD-3 at :167 | G1 |
| `transition-envelope.schema.json` | Every instance transition is an immutable envelope in an append-only ledger | **conflicts (sanctioned)** | Schema description (§7.3); this is the "gated instance advance" SD-8 parked (T-2662:172) | G1 |
| `attempt.schema.json` | One action attempt with hashes, policy decision, executor and outcome | not covered | Schema description (§2.5, §7.4); SD-1 has no action-execution concept | — (depends on G1) |
| `deadline-event.schema.json` | Timeouts and deadlines are durable runtime inputs, re-evaluated after restart | not covered | Schema description (§7.4) | — |
| `evidence-reference.schema.json` | Evidence is hashed before validation; accepted evidence is immutable | not covered | Schema description (§6.6.1, §2.5) | — |
| `refusal.schema.json` (v2) | A refusal is a durable record with no side effect; adds `privilege_exceeds_profile` | not covered | Schema description; `v2/MANIFEST.yaml:29-32`, `:44` | — |
| `task-lifecycle-contract.md` | The task stays the canonical record; a task binds to an instance; runner snapshots the task hash at each gate | **conflicts (sanctioned)** on binding; conforms on "task stays canonical" (Governance concept in SD-1) | `v2/task-lifecycle-contract.md:1-5`; SD-3 at T-2662:167 | G1 |
| `evidence-and-idempotency.md` | Snapshot → hash → validate → accept; idempotent attempts and timers | not covered | `v2/evidence-and-idempotency.md:1-5` | — |
| `accepted-scenarios.md` | New scenarios N-1, N-2 the future engine must pass | not covered | `v2/accepted-scenarios.md:1-12` | — |
| `traceability.yaml` | Each §13 scenario and N-1/N-2 traced to contract, refusal, component, fence | not covered (rail-like in shape: a checked fence, `tools/ewcr-trace-check.py`) | `v2/traceability.yaml:1-20` | — |
| `refusal-threat-matrix.md` | Every blocker from four external reviews traced to a refusal scenario | not covered | `v2/refusal-threat-matrix.md:1-14` | — |

Count: conforms 0 · conflicts (sanctioned) 4 · not covered 8.

One SD-1 property the whole set does keep: the freeze discipline (sha pinning, a change
means a new version, `v2/MANIFEST.yaml:1-3`) matches SD-6 (T-2662:170).

### 3.2 Inventory B — the five shared Designer↔AEF contracts

| Contract | What it asserts | SD-1 verdict | Evidence | Gap |
|---|---|---|---|---|
| Procedure interchange | Designer exports procedure definitions with stable IDs, typed I/O and a content hash | **conflicts (sanctioned)** — same reason as `procedure.schema.json` | architecture:346-347; Q&D:103 "v1 (unset)" | G1, G2 |
| Mapping / compatibility | Which Designer/BPMN version produces which runtime-contract version | not covered | architecture:348-350; Q&D:104 | G2 |
| Validation / refusal diagnostics | Structured diagnostics with stable codes and element IDs | not covered | architecture:351-352; Q&D:105 | G2 |
| Runtime projection | Read-only instance state that the Designer renders; operator submits typed proposals | **conforms** in direction: it is an overlay, and the Designer renders but does not own state (SD-1 "overlay"). The state it projects is instance state, which SD-10 parked. | architecture:353-354; Q&D:106 | G2 |
| Ratification | A Designer save/export is only a proposal until AEF records the human decision | **conforms** — SD-4 (AEF/code governs) and SD-6 (gated promote) | architecture:355-357; Q&D:107; T-2662:168, :170 | G2 |

Count: conforms 2 · conflicts (sanctioned) 1 · not covered 2.

### 3.3 Inventory C — Designer data APIs (listed, not row-by-row)

`/api/instances` (`designer_api.py:323`, T-4831) and `/api/overlay` (`designer.py:269`)
project live task state onto the `aef-task-lifecycle` map. That is the SD-1 "overlay",
in mirror direction, so they **conform**. `/api/save`, `/api/list`, `/api/versions`,
`/api/version`, `/api/delete` and `/api/thumb` serve the designer store
(`.context/designer/projects/`), which SD-5 named as the home. They **conform**.
`/api/validate` (T-4830), `/api/field-catalog` (T-4832), `/api/lens-definition` and
`/api/health` are **not covered** by SD-1. No gap is raised for C.

## 4. Gaps

**G1 — The SD register and D-344 were never updated after T-2668.**
SD-3, SD-8 and SD-10 still say "parked with T-2668" (T-2662:167, :172, :174), and D-344
still says "Guided mode parked (T-2668)". T-2668 closed on 2026-09-19 (D-575) and passed
the question to arc-019. So the record says "parked" while a frozen contract set
(4 contracts in §3.1, 1 in §3.2) defines exactly that parked thing. The EWCR documents
also never cite T-2663 or D-344. They ground themselves on 832's
`DISPOSITION-2026-07-28.md` instead (architecture:322, :954; grep of
`docs/research/executable-workflow/` and `docs/reports/EWCR/` for "2663" / "D-344"
returns nothing). Result: a reader of SD-1 alone would conclude EWCR contradicts it.

**G2 — The five shared contracts still have no paired tasks.**
All five are "v1 (unset)" (Q&D:103-107). Drive 7 records them as unpaired on both
sides (`docs/reports/EWCR/drive-7-procasfit-handback.md:398`). Q-10 and Q-11 are still
open because of this (Q&D:83-84). This is not an SD-1 conflict. But until the
contracts exist, 3 of 5 cannot be checked against SD-1 beyond their one-line
description.

**G3 — The pinned designer validator still calls YAML "AEF-canonical".**
`vendor/designer/validate-workflow-0.43.0.py:10` says *"YAML canonical form (section 3)
-- the AEF-canonical, source-controlled, hand-authorable representation"*. SD-1's GO
criterion retires the YAML-canonical form (T-2663 §Go/No-Go), and SD-5 names a single
stored representation (T-2662:169; T-2608 GO: single stored XML, YAML derived on
demand). This is wording in 832's artefact. I did not check whether AEF stores YAML
anywhere, so this is a wording conflict, not a proven behaviour conflict.

## 5. Proposed owners

| Gap | Proposed owner | Why |
|---|---|---|
| G1 | **T-5182** (captured, horizon later): operator amendment of the SD register (T-2662 §7) and D-344, recording that SD-3/SD-8/SD-10 moved from "parked (T-2668)" to "taken up by arc-019 EWCR (D-575)", and that EWCR procedures are a sanctioned exception to SD-4's mirror direction. Plus a one-line cross-reference to T-2663/D-344 in the EWCR architecture grounding record. | No existing task fits. T-2663 and T-2668 are completed. A grep of `.tasks/active/` for "SD register", "SD-3", "SD-10" finds nothing. Changing a ratified decision is the operator's call. |
| G2 | **T-5183** (captured, horizon later; split per contract once versions are agreed with 832): create AEF-side paired tasks for the five shared contracts at an agreed version/hash. | The register says "None are created by this task" (Q&D:99). No active task names them. T-3389 (EWCR Arc 0 cand 3) is `work-completed` and covers the refusal matrix, not pairing. |
| G3 | **832** (gap homing: the file is 832's release artefact, and AEF never edits the vendored copy, `policy/designer-pin.yaml:1-5`). AEF side: **new task needed** only if 832 asks AEF to confirm that no YAML is stored. | The fix belongs in 832's validator docstring and `docs/designer/schema.md`. |

## 6. What was not found

- 832's exact R7 wording and their definition of "the designer contract inventory" (§2).
- 832's `docs/designer/schema.md` and `T-1300-designer-data-api-contract.md` (not in this repo).
- Any AEF document, after 2026-07-28, that amends or cites SD-1 besides T-2668's review.
