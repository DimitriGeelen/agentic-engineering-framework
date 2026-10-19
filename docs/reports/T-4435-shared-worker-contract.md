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
- opencode (Z.ai): `docs/reports/T-4435-reviews/opencode.md`, an isolated re-run (see the process note below)
- claude (Anthropic, a fresh `claude -p` with no tools and no session context): `docs/reports/T-4435-reviews/claude.md`

**Process note: the first opencode seat was not independent.** It ran with file and shell tools on, from a directory
inside the repo. Before writing, it:

- listed ~900 active task filenames;
- read ~20 lines of lib/spawn.py and grepped termlink.sh;
- read the first 5 lines of the codex and claude reviews.

No IP address or internal hostname was in anything it read; this was checked line by line against its own tool log.
The run is kept, labelled, as `opencode-contaminated.md`, and it is not counted. It was re-run from a directory
outside the repo with every tool disabled; that re-run is the counted seat. Follow-up: reviewer runs should default to
outside-repo and tools-off (T-4437).

### 6.1 Verdicts

| Seat | Verdict | Headline |
|---|---|---|
| codex | agree with conditions (direction); **not yet as a build spec** | Terminal-state arbitration, supervisor recovery and how a running agent actually *consumes* an answer are unresolved. Biggest risk: agreeing on a record format while three implementations give its transitions different meanings |
| claude | agree with conditions | "Single writer" is not enough. There are two terminal writers by design (supervisor `done`, hub `lost`), so the safety comes from CAS and a precedence rule. Narrow condition 4. Shadow-mode before switching over |
| opencode | agree with conditions ("not 'not yet': spec holes in a sound design") | Fenced `done` must outrank `lost` with a late-evidence upgrade. Answer TTL must be no longer than the worker's lifetime, then bounce to the dispatcher, never ride the ladder. The hand-back schema is contract surface |

**Nobody said no, and nobody said yes as drafted.**

### 6.2 Where all three converge (each found it independently)

1. **`done` and `lost` race, and the draft has no precedence rule.**
   - The race: run.sh writes its local `exit_code`, the session ends before the hub `done` lands, and the hub writes `lost`.
   - Required: every transition is a compare-and-swap from an expected prior state, and fenced completion evidence
     outranks `lost`, with an idempotent `lost → done` upgrade. This is the rank-not-recency rule `direct.py` already
     uses (HANDED_OVER outranks ESCALATED).
   - Without it, T-3960's last-writer-wins (finding 1c) simply moves to the hub.
2. **"`lost` only on confirmed session end" leaves `running` stuck forever** when confirmation is impossible: hub
   restart, a partition, a zombie session. T-4152's 37 workers blocked in `n_tty_read` are proof the class exists.
   Required: a bounded, operator-visible `unknown`/`stale` state with a resolution verb. It is not a heartbeat-driven
   `lost`.
3. **Fencing protects the record, not the world.**
   - Attempts and nonces must be **allocated by the hub, atomically**, and the nonce is checked in the same atomic step
     as the write.
   - **No new attempt starts before the previous one is terminal**, because workers share the main checkout and a stale
     attempt's commits stay in the repo.
   - The result hash is bound to its attempt.
4. **Condition 2 (answers through the record) is right**, and the worker-addressed answer path must not use the retry
   ladder:
   - Answers live in a per-attempt section of the record that the lifecycle ignores. The worker acks by writing a
     read-marker under the same fence.
   - An answer's TTL is at most the attempt's remaining life. It then **bounces** to the dispatcher (a circuit that is
     read) or dead-letters by dispatch id; it never escalates.
   - No inbox topic is ever created for a worker, so the orphan-inbox class (T-4418) is excluded by construction and
     T-4423 stays intact.
5. **Condition 3 (local fallback) needs the same semantics, not only the same shape.**
   - It needs the same CAS (flock plus expected-state check) and a local `lost` source, because the local path has no
     hub.
   - The two backends must pass **one shared conformance test suite**.
   - The authoritative backend is chosen at dispatch time and never switched mid-flight, which would be split-brain.
6. **Condition 1 (record the dispatching session) is necessary but not sufficient.** Name the identifier: the Claude
   session id changes on `claude -c` and on compaction; the TermLink `claude-master-<PID>` persists. Recording it is
   audit, not routing. Questions from a worker still need a route to that session.
7. **`done` means "stopped", not "succeeded".** It needs an outcome field: succeeded / failed / refused / hand-back
   malformed. run.sh exits 0 even when the worker's exit code is non-zero.

