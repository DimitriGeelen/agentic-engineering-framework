HEAD is `df7c66835` (a few doc/vendor commits after `bf07a0255`; I'll verify no behavioural lib/tests changes landed after it). Now reading the core implementation files.
`lib/`, `bin/`, `agents/`, `tests/`, `.claude/` are unchanged between `bf07a0255` and HEAD (only vendored copy + docs/tasks changed) — so reviewing HEAD files equals reviewing bf07a0255 behaviour. Reading adapter.py and hooks.py next.
The prompt-hook headless guard (hooks.py:192-193) and the no-record fallback gate (inject.py:232-243) are present. Now the peek hook, CLI, receipts, watcher, inbox.
Peek-hook guard present (sidecar-inbox.sh:41-46). Now the CLI and watcher.
CLI looks correct (print→flush→RECEIVED in cmd_inbox finally; REPLIED only on rc==0). Now watcher.py, inbox.py, transport, latency.
Hub-path urgency wiring confirmed (transport:102-105, inbox:239, watcher:261). Now the cited tests.
T-3745 tests check out — including the round-3 regression tests. Now the receipts tests.
Receipts tests match the brief's disclosure. Now the watcher unit tests.
Now the live e2e suite — the critical piece for the measurement claims.
The live suite reads only component-written ledgers and asserts measured bounds. Now verifying the committed run-10 artifacts against those assertions.
Run 10 confirmed 8/8; register rows built. Now the bats peek-hook test and audit wiring.
Headless peek bats test verified with both controls. Now the receiver-test fixture pin, latency artifacts, and conftest.
Latency figures match the brief. Final checks: claude-fw wiring, vendored-copy sync, and the audit rail bats.
# T-3684 / T-3685 / T-3745 — adversarial review, round 4

Read-only as instructed: no files created/modified, no state-changing git commands. HEAD `df7c66835`; verified `lib/`, `bin/`, `agents/`, `tests/`, `.claude/` are byte-identical to the round-3-fix commit `bf07a0255` (only docs/tasks/vendor-sync landed after), so the reviewed code IS the round-3-fix code. I did not re-run suites (they write files/launch services); verdicts rest on code inspection plus committed artifacts (run-10 log: 4 passed in 98 s + 4 passed in 500 s = 8/8).

## Round-3 findings — fixed or still open

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | urgent no-record fallback could type into a headless worker's PTY; PTY-only claim surfaced by its prompt hook | **Fixed** | inject.py:232-243 — fallback injects only when `adapter.claude_in_pty(pid) == "interactive"`, refuses headless/None/bare-shell; headless records removed from `tagged`/`candidates` (inject.py:205-211); hooks.py:192-193 — headless session surfaces nothing, claimed or not. Tests: test_sidecar_session_ready_t3745.py:273 (no-record case, refuses `headless` and `None`, injects on `interactive`), :295 (codex's exact PTY-only-claim scenario), :310 (`claude_in_pty` over **real** process trees, incl. `claude -p` → headless) |
| 2 | peek hook in `claude -p` with no own id peeked the project inbox and receipted it | **Fixed** | sidecar-inbox.sh:41-46 exits before `fw` when no `FW_SIDECAR_AGENT_ID` and `_is_headless(_claude_ancestor_pid())`; bats sidecar_inbox_hook.bats:52-66 runs the real hook under a fake `claude` ancestor (comm `claude`) with `-p`: empty output, fw never called, plus both controls (interactive surfaces; headless+own-id surfaces) |
| 3 | drain test name claimed print-before-receipt order without asserting it | **Fixed** | test_sidecar_receipts_t3684.py:163-189 wraps the **real** `receipts.send` and captures `capsys` output at call time; asserts `"drain-me"` already printed; ledger `["RECEIVED"]` only |
| 4 | brief wrongly said hub urgency not exercised live | **Fixed** | Brief §00#4 corrected; artifact `T-3684-e2e-3-busy-urgent.json` `hub_urgent`: `urgent_bypass: true`, `busy_at_inject: true`, `trigger: tick`, inject before turn end |
| — | headless regression covered only already-recorded workers | **Fixed** | the no-record case is finding 1's first test (t3745:273) |

