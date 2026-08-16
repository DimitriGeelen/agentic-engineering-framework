---
id: T-3044
name: "Structural message triage — hub messages and observations to typed tasks"
description: >
  Inception: Structural message triage — hub messages and observations to typed tasks

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-08-16T18:09:29Z
last_update: 2026-08-16T19:43:37Z
date_finished: 2026-08-16T19:43:37Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-08-16T18:11:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-16T18:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 7
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3044: Structural message triage — hub messages and observations to typed tasks

## Problem Statement

There is no pipeline from message to task. 35,125 messages were recovered from two ring20
hubs plus the local hub, 15 more from a silently-stalled outbound queue, and 181
observations sit pending (19 urgent). Roughly 13 messages have been read — by hand, by
grep, by whoever happened to be looking.

The proof that this is structural rather than a backlog: a fully-formed bug report with
reproduction evidence and three costed fix options
(`PICKUP-ring20-mgmt-20260517-203835-cred-gate-watchtower-split`) arrived 2026-05-17 and
was first read 2026-08-16 — three months later, incidentally, while grepping for something
else. It describes the same credential-gate flow that blocked this session (OBS-299).

Every stage of a pipeline exists as a component (`fw pickup process`, `fw note triage`,
`fw bus`, `fw peer subscribe`). No stage is connected to the one before it. The corpus is
a lake with an inlet and no outlet.

Research artifact: `docs/reports/T-3044-message-triage-inception.md`

## Assumptions

- **A1: The classification problem is tractable, not open-ended.** Census shows 79%
  (27,789) is telemetry that should never reach a human, ~12% (~4,100) is unstructured
  `chat`/`note`/`reflection` judgement load, and ~12 messages are *already typed and
  self-describing* (`handoff`, `framework-pickup`, `request`, `prod-deploy-approval`).
  The actionable subset needs routing, not intelligence. **Tested:** `msg_type` census over
  273 archive files — see artifact §1.

- **A2: A silent-drop pipeline would be worse than today.** Today an unread message still
  sits in a greppable pile, which is exactly how the cred-gate pickup was eventually found.
  A stage-② classifier that discards without a queryable record removes that last property.
  **Not yet tested** — this is IW-2 and is a design constraint on slice 1, not a metric.

- **A3: The framework does not own ingest.** T-3041 IW-3's write-site inventory scanned
  `lib/ agents/ bin/ web/` and found no in-repo writer for `.context/message-archive/**`,
  yet the files change actively. **Tested by absence** — IW-1 must resolve who does.

## Open Questions

- **IW-1: Who writes `.context/message-archive/**`, and should the framework own
  ingest itself?**
  confidence: 1
  disposition: deferred
  rationale: Gates slice-1 BUILD, not this decision — the routing table is
    correct whoever owns ingest. Deferred to the slice-1 design task, which
    cannot start until it is answered. Evidence of the gap
    docs/reports/T-3041-write-site-inventory.md (no in-repo writer found).
  <!-- T-3041 IW-3's inventory scanned lib/, agents/, bin/, web/ and found NO
       in-repo writer, yet the files change actively. Until ingest is owned,
       stages 2-4 are built on a producer nobody can point at. Gates the design:
       if the framework owns ingest it can set the cursor contract; if not, it is
       a consumer of someone else's at-least-once/at-most-once semantics. -->

- **IW-2: What false-drop rate is acceptable, and how is a wrong drop discovered?**
  confidence: 1
  disposition: answered
  rationale: Answered as a DESIGN CONSTRAINT rather than a rate — target is
    zero silent drops. Every non-routed message is recorded with a reason and
    stays queryable; nothing is deleted. A drop is discovered by querying the
    drop log. If that cannot be built, stage 2 does not ship (artifact §5).
  <!-- The failure that matters. A pipeline that silently discards a real bug
       report is WORSE than today, because today the message at least sits in a
       pile someone can grep — which is literally how the 3-month-old
       cred-gate pickup was found. Same false-green class as OBS-302 (a failed
       RPC rendered as an empty result). Design constraint, not a metric to
       optimise later: every drop must be recorded with a rationale and be
       queryable, or the stage should not ship. -->

