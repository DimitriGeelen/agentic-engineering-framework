# Meter-only sidecar (AEF adapter/2 trial, T-3769)

A TermLink sidecar that **only takes `termlink.adapter/2` reports** (meter, `origin_checked`, the main-lease view)
and **never pulls mail from the hub, never hands mail to the session, never rings the doorbell and never types into
the session**. It is for a session that already has its own receiver: the AEF framework session on .107 in the
AEF T-5054 trial (request P-44, conversation `termlink-arc011-p44-adapter2`).

There is no special build or mode. It is the ordinary sidecar (`termlink sidecar start --config F`) with two flag
files written into its store **before the first start** and a third flag never written:

| flag in `<store>/sidecar/<agent>/` | effect | read |
|---|---|---|
| `delivery.off` (present) | `pull` hands nothing over (`{"none":true,"why":"delivery-off"}`); the doorbell switch also needs delivery on, so it is off twice | on every call, fail-closed (`policy::delivery_enabled`) |
| `receive.drained` (present) | the receive loop takes nothing from the hub; mail for this agent stays on the hub | on every pass (`policy::receiving_enabled`) |
| `doorbell-on` (**absent**) | the doorbell and its watchdog never ring or type (B-16) | on every tick (`doorbell::switch_on`) |

Proof: `crates/termlink-sidecar/tests/t3769_meter_only.rs` (below).

## 1. Question 1: the minimal config, and how the socket path is chosen

Agent name: **`aef-meter`**. It must be the `agent_id` the AEF adapter puts in every report (the meter refuses
"another agent's id"). Use a name that is **not** the one AEF's own receiver uses on the hub, so the two never share
a hub inbox. The receive loop is drained anyway; the separate name means even an accidental undrain cannot touch
AEF's mail.

`/etc/termlink-sidecar/aef-meter.json`:

```json
{
  "agent": "aef-meter",
  "instance": "aef-meter.t5054-trial",
  "hub": {"type": "unix", "path": "/var/lib/termlink/hub.sock"},
  "hub_id": "<output of: termlink sidecar hub-id --hub-socket /var/lib/termlink/hub.sock>",
  "key_file": "/root/.termlink/identities/aef-meter.key",
  "key_register": "/etc/termlink-sidecar/keys/aef-meter.pub",
  "roster": [],
  "queue_path": "/var/lib/termlink-sidecar/aef-meter/outbox.sqlite",
  "book": {"peers": {"<AEF receiver agent id>": "<its instance id>"}},
  "main_project": "<the project name AEF's hooks pass to termlink main claim --project>"
}
```

Field by field:

1. `hub`, `hub_id`: the local hub on .107 (runtime dir `/var/lib/termlink`). `hub_id` is read, never typed:
   `termlink sidecar hub-id --hub-socket /var/lib/termlink/hub.sock`.
2. `key_file`, `key_register`: production never mints a key. The key file must exist and its public key must equal
   the one-line register file (64 hex), or the start is refused. Both are written by the operator's script.
3. `roster: []`: nobody is a trusted sender. A third belt: if mail ever did arrive it would be `HELD FOR OPERATOR`,
   never delivered. (The proof uses a roster sender on purpose, to show the two flags alone stop delivery.)
4. `book`: production refuses an empty address book. One entry is enough; nothing here sends. Do **not** set
   `book.main`: a pinned main makes the sidecar post liveness notes to the hub, which a meter does not need.
5. `main_project`: turns on the read-only lease view (`status.main.lease`, polled from `main:<project>` on the hub)
   and the waiting-mail signal. It never claims; the hooks claim (question 4).
6. `poll_ms` / `timeout_ms` may be left out (500 ms / 10 s).
7. No `enc_key_register`: no encryption key; encrypted blobs are refused, which a meter never receives.

