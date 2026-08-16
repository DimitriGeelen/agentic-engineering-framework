# T-3044 — Structural message triage: hub messages and observations to typed tasks

**Task:** T-3044 (inception)
**Date:** 2026-08-16
**Status:** exploration complete, recommendation GO
**Origin question (operator, verbatim):** *"what are we doing to struturally process all emssages, evelaute them, ccreate build, bug fix or inception tasks form it, in a methiondical, relisable, procedural way?"*

---

## 0. The honest answer

**Nothing structural. There is no pipeline.**

Over the preceding two sessions the framework recovered **35,125 messages** from two ring20
hubs plus the local hub, and **15 more** from a silently-stalled outbound queue. I then
hand-read roughly **13 of them** — the ones that happened to be near the top of a `jq`
output, or that a grep for a keyword I already had in mind surfaced.

That is not a process. That is me picking.

The evidence that it is not a process is not an argument, it is a date: a fully-formed bug
report with reproduction evidence and three costed fix options
(`PICKUP-ring20-mgmt-20260517-203835-cred-gate-watchtower-split`) arrived on **2026-05-17**
and was read for the first time **today, 2026-08-16** — three months later — and only
because I was grepping the archive for something else. It describes the same credential-gate
flow that blocked this very session (the Infisical 403 → `fw-authority` dead end, OBS-299).

Reading it in May would have saved today's detour. Nothing read it, because nothing reads.

---

## 1. Census — what is actually in the corpus

`msg_type` distribution across `.context/message-archive/*.json` (273 files, ~14 MB):

| `msg_type` | Count | Class |
|---|---:|---|
| `dashboard.health-state` | 13,298 | telemetry |
| `heartbeat` | 9,687 | telemetry |
| `dashboard.startup` | 4,794 | telemetry |
| `chat` | 2,613 | **unstructured signal** |
| `note` | 981 | **unstructured signal** |
| `reflection.envelope.v1` | 537 | **unstructured signal** |
| `file.*` | 255 | payload |
| `receipt` | 49 | telemetry |
| `dashboard.ping` | 10 | telemetry |
| `test.deployment` | 9 | typed |
| `topic_metadata` | 6 | metadata |
| `handoff` | 3 | **typed, actionable** |
| `probe-shipped` | 3 | typed |
| `framework-pickup` | 2 | **typed, actionable** |
| `request` | 2 | **typed, actionable** |
| `prod-deploy-approval` | 2 | **typed, actionable** |

Three bands, and the shape of the problem is in the ratio:

- **27,789 (79%) telemetry.** Should never reach a human, and today does not — but only
  because nothing reaches a human at all. A pipeline that routes everything would drown.
- **~4,100 (12%) unstructured signal** — `chat`, `note`, `reflection`. Genuine judgement
  load. This is the expensive band and the reason "just process all messages" is not a plan.
- **~12 typed and directly actionable** — `handoff`, `framework-pickup`, `request`,
  `prod-deploy-approval`. **Twelve.** Every one of them is already self-describing: the
  sender declared the type, the intent, and usually the evidence.

The last row is the finding. The subset that needs no classifier, no LLM, no judgement — just
routing — is twelve messages. And the three-month-old bug report is one of them.

---

## 2. What already exists (and why it doesn't fire)

The framework is not missing machinery. It is missing wiring.

| Component | What it does | Why it doesn't close the loop |
|---|---|---|
| `fw pickup process` | Parses a `framework-pickup` envelope into a proposal | Must be invoked by hand; nothing calls it on arrival |
| `fw note triage` | Walks `.context/inbox.yaml` observations | **181 pending, 19 urgent** — invoked when a human remembers |
| `fw bus post/manifest` | Typed result envelopes with size gating | Dispatch-side only; hub messages never enter the bus |
| `.context/message-archive/**` | Holds the corpus | **No in-repo writer** (see IW-1) — files change, nothing here writes them |
| `fw peer subscribe` | Long-polls `inbox.queued`, spawns responders | Responder path, not a triage path |
| G-020 / P-002 gates | Refuse ungoverned build work | Correctly refuse — but only once someone has *decided* to file a task |

Every stage of a pipeline exists as a component. No stage is connected to the one before it.
The corpus is a lake with an inlet and no outlet.

---

## 3. Proposed pipeline (four stages)

```
        ┌──────────┐   ┌───────────┐   ┌──────────┐   ┌────────┐
hubs ──▶│ ① ingest │──▶│ ② classify│──▶│ ③ triage │──▶│ ④ file │──▶ .tasks/ + inbox.yaml
        └──────────┘   └───────────┘   └──────────┘   └────────┘
         cursor +       msg_type        dedupe vs      serial
         at-least-once  routing table   open work      writer
```

