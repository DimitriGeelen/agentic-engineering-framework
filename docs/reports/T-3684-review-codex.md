**The review fails.** The new live evidence resolves several earlier gaps, but receipt semantics and universal coverage remain incomplete.

I inspected the implementation, tests, and recorded artifacts. I did not rerun the suites: this session is read-only, while they create files and launch services. That restriction also prevents updating the review file or running `fw handover --commit`.

**Blocking findings**

1. **HANDED_OVER can precede delivery to an agent.** [`cmd_inbox`](/opt/999-Agentic-Engineering-Framework/lib/sidecar_cli.py:164) sends RECEIVED and HANDED_OVER before calling `dm.pending()` and before printing any message. A subsequent failure can leave the sender with HANDED_OVER despite no output. There is no transcript check on this path.

2. **A failed reply can still produce REPLIED.** [`cmd_send`](/opt/999-Agentic-Engineering-Framework/lib/sidecar_cli.py:110) calls `_replied_receipt()` in `finally`, including when `_cmd_send()` fails or raises. Thus the receipt can certify an answer that was never delivered.

3. **Hub transport loses urgency.** [`build_post_command`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/termlink_transport.py:71) does not serialize urgency; [`inbox.pending`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inbox.py:180) does not preserve it; [`ingest_hub`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:254) explicitly sets `"urgent": False`. An urgent consult using the supported hub fallback waits for readiness.

4. **The legacy prompt-hook path is not fully demonstrated or instrumented.** [`sidecar-inbox.sh`](/opt/999-Agentic-Engineering-Framework/agents/context/sidecar-inbox.sh:43) requests RECEIVED receipts and surfaces messages, but does not finalize transcript-backed HANDED_OVER. The live fixtures install only the receiver adapter and readiness hooks, omitting this hook: [`_project`](/opt/999-Agentic-Engineering-Framework/tests/integration/t3693_sidecar_e2e_test.py:87).

**T-3684 — all seven acceptance criteria**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| R3/R5 built and registered with evidence | **NOT MET** | Both are labelled built in the [register](/opt/999-Agentic-Engineering-Framework/docs/architecture/sidecar-target-architecture.md:203). R3 is implemented; R5’s unrestricted urgent-bypass claim is contradicted by finding 3. |
| Supervised configurable tick, default 30 seconds; receiver and hub inbox checks | **MET** | [`run_tick` and `run_forever`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:405) ingest hub messages, invoke receiver delivery, increment sequence, and schedule ticks. [`SIDECAR_TICK`](/opt/999-Agentic-Engineering-Framework/lib/config.sh:266) is registered with default 30. The live fixture checks that default. |
| Urgent bypass; non-urgent readiness; transcript-only HANDED_OVER; sender informed | **NOT MET** | The receiver injection/finalization path implements these behaviors, including hub CONFIRM-2. However, urgent hub messages lose urgency, and inbox drain issues HANDED_OVER without transcript evidence—findings 1 and 3. |
| Live idle ≤60 seconds, busy gating, urgent while busy, legacy ≤60 seconds, disabled-watcher negative control | **MET** | Recorded live results: idle **1.427 s**; legacy handover **17.321 s**; non-urgent injection **14.974 s after observed turn end**; urgent injection **0.051 s while busy**. The [negative control](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-5-negative-control.json) records ESCALATED, no injection/handover, and no legacy ingestion during observation. |
| Per-message latency, median/p95/max, measured figures in brief | **MET** | [`latency.py`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/latency.py:54) computes the requested metrics. [Recorded CLI output](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-latency-A.txt) matches the brief’s pooled figures. |
| Receipt telemetry on every path; three timestamps; live legacy sender RECEIVED ≤60 seconds | **NOT MET** | The live watcher path now proves sender RECEIVED in **15.955 s**, and test 2b records all three states. That does not resolve premature HANDED_OVER, false REPLIED on failed sends, or the legacy prompt-hook gap—findings 1, 2 and 4. |
| Independent review file ends `VERDICT: PASS` | **NOT MET** | The existing [review file](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-review-codex.md) ends FAIL; this review also finds blocking defects. |

