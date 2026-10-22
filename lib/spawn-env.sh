#!/usr/bin/env bash
# lib/spawn-env.sh — T-4647 (SEV-1 T-4635, G-116): the environment a spawned session or
# dispatch worker starts with is built from an ALLOW-LIST, never "the caller's minus a few".
#
# A `termlink spawn` that finds no tmux server starts one, and that server's global env is the
# env it was started with; every later session on it inherits that. The deny-list this replaced
# (T-4217, T-4222: `env -u PROJECT_ROOT -u … `) failed open — 1409-sprind's CONTEXT_DIR/TASKS_DIR
# seeded the host's default server and, through it, other projects' sessions and workers.
#
# TermLink variables are named exactly, never by prefix (T-4665): only where the hub lives
# (TERMLINK_RUNTIME_DIR, TERMLINK_RUNTIME_DIR_FALLBACK) and which binary to call (TERMLINK_BIN).
# Identity, socket and per-session variables (TERMLINK_AGENT_ID, TERMLINK_IDENTITY_*,
# TERMLINK_SIDECAR_*, TERMLINK_SESSION*) belong to the spawning agent: a worker that inherited
# them could read its mail and sign as it.
#
# Allowed: host identity and locale, terminal, tmux/TermLink plumbing, XDG/D-Bus/ssh-agent,
# proxies and CA bundles, and the model credentials a worker authenticates with. Everything
# else — project paths (PROJECT_ROOT, FRAMEWORK_ROOT, CONTEXT_DIR, TASKS_DIR), every FW_*,
# GIT_*, PYTHONPATH, CLAUDECODE … — is dropped; a worker's own paths and FW_* come from its
# run.sh/env.sh, derived from its --project.
#
# The dispatch runtime (run.sh, heredoc in agents/termlink/termlink.sh) carries a copy of
# FW_SPAWN_ENV_ALLOW, because it must stay self-contained; t4647 bats pins the two equal.

FW_SPAWN_ENV_ALLOW='^(HOME|USER|LOGNAME|SHELL|LANG|LANGUAGE|LC_[A-Z_]+|TERM|COLORTERM|TZ|TMPDIR|TMUX|TMUX_PANE|TMUX_TMPDIR|TERMLINK_RUNTIME_DIR|TERMLINK_RUNTIME_DIR_FALLBACK|TERMLINK_BIN|XDG_[A-Z_]+|DBUS_SESSION_BUS_ADDRESS|SSH_AUTH_SOCK|ANTHROPIC_[A-Z0-9_]+|CLAUDE_CONFIG_DIR|CLAUDE_CODE_OAUTH_TOKEN|http_proxy|https_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|SSL_CERT_FILE|SSL_CERT_DIR|NODE_EXTRA_CA_CERTS)$'

# fw_spawn_path [binary...] — print a PATH built by construction (T-4666), never the caller's:
# this framework's bin, the directories of the resolved claude/termlink/node (and of any
# binary named as an argument), ~/.local/bin, ~/.cargo/bin, then the system dirs — only those
# that exist, each once. A caller PATH with /opt/other/.agentic-framework/bin first made the
# worker run another project's fw; a resolved binary sitting in some other
# .agentic-framework/bin is not followed. node is resolved because MCP servers start via npx.
fw_spawn_path() {
    local fwbin _b _d _out="" _seen=":"
    local _dirs=()
    fwbin="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin"
    _dirs+=("$fwbin")
    for _b in claude termlink node "$@"; do
        _b=$(command -v "$_b" 2>/dev/null) || continue
        case "$_b" in /*) _dirs+=("${_b%/*}") ;; esac
    done
    [ -n "${HOME:-}" ] && _dirs+=("$HOME/.local/bin" "$HOME/.cargo/bin")
    _dirs+=(/usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin)
    for _d in "${_dirs[@]}"; do
        case "$_d" in */.agentic-framework/bin) [ "$_d" = "$fwbin" ] || continue ;; esac
        [ -d "$_d" ] || continue
        case "$_seen" in *":$_d:"*) continue ;; esac
        _seen="$_seen$_d:"
        _out="${_out:+$_out:}$_d"
    done
    printf '%s\n' "$_out"
}

# fw_spawn_env — set the array FW_SPAWN_ENV to NAME=VALUE pairs of the exported variables that
# match FW_SPAWN_ENV_ALLOW, plus PATH=$(fw_spawn_path). Use: env -i "${FW_SPAWN_ENV[@]}" <command>
fw_spawn_env() {
    local _k
    FW_SPAWN_ENV=("PATH=$(fw_spawn_path)")
    while IFS= read -r _k; do
        [[ "$_k" =~ $FW_SPAWN_ENV_ALLOW ]] && FW_SPAWN_ENV+=("$_k=${!_k}")
    done < <(compgen -e)
    return 0
}
