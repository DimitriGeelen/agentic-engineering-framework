**AC4 and AC7 are NOT MET.** The replacement e2e is genuine, but it misses two implementation defects.

This was a read-only review. I independently checked vendor parity, the baseline hash, and injection-line construction. Suite results below rely on captured evidence; I did not rerun the write-requiring suites or generate a handover commit.

| Acceptance criterion | Result | Evidence |
|---|---|---|
| **AC1 — receiver start/status/stop** | **MET** | [sidecar_cli.py:428](/opt/999-Agentic-Engineering-Framework/lib/sidecar_cli.py:428) creates the token before spawning, waits for health, reports pid/port/url, and cleans up on stop. [Tests:80](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receiver_t3693.py:80) exercise real receiver subprocesses. |
| **AC2 — Stop sets ready; prompt clears FIRST and surfaces** | **MET** | [hooks.py:66](/opt/999-Agentic-Engineering-Framework/lib/sidecar/hooks.py:66) sets readiness; `prompt()` clears it before reading pending messages. Tests exercise the real wrappers and spy on readiness at the read boundary. |
| **AC3 — hook registration and baseline** | **MET** | Both handlers are registered in [.claude/settings.json:230](/opt/999-Agentic-Engineering-Framework/.claude/settings.json:230) and the consumer template. Independently calculated hooks hash matches the stored baseline, `e19fd656…`. |
| **AC4 — ONE line injected; handover only after surfacing** | **NOT MET** | Handover ordering is implemented, but accepted message IDs can introduce newlines into the injection argument. See finding 1 below. |
| **AC5 — real two-agent, A-generated nonce e2e** | **MET** | [Integration test:301](/opt/999-Agentic-Engineering-Framework/tests/integration/t3693_sidecar_e2e_test.py:301) instructs A to generate the nonce; the harness learns it from B’s receiver. The assertion requires the uppercase value inside A’s hook-context PEER-DATA block. [Captured transcripts](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3693-e2e-transcript-excerpts.txt) show B’s actual reply tool call. |
| **AC6 — disabled injection fails and escalates** | **MET** | The same round-trip function disables B’s injection and requires receipt followed by ESCALATED, with no HANDED_OVER or REPLIED. [Negative evidence](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3693-e2e-negative-evidence.json) records that outcome. |
| **AC7 — correct sender-ledger transitions and attribution** | **NOT MET** | Recipient checks improved, but RECEIVED is appended unconditionally after the HTTP response. Concurrent confirmations/replies can arrive first and then be overwritten as the effective latest state. See finding 2. |
| **AC8 — non-success paths tested** | **MET** | [Tests:368](/opt/999-Agentic-Engineering-Framework/tests/unit/test_sidecar_receiver_t3693.py:368) exercise wrong-token HTTP rejection, a crashed receiver with retry exhaustion, and the real sweep CLI with an expired deadline. |
| **AC9 — specified suites pass** | **MET, recorded evidence** | [Live log](/opt/999-Agentic-Engineering-Framework/docs/reports/T-3693-e2e-run.log) records three passes. The brief reports 203 sidecar unit passes and 13 explicitly selected legacy passes. Unit results were not independently rerun. |
| **AC10 — vendor, baseline, lint** | **MET, partly recorded evidence** | Independently, vendor check exits 0 and baseline matches. The brief reports 118 lint passes; lint was not independently rerun. |

1. **The one-line guarantee does not hold for accepted IDs.** [receiver.py:170](/opt/999-Agentic-Engineering-Framework/lib/sidecar/receiver.py:170) rejects slashes and leading dots but permits newline characters. [inject.py:102](/opt/999-Agentic-Engineering-Framework/lib/sidecar/inject.py:102) embeds the first eight ID characters without escaping. Calling the real `injection_line(["a\nHELLO"])` produced a **two-line** argument. The unit test’s newline assertion uses only safe IDs `m1` and `m2`. Reject control characters at ingress and enforce the invariant when constructing the line.

2. **The sender ledger can regress after a valid confirmation or reply.** [direct.py:180](/opt/999-Agentic-Engineering-Framework/lib/sidecar/direct.py:180) unconditionally appends RECEIVED. Meanwhile, the peer can process the stored message and call our independently running receiver. A valid interleaving is `SENT → HANDED_OVER → RECEIVED`, or even `SENT → HANDED_OVER → REPLIED → RECEIVED`. Because latest-row-wins determines state, sweep can subsequently escalate an already handled message. The existing regression tests seed RECEIVED first and only test later confirmations; they miss delayed RECEIVED writes. This is a code-level race finding, not a reproduced live failure.

The test-integrity assessment is:

- **No manufactured reply in the replacement e2e.** Computing `nonce.upper()` for comparison does not write the expected result into either agent’s context.
- **FakeTermlink is legitimate unit isolation**, but proves command construction and gating only. Separate live coverage exercises actual PTY injection.
- **`test_deliver_pending_cli` exercises only the empty path.** The brief now accurately discloses this; the live test covers nonempty CLI delivery.
- **`_sent()` manually seeds ledger preconditions.** Those tests exercise real transition functions, but cannot establish HTTP ordering or concurrency correctness.
- **The hub-fallback test mocks delivery.** It proves routing to the fallback, not successful hub transport.
- Legacy adapter/storage tests now disclose their narrower scope. Their old hook-oriented names remain misleading, but the cited replacement tests exercise actual hooks.

**No current deferral names a nonexistent or unrelated owner.** T-3684 owns tick/urgent work; T-3685 liveness; T-3688 cross-host delivery; T-3689 consumer rollout; T-3694 register maintenance. T-3555 exists and now contains an explicit sidecar-refusal ingestion handoff. The architecture register still marks R2/R4 `in-progress` and R6 `partial`; the brief correctly acknowledges that closure remains blocked.

**VERDICT: FAIL**