**① ingest** — durable cursor per (hub, topic). At-least-once, idempotent on message id.
Owned by the framework, or explicitly declared a consumer of someone else's semantics —
that choice is IW-1 and it gates everything downstream.

**② classify** — for slice 1 this is a **static routing table on `msg_type`**, not a model.
Telemetry → drop (recorded). Typed → route. Unstructured → park, searchable, untouched.

**③ triage** — dedupe against open tasks and `concerns.yaml` before proposing anything.
Without this the pipeline converts a message backlog into a task backlog, which is not
progress (IW-3).

**④ file** — `fw work-on` / `fw note` / `concerns.yaml`. **Serial by construction.**
`.tasks/` and `.context/inbox.yaml` are both in the 27-site dangerous write set T-3041 IW-3
measured. Workers analyse in parallel; the parent integrates one at a time (IW-5).

---

## 4. Open questions (IW-1..IW-5)

Filed in the task frontmatter body; summarised here with why each one gates design.

| ID | Question | Conf | Why it gates |
|---|---|---:|---|
| IW-1 | Who writes `.context/message-archive/**`? Should the framework own ingest? | 1 | T-3041 IW-3 scanned `lib/ agents/ bin/ web/` and found **no in-repo writer**, yet the files change actively. Stages ②–④ would be built on a producer nobody can point at. |
| IW-2 | What false-drop rate is acceptable, and how is a wrong drop discovered? | 1 | **The failure that matters.** A pipeline that silently discards a real bug report is *worse than today* — today the message sits in a pile someone can grep, which is literally how the cred-gate pickup was found. Same false-green class as OBS-302. |
| IW-3 | Does triage dedupe against existing tasks/concerns, and how? | 1 | 181 pending observations already repeat; the recovered corpus contains defects we have since filed independently (the greenfield agent's DISCOVERY 1 *is* T-3043's defect class). |
| IW-4 | Where does the ~4,100 `chat`/`note` judgement load run? | 2 | Out of slice 1, but shapes the seam. Candidates: local ollama batch (cost 0, quality unproven), dispatched TermLink workers (measured 30–83% verification pass by workflow_type), or **never** — leave unstructured searchable and act only on typed. The last is genuinely on the table and is cheapest. |
| IW-5 | Does stage ④ respect the T-3041 converging write-set, or fight it? | 3 | Rule already exists and is measured. Recorded so slice 1 cannot quietly parallelise the write leg. |

**IW-2 is the design constraint, not a metric to tune later.** Every drop must be recorded
with a rationale and be queryable, or stage ② should not ship.

---

## 5. Recommendation

**GO** — with a deliberately narrow first slice.

**Slice 1: route the ~12 already-typed, already-actionable messages.**

- No classifier. No model. A static `msg_type` → handler table.
- `framework-pickup` → `fw pickup process` (exists, unwired).
- `handoff` / `request` / `prod-deploy-approval` → surface to `/approvals`, do not auto-file.
- Everything else → recorded as dropped with reason, queryable. Nothing deleted.
- Serial writer for stage ④.

**Why this slice:** it is the smallest change that would have caught the three-month-old bug
report **on the day it arrived**, and it needs none of the expensive machinery. It also
forces IW-1 to be answered (you cannot build a cursor over a producer you cannot name)
without betting anything on IW-4.

**Explicitly out of slice 1:** the ~4,100 unstructured messages. Leave them searchable.
Deciding *how* to grind them is IW-4 and does not block slice 1.

**GO criteria met:**
- Root cause identified with bounded fix path — yes: components exist, wiring does not.
- Fix is scoped, testable, reversible — yes: a routing table over 12 messages, additive only.

**NO-GO criteria not met:**
- No fundamental redesign required; slice 1 touches no existing behaviour.
- Cost is bounded well under benefit: one three-month-old missed bug report already exceeds it.

---

## 6. Evidence index

| Claim | Source |
|---|---|
| 35,125 recovered messages | commit `090178319`, `.context/message-archive/` |
| 15 silently-queued outbound messages, `attempts=0` | `.context/message-archive/outbound-queue-20260816/decoded.json` |
| Census figures | `jq` over `.context/message-archive/*.json`, §1 above |
| 3-month-old unprocessed bug report | `PICKUP-ring20-mgmt-20260517-203835-cred-gate-watchtower-split` (dated 2026-05-17) |
| 181 pending observations, 19 urgent | `bin/fw handover` output, session S-2026-0816-2013 |
| 27 dangerous shared-RMW write sites | `docs/reports/T-3041-write-site-inventory.md` |
| No in-repo writer for message-archive | `docs/reports/T-3041-write-site-inventory.md`, IW-3 scan |
| Dispatch pass rates by workflow_type | CLAUDE.md §Execution Model, joined from `.context/dispatches.jsonl` |
| False-green class precedent | OBS-302, `docs/reports/T-3043-termlink-nonroot-rca.md` §4.3 |
