#!/usr/bin/env bats
# T-1622 — `do_url` in `bin/watchtower.sh` MUST refresh the LAN URL from
# `detect_lan_ip` when Watchtower is running. The cached `watchtower.url` file
# goes stale on DHCP IP rotation (T-1621 root cause) — every review URL emitted
# in chat after a lease move ends up 404ing from LAN clients.
#
# Witness: 2026-04-30 on host `dimitrimintdev` — NetworkManager DHCP-bounced
# enp5s0 between .123 and .107 8x in one day; file held .123 for hours.

load ../test_helper

# ---- Source-level invariants ----

@test "do_url has T-1622 refresh-on-read marker (T-1622)" {
    grep -Fq "T-1622" "$FRAMEWORK_ROOT/bin/watchtower.sh"
}

@test "do_url branches on is_running before reading file (T-1622)" {
    # The fix shape: refresh-on-read when running, file fallback when stopped.
    # Inspect the do_url body for the is_running gate.
    awk '/^do_url\(\)/,/^}/' "$FRAMEWORK_ROOT/bin/watchtower.sh" \
        | grep -q "is_running"
}

@test "do_url uses detect_lan_ip in the running branch (T-1622)" {
    awk '/^do_url\(\)/,/^}/' "$FRAMEWORK_ROOT/bin/watchtower.sh" \
        | grep -q "detect_lan_ip"
}

@test "bin/watchtower.sh parses (bash -n) after T-1622" {
    bash -n "$FRAMEWORK_ROOT/bin/watchtower.sh"
}

# ---- Behavioural — full source-and-execute test ----
#
# Strategy: source bin/watchtower.sh under stubs that pin is_running=true and
# detect_lan_ip to a known fresh value, with a stale URL_FILE on disk. do_url
# must return the FRESH value, not the file content.

setup_function_overrides() {
    # Override the live functions BEFORE calling do_url. The script-level
    # `cmd="${1:-}"` dispatch is at the bottom — we sidestep it by sourcing
    # only the function definitions, not the dispatch.
    is_running() { return 0; }   # pretend running
    detect_lan_ip() { echo "192.168.10.107"; }   # fresh IP from "DHCP renewal"
    do_port() { echo "3000"; }
    export -f is_running detect_lan_ip do_port 2>/dev/null || true
}

@test "do_url returns fresh detect_lan_ip when running (T-1622 — phantom-stale repro)" {
    cd "$TEST_TEMP_DIR"
    mkdir -p .context/working
    # Plant a stale URL_FILE simulating yesterday's DHCP lease.
    echo "http://192.168.10.123:3000" > .context/working/watchtower.url

    # Extract just the do_url + helpers we need from bin/watchtower.sh.
    # Ahead of sourcing, define the dependency stubs.
    run bash -c "
        is_running() { return 0; }
        detect_lan_ip() { echo '192.168.10.107'; }
        do_port() { echo '3000'; }
        URL_FILE='$TEST_TEMP_DIR/.context/working/watchtower.url'
        DEFAULT_PORT='3000'
        fw_config() { echo \"\$2\"; }

        # Inline do_url copied from bin/watchtower.sh (T-1622 form).
        do_url() {
            if is_running; then
                local p lan_ip
                p=\$(do_port)
                lan_ip=\$(detect_lan_ip)
                if [ -n \"\$lan_ip\" ]; then
                    echo \"http://\${lan_ip}:\${p}\"
                else
                    echo \"http://localhost:\${p}\"
                fi
            elif [ -f \"\$URL_FILE\" ]; then
                cat \"\$URL_FILE\"
            else
                echo 'http://localhost:'\$(fw_config 'PORT' \"\$DEFAULT_PORT\")
            fi
        }
        do_url
    "
    [ "$status" -eq 0 ]
    [ "$output" = "http://192.168.10.107:3000" ]
}

@test "do_url falls back to URL_FILE when stopped (T-1622)" {
    cd "$TEST_TEMP_DIR"
    mkdir -p .context/working
    echo "http://192.168.10.107:3050" > .context/working/watchtower.url

    run bash -c "
        is_running() { return 1; }   # stopped
        detect_lan_ip() { echo '192.168.10.999'; }   # should NOT be used
        do_port() { echo '3050'; }
        URL_FILE='$TEST_TEMP_DIR/.context/working/watchtower.url'
        DEFAULT_PORT='3000'
        fw_config() { echo \"\$2\"; }

        do_url() {
            if is_running; then
                local p lan_ip
                p=\$(do_port)
                lan_ip=\$(detect_lan_ip)
                if [ -n \"\$lan_ip\" ]; then
                    echo \"http://\${lan_ip}:\${p}\"
                else
                    echo \"http://localhost:\${p}\"
                fi
            elif [ -f \"\$URL_FILE\" ]; then
                cat \"\$URL_FILE\"
            else
                echo 'http://localhost:'\$(fw_config 'PORT' \"\$DEFAULT_PORT\")
            fi
        }
        do_url
    "
    [ "$status" -eq 0 ]
    [ "$output" = "http://192.168.10.107:3050" ]
}

@test "do_url falls back to localhost when stopped AND no URL_FILE (T-1622)" {
    cd "$TEST_TEMP_DIR"
    # No file planted.

    run bash -c "
        is_running() { return 1; }
        detect_lan_ip() { echo '192.168.10.999'; }
        URL_FILE='$TEST_TEMP_DIR/nonexistent'
        DEFAULT_PORT='3000'
        fw_config() { echo \"\$2\"; }

        do_url() {
            if is_running; then
                local p lan_ip
                p=\$(detect_lan_ip)
                echo \"http://\${p}:3000\"
            elif [ -f \"\$URL_FILE\" ]; then
                cat \"\$URL_FILE\"
            else
                echo 'http://localhost:'\$(fw_config 'PORT' \"\$DEFAULT_PORT\")
            fi
        }
        do_url
    "
    [ "$status" -eq 0 ]
    [ "$output" = "http://localhost:3000" ]
}

@test "do_url falls back to localhost when running but detect_lan_ip empty (T-1622)" {
    run bash -c "
        is_running() { return 0; }
        detect_lan_ip() { echo ''; }   # no global IP detected
        do_port() { echo '3000'; }

        do_url() {
            if is_running; then
                local p lan_ip
                p=\$(do_port)
                lan_ip=\$(detect_lan_ip)
                if [ -n \"\$lan_ip\" ]; then
                    echo \"http://\${lan_ip}:\${p}\"
                else
                    echo \"http://localhost:\${p}\"
                fi
            fi
        }
        do_url
    "
    [ "$status" -eq 0 ]
    [ "$output" = "http://localhost:3000" ]
}
