#!/bin/bash
# T-4238: Python dependency checks shared by `fw doctor`, `fw preflight` and bin/fw.
#
# The install hint never says a bare `pip install`: PEP 668 interpreters
# (Debian 12, Ubuntu 24.04, Mint 22, Homebrew) refuse it with
# "externally-managed-environment". On Debian-likes the hint names the apt
# packages; elsewhere it is a venv (same path bin/watchtower.sh, T-4304, names).
#
# install.sh runs before the framework is fetched, so it cannot source this
# file and carries its own copy of the module lists. The copies are pinned
# equal by tests/unit/t4238_python_deps_hint.bats.

# Format: import-name|pip-name|apt-name
FW_PYYAML_MODULE="yaml|pyyaml|python3-yaml"
# The modules Watchtower imports at load — same list as bin/watchtower.sh
# WATCHTOWER_REQUIRED_MODULES (T-4304).
FW_WATCHTOWER_MODULES=(
    "flask|flask|python3-flask"
    "flask_socketio|flask-socketio|python3-flask-socketio"
    "yaml|pyyaml|python3-yaml"
    "markdown2|markdown2|python3-markdown2"
)

# fw_pydeps_missing ENTRY... — print each entry whose module python3 cannot import.
fw_pydeps_missing() {
    local entry
    for entry in "$@"; do
        python3 -c "import ${entry%%|*}" 2>/dev/null || echo "$entry"
    done
}

# fw_pydeps_names ENTRY... — the import names, comma-separated.
fw_pydeps_names() {
    local entry out=""
    for entry in "$@"; do
        out="${out:+$out, }${entry%%|*}"
    done
    echo "$out"
}

# fw_pydeps_hint_line ENTRY... — the hint as printed to a person.
fw_pydeps_hint_line() {
    local cmd
    cmd=$(fw_pydeps_install_hint "$@")
    case "$cmd" in
        *activate) echo "$cmd  (then re-run fw in that shell)" ;;
        *) echo "$cmd" ;;
    esac
}

# fw_pydeps_install_hint ENTRY... — the install command for this machine.
# Prints it; never runs sudo or pip. FW_OS_RELEASE overrides /etc/os-release (tests).
fw_pydeps_install_hint() {
    local entry mod pip_name apt_name pips="" apts=""
    for entry in "$@"; do
        IFS='|' read -r mod pip_name apt_name <<< "$entry"
        pips="${pips:+$pips }$pip_name"
        apts="${apts:+$apts }$apt_name"
    done
    if command -v apt-get >/dev/null 2>&1 && grep -qiE '^ID(_LIKE)?=.*(debian|ubuntu)' "${FW_OS_RELEASE:-/etc/os-release}" 2>/dev/null; then
        echo "sudo apt-get install -y $apts"
    else
        # A plain command (lib/preflight.sh may eval it, with consent); callers
        # that print it add "then re-run fw in that shell".
        echo "python3 -m venv ~/.venvs/aef-watchtower && ~/.venvs/aef-watchtower/bin/pip install $pips && . ~/.venvs/aef-watchtower/bin/activate"
    fi
}
