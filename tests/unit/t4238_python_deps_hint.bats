#!/usr/bin/env bats
# T-4238: install.sh and fw doctor check PyYAML (hard) and the Watchtower Python
# stack (soft), and the install hint works under PEP 668 — apt package names on
# Debian-likes, a venv elsewhere, never a bare system `pip install`.
#
# Missing modules are simulated with a python3 shim on PATH that fails exactly
# `python3 -c "import <mod>"` for the modules in FAKE_MISSING and hands every
# other call to the real interpreter.

setup() {
    FW_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TMP="$(mktemp -d)"
    REAL_PY="$(command -v python3)"
    mkdir -p "$TMP/bin"
    cat > "$TMP/bin/python3" <<EOF
#!/bin/bash
if [ "\$1" = "-c" ] && [ "\$#" -eq 2 ]; then
    for m in \$FAKE_MISSING; do
        [ "\$2" = "import \$m" ] && exit 1
    done
fi
exec "$REAL_PY" "\$@"
EOF
    chmod +x "$TMP/bin/python3"
    printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/apt-get"
    chmod +x "$TMP/bin/apt-get"
    printf 'ID=linuxmint\nID_LIKE="ubuntu debian"\n' > "$TMP/os-release-mint"
    printf 'ID=fedora\n' > "$TMP/os-release-fedora"
    export PATH="$TMP/bin:$PATH"
}

teardown() {
    rm -rf "$TMP"
}

@test "helper: Debian-like host gets apt package names" {
    run env FW_OS_RELEASE="$TMP/os-release-mint" bash -c "source '$FW_ROOT/lib/python-deps.sh'; fw_pydeps_install_hint \"\${FW_WATCHTOWER_MODULES[@]}\""
    [ "$status" -eq 0 ]
    [ "$output" = "sudo apt-get install -y python3-flask python3-flask-socketio python3-yaml python3-markdown2" ]
}

@test "helper: non-Debian host gets a venv, never a system pip install" {
    run env FW_OS_RELEASE="$TMP/os-release-fedora" bash -c "source '$FW_ROOT/lib/python-deps.sh'; fw_pydeps_install_hint \"\$FW_PYYAML_MODULE\""
    [ "$status" -eq 0 ]
    [[ "$output" == "python3 -m venv ~/.venvs/aef-watchtower && ~/.venvs/aef-watchtower/bin/pip install pyyaml"* ]]
}

@test "helper: missing lists only the modules python3 cannot import" {
    run env FAKE_MISSING="flask markdown2" bash -c "source '$FW_ROOT/lib/python-deps.sh'; fw_pydeps_names \$(fw_pydeps_missing \"\${FW_WATCHTOWER_MODULES[@]}\")"
    [ "$status" -eq 0 ]
    [ "$output" = "flask, markdown2" ]
}

@test "preflight: PyYAML hint is not pip3 install on a PEP 668 host" {
    run env FAKE_MISSING="yaml" FW_OS_RELEASE="$TMP/os-release-mint" bash -c "source '$FW_ROOT/lib/preflight.sh' --check-only; check_pyyaml >/dev/null; printf '%s\n' \"\${REQUIRED_INSTALL_CMDS[@]}\""
    [ "$status" -eq 0 ]
    [ "$output" = "sudo apt-get install -y python3-yaml" ]
}

@test "install.sh: missing PyYAML is a prerequisite failure with an apt hint" {
    # install.sh runs the installer when sourced; extract the functions instead.
    awk '/^PYYAML_MODULE=/,/^check_prereqs\(\)/' "$FW_ROOT/install.sh" | sed '$d' > "$TMP/pydeps.sh"
    grep -q '^check_python_modules()' "$TMP/pydeps.sh"
    run env FAKE_MISSING="yaml" FW_OS_RELEASE="$TMP/os-release-mint" bash -c "info(){ echo \"INFO \$*\"; }; warn(){ echo \"WARN \$*\"; }; error(){ echo \"ERROR \$*\"; }; source '$TMP/pydeps.sh'; check_python_modules"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR PyYAML not installed"*"sudo apt-get install -y python3-yaml"* ]]
}

@test "install.sh: missing Watchtower stack only warns" {
    awk '/^PYYAML_MODULE=/,/^check_prereqs\(\)/' "$FW_ROOT/install.sh" | sed '$d' > "$TMP/pydeps.sh"
    run env FAKE_MISSING="flask_socketio" FW_OS_RELEASE="$TMP/os-release-fedora" bash -c "info(){ echo \"INFO \$*\"; }; warn(){ echo \"WARN \$*\"; }; error(){ echo \"ERROR \$*\"; }; source '$TMP/pydeps.sh'; check_python_modules"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO PyYAML installed"* ]]
    [[ "$output" == *"WARN Watchtower Python stack incomplete (missing: flask_socketio)"*"bin/pip install flask-socketio"* ]]
}

@test "install.sh calls the module check from check_prereqs" {
    awk '/^check_prereqs\(\)/,/^}/' "$FW_ROOT/install.sh" | grep -q 'check_python_modules || ok=false'
}

@test "module lists are identical in install.sh, lib/python-deps.sh and bin/watchtower.sh" {
    a=$(awk '/^FW_WATCHTOWER_MODULES=\(/,/^\)/' "$FW_ROOT/lib/python-deps.sh" | grep '"')
    b=$(awk '/^WATCHTOWER_MODULES=\(/,/^\)/' "$FW_ROOT/install.sh" | grep '"')
    c=$(awk '/^WATCHTOWER_REQUIRED_MODULES=\(/,/^\)/' "$FW_ROOT/bin/watchtower.sh" | grep '"')
    [ -n "$a" ]
    [ "$a" = "$b" ]
    [ "$a" = "$c" ]
}

@test "fw doctor: missing PyYAML FAILs and missing Flask WARNs, both with a PEP 668-safe hint" {
    run env FAKE_MISSING="yaml flask" FW_OS_RELEASE="$TMP/os-release-mint" timeout 600 "$FW_ROOT/bin/fw" doctor --quick
    [[ "$output" == *"FAIL"*"PyYAML not installed"* ]]
    [[ "$output" == *"Install: sudo apt-get install -y python3-yaml"* ]]
    [[ "$output" == *"Watchtower Python stack incomplete — missing: flask, yaml"* ]]
    [[ "$output" != *"pip install -r"* ]]
}

@test "fw doctor: healthy interpreter reports both OK" {
    run timeout 600 "$FW_ROOT/bin/fw" doctor --quick
    [[ "$output" == *"OK"*"PyYAML installed"* ]]
}

@test "bin/fw no longer hints pip install -r web/requirements.txt" {
    ! grep -n 'pip install -r \$FRAMEWORK_ROOT/web/requirements.txt' "$FW_ROOT/bin/fw" || false
    ! grep -n '"pip3 install pyyaml"' "$FW_ROOT/lib/preflight.sh" || false
}
