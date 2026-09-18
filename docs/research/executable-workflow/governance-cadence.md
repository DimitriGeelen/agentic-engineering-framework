# Governance cadence and status board — Executable Workflow Contract Runtime (AEF side)

**Task:** T-3145 · **Correlation:** `t037-aef-ingestion` · **Role:** `aef-agent`
**Implements:** Shared operating contract Phase 5 (governance execution and
monitoring loop) and Phase 6 (continuity discipline).

> Deltas only. Do not flood the operator with unchanged status. Escalate
> contradictions; do not average them away.

---

## 1. Reconciliation triggers

Run the nine-point reconciliation (§2) at **each** of these moments — not on a
clock:

| Trigger | Also do |
|---|---|
| Session start | Re-verify both source hashes before reading either document |
| Task status transition | Re-check proposed-vs-confirmed BVP state |
| Any AEF↔Designer handoff (send **or** receive) | Re-verify hashes; record envelope + receipt in both projects |
| Verification failure | Route to `issues`/healing — never a silent path switch |
| Arc boundary (start, exit gate, close) | Full re-grounding: load full sources, not the digest |
| Before any completion claim | Phase 7 completion standard in full |
| Contract or source version change | New manifest revision entry; never overwrite a snapshot |

## 2. The nine-point reconciliation

1. Current task / arc / focus and outstanding human decisions
2. Source manifest hashes and shared contract versions
3. Acceptance / verification state and unresolved refusals
4. Dependency gates, pauses, claims, worktree / write-set isolation
5. Peer handoffs awaiting read-back or disposition
6. BVP scores — proposed versus confirmed
7. Component Fabric coverage and blast-radius uncertainty
8. Audit / doctor findings, stale services, ownership drift, bypass logs
9. Context-budget / continuity state and the next evidence-backed action

**Local commands** (discovered, not assumed):
`bin/fw context status` · `bin/fw doctor` · `bin/fw audit` · `bin/fw metrics` ·
`bin/fw fabric overview` · `bin/fw fabric drift` · `bin/fw review-queue` ·
`bin/fw gaps` · `sha256sum docs/research/executable-workflow/*.md`

## 3. Status board

Append a new dated block on meaningful change only. Never edit a prior block.

```text
source revision | current arc/task | gate state | peer contract/receipt state
latest evidence | blockers/risks | human decisions needed | next safe action
```

### 2026-08-25 — ingestion complete

| Field | Value |
|---|---|
| **Source revision** | manifest v1, rev 0 — architecture `c9070637`, roadmap `5be23719`; both re-verified this session, `hash_match: true` |
| **Current arc / task** | No arc. T-3145 (`design`, `started-work`, owner `agent`) |
| **Gate state** | Ingestion gates met. **Arc-start gate NOT met** — no local human authorisation exists. Roadmap §6 fence 1 (Fabric non-empty, enriched, validated) **fails**: 512/1117 components unclassified |
| **Peer contract / receipt state** | Inbound packet received and read back. **Outbound receipt not yet acknowledged** by T-037 on correlation `t037-aef-ingestion`. Two peer actions outstanding: raw-URL endpoint (G-086), and transfer of the four cited external reviews |
| **Latest evidence** | `source-manifest.yaml` (both `read_back_ok: true`); `questions-and-dispositions.md` (13-row gap matrix, 15 questions, 7 arc dispositions) |
| **Blockers / risks** | R1 Fabric coverage fails fence 1 · R2 no runner/service identity (C4) · R3 `--force`/`FW_*` vs arch §13.16 (Q-04) · R4 `--from-watchtower` vs arch §13.20 (Q-05) · R5 external review artefacts not transferred |
| **Human decisions needed** | See §4 — six, none of which an agent may take |
| **Next safe action** | Operator reviews this ingestion and rules on D1 (arc-start). No further AEF work until then |

### 2026-08-26 — Arc 0 falsifier 1 measured

