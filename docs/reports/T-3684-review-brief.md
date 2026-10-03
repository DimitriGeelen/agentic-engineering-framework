# T-3684 / T-3685 / T-3745 — review brief (sidecar watcher), round 2

Independent-review input. Every claim points at code (file:line), a test, or a
recorded artefact. Live evidence: **run 6** of
`tests/integration/t3684_sidecar_watcher_e2e_test.py` on committed HEAD 3ec45b45e —
**7 passed in 562 s** (log `docs/reports/T-3684-e2e-run.log`; per-test JSON
`docs/reports/T-3684-e2e-*.json`). Runs 1–5 are described in §8: each found a real
problem.

Commits: 41a55a515, 7619e1c08 (T-3745); 2e7bdc0ab, 5d0aac008, a2c5c188d, e3f76a1e5,
3ec45b45e (T-3684); 7fb5ba890 (T-3685).

## 0. Round-1 findings (docs/reports/T-3684-review-codex.md, FAIL) and what changed

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
| ready keyed by session_id (+transcript_path); inject only into the session whose own flag is ready | MET | unit tests/unit/test_sidecar_session_ready_t3745.py (15 tests: 055 scenario, busy-until-own-Stop, claim-before-typing, dead claude pid, urgent into busy, no-decision-on-record → nothing taken, headless → nothing taken); live test_6 |
| HANDED_OVER only to the injected session, from its transcript | MET | unit `test_handed_over_is_attributed_only_to_the_injected_session`; live test_6: HANDED_OVER evidence `transcript:2bb89747-….jsonl` = C2's session |
| two sessions, one project: idle gets it, busy PTY nothing | MET (live) | T-3684-e2e-6-two-sessions.json: inject session = C2's TermLink id; C1 busy at check; `c1_pty_has_line: false`, `c1_pty_has_any_sidecar_line: false`; `c2_pty_has_line: true` |

## 3. T-3684

| AC | status | evidence |
|---|---|---|
| R3, R5 built with evidence | MET | architecture §7 rows R3, R5 |
| supervised tick every SIDECAR_TICK (default 30), checks receiver AND hub topic(s) | MET | watcher.py:405; unit `test_tick_default_30_env_and_framework_yaml`, `test_legacy_topic_consult_is_ingested_once_and_injected`; live fixture asserts `tick_s == 30` |
| urgent regardless; non-urgent when ready; HANDED_OVER on transcript; sender informed | MET | live test_3; test_1 sender ledger HANDED_OVER `by: peer-receiver:…`; hub senders get a HANDED_OVER receipt (test_2) |
| live: idle ≤60 s; busy only after turn end; urgent while busy; legacy ≤60 s; watcher disabled → no pickup + ESCALATED | MET (live) | §4 |
| `fw sidecar latency` median/p95/max, figures here | MET | §4, docs/reports/T-3684-latency-A.txt, -B.json |
| receipt telemetry on every path; 3 timestamps in latency; live legacy → RECEIVED at sender ≤60 s | MET | live test_2 (RECEIVED at sender 15.95 s, HANDED_OVER 17.38 s), test_2b (RECEIVED 27.7 s, HANDED_OVER 29.2 s, REPLIED 32.2 s, latency row `path: hub`, `send_to_replied_s` set); unit tests/unit/test_sidecar_receipts_t3684.py (7: real receivers over HTTP for the direct leg; drain, peek, detached flush, hub fallback consumed as a receipt, forged/wrong-peer refused) |
| codex VERDICT: PASS | this review | |

## 4. Measured latencies (run 6, default 30 s tick, model haiku)

From component-written ledgers: A's `direct-ack.jsonl` / `receipts.jsonl` / outbox
`created_at`, B's receiver `events.jsonl`, the hub's own post timestamp.

| case | send→RECEIVED | send→HANDED_OVER | delivered by |
|---|---|---|---|
| idle, non-urgent (test_1) | 0.012 s | **1.43 s** | on-store inject |
| legacy hub topic (test_2) | ingest 15.92 s; **at the sender 15.95 s** | 17.32 s (at sender 17.38 s) | tick |
| legacy + reply (test_2b) | 27.72 s at sender | 29.15 s at sender; **REPLIED 32.19 s** | tick |
| busy, non-urgent (test_3) | ≈0.01 s | 102.3 s (turn ran ~90 s); injected **15.0 s after the turn ended** | tick |
| busy, urgent (test_3) | ≈0.01 s | typed **0.051 s** after send while busy (`urgent_bypass`, line in the busy PTY); HANDED_OVER 78.6 s | on-store, urgent bypass |
| two sessions (test_6) | — | ~1.4 s into idle C2 | on-store |