Round-1/2 findings: spot-checked all remain fixed (drain RECEIVED-only sidecar_cli.py:166-181 with flush-before-receipt; REPLIED only on rc==0 sidecar_cli.py:110-116; urgency transport:102-105 → inbox:239 → watcher:261; hub CONFIRM-2 hooks.py:137-143; wrapper+SessionStart autostart bin/claude-fw:625-632, sidecar-autostart.sh, .claude/settings.json:36,49; live SIGSTOP→FAIL→auto-heal artifact below).

## T-3684 Agent ACs

| AC | Verdict | Evidence |
|---|---|---|
| R3/R5 built with evidence | **MET** | register (sidecar-target-architecture.md) R3, R5 `status: built` with code+live evidence |
| Supervised tick every SIDECAR_TICK (default 30), checks receiver AND hub topics | **MET** | watcher.py:412-441 `run_tick` (ingest_hub → deliver_pending → escalate → probe → liveness), :467-494 loop, :527-602 supervisor; config.sh:266 `SIDECAR_TICK\|30`; tests test_sidecar_watcher_t3684.py:92-107, :189-228 |
| Urgent regardless; non-urgent only ready; HANDED_OVER on transcript; sender informed | **MET** | inject.py:212-231, :307-341 (claim before typing, INJECT_TYPING); hooks.py:276-322 finalize requires attempt-token attachment (hooks.py:235-266); CONFIRM-2 / hub HANDED_OVER receipt hooks.py:134-157; live: test_1 sender HANDED_OVER `by: peer-receiver:…`, test_3 `urgent_bypass`, non-urgent injected 17.25 s after turn end, trigger tick |
| Live: idle ≤60 s; busy gating; urgent while busy; legacy ≤60 s; disabled → ESCALATED | **MET** | run-10 artifacts: idle 1.43 s (asserted `lat <= 60`, t3684 e2e:324); legacy 16.28 s; urgent typed 0.73 s while busy (PTY line present); negative control: states `[SENT, RECEIVED, ESCALATED]`, `by: infrastructure`, no INJECT_ATTEMPT/HANDED_OVER, legacy never ingested |
| `fw sidecar latency` median/p95/max, figures in brief | **MET** | latency.py; T-3684-latency-A.txt figures match brief §4 exactly (9.476/27.645…119.364) |
| Receipts on EVERY path; 3 timestamps; live legacy RECEIVED at sender ≤60 s | **MET** | watcher ingest (watcher.py:274), peek hook (sidecar-inbox.sh:161-180 + receipts.flush transcript gate receipts.py:245-293), drain (sidecar_cli.py:175-181), REPLIED (sidecar_cli.py:96-116); sender-side acceptance only for own outbox ids (receipts.py:111-130, test :130); live test_2: sender RECEIVED **14.90 s** (asserted ≤60), HANDED_OVER 16.34 s; test_2b all three states, latency row `path: hub`, `send_to_replied_s` 34.586 |

## T-3685 Agent ACs

| AC | Verdict | Evidence |
|---|---|---|
| R7/R14/R15 built with evidence | **MET** | register rows all `built`; R14 via claude-fw (:625) + SessionStart hook + cron ensure; explicit stop / review-worker opt-outs tested (test_sidecar_watcher_t3684.py:424-435) |
| Tick: seq+1, loopback probe, liveness fields | **MET** | watcher.py:428-435 writes all `_LIVENESS_KEYS` after authenticated /health+/ack probe (:288-313); test :112-126 with a real receiver |
| Started with receiver; supervised restart; reboot pattern; in status; claude-fw one; inert+visible | **MET** | cmd_receiver_start (sidecar_cli.py:564-579); real-signal tests :258-324; `fw sidecar status` shows watcher (sidecar_cli.py:298-304); claude-fw behavioural test both modes (:384-402, inert lines bin/claude-fw:630-632); @reboot + 1-min cron installed (test :364-370) — no actual reboot performed, disclosed, AC asks for the repo's existing pattern |
| doctor/audit WARN/FAIL; live kill → reported → auto-restart | **MET** | bin/fw:3464-3484, audit.sh:4068-4100; run-10 `4-kill`: SIGSTOP → doctor `FAIL … seq stalled at 6 for 74s`, audit `[FAIL]` at 78 s → supervisor replaced after 96.6 s (`WATCHER_HUNG_KILLED`), no manual ensure on the hung leg |