The environment the process runs with (`/etc/termlink-sidecar/<project>--aef-meter.env`, the unit's EnvironmentFile):

```
PROJECT_DIR=<the AEF repo on .107>
AGENT=aef-meter
SIDECAR_CONFIG=/etc/termlink-sidecar/aef-meter.json
SIDECAR_BIN=<path of termlink 0.12.61, e.g. /root/.local/bin/termlink>
TERMLINK_SIDECAR_STORE=/var/lib/termlink-sidecar/aef-meter
TERMLINK_RUNTIME_DIR=/var/lib/termlink
HOME=/root
TERMLINK_MAIN_PROJECT=<same as main_project>
```

The store root `/var/lib/termlink-sidecar/aef-meter/` carries the production marker `.termlink-sidecar-root`
(first line `termlink-sidecar-production v1`, owned by the user that runs the sidecar, mode 0644). Without it the
sidecar refuses to start (it only runs in a marked test estate or under a marked production root).

**Socket path.** It is not configured; it is derived from the runtime dir and the agent name
(`api::socket_path`): `<TERMLINK_RUNTIME_DIR>/sidecar/<agent>.<scope>.sock`. Here:

| scope | path | who |
|---|---|---|
| send | `/var/lib/termlink/sidecar/aef-meter.send.sock` | the AEF hooks: report lines go here; set `TERMLINK_SIDECAR_SOCKET` to it in the session |
| status | `/var/lib/termlink/sidecar/aef-meter.status.sock` | `{"op":"status"}` |
| admin | `/var/lib/termlink/sidecar/aef-meter.admin.sock` | the operator only (delivery, drain) |

The directory is 0700 and each socket 0600; a caller with another uid is refused (`SO_PEERCRED`). So the AEF hooks
must run as the same user as the sidecar. The start prints the send socket: `termlink-sidecar: aef-meter running;
send socket ...`.

**What the hooks send.** One JSON object per line on the send socket, no `op` field:
`{"schema":"termlink.adapter/2","harness":"claude-code","agent_id":"aef-meter","session_id":...,"event":...,"at_ms":...}`
plus the event's fields (P-2 order fields `boot_id`, `mono_ns` when the hook has them). The reply is one line:
`{"ok":true}`; for `prompt_submit` also `"origin_checked"` and `"basis_checked"`. AEF must **not** wire
`termlink sidecar hook post-tool-use|stop` (those call `pull`); with `delivery.off` they would hand nothing over
anyway.

## 2. Question 2: the supervised start

Every step is one operator script (a runme action), idempotent and checked on disk:

1. `termlink sidecar tools install --system`: installs the supervise script and the `termlink-sidecar@.service`
   template under `/usr/local/share/termlink/sidecar/`, the unit in systemd, the 10-minute backstop crontab, and
   runs `daemon-reload` when the unit changed. Already installed on .107 for the TermLink pair; re-running is a no-op.
2. Key: create `/root/.termlink/identities/aef-meter.key` once
   (`TERMLINK_IDENTITY_FILE=<file> termlink identity show --resolve --json` creates and prints it) and write its
   public key to `/etc/termlink-sidecar/keys/aef-meter.pub` (0644). A different existing key is a failure, never
   overwritten.
3. Store root `/var/lib/termlink-sidecar/aef-meter/` (0700) with the production marker.
4. **The flags, before any start:** `mkdir -p -m 0700 /var/lib/termlink-sidecar/aef-meter/sidecar/aef-meter`, then
   write `delivery.off` and `receive.drained` in it (any content; a reason line is good), and verify that
   `doorbell-on` does not exist. Written first, there is no moment in which the sidecar could pull or deliver.
5. Config and env file as in section 1; `hub_id` read from the hub.
6. The project's `.framework.yaml` needs `SIDECAR_KEEP_RUNNING: on` (the unit's `ExecCondition` runs
   `sidecar-supervise.sh may-run`, which reads it; absent means off and the unit will not start). Check first that
   nothing of AEF's own reads that key differently.
