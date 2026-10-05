# T-3855 — Cross-hub sidecar end to end

Source: ring20-dashboard T-2459 spec (§5 items 3, 5, 6; §3.6; §6 acceptance),
relayed by the operator 2026-10-05. Parts (1)+(2) (`--hub` auth via hubs.toml,
version floor) shipped in T-3806, and (4) (owner inbox topic) shipped in T-3803.
This task does (3) addressing, (5) receipts, (6) wake, and the §3.6 attribution fix.

## The measured bug

`fw sidecar send --to ring20-dashboard --hub ring20-dashboard` returned
`HUB_ACCEPTED` / delivered. The post went to
`inbox:cacc73ea32b121dd/999-Agentic-Engineering-Framework/ring20-dashboard`,
which is in the sender's namespace, and `--ensure-topic` created that topic on
the recipient's hub. The recipient reads `inbox:1389a831016c4bf1/ring20-dashboard`.
Any bare `--to` that was not a fleet project id took the same path, for example
dimitri-mint-dev, claude-shared-toolkit and smk-b. 87 outbound messages sat
unread this way.

## What shipped (AEF half)

| Leg | Fix | Where |
|---|---|---|
| §5.3 addressing | The recipient's topic is anchored on the recipient's hub id. That id comes from one of three places: an explicit `--to <hubid>/<name>`; the peer directory (`.context/sidecar/peers.json`), learned from received envelopes' `from_circuit`; or a `--hub` read. The `--hub` read takes the fingerprint from `termlink hub probe` and checks it against termlink's TOFU pin. It only runs for a hub with a usable hubs.toml credential, and `probe_hub` then makes an authenticated version read before anything is posted. A bare name goes into our namespace only with sub-agent evidence: its inbox exists on our hub, a receiver is registered, or `--level agent` is given. Anything unresolved is **refused by name**, exit 2, with no outbox write and no post. "delivered" output now names the topic **and** the hub. | `lib/sidecar/addressing.py`, `lib/sidecar_cli.py` |
| §5.5 receipts | RECEIVED / HANDED_OVER / REPLIED go to the topic named by the envelope's `from_circuit`. For a foreign hub, `--hub` is the hubs.toml profile whose hub id matches. If no profile matches, the receipt is reported failed rather than posted locally. Receipts now carry `from_circuit`. | `lib/sidecar/receipts.py` |
| §3.6 attribution | The sender is `from_agent`, else the name its `from_circuit` carries. A raw post with neither is labelled `unattributed (raw post)` and gets no reply line. "unknown" is gone from every inbound renderer (CLI, prompt hooks, waiting register). For a remote sender the reply line uses its circuit, so the answer lands in the sender's own namespace. | `lib/sidecar/inbox.py`, `hooks.py`, `waiting.py`, `sidecar_cli.py`, `agents/context/sidecar-inbox.sh` |
| §5.6 wake | The watcher runs a follower thread on `termlink channel subscribe inbox.queued --push --hub <own hub's TCP profile>`. A frame whose `channel` is one of our inbox topics ends the tick wait at once, so the watcher ingests, sends RECEIVED and injects. If no profile reaches our own hub, the follower says so in `follower.json` and the 30 s tick stays the floor. Plain `claude` sessions already start the watcher from SessionStart (`sidecar-autostart`). `fw doctor` and `fw audit` now **FAIL** when the agent has a sidecar inbox and no live watcher would notice a message; this used to be a WARN for "absent". | `lib/sidecar/watcher.py`, `lib/sidecar-audit.sh`, `bin/fw`, `agents/audit/audit.sh` |

Live check: read-only (hub probe, TOFU list and fleet doctor; nothing was posted).

- `.121` resolves to `inbox:1389a831016c4bf1/ring20-dashboard`.
- `.122` resolves to `inbox:22c19fedafd73da2/ring20-management`.
- This host's watcher picked up the new code under supervision. Its follower is
  `following` via profile `workstation-107-public (192.168.10.107:9100)`.

## What the TermLink side needs (precise asks)

1. **One authenticated read that returns a hub's identity.** Today we combine
   two separate connections. `hub probe --json` reads the certificate
   fingerprint unauthenticated. `fleet doctor --json` makes the authenticated
   `hub.version` read, walks every profile and carries no fingerprint. A single
   call fixes both problems: `termlink remote doctor <profile> --json`, or
   `hub.info` returning `{hub_id/fingerprint, version}` over the profile's
   secret and TOFU pin. The hub id would then come from the same authenticated
   session that the post uses.
2. **`inbox.queued` reachable without a TCP profile.** The aggregator is
   push-only. `channel subscribe inbox.queued` on the local unix socket answers
   `unknown topic`, and `--push` requires a TCP `--hub` plus a secret (WS over
   Unix is noted as a follow-on in the `--push` help). A co-located agent has to
   hold a hubs.toml profile pointing at its *own* hub just to be woken. Ask:
   push over the unix socket, or a pollable `inbox.queued` topic.
3. **Waking an idle session that termlink did not spawn.** Injection needs a
   TermLink-registered PTY. `claude-fw --termlink` provides one. A plain
   `claude` in a non-tmux terminal has none, and `be-reachable.sh` prints the
   same "push-wake DORMANT" condition. For such a session our side does this:
   - the message is still ingested within seconds and RECEIVED goes back to the sender;
   - the operator is pushed by the waiting register;
   - the message is surfaced at the session's next prompt.

   It is **not** typed into the idle prompt. Ask: a way to register an existing
   session's PTY (or another wake channel) without spawning it under termlink.

Until (3) exists, the §6 line "B idle woken <60 s" holds for TermLink-wrapped
sessions only (`claude-fw --termlink`, or tmux with a registered session). A plain
non-PTY session gets RECEIVED plus operator push, but no injection. That limit is
stated here rather than claimed closed.

## Not done here

- **The §6 joint acceptance test (.121 <-> .122):** owned by the parent with ring20.
  This task posted nothing into their inboxes.
- **The 87 outbound rows already in the wrong namespace:** this task does not
  migrate them. They stay in the outbox ledger. The sweep re-posts to the topic
  each row recorded, so those rows need an operator `fw sidecar drop` or a resend
  to the corrected address.
