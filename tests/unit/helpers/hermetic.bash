# tests/unit/helpers/hermetic.bash — one hermetic fixture for bats (T-4378).
#
# Replaces the per-file fixtures that each fixed only the leak their author had
# already hit (T-2746 env -i temp dir, T-4313 project marker, T-4318 private
# TMPDIR, T-4315 sidecar, t4347 PROJECT_ROOT). The pytest twin is
# tests/unit/_hermetic.py; keep the two contracts the same.
#
#   load helpers/hermetic
#   setup()    { hermetic_setup --project; }   # or no flag: an empty non-project dir
#   teardown() { hermetic_teardown; }
#
# Each test gets:
#   HERMETIC_ROOT     private mktemp dir, removed at teardown
#   TMPDIR            $HERMETIC_ROOT/tmp, exported — no shared /tmp listing to race on
#   HERMETIC_HOME     an empty directory; pass HOME="$HERMETIC_HOME" where you want it
#                     (not the default: git and ~/.claude read HOME)
#   HERMETIC_PROJECT  $HERMETIC_ROOT/project and the cwd. With --project it carries the
#                     markers fw needs to accept it (.tasks/, .context/), so fw never
#                     auto-inits; without, it is empty
#   PROJECT_ROOT, FRAMEWORK_ROOT, CLAUDE*, FW_*, TERMLINK_SESSION_ID (T-4524) are
#   unset in the test shell, so
#   nothing inherited from a worker or the nightly cron routes a call to the checkout.
#   FW_VERB_TELEMETRY=0 is then set, so no verb is counted into the checkout (T-4523).
#   hermetic_project DIR   add the project markers to DIR
#   hermetic_run CMD...    `run` CMD with stdin=/dev/null
#
# Tripwires — hermetic_teardown fails the test when one fired:
#   termlink    the T-4205 recording fake is first on PATH; a non-probe call fails
#   watchtower  FW_PORT names a decoy listener this helper owns; any connection fails
#               unless the test called hermetic_allow_watchtower "<reason>"
#   live state  the live sidecar's explicit-stop marker appears (T-4315), or a new
#               top-level entry appears in the real checkout or its .context/
# Limit: a hard-coded `localhost:3000` bypasses FW_PORT and is not seen.

HERMETIC_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

# shellcheck source=tests/git_fence.bash
source "$HERMETIC_REPO/tests/git_fence.bash"

hermetic_strip_env() {
    local v
    for v in $(compgen -e); do
        case "$v" in
            PROJECT_ROOT|FRAMEWORK_ROOT|CLAUDE*|FW_*|TERMLINK_SESSION_ID) unset "$v" ;;
        esac
    done
}

hermetic_project() {
    mkdir -p "$1/.tasks/active" "$1/.tasks/completed" "$1/.context/working" "$1/.context/project"
}

_hermetic_snapshot() {
    { ls -A "$HERMETIC_REPO"; ls -A "$HERMETIC_REPO/.context" | sed 's|^|.context/|'; } 2>/dev/null | sort
}

_hermetic_start_decoy() {
    local portfile="$HERMETIC_ROOT/.decoy.port" i
    python3 - "$portfile" "$HERMETIC_ROOT/.decoy.log" >/dev/null 2>&1 3>&- <<'PY' &
import os, socket, sys
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen(16)
tmp = sys.argv[1] + ".tmp"
with open(tmp, "w") as fh:
    fh.write(str(s.getsockname()[1]))
os.replace(tmp, sys.argv[1])
while True:
    c, _ = s.accept()
    c.settimeout(0.5)
    try:
        first = c.recv(256).split(b"\r\n", 1)[0].decode("latin-1")
    except OSError:
        first = ""
    with open(sys.argv[2], "a") as fh:
        fh.write("connect %s\n" % (first or "(no request)"))
    c.close()
PY
    HERMETIC_DECOY_PID=$!
    for i in $(seq 1 100); do
        [ -s "$portfile" ] && break
        sleep 0.02
    done
    [ -s "$portfile" ] || { echo "hermetic: decoy Watchtower did not start" >&2; return 1; }
    FW_PORT="$(cat "$portfile")"
    export FW_PORT
}

