# T-4435 — Shared dispatched-worker contract (TermLink + AEF + ring20)

**Phase:** inception. **Decision owner:** the operator. **Status:** the operator asked for three independent reviews
before deciding (2026-10-19).

## 1. The proposal (from 010-termlink, msg 0673a051, 2026-10-19)

TermLink's operator ruled their T-3483 option C, with conditions. termlink now proposes **one shared contract for
dispatched agent workers, agreed three-way** (TermLink, AEF, ring20), based on ring20's arc-009 S-1 model:

1. **Record.** One durable per-dispatch record on the TermLink hub, keyed by a dispatch id with numbered attempts.
   Fencing is (dispatch id, attempt) plus a per-attempt nonce that the hand-back must echo. Old attempts are rejected
   (`fence_reject`).
2. **Lifecycle.** dispatched → running → done | lost.
   - `done` is written only by the supervisor (a single writer), from fenced evidence read after the worker has
     stopped. The worker never writes it.
   - `lost` is written only on a confirmed session end, never on a missed heartbeat.
3. **Result.** The result is a hash: a commit sha, or the sha256 of the hand-back. Review verdicts name that hash.
4. **Worker instruction and communication.**
   - The instruction carries a hand-back block: commission, attempt, nonce, status, summary, findings.
   - Status goes into the record.
   - Questions to the orchestrator go through the sidecar.
   - Answers go to the worker's own inbox, with an ack per command id.

**Proposed ownership:**
- **TermLink** builds the ledger primitive on the hub: `worker wait`, lookup, and a hub-written `lost` on a confirmed
  session end.
- **AEF** owns `run.sh` as the supervisor-writer for `fw termlink dispatch`, records the dispatcher in the dispatch,
  and owns the worker instruction.
- **ring20's** S-1 design is the base. ring20 checks that its supervisor can use the shared primitive instead of its
  own ledger.

**Left open on purpose by termlink:** the answer path for questions back to a worker (AEF, because of T-4423), record
retention, and a later sidecar notice layer.

**Questions put to AEF:**
1. Does AEF agree to own the run.sh writer, the dispatcher recording and the worker instruction?
2. Does this replace or absorb ring20's T-2281 offer? (That is ring20's task number; AEF's own T-2281 is unrelated.)
3. Anything in the split of ownership to change before the build task is written?

## 2. AEF context the reviewers need

- **Prior decision.** T-3977 is GO: take ring20's arc-009 orchestration into AEF piece by piece, not as one merge.
  T-3960 was AEF's stakeholder check of the S-1 contract v0.3. Its claim table verifies S-1's statements about AEF
  code. One finding is directly relevant here, **1c**: `update_outcome_row` (lib/spawn.py:218-272) is last-writer-wins
  with no fence, and matches only on dispatch_id.
- **How a dispatch finishes today.**
  - `fw termlink dispatch` (agents/termlink/termlink.sh) starts `claude -p` in a TermLink session, with a run.sh
    wrapper.
  - run.sh writes `exit_code` into the worker dir before it exits (T-4152). That makes completion durable on local
    disk; `fw termlink wait/status` read it.
  - run.sh also emits `termlink event emit <worker> worker.done`. That event lives on the worker's own session and
    dies with it.
  - Dispatches and outcomes are appended to `.context/dispatches.jsonl` and `.context/dispatch-outcomes.jsonl`.
- **Who the dispatcher is.** The dispatch records task, name and worker dir, but not the dispatching session. AEF's
  sidecar agent id is **per project** (one id for every session in the project), not per session.
- **Workers have no sidecar receiver.** T-4423 (2026-10-19): a dispatched worker (FW_DISPATCHED_WORKER=1) may not
  start, or persist, a sidecar receiver under its own id. The motivation was a worker's id leaking into the project's
  persisted receiver identity, which broke delivery for the whole project.
- **TermLink is optional for AEF users** (portability directive D4). Today, dispatch without TermLink falls back to
  other worker kinds.

## 3. Sidecar addressing and the retry ladder: how they tie in (operator question)