- **IW-3: Does triage dedupe against existing tasks/concerns, and how?**
  confidence: 1
  disposition: deferred
  rationale: Deferred to slice-1 design. At ~12 messages the dedupe can be a
    human eyeball, so it does not block slice 1 — but it hard-blocks any later
    slice touching the ~4,100 unstructured band. Recorded so that slice cannot
    start without answering it. Worked instance the greenfield agent's
    DISCOVERY 1 duplicates T-3043's defect class.
  <!-- 176 pending observations already contain repeats; the recovered corpus
       contains messages describing defects we have since filed independently
       (the greenfield agent's DISCOVERY 1 is T-3043's defect class). Without
       dedupe the pipeline manufactures duplicate tasks faster than a human can
       close them, converting a backlog of messages into a backlog of tasks —
       no progress, more noise. -->

- **IW-4: Where does the ~4,100 `chat`/`note` judgement load run?**
  confidence: 2
  disposition: deferred
  rationale: Explicitly fenced OUT of slice 1 (Scope Fence) and off the
    critical path — slice 1 delivers value without touching the band. Deferred
    to a separate inception once slice 1 has produced real routing data.
    "Never — leave them searchable" remains a live candidate and is cheapest.
  <!-- Explicitly OUT of slice 1, but the answer shapes the seam. Candidates:
       local ollama batch (cost 0, quality unproven for this task), dispatched
       TermLink workers (measured 30-83% verification pass by workflow_type), or
       never — leave unstructured messages searchable and act only on typed ones.
       The last option is genuinely on the table and would be cheapest. -->

- **IW-5: Does stage 4 respect the T-3041 converging write-set, or fight it?**
  confidence: 3
  disposition: answered
  rationale: Respects it. Stage 4 is serial by construction — recorded in
    Technical Constraints as a hard requirement, not a preference. Rule
    CLAUDE.md §Execution Model item 4; measurement
    docs/reports/T-3041-write-site-inventory.md (27 dangerous sites, .tasks/
    and .context/inbox.yaml both in it); live instance T-3042.
  <!-- Filing writes .tasks/ and .context/inbox.yaml — both in the dangerous set
       T-3041 IW-3 measured (27 sites, shared read-modify-write). CLAUDE.md's
       worked example for observation triage is this exact case: workers analyse
       in parallel, the parent integrates serially. Confidence 3 because the rule
       already exists and is measured; recorded so slice 1 cannot quietly
       parallelise the write leg. -->


<!-- T-2190 (T-2186 Slice 4): every IW-N question must be disposed before
     --status work-completed. Disposition gate (agents/task-create/update-task.sh
     check_disposition_gate) refuses on under-disposed inceptions.

     Per-question shape:

       - **IW-1: <question text>**
         confidence: 0-3      (your confidence in your current answer; 0=guess, 3=verified)
         disposition: answered | deferred | dissolved
         rationale: <one-line evidence — file:line, decision id, dialogue ref>

     Never bare yes/no — the gate refuses bare checkboxes. See 050-Inceptions.md
     §Disposition Gate. Bypass: --skip-disposition-gate "rationale" (direct) or
     FW_SKIP_DISPOSITION_GATE=1 (env-var, T-1890 producer/consumer parity).
-->

## Exploration Plan

