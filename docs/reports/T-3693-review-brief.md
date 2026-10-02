# T-3693 Review Brief — arc-011 sidecar slice 1 (finishing T-3561)

**Date:** 2026-10-02 · **Task:** `.tasks/active/T-3693-arc-011-sidecar-s1-finish-t-3561-closed-.md`
**Commits:** `801c9c253` (receiver, hooks, injection, sender path, unit tests, vendored copies) ·
`70d2946c2` (live e2e + negative control) · `82ce0b483` (brief + evidence) · `7f46f6515`
(codex round-1 fixes) · this round's commit (codex round-2 fixes + a defect found live; see §Round 3).
The previous worker's `8558988a0` / `bf6d38b47` / `9e7c932ba` are superseded where noted.

Reviews so far: `docs/reports/T-3693-review-codex-round1.md` (FAIL: AC5, AC7) and
`docs/reports/T-3693-review-codex-round2.md` (FAIL: AC4, AC7). Every finding is addressed below.

---

## What the previous worker left, verified and fixed

| Found | Fix |
|---|---|
| Any non-empty bearer token accepted; env-var fallback | `hmac.compare_digest` against `receiver.token` (`lib/sidecar/http_server.py:55-60`) |
| Token written AFTER the port opened (T-3475: before) | token first (`lib/sidecar_cli.py:451`); server refuses without one (`http_server.py:131-148`) |
| Prompt hook marked HANDED_OVER before printing; errors to `/dev/null` | `lib/sidecar/hooks.py` (below) |
| No injection code | `lib/sidecar/inject.py` |
| Reused id with different content accepted, and a test asserting that | content hash → `conflict` (`receiver.py`); test now asserts rejection |
| `tests/unit/t3561_e2e_nonce.py` wrote agent B's reply itself | deleted (`801c9c253`) |

---

## Acceptance criteria

### AC1 — `fw sidecar receiver start|stop|status` — **MET**
- `lib/sidecar_cli.py:428` start: writes the 0600 token FIRST (`:451` →
  `lifecycle.write_token`, created `O_EXCL` 0600). It then spawns `lib/sidecar/http_server.py`,
  which refuses to bind without the token (`http_server.py:142-148`). After binding it writes the
  pid/port/url triple-file and a host registry entry. The CLI waits for `/health`.
- `:489` stop: SIGTERM, wait, SIGKILL only if needed; removes the triple-file and the registry entry.
- `:517` status: pid/port/url, `/health`, inject enabled, awaiting count, ready flag.
- Tests (`tests/unit/test_sidecar_receiver_t3693.py`, real receiver subprocesses):
  `test_receiver_start_writes_token_0600_triple_file_and_registry`,
  `test_receiver_status_reports_pid_port_url_and_health`, `test_receiver_stop_is_clean`,
  `test_server_refuses_to_open_a_port_without_a_token`.

### AC2 — Stop sets ready; UserPromptSubmit clears it FIRST, then surfaces — **MET**
- `lib/sidecar/hooks.py:79` `stop()` → `adapter.set_ready_for_input(True)`.
- `hooks.py:147` `prompt()`: `:153` clears ready first. It then emits the stored, not-yet-handed-over
  messages as `additionalContext` framed as untrusted data (PEER-DATA markers that a body cannot
  close early), flushes (`:164`), starts the detached finalizer (`:172`) and exits.
- The ready-flag write is an atomic replace with **no fsync** (`lib/sidecar/adapter.py:53`).
  See §Round 3 for why.
- Wrappers `agents/context/sidecar-receiver-ready.sh` / `sidecar-receiver-adapter.sh` pass stdin
  through and log errors to `.context/sidecar/receiver/hook-errors.log`.
- Tests: `test_stop_hook_sets_ready_via_fw_hook` (real `bin/fw hook`),
  `test_prompt_hook_clears_ready_before_reading_messages` (a spy at the read sees `ready=False`),
  `test_prompt_hook_surfaces_untrusted_then_hands_over_and_confirms`,
  `test_prompt_hook_via_fw_hook_wrapper_exits_fast_and_finalizes` (real wrapper, real detached finalizer).

