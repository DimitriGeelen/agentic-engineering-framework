**Four counterexamples prevent a PASS.** I read the brief, implementation and cited tests, and reproduced these gaps with in-memory probes that made no filesystem changes.

1. **AC1 — Immediate sender receipt on every receive path: NOT MET.**  
   A normal message targeting a dead agent whose TermLink PTY remains registered is classified as `"agent not ready"` when no live session candidates remain. `is_no_recipient()` excludes that reason, so no WAITING receipt is sent. The probe reproduced this with an explicitly `alive=False` session. See [inject.py:210](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:210) and [waiting.py:169](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:169).  
   The live test sends an urgent message first; its urgent bypass detects the dead recipient and masks this normal-message-only failure.

2. **AC2 — Threshold push, immediately for urgent, once per level: NOT MET.**  
   Outbound direct messages are constructed with `urgent=False` unconditionally. The direct SENT ledger also omits urgency. Consequently, an urgent direct message with a WAITING receipt does **not** trigger immediate sender-side escalation. My probe returned `urgent=False, due_levels=[]`. See [waiting.py:348](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:348) and [direct.py:198](/opt/999-Agentic-Engineering-Framework/lib/sidecar/direct.py:198).  
   **Ordinary successive ticks do not repeat pushes:** `escalate()` deduplicates by item and level; the cited 60-tick test covers that behavior. This does not fix missing escalation candidates.

3. **AC3 — Listed in handover and Watchtower until handled: NOT MET.**  
   The outbound cutoff is initialized on the **first listing**, rather than before sending. Any message sent before that first scan is permanently excluded—even one sent just a second earlier after installation. My probe found it still absent 400 days later. See [waiting.py:128](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:128), [waiting.py:337](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:337), and [waiting.py:364](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:364).  
   **A silent path therefore exists:** send through the hub while the recipient sidecar is down, before the sender’s first waiting scan. The recipient supplies no receipt or push; the sender permanently omits the message from both listing and escalation. Both UI surfaces consume this incomplete list. The outbound test avoids the defect by explicitly calling `waiting.epoch()` before sending.

4. **AC4 — Logged, operator-only recovery with message and conversation pointer: NOT MET.**  
   Session launch, logging, transcript confirmation and the Watchtower action are implemented. **There is no direct peer recovery route:** the receiver accepts only `/message` and `/ack`. However, recovery’s trusted preamble interpolates unvalidated peer-controlled `from` and `conversation_id`; those fields also appear outside the markers in hook headers and reply commands. See [waiting.py:571](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:571), [hooks.py:90](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:90), and [http_server.py:86](/opt/999-Agentic-Engineering-Framework/lib/sidecar/http_server.py:86).  
   A conversation ID containing a newline and an instruction appeared **outside PEER-DATA** in my probe. Body text is framed and its delimiters neutralized; metadata is not. This establishes instruction exposure, not proof that a model would obey it. The hostile-input test exercises only the body.

5. **AC5 — Closure only by reply, HANDED_OVER or operator drop; never expiry: MET.**  
   I found no expiry-based closure transition. Direct deadline expiry produces ESCALATED, which remains eligible for listing; an expired recovery claim releases delivery rather than closing the message. See [direct.py:302](/opt/999-Agentic-Engineering-Framework/lib/sidecar/direct.py:302), [waiting.py:241](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:241), and [waiting.py:246](/opt/999-Agentic-Engineering-Framework/lib/sidecar/waiting.py:246).  
   The cutoff defect above is permanent omission, not a legitimate closure.

6. **AC6 — Live kill/send/notify/handover/recover test and negative control: MET, based on recorded evidence.**  
   The [committed evidence](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3782-e2e/T-3782-e2e-s5hbge.json) records sender receipts within two seconds, two pushes, handover inclusion, transcript-confirmed recovery and a still-listed negative control. The integration test asserts these outcomes. Its urgent-first scenario does not cover the counterexamples above.

I did not rerun the filesystem-writing suites or live integration test. The read-only environment also prevents the required `fw handover --commit`.

VERDICT: FAIL