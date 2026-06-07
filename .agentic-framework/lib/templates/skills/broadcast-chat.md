# /broadcast-chat — fan a chat-arc post to every hub in the fleet (T-1856 wrapper)

Wraps `scripts/chat-arc-broadcast.sh`. The "tell the fleet" verb that
completes the doorbell+mail interactive arc alongside the read-only
discovery skills. **This skill mutates state** (posts a real envelope
to every hub) — pair with `/recent-chat` for read-side context BEFORE
firing, never after.

agent-chat-arc does NOT federate (G-060). Without explicit cross-post
a chat-arc message lands on one hub only and peers on other hubs
never see it. This skill is the operator's one-keystroke fix.

**Invocation:**

| Form | Action |
|------|--------|
| `/broadcast-chat <text>` | Post `<text>` to every hub in `~/.termlink/hubs.toml` |
| `/broadcast-chat --from ID --payload "..."` | Override sender; pass-through flag form |
| `/broadcast-chat --hubs-file PATH ...` | Custom hubs.toml |
| `/broadcast-chat --json --payload "..."` | Machine-readable envelope |

The wrapper auto-resolves sender via:
1. `--from` flag
2. `$TERMLINK_AGENT_ID` env
3. `~/.termlink/be-reachable.state` (from `/be-reachable`)
4. Exit 2 with hint if all four fail

## Step 1: Pre-flight

Run:

```
bash scripts/chat-arc-broadcast.sh --help >/dev/null 2>&1
```

If exit non-zero: **stop**. Print:

```
broadcast-chat: wrapper not found at scripts/chat-arc-broadcast.sh.
Ensure you're in the TermLink project root (cd /opt/termlink).
```

## Step 2: Parse arguments

`$ARGUMENTS` is the operator's tail. Normalize:

- If `$ARGUMENTS` starts with `--`: treat the whole thing as
  pass-through flags. The wrapper validates and errors with usage on
  malformed input. Do NOT auto-construct `--payload` in this branch.
- Otherwise: treat the entire `$ARGUMENTS` as the broadcast text and
  pass it as `--payload "$ARGUMENTS"`.

Examples:

| Operator typed | Command emitted |
|------|------|
| `/broadcast-chat heads up team, I'm back online` | `bash scripts/chat-arc-broadcast.sh --payload "heads up team, I'm back online"` |
| `/broadcast-chat --from claude-alt --payload "..."` | pass-through |
| `/broadcast-chat --hubs-file /tmp/hubs.toml --payload "..."` | pass-through |
| `/broadcast-chat --json --payload "..."` | pass-through |

If `$ARGUMENTS` is empty: **stop**. Print:

```
broadcast-chat: payload required.
Usage: /broadcast-chat <text>
       /broadcast-chat --payload "<text>" [--from ID] [--json]
```

Do NOT default to a placeholder payload. A broadcast without an
operator-authored text is noise on every hub — refuse instead.

## Step 3: Run the wrapper

Execute the constructed command via Bash. Per-hub calls inside the
wrapper are bounded by `timeout 8` (PL-189) so a wedged hub cannot
hang the broadcast. The wrapper writes one row per hub:

```
  192.168.10.141:9100          offset=386
  192.168.10.122:9100          offset=665
  ...
chat-arc-broadcast: 5/5 delivered, 0 failed (sender=root-claude-mydev)
```

Surface the wrapper's stdout verbatim. If `--json` was passed, the
envelope is `{ok, hubs_attempted, hubs_delivered, hubs_failed, sender,
results:[...]}` — surface that verbatim too.

## Step 4: Surface failures distinctly

If any hub failed (wrapper exit 1):
- Tell the operator which hubs were skipped and why (the wrapper's
  per-hub `FAILED:` lines already include the error message)
- Suggest: `bash scripts/check-fleet-doorbell-mail-health.sh` to
  diagnose health before retrying

If the wrapper exits 2 (sender unresolved): tell the operator the
resolution chain and recommend `/be-reachable` to auto-establish a
sender identity before retrying.

## Rules

- **This skill writes state.** Unlike `/recent-chat`, every successful
  invocation produces N real envelopes (one per hub). There is no
  undo. Treat broadcasts like emails sent to a mailing list.
- **Never auto-broadcast.** The operator's text is the operator's
  voice — never paraphrase, summarize, or append agent commentary.
  Pass `$ARGUMENTS` through verbatim as `--payload`.
- **Never silently default sender.** If sender resolution fails, exit
  with the wrapper's hint. Do not invent an agent_id.
- **Pair with read before write.** Best practice for an agent landing
  fresh: `/recent-chat` first to see what's been said, then
  `/broadcast-chat` with informed context. Don't fire blind.
- **Do not use `AskUserQuestion`.** Just run and report.

## Related

- T-1856 (the underlying script)
- T-1851 (`/recent-chat` — the read-side counterpart)
- T-1841 (`/be-reachable` — establishes sender identity used here)
- T-1431 (`/agent-handoff` — direct DM to one peer, not fleet broadcast)
- G-060 (`docs/operations/channel-topic-semantics.md` — why fanout is
  client-driven; this skill is the operator-facing fix)
- PL-189, PL-191 (invariants the wrapper applies)
