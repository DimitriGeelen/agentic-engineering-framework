# T-3684 / T-3685 / T-3745 — review brief (sidecar watcher)

Independent-review input. Every claim points at code (file:line), a test, or a
recorded artefact. Live evidence was produced by run 3 of
`tests/integration/t3684_sidecar_watcher_e2e_test.py` (6 passed in 411 s; log:
`docs/reports/T-3684-e2e-run.log`; per-test JSON: `docs/reports/T-3684-e2e-*.json`).
Runs 1 and 2 are described honestly in §5 — they found two real problems.

Commits: 41a55a515 (T-3745), 2e7bdc0ab (T-3684 watcher), 7fb5ba890 (T-3685 rail fix),
5d0aac008 (live e2e, register rows, vendored copies).

## 1. What was built

| piece | where |
|---|---|
| Per-session readiness (T-3745): Stop/UserPromptSubmit write `.context/sidecar/sessions/<session_id>.json` {session_id, transcript_path, termlink_session = `$TERMLINK_SESSION_ID`, claude_pid, ready} | lib/sidecar/adapter.py:195 `session_identity`, :211 `set_session_ready`, :256 `session_records`; hooks.py:80 `stop` |
| Target choice from per-session records only (project-wide flag no longer consulted) | lib/sidecar/inject.py:148 `choose_target` |
| Claim naming the target session, written BEFORE typing; INJECT_TYPING row before keystrokes | inject.py:113 `_write_claim`, :234 `_deliver_locked`, :271 |
| Prompt hook surfaces only messages claimed for ITS session | hooks.py:189 (`inject.is_claimed_for`, inject.py:99) |
| Watcher tick: hub-topic ingest → inject → escalate → loopback probe → liveness.yaml | lib/sidecar/watcher.py:398 `run_tick`, :228 `ingest_hub`, :274 `self_probe`, :319 `write_liveness` |
| Tick config `SIDECAR_TICK` default 30 | lib/config.sh:266; watcher.py:91 `tick_seconds` |
| Supervisor: respawn on exit, kill+replace on seq stall (hung), restart dead receiver, single-instance locks, orphan adoption | watcher.py:513 `supervise` |
| Liveness predicate (absent / not-live / live) | watcher.py:353 `liveness_verdict` |
| CLI `fw sidecar start|stop|ensure [--all]|liveness|latency|tick`; `receiver start` also starts the watcher (`--no-watcher` to opt out); `receiver stop` stops it first; watcher line in `fw sidecar status` and `receiver status` | lib/sidecar_cli.py:524, :548, :581, :598, :506, :260, :672 |
| Latency report | lib/sidecar/latency.py |
| doctor FAIL/WARN | bin/fw:3460; fact fn lib/sidecar-audit.sh:183 |
| audit FAIL/WARN | agents/audit/audit.sh:4068 `check_sidecar_watcher` |
| Reboot / supervisor death: cron `sidecar-ensure-1m` (every minute) + `sidecar-ensure-boot` (@reboot) → `fw sidecar ensure --all` over the host enabled-registry | .context/cron-registry.yaml:45, :59; generated .context/cron/agentic-audit.crontab; installed /etc/cron.d/agentic-audit-999-agentic-engineering-framework |
| `claude-fw --termlink` starts the sidecar; without TermLink prints "sidecar watcher NOT started — TermLink absent … (inert)" | bin/claude-fw:616 `sidecar_start` |
| Legacy hub-topic senders: CONFIRM-2 recorded as CONFIRM_SKIPPED (no direct ledger to confirm into) | hooks.py:141 |

Supervision pattern choice: the repo has no systemd-user units for framework
daemons; its pattern is the cron registry → /etc/cron.d with flock. The 30 s tick
is a loop in the supervised process; the cron keep-alive restarts supervisors.

## 2. T-3745 acceptance criteria

