Round-1 fixes address the reported happy paths, but two failure paths remain: outbound messages can become permanently invisible after an epoch-write failure, and hub ingestion advances its cursor before durable storage.

1. **AC1 — Immediate waiting receipt on every receive path: NOT MET.**  
   The dead-agent/surviving-PTY fix holds: `is_no_recipient("agent not ready: no session …")` returns true. However, [hub ingestion](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:239) calls `inbox.pending(advance=True)` before storing messages. [The cursor and seen-set are saved](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inbox.py:251) first. A subsequent storage failure is recorded as `HUB_DUPLICATE_SKIPPED`; the next tick cannot retry that message. It receives neither a waiting receipt nor a recipient-side listing/push. Sender-side tracking can mitigate this, but does not satisfy the receipt AC.

2. **AC2 — Threshold/urgent push, once per level: NOT MET.**  
   The round-1 change correctly persists `urgent` on direct SENT rows. But [due_levels](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:429) grants immediate escalation only for two explicit no-recipient states. An urgent send to an unreachable sidecar becomes `undeliverable` and waits for the normal threshold. An in-memory reproduction returned `[]` for its due levels.  
   **Pushes do not repeat every normal sequential tick:** [escalate](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:504) deduplicates by item and level, including failed/disabled attempts. The supplied 60-tick test covers this.

3. **AC3 — Handover and Watchtower listing until handled: NOT MET.**  
   Both surfaces consume the waiting list correctly, but round-1’s cutoff fix remains fail-open. [direct._mark_epoch](/opt/999-Agentic-Engineering-Framework/lib/sidecar/direct.py:176) and [outbox.write_message](/opt/999-Agentic-Engineering-Framework/lib/sidecar/outbox.py:107) swallow epoch-creation exceptions and continue sending. A later successful initialization creates a cutoff *after* those sends; [outbound_items](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:334) permanently excludes them.  
   **Reproduced:** injected an epoch-write failure, allowed the send to record `UNDELIVERABLE`, then supplied a later epoch. The outbound listing remained empty **400 days later**. With the peer down, this leaves no waiting receipt, operator push, or waiting listing.

4. **AC4 — Logged operator recovery with safely framed message: MET.**  
   [Recovery](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:594) starts the local project’s agent with the message and conversation pointer, logs the launch, and requires user-transcript evidence before marking handover. The Watchtower button invokes that path. The receiver exposes only `/message` and `/ack`; neither triggers recovery. The CLI rejects agent-context invocation unless explicitly overridden.  
   The round-1 metadata fix holds: `safe_meta` replaces unsafe metadata wholesale; body delimiters are neutralized inside the untrusted-data block. **Recover does not promote peer text into instructions.**

5. **AC5 — Closure only by reply, handover, or reasoned operator drop: MET.**  
   [Closure checks](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:255) contain no expiry-based closure. Recovery-claim timeout releases the claim; direct deadline expiry escalates rather than closes. Drop requires a reason. The epoch defect above hides records, but does not write a closure.

6. **AC6 — Live test and negative control: MET, based on recorded evidence.**  
   [The committed live-run evidence](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3782-e2e/T-3782-e2e-s5hbge.json) records both waiting receipts, two pushes, the handover section, recovery confirmed by transcript, and the unrecovered control still listed after 162.5 seconds. Notification delivery was captured through the configured test notifier.

I inspected the cited tests and ran filesystem-free mocked reproductions. I did not rerun the write-dependent suites or generate `fw handover --commit` because this session permits only filesystem reads.

**VERDICT: FAIL**