| Field | Value |
|-------|-------|
| **Source revision** | manifest v1, rev 0 — unchanged (`c9070637` / `5be23719`) |
| **Current arc / task** | arc-019 `ewcr-arc0-contract-evidence` (**draft**). T-3147 (`design`, `started-work`, owner `agent`) |
| **Gate state** | **Falsifier 1 answered: `fence-1 blocking (3 components in the write set)`** — 4 under the BROAD write set. Fence 1 remains failed, but its measured cost collapses from a feared 512 components to **~28 items** |
| **Peer contract / receipt state** | Unchanged. Outbound receipt to T-037 on `t037-aef-ingestion` still unacknowledged; no reachable session found for 0503-codex-cli-playground |
| **Latest evidence** | `arc0-write-set.md` (derivation, §5.1 row per path) · `arc0-falsifier1-result.md` (result + control) · `tools/ewcr-arc0-unknown-overlap.py` · `tools/ewcr-arc0-coverage-check.py` · `.context/audits/ewcr-arc0-unknown-overlap.json` — all re-runnable at commit `ce2987fd2` |
| **Blockers / risks** | R1 **revised, not cleared** — 519 Unknown cards, but 453 (87%) are `tests/`, which the runtime does not write. Real fence-1 scope: 3 CORE + 17 `agents/` + 8 uncarded `policy/` YAML ≈ 28. **NEW R6: `policy/` has 0% Fabric coverage (0 of 8 YAML files carded)** — §5.1 row 2, the procedure/runtime-semantics surface. The falsifier as posed structurally cannot detect this: a directory with no cards contributes no Unknown cards and therefore reads as clean. R2–R5 unchanged |
| **Human decisions needed** | D5 (Q-03 coverage threshold) now has a measured number behind it — a **proposal** is stated in `arc0-falsifier1-result.md` and nothing has been applied. D1 (arc-start) still un-ruled; arc-019 remains `draft` |
| **Next safe action** | Operator rules on D5 using the proposed threshold, and on D1. No implementation, no threshold enforcement, no task creation until then |

**Method note.** The overlap count alone would have been misread. A low overlap is
produced both by a well-classified write set and by a write set that is barely in the
Fabric; a control (`ewcr-arc0-coverage-check.py`) was written to discriminate them and
found the second case in `policy/`. Any future restatement of fence 1 should carry the
coverage clause, not the Unknown-count clause alone — `policy/` scores a perfect zero
Unknown today while having no cards at all.

### 2026-09-08 — fence-1 measured scope cleared (operator-directed landing drive)

| Field | Value |
|-------|-------|
| **Source revision** | manifest v1, rev 0 — unchanged (`c9070637` / `5be23719`) |
| **Current arc / task** | arc-019 `ewcr-arc0-contract-evidence` (**draft**, unchanged). Drive T-3349 + slices T-3350/T-3351/T-3352 all `work-completed` |
| **Gate state** | **Fence 1's entire measured scope is cleared.** R6: `policy/` 0% → **100%** carded (T-3350). Unknown ∩ write-set: 3 CORE / 4 BROAD → **0 / 0**, list re-derived live, 23 cards reclassified (T-3351). Coverage clause: lib **98.2%**, web **98.8%**, agents **100%**, bin 100%, policy 100% — every CORE root ≥95% with 0 Unknown (T-3352; non-component files justified in task Updates, not silently dropped). All three slices ran as TermLink workers and were independently re-verified by the parent session re-running both measurement scripts |
| **Scope authorisation** | Arc 0's no-task-creation fence was lifted for this delta by explicit operator instruction in-session (2026-09-08, "stop finding, start landing… if there is a new scope, add that as tasks"). Registered as OBS-385 before fixing |
| **Latest evidence** | commits `b39495a0d`/`715d5dfee` (T-3350) · `ac9a9d410`/`7c5343e3d` (T-3351) · `abfd3069c`/`ad1018958`/`a2aec9f9a` (T-3352) · re-run `tools/ewcr-arc0-coverage-check.py` + `tools/ewcr-arc0-unknown-overlap.py` |
| **Blockers / risks** | R1 **cleared** (this block). R6 **cleared** (T-3350). R2–R5 unchanged |
| **Human decisions needed** | D5 and D1 only — unchanged, now with fence-1 pre-cleared under the proposed threshold. Under the proposal (≥95% coverage AND 0 Unknown per CORE root, tests/ excluded) fence 1 **passes today** |
| **Next safe action** | Operator rules on D5 and D1 at `/review/T-3147`. No runtime implementation until D1 GO — no agent-side EWCR work remains |

### 2026-09-17 — second landing drive (T-3381): no agent-side work found, arc focus taken

| Field | Value |
|-------|-------|
| **Source revision** | manifest v1, rev 0 — unchanged (`c9070637` / `5be23719`) |
| **Current arc / task** | arc-019 `ewcr-arc0-contract-evidence` (**draft**, unchanged). T-3147 partial-complete, 0/2 Human ACs |
| **Drive outcome** | **Nothing landed, by design.** A second operator "stop finding, start landing" drive re-reconciled the backlog and reached the same terminal state as the 2026-09-08 drive: all four arc tasks plus drive T-3349 are `work-completed`, fence 1's measured scope is cleared, and the only remaining items are D1 and D5 — which §4 records as human-only. Building the runtime would require superseding the 2026-08-26 draft-only fence, i.e. taking D1 |
| **Arc focus** | Switched `continuous-run` → `ewcr-arc0-contract-evidence` (operator-authorised in-session). Previous *task* focus T-3363 is itself operator-blocked on its AC5 advisory, so nothing in flight was pre-empted |
| **Backlog reconciliation** | Arc tasks by `arc_id`: T-3147, T-3350, T-3351, T-3352. Broad grep adds T-3349 (drive) and T-3146 (832 triage, tangential). **No handover message exists**: no workflow/designer agent session on the TermLink hub, no EWCR topic, no EWCR channel, and the only EWCR inbox item (OBS-385) had already landed as T-3350. Every task's origin is this repo's own drives — none orphaned, none from a peer |
| **BVP** | `--quadrant hv-lc` and `hv-hc` both return empty: no task in the corpus has confirmed `bvp_scores:`. That is D2 (BVP confirmation, human-only) un-ruled, not a tooling failure — and is consistent with the arc-0 fence |
| **Human decisions needed** | D1 and D5 only — unchanged for the ninth day. `http://192.168.10.107:3002/review/T-3147` (verified 200) |
| **Next safe action** | Unchanged: operator rules D5 then D1. Until D1 GO there is no in-scope agent work; a third landing drive will reach this same row |