### 6.3 Where they differ: condition 4 ("replace, not beside")

- **opencode:** replace, and migrate every consumer (`record-outcome` route learning, dispatch-outcomes readers).
- **codex:** the record holds the authority, while the existing JSONL may stay as *derived* audit projections that no
  longer decide outcomes.
- **claude:** narrow it. The record replaces the *completion* writer only. The *evaluation* ledger
  (dispatch-outcomes.jsonl, backprop at task close, the data behind the dispatch pass-rate table) is a different fact
  with a different writer and stays separate. Run the shared record **in shadow mode beside** `update_outcome_row`
  and switch over only when the two agree on real dispatches.

**Resolution (agent):** the three positions reconcile.

- The record is the single **completion authority**.
- The evaluation ledger stays a separate append-only fact, keyed by (dispatch id, attempt, result hash).
- The old completion writer becomes a derived projection, then is removed.
- Switch-over happens after a shadow period, not on day one.

### 6.4 Additions (raised by one seat, uncontested)

- **Session ↔ (dispatch id, attempt) binding at spawn** (claude). Today a TermLink worker's session name is a random
  `tl-<8>` (T-3960 1b), so the hub could not know which record to mark `lost`. AEF passes the binding and TermLink
  persists it.
- **The hand-back schema and the hash rules are contract surface** (opencode), specified three-way and validated by the
  hub, not just written by AEF's template.
- **Answer consumption must be demonstrated** (codex). A prompt saying "poll" does not show that a running `claude -p`
  takes in an answer. claude's practical default: **pause and re-dispatch**, with the answer riding in attempt N+1's
  instruction (the existing T-1809 pause mechanism). In-run polling is the fast path.
- **Preserve `retry_of_dispatch_id` semantics** (claude, opencode; T-3960 2a), or the pause queue silently deflates.
- **A contract version field. Retention is not optional**, because rejecting old attempts requires keeping them.
- **pi/ollama workers never touch the hub**; they must reach the same truth through the local backend, or the ledger
  forks by worker kind.
- **[ring20] conforms through the shared test vectors** rather than being a third free implementation (claude).
  ring20's T-2281 scope must be mapped against this contract before anyone says it is "replaced" (codex).

### 6.5 What this means for the decision

The question asked of AEF ("own the run.sh writer, the dispatcher recording and the worker instruction?") is answered
yes by all three seats. They agree just as clearly that the **contract is not build-ready**: its transition semantics
are the part that decides correctness, and they are unspecified. So the GO is for ownership plus a spec-first first
slice, not for code.

**Recommended answer to termlink:** AEF agrees to own the three pieces (plus the reconciler from local evidence, and the
session ↔ dispatch binding at spawn), on these conditions:

1. **First deliverable: a jointly agreed transition table.**
   - Contents: states; writer per transition; expected prior state (CAS); precedence (fenced `done` > `lost`);
     a bounded `unknown` with a resolution verb; hub-allocated attempts and nonces; no overlapping attempts; an outcome
     field on `done`.
   - Plus a shared conformance suite that both the hub backend and the AEF local backend must pass.
   - **No implementation before that.**
2. **Answers are per-attempt record entries**, acked by a fenced read-marker, with TTL at most the attempt's life,
   then bounce to the dispatcher. Never the retry ladder, never a worker inbox. Default to pause-and-redispatch until
   in-run consumption is demonstrated.
3. **The local backend has the same CAS semantics**, is chosen at dispatch time, and passes the same conformance
   suite.
4. **The record replaces the completion authority only.** The evaluation ledger stays separate. Shadow mode before
   switch-over.
5. **The dispatcher identity is a named, durable session id**, bound to the dispatch at spawn.
6. **ring20 maps T-2281 against the contract** before it is declared absorbed.

## Dialogue log

- **2026-10-19.** termlink's formal question arrived. The agent drafted "yes, with four conditions".
- **Operator:** "Maybe we get three reviews on this." → this inception task and the three reviews.
- **Operator:** "we've talked a lot about agent circuit addresses and the fallback ladder; does this also tie into
  this?" → yes. See §3, now reviewer question 4.
- **2026-10-20.** Three reviews in. The first opencode seat was found non-independent and was re-run isolated (see
  §6). All three seats: agree with conditions. Synthesis in §6; recommendation GO (ownership plus a spec-first first
  slice).
