# Persistent `listener-heartbeat` via systemd

> T-1840 (T-1830 follow-up). Closes the third "deliberately not done yet"
> item in [agent-conversations.md](agent-conversations.md).

`scripts/listener-heartbeat.sh` runs in foreground. Operators currently
background it manually or wire it into ad-hoc supervisors; reboots
reset everything. This recipe wraps the heartbeat in a systemd template
unit so the agent re-registers automatically on boot.

## When to install

You want this when:

- The host runs persistently (not an ephemeral container).
- An agent on this host should be reachable via `--to <agent_id>` from
  peers (T-1834 / T-1839) without operator action after each reboot.
- The host is in the fleet's `hubs.toml` and should appear in
  `agent-listeners-fleet.sh` output (T-1837).

You **don't** want this when:

- The agent is short-lived (a single claude-code session). Background
  the heartbeat manually and let it die with the session.
- The host's hub is volatile (e.g. /tmp-based runtime_dir per PL-021).
  Fix the hub persistence first ([CLAUDE.md hub-auth-rotation
  protocol](../../CLAUDE.md)).

## Install

```bash
# 1. Stage the unit template
sudo install -d /etc/systemd/system
sudo cp systemd-templates/termlink-listener-heartbeat@.service \
        /etc/systemd/system/

# 2. Author an env file per agent_id
sudo install -d /etc/termlink/listener-heartbeat

sudo tee /etc/termlink/listener-heartbeat/cohort-agent-ring20.env >/dev/null <<'EOF'
# T-1840 per-instance config — read by termlink-listener-heartbeat@cohort-agent-ring20
TERMLINK_LH_ROLE=cohort-agent
TERMLINK_LH_TOPIC=agent-presence
TERMLINK_LH_INTERVAL=30

# CSV: one --listen-topic per element. dm:* is required for auto-discover
# from `agent-send.sh --to <agent_id>` (T-1834).
TERMLINK_LH_LISTEN_TOPICS=dm:cohort-agent-ring20:peer-a,agent-chat-arc

# PTY session name — required for `--to` doorbell auto-discover (T-1834).
# Match your tmux/screen/pty multiplexer session name.
TERMLINK_LH_PTY_SESSION=cohort

# Optional: pin to a non-local hub.
# TERMLINK_LH_HUB=192.168.10.122:9100

# Optional: extra args appended verbatim. Reserved for forward-compat.
# TERMLINK_LH_EXTRA_ARGS=
EOF

# 3. Activate
sudo systemctl daemon-reload
sudo systemctl enable --now termlink-listener-heartbeat@cohort-agent-ring20.service
```

## Inspect

```bash
# Status
systemctl status termlink-listener-heartbeat@cohort-agent-ring20

# Live logs
journalctl -u termlink-listener-heartbeat@cohort-agent-ring20 -f

# Confirm presence shows up
bash /opt/termlink/scripts/agent-listeners.sh \
  --filter-agent-id cohort-agent-ring20 --include-offline --json | jq .
```

The default loop cadence in `listener-heartbeat.sh` is **30 seconds**.
Allow at least 60 seconds after `start` before checking `agent-listeners`
or you may see a brief "OFFLINE / not yet seen" window.

## Uninstall

```bash
sudo systemctl disable --now termlink-listener-heartbeat@cohort-agent-ring20
sudo rm /etc/termlink/listener-heartbeat/cohort-agent-ring20.env
# (leave the template in place if other instances still use it)
```

## Env-var reference

| Var | Purpose | Required |
|-----|---------|----------|
| `TERMLINK_LH_ROLE` | `--role`, default `listener` | no |
| `TERMLINK_LH_TOPIC` | `--topic`, default `agent-presence` | no |
| `TERMLINK_LH_INTERVAL` | `--interval` seconds (min 5), default 30 | no |
| `TERMLINK_LH_LISTEN_TOPICS` | CSV → one `--listen-topic` per element | YES for `--to` |
| `TERMLINK_LH_PTY_SESSION` | `--pty-session`, target for doorbell ring | YES for `--to` |
| `TERMLINK_LH_HUB` | `--hub <addr>` (default: local hub) | no |
| `TERMLINK_LH_EXTRA_ARGS` | appended verbatim — escape hatch | no |
| `TERMLINK_LH_SCRIPT` | path to `listener-heartbeat.sh` (default `/opt/termlink/scripts/listener-heartbeat.sh`) | no |

The instance name (after the `@`) becomes the `--agent-id`. Multiple
agents on one host = one env file per agent_id, one `enable --now` per
instance.

## Hardening notes

The unit ships with conservative `NoNewPrivileges`, `PrivateTmp`,
`ProtectSystem=strict`, `ProtectHome=true`. `ReadWritePaths` allows
`/var/lib/termlink` and `/tmp`. If your hub's runtime_dir is
elsewhere, add it to `ReadWritePaths=` or the heartbeat will fail with
"permission denied" trying to read the local hub socket.

## Related

- [agent-conversations.md](agent-conversations.md) — T-1830 recipe
- [`scripts/listener-heartbeat.sh`](../../scripts/listener-heartbeat.sh) — T-1832
- [`scripts/agent-listeners-fleet.sh`](../../scripts/agent-listeners-fleet.sh) — T-1837 cross-hub
- [CLAUDE.md hub-auth-rotation protocol](../../CLAUDE.md) — when runtime_dir is volatile