### 2026-09-18 — third landing drive (T-3384): D1 and D5 ruled, Arc 0 started

| Field | Value |
|-------|-------|
| **Source revision** | manifest v1, rev 0 — unchanged (`c9070637` / `5be23719`) |
| **D5 ruling (Q-03)** | **ACCEPTED as proposed** — Fabric coverage ≥95% AND 0 `Unknown` subsystem per CORE write-set root, `tests/` excluded. Ruled by the operator: `[REVIEW]` AC ticked on `/review/T-3147` at 2026-09-18 06:34:21 (`POST /api/task/T-3147/toggle-ac`, LAN host), direction confirmed in chat 2026-09-18 ("2 yes") after the agent declined to infer it from the tick |
| **D1 ruling** | **START** — Arc 0 authorised draft → in-progress. Same provenance: AC ticked 06:34:23, direction confirmed in chat 2026-09-18 ("1 yes start"). The 2026-08-26 draft-only fence is superseded for Arc 0 by this ruling; the arc YAML `description:` still quotes the old fence wording and needs an operator edit (arc-scope change, not taken by the agent) |
| **Arc transition** | `fw arc start ewcr-arc0-contract-evidence` executed by T-3384 as the mechanical act of the human decision (the verb carries no `$CLAUDECODE` refusal; the decision was the Sovereign act, now recorded above) |
| **Current arc / task** | arc-019 `ewcr-arc0-contract-evidence` (**in-progress**). Anchor T-3147: all Agent and Human ACs ticked, still in `active/` — finalisation (`--status work-completed`) is the human's |
| **Next safe action** | Groom Arc 0 for NEW SCOPE under the headline mechanic; landing loop begins under T-3384. D2/D3/D4/D6 remain un-ruled and blocking their respective arcs |

## 4. Human decisions required (blocking)

Owner: **dimitri@geelenandcompany.com**. None may be taken by an agent.

| ID | Decision | Blocks |
|---|---|---|
| D1 | Arc-start authorisation for a *draft* Arc 0 in AEF — **RULED 2026-09-18: START** (see §3) | All Arc 0 work |
| D2 | BVP confirmation (`fw bvp confirm`) — estimator proposals only exist today | BVP-based ranking |
| D3 | Q-04 — two-plane bypass model (task plane bypassable, runner plane not) | Arc 1 refusal design |
| D4 | Q-05 — disposition of the `--from-watchtower` direct-mutation pattern | Arc 4 projection/admission design |
| D5 | Q-03 — Component Fabric coverage threshold and limited-mode policy — **RULED 2026-09-18: ≥95% coverage, 0 Unknown per CORE root, `tests/` excluded** (see §3) | Arc 0 exit gate |
| D6 | Q-14 — runner isolation topology | Arc 2 (hard gate) |

## 5. Stop conditions

Stop and escalate — do not resolve by judgement:

- A received document's hash does not match **and** the transport is verified raw → `VERSION MISMATCH`, new manifest revision required.
- Any instruction to start an arc, confirm BVP, or bulk-create tasks without a recorded human decision.
- Any request to edit the Workflow Designer repository directly.
- Any proposal to let Designer UI, agents, TermLink delivery, model output, BVP rank, or editable state become execution or approval authority.
- Fabric coverage still failing fence 1 at Arc 0 exit.
- A peer handoff with transport evidence but no read-back and no substantive `accepted`/`refused`/`needs-decision` response.
- Secret **values** appearing anywhere — definitions, task files, Context Fabric, TermLink messages, prompts, logs, audit records. Opaque binding names only.
- Context budget above 85% → wrap-up only; update digest and handover, resume from governed state, never from memory.

## 6. Reporting rule

Report to the operator on: meaningful change · a decision need · a failed gate ·
an unresolved peer handoff · each arc boundary. Nothing else.
