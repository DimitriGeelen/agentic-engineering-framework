# Canonical Session Schema (T-2417)

Contract between `fw sessions` provider adapters and the generic renderer.
Adapters live under `agents/sessions/<provider>/` and emit JSON-Lines (one
session per line) on stdout, conforming to this schema. The renderer
(`agents/sessions/render.py`) consumes the JSONL and prints the grouped
tree — it never reads provider-native formats directly.

## Required fields

| Field          | Type   | Meaning |
|----------------|--------|---------|
| `provider`     | string | Adapter identifier: `claude-code`, `cursor`, `aider`, `cline`, ... |
| `project`      | string | `basename(cwd)` if cwd is inside a git repo on this host; literal `"(loose)"` otherwise |
| `name`         | string | Session display name as the provider presents it |
| `state`        | string | One of: `needs-input` \| `working` \| `completed` |
| `age_seconds`  | int    | Seconds since session last activity (or creation if no activity recorded) |
| `session_id`   | string | Provider-native session identifier (opaque to renderer) |

## Optional fields

| Field          | Type   | Meaning |
|----------------|--------|---------|
| `cwd`          | string | Full working directory path (renderer may surface in verbose mode) |
| `description`  | string | Right-column text in CC's picker — the auto-summary / current activity snippet |
| `detail`       | string | Provider-native detail field if richer than `description` |

## State value semantics

- `needs-input`: session is paused awaiting user reply (CC's "Needs input" group)
- `working`: session is actively running a tool call or generation (CC's "Working" group)
- `completed`: session has finished its current turn and is idle (CC's "Completed" group)

Adapters MUST map their native states into these three. If a provider has a
state with no clean mapping (e.g. "error"), pick the closest of the three and
encode the distinction via `description`.

## Project semantics

`project` is a render-time bucket label, not an exact filesystem path.
Computation rule (in the adapter):

1. If `cwd` resolves to a path inside a git repo whose toplevel is a directory
   under `/opt/`, `/srv/`, `/home/<user>/projects/`, or any common project root:
   emit `project = basename(toplevel)`.
2. If `cwd` is `$HOME`, `$HOME/<simple file>`, `/tmp`, `/var/tmp`, or other
   non-repo system paths: emit `project = "(loose)"`.
3. If `cwd` cannot be resolved (provider didn't record it): emit
   `project = "(loose)"` and log the case in adapter stderr for diagnosis.

The renderer groups by `project` verbatim — adapter is the source of truth.

## Age semantics

`age_seconds` is the **integer second count since last activity**, computed
adapter-side relative to "now" at the moment the adapter runs. The renderer
formats it as relative (`< 1m`, `Nm`, `Nh`, `Nd`, `Nw`) — adapter never
emits a pre-formatted string.

## JSONL emission

- One JSON object per line, newline-separated.
- No surrounding array, no trailing comma, no header line.
- All required fields MUST be present per line.
- Optional fields MAY be omitted entirely or set to JSON `null`.
- Field order within each line is unspecified.

## Adapter exit codes

- `0`: success, JSONL emitted (zero lines is valid — no sessions)
- `2`: provider not installed / not reachable (e.g. `claude` not on PATH)
- `3`: provider returned malformed data the adapter couldn't parse
- other non-zero: unexpected error

## Adding a new adapter

1. Create `agents/sessions/<provider>/list.sh` (or `.py`)
2. Emit canonical JSONL as described above
3. Add probe binary to `bin/fw sessions` autodetect chain
4. Document any provider-specific quirks in `agents/sessions/<provider>/README.md` if needed
