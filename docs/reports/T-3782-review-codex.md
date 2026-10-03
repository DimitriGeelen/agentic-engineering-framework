Round 3 still finds failures: a hub message can disappear before storage, and the production notifier can report success without sending anything.

1. **AC1 — Immediate sender receipt on every receive path: NOT MET.**  
   [inbox.py:233](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inbox.py:233) discards any previously seen `client_msg_id` without comparing content. Consequently, a second hub message with different content never reaches the new conflict handler in `watcher.ingest_hub`.

   I reproduced this using the real `inbox.pending` with in-memory state: first body returned; second body discarded; cursor advanced to **2**. The second message gets no receipt, push, or receiver listing. If the original was already handed over, its existing sender state cannot protect the second message either.

   The [round-2 regression test:566](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_waiting_t3782.py:566) misses this because it stores the first message directly, leaving the inbox’s seen-set empty.

2. **AC2 — Threshold/urgent push, once per escalation level: NOT MET.**  
   Threshold calculation, urgent failed-send handling, and ordinary sequential-tick deduplication are implemented in [waiting.py:436](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:436) and `escalate`. **Pushes do not repeat every normal tick.**

   However, [waiting.py:489](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:489) treats the shell’s zero exit status as `sent`, while [notify.sh:101](/opt/999-Agentic-Engineering-Framework/lib/notify.sh:101) returns zero when the dispatcher is missing. I reproduced `default_notifier(...) == "sent"` with notifications enabled and a nonexistent dispatcher. The escalation ledger then suppresses subsequent attempts for that level. Background dispatcher failures likewise do not reliably propagate.

3. **AC3 — Handover and Watchtower listing until handled: NOT MET.**  
   Both surfaces correctly consume the waiting list, but that list cannot include the discarded message above.

   The round-2 spool also remains outside the listing: [watcher.py:252](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:252) reads the hub **before** draining retries and returns immediately on an exception. I reproduced that neither the spool reader nor storage runs when the hub read raises. Persistently failing stored-message retries likewise remain spooled without a waiting receipt or recipient-side listing/push. Furthermore, the spool is unlinked before replay, leaving a crash-loss window.

4. **AC4 — Logged, operator-only recovery with message and conversation pointer: MET.**  
   [waiting.py:608](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:608) constructs a fixed preamble and frames the body as untrusted peer data. Metadata uses `safe_meta`; embedded delimiters are neutralized; shell arguments are individually quoted. Recovery claims suppress duplicate delivery, and transcript evidence controls confirmation.

   **No peer-triggerable recovery route was found** in the receiver API. CLI restrictions and the CSRF-checked Watchtower action match the documented operator workflow. **Recovery does not present peer text as authoritative instructions.**

5. **AC5 — Closure only by reply, handover, or explicit operator drop; never expiry: MET.**  
   [waiting.py:265](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:265) checks explicit closure evidence. Direct deadline expiry produces `ESCALATED`, which remains open; recovery-claim expiry releases the claim. Neither closes the message. The cited 400-day test covers continued listing. The ingestion losses above are separate from expiry-based closure.

6. **AC6 — Live test and unrecovered negative control: MET, based on recorded evidence.**  
   The [committed live-run artifact](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3782-e2e/T-3782-e2e-s5hbge.json) records both waiting receipts, two captured notifications, handover inclusion, recovery transcript evidence, and the negative control remaining listed. The integration test checks those outcomes. Its notification command override does **not** validate production `fw_notify` failure reporting.

The **round-1 fixes hold on inspection**: dead-session classification, direct-send urgency persistence, epoch creation before send, and recovery metadata framing. **Round 2 is only partially fixed**: urgent failure states and epoch failure handling are implemented, but collision preservation and durable, visible retry handling remain incomplete.

Validation comprised code/test inspection and three read-only executable probes. I did not rerun the filesystem-writing suites or live integration test. The read-only sandbox also prevented generating `fw handover --commit`.

VERDICT: FAIL