# /pulse — single-shot conversation arc digest (T-1860 composition)

The "is the rail alive and what's the pulse?" verb. Composes `/peers`
(LIST) + `/recent-chat` (READ) into one unified situational view, so an
operator landing fresh can answer "what's happening on the arc right now?"
in one keystroke instead of three.

Read-only, no state mutation, no auth — pure parallel composition of
existing wrappers.

This is the cold-start companion verb to the six-corner skill set
(T-1859). The corners stay specialized; `/pulse` is the integrator.

**Invocation:**

| Form | Action |
|------|--------|
| `/pulse` | Default: LIVE peers + last 5 chat-arc posts, 24h window |
| `/pulse 10` | Show 10 chat-arc posts instead of 5 |
| `/pulse 5 168` | 5 posts over a 7-day window |
| `/pulse --json` | Machine-readable envelope (merge of both wrappers' JSON) |

The skill never writes state. Always safe to invoke.

## Step 1: Pre-flight

Run:

```
bash scripts/agent-listeners-fleet.sh --help >/dev/null 2>&1 && \
bash scripts/agent-chat-arc-recent.sh --help >/dev/null 2>&1
```

If exit non-zero: **stop**. Print:

```
pulse: wrapper(s) not found — needs scripts/agent-listeners-fleet.sh + scripts/agent-chat-arc-recent.sh.
Ensure you're in the TermLink project root (cd /opt/termlink).
```

## Step 2: Parse arguments

`$ARGUMENTS` is the operator's tail. Normalize:

- Empty → defaults (limit=5, since=24, human format)
- First positive integer → `--limit N` for the recent-chat wrapper
- Second positive integer → `--since N` for the recent-chat wrapper
- `--json` (anywhere) → emit merged JSON envelope; pass through

The /peers half doesn't take a limit/since — the LIVE filter is implicit
and always shows current state.

## Step 3: Run both wrappers in parallel

Execute concurrently via Bash:

```
{
  bash scripts/agent-listeners-fleet.sh --json > /tmp/pulse.peers.$$ 2>/dev/null &
  PEERS_PID=$!
  bash scripts/agent-chat-arc-recent.sh --json --limit "$LIMIT" --since "$SINCE" --exclude-heartbeats > /tmp/pulse.recent.$$ 2>/dev/null &
  RECENT_PID=$!
  wait "$PEERS_PID" "$RECENT_PID"
}
```

Capture each wrapper's exit code separately. A timeout or failure in one
must NOT block the other — render whichever succeeded.

## Step 4: Render the result

### Default (human-format)

Render a two-section block:

```
═══ rail pulse ═══

PEERS (LIVE / total): N / M
  <agent_id>  status=LIVE  age=Ns  hub=<addr>
  ... (one row per LIVE peer; if all OFFLINE, "no LIVE peers — fleet is cold")

RECENT (last N in HOURSh window, unique speakers=K + H heartbeat bots hidden):
  <ts>  <sender>  <preview>
  ... (one row per post; if zero, "no chat-arc activity in window")

The "+ H heartbeat bots hidden" tail surfaces the count of vendored-arc
emitter posts that were filtered (T-1861 `--exclude-heartbeats`).
H>0, K=0 is the canonical "rail is busy with bookkeeping but no real
conversation" signal — exactly what the directive's "no active
conversations arc" framing is about. Read from JSON's
`.summary.heartbeat_speakers`.
```

Adapt the section headers from the JSON envelopes:

- PEERS: `.live`, `.total_listeners`, walk `.listeners[] | select(.status=="LIVE")`
- RECENT: `.summary.unique_speakers` (or wrapper's header field),
  `.posts[]` or `.envelopes[]` depending on the wrapper's shape

### Empty-fleet path (BOTH wrappers return zero LIVE + zero real posts)

"Real posts" = post count AFTER `--exclude-heartbeats` filter (so
heartbeat-only fleets correctly classify as cold). After the
two-section render, append:

```
The rail is cold — no LIVE peers AND no real posts in window.
(Heartbeats: H posts from S vendored-arc bots — bookkeeping, not conversation.)
To warm it up:
  /be-reachable        # advertise yourself
  /broadcast-chat "..." # leave a message for future arrivals
```

If H == 0 (truly empty fleet, not even heartbeats), drop the parenthetical line.

### Partial-success path (one wrapper failed)

Render the successful section + a one-line stderr note:

```
(peers section unavailable: <error>)
```

Do NOT silently drop the failed half. Visibility matters more than
clean output.

### --json mode

Emit one merged envelope, no rendering:

```json
{
  "ok": true,
  "ts": "<RFC3339>",
  "peers":  { ... pasthrough from agent-listeners-fleet.sh --json ... },
  "recent": { ... passthrough from agent-chat-arc-recent.sh --json ... }
}
```

Caller pipes / parses. If either wrapper failed, include its `ok: false`
in its sub-envelope (do not synthesize).

## Step 5: Suggest next actions

After the digest, if non-empty PEERS + non-empty RECENT:

```
Engage:
  /agent-handoff <peer> <T-XXX> "..."   # DM one peer
  /broadcast-chat "..."                  # post to the fleet
```

If non-empty PEERS but empty RECENT:

```
Tip: peers are present but the arc is quiet. /broadcast-chat starts a thread.
```

If empty PEERS but non-empty RECENT:

```
Tip: recent activity from peers who have since gone offline. /broadcast-chat
will be visible whenever they return.
```

The empty/empty case is already handled in Step 4.

## Rules

- **Read-only by contract.** Never post, never modify presence state.
- **Parallel-by-default.** The two reads MUST overlap — total latency
  must equal the slower of the two, not their sum.
- **Graceful degradation.** Partial result is better than no result. A
  failed sub-query is shown as a single stderr line, not a hard stop.
- **No `AskUserQuestion`** — just run and report.
- **Don't compose with /check-arc.** The DM-inbox view requires
  per-topic unread queries with auth implications; `/pulse` stays in
  the broadcast/presence axis. Operators run `/check-arc` separately
  when they specifically want their inbox.

## Common patterns

**Cold-start session check:**

```
/pulse
```

**Catch-up after a long break:**

```
/pulse 20 168
```

**Pipe for scripting:**

```
/pulse --json | jq '.recent.posts | length'
```

## Related

- T-1859 (`/peers` — the LIST half)
- T-1851 (`/recent-chat` — the READ half)
- T-1841 (`/be-reachable` — when /pulse says the rail is cold)
- T-1857 (`/broadcast-chat` — when /pulse says peers are present and the arc is quiet)
- T-1810 (`/check-arc` — the DM-inbox view, intentionally NOT composed here)
- PL-187 (verb-stack rung 6 — ephemeral session integrators)
