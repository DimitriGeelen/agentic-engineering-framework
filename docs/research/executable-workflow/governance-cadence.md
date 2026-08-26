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

## 4. Human decisions required (blocking)

Owner: **dimitri@geelenandcompany.com**. None may be taken by an agent.

| ID | Decision | Blocks |
|---|---|---|
| D1 | Arc-start authorisation for a *draft* Arc 0 in AEF | All Arc 0 work |
| D2 | BVP confirmation (`fw bvp confirm`) — estimator proposals only exist today | BVP-based ranking |
| D3 | Q-04 — two-plane bypass model (task plane bypassable, runner plane not) | Arc 1 refusal design |
| D4 | Q-05 — disposition of the `--from-watchtower` direct-mutation pattern | Arc 4 projection/admission design |
| D5 | Q-03 — Component Fabric coverage threshold and limited-mode policy | Arc 0 exit gate |
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
