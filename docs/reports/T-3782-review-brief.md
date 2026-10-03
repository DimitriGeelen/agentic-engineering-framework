# T-3782 review brief — no message goes unnoticed

Task: `.tasks/active/T-3782-no-message-goes-unnoticed-a-consult-wait.md`
Design of record: module docstring of `lib/sidecar/waiting.py`.
Operator ruling (2026-10-03): respawn stays OFF (T-3751 2b, T-3781), so a message for a
dead/absent recipient WAITS — and "what you won't prevent is it goes by unnoticed and it
never gets executed". Recovery may be manual.

## Mechanism in one paragraph

The injector (`lib/sidecar/inject.py:_deliver_locked`) already decides, every 30 s tick and
on every store, whether a session can take each waiting message. Every reason it gives
except "agent not ready" (alive but busy) now means *no live recipient*
(`waiting.is_no_recipient`). For those messages `deliver_pending` calls
`waiting.note_no_recipient` after releasing the inject lock: one receiver event
`WAITING_NO_RECIPIENT` (first decision + time), and a sender receipt of that state through
the existing receipt path (`receipts.send`: sender's live receiver `/ack`, else its hub
inbox topic as a `kind=receipt` post — an install older than this one shows that post as a
short note). The watcher tick (`watcher.run_tick`) then calls `waiting.escalate`, which
pushes (fw_notify) every (item, level) that is due and not yet in
`.context/sidecar/waiting/escalations.jsonl`. Listing = `waiting.open_items()`, read by
`fw sidecar waiting`, the handover section and the Watchtower card. Operator verbs
`fw sidecar recover|drop`. Closure = HANDED_OVER, REPLIED, or drop; nothing ages out.

## Agent ACs → evidence

### AC1 — immediate sender receipt "waiting, no live recipient", every receive path
- Receiver side: `inject.py` `deliver_pending` → `waiting.note_no_recipient`
  (`lib/sidecar/waiting.py`, section "1. receipt"). Both receive paths end in the receiver
  store and the same injector: direct `/message` (`http_server._handle_message` →
  on-store inject thread) and hub topic (`watcher.ingest_hub` → same tick's
  `deliver_pending`).
- New receipt states `WAITING_NO_RECIPIENT`, `DROPPED` in `receipts.STATES`; carried with
  `note` (reason) and `since` (time) on `/ack` and as hub metadata
  `receipt_note`/`receipt_since`.
- Sender side records it for BOTH send paths: hub-path sends in `receipts.jsonl`
  (`receipts.record_from_peer`), direct-path sends in `direct-ack.jsonl`
  (`direct.confirm_from_peer` now accepts WAITING/DROPPED, once each; RANK places WAITING
  between RECEIVED and ESCALATED so the deadline sweep still escalates it, see
  `direct.escalate_expired`). A hub-fallback receipt for a direct-path send is routed to
  the direct ledger by `inbox.pending` (previously dropped).
- Tests: `tests/unit/test_sidecar_waiting_t3782.py`
  `test_direct_path_no_session_sends_waiting_receipt_once_to_live_sender`,
  `test_hub_path_ingested_message_with_no_session_sends_waiting_receipt`,
  `test_sender_without_receiver_gets_it_on_its_hub_topic_as_note_and_records_it`,
  `test_live_but_busy_agent_is_not_no_recipient`. Live: e2e step 2 (sender told in ~2 s).

### AC2 — operator push at the threshold (urgent at once), once per message per level
- `waiting.due_levels`: `warn` at `SIDECAR_CONSULT_WARN_HOURS` (env > .framework.yaml >
  4; non-finite/non-positive ignored), or at once when urgent and no live recipient;
  `overdue` at max(24 h, 2× warn).
- `waiting.escalate`: ledger-deduped by (item key, level); the tick only asks what is due
  and not on the ledger. Push via `lib/notify.sh` `fw_notify`; result recorded honestly as
  `sent` / `disabled` (NTFY off) / `failed:…` — a disabled push still leaves the item
  listed (AC3).
