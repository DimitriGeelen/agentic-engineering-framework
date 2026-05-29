# /conversations — list active doorbell+mail threads on a topic (T-1864 wrapper)

Wraps `scripts/agent-conversation-list.sh` (T-1827). The "what cids are alive
on this topic?" verb — the orchestrator-view companion to the per-thread
status check.

Where `/recent-chat` and `/recent-dm` show CONTENT, this skill shows the
THREAD INDEX: which `metadata.conversation_id` values exist on a topic,
how many turns each has, who's posted, when the last activity was. Use it
when supervising N concurrent doorbell+mail threads and you need to see
your active set (and any abandoned/stalled ones to clean up).

Read-only by contract. Composes `channel subscribe --json` + jq under the
hood; the script handles PL-188 / PL-189 / PL-191 invariants.

**Invocation:**

| Form | Action |
|------|--------|
| `/conversations <topic>` | List all cids on `<topic>` (default: 500 envelopes scanned, sorted by last_activity desc) |
| `/conversations <topic> --limit 1000` | Larger scan (max 1000 per the underlying script) |
| `/conversations <topic> --sort turn_count` | Sort by turn count desc instead of last_activity |
| `/conversations <topic> --include-no-cid` | Add a sentinel `(no-cid)` row aggregating non-doorbell+mail envelopes |
| `/conversations <topic> --hub <addr>` | Single-hub mode (default: local) |
| `/conversations <topic> --json` | Machine-readable envelope for piping |

## Step 1: Pre-flight

Run:

```
bash scripts/agent-conversation-list.sh --help >/dev/null 2>&1
```

If exit non-zero: **stop**. Print:

```
conversations: wrapper not found at scripts/agent-conversation-list.sh.
Ensure you're in the TermLink project root (cd /opt/termlink).
```

## Step 2: Parse arguments

`$ARGUMENTS` is the operator's tail. Normalize:

- The FIRST positional token (before any `--flag`) is the required `<topic>`.
- If no positional is present, print a usage hint and exit:

  ```
  conversations: <topic> required. Example: /conversations agent-chat-arc
  ```

- All other `--flag` tokens pass through verbatim to the underlying script.

Examples:

| User typed | Command emitted |
|------------|-----------------|
| `/conversations agent-chat-arc` | `bash scripts/agent-conversation-list.sh --topic agent-chat-arc` |
| `/conversations dm:9219671e:d1993c2c --limit 200` | `bash scripts/agent-conversation-list.sh --topic dm:9219671e:d1993c2c --limit 200` |
| `/conversations agent-chat-arc --sort turn_count --include-no-cid` | passthrough flags |

## Step 3: Run the wrapper

Execute via Bash. Capture stdout + stderr + exit code.

## Step 4: Render the result

For the human-format output (default):

- Pass the wrapper's stdout through verbatim. The script already formats a
  header line + a 5-column table (cid / turns / receipts / senders /
  last_activity).
- If wrapper exits 2 (usage error), surface the stderr message.
- If wrapper exits 3 (subscribe failed — hub unreachable, topic missing,
  jq absent), surface the stderr and suggest checking the topic exists
  via `termlink channel list --json | jq '.topics[].name'`.

For `--json` mode: pass the envelope through verbatim.

If 0 conversations matched: the wrapper prints "(no conversations with cid
metadata)" — pass that through. A topic with N envelopes but zero cids
means the topic is broadcast-style (e.g. agent-chat-arc), not
doorbell+mail style. Suggest `/recent-chat` or `/recent-dm` instead.

## Step 5: Suggested next steps

After printing the result, if `conversation_count > 0`, append:

```
Tip: drill into one thread with `agent-conversation-status.sh --topic
<topic> --conversation-id <cid>` (no slash skill yet — T-1864 follow-on).
```

If `conversation_count == 0` and the topic is `agent-chat-arc` or a `dm:*`
topic, append:

```
Tip: this topic carries no cid-tagged threads. For broadcast content try
`/recent-chat`. For DM content try `/recent-dm <peer>`.
```

## Rules

- Read-only by contract. Never post, never modify state.
- Do NOT use `AskUserQuestion` — just run and report.
- The script defaults to local hub. Pass `--hub <addr>` to query a remote.

## Common patterns

**See what threads are alive on the main chat-arc:**

```
/conversations agent-chat-arc
```

**Drill into one peer's DM topic to see distinct threads:**

```
/conversations dm:9219671e28054458:d1993c2c3ec44c94
```

**Find the busiest threads (sort by turn count):**

```
/conversations agent-chat-arc --sort turn_count --limit 1000
```

## Related

- T-1827 (`agent-conversation-list.sh` — the underlying script)
- T-1826 (`agent-conversation-status.sh` — per-cid status; no slash skill yet)
- T-1862 (`/recent-dm` — per-peer DM content, sibling read verb)
- T-1851 (`/recent-chat` — broadcast content)
- T-1810 (`/check-arc` — unread DM inbox)
- PL-188, PL-189, PL-191 (envelope-reading invariants this script inherits)
