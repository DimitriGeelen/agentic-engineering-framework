#!/usr/bin/env bats
# T-3765: fw task review-batch's Watchtower reachability probe must be the cheap
# identity endpoint (/api/_identity), never the dashboard root (/).
#
# The dashboard's / re-reads the whole task corpus on a cache miss; a probe there
# can time out on a busy server and print "No Watchtower reachable" for a live one.
# The probe is run against a curl spy (no network); the spy records every URL asked for.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export FRAMEWORK_ROOT
    export PROJECT_ROOT="$TEST_TEMP_DIR"
    export NO_COLOR=1
    unset WATCHTOWER_URL
    source "$FRAMEWORK_ROOT/lib/colors.sh"
    source "$FRAMEWORK_ROOT/lib/paths.sh"
    source "$FRAMEWORK_ROOT/lib/review.sh"

    mkdir -p "$TEST_TEMP_DIR/.tasks/active" "$TEST_TEMP_DIR/.tasks/completed" "$TEST_TEMP_DIR/.context/working"
    cat > "$TEST_TEMP_DIR/.tasks/active/T-9001-probe.md" <<'EOF'
---
id: T-9001
name: "Probe fixture"
status: started-work
workflow_type: build
owner: agent
---

# T-9001
EOF

    # curl spy: log each URL, answer "not reachable" so the probe walks every candidate.
    mkdir -p "$TEST_TEMP_DIR/spy"
    cat > "$TEST_TEMP_DIR/spy/curl" <<EOF
#!/bin/bash
for a in "\$@"; do case "\$a" in http*) echo "\$a" >> "$TEST_TEMP_DIR/curl.log" ;; esac; done
exit 7
EOF
    chmod +x "$TEST_TEMP_DIR/spy/curl"
    export PATH="$TEST_TEMP_DIR/spy:$PATH"
}

teardown() {
    [ -d "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "review-batch probes only /api/_identity, never the dashboard root" {
    run emit_review_batch T-9001
    [ "$status" -eq 0 ]
    [ -s "$TEST_TEMP_DIR/curl.log" ]
    # every probe is the identity endpoint
    run bash -c "grep -v '/api/_identity\$' '$TEST_TEMP_DIR/curl.log'"
    [ "$status" -ne 0 ]
    # and none of them is a bare root URL
    run bash -c "grep -E 'https?://[^/]+(:[0-9]+)?/?\$' '$TEST_TEMP_DIR/curl.log'"
    [ "$status" -ne 0 ]
}