## T-3745 Agent ACs

| AC | Verdict | Evidence |
|---|---|---|
| Ready keyed by session_id (+transcript); inject only own-ready session, never busy sibling | **MET** | adapter.py:223-316 per-session records; inject.py:183-248; 16 unit tests incl. the 055 scenario; live test_6 |
| HANDED_OVER only for injected session, from its transcript | **MET** | claim-before-typing + `is_claimed_for` session match (inject.py:99-116); finalize transcript evidence per attempt; run-10 test_6: HANDED_OVER evidence `transcript:bf52bfe5-….jsonl` = C2's session id. Round-3's PTY-only-claim hole closed by hooks.py:192-193 |
| Two sessions: idle gets it, busy PTY nothing | **MET** | run-10 `6-two-sessions`: inject target = C2 (`target_session_id` = C2 sid), `c1_pty_has_line: false`, `c1_pty_has_any_sidecar_line: false`, `c1_busy_at_check: true` |

## Do tests fake the behaviour they claim?

The brief's §7 list is accurate — I found every substitution it discloses and no undisclosed one. Two tests call `hooks._confirm` directly (receipt transport, not transcript proof — the transcript check is proven elsewhere); session/peek tests write their own transcript attachments (test the check; live test_1/2/6/2c verify real transcripts); latency unit tests are synthetic arithmetic (real figures come from run 10); `_cmd_send`/`receipts.send` monkeypatched only in `test_failed_reply_sends_no_replied`. The live suite writes no ledger/transcript/receipt itself — every timing is computed from component-written rows (sender ledger SENT ts, outbox `created_at`, hub `hub_ts`, receiver events) and asserted `<= 60`. Receivers, supervisor, watcher, CLI, claude-fw and the peek/drain hooks all run as real processes or real scripts in their tests.

## The 60 s bounds and hub receipts — really measured?

Yes. Idle: e2e:307-326 computes ledger-ts delta and asserts `lat <= 60` (1.43 s, on-store path; tick path separately in test_2). Hub receipts at sender: e2e:349-367 computes A's receipts.jsonl RECEIVED ts minus A's outbox `created_at`, asserts ≤ 60 (14.90 s) and `by == peer:<B>`; REPLIED asserted with the latency row (34.59 s). These are measured cases, not worst-case proofs — the brief says so itself (§4).

## Can a headless worker still take or be typed peer mail?

All five routes closed on the reviewed code: recorded-session injection (inject.py:205-211), no-record urgent fallback (inject.py:236-243, interactive-claude-in-PTY evidence required, verified against real process trees), claimed-mail surfacing incl. PTY-only claims (hooks.py:192-193), plain-terminal fallback (hooks.py:204), peek hook (sidecar-inbox.sh:41-46; with own id, `agent_name()` returns it — circuit.py:164-170 — so it reads only its own topics). A stale interactive record whose claude died reads `alive=False/ready=False` (adapter.py:310-314), and the fallback re-inspects live /proc state, not the record. Residual, disclosed in brief §0: headlessness is detected from `-p`/`--print` in the claude cmdline; a differently-spelled headless launch (or a crashed detection probe in the fail-open peek hook) would read as interactive. That is a detection-coverage limit, not an open route in the implemented model, and it is honestly stated.

## Reservations (non-blocking)

- No actual reboot test (wiring only) — disclosed; AC wording asks for the repo's supervision pattern.
- Headless-spelling dependency above.
- `record_from_peer`/`_already` rescan whole ledgers per call — perf nit only.

VERDICT: PASS
