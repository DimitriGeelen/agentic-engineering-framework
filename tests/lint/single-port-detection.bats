#!/usr/bin/env bats
# T-1155: Invariant test — no inline Watchtower port detection
# All port detection must go through lib/watchtower.sh:_watchtower_url()
# This prevents the recurring bug where consumer Watchtower on ports != 3000
# returns 404 because the framework defaults to 3000.

@test "lib/review.sh sources watchtower.sh, not config.sh for port" {
    run grep 'source.*watchtower\.sh' lib/review.sh
    [ "$status" -eq 0 ]

    # Must NOT have inline port detection
    run grep 'fw_config.*PORT.*3000' lib/review.sh
    [ "$status" -ne 0 ]
}

@test "lib/review.sh uses _watchtower_url, not inline detection" {
    run grep '_watchtower_url' lib/review.sh
    [ "$status" -eq 0 ]

    # Must NOT have watchtower.pid inline detection
    run grep 'watchtower\.pid' lib/review.sh
    [ "$status" -ne 0 ]
}

@test "lib/verify-acs.sh uses _watchtower_url" {
    run grep '_watchtower_url' lib/verify-acs.sh
    [ "$status" -eq 0 ]

    # Must NOT have inline fw_config PORT fallback
    run grep 'fw_config.*PORT.*3000' lib/verify-acs.sh
    [ "$status" -ne 0 ]
}

@test "lib/watchtower.sh exists with _watchtower_url function" {
    [ -f lib/watchtower.sh ]
    run grep '_watchtower_url()' lib/watchtower.sh
    [ "$status" -eq 0 ]
}

@test "no inline fw_config PORT 3000 in review or verify-acs" {
    violations=$(grep -rn 'fw_config.*"PORT".*3000' lib/review.sh lib/verify-acs.sh 2>/dev/null || true)
    if [ -n "$violations" ]; then
        echo "Found inline port detection (should use _watchtower_url from lib/watchtower.sh):"
        echo "$violations"
        return 1
    fi
}