| Spike | Question | Time-box | Status |
|---|---|---|---|
| S1 | `msg_type` census over the recovered corpus — is the actionable subset bounded? | 30 min | **done** — 273 files, 16 types, ~12 actionable (artifact §1) |
| S2 | Component inventory — what already exists and why does it not fire? | 20 min | **done** — 6 components, all unwired (artifact §2) |
| S3 | Evidence of real cost — find one message whose non-processing cost something | 15 min | **done** — cred-gate pickup, 3 months, cost paid this session |
| S4 | Ingest ownership — who writes `.context/message-archive/**`? | — | **deferred to IW-1**; T-3041 IW-3's scan found no in-repo writer |
| S5 | Unstructured-band grinding (ollama vs dispatch vs never) | — | **deferred to IW-4**; explicitly out of slice 1 |

S1–S3 were sufficient to reach a recommendation. S4 gates build, not the decision. S5 is
a later slice and deliberately not on the critical path.

## Technical Constraints

- **Converging write-set.** Stage ④ writes `.tasks/` and `.context/inbox.yaml`, both in the
  27-site dangerous shared-RMW set measured by T-3041 IW-3. Fan out on reads, fan in
  serially on writes (CLAUDE.md §Execution Model item 4). This is a hard constraint, not a
  preference — T-3042 is a live instance of the class it prevents.
- **At-least-once ingest.** Any cursor must be idempotent on message id; the hub gives no
  exactly-once guarantee and the outbound queue has already demonstrated silent stalls
  (`attempts=0` on 15 messages, permanent auth failure treated as transient).
- **No hub restart.** `/var/lib/termlink/hub.secret` is absent; T-933 persist-if-present
  would mint a new secret and break every fleet credential. Any ingest design must work
  against the running hubs as-is.
- **Volume.** ~14 MB / 35k messages today, growing. Stage ① must not load the corpus into
  an agent context — this is the T-073 explosion class.

## Scope Fence

**IN (this inception):**
- Whether a structural message→task pipeline is warranted, and what its stages are.
- Sizing the classification problem (census).
- Naming the first build slice narrowly enough to be reversible.

**IN (slice 1, if GO):**
- Static `msg_type` routing table for the ~12 already-typed messages.
- Recorded, queryable drops for everything not routed. Nothing deleted.
- Serial stage-④ writer.

**OUT (explicitly):**
- The ~4,100 unstructured `chat`/`note`/`reflection` messages. Left searchable, untouched.
- Any LLM or embedding-based classifier. Slice 1 is a lookup table.
- Auto-filing tasks without human review for `handoff` / `request` /
  `prod-deploy-approval` — those surface to `/approvals`.