### AC3 — registered in `.claude/settings.json` + consumer template; baseline — **MET**
- `.claude/settings.json:241` (Stop, alongside `stop-driver.sh`), `:256` (UserPromptSubmit,
  alongside `sidecar-inbox`); `lib/init.sh:1234` and `:1239-1249`.
- `bin/fw enforcement baseline` re-run (`801c9c253`). `bin/fw enforcement status` →
  `✓ Baseline set (e19fd6564856929a...)`; codex recomputed the hash independently in both rounds.
- `stop_driver.bats` 19/19 ok; `upgrade_fresh_machine_simulation.bats` 13/13 ok (required for
  `lib/init.sh` edits). Test: `test_hooks_registered_in_settings_and_consumer_template`.

### AC4 — ONE line injected when pending + ready; HANDED_OVER only when the hook actually surfaced it — **MET**
(The AC wording was corrected to the operator directive; see the task's `## Decisions`.)
- `lib/sidecar/inject.py:129` `_deliver_locked`, under an flock. It resolves the session by the
  `fw-project=<sha256(root)[:16]>` tag that `bin/claude-fw:70-101` now registers, else a
  `claude`-tagged session with cwd == project root. Zero or several matches → no inject, and an
  INJECT_BLOCKED event records why (`:80` "refusing to guess"). Readiness is cleared before typing
  (`:156`), then one `termlink pty inject <session> <line> --enter` (`:159`).
- **One line, guaranteed** (round-2 finding 1): ids must match `[A-Za-z0-9_:-]{1,128}` at
  ingress (`receiver.py:57`, so a newline id → HTTP 400 REJECTED), and `injection_line`
  (`inject.py:104`) strips every id to `[A-Za-z0-9-]` again and asserts the line is printable.
  The line never carries peer content. Tests: `test_unsafe_ids_rejected_at_ingress[×8]`,
  `test_unsafe_id_rejected_over_real_http`, `test_injection_line_is_one_printable_line_whatever_the_ids`.
- **HANDED_OVER** is written only by `hooks.finalize` (`hooks.py:202`, `:223`). It runs only when
  the session transcript (`transcript_path` from the hook input) holds a
  `hook_additional_context` attachment carrying `[msg <id>]` (`_in_transcript`, `:180`), i.e. the
  harness's own record that the model was given it. The injector records INJECT_ATTEMPT only;
  printing records nothing. With no evidence → HANDOVER_UNCONFIRMED (`:230`), and the message is
  released (`.injected`/`.surfacing` removed) for re-surfacing and re-injection.
- Triggers: on store (`http_server.py:107`) and `fw sidecar deliver-pending` (`sidecar_cli.py:544`).
  Urgent bypasses readiness (`inject.py:142`).
- Unit (termlink binary stubbed; injector real): `test_inject_one_line_when_ready_and_never_hand_over`,
  `test_no_inject_when_not_ready`, `test_urgent_bypasses_readiness`,
  `test_no_matching_session_leaves_message_flagged[×2]`, `test_two_matching_sessions_refuse_to_guess`,
  `test_cwd_fallback_matches_claude_session`, `test_injection_disabled_blocks`,
  `test_no_transcript_evidence_means_no_hand_over_and_release`,
  `test_finalizer_waits_for_the_transcript_to_catch_up`.
- Live, real TermLink: `tests/integration/t3693_sidecar_e2e_test.py::test_real_termlink_inject_reaches_the_tagged_session`
  drives the real `bin/fw sidecar deliver-pending` CLI into a real tagged PTY. The line appears;
  INJECT_ATTEMPT, no HANDED_OVER. PASSED.
- Live e2e: every HANDED_OVER carries `evidence: transcript:<session>.jsonl`:
  ```
  A STORED · A INJECT_ATTEMPT on-store · A HANDED_OVER transcript:b9821d75-….jsonl · A CONFIRM_SENT
  B STORED · B INJECT_ATTEMPT on-store · B HANDED_OVER transcript:3a6f6989-….jsonl · B CONFIRM_SENT
  ```

### AC5 — REAL e2e: two real Claude sessions; A generates the nonce; B's prompt never mentions it — **MET**
`tests/integration/t3693_sidecar_e2e_test.py::test_e2e_two_real_agents_nonce_round_trip`
- Two scratch projects, each running `fw sidecar receiver start`, with a `.claude/settings.json`
  that registers only the two framework hooks, and a real `bin/claude-fw --termlink --no-restart
  --model sonnet hello` session found through its `fw-project` tag.
- **A generates the nonce in its own session** (`:301` operator instruction). A ran
  `N=$(head -c 4096 /dev/urandom | tr -dc a-z | head -c 12); … fw sidecar send … --body "Nonce check $N: …"`.
  **The test never chooses the nonce.** It learns it by observing B's receiver store (`:176`).
- **B's only prompts: `hello` and the injected `[sidecar] …` line.** B's model then issued
  `fw sidecar send --to t3693a-69ukz9 … --in-reply-to d08e401c-… --body 'AWBDZVLBQBLU'`, and A's
  model said: *"The peer replied `AWBDZVLBQBLU`. That is my nonce `awbdzvlbqblu` in uppercase,
  so the check passed."* (`docs/reports/T-3693-e2e-transcript-excerpts.txt`).
- **The pass condition** (`:332`): the UPPERCASE string, which the test never writes, must be in
  A's receiver store AND in A's transcript inside the PEER-DATA block of a
  `hook_additional_context` attachment (`_surfaced_in_transcript`, `:151`).
- Captured (`docs/reports/T-3693-e2e-run.log`, `T-3693-e2e-positive-evidence.json`):
  ```
  [t3693-e2e 03:33:11] observed A's nonce on the wire at B's receiver: awbdzvlbqblu
  "elapsed_s": 12.5,
  "transformed_nonce_in_A_receiver": "b7c910ed-5883-4345-b802-fd7d1d5abc3a",
  "transformed_nonce_in_A_context": "b9821d75-….jsonl [hook_additional_context] PEER-DATA block: 'AWBDZVLBQBLU'",
  PASSED
  ```
- Reliability after the round-3 fix: 5/5 positive runs passed (12.5, 17.7, 11.8, 11.5, 11.6 s).
  All injections were `on-store`; the harness's 5 s `deliver-pending` loop (labelled as T-3684's
  stand-in) never had to deliver.

