**The review fails: a headless worker can still receive a peer’s message.** The earlier receipt defects are fixed, but the new headless exclusion does not cover startup before a session record exists.

I inspected the brief, both reviews, implementation, tests, and recorded artifacts. I ran an in-memory reproduction of the remaining defect. I did not rerun the file-writing suites or live services; this session is read-only. That also prevents updating the review file and generating `fw handover --commit`.

**Blocking finding: the headless exclusion is incomplete**

The following path remains possible:

1. A worker’s PTY is registered, but its first prompt hook has not written a session record.
2. [`choose_target()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:205) excludes only PTYs identified as headless **in existing records**. Its [urgent fallback](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:232) still selects the sole unrecorded PTY, with `session_id=None`.
3. [`is_claimed_for()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:99) accepts that claim based solely on the PTY.
4. [`prompt()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:189) surfaces matching claims even when its newly recorded session is headless. The headless guard applies only to **unclaimed-mail fallback**.

Using the real selection and prompt functions, with discovery/storage boundaries substituted in memory, I obtained:

```text
No-record urgent target: {'session_id': None, 'termlink_session': 'tl-worker', 'ready': False}
Headless prompt surfaced: ['peer-message']
Peer body in hook output: True
```

This is a deterministic logic reproduction, not a live startup-race measurement. The [new regression test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_session_ready_t3745.py:253) misses it because it writes the worker’s headless record **before** selecting a target.

There is also an independent limitation: the [peek hook](/opt/999-Agentic-Engineering-Framework/agents/context/sidecar-inbox.sh:35) excludes review workers, not all headless workers. Without a distinct `FW_SIDECAR_AGENT_ID`, [`agent_name()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/circuit.py:164) defaults to the project. A plain `claude -p` launch can therefore surface pending project-topic mail. The brief’s “worker’s OWN topics” assurance depends on launcher-provided identity.

**T-3684 — every Agent AC**