The proposal's communication split (questions via the sidecar; answers via the worker's own inbox) rests on two
sidecar mechanisms that AEF has been reworking:

- **Circuit addresses** (lib/sidecar/addressing.py, T-3855, T-4418).
  - A recipient lives at `inbox:<recipient hub id>/<agent>`.
  - A topic built in the wrong namespace, or a nickname address nobody reads, was reported "delivered" while nobody
    read it: 87 messages in one case, 14 consults in another.
  - T-4418 (2026-10-19) now refuses a send to an explicit circuit that nothing reads, and WARNs on unread orphan
    inboxes.
- **The universal retry ladder** (lib/retry_ladder.py, D-600, T-3434).
  - 16 attempts over 8 rungs, doubling from 1 minute to 1 month, about 76 days in all.
  - It escalates to a nudge, then to the operator, then dead-letters.
  - One schedule covers every message kind: consults, pickups, dispatch results.
- **Direct path and hub fallback** (lib/sidecar/direct.py). A receiver-to-receiver send runs through the states SENT →
  RECEIVED → HANDED_OVER → REPLIED. When the receiver is down, the send falls back to the hub inbox, which is driven
  by the ladder.

**Why this matters for the contract:**
- A worker lives minutes to an hour, has no receiver (T-4423), and has no stable circuit.
- An answer sent to "the worker's own inbox" therefore needs an address the worker actually polls while it runs.
  Otherwise it becomes exactly the orphan-inbox class T-4418 just closed.
- The ladder's later rungs (hours to a month) outlive every worker, so an undelivered answer to a worker should
  dead-letter or reroute to the supervisor quickly, not ride the ladder for 76 days.
- The dispatcher's circuit (where a worker's question goes) is the per-project agent, not a session (condition 1
  below).

## 4. AEF's draft position (to be reviewed)

**Draft recommendation:** yes, AEF owns the three pieces, with four conditions written into the build task:

1. **Record the dispatching session, not only the project.** The sidecar id is per project, so a project-level
   "dispatcher" cannot tell two parent sessions apart.
2. **Answers to a worker travel through the fenced record, not a worker receiver.** The worker polls its own record
   (keyed by dispatch id and attempt), which keeps T-4423 intact and gives answers the same fencing as status.
3. **A local-file fallback with the same record shape when there is no TermLink hub** (D4 portability).
4. **The shared record replaces AEF's last-writer-wins outcome writing** (T-3960 finding 1c) rather than running
   beside it: one source of truth.

## 5. Questions for the reviewers

Answer each, with file:line or design-level evidence where you can. Under 1,200 words in total.

1. Is the contract sound? Look in particular at:
   - the single-writer `done`;
   - the fencing (dispatch id, attempt, nonce);
   - `lost` only on a confirmed session end.

   Name any race, split-brain or stuck state it leaves open.
2. Is the ownership split right? Should AEF own the run.sh supervisor-writer, the dispatcher recording and the worker
   instruction, or should something move to TermLink or ring20?
3. Are AEF's four conditions right, missing something, or overreaching?
4. How should the answer path to a running worker work, given:
   - no worker receiver (T-4423);
   - circuit addressing, and the orphan-inbox failure class;
   - a retry ladder whose rungs outlive any worker?
5. What is the biggest risk of agreeing now, and what would you want settled first?
6. Overall: agree, agree with conditions (which), or not yet (why)?

## 6. Reviews

Three independent reviewers, three vendors, all internal backends (cost logged, unmetered):

- codex (OpenAI): `docs/reports/T-4435-reviews/codex.md`
- opencode (Z.ai): `docs/reports/T-4435-reviews/opencode.md`
- claude (Anthropic, a fresh `claude -p` with no session context): `docs/reports/T-4435-reviews/claude.md`

Synthesis: to follow.

## Dialogue log

- **2026-10-19.** termlink's formal question arrived. The agent drafted "yes, with four conditions".
- **Operator:** "Maybe we get three reviews on this." → this inception task and the three reviews.
- **Operator:** "we've talked a lot about agent circuit addresses and the fallback ladder; does this also tie into
  this?" → yes. See §3, now reviewer question 4.
