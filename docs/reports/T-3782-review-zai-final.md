The placeholder `T-3782-review-zai-final.md` is empty — I'll deliver my review in-response only (read-only). Now reading the code at HEAD (`d06a58401`, includes post-round-3 fixes `50497f68a`).
Now the Watchtower surface and handover:
Now the e2e evidence and integration test:
Code and evidence reviewed. Now running the cited suites at HEAD (they write only to pytest tmp dirs; no repo files touched):
One last timestamp check — that the committed e2e rerun postdates the round-3 fixes:
# T-3782 — final adversarial review (read-only, outside reviewer)

HEAD `d06a58401` (includes post-round-3 fixes `50497f68a`). Read: brief, rounds 1–3 (+ `codex.md`, identical to round 3), task file, all cited code, tests; ran the cited suites (scratch/tmp only): **32/32 unit, 57/57 receiver+receipts regression, 8/8 web passed**; `bash -n` on `bin/claude-fw` and `handover.sh` clean. Note: `docs/reports/T-3782-review-zai-final.md` exists but is empty (0 bytes) — per read-only instruction I did not write it; verdict is in-response only.

## Agent ACs

**AC1 — immediate "waiting, no live recipient" receipt on every receive path: MET.**
`inject.deliver_pending` → `waiting.note_no_recipient` outside the lock (inject.py:274-283); both receive paths end there (http_server.py:104-108 on-store thread; watcher.py:513 tick). `is_no_recipient` (waiting.py:185-191) counts everything except live-busy, including dead-agent-in-surviving-PTY `_NO_LIVE_SESSION` (round-1 fix, test :471) and store-failed spool (`_spool` sends WAITING, watcher.py:374-379). Sender records it for both paths (receipts.py:117-142; direct.py:252-277, RANK 2.5); hub-fallback receipt for a direct send routed to the direct ledger (inbox.py:228-233). Receipt retried until an ok row (`receipts.already`). Tests :95, :124, :142, :174; e2e sender told in 2.0 s.

**AC2 — push at threshold, urgent at once, once per level, never per tick: MET.**
`due_levels` (waiting.py:478-490): warn at `warn_hours()` (env>yaml>4, non-finite ignored), urgent at once for every can't-be-taken state incl. undeliverable/rejected/escalated/store-failed; overdue at max(24, 2×warn). `escalate` ledger-dedupes per (key, level) (waiting.py:573-599); failed pushes retried ≤ every 30 min, cap 6, then honest stop — item stays listed (`_escalated_levels`, waiting.py:295-307). Round-3 notifier fix holds: `default_notifier` runs the dispatcher in the **foreground** and takes its exit status; missing dispatcher → `failed:` (waiting.py:506-544) — verified `fw_notify` itself still backgrounds and returns 0 (notify.sh:101,116-123), which is why the bypass is correct. Tests :191 (60 ticks), :215, :226, :239, :578, :664, :683.

**AC3 — listed in handover and on Watchtower until handled: MET.**
handover.sh:1413-1439 (failure printed as "Could not be listed", never omitted); approvals.py:587-619 (subprocess listing, mtime+1-min cache, failure → error card, never empty-list); card `#section-waiting` with both actions (_approvals_content.html:483-532); badge counts it (approvals.py:956-960). Both directions listed; outbound cut-off created at send, fail-closed (outbox.py:107-111, direct.py:176-183), fail-open when unreadable (waiting.py:131-143). Spooled store-failures listed at once (waiting.py:338-355). Tests :444, :258, :288, :297, :321, :507, :589, :605; web tests green; e2e `handover_has_section: true`.

**AC4 — recover: operator-only, logged, framed, never peer-triggered: MET.**
`recover` (waiting.py:730-775): claim-first (suppresses double delivery in inject.py:301-302 and hooks.py:216-217), logged to recover.jsonl + receiver events, HANDED_OVER only on transcript USER-message evidence with the secret token (waiting.py:791-853; assistant-quote is not evidence, test :379). No peer route: receiver API is `/message`,`/ack`,`/health`,`/status` only (http_server.py:73-134); no receipt state names recover; CLI refuses under CLAUDECODE even with `--from-watchtower` (sidecar_cli.py:808-823, test :413); Watchtower route CSRF-checked (web/app.py:130-158) and strips CLAUDECODE (approvals.py:581). Peer text stays data: fixed preamble + `hooks._frame` markers, neutralised closers, 4000-char cap, `safe_meta` outside markers (waiting.py:680-692, hooks.py:93-150); `printf ' %q'` per-arg into the PTY line (bin/claude-fw:686-693, tests :339, :457, :518). E2e: real recovered session, HANDED_OVER with `recover-transcript:` evidence in ~4 s.

