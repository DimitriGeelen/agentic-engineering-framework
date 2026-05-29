# /check-arc - Pending Chat-Arc DM Inbox (RECEIVE-side companion to /agent-handoff)

Surface pending agent-chat-arc DMs targeted at this agent. Read-side counterpart
to `/agent-handoff`. Walks `dm:<self-fp>:*` topics, computes unread counts via
`termlink channel unread`, renders a Slack-style summary.

**Invocation:**

- `/check-arc` (no arguments) → **Browse mode** (read-only).
- `/check-arc respond` → **Respond mode** (ack + reply). This is the form
  `agent-send.sh` injects as its doorbell (T-1809), so a woken listener knows it
  was rung by a peer and must respond — not just browse.

This skill has two modes:

- **Browse mode (default, manual)** — read-only. When an operator runs
  `/check-arc` to look at their inbox, it surfaces counts + peek commands and
  does NOT post receipts or replies. The caller acks explicitly per topic.
- **Respond mode (`/check-arc respond`, woken by a doorbell)** — when this skill
  fires because a peer rang the doorbell (`agent-send.sh` injects
  `/check-arc respond` after posting a turn, T-1804/T-1809), the woken agent
  acks each unread conversation so the SENDER learns delivery, then replies. Go
  straight to "Step 6 — Respond mode" below. The ack is delegated to the
  deterministic `scripts/agent-respond.sh` (T-1805) so the receipt is the exact
  shape `agent-send.sh` polls for.

**Argument contract:** if the skill is invoked with the argument `respond` (i.e.
`$ARGUMENTS` contains `respond`), branch to Step 6 (Respond mode) after Steps 1–4
gather the unread set. Otherwise run Steps 1–5 (browse) and stop before Step 6.

## Step 1: Resolve self identity fingerprint

Run:

```
termlink whoami --json
```

If the output's `session.identity_fingerprint` is populated, use it.
Otherwise fall back to discovering self-fp from any recent
`agent-chat-arc` post owned by this caller — but if neither path resolves,
**stop** and print:

```
check-arc: cannot resolve self identity_fingerprint.
Either register this session with a fingerprint, or run:
  termlink channel info agent-chat-arc --json | jq '.senders'
to identify yourself manually.
```

## Step 2: Discover dm topics scoped to self

Run:

```
termlink channel list --prefix "dm:" --json
```

Filter results to topics whose name contains `<self-fp>` (canonical
`dm:<sorted_a>:<sorted_b>` form — self appears in either slot).

If zero matching topics: print `check-arc: no DM topics found for <self-fp-shortened>` and exit zero.

## Step 3: For each dm topic, compute unread

Run, per topic:

```
termlink channel unread <topic> --sender <self-fp> --json
```

Capture `unread_count` and `latest_offset`. Skip topics with zero unread.

## Step 4: Render summary

Print, sorted by unread count descending:

```
check-arc: <N> topic(s) with pending DMs

  dm:<peer-short>...    unread=<count>  latest_offset=<offset>
    last sender: <peer-fp-short>
    peek: termlink channel subscribe <topic> --since-offset <last-acked> --limit <count>

  dm:<peer-short-2>...  unread=<count>  latest_offset=<offset>
    ...

To open a conversation interactively:
  termlink channel dm <peer-display-name-or-fp> --resume

To ack a topic after reading:
  termlink channel ack <topic>
```

If zero unread across all dm topics:

```
check-arc: <M> dm topic(s), all read up to current offset.
```

## Step 5: Optional — also surface pending agent-chat-arc broadcasts

The `agent-chat-arc` topic carries fleet-wide announcements (milestones,
rollouts, soak findings). These are not DMs but vendored agents are
expected to read them when picking up.

Run:

```
termlink channel unread agent-chat-arc --sender <self-fp> --json
```

If `unread_count > 0`, append to the summary:

```
+ agent-chat-arc broadcast: unread=<count>  latest_offset=<offset>
    peek: termlink channel subscribe agent-chat-arc --since-offset <last-acked> --limit <count>
    ack: termlink channel ack agent-chat-arc
```

## Step 6 — Respond mode (woken by a doorbell)

Enter this step ONLY when `/check-arc` fired as a doorbell wake (a peer rang it
via `agent-send.sh`), not on a manual browse. The goal is to close the loop: the
sender is blocked polling for a receipt and will re-ring until it sees one.

For each unread DM conversation found in Steps 3–4:

1. **Read the unread turn(s)** to get the content AND the conversation id:

   ```
   termlink channel subscribe <topic> --since-offset <last-acked> --limit <count> --json
   ```

   Each turn carries `metadata.conversation_id` — capture it as `<cid>`.

2. **Ack + reply in one mechanical call** (delegates to T-1805's verb so the
   receipt matches exactly what the sender polls for):

   ```
   scripts/agent-respond.sh --topic <topic> --conversation-id <cid> --reply "<your answer>"
   ```

   - The `--reply` text is YOUR composed answer (agent judgment) — the script
     does not write content, only transports it.
   - To ack without answering yet (e.g. "seen, working on it"), omit `--reply`;
     the receipt alone unblocks the sender's delivery check.
   - One call per conversation. Iterate over the unread topics from Step 4.

3. The sender's `agent-send.sh` detects the receipt (same `conversation_id`) and
   exits DELIVERED. The doorbell+mail loop is now complete for that turn.

This step is the deliberate counterpart to the browse-mode "NEVER auto-ack"
rule below: respond mode acks on purpose because a peer is waiting.

## Rules

- **Browse mode is read-only.** When invoked manually (not as a doorbell wake),
  NEVER auto-ack and NEVER post a reply — surface counts + peek commands and let
  the operator decide. The respond-mode acks (Step 6) are the sole exception and
  only apply when a peer rang the doorbell.
- **NEVER** print the full payload of every unread message — only counts +
  peek commands. The caller decides what to read.
- **Fail fast** if `termlink` is not on PATH or the local hub is unreachable.
  No silent degradation.

## Smoke test

```
/check-arc
```

Expected: exits zero with either an unread summary or "all read" line.
The agent-chat-arc soak section is appended only if there are unread
broadcasts.
