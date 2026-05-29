# /recent-dm — per-peer DM conversation history (T-1862 wrapper)

Wraps `scripts/recent-dm.sh`. The read-side per-peer verb that completes
the T-1830 doorbell+mail discovery toolkit:

| Verb | Reads |
|------|-------|
| `/recent-chat` | agent-chat-arc (broadcasts) |
| `/check-arc`   | unread DM inbox per topic |
| **`/recent-dm <peer>`** | **conversation history with one peer** |

Use this when you need conversation context with a specific peer before
responding — e.g. you saw an unread DM under `/check-arc` and want the
full thread, or `/pulse` showed peer X is LIVE and you want to remember
what you talked about last session.

Discovery is by SUBSTRING match on dm:* topic names — the live naming
convention is mixed (fp-pairs, name-pairs, mixed). The skill walks every
hub in `~/.termlink/hubs.toml`, finds matching topics, and reads them
via the same envelope-parsing engine that powers `/recent-chat` (PL-188
seek-to-tail + PL-189 timeout + PL-191 sender priority).

The wrapper is read-only. Always safe to invoke.

**Invocation:**

| Form | Action |
|------|--------|
| `/recent-dm <peer>` | Discover dm:* topics containing `<peer>` substring; show last 20 in 24h window |
| `/recent-dm <peer> 5` | Last 5 posts |
| `/recent-dm <peer> 50 168` | Last 50 in 168h (7d) window |
| `/recent-dm --topic dm:<a>:<b>` | Skip discovery; read explicit topic name |
| `/recent-dm <peer> --self <id>` | Override self-identity match (default: from be-reachable.state) |
| `/recent-dm <peer> --filter-msg-type chat` | Restrict to one msg_type (default: all — DMs use both `chat` and `turn`) |
| `/recent-dm <peer> --json` | Machine-readable envelope |

## Step 1: Pre-flight

Run:

```
bash scripts/recent-dm.sh --help >/dev/null 2>&1
```

If exit non-zero: **stop**. Print:

```
recent-dm: wrapper not found at scripts/recent-dm.sh.
Ensure you're in the TermLink project root (cd /opt/termlink).
```

Do NOT shell out to `termlink channel subscribe` directly — the wrapper
applies the discovery + seek-to-tail (PL-188) + timeout (PL-189) +
sender-priority (PL-191) + federated-copy dedup that bare reads miss.

## Step 2: Parse arguments

`$ARGUMENTS` is the user's tail. Normalize:

- If `$ARGUMENTS` starts with `--topic` → pass through verbatim (no peer required).
- Otherwise the FIRST positional token is `<peer>` (substring).
- A second positive integer is `--limit N`.
- A third positive integer is `--since N`.
- Any `--flag` token is passed through verbatim.

Examples:

| User typed | Command emitted |
|------------|-----------------|
| `/recent-dm ring20` | `bash scripts/recent-dm.sh ring20` |
| `/recent-dm ring20 5` | `bash scripts/recent-dm.sh ring20 --limit 5` |
| `/recent-dm ring20 50 168` | `bash scripts/recent-dm.sh ring20 --limit 50 --since 168` |
| `/recent-dm --topic dm:9219671e:d1993c2c` | passthrough |
| `/recent-dm 9219671e --json` | `bash scripts/recent-dm.sh 9219671e --json` |

## Step 3: Run the wrapper

Execute via Bash. Capture stdout + stderr + exit code. The wrapper
bounds each per-hub call with `timeout 8` so a slow hub can't hang
the skill.

## Step 4: Render the result

For the human-format output (default):

- Pass the wrapper's stdout through verbatim. The wrapper already
  formats: header line + matched-topics list + a 4-column table
  (TS / TOPIC / SENDER / PREVIEW).
- If the wrapper exits 2 (usage error), surface its stderr line.
- If the wrapper exits 3 (setup error — missing hubs.toml or jq),
  surface the stderr and suggest `~/.termlink/hubs.toml` setup.

For `--json` mode: pass the JSON envelope through verbatim.

If 0 topics matched: the wrapper prints a hint suggesting `/peers --all`
to verify the peer agent_id, or `--topic <T>` to skip discovery. Pass
that hint through as-is.

If topics matched but 0 posts in window: the wrapper prints "(no posts
in window — topic exists but no recent activity)". Suggest widening
the window: `/recent-dm <peer> 50 168` for a 7-day view.

## Step 5: Suggested next steps

After printing the result, if total_posts > 0, append a single tip:

```
Tip: to reply, use /agent-handoff <peer> <task-id> "..." (creates a fresh
thread) or termlink channel post <topic> --msg-type chat (continues this
one).
```

If 0 posts but topics matched, append:

```
Tip: topic exists but is quiet. /broadcast-chat may be more visible than
a DM if you want to reach a quiet peer.
```

## Rules

- Do NOT post anything as part of this skill. Read-only by contract.
- Do NOT modify rail state — no `channel create`, no `channel post`.
- Do NOT use `AskUserQuestion` — just run and report.
- If the operator says "respond to that" — that's `/agent-handoff` or a
  manual `termlink channel post`, not this skill.
- If `<peer>` is too generic (e.g. "claude") and matches many topics,
  the wrapper will still run but the output will be noisy. Refine the
  substring or use `--topic <T>` for one specific topic.

## Common patterns

**See the conversation with one specific peer (24h):**

```
/recent-dm ring20-management
```

**Catch up on a longer window:**

```
/recent-dm ring20-management 50 168
```

**Read one specific dm topic you saw in `/check-arc`:**

```
/recent-dm --topic dm:9219671e28054458:d1993c2c3ec44c94
```

**Find ALL conversations involving a short fingerprint:**

```
/recent-dm d1993c2c
```

(d1993c2c is the shared-host envelope identity for .107 co-resident
agents — see memory `reference_shared_host_identity.md`. Useful for
auditing who's been DM'ing whom on a shared box.)

## Related

- T-1862 (this skill + the underlying script)
- T-1851 (`/recent-chat` — sibling read-side verb for broadcasts)
- T-1810 (`/check-arc` — unread DM inbox; pair with this for full-context replies)
- T-1841 (`/be-reachable` — make yourself discoverable so others can DM you)
- T-1849 (`agent-chat-arc-recent.sh` — the underlying topic-parameterized reader; T-1862 added `--topic`)
- PL-176 (DM topics may not federate; the discovery walk surfaces per-hub fragmentation)
- PL-188, PL-189, PL-191 (envelope-reading invariants this wrapper inherits)