7. Start: `systemctl enable --now termlink-sidecar@<project>--aef-meter.service`, or
   `sidecar-supervise.sh start <project>--aef-meter` (which picks systemd when present).
8. Check (the script must verify, not trust the exit code):
   `TERMLINK_SIDECAR_SOCKET=/var/lib/termlink/sidecar/aef-meter.send.sock termlink sidecar status --json` (it finds
   the status socket beside the send socket) shows `"delivery":"off"`, `"doorbell":{"switch":"off",...}` and a
   `main.lease` object; `delivery.off` and `receive.drained` are still in the store dir and `doorbell-on` is not.

To stop: `sidecar-supervise.sh stop <project>--aef-meter` (writes the stop marker first, so neither systemd nor the
backstop restarts it). Removing the trial: stop, then the operator removes the env file; the flags can stay.

## 3. Question 3: is termlink 0.12.61 new enough?

Yes. Installed 0.12.61 on .107 has P-2 (the report order fields `boot_id` / `mono_ns`, parity fixture
`p2-report-ordering.json`) and E-153 (`origin_checked` / `basis_checked` in the `prompt_submit` reply). It also has
every verb used above (`sidecar start`, `sidecar hub-id`, `sidecar tools install`, `main origin-reporting`). No
upgrade is needed first.

What the check can and cannot do in this trial: the receiver checks a `human` prompt against the session's PTY input
counters (S1). That needs the Claude Code session to run inside a TermLink PTY session the sidecar can bind. When it
cannot bind one, `status.activity.sessions.<id>.s1` says `unknown: no TermLink PTY session is bound to this session`
and `origin_checked` is the adapter's own origin (measured: `human` / `inferred` in, `human` / `inferred` back). It
never upgrades an origin; it can only downgrade one. Since the doorbell is off, no doorbell line can be mistaken
for a person here.

## 4. Question 4: the hub side (origin reporting)

Yes. Until the operator switches the harness on, the lease ignores the origin a claim carries: a claim without
origin, or from a harness that is not switched on, counts as it did before B-25 ("built"). The switch is the
operator act 17.10.a, run from a runme action only, after the adapter passes the parity fixtures:

```
termlink main origin-reporting --project <project> --harness claude-code --by <operator>
```

It posts an `OriginReporting {harness, on, by, at_ms}` event to the hub topic `main-config:<project>` (the project's
home hub, here `/var/lib/termlink/hub.sock`), reads the record back, and fails if it does not read back. It is per
project and per harness, and it is undone with `--off`. `termlink main status --project <project> --json` shows the
lease with the reporting harnesses applied. The meter-only sidecar does not need it to run; the hooks' claims need
it for their origin to count.

## 5. The proof

`cargo test -p termlink-sidecar --test t3769_meter_only` (a throwaway estate with its own hub under `/tmp/tl-estate-*`;
nothing on the live host is opened). A roster peer puts a message for `aef-meter` on the hub before it starts; the
meter starts with the two flags already written. Then:

1. `session_start` and `ready` reports are accepted (`{"ok":true}`); a malformed one is ignored (`ok:false`).
2. `prompt_submit` is answered with `origin_checked` and `basis_checked`; the hook helper `hook::checked_origin`
   reads the same.
3. `status` shows the meter's session (after one meter tick: `ready`, `last_prompt`, `conversation`, `s1`), the
   counters, `delivery: off`, `doorbell.switch: off`, and the lease view of `main:<project>`.
4. After several receive polls and ticks: the message is never `RECEIVED`/`STORED` (it stays on the hub), the store
   holds no message, `pull` answers `none`, the doorbell rang 0 times, and `doorbell-on` was never created.

Negative control (same config, same process): the operator's admin socket lifts the drain and turns delivery on;
the waiting message is then received and `pull` hands it over in a frame. A mutant of the test that does not write
the two flags fails at step 4 (`drained sidecar received the mail: stage STORED`).
