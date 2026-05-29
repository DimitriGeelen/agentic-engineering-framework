# /be-reachable — opt-in to agent-presence for this session (T-1841)

Wraps `scripts/be-reachable.sh` so a claude-code session can become
discoverable on the fleet's `agent-presence` topic in one command.
Peers can then call you via `termlink agent contact <agent_id>` or
`agent-send.sh --to <agent_id>` without out-of-band coordination.

This skill is the ephemeral-session counterpart to the persistent rail
in `docs/operations/listener-heartbeat-systemd.md` (T-1840). Use this
for ad-hoc claude sessions; use the systemd template for hosts that
should be reachable across reboots.

**Invocation:**
- `/be-reachable` — start with auto-derived defaults
- `/be-reachable start [--agent-id NAME] [...]` — start with overrides
- `/be-reachable status` — report current state
- `/be-reachable stop` — terminate the background heartbeat

The wrapper is idempotent: a second `start` while one is already
running prints the existing agent_id and exits 0 without spawning a
duplicate.

## Step 1: Pre-flight — confirm wrapper is present

Run:

```
bash scripts/be-reachable.sh --help >/dev/null
```

If exit non-zero: **stop**. Print:

```
be-reachable: wrapper not found at scripts/be-reachable.sh.
Ensure you're in the TermLink project root (cd /opt/termlink).
```

Do NOT attempt to spawn `listener-heartbeat.sh` directly — the wrapper
applies the right defaults and writes the state file that other tools
rely on.

## Step 2: Dispatch the subcommand

Map the user's argument to a subcommand:

| User said | Run |
|-----------|-----|
| `/be-reachable` (no args) | `bash scripts/be-reachable.sh start` |
| `/be-reachable start ...` | `bash scripts/be-reachable.sh start <args>` |
| `/be-reachable status` | `bash scripts/be-reachable.sh status` |
| `/be-reachable stop` | `bash scripts/be-reachable.sh stop` |

Pass through any extra arguments verbatim. The wrapper validates and
errors with exit 2 if anything is malformed.

## Step 3: Surface the result

After `start`, the wrapper prints a block like:

```
be-reachable: started.
  agent_id:      root-claude-mydev
  pid:           12345
  pty_session:   main
  listen_topics: dm:root-claude-mydev:*,agent-chat-arc
  state:         /root/.termlink/be-reachable.state
  log:           /root/.termlink/be-reachable.log
```

Echo the `agent_id` to the user — that's the handle peers need.

If the wrapper exits 3 (immediate-exit failure), the log path is
named in stderr. Read the last 20 lines of the log and surface the
real error (usually: hub unreachable, listener-heartbeat.sh
mis-installed, or termlink binary missing from PATH).

## Step 4: Optional — confirm presence is live

Discovery propagates within `interval` seconds (default 30). To
confirm:

```
sleep 35 && bash scripts/agent-listeners.sh \
  --filter-agent-id "$(jq -r .agent_id ~/.termlink/be-reachable.state)" \
  --include-offline --json | jq .
```

`status` should read `LIVE`. If `STALE` or `OFFLINE`, check the log
file named in the start output for the actual emit error.

## Notes

- **One instance per user per host** by default. The state file is at
  `~/.termlink/be-reachable.state`. To run multiple instances on the
  same host (e.g. one per tmux pane), override
  `BE_REACHABLE_STATE_DIR` and `BE_REACHABLE_STATE` per pane before
  invoking `start`.
- **The heartbeat survives the session** because `setsid + nohup` are
  used. To kill it, run `/be-reachable stop`. Closing the terminal
  alone will NOT stop it.
- **PTY session auto-detection** reads `$TMUX` (tmux) or `$STY`
  (screen). Without a multiplexer it stays empty — that's fine for
  presence, but `agent-send --to <id>` doorbell ring needs a target,
  so set one explicitly with `--pty-session NAME` if you want to be
  doorbell-pinged.
- **State file is gitignored implicitly** — it lives in `~/.termlink/`,
  not in the project tree.

## Related

- `.claude/commands/agent-handoff.md` — counterpart for sending
- `scripts/listener-heartbeat.sh` — T-1832 underlying emitter
- `scripts/agent-listeners.sh` — T-1833 discovery (single-hub)
- `scripts/agent-listeners-fleet.sh` — T-1837 discovery (cross-hub)
- `docs/operations/listener-heartbeat-systemd.md` — T-1840 persistent
  rail for hosts that should be reachable across reboots
- `docs/operations/agent-conversations.md` — T-1830 recipe master doc
