# T-3693 Review Brief — arc-011 sidecar slice 1 (finishing T-3561)

**Date:** 2026-10-02 · **Task:** `.tasks/active/T-3693-arc-011-sidecar-s1-finish-t-3561-closed-.md`
**Commits:** `801c9c253` (receiver, hooks, injection, sender path, unit tests, vendored copies),
`70d2946c2` (real two-agent e2e + negative control, task ACs/Verification). The previous
worker's commits `8558988a0`, `bf6d38b47` and `9e7c932ba` are superseded where noted below.

This replaces the previous worker's brief. That brief marked AC4/AC5/AC6 as not met and
deferred injection to "T-3694", which is the design-conformance task and not an injection
owner. Every claim below names a file:line, a test, or captured output.

---

## What was wrong with what the previous worker left (verified, then fixed)

| Found | Where | Fix |
|---|---|---|
| Any non-empty bearer token was accepted; an env var `SIDECAR_AUTH_TOKEN` was a fallback | old `http_server.py:_is_authorized` | `hmac.compare_digest` against `receiver.token`, `lib/sidecar/http_server.py:55-60` |
| Token written AFTER the port opened (T-3475 says before) | old `sidecar_cli.py:cmd_receiver_start` | token first `lib/sidecar_cli.py:451`; server refuses without one `http_server.py:131-136, 142-148` |
| Stop hook only set a flag through a heredoc with `2>/dev/null`; the prompt hook marked HANDED_OVER *before* printing | old `agents/context/sidecar-receiver-*.sh` | `lib/sidecar/hooks.py`: print, flush, THEN `mark_handed_over` (`hooks.py:134-144`) |
| No injection code at all | — | `lib/sidecar/inject.py` |
| A reused id with different content was silently accepted, and a test asserted that | `receiver.py`, `tests/unit/t3561_receiver_storage.py:85` | content hash → `conflict` (`receiver.py:178`); test now asserts rejection |
| `tests/unit/t3561_e2e_nonce.py` wrote agent B's reply itself | — | deleted in `801c9c253`; replaced by the live test below |

---

## Acceptance criteria

### AC1 — `fw sidecar receiver start|stop|status`
**MET.**
- `lib/sidecar_cli.py:428` `cmd_receiver_start`: writes the 0600 token first (`:451` →
  `lib/sidecar/lifecycle.py:67-84`, created `O_EXCL` with mode 0600 so it is never world-readable),
  then spawns `lib/sidecar/http_server.py`. The server reads the token and refuses to bind
  without it (`http_server.py:142-148`). After binding it writes the pid/port/url triple-file
  and a host registry entry (`lifecycle.py:198`). The CLI waits for `/health` before reporting.
- `:489` `cmd_receiver_stop`: SIGTERM, waits up to 5 s, SIGKILL only if needed; removes the
  triple-file and the registry entry (the server also cleans up on SIGTERM, `http_server.py:150-168`).
- `:517` `cmd_receiver_status`: pid/port/url, `/health`, inject enabled, awaiting count, ready flag.
- Tests (`tests/unit/test_sidecar_receiver_t3693.py`, real subprocess receivers):
  `test_receiver_start_writes_token_0600_triple_file_and_registry`,
  `test_receiver_status_reports_pid_port_url_and_health`, `test_receiver_stop_is_clean`,
  `test_server_refuses_to_open_a_port_without_a_token`.

### AC2 — Stop sets ready; UserPromptSubmit clears it FIRST, then surfaces
**MET.**
- `lib/sidecar/hooks.py:66` `stop()` → `adapter.set_ready_for_input(True)`.
- `hooks.py:123` `prompt()`: line `:127` `adapter.clear_ready_for_input()` is the first
  statement after the activity check. Then it reads the stored messages, emits them as
  `additionalContext` framed as untrusted data (`_frame`, PEER-DATA markers that a body cannot
  close early), flushes (`:136`), and only then calls `mark_handed_over` (`:144`) and sends CONFIRM-2.
- Wrappers: `agents/context/sidecar-receiver-ready.sh`, `agents/context/sidecar-receiver-adapter.sh`
  (stdin passed through, errors logged to `.context/sidecar/receiver/hook-errors.log`).
- Tests: `test_stop_hook_sets_ready_via_fw_hook` (runs the real `bin/fw hook`),
  `test_prompt_hook_clears_ready_before_reading_messages` (a spy on the read sees `ready=False`),
  `test_prompt_hook_surfaces_untrusted_then_hands_over_and_confirms` (hostile body, breakout
  attempt, CONFIRM-2 to a real receiver), `test_prompt_hook_via_fw_hook_wrapper`.
- Live: both e2e agents became ready only through their own Stop hook (`… ready (Stop hook fired)`
  in the run log below).