- Re-architecting hub transport or ingest ownership (that is IW-1's answer, then its own task).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- The actionable subset of the corpus is **bounded and enumerable** — i.e. a first slice
  exists that needs routing rather than classification. *(Met: ~12 typed messages, artifact §1.)*
- The machinery already exists and the gap is **wiring**, not new subsystems.
  *(Met: 6 components inventoried, all present, none connected — artifact §2.)*
- At least one **concrete, dated cost** of the current non-process can be cited.
  *(Met: cred-gate pickup, 2026-05-17 → 2026-08-16, cost paid in this session.)*
- Slice 1 is **additive and reversible** — no existing behaviour changes, nothing deleted.

**NO-GO if:**
- The only viable first slice requires grinding the ~4,100 unstructured messages
  (i.e. needs a classifier before it produces any value). *(Not met — slice 1 avoids the band entirely.)*
- Stage ④ cannot be made serial, forcing parallel writes into the T-3041 dangerous set.
  *(Not met — serial writer is a stated constraint, IW-5 confidence 3.)*
- A drop-recording design cannot be specified, so the pipeline would be strictly worse than
  the greppable pile it replaces. *(Not met — recorded/queryable drops are a slice-1 gate, IW-2.)*

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

35,125 recovered messages, 176 pending observations, and a framework-pickup bug report unprocessed for 3 months prove there is no pipeline from message to task. The machinery (fw pickup process, fw note triage, fw bus) exists but nothing routes to it. Census shows 79% is telemetry that should never reach a human and ~12 messages are typed and directly actionable, so the classification problem is tractable rather than open-ended.

**Evidence:**

- **Research artifact:** `docs/reports/T-3044-message-triage-inception.md` (census, component
  inventory, 4-stage pipeline, IW-1..IW-5, evidence index).
- **Census (S1):** 273 archive files, ~14 MB, 16 `msg_type` values. 27,789 telemetry (79%),
  ~4,100 unstructured (12%), **~12 typed and directly actionable** —
  `handoff` (3), `framework-pickup` (2), `request` (2), `prod-deploy-approval` (2),
  `probe-shipped` (3). The actionable band needs a lookup table, not a model.
- **Dated cost (S3):** `PICKUP-ring20-mgmt-20260517-203835-cred-gate-watchtower-split` —
  filed 2026-05-17 with reproduction evidence and three costed fix options; first read
  2026-08-16 while grepping for something else. Same credential-gate flow that blocked this
  session (OBS-299). Three months, one incidental discovery.
- **Component inventory (S2):** `fw pickup process`, `fw note triage`, `fw bus`,
  `fw peer subscribe`, `.context/message-archive/**`, G-020/P-002 gates — all present, none
  wired to the stage before it.
- **Backlog scale:** 35,125 recovered messages (commit `090178319`); 15 outbound messages
  with `attempts=0` (`.context/message-archive/outbound-queue-20260816/decoded.json`);
  181 pending observations, 19 urgent (handover S-2026-0816-2013).
- **Write-set constraint:** 27 dangerous shared-RMW sites measured in
  `docs/reports/T-3041-write-site-inventory.md`; `.tasks/` and `.context/inbox.yaml` are both
  in it. T-3042 is a live instance of the loss class.
- **False-green precedent for IW-2:** OBS-302 / `docs/reports/T-3043-termlink-nonroot-rca.md`
  §4.3 — a failed RPC rendered as an empty result, indistinguishable from success. A silent
  classifier drop is the same shape.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: 35,125 recovered messages, 176 pending observations, and a framework-pickup bug report unprocessed for 3 months prove there is no pipeline from message to task. The machinery (fw pickup process, fw note triage, fw bus) exists but nothing routes to it. Census shows 79% is telemetry that should never reach a human and ~12 messages are typed and directly actionable, so the classification problem is tractable rather than open-ended.

**Date**: 2026-08-16T19:43:36Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-16T18:11:29Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-16T19:43:36Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 35,125 recovered messages, 176 pending observations, and a framework-pickup bug report unprocessed for 3 months prove there is no pipeline from message to task. The machinery (fw pickup process, fw note triage, fw bus) exists but nothing routes to it. Census shows 79% is telemetry that should never reach a human and ~12 messages are typed and directly actionable, so the classification problem is tractable rather than open-ended.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-8ae8f45b
- **Timestamp:** 2026-08-16T19:43:38Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **disposition-incomplete** (partial, heuristic) @ ## Open Questions: IW-2
     - evidence: `IW-2 disposition='answered' but rationale has no evidence citation (T-NNNN, file:line, docs/reports/, G-/L-/D-id, dialogue-log, or commit hash)`

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-a351daf5
- **Timestamp:** 2026-08-16T19:43:38Z
- **Overall:** CONFIRMED
- **Claims:** 8

| Claim | Type | Status |
|-------|------|--------|
| `docs/reports/T-3044-message-triage-inception.md` | file | ✓ pass |
| `.context/message-archive/outbound-queue-20260816/decoded.json` | file | ✓ pass |
| `docs/reports/T-3041-write-site-inventory.md` | file | ✓ pass |
| `.context/inbox.yaml` | file | ✓ pass |
| `docs/reports/T-3043-termlink-nonroot-rca.md` | file | ✓ pass |
| `T-3041` | task | ✓ pass |
| `T-3042` | task | ✓ pass |
| `T-3043` | task | ✓ pass |

### 2026-08-16T19:43:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