### AC6 — negative control: injection disabled → FAIL, sender sees ESCALATED — **MET**
`::test_e2e_negative_control_injection_disabled_fails_and_escalates` runs the SAME
`run_round_trip()` with B's receiver started `--no-inject`. It asserts that A's nonce reached B's
receiver, that `not result.passed`, and that A's ledger reads SENT → RECEIVED → ESCALATED with no
HANDED_OVER and no REPLIED, set by infrastructure.
- Captured (`T-3693-e2e-negative-evidence.json`): A generated `lrdbvcksduye`, and it reached B's
  receiver. A's ledger `SENT/sender, RECEIVED/receiver-response, ESCALATED/infrastructure`. B's
  events: STORED, then INJECT_BLOCKED "injection disabled (receiver started with --no-inject)"
  on-store and on every tick. B's transcript: only `hello`. A said "I haven't seen a reply yet."
  PASSED.

### AC7 — sender ledger SENT → RECEIVED → HANDED_OVER → REPLIED, each by the party that can know it — **MET**
`lib/sidecar/direct.py`:
- SENT by the sender (`:191`); RECEIVED from the receiver's HTTP response (`:205`).
- HANDED_OVER only through `confirm_from_peer` (`:235`), reached through our receiver's `/ack`
  (`http_server.py:110`). The peer's finalizer posts that only after transcript evidence. It is
  accepted only if this ledger SENT the id, the confirming peer IS the original recipient, and the
  message is not already HANDED_OVER/REPLIED.
