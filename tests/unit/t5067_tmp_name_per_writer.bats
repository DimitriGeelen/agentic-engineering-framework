#!/usr/bin/env bats
# T-5067 — why `$$` is not enough, measured rather than asserted: two background
# subshells of one script share `$$` (the parent's pid) but get different
# `${BASHPID:-$$}`. The lint test (tests/lint/t5067-no-pid-only-tmp-names.bats)
# keeps pid-only names out of the tree; this pins the premise it rests on.

@test "T-5067: concurrent subshells share \$\$ but not \${BASHPID:-\$\$}" {
    run bash -c '
        a=$( (echo "$$ ${BASHPID:-$$}") & wait )
        { sleep 0.1; echo "$$ ${BASHPID:-$$}" > "$1"; } &
        { sleep 0.1; echo "$$ ${BASHPID:-$$}" > "$2"; } &
        wait
        read -r p1 b1 < "$1"; read -r p2 b2 < "$2"
        [ "$p1" = "$p2" ] || { echo "dollar-dollar differed"; exit 1; }
        [ "$b1" != "$b2" ] || { echo "BASHPID equal"; exit 1; }
        echo ok
    ' _ "$BATS_TEST_TMPDIR/one" "$BATS_TEST_TMPDIR/two"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "T-5067: a Python temp name built by the fixed pattern differs between threads" {
    run python3 -I -c '
import os, threading
names = []
def make():
    names.append(f".json.{os.getpid()}-{os.urandom(4).hex()}.tmp")
ts = [threading.Thread(target=make) for _ in range(8)]
[t.start() for t in ts]; [t.join() for t in ts]
print(len(set(names)))
'
    [ "$status" -eq 0 ]
    [ "$output" = "8" ]
}
