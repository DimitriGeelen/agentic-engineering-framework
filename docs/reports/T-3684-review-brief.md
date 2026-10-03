# T-3684 / T-3685 / T-3745 — review brief (sidecar watcher), round 4

Independent-review input. Every claim points at code (file:line), a test, or a
recorded artefact. Live evidence: **run 10** of
`tests/integration/t3684_sidecar_watcher_e2e_test.py` on committed code bf07a0255
(round-3 fixes) — **8 passed** (tests 1/2/2b/2c in 98 s, tests 3–6 in 500 s; log
`docs/reports/T-3684-e2e-run10.log`; per-test JSON `docs/reports/T-3684-e2e-*.json`,
written by run 10 on 2026-10-03 13:24–13:34 UTC). Runs 8 (e9c6bbb46) and 9
(f7c7f1d2c) were also 8/8 (`T-3684-e2e-run8.log`, `-run9.log`). Unit: all 271
tests in `tests/unit/test_sidecar_*.py` pass; bats sidecar_inbox_hook (11),
t3559_sidecar_inbox_contract (5), sidecar_audit_rail (12) pass with no skips, also
with `FW_SIDECAR_AGENT_ID` unset under a `claude -p` runner.

Commits: 41a55a515, 7619e1c08 (T-3745); 2e7bdc0ab, 5d0aac008, a2c5c188d, e3f76a1e5,
3ec45b45e, bb823a983, e9c6bbb46, f7c7f1d2c, 987dff4f4, ede6b2f95, bf07a0255,
c680353dc (T-3684); 7fb5ba890 (T-3685).

## 00. Round-3 findings (docs/reports/T-3684-review-codex-round3.md, FAIL) and what changed (bf07a0255)

| # | finding | fix | test (each fails on the round-3 code, passes now) |
|---|---|---|---|
| 1 | urgent "only registered session, no record yet" fallback could pick a headless worker's PTY before its first hook wrote a record; the PTY-only claim (session_id None) then matched the worker's prompt hook, which surfaced it (codex's in-memory reproduction) | (a) inject.py `choose_target` no-record fallback: types only when `adapter.claude_in_pty(pid)` (new, adapter.py ≈l.195 — breadth-first over /proc children of the TermLink PTY's shell, first `claude` decides via `_is_headless`) returns `interactive`; headless, a bare shell or no evidence → refused, the message waits; (b) hooks.py `prompt`: a headless session surfaces NONE of the receiver's mail, claimed for its PTY or not (a stale claim expires after REINJECT_AFTER_S=120 and is retried) | `test_urgent_no_record_fallback_needs_an_interactive_claude_seen_in_the_pty`; `test_headless_session_surfaces_nothing_even_with_a_pty_only_claim` (codex's scenario: PTY-only claim for `tl-w`, headless worker prompts → nothing, body absent; an interactive session in that PTY takes it); `test_claude_in_pty_reads_real_processes` (real process trees: shell → `claude` / `claude -p` / bare `sleep`) |
| 2 | the peek hook in a plain `claude -p` with no `FW_SIDECAR_AGENT_ID` peeks the PROJECT's inbox (agent_name() defaults to the project) and would send receipts for it | agents/context/sidecar-inbox.sh: a headless session with no agent id of its own exits silently before calling fw; an addressable worker (own id) still reads its own inbox | bats `headless claude -p with no agent id of its own: silent, the project's inbox is never read` — a fake `claude` ancestor (`#!/bin/bash` so /proc comm is `claude`) with `-p`: no output, fw never called; CONTROL 1 interactive → surfaces; CONTROL 2 headless + own id → surfaces. Fails on the round-3 hook (output non-empty) |
| 3 | drain test name claimed print-before-receipt order but did not assert it | `test_inbox_drain_really_sends_received_after_printing_and_no_handed_over` wraps the REAL `receipts.send` and records what had been printed at the moment of the call; asserts the consult body was already printed | — |
| 4 | the brief said hub urgency was not exercised live; the artifact has `hub_urgent` | corrected: live test_3 posts an urgent consult over the hub topic; run 10: `INJECT_ATTEMPT trigger: tick, urgent_bypass: true, busy_at_inject: true` | live test_3 |
| — | headless regression test covered only already-recorded workers | the no-record case is finding 1's first test | — |