**T-3685 — all four acceptance criteria**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| R7/R14/R15 built and registered with evidence | **NOT MET** | All are marked built, but R14 still says **“Every agent runs a sidecar.”** [`claude-fw`](/opt/999-Agentic-Engineering-Framework/bin/claude-fw:619) now starts one with or without TermLink, which fixes the earlier wrapper gap. Plain `claude` launches remain uncovered, explicitly acknowledged in the register. A diagnostic WARN does not start a sidecar. |
| Each tick increments sequence, probes loopback, writes required liveness fields | **MET** | [`watcher.py`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:281) performs real HTTP health/authenticated-ack probes; the loop increments sequence and writes the specified fields. The tick unit test uses a real receiver for its probe. |
| Receiver/wrapper startup, supervised restart, reboot mechanism, status, visible inert mode | **MET** | Real-process tests exercise startup, signals, restart and status. The behavioral wrapper test runs the actual wrapper with a stub Claude executable. Installed [cron configuration](/etc/cron.d/agentic-audit-999-agentic-engineering-framework:15) contains minute recovery and `@reboot`. **No actual reboot was tested.** |
| Doctor/audit report not-live; live failure → report → automatic supervisor recovery | **MET** | The updated [kill artifact](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-4-kill.json) shows SIGSTOP → doctor FAIL at 73 seconds → audit FAIL at 77 seconds → supervisor replacement and recovery after **97.205 seconds**. Unlike round 1, this sequence requires no manual `ensure`. Separate SIGKILL recovery is also exercised. |

**T-3745 — all three acceptance criteria**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| Session-keyed readiness; no non-urgent injection into a busy sibling | **MET** | [`adapter.py`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/adapter.py:195) records session identity and transcript path; [`choose_target`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:183) uses each candidate’s own readiness. |
| HANDED_OVER attributed to the injected session through its transcript | **MET** | On the receiver path, claims are written before typing; [`prompt`](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:175) filters by session claim, and the finalizer requires the attempt-specific transcript attachment. Live test 6 attributes handover to C2’s transcript. |
| Two real sessions: idle receives; busy PTY receives nothing | **MET** | [Test 6 evidence](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-6-two-sessions.json) records C2 as target, C1 still busy, the line present in C2, and no sidecar line in C1’s inspected PTY output. |

**Tests that substitute or manufacture behavior**

The brief’s assertion that unit tests stand in “only” for TermLink and the hub reader is inaccurate:

- [`test_inbox_drain_sends_received_and_handed_over`](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receipts_t3684.py:163) replaces both `inbox.pending` and `receipts.send`. It proves calls were requested, **not that receipts reached a sender or that handover occurred**.
- [`test_prompt_hook_peek_sends_received_detached`](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receipts_t3684.py:177) replaces `send_detached` with a list append and checks a shell-script string. It never runs the actual prompt hook.
- The receipt integration-style unit test calls [`hooks._confirm` directly](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receipts_t3684.py:87), bypassing transcript verification.
- The [session-attribution unit test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_session_ready_t3745.py:146) and [receiver tests](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receiver_t3693.py:171) write their own expected transcript attachments.
- Latency unit tests write synthetic ledger timestamps and directly mark messages handed over. They test calculations, not delivery latency.

These are useful unit fixtures when described accurately. They cannot establish the broader live claims. **I found no equivalent fabrication in the live suite:** its evidence JSON serializes observations from component-written ledgers, transcripts and PTYs.

**The 60-second idle pickup is really measured.** [Test 1](/opt/999-Agentic-Engineering-Framework/tests/integration/t3684_sidecar_watcher_e2e_test.py:285) subtracts sender SENT from receiver HANDED_OVER, explicitly asserts `lat <= 60`, and checks the real transcript. Its result is **1.427 seconds via on-store injection**. Test 2 separately measures tick-driven hub pickup. These demonstrate the recorded cases, not a universal worst-case guarantee.

**Deferral owners:** No nonexistent or unrelated named owner was found. [T-3690](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3690-arc-011-sidecar-s7-retire-the-legacy-sid.md:1) exists and owns legacy-address retirement. The register’s cross-host deferral points to existing, relevant T-3688. Neither deferral excuses the receipt requirements or silently dropping urgency.

VERDICT: FAIL