### AC3 — registration in `.claude/settings.json` (+ consumer template), baseline refreshed
**MET.**
- `.claude/settings.json:241` (Stop, alongside `stop-driver.sh`), `:256` (UserPromptSubmit,
  alongside `sidecar-inbox`).
- `lib/init.sh:1234` (UserPromptSubmit adapter), `:1239-1249` (new Stop block).
- `bin/fw enforcement baseline` re-run in `801c9c253` (`.context/project/enforcement-baseline.sha256`).
  `bin/fw enforcement status` → `✓ Baseline set (e19fd6564856929a...)`.
- `stop-driver.sh` still works: `bats tests/unit/stop_driver.bats` → 19 ok, 0 not ok.
  `upgrade_fresh_machine_simulation.bats` (required for `lib/init.sh` edits) → 13 ok, rc 0.
- Test: `test_hooks_registered_in_settings_and_consumer_template`.

### AC4 — inject ONE line when pending + ready; HANDED_OVER only when the hook surfaced it
**MET.** The AC's wording was corrected to the operator directive. The previous worker wrote
"on success [of the inject] records HANDED_OVER", which the directive and T-3561 AC3 forbid.
Recorded in the task's `## Decisions`.
- `lib/sidecar/inject.py:122` `_deliver_locked`, under an flock: nothing waiting → no-op;
  `--no-inject` → INJECT_BLOCKED; not ready and not urgent → wait; resolve the session (`:58`):
  `fw-project=<sha256(root)[:16]>` tag that `bin/claude-fw:70-101` now adds to the session it
  registers, else `claude`-tagged with cwd == project root. Zero or several matches → no inject,
  INJECT_BLOCKED with the reason (`:79` "refusing to guess"). Readiness is cleared before typing
  (`:149`). Then one `termlink pty inject <session> <line> --enter` (`:152`). The line holds a
  count and ids, never peer content. INJECT_ATTEMPT is recorded; HANDED_OVER is not.
- Triggers: on store (`http_server.py:107`, after the RECEIVED response) and
  `fw sidecar deliver-pending` (`sidecar_cli.py:544`). There is no tick (T-3684).
- Urgent: injects even when not ready (`inject.py:135`), recorded as `urgent_bypass`.
- Unit (termlink binary stubbed; the component under test is real):
  `test_inject_one_line_when_ready_and_never_hand_over`, `test_no_inject_when_not_ready`,
  `test_urgent_bypasses_readiness`, `test_no_matching_session_leaves_message_flagged[×2]`,
  `test_two_matching_sessions_refuse_to_guess`, `test_cwd_fallback_matches_claude_session`,
  `test_injection_disabled_blocks`, `test_deliver_pending_cli` (nothing-waiting path only; the
  CLI-triggered injection is proven live, next bullet).
- Live, real TermLink: `tests/integration/t3693_sidecar_e2e_test.py::test_real_termlink_inject_reaches_the_tagged_session`
  drives the real `bin/fw sidecar deliver-pending` CLI against a real TermLink PTY session tagged
  with the project tag. The line appears in the PTY; events contain INJECT_ATTEMPT and no
  HANDED_OVER. PASSED.

### AC5 — REAL e2e: two real Claude sessions; A generates the nonce; B's prompt never mentions it
**MET.** `tests/integration/t3693_sidecar_e2e_test.py::test_e2e_two_real_agents_nonce_round_trip`.
- Two scratch projects, each with `fw sidecar receiver start`, a `.claude/settings.json` that
  registers only the two framework hooks, and a real `bin/claude-fw --termlink --no-restart
  --model sonnet hello` session found through its `fw-project` tag.
- **A generates the nonce in its own session** (round-2 fix, after codex round 1). The operator
  instruction (`:301`) tells A to run a `/dev/urandom` one-liner and send the result. A's own
  tool call ran `N=$(head -c 4096 /dev/urandom | tr -dc a-z | head -c 12); … fw sidecar send …
  --body "Nonce check $N: …"` and printed `ccmmpycodjyq`. **The test never chooses the nonce.**
  It learns it only by observing the message in B's receiver store (`_nonce_sent_by_a`, `:176`).
- **B's only prompts were `hello` and the injected `[sidecar] …` line.** B's hook surfaced the
  message, and **B's model issued** `fw sidecar send --to t3693a-uu6nns … --in-reply-to
  eb91d596-… --body 'CCMMPYCODJYQ'` (`docs/reports/T-3693-e2e-transcript-excerpts.txt`).
- **The pass condition** (`:332`, `passed = bool(stored and surfaced)`): the UPPERCASE string,
  which the test never writes, must appear in A's receiver store AND in A's transcript.
  `_surfaced_in_transcript` (`:151`, strict since round 2) requires a `hook_additional_context`
  attachment whose text starts `# Sidecar receiver` and whose **PEER-DATA block** contains the
  string. Matching anywhere on the line is no longer enough.