Pooled `fw sidecar latency` (run-6 projects; includes the deliberately delayed
busy and negative-control messages — the negative control's hub post was taken
119 s later when test_5's teardown re-enabled B's watcher):
```
A outbound (8): send→RECEIVED n=8 median=0.011s p95=119.675s max=119.675s
                send→HANDED_OVER n=8 median=53.892s p95=121.416s max=121.416s
                send→REPLIED n=2 median=43.506s p95=54.82s max=54.82s
B inbound  (7): send→RECEIVED n=7 median=0.011s p95=119.613s max=119.613s
                send→HANDED_OVER n=7 median=78.586s p95=121.383s max=121.383s
                send→REPLIED n=1 median=32.159s
```

**Limitation — urgent while busy.** The line is typed into the busy session at once,
but Claude Code queues input typed during a turn; the prompt hook (and HANDED_OVER)
fires when the turn ends. Injection is immediate; the agent seeing it is bounded by
the current turn. Interrupting would need Escape, which could abort tool work and the
design does not ask for.

## 5. T-3685

| AC | status | evidence |
|---|---|---|
| R7, R14, R15 built with evidence | MET | §7 rows; R14 = every claude-fw session (termlink or not) + doctor/audit WARN wherever none runs; a plain `claude` launch has no launcher to hook — the WARN is the rail |
| each tick: seq+1, loopback probe, liveness.yaml fields | MET | watcher.py:405/:281/:326; unit `test_tick_injects_into_the_ready_session_and_writes_liveness` (real receiver process) |
| started with receiver; restarted when killed; reboot via repo pattern; in `fw sidecar status`; claude-fw gets one; inert+visible without TermLink | MET | unit `test_start_supervises_restarts_and_ensure_recovers` (real processes/signals; `fw sidecar status` shows `watcher: live … supervisor=up`), `test_claude_fw_really_starts_the_sidecar[--termlink / plain]` (runs the real bin/claude-fw with a stub claude, PATH without termlink → live supervised watcher, `termlink: absent`, inert line printed), `test_supervisor_restarts_a_dead_receiver`, `test_receiver_start_starts_the_watcher_and_receiver_stop_stops_it`. Reboot: @reboot cron line (no reboot performed). |
| doctor + audit FAIL when not live; live kill → not-live reported → supervisor restarts | MET (live) | T-3684-e2e-4-kill.json `hung`: watcher SIGSTOPped → doctor `FAIL Sidecar watcher NOT live: seq stalled at 8 for 73s (> 2 ticks of 30s)`, audit `[FAIL] Sidecar watcher NOT live` → supervisor replaced it by itself after 97 s (`WATCHER_HUNG_KILLED` event) → live. Also: SIGKILL watcher → respawned in seconds; SIGKILL supervisor+watcher → doctor FAIL → `ensure --all` (the cron command) → doctor `OK … live` |

## 6. Live incident during this work (disclosed)

Round-1's plain-terminal fallback let this repo's prompt hook (in MY dispatch-worker
session) take a peer consult from 055-agentic-fleet-cockpit: this repo has a receiver
but no injector decision on record. Fixed in 7619e1c08 (fallback only on a positive
"no session registered" decision and never in a headless session; three unit tests).
The consult was answered factually by me (`fw sidecar send … --in-reply-to
60c17fc4…`), stating it reached a worker, answering only the factual part, and
leaving its decisions to the operator.

## 7. Fakes, honestly

Unit tests stand in only for the `termlink` binary (recorded runner) and, in tick
tests, the hub reader; some unit tests write a transcript attachment to drive the
finalizer (the live suite never does: it reads real transcripts). Receivers,
supervisors, watchers, the CLI and claude-fw run as real processes. Hermetic guard:
tests/unit/conftest.py sets FW_SIDECAR_ENABLED_DIR / FW_SIDECAR_REGISTRY_DIR to tmp
for every `test_sidecar_*` module.

## 8. Runs 1–5

1. haiku ran `sleep 90` in the background (busy precondition false); a watcher
   SIGKILLed mid-tick left no INJECT_ATTEMPT → INJECT_TYPING added.
2. Claude Code's Bash tool refuses a bare `sleep N` → python sleep; e2e asserts the
   session is still busy 8 s later.
3. 6/6 — before the receipts AC was added to the task.
4. 7/7 — but the hook fix in §6 landed mid-run.
5. 6/7 — haiku declined to run a peer-requested reply command → test_2b: the
   operator asks the agent to reply (reply still via the real CLI).

## 9. Not done / deferred

- No reboot performed; reboot survival rests on the installed @reboot line.
- This framework repo's own sidecar is not started by me (it would change how peers'
  mail is taken here); `bin/fw sidecar start` does it — operator's call. Doctor WARNs.
- Legacy-topic retirement: T-3690 (exists, active).
