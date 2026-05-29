# /peers — list reachable agents across the fleet (T-1837 skill-layer wrap)

Wraps `scripts/agent-listeners-fleet.sh`. The **LIST-PEERS** verb in the
T-1830 doorbell+mail arc discovery triangle — answers "who's around to
DM?" before you fire `/agent-handoff` or `/broadcast-chat`.

The interactive arc has six skill-layer corners. This one was the last
gap:

1. **PRESENCE (self)** — `/be-reachable` (T-1841)
2. **LIST-PEERS** — **this skill**
3. **SEND (1:1)** — `/agent-handoff` (T-1431)
4. **RECEIVE (inbox)** — `/check-arc`
5. **READ (chat-arc)** — `/recent-chat` (T-1851)
6. **BROADCAST (fleet)** — `/broadcast-chat` (T-1857)

Read-only, no auth, no state mutation — pure discovery.

**Invocation:**

| Form | Action |
|------|--------|
| `/peers` | LIVE listeners only (default — the actionable view) |
| `/peers --all` | Include STALE + OFFLINE entries |
| `/peers --filter-role claude-code` | Only show peers with `metadata.role == claude-code` |
| `/peers --filter-listen-topic agent-chat-arc` | Only show peers subscribed to a specific topic |
| `/peers --json` | Machine-readable envelope (passes through to wrapper) |
| `/peers --hubs-file PATH` | Custom hubs.toml |
| `/peers --limit N` | Envelopes scanned per hub (default 200, max 1000) |

The wrapper merges per-hub views by `agent_id` with `LIVE > STALE > OFFLINE`
preference and routes the surviving `hub` field to the right address — so
the handoff hint per peer is always actionable (peer is reachable via the
named hub).

## Step 1: Pre-flight

Run:

```
bash scripts/agent-listeners-fleet.sh --help >/dev/null 2>&1
```

If exit non-zero: **stop**. Print:

```
peers: wrapper not found at scripts/agent-listeners-fleet.sh.
Ensure you're in the TermLink project root (cd /opt/termlink).
```

Do NOT shell out to `termlink channel subscribe agent-presence` directly —
the wrapper applies fleet-aware merging (LIVE > STALE > OFFLINE per
agent_id) that a single-hub read would miss on multi-hub fleets (G-060
fan-out semantics apply to agent-presence too).

## Step 2: Parse arguments

`$ARGUMENTS` is the operator's tail. Normalize:

- Empty → run with no flags (defaults: LIVE-only, table output).
- `--all` (anywhere in args) → translate to `--include-offline` for the
  wrapper. Strip `--all` from the args before pass-through.
- Any other `--flag` token → pass through verbatim.

Examples:

| User typed | Command emitted |
|------------|-----------------|
| `/peers` | `bash scripts/agent-listeners-fleet.sh` |
| `/peers --all` | `bash scripts/agent-listeners-fleet.sh --include-offline` |
| `/peers --json` | `bash scripts/agent-listeners-fleet.sh --json` |
| `/peers --filter-role claude-code` | passthrough |
| `/peers --all --json` | `bash scripts/agent-listeners-fleet.sh --include-offline --json` |

## Step 3: Run the wrapper

Execute the constructed command via Bash. Capture stdout + stderr +
exit code.

## Step 4: Render the result

For **default human-format** output:

- Pass the wrapper's stdout through verbatim (it's a fixed-width table
  with TS / STATUS / AGENT_ID / ROLE / HUB / LISTEN_TOPICS columns).
- If exit code is 0 and the table is empty (no rows after the header),
  the fleet has zero LIVE peers — see Step 5 for the empty-fleet hint.
- If exit code is 2 (usage error), surface stderr and stop.
- If exit code is 3 (every hub unreachable), surface the stderr line
  and suggest `termlink fleet doctor` to diagnose.

For `--json` mode: pass the JSON envelope through verbatim. Do not
re-render — callers piping/parsing rely on the wrapper's schema.

## Step 5: Empty-fleet hint

If the wrapper exits 0 and reports zero LIVE peers (count `LIVE` rows
in stdout, or read `.live` from `--json` mode), append this hint
**after** the wrapper's output:

```
No LIVE peers found.

To make yourself reachable to peers landing here:
  /be-reachable

To leave a message that any future arrival will see:
  /broadcast-chat <text>

To see who has been here recently (last 24h):
  /peers --all
```

This is the actionable closure for an empty arc. Never silent on empty.

## Step 6: Per-peer handoff hints

For non-empty results in human-format mode (NOT json mode), after the
wrapper's table, append a "Reach them with:" section listing one
`/agent-handoff` invocation per LIVE peer:

```
Reach them with:
  /agent-handoff <agent_id> <T-XXX> "<msg>"

LIVE peers:
  /agent-handoff root-claude-mydev T-1859 "your message"
  /agent-handoff ring20-manager-vendored T-1859 "your message"
```

Use the current focus task (read `.context/working/focus.yaml`
`current_task:`) for `<T-XXX>` placeholder; fall back to `T-XXX` literal
if no focus.

Skip this section in `--json` mode (machine output should be pure
envelope).

## Rules

- **Read-only by contract.** Never post, never modify presence state.
- **Never invent peers.** If wrapper output is empty, surface the empty
  state — do not pad with placeholder rows.
- **LIVE-default is intentional.** OFFLINE peers can't receive a DM right
  now; surfacing them by default invites mis-handoffs. Require `--all`
  to opt into the broader view.
- **No `AskUserQuestion`** — just run and report.
- **Pair with read before write** for fresh-session etiquette: run
  `/recent-chat` first to see what's been said, then `/peers` to see
  who's there, then `/agent-handoff` or `/broadcast-chat` to act.

## Related

- T-1837 (`scripts/agent-listeners-fleet.sh` — the underlying multi-hub merge)
- T-1839 (`termlink_agent_listeners_fleet` — MCP wrapper of the same script)
- T-1841 (`/be-reachable` — the SELF-advertise counterpart)
- T-1431 (`/agent-handoff` — the verb /peers feeds into)
- T-1857 (`/broadcast-chat` — the fan-to-all alternative when no one's LIVE)
- T-1851 (`/recent-chat` — read-side context before write)
- PL-187 (verb-stack pattern rung 6: ephemeral session skills)
- G-060 (channel topics are hub-local — why the fleet-merge in T-1837 is necessary)