- Captured round 2 (`docs/reports/T-3693-e2e-run.log`, `T-3693-e2e-positive-evidence.json`):
  ```
  [t3693-e2e 02:56:37] A instructed (operator) to generate a nonce and send it to B
  [t3693-e2e 02:56:43] observed A's nonce on the wire at B's receiver: ccmmpycodjyq
  "nonce_generated_by_A": "ccmmpycodjyq",
  "elapsed_s": 11.5,
  "transformed_nonce_in_A_receiver": "406dcbb4-b7d3-4009-a589-b645f1a6c3d4",
  "transformed_nonce_in_A_context": "9891be35-….jsonl [hook_additional_context] PEER-DATA block: 'CCMMPYCODJYQ'",
  PASSED
  ```
  Both injections were `trigger: on-store`; the harness's 5 s `deliver-pending` loop (standing
  in for T-3684's tick, labelled in the test) never had to deliver.

### AC6 — negative control: injection disabled → FAIL, sender sees ESCALATED
**MET.** `::test_e2e_negative_control_injection_disabled_fails_and_escalates` runs the SAME
`run_round_trip()` with B's receiver started `--no-inject`. It asserts that A's nonce reached B's
receiver (so the path was exercised), that `not result.passed`, and that A's ledger reads
`SENT → RECEIVED → … ESCALATED` with no HANDED_OVER and no REPLIED.
- Captured (`T-3693-e2e-negative-evidence.json`): A generated `zkwdzpyfgcgm`, and it reached B's
  receiver. A's ledger: `SENT/sender, RECEIVED/receiver-response, ESCALATED/infrastructure`.
  B's events: `STORED`, then `INJECT_BLOCKED` "injection disabled (receiver started with
  --no-inject)" on-store and on every tick. B's transcript holds only `hello`.
  `transformed_nonce_in_A_*: null` after the full ~300 s window, then `fw sidecar sweep` escalated
  A's message. PASSED.

### AC7 — sender ledger SENT → RECEIVED → HANDED_OVER → REPLIED, each by the party that knows it
**MET.** `lib/sidecar/direct.py`:
- `SENT` by the sender (`:166`). `RECEIVED` from the receiver's HTTP response (`:180`).
- `HANDED_OVER` only through `confirm_from_peer` (`:210`), reached from our receiver's `/ack`
  (`http_server.py:110`), which the peer's prompt hook posts after surfacing. Round-2 hardening
  after codex: accepted only if this ledger SENT the id, the confirming `peer` IS the agent it was
  sent to, and the message is not already HANDED_OVER/REPLIED (no regression, no duplicates). A late
  confirmation after ESCALATED is recorded, because it is the truth arriving late.
- `REPLIED` only through `note_reply` (`:233`), by our own receiver when the answering message
  is stored, and only if it comes FROM the original recipient (explicit `in_reply_to` or same
  peer + conversation).
- Trust model: same-host; the peer authenticates with our 0600 token, and the `peer` name is
  checked against the SENT row. Signed peer identity across hosts is T-3688.