hermetic_setup() {
    HERMETIC_ROOT="$(mktemp -d)"
    HERMETIC_HOME="$HERMETIC_ROOT/home"
    HERMETIC_PROJECT="$HERMETIC_ROOT/project"
    mkdir -p "$HERMETIC_ROOT/tmp" "$HERMETIC_HOME" "$HERMETIC_PROJECT"
    [ "${1:-}" = "--project" ] && hermetic_project "$HERMETIC_PROJECT"
    export HERMETIC_ROOT HERMETIC_HOME HERMETIC_PROJECT

    _hermetic_snapshot > "$HERMETIC_ROOT/.live-before"
    HERMETIC_SIDECAR_STOPPED="$HERMETIC_REPO/.context/sidecar/watcher/stopped"
    HERMETIC_SIDECAR_WAS_STOPPED=0
    [ -e "$HERMETIC_SIDECAR_STOPPED" ] && HERMETIC_SIDECAR_WAS_STOPPED=1

    hermetic_strip_env
    # T-4523: the strip removes the runner's FW_VERB_TELEMETRY=0, and fw run outside
    # a project still counts its verb into the checkout's tracked .verb-counter.
    export FW_VERB_TELEMETRY=0
    TMPDIR="$HERMETIC_ROOT/tmp"
    export TMPDIR
    fence_git_discovery

    export PATH="$HERMETIC_REPO/tests/lib/termlink-tripwire:$PATH"
    export TERMLINK_TRIPWIRE_LOG="$HERMETIC_ROOT/termlink-tripwire.log"
    export TERMLINK_RUNTIME_DIR="$HERMETIC_ROOT/no-live-hub"

    _hermetic_start_decoy || return 1
    cd "$HERMETIC_PROJECT" || return 1
}

# hermetic_allow_watchtower REASON — the code under test probes Watchtower on purpose
# (e.g. fw init's /api/_identity check, lib/watchtower.sh:67). The decoy still answers,
# so the live server is never reached; only the tripwire is silenced, and the reason
# is required so the exemption reads as a decision.
hermetic_allow_watchtower() {
    [ -n "${1:-}" ] || { echo "hermetic_allow_watchtower: a reason is required" >&2; return 1; }
    HERMETIC_WATCHTOWER_ALLOWED="$1"
}

hermetic_run() {
    run "$@" </dev/null
}

# hermetic_tripwires — 0 when nothing fired; otherwise names each leak on stderr.
hermetic_tripwires() {
    local rc=0 new
    if [ -s "$TERMLINK_TRIPWIRE_LOG" ] && grep -q '^call ' "$TERMLINK_TRIPWIRE_LOG"; then
        echo "HERMETIC TRIPWIRE: termlink non-probe call: $(grep '^call ' "$TERMLINK_TRIPWIRE_LOG" | head -3 | tr '\n' ' ')" >&2
        rc=1
    fi
    if [ -s "$HERMETIC_ROOT/.decoy.log" ] && [ -z "${HERMETIC_WATCHTOWER_ALLOWED:-}" ]; then
        echo "HERMETIC TRIPWIRE: the test connected to Watchtower (decoy port $FW_PORT): $(head -3 "$HERMETIC_ROOT/.decoy.log" | tr '\n' ' ')" >&2
        rc=1
    fi
    if [ "$HERMETIC_SIDECAR_WAS_STOPPED" = 0 ] && [ -e "$HERMETIC_SIDECAR_STOPPED" ]; then
        echo "HERMETIC TRIPWIRE: the live sidecar was explicitly stopped ($HERMETIC_SIDECAR_STOPPED); restart: bin/fw sidecar start" >&2
        rc=1
    fi
    new="$(_hermetic_snapshot | comm -13 "$HERMETIC_ROOT/.live-before" -)"
    if [ -n "$new" ]; then
        echo "HERMETIC TRIPWIRE: new entries in the real checkout: $(echo "$new" | tr '\n' ' ')" >&2
        rc=1
    fi
    return "$rc"
}

hermetic_teardown() {
    local rc=0
    cd "$HERMETIC_REPO" || true
    if [ -n "${HERMETIC_DECOY_PID:-}" ]; then
        kill "$HERMETIC_DECOY_PID" 2>/dev/null
        wait "$HERMETIC_DECOY_PID" 2>/dev/null
    fi
    [ -n "${HERMETIC_ROOT:-}" ] && [ -d "$HERMETIC_ROOT" ] || return 0
    hermetic_tripwires || rc=1
    rm -rf "$HERMETIC_ROOT"
    return "$rc"
}
