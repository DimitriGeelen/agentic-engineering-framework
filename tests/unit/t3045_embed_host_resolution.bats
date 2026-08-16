#!/usr/bin/env bats
# T-3045 A6 — how Config.EMBED_HOST resolves, pinned.
#
# WHY THIS FILE EXISTS AT ALL:
# `.context/settings.yaml` is gitignored. A wrong `embed_host:` there is invisible
# to code review, absent from CI, and survives every test the repo runs. That is
# how this install spent a day embedding against a dead loopback sidecar
# (127.0.0.1:11435, no listener) while T-3017's failover quietly answered every
# request from ollama_host — the same machine by LAN IP. Nothing was broken and
# nothing was right.
#
# These tests cannot see settings.yaml (nor should they). What they CAN pin is
# the resolution RULE in web/config.py, which is tracked: unset falls back to
# OLLAMA_HOST, set wins. The rule is the part a future edit could break silently,
# because breaking it produces no error — just a different host answering.
#
# The reachability half of the problem is A5's job (a `fw doctor` check). A test
# cannot assert an endpoint is up on an arbitrary machine; doctor can, on this one.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export FRAMEWORK_ROOT
    # Isolate from this machine's real settings.yaml — PROJECT_ROOT drives which
    # file web/config.py reads (config.py:18-21).
    TMP_ROOT="$(mktemp -d)"
    export TMP_ROOT
    mkdir -p "$TMP_ROOT/.context"
}

teardown() {
    [ -n "$TMP_ROOT" ] && rm -rf "$TMP_ROOT"
}

# Import web/config.py against a synthetic PROJECT_ROOT and print one attribute.
# Env is scrubbed of FW_/OLLAMA_ overrides so the test measures the file's rule,
# not the developer's shell.
_cfg() {
    local attr="$1"
    env -u FW_EMBED_HOST -u FW_EMBED_BULK_HOST -u OLLAMA_HOST \
        PROJECT_ROOT="$TMP_ROOT" \
        python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/web')
for m in list(sys.modules):
    if m == 'config':
        del sys.modules[m]
from config import Config
print(getattr(Config, '$attr'))
"
}

@test "t3045: with embed_host unset, EMBED_HOST falls back to OLLAMA_HOST" {
    cat > "$TMP_ROOT/.context/settings.yaml" <<'EOF'
ollama_host: http://ollama.example:11434
provider: ollama
EOF
    run _cfg EMBED_HOST
    [ "$status" -eq 0 ]
    [ "$output" = "http://ollama.example:11434" ]
}

@test "t3045: an empty embed_host falls back too — not to the empty string" {
    # `or OLLAMA_HOST` (config.py:43) makes '' falsy, so a key someone blanked
    # rather than deleted must behave identically to a deleted one. Without this
    # the embed client would be constructed against '' and fail at call time,
    # far from the cause.
    cat > "$TMP_ROOT/.context/settings.yaml" <<'EOF'
embed_host: ""
ollama_host: http://ollama.example:11434
EOF
    run _cfg EMBED_HOST
    [ "$status" -eq 0 ]
    [ "$output" = "http://ollama.example:11434" ]
}

@test "t3045: an explicit embed_host still wins over ollama_host" {
    # The T-3006 split must remain AVAILABLE. T-3045 retires it on this host
    # because OLLAMA_MAX_LOADED_MODELS went 1 -> 2; it does not remove the
    # mechanism, because a host back on =1 needs it again.
    cat > "$TMP_ROOT/.context/settings.yaml" <<'EOF'
embed_host: http://127.0.0.1:11435
ollama_host: http://ollama.example:11434
EOF
    run _cfg EMBED_HOST
    [ "$status" -eq 0 ]
    [ "$output" = "http://127.0.0.1:11435" ]
}

@test "t3045: FW_EMBED_HOST env overrides the settings file" {
    cat > "$TMP_ROOT/.context/settings.yaml" <<'EOF'
embed_host: http://from-file:11435
ollama_host: http://ollama.example:11434
EOF
    run env FW_EMBED_HOST=http://from-env:11436 \
        PROJECT_ROOT="$TMP_ROOT" \
        python3 -c "
import sys
sys.path.insert(0, '$FRAMEWORK_ROOT/web')
from config import Config
print(Config.EMBED_HOST)
"
    [ "$status" -eq 0 ]
    [ "$output" = "http://from-env:11436" ]
}

@test "t3045: EMBED_BULK_HOST falls back to OLLAMA_HOST independently of EMBED_HOST" {
    # T-3016 split query host from bulk host. A pinned embed_host must NOT drag
    # bulk reindex onto the same box — that is what made the bootstrap 29h
    # (1.9 chunks/s on the CPU sidecar vs 69.9 on the GPU host).
    cat > "$TMP_ROOT/.context/settings.yaml" <<'EOF'
embed_host: http://127.0.0.1:11435
ollama_host: http://ollama.example:11434
EOF
    run _cfg EMBED_BULK_HOST
    [ "$status" -eq 0 ]
    [ "$output" = "http://ollama.example:11434" ]
}

@test "t3045: this install does not pin a loopback sidecar that no unit can start" {
    # The live-install guard, and the only test here that reads the real file.
    # Skips when absent (fresh clone / CI) — its purpose is to fail on THIS class
    # of machine, where a human pinned a host by hand and nothing re-checks it.
    local settings="$FRAMEWORK_ROOT/.context/settings.yaml"
    [ -f "$settings" ] || skip "no settings.yaml on this install"

    local pinned
    pinned="$(grep -E '^embed_host:[[:space:]]*\S' "$settings" | head -1 || true)"
    [ -z "$pinned" ] && skip "embed_host unset — resolves to ollama_host (T-3045)"

    # If it IS pinned, it must at minimum be reachable. A pinned-but-dead host is
    # the exact T-3045 state: invisible, because failover makes it work anyway.
    local host
    host="$(printf '%s' "$pinned" | sed 's/^embed_host:[[:space:]]*//')"
    run curl -sf -m 5 "${host%/}/api/tags" -o /dev/null
    [ "$status" -eq 0 ]
}