- Live: A's ledger `[SENT/sender, RECEIVED/receiver-response, HANDED_OVER/peer-receiver:t3693b-uu6nns,
  REPLIED/own-receiver]`, asserted after the verdict.
- Unit: `test_received_then_replied_ledger_order`, `test_confirm_only_from_the_original_recipient`,
  `test_late_or_repeated_confirm_never_regresses`, `test_late_confirm_after_escalation_is_recorded`,
  `test_reply_only_from_the_original_recipient`, `test_peer_cannot_confirm_an_unknown_message`.

### AC8 — UNDELIVERABLE, REJECTED, ESCALATED
**MET.**
- UNDELIVERABLE: `direct.py:193` after `retries` attempts with backoff. Test
  `test_receiver_down_spends_budget_then_undeliverable` SIGKILLs a real receiver (its registry
  entry survives, as after a crash) → 3 attempts, 2 sleeps, UNDELIVERABLE.
- REJECTED: 401 from the real server for a wrong token. `test_bad_token_rejected_never_stored_never_injected`
  checks REJECTED in the ledger, a refusals.jsonl row, nothing stored (so nothing can be injected),
  and a receiver REJECTED event. Also 409 for a reused id: `test_reused_id_with_other_content_is_rejected`.
- ESCALATED: `direct.escalate_expired` (`:238`), run by `fw sidecar sweep` (`sidecar_cli.py:269`).
  Test `test_escalated_by_sweep_when_handover_deadline_passes` drives the real CLI; live in AC6.
- Every non-success row is also appended to `.context/sidecar/refusals.jsonl` for T-3555, which
  has not shipped (`direct.py:76`).

### AC9 — all tests pass
**MET** (commands and output):
```
$ python3 -m pytest tests/integration/t3693_*.py -v -s
…::test_real_termlink_inject_reaches_the_tagged_session PASSED
…::test_e2e_two_real_agents_nonce_round_trip PASSED
…::test_e2e_negative_control_injection_disabled_fails_and_escalates PASSED
======================== 3 passed in 370.08s (0:06:10) =========================
$ python3 -m pytest tests/unit -k sidecar -q
203 passed, 3968 deselected in 20.94s
$ python3 -m pytest tests/unit/t3561_adapter.py tests/unit/t3561_receiver_storage.py -q
13 passed
```
(`tests/unit/t3561_*.py` are not collected by a directory run, because they lack a `test_`
prefix, so they are run by path.) The skip is loud: `needs_live` names the missing binaries and
says "a skip here proves nothing"; the Verification line also refuses `SKIPPED`.

### AC10 — vendor check, baseline, lint
**MET.** `bin/fw vendor self --check` → `Self-vendor: vendored .agentic-framework/ in sync with source.`
(rc 0). `timeout 590 bats tests/lint/` → 118 ok, 0 not ok, rc 0. Baseline: see AC3.

---

## Scope fence — every deferral and its owner (all exist and are active)

| Not built here | Owner | Check |
|---|---|---|
| 30 s tick driver (design R3) — this slice gives it `fw sidecar deliver-pending` to call | **T-3684** "arc-011 sidecar S3: 30s inject tick…" | `.tasks/active/T-3684-*.md`, handoff note appended 2026-10-02 |
| Urgent bypass as a *register row* (R5). Inject-time urgent bypass exists (`inject.py:135`); T-3694 pointed R5 at T-3684 | **T-3684** | register R5 `owner_task: T-3684` |
| Always-on per-agent sidecar / liveness (R7, R14, R15) — receivers here are started by `fw sidecar receiver start` | **T-3685** | `.tasks/active/T-3685-*.md` |
| Cross-host delivery (the registry is same-host, token read from a 0600 file) | **T-3688** | `.tasks/active/T-3688-*.md` |
| Consumer install (template entries ARE added to `lib/init.sh`; no upgrade rollout) | **T-3689** | `.tasks/active/T-3689-*.md` |
| T-3555 refusal ledger (rows recorded for it in `.context/sidecar/refusals.jsonl`) | **T-3555** | `.tasks/active/T-3555-*.md`, handoff note appended 2026-10-02 |
| Register rows R2/R4/R6 → `built` (doc owned by T-3694; I may not edit it) | **T-3694** asked via `fw sidecar send` (conversation `t3693-register-rows`) | see below |

**Register state at writing.** `lib/design_register.py close-check` reports R2, R4 and R6 as
"owned by T-3693 and still in-progress/partial". All three are built (AC4/AC2/AC7). Only the
document is stale, and its owner has been asked to set `status: built` with the evidence above.
T-3693 does not close until that close-check is clean. R6's row text still uses the old state
names (stored / injected-now / injected-later); the built states are T-3561's.

## Round-1 review findings and what changed (codex, `docs/reports/T-3693-review-codex.md` round 1: FAIL)

| Finding | Change |
|---|---|
| AC5: the harness generated the nonce; the AC says A generates it | A generates it in its own session; the test observes it on the wire (`:176`, `:301`) |
| AC5: the transcript match was any line with three strings | strict: `hook_additional_context` attachment + nonce inside a PEER-DATA block (`:151`) |
| AC7: any peer could confirm; late confirms could regress REPLIED; any sender could set REPLIED | `confirm_from_peer` / `note_reply` enforce recipient identity and no regression, + 4 tests |
| legacy `t3561_adapter.py` / `t3561_receiver_storage.py` tests overclaimed (no harness, no stale flag, no framing) | `test_ac3_safe_boundary_timing` deleted; `test_ready_flag_freshness` replaced by a real fail-safe test (missing/garbled flag → not ready); the storage-only test renamed `test_hostile_payload_stored_verbatim`; docstrings point at the tests that do prove hook behaviour |
| `test_deliver_pending_cli` only covers "nothing waiting" | the live TermLink leg now injects through the real `fw sidecar deliver-pending` CLI |
| T-3555 handoff unconfirmed | Updates entry appended to `.tasks/active/T-3555-*.md` naming `.context/sidecar/refusals.jsonl`; the same for T-3684 (`deliver-pending`, R3/R5) |

## Not mine, found on the way (pre-existing, not fixed here)

`tests/unit/sidecar_audit_rail.bats` has 6 failures. The nightly unit-suite record already lists
them (`.context/audits/unit-suite/LATEST.yaml:442` `sidecar_audit_rail.bats: 6`). The cause is
T-3561's `INJECTED_NOW`→`HUB_ACCEPTED` rename: `lib/sidecar-audit.sh:48` still counts the
`INJECTED_NOW` key. Neither file is touched by T-3693.