| AC | status | evidence |
|---|---|---|
| ready-for-input keyed by session_id (+transcript_path); inject only into the session whose own flag is ready, never a busy sibling | MET | adapter.py:211; inject.py:148 (non-urgent: `ready` candidates only). Unit: tests/unit/test_sidecar_session_ready_t3745.py `test_non_urgent_goes_only_to_the_idle_session_never_the_busy_sibling`, `test_busy_session_receives_nothing_until_its_own_stop` (operator's plain-terminal Stop + project flag set → nothing typed). Live: test_6 |
| HANDED_OVER attributed only to the injected session, from its transcript | MET | hooks.py:189 + inject.py:99. Unit `test_handed_over_is_attributed_only_to_the_injected_session` (sibling prompting first gets nothing; evidence `transcript:fleet.jsonl`). Live test_6: HANDED_OVER evidence `transcript:<C2 session_id>.jsonl` |
| Two sessions in one project, one busy one idle → lands in the idle one only; busy PTY receives nothing | MET (live) | docs/reports/T-3684-e2e-6-two-sessions.json: inject `session` = C2's TermLink id, `target_session_id` = C2's Claude session; `c1_busy_at_check: true`, `c1_pty_has_line: false`, `c1_pty_has_any_sidecar_line: false` (last 400 PTY lines), `c2_pty_has_line: true` |

## 3. T-3684 acceptance criteria

| AC | status | evidence |
|---|---|---|
| Register R3, R5 → built with evidence | MET | docs/architecture/sidecar-target-architecture.md §7 rows R3, R5 |
| Supervised loop ticks every SIDECAR_TICK (registry key, default 30); each tick checks receiver flagged messages AND hub inbox topic(s) | MET | watcher.py:398 (ingest_hub then deliver_pending); lib/config.sh:266. Unit `test_tick_default_30_env_and_framework_yaml`, `test_sidecar_tick_is_a_registered_config_key`, `test_legacy_topic_consult_is_ingested_once_and_injected`. Live fixture asserts `tick_s == 30` from B's liveness.yaml |
| Urgent injects regardless of ready; non-urgent only when ready; HANDED_OVER only on transcript evidence; sender informed (CONFIRM-2) | MET | inject.py:148; hooks.py finalize (T-3693, unchanged). Live test_3 (below); test_1: sender ledger row HANDED_OVER `by: peer-receiver:…` |
| Live e2e: idle ≤60 s; busy only after turn end; urgent while busy; legacy topic ≤60 s; watcher disabled → no pickup + ESCALATED | MET (live) | test_1..test_5, numbers in §4 |
| `fw sidecar latency` (median, p95, max) and figures in this brief | MET | lib/sidecar/latency.py; unit `test_latency_reports_median_p95_max_from_ledgers`; output §4 |
| codex review VERDICT: PASS | pending at time of writing | docs/reports/T-3684-review-codex.md |

## 4. Measured latencies (run 3, default 30 s tick, model haiku)

From ledger timestamps (A's sender ledger `.context/sidecar/direct-ack.jsonl`,
B's receiver `events.jsonl`, the hub's own post timestamp for the legacy leg):

| case | send→RECEIVED | send→HANDED_OVER | delivered by |
|---|---|---|---|
| idle, non-urgent (test_1) | 0.01 s | **1.42 s** | on-store inject |
| legacy hub topic (test_2) | 15.9 s (hub post → watcher ingest) | **17.3 s** | tick |
| busy, non-urgent (test_3) | ≈0.01 s | 110.7 s (session busy ~94 s); injected **23.4 s after the turn ended** | tick |
| busy, urgent (test_3) | ≈0.01 s | typed **0.05 s** after send while busy (`urgent_bypass: true`, line visible in PTY while busy); HANDED_OVER 78.5 s | on-store, urgent bypass |
| two sessions (test_6) | — | ~1.4 s into idle C2 | on-store |

`fw sidecar latency` over the run-3 projects (all cases pooled, so skewed by the
deliberately delayed busy and negative-control messages):

```
A outbound (5): send→RECEIVED  n=5 median=0.01s  p95=1.107s  max=1.107s
                send→HANDED_OVER n=5 median=78.52s p95=110.713s max=110.713s
B inbound  (6): send→RECEIVED  n=6 median=0.009s p95=103.716s max=103.716s
                send→HANDED_OVER n=6 median=91.817s p95=110.68s max=110.68s
```
(docs/reports/T-3684-latency-A.txt, docs/reports/T-3684-latency-B.json. The
negative-control message was delivered late after test_5's teardown re-enabled
B's watcher; its ESCALATED row stays, HANDED_OVER ranks above it — direct.py RANK.)

**Limitation, stated plainly — urgent while busy.** The urgent line is typed into
the busy session at once, but Claude Code queues input typed during a turn; the
prompt hook (and so HANDED_OVER) fires when that turn ends. Injection is immediate;
the agent *seeing* it is bounded by the current turn. Interrupting a turn would need
Escape, which the design does not ask for and which could abort tool work.

## 5. T-3685 acceptance criteria

| AC | status | evidence |
|---|---|---|
| Register R7, R14, R15 → built with evidence | MET | §7 rows R7, R14, R15 |
| Each tick increments seq, runs loopback self-probe, writes liveness.yaml {identity, seq, last_probe_at, last_probe_ok, last_probe_latency_ms} | MET | watcher.py:398/:274/:319. Unit `test_tick_injects_into_the_ready_session_and_writes_liveness` (keys, seq, probe latency > 0 against a REAL receiver process), `test_probe_fails_without_a_receiver_and_verdict_is_not_live` |
| Started with the receiver; restarted when killed; survives reboot (repo pattern); in `fw sidecar status`; claude-fw --termlink gets one; inert+visible without TermLink | MET | Unit (real processes, real signals) `test_start_supervises_restarts_and_ensure_recovers` (SIGKILL → respawn; SIGSTOP → stall → not-live → hung watcher replaced; SIGKILL supervisor+watcher → not-live → `ensure --all` → live; `fw sidecar status` shows `watcher: live … supervisor=up`; PATH without termlink → `termlink=ABSENT`, liveness `termlink: absent`), `test_receiver_start_starts_the_watcher_and_receiver_stop_stops_it`, `test_supervisor_restarts_a_dead_receiver`, `test_cron_registry_has_the_keepalive_and_boot_legs`. Live fixture: B's claude-fw log contains "sidecar watcher running", liveness live. Reboot leg is the @reboot cron line; a reboot was not performed. |
| doctor and audit WARN/FAIL when not live; live kill test | MET (live) | docs/reports/T-3684-e2e-4-kill.json: watcher SIGKILLed → respawned (new pid); supervisor+watcher SIGKILLed → doctor `FAIL Sidecar watcher NOT live: seq stalled at 6 for 75s (> 2 ticks of 30s)`, audit `[FAIL] Sidecar watcher NOT live`; `ensure --all` → "supervisor restarted"; doctor after: `OK Sidecar watcher live (seq 7, …)` |

## 6. Runs 1–2: what they found

- Run 1: haiku ran the requested `sleep 90` with run_in_background, so the "busy" turn
  lasted 6 s and test_3 failed its own precondition. Test_4 then SIGKILLed the watcher
  mid-tick, after a line was typed and before INJECT_ATTEMPT was written → fixed:
  INJECT_TYPING row before keystrokes (inject.py:271).
- Run 2: Claude Code's Bash tool refuses a bare `sleep N`; the session ended its turn.
  The e2e now uses `python3 -c 'import time; time.sleep(N)'` and asserts the session is
  still busy 8 s after the prompt, so a weak precondition fails loudly.

## 7. Tests that are NOT live, and why

Unit tests stand in only for the `termlink` binary (a recorded runner for discover /
pty inject) and, in tick tests, the hub reader. Receiver, supervisor, watcher and
CLI are real processes. The live suite exercises real TermLink, a real hub and real
Claude sessions. Hermetic guard: tests/unit/conftest.py sets FW_SIDECAR_ENABLED_DIR
and FW_SIDECAR_REGISTRY_DIR to tmp for every `test_sidecar_*` module.

## 8. Not done / deferred

- No reboot was performed; reboot survival rests on the installed @reboot cron line.
- This framework repo's own sidecar is not started (doctor WARNs "No sidecar watcher
  in this project"): starting it changes how peers' sends to this project route
  (direct instead of hub), which is the operator's call. `bin/fw sidecar start` does it.
- Retiring the legacy topic is T-3690 (exists, active).