- REPLIED only through `note_reply` (`:258`), by our own receiver, and only from the original recipient.
- **Out-of-order rows cannot regress the state** (round-2 finding 2). The rows come from three
  processes and may arrive out of order: the peer can confirm before our send call writes
  RECEIVED. The state is therefore the **highest-ranked** row (`RANK`, `:57`; `_effective`,
  `:110`), not the newest, so a late RECEIVED never undoes HANDED_OVER/REPLIED and the sweep never
  escalates a handled message. A late HANDED_OVER after ESCALATED still counts (truth arriving
  late). The ledger keeps every row in arrival order.
- Tests: `test_received_then_replied_ledger_order`, `test_confirm_only_from_the_original_recipient`,
  `test_late_or_repeated_confirm_never_regresses`, `test_late_confirm_after_escalation_is_recorded`,
  `test_reply_only_from_the_original_recipient`, `test_peer_cannot_confirm_an_unknown_message`,
  `test_late_received_never_regresses_a_handed_over`, `test_late_received_never_regresses_a_reply`.
- Live: A's ledger `[SENT/sender, RECEIVED/receiver-response, HANDED_OVER/peer-receiver:t3693b-69ukz9,
  REPLIED/own-receiver]`.
- Trust model: same-host. The peer authenticates with our 0600 token, and its name is checked
  against the SENT row. Cross-host signed identity is T-3688.

### AC8 — UNDELIVERABLE, REJECTED, ESCALATED — **MET**
- UNDELIVERABLE (`direct.py:218`): `test_receiver_down_spends_budget_then_undeliverable` SIGKILLs a
  real receiver (its registry entry survives, as after a crash) → 3 attempts, 2 backoffs.
- REJECTED: wrong token → real 401, `test_bad_token_rejected_never_stored_never_injected` (nothing
  stored, so nothing can be injected); id reuse → 409; unsafe id → 400.
- ESCALATED: `escalate_expired` (`:291`) via `fw sidecar sweep`;
  `test_escalated_by_sweep_when_handover_deadline_passes` (real CLI); live in AC6.
- Every non-success row also goes to `.context/sidecar/refusals.jsonl` for T-3555 (unshipped).
  The handoff note is appended to `.tasks/active/T-3555-*.md`.

### AC9 — all tests pass — **MET**
```
$ python3 -m pytest tests/integration/t3693_*.py -v -s
…::test_real_termlink_inject_reaches_the_tagged_session PASSED
…::test_e2e_two_real_agents_nonce_round_trip PASSED
…::test_e2e_negative_control_injection_disabled_fails_and_escalates PASSED
======================== 3 passed in 372.67s (0:06:12) =========================
$ python3 -m pytest tests/unit -k sidecar -q
217 passed, 3968 deselected
$ python3 -m pytest tests/unit/test_sidecar_receiver_t3693.py tests/unit/t3561_adapter.py tests/unit/t3561_receiver_storage.py -q
56 passed
```
The live tests skip loudly ("T-3693 LIVE E2E NOT RUN … a skip here proves nothing") when
termlink, claude or tmux is missing, and the Verification line refuses `SKIPPED`.

### AC10 — vendor check, baseline, lint — **MET**
`bin/fw vendor self --check` → `in sync` (rc 0). `bats tests/lint/` → 118 ok, 0 not ok (re-run
before the final commit). Baseline: AC3.

---

## Round 3 — a defect the live runs found (not raised by codex)

With the round-2 code, 2 of 8 positive runs failed. The PTY capture now in the evidence
(`docs/reports/T-3693-e2e-failed-run-hook-timeout.json`) showed B's screen:
*"UserPromptSubmit hook [fw hook sidecar-receiver-adapter] timed out after 30s — output
discarded"*. B saw only the notice, and A's ledger (correctly) went to ESCALATED. B's files showed
the hook had printed and written `.pending` (HANDED_OVER) at 03:22:54.29, then stalled in the next
fsync (btrfs, load average ~28). **So the receiver held a false HANDED_OVER for a message the model
never received, and it would never have been re-delivered.** The root cause: Claude Code uses a
hook's stdout only if the process exits within its timeout, so any record written inside the hook
is premature.

Fix: no fsync on the hook's critical path (`adapter.py:53`). The hook prints and exits. A detached
finalizer records HANDED_OVER only on the transcript's own `hook_additional_context` evidence,
otherwise HANDOVER_UNCONFIRMED plus release (AC4). After the fix: 5/5 positive runs, and the full
file passed (3/3).

## Review findings → changes

| Round | Finding | Change |
|---|---|---|
| 1 | AC5: harness generated the nonce | A generates it; test observes it on the wire |
| 1 | AC5: loose transcript match | strict attachment + PEER-DATA block check |
| 1 | AC7: any peer could confirm; regressions; any sender REPLIED | recipient identity + no-regression in `confirm_from_peer` / `note_reply` |
| 1 | legacy t3561 tests overclaimed | deleted/replaced/renamed (`test_adapter_set_ready_for_input`, `test_adapter_clear_ready_for_input`, `test_missing_or_unreadable_flag_reads_not_ready`, `test_hostile_payload_stored_verbatim`) |
| 1 | `deliver-pending` CLI only tested empty | live TermLink leg now goes through the real CLI |
| 1 | T-3555 handoff unconfirmed | Updates notes appended to T-3555 and T-3684 |
| 2 | AC4: ids could carry a newline into the "one line" | ingress charset + sanitised, asserted-printable line |
| 2 | AC7: late RECEIVED could regress HANDED_OVER/REPLIED | effective state = highest rank |
| 3 (live) | hook killed after printing → false HANDED_OVER | transcript-evidenced detached finalizer; no fsync in the hook path |

## Scope fence — every deferral, owner exists and is active

| Not built here | Owner | Check |
|---|---|---|
| 30 s tick driver (R3); this slice provides `fw sidecar deliver-pending` for it | **T-3684** | `.tasks/active/T-3684-*.md`, handoff note appended |
| Urgent bypass as a register row (R5). The inject-time bypass exists (`inject.py:142`) | **T-3684** | register R5 `owner_task: T-3684` |
| Always-on per-agent sidecar / liveness (R7, R14, R15) | **T-3685** | `.tasks/active/T-3685-*.md` |
| Cross-host delivery and signed peer identity | **T-3688** | `.tasks/active/T-3688-*.md` |
| Consumer rollout (template entries ARE added to `lib/init.sh`) | **T-3689** | `.tasks/active/T-3689-*.md` |
| Refusal ledger ingestion of `.context/sidecar/refusals.jsonl` | **T-3555** | `.tasks/active/T-3555-*.md`, handoff note appended |
| Register rows R2/R4/R6 → `built` (document owned by T-3694; this task may not edit it) | **T-3694**, asked via `fw sidecar send` (conversation `t3693-register-rows`) | see below |

**Register state at writing.** `python3 lib/design_register.py close-check` reports R2, R4 and R6
as "owned by T-3693 and still in-progress/partial". All three are built (R2 = AC4 on-store
injection; R4 = AC2; R6 = AC7). Only the document is stale; its owner has been asked to mark them
built, and has not answered yet. **T-3693 does not close until that check is clean.**

## Not mine, found on the way (pre-existing, not fixed here)

`tests/unit/sidecar_audit_rail.bats` has 6 failures. The nightly record already lists them
(`.context/audits/unit-suite/LATEST.yaml:442`). The cause is T-3561's `INJECTED_NOW`→`HUB_ACCEPTED`
rename: `lib/sidecar-audit.sh:48` still counts `INJECTED_NOW`. Neither file is touched by T-3693.
