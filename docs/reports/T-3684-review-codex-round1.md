**The review fails:** the implementation lacks the required receipt telemetry on every delivery path, and the brief omits that acceptance criterion.

I inspected the code, tests, and recorded run artifacts. I did not rerun the suites: this session’s filesystem is read-only, while the tests create projects and launch services. The same restriction prevents writing the review file or generating `fw handover --commit`.

**T-3684 — all seven acceptance criteria**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| R3/R5 built and registered with evidence | **MET** | Both rows say `status: built` and cite implementation and live evidence in [the register](/opt/999-Agentic-Engineering-Framework/docs/architecture/sidecar-target-architecture.md:197). The tick and direct urgent-injection paths exist. |
| Configurable supervised tick, default 30 seconds, checks receiver and hub inboxes | **MET** | [run_tick](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:398) ingests hub messages and calls `deliver_pending`; `run_forever` increments sequence and schedules ticks. Configuration tests exercise default, environment, and YAML settings. The live fixture asserts `tick_s == 30`. |
| Urgent bypass; non-urgent readiness; transcript-backed HANDED_OVER; sender receives CONFIRM-2 | **NOT MET** | Readiness, direct urgent bypass, and transcript verification are implemented. However, [_confirm](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:138) explicitly skips CONFIRM-2 for hub-topic messages. The criterion does not exempt those senders. |
| Live idle ≤60 seconds, busy gating, urgent while busy, legacy ≤60 seconds, disabled-watcher negative control | **MET** | The [live suite](/opt/999-Agentic-Engineering-Framework/tests/integration/t3684_sidecar_watcher_e2e_test.py) exercises real CLI/TermLink/Claude paths. Recorded results: idle **1.423 s**, legacy **17.329 s**, non-urgent injection **23.410 s after observed turn end**, urgent injection **0.049 s while busy**. The negative control records sender `ESCALATED` and no handover or legacy ingestion. |
| Per-message latency plus median/p95/max; figures in brief | **MET** | [latency.py](/opt/999-Agentic-Engineering-Framework/lib/sidecar/latency.py) computes both requested legs and summaries. [Recorded CLI output](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-latency-A.txt) agrees with the brief. Hub inbound “RECEIVED” means local storage, not sender notification. |
| Receipt telemetry on **every** path; RECEIVED/HANDED_OVER/REPLIED timestamps; live legacy sender receipt ≤60 seconds | **NOT MET** | [inbox.pending](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inbox.py:184) advances cursors without sending receipts; [cmd_inbox](/opt/999-Agentic-Engineering-Framework/lib/sidecar_cli.py:143) calls it directly. [Watcher ingestion](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:228) stores locally without notifying the sender. Hub CONFIRM-2 is explicitly skipped. `latency.py` has no REPLIED metric. Live test 2 measures receiver ingestion, **never a RECEIVED row at the sender**. |
| Independent review file ends `VERDICT: PASS` | **NOT MET** | `docs/reports/T-3684-review-codex.md` is absent, and this review finds failures. |

**T-3685 — all four acceptance criteria**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| R7/R14/R15 built and registered with evidence | **NOT MET** | All three are labelled built, but R14’s “Every agent runs a sidecar” is stronger than the implementation. Startup is conditional; [claude-fw](/opt/999-Agentic-Engineering-Framework/bin/claude-fw:616) returns without starting it outside TermLink mode. The brief also explicitly says this framework project’s sidecar is not started. The register’s universal claim is unsupported. |
| Each tick increments sequence, probes loopback, writes required liveness fields | **MET** | [watcher.py](/opt/999-Agentic-Engineering-Framework/lib/sidecar/watcher.py:274) performs real HTTP health/authenticated acknowledgement probes; `run_forever` increments sequence; `run_tick` writes the required fields. The single-tick unit test uses a real receiver process for the probe. |
| Receiver/wrapper startup, supervised restart, reboot mechanism, status, visible inert mode | **MET** | CLI and wrapper wiring exist; process tests exercise actual signals and restarts. The installed [cron file](/etc/cron.d/agentic-audit-999-agentic-engineering-framework:15) contains minute recovery and `@reboot` recovery. **Reboot survival is supported by wiring, not an actual reboot test.** |
| Doctor/audit WARN/FAIL; live kill → not-live → supervisor restart | **NOT MET** | Diagnostics work, but the exact live sequence is not demonstrated. Test 4 first kills only the watcher and observes respawn; then kills **both supervisor and watcher**, observes not-live, and explicitly invokes `ensure --all`. [Its artifact](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-4-kill.json) proves those separate scenarios, not the requested automatic sequence. The SIGSTOP unit test covers stall/replacement separately. |

**T-3745 — all three acceptance criteria**

| Acceptance criterion | Result | Evidence |
|---|---|---|
| Session-keyed readiness; no injection into a busy sibling | **MET** | [adapter.py](/opt/999-Agentic-Engineering-Framework/lib/sidecar/adapter.py:195) records session identity/readiness; [choose_target](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:148) filters non-urgent candidates by their own readiness. |
| HANDED_OVER attributed to injected session using its transcript | **MET** | Claims name the target before typing; [prompt](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:176) filters by that claim, and finalization checks transcript attachment evidence. Live test 6’s handover names C2’s transcript. |
| Two real sessions: idle receives, busy PTY receives nothing | **MET** | [Test 6 evidence](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3684-e2e-6-two-sessions.json) records C2 as injection target, C1 still busy, C2’s line present, and no sidecar line in C1’s inspected PTY output. |

**Tests that manufacture inputs or substitute behavior**

- [Session attribution unit test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_session_ready_t3745.py:146) **writes its own transcript attachment**, then calls the real finalizer. This tests attribution/finalization logic, not Claude accepting hook output.
- [Receiver tests](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receiver_t3693.py:171) likewise manufacture transcript attachments. One replaces sleep with a callback that writes the attachment.
- Watcher/session unit tests replace TermLink with a recording runner. Latency tests write synthetic ledger rows; one directly calls `mark_handed_over`. These are legitimate unit fixtures, but cannot establish live delivery or measured transport latency.
- Cron and wrapper wiring tests inspect configuration/source strings; they do not boot the machine or exercise every wrapper branch.
- I found **no corresponding fabrication in the live suite**: it reads component-written ledgers, real transcripts, and PTY output. Writing its evidence JSON serializes observations.

**The 60-second idle pickup is genuinely measured.** Test 1 calculates elapsed time from sender `SENT` to receiver `HANDED_OVER` and explicitly asserts `lat <= 60`. The helper’s unused `limit` argument does not invalidate the caller’s assertion. This particular result exercises **on-store injection**; test 2 separately demonstrates tick-driven legacy pickup. Neither establishes a universal worst-case bound.

**Deferrals:** [T-3690](/opt/999-Agentic-Engineering-Framework/.tasks/active/T-3690-arc-011-sidecar-s7-retire-the-legacy-sid.md:1) exists and concerns legacy-address retirement. No nonexistent or unrelated named deferral owner was found. It does **not** justify deferring receipt telemetry required by T-3684.

VERDICT: FAIL