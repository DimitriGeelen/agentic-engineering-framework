# T-2233 — `fw consumer-recover` Wrapper Design

**Status:** design — inception artifact for Sovereign GO on T-2233
**Audience:** the build-slice agent (post-GO) and the operator reviewing the inception
**Origin:** ring20-dashboard recovery 2026-06-06 (memory `feedback_t2232_forward_looking_recovery`)

## 1. One-liner

`fw consumer-recover <host> [<project-path>]` — SSH (or TermLink) to a legacy consumer's host, clone the canonical upstream framework to `/tmp`, run `fw upgrade` against the consumer with explicit `FRAMEWORK_ROOT=/PROJECT_ROOT=` env scoping, then clean up. Dry-run by default.

## 2. Why we need it (1 paragraph)

Consumers vendored before T-1634 (auto-clone from `upstream_repo:`) or T-2232 (durable in-consumer fallback chain) cannot self-heal. Their vendored `bin/fw` either lacks `--from-upstream` or never wrote the `.upstream` sentinel — both legs of T-2232's three-leg fallback miss. T-1542's bare-from-consumer guard correctly refuses to overwrite, but the recovery path is a four-step recipe with mandatory `env` scoping (without it, `resolve_framework` re-picks the consumer's broken vendored copy — same root cause as T-2099). The recipe is mechanical, not subtle, and a forgotten `FRAMEWORK_ROOT=` produces an opaque second failure. Wrapping it into a verb removes the typo class and turns the recovery teaching from "remember the memo" into "read the verb".

## 3. CLI surface

```
fw consumer-recover <host> [<project-path>] [options]

Arguments:
  <host>           SSH host or TermLink-registered host name (required)
  <project-path>   Consumer project path on the host (default: $HOME/<consumer-from-host>; see §3.1)

Options:
  --apply              Execute (default is dry-run; print recipe only)
  --upstream URL       Override auto-detected upstream URL
  --via {ssh,termlink} Force transport (default: termlink if registered, else ssh)
  --keep-temp          Leave /tmp/fw-fresh-<sha> on consumer after upgrade
  --dry-run            Explicit dry-run (default; included for symmetry)
  --json               Emit structured result to stdout for dispatchers

Exit codes:
  0   recipe printed (dry-run) OR upgrade succeeded
  1   precondition failed (host unreachable, git missing, /tmp not writable)
  2   consumer is post-T-2232 — refused with redirect (use plain fw upgrade)
  3   recovery executed but post-upgrade verification (doctor) reported FAIL
```

### 3.1 Project path resolution

If `<project-path>` is omitted, the wrapper does a best-effort lookup via:

1. `--project-path` flag if passed
2. `${FW_CONSUMER_PATH}` env if set
3. SSH probe: `ssh HOST 'ls -d /root/*/.framework.yaml /home/*/*/.framework.yaml 2>/dev/null | head -1'` — if exactly one match, use it; if multiple, fail with a clear list

The "remember the path" failure mode in the ring20 recovery was the second-most-painful typo class after env scoping; resolving the obvious case removes it.

## 4. Wrapper flow

```
STEP 0  classify args, resolve transport, resolve upstream URL
STEP 1  precondition probes via transport
        - ssh/termlink reachable
        - git available on host
        - project path exists and contains .framework.yaml
STEP 2  sentinel check (idempotency)
        - cat <project>/.agentic-framework/.upstream
        - if present + non-empty: print T-2232-vintage redirect + exit 2
STEP 3  print recipe (always — dry-run output OR the script we're about to run)
STEP 4  if --apply: execute the recipe via heredoc-driven transport
        - mktemp -d /tmp/fw-fresh.XXXX
        - git clone <upstream> $tmpdir
        - env FRAMEWORK_ROOT=$tmpdir PROJECT_ROOT=<project> $tmpdir/bin/fw upgrade <project>
        - capture stdout/stderr/exit
STEP 5  verification (--apply only)
        - env FRAMEWORK_ROOT=$tmpdir $tmpdir/bin/fw doctor (against the consumer, exit 0 expected)
        - record per-suite for the bus envelope
STEP 6  cleanup
        - rm -rf $tmpdir UNLESS --keep-temp
STEP 7  emit result
        - human-readable summary on stderr
        - --json: structured envelope on stdout
        - if dispatched, fw bus post (the worker, not the wrapper, owns this)
```

## 5. Transport abstraction

```
# lib/consumer-recover/transport-ssh.sh
recover_ssh_exec()   { ssh -o BatchMode=yes "$host" "$@" ; }
recover_ssh_script() { ssh -o BatchMode=yes "$host" bash -s -- "$@" ; }   # stdin = heredoc

# lib/consumer-recover/transport-termlink.sh
recover_tl_exec()   { termlink remote exec "$host" -- "$@" ; }
recover_tl_script() { termlink remote exec "$host" -- bash -s -- "$@" ; } # stdin = heredoc
```

Both legs expose the same two verbs (`_exec` for single commands, `_script` for heredoc-driven multi-line). The wrapper picks the leg at STEP 0 and never branches on transport again. Tests can swap a mock transport that records calls without touching SSH/TermLink.

## 6. Heredoc — the actual recovery script

```bash
# This is what the wrapper runs on the consumer host (via SSH stdin or TermLink remote exec).
# Generated from a template with $PROJECT_PATH and $UPSTREAM substituted.

set -euo pipefail

PROJECT_PATH="$1"
UPSTREAM="$2"

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "consumer-recover: project path '$PROJECT_PATH' not found on $(hostname)" >&2
    exit 1
fi

TMPDIR=$(mktemp -d /tmp/fw-fresh.XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

echo "consumer-recover: cloning $UPSTREAM into $TMPDIR" >&2
git clone --depth 1 "$UPSTREAM" "$TMPDIR" >&2

echo "consumer-recover: running env-scoped upgrade" >&2
env FRAMEWORK_ROOT="$TMPDIR" PROJECT_ROOT="$PROJECT_PATH" \
    "$TMPDIR/bin/fw" upgrade "$PROJECT_PATH"

echo "consumer-recover: post-upgrade doctor" >&2
env FRAMEWORK_ROOT="$TMPDIR" PROJECT_ROOT="$PROJECT_PATH" \
    "$TMPDIR/bin/fw" doctor

# $TMPDIR removed by trap — unless --keep-temp, in which case the wrapper
# overrides the trap when generating the script.
```

Notes:
- `set -euo pipefail` + `trap 'rm -rf' EXIT` is the atomic cleanup — partial-clone debris doesn't survive a kill.
- `--depth 1` keeps the clone fast (we're running this on prod hosts; full history isn't needed).
- The two `env` invocations are the load-bearing part. Skipping either re-picks the consumer's broken vendored copy via `resolve_framework`.

## 7. Dry-run output (the teaching artifact)

```
$ fw consumer-recover ring20-dashboard /root/ring20-dashboard
=== fw consumer-recover — DRY RUN ===

Host:          ring20-dashboard
Project path:  /root/ring20-dashboard
Upstream URL:  https://github.com/DimitriGeelen/agentic-engineering-framework.git
Transport:     ssh (via ~/.ssh/config)

Would execute on host:

  set -euo pipefail
  TMPDIR=$(mktemp -d /tmp/fw-fresh.XXXXXX)
  trap 'rm -rf "$TMPDIR"' EXIT

  git clone --depth 1 \
    https://github.com/DimitriGeelen/agentic-engineering-framework.git "$TMPDIR"

  env FRAMEWORK_ROOT="$TMPDIR" PROJECT_ROOT="/root/ring20-dashboard" \
    "$TMPDIR/bin/fw" upgrade /root/ring20-dashboard

  env FRAMEWORK_ROOT="$TMPDIR" PROJECT_ROOT="/root/ring20-dashboard" \
    "$TMPDIR/bin/fw" doctor

To execute, re-run with --apply.
```

The operator can copy-paste the printed block as a runbook entry, audit it, or hand it to a peer — the wrapper becomes a teaching surface.

## 8. Tests (bats, mocked transport)

Each test asserts on the *generated heredoc* string, not real SSH/TermLink calls:

```
tests/unit/test_consumer_recover.bats:
  - dry-run prints recipe with all four bullets
  - dry-run substitutes $PROJECT_PATH and $UPSTREAM correctly
  - sentinel detected → exit 2 + redirect message
  - missing host → exit 1 + clear stderr
  - --keep-temp omits the trap line
  - --upstream URL overrides auto-detect
  - --via ssh forces SSH even if TermLink would resolve
  - --json emits structured outcome with host/project/upstream/exit
```

Mocked transport: a shell function that records call args to a file and returns whatever was pre-staged. No real network.

## 9. Wire-up

- `bin/fw:~6800` (after `upgrade)`): add `consumer-recover)` dispatcher → `lib/consumer-recover.sh`
- `fw help`: one-liner under "Setup and upgrade"
- `CLAUDE.md` Quick Reference: add to "Setup and upgrade" block
- `docs/reference/`: a short reference page mirroring §3 + §7 here
- The `feedback_t2232_forward_looking_recovery` memory can then point at the verb instead of carrying the recipe in prose

## 10. What this is NOT

- Not a replacement for T-2232 — that ships the self-heal path for *new* consumers
- Not a fleet tool — single-host orchestration; fleet-parallel needs a separate task
- Not a Tier-0 verb — Tier-1 with `--apply` opt-in; no special approval gate
- Not a `fw upgrade` flag — sibling verb, separate `lib/consumer-recover.sh`
- Not an arc — the build slice fits in one ~2-hour session; arc would be over-scoping

## 11. Build slice breakdown (~2 hours)

| Slice | Time | Deliverable |
|-------|------|-------------|
| B-1   | 30m  | `lib/consumer-recover.sh` skeleton + flag parser + sentinel detection |
| B-2   | 45m  | Transport legs (SSH + TermLink) + heredoc generator + dry-run printer |
| B-3   | 30m  | bats tests (8 cases above) + mocked transport fixture |
| B-4   | 15m  | `bin/fw` dispatcher + `fw help` + CLAUDE.md Quick Reference + reference doc |

Reviewer + close on landing. P-011 verification block in the build task will run the bats and `fw reviewer T-NNNN`.

## 12. Risk register

- **R-1:** SSH heredoc quoting bugs (escape of `$`, backticks). Mitigation: heredoc uses `'EOF'` (literal) and substitutes only via positional args (`$1`, `$2`).
- **R-2:** Disk pressure on consumer `/tmp` — a ~50MB framework checkout could fail on tight containers. Mitigation: `df /tmp` precondition; clear failure if <100MB free.
- **R-3:** GitHub rate-limit during burst recovery. Mitigation: `--depth 1` minimizes hit weight; retry once on transient (sibling to the upstream-issue-15 retry policy).
- **R-4:** Consumer using a fork or private mirror. Mitigation: `--upstream URL` explicit override (already in §3).
- **R-5:** Operator runs `--apply` against the wrong host. Mitigation: dry-run-by-default makes the destination explicit BEFORE execution; the printed block names the host on the first line.
