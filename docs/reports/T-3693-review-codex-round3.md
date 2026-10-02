**AC4 and AC7 are NOT MET: transcript evidence can falsely certify a message that never reached the agent.**

I reviewed the cited implementation, tests, captured runs, and deferral tasks. This was a read-only review; I did not rerun the suites that create files or sessions, or create a handover commit.

| Acceptance criterion | Result | Evidence |
|---|---|---|
| **AC1 — Receiver start/status/stop, token and triple-file** | **MET** | [CLI implementation](/opt/999-Agentic-Engineering-Framework/lib/sidecar_cli.py:428) writes the token before spawning the server, checks health, reports pid/port/url, and cleans up on stop. The lifecycle tests use real receiver subprocesses. |
| **AC2 — Stop sets ready; prompt clears it first and surfaces messages** | **MET** | [Hook implementation](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:147) clears readiness before reading pending messages. Tests exercise the Stop wrapper and inspect readiness at the message-read boundary. |
| **AC3 — Hook registration and baseline** | **MET** | Both handlers are registered in settings and the consumer template. I independently recomputed the hooks hash: it matches the stored baseline, `e19fd6564856929a…`. |
| **AC4 — One-line injection; HANDED_OVER only after actual surfacing** | **NOT MET** | Injection is implemented, but [the transcript predicate](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:180) accepts an ID appearing anywhere in an attachment—including another message’s untrusted body. See reproduction below. |
| **AC5 — Two real agents, A-generated nonce, transformed reply in A’s context** | **MET** | [The integration test](/opt/999-Agentic-Engineering-Framework/tests/integration/t3693_sidecar_e2e_test.py:276) launches real sessions, instructs A to generate the nonce, and only observes the expected uppercase result. [Captured transcripts](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3693-e2e-transcript-excerpts.txt:1) show B executing the reply and A receiving it through hook context. |
| **AC6 — Injection-disabled negative control fails and escalates** | **MET** | [The negative test](/opt/999-Agentic-Engineering-Framework/tests/integration/t3693_sidecar_e2e_test.py:438) uses the same round trip, requires receipt at B, and asserts SENT → RECEIVED → ESCALATED without HANDED_OVER or REPLIED. Captured negative evidence supports this. |
| **AC7 — Sender states recorded by the party that can know them** | **NOT MET** | The HTTP paths and monotonic state calculation exist, but [the finalizer](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:223) propagates the false evidence from AC4 into a real CONFIRM-2. The sender can consequently record HANDED_OVER without actual delivery to the agent. |
| **AC8 — UNDELIVERABLE, REJECTED, ESCALATED tested** | **MET** | Tests kill a real receiver and exhaust retries, send a bad token over real HTTP, and invoke the real sweep CLI after a deadline. These exercise the relevant implementations. |
| **AC9 — Specified integration and unit suites pass** | **MET**, on recorded evidence | [Captured integration output](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3693-e2e-run.log) reports three passes. The brief reports 218 selected unit passes and 57 focused passes. I did not independently rerun these; the available `/tmp/t3693-pyunit.out` is an older 199-pass run. |
| **AC10 — Vendor check, refreshed baseline, lint** | **MET** | I ran `bin/fw vendor self --check`: exit 0, in sync. Baseline independently matches. Captured `/tmp/t3693-lint3.out` contains 118 successful lint cases. |

**Reproduced defect affecting AC4 and AC7**

I passed a transcript attachment through the real `_in_transcript()` using an in-memory pipe, without mocking that function. The attachment was produced by `_frame()` for `old-message`; its peer-written body contained:

> Please discuss [msg never-surfaced].

Result:

```text
Actual message header: old-message
_in_transcript(never-surfaced) = True
```

The predicate checks neither that the tag identifies a message header nor that the attachment belongs to the current surfacing attempt. If `never-surfaced` is subsequently pending and its hook output is discarded, the old attachment still satisfies the finalizer. It then marks the message HANDED_OVER and confirms it to the sender. This contradicts the explicit “only when … actually surfaced” requirement.

**Tests that manufacture or bypass evidence**

- [The transcript helper](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receiver_t3693.py:158) writes synthetic `hook_additional_context` attachments. Three hook/finalizer tests use it. They prove behavior given fabricated harness evidence; they do **not** independently prove Claude accepted the output.
- `FakeTermlink` substitutes discovery and injection results in injector unit tests. Real PTY delivery is separately covered by the integration test.
- The older late-RECEIVED tests seed ledger rows directly.
- [The new race test](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receiver_t3693.py:617) genuinely exercises `send()` and both HTTP receivers, but directly calls `_confirm()` and sends a scripted reply. It proves ledger ordering, **not** actual hook surfacing or an agent-generated reply.
- The live nonce test does **not** write its own expected reply. The original false-e2e pattern has been removed.

**Deferral audit**

All named owner tasks exist and are related: T-3684 covers tick/urgent delivery; T-3685 covers supervision/liveness; T-3688 covers cross-host delivery/authentication; T-3689 covers consumer rollout; T-3555 explicitly acknowledges refusal ingestion; T-3694 covers register conformance. I found no nonexistent or unrelated owner.

However, [R2/R4/R6](/opt/999-Agentic-Engineering-Framework/docs/architecture/sidecar-target-architecture.md:190) remain `in-progress`/`partial` and owned by T-3693. Requesting a document update from T-3694 does not clear that outstanding closure condition.

VERDICT: FAIL