**AC5 — closes only on reply / HANDED_OVER / operator drop, never expiry: MET.**
`is_closed_inbound` (waiting.py:265-267): handed-over marker, dropped marker, replied — no age predicate exists in the module; recover-claim timeout only releases the claim (waiting.py:270-282); direct deadline expiry → ESCALATED, which stays listed (direct.py:313-327; waiting.py:411). 400-day test :258. Drop requires a reason and tells the sender DROPPED (waiting.py:640-677).

**AC6 — live test with negative control: MET (on committed evidence + final-code rerun).**
`tests/integration/t3782_waiting_recover_e2e_test.py` asserts in AC order incl. the negative control judged over the whole no-agent window (:139-148). Evidence `T-3782-e2e-7y0peo.json` (result PASS) was committed in `6cbc683b5` (00:41:17 +02:00), after the round-3 fixes `50497f68a` (00:37:55 +02:00) — it ran on final code. I did not re-run the live claude-fw leg myself (read-only session); the earlier `s5hbge` run corroborates.

## Earlier findings — all confirmed FIXED at HEAD

- **R1-1** dead-agent/surviving-PTY — fixed (`_NO_LIVE_SESSION`, test :471). **R1-2** urgent not persisted on direct send — fixed (direct.py:209, test :493). **R1-3** epoch initialised at first listing — fixed (created at send, fail-closed; tests :507/:589/:605). **R1-4** metadata outside markers — fixed (`safe_meta`, `_safe_note`; test :518).
- **R2-1** hub store-fail after cursor advance — fixed (spool + replay; test :549). **R2-2** urgent failed sends not immediate — fixed (test :578). **R2-3** epoch fail-open at send — fixed (tests :589/:605).
- **R3-1** content-blind inbox dedupe — fixed: `seen_key = id#content-hash`, legacy bare-id still matches (inbox.py:234-246); real-`pending` test :616; conflict handler keeps the second message (watcher.py:279-288, test :566). **R3-2** notifier always-0 — fixed (foreground dispatcher, retry/cap; tests :664/:683). **R3-3** spool ordering/visibility/crash window — fixed: `_drain_spool()` runs FIRST in `ingest_hub`, independent of the hub read (watcher.py:248,255-257); atomic rewrite under lock, never unlinked before replay (:317-345); spooled items listed at once, drop-only, urgent pushes at once (tests :631/:653).

## The five explicit checks

1. **Can a waiting message still go unnoticed? No.** Inbound: every stored message is re-decided every tick; every non-busy refusal → receipt + at-once listing; store-failures spool, list and tell the sender. Outbound: WAITING receipt / failed send / threshold → listed and pushed. Residual is exactly the brief's stated limit: a recipient whose watcher itself is dead sends no receipt — covered sender-side after the threshold and by fw doctor/audit's not-live watcher flag (T-3685). Not silent, and not hidden.
2. **Can expiry close it? No** — closure predicates are marker/receipt-only; no age test exists; 400-day listing pinned.
3. **Can a peer trigger recover? No** — no HTTP route, no receipt state, CLI/CSRF gates, secret-token transcript confirmation; peer-forged receipts are confined to their own addressee-verified ids (pre-existing CONFIRM-2 trust model, unchanged).
4. **Does the push repeat every tick? No** — ledger dedupe per (item, level); sent/disabled finish a level; failed retries throttled to ≥30 min, capped at 6; pinned by the 60-tick, backoff and cap tests.
5. **Does recover inject peer text as instructions? No** — preamble is fixed trusted text with `safe_meta`'d ids; the body is inside PEER-DATA with neutralised closers and a cap; `%q` quoting keeps `$`/quotes/newlines data.

## Residual notes (non-blocking, none contradicts an AC)

- A peer-side DROPPED receipt on an outbound message does not close the sender's listing (only the local operator drop does); the item shows state `dropped` until dropped locally — over-listing in the safe direction, operator can clear it.
- The inbox dedupe hash covers `payload_b64` only; an envelope carrying a bare `payload` field (never observed from `termlink --json`) would dedupe by id alone. Theoretical.
- Round-3's fixes were verified here directly (this round); nothing remains unreviewed.

VERDICT: PASS