- Tests: `test_push_at_threshold_once_per_level_never_per_tick` (60 ticks → nothing new),
  `test_urgent_with_no_recipient_pushes_at_once`,
  `test_threshold_follows_config_and_a_disabled_push_is_recorded_honestly`,
  `test_the_watcher_tick_escalates`. Live: e2e step 3 (U pushed at once, N at a 72 s
  threshold, exactly 2 pushes after two further ticks).

### AC3 — listed in the handover and on Watchtower /approvals until handled
- Handover: `agents/handover/handover.sh` section "Messages Waiting for a Recipient"
  (runs `sidecar_cli.py waiting`; a listing failure is printed as "Could not be listed",
  never omitted).
- Watchtower: `web/blueprints/approvals.py` `_load_waiting_messages` (subprocess
  `sidecar_cli.py waiting --json`, mtime + 1-minute cache; failure → error card), card in
  `web/templates/_approvals_content.html` `#section-waiting`; counts toward the badge
  (`_approval_counts`).
- Both directions are listed: inbound (our receiver holds it) and outbound (we sent it,
  peer has not handed it over/answered — so a recipient whose whole sidecar is down, which
  can send no receipt, is still noticed by the sender). Outbound before the module's first
  run (epoch) is excluded (hundreds of pre-receipt sends).
- Tests: `test_handover_lists_waiting_messages`,
  `tests/web/test_t3782_waiting_card.py` (card fields, both actions, body never rendered,
  error card). Live: e2e step 4 (real `fw handover` in B).

### AC4 — `fw sidecar recover` (+ button): starts the agent with the message + conversation_id; logged; operator-only; never by a peer
- `waiting.recover`: claims the message (`<id>.recovering`, so the injector and the prompt
  hook skip it — no double delivery), launches `bin/claude-fw --termlink` detached in the
  project root with the first prompt from `waiting.recover_prompt`: a fixed preamble naming
  message id, sender and conversation_id, then the message in the prompt hook's own
  framing (`hooks._frame`, PEER-DATA markers, closer neutralised, body capped). Logged to
  `.context/sidecar/waiting/recover.jsonl` + receiver events.
- `waiting.finalize_recover` (detached): HANDED_OVER only when a session transcript holds
  a USER message starting with the recover token and naming the id; otherwise
  RECOVER_UNCONFIRMED, claim released, message stays listed.
- `bin/claude-fw`: TermLink path now `printf %q`-quotes every argument into the PTY
  line, so a multi-word, multi-line prompt arrives as ONE argument and `$`, quotes and
  newlines stay data (previously `${CLAUDE_ARGS[*]}` re-split on spaces).
- Operator-only: `sidecar_cli._operator` refuses under `CLAUDECODE=1` unless
  `--i-am-human` (recorded `agent-override`); `--from-watchtower` does NOT lift it under
  CLAUDECODE. Watchtower strips CLAUDECODE and posts `--from-watchtower` (CSRF-checked
  route `/api/sidecar/recover`). A peer's only surface is the receiver HTTP API
  (`/message`, `/ack`), which has no recover route; no receipt state names it.