| # | Acceptance criterion | Result | Evidence |
|---|---|---|---|
| 1 | R3/R5 built and registered with evidence | **MET** | [Register](/opt/999-Agentic-Engineering-Framework/docs/architecture/sidecar-target-architecture.md:197) marks both built. Tick delivery and urgency propagation exist; run 9 records direct and hub urgent bypass. |
| 2 | Supervised configurable tick, default 30 seconds; receiver and hub checks | **MET** | [`run_tick()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:405) ingests hub mail and invokes pending receiver delivery. Configuration and process tests cover scheduling; live fixtures assert 30 seconds. |
| 3 | Urgent bypass; non-urgent readiness; transcript-backed handover; sender informed | **NOT MET** | Normal interactive paths implement these behaviors, including hub confirmation. However, urgent targeting can select an unverified headless PTY and give its claim to the worker’s prompt hook, as reproduced above. |
| 4 | Live idle ≤60 seconds, busy gating, urgent while busy, legacy pickup ≤60 seconds, disabled-watcher negative control | **MET** | [Live suite](/opt/999-Agentic-Engineering-Framework/tests/integration/t3684_sidecar_watcher_e2e_test.py:307) and run-9 artifacts record these cases. Idle handover: **1.433 s**; hub handover: **18.242 s**; non-urgent injection: **17.665 s after observed turn end**; direct urgent injection: **0.054 s while busy**. Negative control records ESCALATED without pickup during observation. |
| 5 | Per-message latency, median/p95/max, measured figures in brief | **MET** | [`latency.py`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/latency.py:54) computes the metrics; [recorded CLI output](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-latency-A.txt) supports the brief’s figures. |
| 6 | Receipts on watcher, prompt-hook and CLI paths; three timestamps; live hub sender RECEIVED ≤60 seconds | **MET** | Watcher and peek paths now provide RECEIVED and transcript-backed HANDED_OVER. CLI drain sends RECEIVED only, appropriately withholding unproven handover. Successful replies generate REPLIED. [Test 2](/opt/999-Agentic-Engineering-Framework/tests/integration/t3684_sidecar_watcher_e2e_test.py:329) checks sender RECEIVED ≤60 seconds; test 2b records all three states and latency. |
| 7 | Independent review file ends `VERDICT: PASS` | **NOT MET** | The named review still ends FAIL; this review also identifies a blocking defect. |

**T-3685 — every Agent AC**

| # | Acceptance criterion | Result | Evidence |
|---|---|---|---|
| 1 | R7/R14/R15 built and registered | **MET** | [Register](/opt/999-Agentic-Engineering-Framework/docs/architecture/sidecar-target-architecture.md:274), wrapper startup, and SessionStart autostart cover normal framework launches. Explicit stop, opt-out and review-worker exceptions remain. |
| 2 | Increment sequence, loopback probe, required liveness fields each tick | **MET** | [`watcher.py`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:405) writes the required fields after probing. The tick test uses a real receiver; loop/process tests observe advancing sequence. |
| 3 | Receiver/wrapper startup, supervisor restart, reboot mechanism, status, visible inert mode | **MET** | [Process tests](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_watcher_t3684.py:258) exercise actual startup and signals. Behavioral wrapper tests execute the wrapper with a stub Claude. Installed [cron configuration](/etc/cron.d/agentic-audit-999-agentic-engineering-framework:15) contains minute and reboot recovery. **No actual reboot was measured.** |
| 4 | Doctor/audit WARN/FAIL; live failure → report → automatic recovery | **MET** | [Kill artifact](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-4-kill.json) records SIGSTOP, doctor FAIL at 73 seconds, audit FAIL at 77 seconds, and automatic supervisor recovery after **96.662 s**. Separate SIGKILL recovery is also exercised. |

**T-3745 — every Agent AC**

The readiness criterion is interpreted for non-urgent messages, consistent with T-3684’s explicit urgent exception.

| # | Acceptance criterion | Result | Evidence |
|---|---|---|---|
| 1 | Session-keyed readiness; no non-urgent injection into busy sibling | **MET** | [`adapter.py`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/adapter.py:195) records session identity/transcript; selection uses each candidate’s own readiness. Unit and live two-session evidence support this. |
| 2 | HANDED_OVER only for the injected session, from its transcript | **NOT MET** | Recorded-session claims work correctly, but the urgent no-record fallback creates a **PTY-only claim**. Any matching Claude session can surface it, including a headless worker. Transcript verification proves which session received the hook output; it does not repair the missing target-session binding. |
| 3 | Two real sessions: idle receives; busy PTY receives nothing | **MET** | [Test 6 artifact](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-6-two-sessions.json) identifies C2 as target and transcript owner, with C1 still busy and no sidecar line in C1’s inspected PTY output. |

**Earlier findings: fixed or still open**

| Earlier finding | Status |
|---|---|
| Round 1: missing receipt telemetry and REPLIED latency | **Fixed** on the reviewed watcher, peek and CLI paths. |
| Round 1: hub CONFIRM-2 skipped | **Fixed**: [`_confirm()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:133) sends hub HANDED_OVER receipts. |
| Rounds 1–2: wrapper/plain-Claude startup coverage incomplete | **Fixed** for normal configured launches through wrapper plus SessionStart hook. |
| Round 1: failure/report/recovery demonstrated only through separate scenarios and manual ensure | **Fixed** by the live SIGSTOP → diagnostics → automatic replacement sequence. |
| Round 2: CLI drain sends premature, unproven HANDED_OVER | **Fixed**: drain sends no HANDED_OVER. |
| Round 2: failed reply can generate REPLIED | **Fixed**: [`cmd_send()`](/opt/999-Agentic-Engineering-Framework/lib/sidecar_cli.py:110) requests REPLIED only after success. |
| Round 2: hub urgency lost | **Fixed** in serialization, parsing and ingestion. Current run-9 artifact also contains live hub urgent bypass. |
| Round 2: peek hook lacks transcript-backed handover and live evidence | **Fixed** by token-specific transcript checking and live test 2c. |
| Earlier warnings about synthetic unit evidence | **Still applicable**, though the brief now discloses most substitutions. |
| Independent PASS requirement | **Still open**. |

**Test fidelity and actual measurements**

- The receipt integration-style unit test still calls [`hooks._confirm()` directly](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receipts_t3684.py:87). It proves receipt transport, not transcript-backed handover.
- Session/finalizer and peek-hook unit tests write synthetic transcript attachments. Latency tests write synthetic timestamps. Those test checks and arithmetic, not real agent delivery.
- The new drain test uses real receipt delivery, but its assertions inspect output and receipts **after completion**; despite its name, it does not independently assert their ordering.
- The headless regression test covers **already-recorded** workers. It does not establish its broader “never injected” claim.
- I found no equivalent fabrication of delivery ledgers or transcripts in the live suite. Test 2b uses an explicit operator prompt to request the reply; test 2c likewise requires an operator prompt to trigger peek delivery.

**The 60-second idle pickup is genuinely measured:** test 1 subtracts component-written timestamps, asserts `<= 60`, and checks transcript evidence. It measures on-store injection. Test 2 separately measures tick-driven hub pickup and sender receipts: **RECEIVED 16.860 s**, **HANDED_OVER 18.307 s**. Test 2b records **REPLIED 34.829 s**. These establish the recorded cases, not a universal worst-case bound.

The brief also needs correction: it says hub urgency was not exercised live, but the current [busy/urgent artifact](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-3-busy-urgent.json) contains `hub_urgent`, `trigger: tick`, `urgent_bypass: true`, and `busy_at_inject: true`.

VERDICT: FAIL