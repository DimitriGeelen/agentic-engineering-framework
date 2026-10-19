# OpenAI codex — 2026-10-20 — review of T-4435 bundle

**Overall: agree with conditions to the direction; not yet to the contract as a build specification.** AEF’s four conditions are useful, but they do not resolve terminal-state arbitration, supervisor recovery, or how answers actually reach a running agent. Evidence below is from the supplied excerpts.

1. **Is the contract sound?**

   Single-writer `done` is a good constraint, but naming `run.sh` does not establish exclusive authority after crashes or restarts. Two supervisor instances could hold the same attempt nonce. The hub must enforce an authorized supervisor generation and atomic expected-state transitions; worker fencing alone does not fence supervisors.

   The principal race is **hub-written `lost` versus supervisor-written `done`**. A session can end successfully while its completion write is delayed. If the hub immediately writes terminal `lost`, it can reject valid completion evidence. Conversely, allowing arbitrary `lost → done` weakens terminality. Specify one arbitration rule: for example, session end triggers reconciliation, which accepts durable completion evidence before declaring `lost`.

   “Worker stopped” also needs an exact meaning. If it means the entire TermLink session ended, a `run.sh` inside that session cannot subsequently finalize. If it means the agent child exited, the wrapper can finalize before session termination. The distinction must be explicit.

   `(dispatch_id, attempt, nonce)` works only if attempt allocation and fence validation are atomic, old attempts cannot mutate the current attempt, and duplicate submissions are idempotent. It prevents stale record writes, **not stale workers modifying files or external systems**. Retries need isolated workspaces or an explicit overlapping-execution policy.

   Confirmed-session-end-only `lost` avoids false failure from missed heartbeats, but leaves hung workers, permanent partitions, and supervisor death potentially stuck forever. Define an observable uncertainty condition and a cancellation/reconciliation path; timeout alone must not authorize unsafe replacement.

   Finally, `done` must mean execution completed, not successful or approved. The wrapper exits zero after ordinary completion even when `$EXIT_CODE` is nonzero (`agents/termlink/termlink.sh:1675–1700`). Preserve actual worker exit, refusal, finalization, and review outcomes separately.

2. **Is the ownership split right?**

   **Yes for AEF’s three responsibilities**, with a stronger TermLink boundary:

   - **AEF:** agent launch/wait, durable hand-back capture, dispatcher identity, worker instructions, and adapter-specific interpretation of exit/finalization evidence.
   - **TermLink:** atomic record operations, attempt allocation, authorization/fencing enforcement, session identity and end evidence, persistence, and reconciliation primitives.
   - **[REDACTED]:** validate portability through its supervisor and contribute shared conformance cases.

   Lifecycle semantics are jointly owned; TermLink cannot independently define `lost` while AEF independently defines `done`.

   The bundle does not describe [REDACTED]’s T-2281 offer sufficiently to declare it replaced. Map its deliverables against this contract first. Absorb overlapping ledger work while preserving any distinct orchestration responsibilities.

3. **Are AEF’s four conditions right?**

   **Condition 1: necessary but insufficient.** Record an immutable dispatcher session identity, the project circuit, and the dispatch correlation identifiers. Also specify routing from the project receiver to that particular session. Merely recording a session does not make messages reach it. Define ownership transfer when the parent disappears.

   **Condition 2: directionally right, underspecified.** Put answers in a durable per-attempt command stream associated with the record. Do not let supervisors and workers rewrite an entire shared object. Define field-level permissions: supervisor publishes commands, worker acknowledges them, lifecycle authorities change lifecycle fields.

   **Condition 3: right, but “same shape” is too weak.** Local storage needs equivalent fencing, concurrency, durability, and recovery semantics. Select the authoritative backend at dispatch creation. Switching to local writes during a hub outage would create split-brain unless there is an explicit authority-transfer protocol.

   **Condition 4: right about authority, too broad if it means deleting useful logs.** Existing JSONL records can remain derived audit/reporting projections. They must stop independently deciding outcomes. `lib/spawn.py:218–272` already locks against concurrent append loss, but still permits unconditional outcome replacement by dispatch ID. Migration must cover every writer and reader.

   Missing conditions include protocol versioning, recovery, access control, result retention, and conformance tests. A hash identifies bytes; it does not make them retrievable or prove success. Define the hashed artifact, its storage, and the review verdict’s binding to dispatch, attempt, and artifact.

4. **How should answers reach a running worker?**

   Use the project sidecar for questions and the dispatch backend for replies:

   - Each question carries dispatch ID, attempt, question ID, and intended dispatcher session.
   - The project receiver routes it to that session or its explicitly designated successor.
   - The supervisor appends an answer with command ID, question ID, attempt fence, and deadline.
   - A worker-side mechanism polls and delivers it to the agent, then durably acknowledges receipt and application separately.

   **The delivery mechanism is the missing implementation decision.** A prompt saying “poll” does not prove an executing `claude -p` can accept answers. Demonstrate a tool-driven polling loop, supported input channel, or controlled resume mechanism. A wrapper reading a record is not evidence that the model consumed the answer.

   This respects `watcher.py:195–215` without inventing unread worker circuits. Use deduplication lasting through the attempt and its recovery window. Never replay old-attempt answers into a replacement worker automatically.

   Apply worker-specific deadlines outside the universal ladder: expire or escalate to the supervisor when the attempt ends or the answer becomes useless. `retry_ladder.py:1–60` explicitly describes a five-minute sweep and roughly 76-day schedule; neither provides timely interactive delivery. Distinguish stored, received, and applied, consistent with the acknowledgment distinctions in `direct.py:1–60`.

5. **What is the biggest risk of agreeing now?**

   **Agreeing on a record format while three implementations assign different meanings to its transitions.** That produces apparent interoperability with inconsistent outcomes during failures.

   Before build approval, settle a transition/authority table and demonstrate: completion racing session end; supervisor crash before and after commit; duplicate finalization; retry while an old worker survives; hub partition/restart; parent-session loss; and answer delivery plus acknowledgment to a real running worker. Also preserve the existing finalization checks in `_worker_done()` (`termlink.sh:787–805`).

6. **Overall decision**

   **Agree with conditions:** AEF owns the proposed adapter responsibilities, but build approval should require the lifecycle arbitration and recovery rules, enforceable fencing, a demonstrated answer-consumption path, backend semantic parity, and an explicit migration/T-2281 scope map. These are contract-defining decisions, not details to defer until implementation.