- Tests: `test_recover_starts_agent_with_framed_message_and_suppresses_double_delivery`
  (hostile body stays inside the markers), `test_finalize_records_handed_over_only_on_transcript_evidence`
  (an assistant line quoting the token is not evidence),
  `test_operator_verbs_refused_under_claudecode_even_from_watchtower`,
  `test_a_peer_has_no_route_to_recover`, `test_claude_fw_quotes_each_argument_into_the_pty_line`.
  Live: e2e step 5 (real recovered session; HANDED_OVER with `recover-transcript:` evidence;
  A's ledger shows HANDED_OVER).

### AC5 — closes only on reply / HANDED_OVER / operator drop, never by expiry
- `waiting.is_closed_inbound`: handed over, dropped marker, or replied (REPLIED receipt, or
  a direct reply we sent that the peer RECEIVED). Outbound: HANDED_OVER/REPLIED receipt or
  ledger state, or a drop row. No age-based exclusion exists anywhere in the module; the
  recovering claim's timeout only returns the message to normal delivery (still listed).
- `waiting.drop`: reason required; inbound writes `<id>.dropped` (excluded from
  `receiver.awaiting_handover`), sends a DROPPED receipt to the sender, appends
  `closures.jsonl`.
- Tests: `test_listed_until_handed_over_replied_or_dropped_never_by_age` (400 days later
  still listed), `test_outbound_listed_when_peer_never_hands_over_and_closed_by_receipt_or_drop`.

### AC6 — live test
- `tests/integration/t3782_waiting_recover_e2e_test.py`: real claude-fw session in B
  started then killed (B's sidecar keeps running), real `fw sidecar send` from A (urgent U,
  normal N), assertions in the AC order; negative control N judged over the whole no-agent
  window (listed, not handed over, pushed once). Evidence JSON:
  `docs/reports/T-3782-e2e/`.

## Known limits (stated, not hidden)
- If the recipient project's watcher itself is down, the recipient can neither receipt nor
  push; the sender-side outbound listing/push covers it after the threshold, and
  `fw doctor`/`fw audit` already flag a dead watcher (T-3685).
- A push that the notifier reports `failed` is recorded and not retried (to avoid a push per
  tick); the item stays in the handover and on /approvals.
- Recover starts the agent in THIS project only; for an outbound item it refuses and says
  so (the recipient's project must run it).

## Round 1 (codex, FAIL) → fixes (commit dc362eb1c)
1. AC1: "agent not ready: no session …" (registered PTY, no live agent session) is now
   no-recipient (`waiting.is_no_recipient`, `_NO_LIVE_SESSION`). Test
   `test_dead_agent_in_a_surviving_pty_is_no_recipient_for_a_normal_message`.
2. AC2: `direct.send` records `urgent` on the SENT row; outbound items read it. Test
   `test_urgent_direct_send_is_urgent_on_the_sender_side`.
3. AC3: the outbound cut-off (`waiting.epoch`) is created by `outbox.write_message` and
   `direct.send` before the message exists. Test `test_outbound_cutoff_exists_before_the_first_send`.
4. AC4: peer metadata printed outside PEER-DATA (sender, conversation, id — hook headers,
   reply command, recover preamble, listing/handover/push) goes through
   `hooks.safe_meta`: a value outside `[A-Za-z0-9._:/@=+-]{1,128}` is replaced wholesale
   by `invalid-<sha10>`. Receipt notes are one printable line. Test
   `test_peer_metadata_cannot_carry_instructions_outside_the_markers`.

## Round 2 (codex, FAIL) → fixes
1. AC1: hub ingest no longer loses a message whose store fails after the cursor advanced:
   it is spooled (`receiver/ingest-retry.jsonl`) and retried first on every tick; a
   same-id/different-content post is stored as a second message under its topic/offset
   id (`watcher.ingest_hub`). Tests `test_hub_message_whose_store_fails_is_spooled_and_retried_not_lost`,
   `test_hub_id_reused_with_different_content_is_kept_as_a_second_message`.
2. AC2: urgent pushes at once for every can't-be-taken state, including failed sends
   (undeliverable / rejected / escalated) and recover-unconfirmed (`waiting.due_levels`).
   Test `test_urgent_failed_send_pushes_at_once`.
3. AC3: the cut-off is fail-closed at send (no cut-off → the send raises, nothing written)
   and fail-open when read (an existing but unreadable cut-off lists everything). Tests
   `test_send_fails_closed_when_the_cutoff_cannot_be_written`, `test_unreadable_cutoff_fails_open`.
