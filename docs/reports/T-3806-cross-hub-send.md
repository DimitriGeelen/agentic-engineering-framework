# T-3806 — cross-hub `fw sidecar send --hub <remote>`

## Problem

`lib/sidecar/termlink_transport.py` `probe_hub()` refused **every** remote hub
with "version floor is unestablished — no unauthenticated version read exists
(T-2415); supply hub credentials to clear this gate". No code path accepted
credentials, so the advice could not be followed. Reported by ring20-dashboard
(their T-2459), reproduced by ring20-manager, on v1.7.0 and bleeding-edge.

## What termlink already offers (measured 2026-10-04, termlink 0.12.103)

| Surface | Authenticated? | Returns version? | Single hub? |
|---|---|---|---|
| `termlink hub probe <addr>` | no (TLS only) | no | yes |
| `termlink remote ping <hub>` | yes | no (`auth_ms`, `sessions`) | yes |
| `termlink remote doctor <hub> --json` | yes | **no**, despite `--help` naming "version" (checks: connectivity, sessions, inbox) | yes |
| `termlink fleet status --json` | yes | no | no |
| **`termlink fleet doctor --json`** | **yes**, each hubs.toml profile's own secret + TOFU pin | **yes**, `hubs[].hub_version` | **no**: walks every profile |
| hub RPC `hub.version` (via MCP `termlink_remote_call`) | yes | yes: `{hub_version, protocol_version, control_plane_version}` | yes, but there is no CLI verb for an arbitrary remote RPC |

So an authenticated version read **does exist** and uses credentials termlink
already holds. Where those credentials live: `~/.termlink/hubs.toml`
`[hubs.<name>] address = "host:port"`, `secret_file = "<path to 32-byte hex>"`
(or an inline `secret`). The TLS pin lives in `~/.termlink/known_hubs` (TOFU).
Profiles are managed with `termlink remote profile add|list|remove`.

## Fix (shipped)

`probe_hub(<remote>)`:

1. TLS reachability (`hub probe`, unchanged). A hubs.toml profile **name** is
   resolved to its address first.
2. Credential resolution from hubs.toml by profile name or address. Refused by
   name when:
   - hubs.toml is absent or unparseable (the path is named);
   - no profile has that name or address (path and hub named, plus the
     `termlink remote profile add <name> <hub> --secret-file <path>` remedy);
   - the profile's `secret_file` is missing or unreadable (profile and path named),
     or the profile sets neither `secret_file` nor `secret`.
3. Authenticated version read: `termlink fleet doctor --json --timeout 5`. The
   row for the matching profile must be `status: ok` with a parseable
   `hub_version`. An auth failure is refused with termlink's own error and the
   `secret_source`.
4. `VERSION_FLOOR` is checked on that version. When several profiles share the
   address, one good profile is enough.

Live, read-only check on this host: `192.168.10.121:9100` and `ring20-management`
both pass at 0.12.103. An unknown address is refused, naming
`/root/.termlink/hubs.toml` and the remedy.

## Cost and limits (true, not fixed here)

- `fleet doctor` walks **every** profile, so the probe pays for the slowest
  hub, capped by `--timeout 5` per hub and a 90 s subprocess ceiling. On this
  host (6 profiles, 1 down) it took a few seconds.
- The **post** leg (`termlink channel post --hub <addr>`) was not exercised
  live in this task, since the worker rules forbid sending sidecar messages.
  `channel post --hub` takes an address (`host:port`), not a profile name, so
  pass the address to `fw sidecar send --hub`. The probe accepts either.

## TermLink-side need (filed here for TermLink)

**A single-hub, authenticated version read in the CLI**, e.g.
`termlink remote version <hub|profile> --json` returning the `hub.version` RPC
result, or have `termlink remote doctor --json` emit the `version` check its
`--help` already promises. Either one lets the sidecar avoid walking the fleet
per probe. Home: TermLink (Gap Homing, T-1333). This is a cost improvement,
not a correctness blocker: the current path is correct.
