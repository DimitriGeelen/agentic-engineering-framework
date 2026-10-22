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

FW_SPAWN_ENV_ALLOW='^(PATH|HOME|USER|LOGNAME|SHELL|LANG|LANGUAGE|LC_[A-Z_]+|TERM|COLORTERM|TZ|TMPDIR|TMUX|TMUX_PANE|TMUX_TMPDIR|TERMLINK_RUNTIME_DIR|TERMLINK_RUNTIME_DIR_FALLBACK|TERMLINK_BIN|XDG_[A-Z_]+|DBUS_SESSION_BUS_ADDRESS|SSH_AUTH_SOCK|ANTHROPIC_[A-Z0-9_]+|CLAUDE_CONFIG_DIR|CLAUDE_CODE_OAUTH_TOKEN|http_proxy|https_proxy|no_proxy|HTTP_PROXY|HTTPS_PROXY|NO_PROXY|SSL_CERT_FILE|SSL_CERT_DIR|NODE_EXTRA_CA_CERTS)$'

# fw_spawn_env — set the array FW_SPAWN_ENV to NAME=VALUE pairs of the exported variables that
# match FW_SPAWN_ENV_ALLOW. Use: env -i "${FW_SPAWN_ENV[@]}" <command>
fw_spawn_env() {
    local _k
    FW_SPAWN_ENV=()
    while IFS= read -r _k; do
        [[ "$_k" =~ $FW_SPAWN_ENV_ALLOW ]] && FW_SPAWN_ENV+=("$_k=${!_k}")
    done < <(compgen -e)
    return 0
}
