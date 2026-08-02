#!/usr/bin/env bats
# T-2728 — detect_toothless_http: a curl verification line that discards output and
# carries no failure mechanism cannot fail, so it asserts nothing.
#
# Origin OBS-127: two shipped lines read
#   curl -s -o /dev/null -w "%{http_code}\n" http://192.168.10.107:3000/api/...
# `-w` only PRINTS the code; curl exits 0 on any successful connection, so 403/404/
# 500 all read PASS. Both also carried a literal :3000 and reached a DIFFERENT
# project's Watchtower — green about the wrong server AND green regardless of
# the answer.
#
# Measured, not assumed: over all 2715 task files the narrowed detector returns
# exactly ONE finding — T-2063, the line deliberately left toothless with its
# reason recorded, because that task is ABOUT a CSRF 403 and the expected status
# is the author's knowledge.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
}

# _detect <line> — pattern ids the detector returns for one verification line.
_detect() {
    FRAMEWORK_ROOT="$FRAMEWORK_ROOT" LINE="$1" python3 -c '
import sys, os
sys.path.insert(0, os.path.join(os.environ["FRAMEWORK_ROOT"], "lib"))
from reviewer.static_scan import detect_toothless_http as d
print(" ".join(f.pattern_id for f in d(os.environ["LINE"])) or "clean")
'
}

@test "T-2728: the historical OBS-127 line is flagged" {
    run _detect 'curl -s -o /dev/null -w "%{http_code}\n" http://192.168.10.107:3000/review/T-2056'
    [ "$status" -eq 0 ]
    [ "$output" = "toothless-http-assertion" ]
}

@test "T-2728: the POST variant is flagged too" {
    run _detect 'curl -s -X POST -o /dev/null -w "%{http_code}\n" http://h:3000/api/task/T-1/complete'
    [ "$output" = "toothless-http-assertion" ]
}

@test "T-2728 control: -f gives the line teeth, so it is not flagged" {
    run _detect 'curl -sf -o /dev/null "$(bin/fw watchtower url)/review/T-1"'
    [ "$output" = "clean" ]
}

@test "T-2728 control: a captured-and-compared status is not flagged" {
    run _detect 'out=$(curl -s -o /dev/null -w "%{http_code}" "$WURL/x"); test "$out" = "200"'
    [ "$output" = "clean" ]
}

@test "T-2728 control: a redirect carries the value to a later line, not flagged" {
    # This line-oriented scan cannot see the later comparison, so it must not
    # guess. Suppressing here is deliberate under-reach, not a miss.
    run _detect 'curl -s -o /dev/null -w "%{time_total}" "$WURL/timeline" > /tmp/.t.out'
    [ "$output" = "clean" ]
}

@test "T-2728 control: piping the status into a grep is not flagged" {
    run _detect 'curl -s -o /dev/null -w "%{http_code}" "$WURL/" | grep -q 200'
    [ "$output" = "clean" ]
}

@test "T-2728 control: a comment is not flagged" {
    run _detect '# curl -s -o /dev/null -w "%{http_code}" http://h:3000/x'
    [ "$output" = "clean" ]
}

@test "T-2728 control: a non-curl line is not flagged" {
    run _detect 'grep -q "foo" bar.txt'
    [ "$output" = "clean" ]
}

@test "T-2728: the pattern is registered in the anti-pattern catalogue" {
    # An unregistered pattern_id means the finding renders without a name or
    # severity — the detector would fire into a surface that cannot describe it.
    run python3 -c "
import yaml
c = yaml.safe_load(open('$FRAMEWORK_ROOT/policy/anti-patterns.yaml'))
ids = [p['id'] for p in c['patterns']] if isinstance(c, dict) and 'patterns' in c else \
      [p['id'] for p in c]
assert 'toothless-http-assertion' in ids, ids[:5]
print('registered')
"
    [ "$status" -eq 0 ]
    [[ "$output" == *"registered"* ]]
}