Test fixtures that now pin "not headless" (because the suites can run inside a
`claude -p`): `_claude_ancestor_pid` → None in the watcher/receiver/T-3745 fixtures;
`test_urgent_bypasses_readiness` pins `claude_in_pty` → `interactive` (it tests the
bypass itself; the refusal is tested above); the wrapper subprocess test runs the
hook under a fake interactive `claude` parent; the two bats suites set an agent id.

## 0. Round 3 change: a headless worker is never an inject target (f7c7f1d2c)

Found while preparing round 3: `adapter._is_headless` said a `claude -p` session
"can never be injected into", but `inject.choose_target` did not filter on it. A
dispatched worker runs in a TermLink PTY tagged for the project, so an URGENT
message (busy bypass) or the "only registered session, no record yet" fallback
could type into a worker's PTY. Now `choose_target` (lib/sidecar/inject.py ≈l.197)
drops sessions whose record is headless before choosing, and a headless PTY does not
count as a registered interactive session (so a plain interactive terminal may take
the mail, T-3745 fallback). Unit test
`test_headless_worker_in_a_tagged_pty_is_never_injected_not_even_urgent`
(tests/unit/test_sidecar_session_ready_t3745.py) fails on the old inject.py (it
typed `u1` into the worker's PTY) and passes now. Three test fixtures now pin
"not headless" (`_claude_ancestor_pid` → None, as the T-3745 fixture already did):
run from inside a `claude -p` worker, their sessions read as headless and were
correctly no longer targets.

Can a headless worker still take a peer's message? Every route, as built after
bf07a0255 (round 3 found two of these open; §00):
- injection with a session record: no (above);
- injection with no record yet (urgent fallback): only into a PTY where an
  interactive claude is seen (§00 #1a);
- its prompt hook, claimed mail: none surfaced in a headless session, whatever the
  claim names (§00 #1b);
- its prompt hook's plain-terminal fallback: no (`not me.get("headless")`;
  unit `test_headless_session_never_takes_fallback_mail`);
- the peek hook: silent in a headless session without its own agent id (§00 #2);
  with its own id (`FW_SIDECAR_AGENT_ID`, set by the dispatcher for addressable
  workers) it peeks only its own inbox topics, never the project's.
The one remaining dependency: headlessness is read from the claude process's
command line (`-p` / `--print`, adapter.py `_is_headless`). A headless launch
spelled differently (e.g. stdin piping without `-p`) would read as interactive.

## 0a. Round-2 findings (docs/reports/T-3684-review-codex.md, FAIL) and what changed

| # | finding | fix (bb823a983) | test |
|---|---|---|---|
| 1 | `fw sidecar inbox` drain sent HANDED_OVER before printing, no transcript proof | lib/sidecar_cli.py `cmd_inbox` (≈l.164): prints first, flushes, THEN sends RECEIVED only; a drain sends no HANDED_OVER at all (nothing proves where its output went) | unit `test_inbox_drain_really_sends_received_after_printing_and_no_handed_over` (real `inbox.pending` over a recorded hub, real receipt to A's real receiver; A's ledger == `["RECEIVED"]`) |
| 2 | REPLIED sent in `finally`, also for a failed reply | `cmd_send` (≈l.110) calls `_replied_receipt` only when `_cmd_send` returned 0 (delivered / hub-accepted) | unit `test_failed_reply_sends_no_replied`; live test_2b REPLIED at the sender |
| 3 | urgency lost on the hub path | termlink_transport.py `build_post_command` adds `--metadata urgent=1`; inbox.py `pending` parses it; watcher.py `ingest_hub` stores `urgent: bool(m["urgent"])` | unit `test_urgency_survives_the_hub_path` (argv + ingest); **new in round 3:** `test_urgent_hub_topic_consult_is_injected_on_the_tick_while_busy` (tests/unit/test_sidecar_watcher_t3684.py) — an urgent hub post is injected on the same tick into a BUSY session; the non-urgent post beside it waits. Also live: test_3's `hub_urgent` leg (§4) |
| 4 | prompt-hook peek path not instrumented / not shown live | agents/context/sidecar-inbox.sh: each shown consult's header carries `[msg <id>] [surfacing <one-time token>]`; RECEIVED for exactly what it showed; a detached `fw sidecar receipts-flush` sends HANDED_OVER only when THIS surfacing's header line appears in a `hook_additional_context` attachment of the session's own transcript (receipts.py `_peek_in_transcript`, `flush`) | unit `test_real_peek_hook_received_now_handed_over_only_on_transcript_evidence` (runs the real hook script), `test_peek_hook_forged_header_in_a_body_is_not_evidence`; **live test_2c**: project D with no sidecar, only the peek hook, a real claude session prompted by its operator → sender A gets RECEIVED 4.04 s and HANDED_OVER 4.04 s after send (D's receipts-sent ledger: RECEIVED + HANDED_OVER `by: prompt-hook-peek`; D's transcript `7c2b4fdd….jsonl` holds the surfacing) |
| R14 | plain `claude` launches got no sidecar | SessionStart hook agents/context/sidecar-autostart.sh (`fw sidecar ensure --autostart`, detached; respects an explicit `fw sidecar stop`; skipped in review workers), registered in .claude/settings.json and by lib/init.sh | register row R14 evidence |
| — | (run 7) an em dash in an operator prompt left test_2c's prompt unsubmitted | e9c6bbb46: ASCII prompts, submission confirmed | run 8: 8/8 |

## 0b. Round-1 findings (docs/reports/T-3684-review-codex-round1.md, FAIL) and what changed

| finding | fix |
|---|---|
| Receipt telemetry on every path absent | lib/sidecar/receipts.py (new); wired in watcher.py:267, sidecar_cli.py:164 (`inbox` drain + `--peek --receipt`), agents/context/sidecar-inbox.sh, hooks.py:142, sidecar_cli.py:96 (REPLIED), http_server.py:120, inbox.py:216; latency.py hub-path + send→REPLIED. Live test_2 / test_2b. |
| CONFIRM-2 skipped for hub-topic senders | now a HANDED_OVER receipt (hooks.py:142), live test_2 asserts it at the sender |
| R14 "every agent runs a sidecar" over-claimed (only `--termlink`) | `claude-fw` starts it for EVERY session, inert-and-says-so without TermLink (bin/claude-fw:619); behavioural unit test runs the real wrapper |
| Live kill sequence was two separate scenarios + a manual `ensure` | supervisor now heals a HUNG watcher one tick AFTER it reads not-live (watcher.py:72 `HUNG_KILL_TICKS`), so live test_4 (a2) shows hang → doctor+audit FAIL → supervisor restarts it, nobody acting |

## 1. What is built

| piece | where |
|---|---|
| Per-session readiness: `.context/sidecar/sessions/<session_id>.json` {session_id, transcript_path, termlink_session=`$TERMLINK_SESSION_ID`, claude_pid, headless} | adapter.py:195, :213, :228; hooks.py `stop` |
| Target choice from per-session records only; injector publishes what it found | inject.py:183 `choose_target`, :152 |
| Claim names the target session, written BEFORE typing; INJECT_TYPING before keystrokes | inject.py `_write_claim`, :307 |
| Prompt hook surfaces only what is claimed for ITS session (hooks.py:189); a plain-terminal-only project (injector has DECIDED none is registered, inject.py:166) lets an INTERACTIVE session take and claim unclaimed mail (hooks.py:198) — never with no decision on record, never in a headless `claude -p` session | |
| Watcher tick: hub-topic ingest (+RECEIVED receipt) → inject → escalate → loopback probe → liveness.yaml | watcher.py:405, :229, :281, :326 |
| `SIDECAR_TICK` default 30 | lib/config.sh:266; watcher.py:92 |
| Supervisor: respawn on exit; replace a hung watcher (stall) one tick after not-live; restart a dead receiver; single-instance locks; orphan adoption | watcher.py:520 |
| Liveness predicate (absent / not-live / live) | watcher.py:360 |
| Receipts (receiver: send once per state via sender's live receiver `/ack`, else `kind=receipt` hub post; sender: accept only for an id our outbox sent to that peer) | receipts.py:181, :108, :154 |
| CLI: `fw sidecar start|stop|ensure [--all]|liveness|latency|receipts|tick`; `receiver start` starts the watcher; `status` shows it | sidecar_cli.py:558, :582, :615, :632, :638, :294 |
| doctor / audit | bin/fw (T-3685 block, FAIL when enabled and not live, WARN when absent); agents/audit/audit.sh `check_sidecar_watcher`; fact fn lib/sidecar-audit.sh `fw_sidecar_watcher_facts` |
| Reboot / supervisor death | cron `sidecar-ensure-1m` + `sidecar-ensure-boot` (@reboot) → `fw sidecar ensure --all` over the host enabled-registry (.context/cron-registry.yaml; installed /etc/cron.d/agentic-audit-999-agentic-engineering-framework) |

## 2. T-3745

| AC | status | evidence |
|---|---|---|
| ready keyed by session_id (+transcript_path); inject only into the session whose own flag is ready | MET | unit tests/unit/test_sidecar_session_ready_t3745.py (16 tests: 055 scenario, busy-until-own-Stop, claim-before-typing, dead claude pid, urgent into busy, no-decision-on-record → nothing taken, headless → nothing taken, headless worker PTY never injected even urgent — §0); live test_6 |
| HANDED_OVER only to the injected session, from its transcript | MET | unit `test_handed_over_is_attributed_only_to_the_injected_session`; live test_6: HANDED_OVER evidence `transcript:bf52bfe5-….jsonl` = C2's session (run 10) |
| two sessions, one project: idle gets it, busy PTY nothing | MET (live) | T-3684-e2e-6-two-sessions.json: inject session = C2's TermLink id; C1 busy at check; `c1_pty_has_line: false`, `c1_pty_has_any_sidecar_line: false`; `c2_pty_has_line: true` |

## 3. T-3684

| AC | status | evidence |
|---|---|---|
| R3, R5 built with evidence | MET | architecture §7 rows R3, R5 |
| supervised tick every SIDECAR_TICK (default 30), checks receiver AND hub topic(s) | MET | watcher.py:405; unit `test_tick_default_30_env_and_framework_yaml`, `test_legacy_topic_consult_is_ingested_once_and_injected`; live fixture asserts `tick_s == 30` |
| urgent regardless; non-urgent when ready; HANDED_OVER on transcript; sender informed | MET | live test_3; test_1 sender ledger HANDED_OVER `by: peer-receiver:…`; hub senders get a HANDED_OVER receipt (test_2) |
| live: idle ≤60 s; busy only after turn end; urgent while busy; legacy ≤60 s; watcher disabled → no pickup + ESCALATED | MET (live) | §4 |
| `fw sidecar latency` median/p95/max, figures here | MET | §4, docs/reports/T-3684-latency-A.txt, -B.json |
| receipt telemetry on every path; 3 timestamps in latency; live legacy → RECEIVED at sender ≤60 s | MET | three hub-topic take-off paths: watcher (live test_2, run 10: RECEIVED at sender 14.90 s, HANDED_OVER 16.34 s; test_2b: RECEIVED 27.64 s, HANDED_OVER 29.07 s, REPLIED 34.59 s, latency row `path: hub`, `send_to_replied_s` set), prompt-hook peek (live test_2c: RECEIVED 4.05 s + HANDED_OVER 4.06 s at the sender), `fw sidecar inbox` drain (unit, RECEIVED only — by design, see §0a #1); unit tests/unit/test_sidecar_receipts_t3684.py (real receivers over HTTP for the direct leg; drain, real peek hook, forged header refused, failed reply → no REPLIED, detached flush, hub fallback consumed as a receipt, wrong-peer refused) |
| codex VERDICT: PASS | this review | |

## 4. Measured latencies (run 10, 2026-10-03, code bf07a0255, default 30 s tick, model haiku)

From component-written ledgers: A's `direct-ack.jsonl` / `receipts.jsonl` / outbox
`created_at`, B's receiver `events.jsonl`, the hub's own post timestamp.

| case | send→RECEIVED | send→HANDED_OVER | delivered by |
|---|---|---|---|
| idle, non-urgent (test_1) | 0.01 s | **1.44 s** | on-store inject |
| legacy hub topic (test_2) | ingest 14.87 s; **at the sender 14.90 s** | 16.28 s (at sender 16.34 s) | tick |
| legacy + reply (test_2b) | 27.64 s at sender | 29.07 s at sender; **REPLIED 34.59 s** | tick |
| legacy, prompt-hook peek, no sidecar (test_2c) | **4.05 s at sender** | 4.06 s at sender (transcript-proven, D's `66ea86ac….jsonl`) | operator prompt 3 s after send |
| busy, non-urgent (test_3) | ≈0.01 s | 104.8 s (turn ran ~87 s); injected **17.3 s after the turn ended** | tick |
| busy, urgent, direct (test_3) | ≈0.01 s | typed **0.73 s** after send while busy (`urgent_bypass`, line in the busy PTY); HANDED_OVER 78.3 s (when the busy turn ended) | on-store, urgent bypass |
| busy, urgent, hub topic (test_3 `hub_urgent`) | — | typed on the next tick while busy (`trigger: tick`, `urgent_bypass: true`, `busy_at_inject: true`) | tick, urgent bypass |
| two sessions (test_6) | — | STORED→HANDED_OVER 1.43 s into idle C2 (`transcript:bf52bfe5….jsonl` = C2) | on-store |
| hung watcher (test_4) | — | doctor FAIL at 74 s, audit FAIL at 78 s, supervisor replaced it after **96.6 s** | supervisor |

Runs 8 (e9c6bbb46) and 9 (f7c7f1d2c) gave the same picture: idle 2.15 / 1.43 s;
legacy RECEIVED at sender 13.30 / 16.86 s; 2b REPLIED 31.47 / 34.83 s; peek 4.04 /
4.01 s; urgent typed 0.12 / 0.054 s; non-urgent 16.2 / 17.7 s after turn end; hung
healed 96.3 / 96.7 s.

The 60 s bound: idle pickup on the direct path is on-store (≈1.5 s); on the hub
path it is bounded by one tick (30 s) + inject; measured 13–28 s over runs 8–10.
The tests assert `<= 60` on measured values; they do not prove a worst case.

`fw sidecar latency` per run-10 project: docs/reports/T-3684-latency-A.txt (all four
projects, text) and docs/reports/T-3684-latency-B.json (B of pair 1, JSON). Pooled
figures include the deliberately delayed busy and negative-control messages:
```
pair 1 A outbound (4): send→RECEIVED median=9.476s p95=27.645s max=27.645s
                       send→HANDED_OVER median=10.2s p95=29.072s max=29.072s
                       send→REPLIED n=2 median=44.903s max=55.219s
pair 1 B inbound  (3): send→RECEIVED median=14.867s max=27.607s
                       send→HANDED_OVER median=16.279s max=29.005s; send→REPLIED 34.549s
pair 2 A outbound (6): send→RECEIVED median=0.366s p95=117.689s max=117.689s
                       send→HANDED_OVER median=91.591s p95=119.406s max=119.406s
pair 2 B inbound  (5): send→RECEIVED median=0.686s max=117.624s
                       send→HANDED_OVER median=104.847s max=119.364s
```

**Limitation — urgent while busy.** The line is typed into the busy session at once,
but Claude Code queues input typed during a turn; the prompt hook (and HANDED_OVER)
fires when the turn ends. Injection is immediate; the agent seeing it is bounded by
the current turn. Interrupting would need Escape, which could abort tool work and the
design does not ask for.

## 5. T-3685

| AC | status | evidence |
|---|---|---|
| R7, R14, R15 built with evidence | MET | §7 rows; R14 = every claude-fw session (termlink or not) AND every other launch (plain `claude`, IDE, worker) via the SessionStart hook `sidecar-autostart` (bb823a983; an explicit `fw sidecar stop` is respected — this repo's own sidecar is in that state, so doctor WARNs here); doctor/audit WARN wherever none runs |
| each tick: seq+1, loopback probe, liveness.yaml fields | MET | watcher.py:405/:281/:326; unit `test_tick_injects_into_the_ready_session_and_writes_liveness` (real receiver process) |
| started with receiver; restarted when killed; reboot via repo pattern; in `fw sidecar status`; claude-fw gets one; inert+visible without TermLink | MET | unit `test_start_supervises_restarts_and_ensure_recovers` (real processes/signals; `fw sidecar status` shows `watcher: live … supervisor=up`), `test_claude_fw_really_starts_the_sidecar[--termlink / plain]` (runs the real bin/claude-fw with a stub claude, PATH without termlink → live supervised watcher, `termlink: absent`, inert line printed), `test_supervisor_restarts_a_dead_receiver`, `test_receiver_start_starts_the_watcher_and_receiver_stop_stops_it`. Reboot: @reboot cron line (no reboot performed). |
| doctor + audit FAIL when not live; live kill → not-live reported → supervisor restarts | MET (live) | T-3684-e2e-4-kill.json `hung`: watcher SIGSTOPped → doctor `FAIL Sidecar watcher NOT live: seq stalled at 6 for 74s (> 2 ticks of 30s)`, audit `[FAIL] Sidecar watcher NOT live` (78 s) → supervisor replaced it by itself after 96.6 s (run 10) (`WATCHER_HUNG_KILLED` event) → live. Also: SIGKILL watcher → respawned in seconds; SIGKILL supervisor+watcher → doctor FAIL → `ensure --all` (the cron command) → doctor `OK … live` |

## 6. Live incident during this work (disclosed)

Round-1's plain-terminal fallback let this repo's prompt hook (in MY dispatch-worker
session) take a peer consult from 055-agentic-fleet-cockpit: this repo has a receiver
but no injector decision on record. Fixed in 7619e1c08 (fallback only on a positive
"no session registered" decision and never in a headless session; three unit tests).
The consult was answered factually by me (`fw sidecar send … --in-reply-to
60c17fc4…`), stating it reached a worker, answering only the factual part, and
leaving its decisions to the operator.

## 7. Fakes, honestly

Round 2 called the round-2 version of this section inaccurate. The full list of what
unit tests substitute:
- the `termlink` binary (a recorded runner) and, in tick/ingest tests, the hub
  reader (a recorded hub);
- some tests write a transcript attachment themselves to drive the finalizer
  (session-attribution, receiver, peek-hook tests) — they test the transcript
  CHECK, not that a model saw anything;
- `receipts.send` is replaced by a list in `test_failed_reply_sends_no_replied` and
  `test_legacy_sender_gets_a_handed_over_receipt_not_a_skip` (they test WHICH receipt
  is requested; delivery of receipts is tested separately with real receivers over
  HTTP in `test_received_handed_over_replied_reach_a_live_sender_receiver`,
  `test_inbox_drain_really_sends_…`, `test_detached_flush_sends`);
- `_cmd_send` is replaced (rc 0 / 1) in `test_failed_reply_sends_no_replied`;
- the peek-hook tests use a stub `fw` whose `sidecar inbox --peek --json` prints a
  fixed payload; the hook script itself and `receipts-flush` are real;
- latency unit tests write synthetic ledger timestamps: they test the arithmetic,
  not delivery latency;
- fixtures pin `_claude_ancestor_pid` → None (not headless), see §0.

Receivers, supervisors, watchers, the CLI and claude-fw run as real processes.
Every latency figure in §4 comes from the live suite, which writes no ledger,
transcript or receipt itself: its JSON serialises what the components and Claude
Code wrote. Hermetic guard: tests/unit/conftest.py sets FW_SIDECAR_ENABLED_DIR /
FW_SIDECAR_REGISTRY_DIR / TERMLINK_RUNTIME_DIR to tmp for every `test_sidecar_*` module.

## 8. Runs 1–10

1. haiku ran `sleep 90` in the background (busy precondition false); a watcher
   SIGKILLed mid-tick left no INJECT_ATTEMPT → INJECT_TYPING added.
2. Claude Code's Bash tool refuses a bare `sleep N` → python sleep; e2e asserts the
   session is still busy 8 s later.
3. 6/6 — before the receipts AC was added to the task.
4. 7/7 — but the hook fix in §6 landed mid-run.
5. 6/7 — haiku declined to run a peer-requested reply command → test_2b: the
   operator asks the agent to reply (reply still via the real CLI).
6. 7/7 on 3ec45b45e (round-2 evidence).
7. 7/8 on bb823a983 — an em dash in test_2c's operator prompt left it
   unsubmitted (`docs/reports/T-3684-e2e-run7.log`) → ASCII prompts (e9c6bbb46).
8. 8/8 on e9c6bbb46 (`docs/reports/T-3684-e2e-run8.log`).
9. 8/8 on f7c7f1d2c (`docs/reports/T-3684-e2e-run9.log`).
10. 8/8 on bf07a0255 (`docs/reports/T-3684-e2e-run10.log`) — the evidence in §4.

## 9. Not done / deferred

- No reboot performed; reboot survival rests on the installed @reboot line.
- This framework repo's own sidecar is in the explicitly-stopped state (`fw sidecar
  stop`), which the SessionStart autostart respects; `bin/fw sidecar start` turns it
  on — operator's call. Doctor WARNs.
- The 2c peek path, the 2b reply and the busy case each need an operator prompt
  (the e2e types it into the real session as the operator would); nothing in them
  is written by the test itself.
- Legacy-topic retirement: T-3690 (exists, active).
