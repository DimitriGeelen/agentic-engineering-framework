#!/usr/bin/env bats
# T-2477: BVP frontmatter round-trip has a ruamel-preferred path with a PyYAML
# safe_load->safe_dump FALLBACK. PyYAML's SafeLoader has an implicit
# `tag:yaml.org,2002:timestamp` resolver that parses an unquoted ISO
# `2026-06-02T00:00:00Z` to a datetime on load and re-emits it as
# `2026-06-02 00:00:00+00:00` on dump — different text that churns task
# frontmatter and breaks `...Z`-expecting readers. The corruption is masked
# wherever ruamel is installed, so it only surfaces on hosts without ruamel
# (OBS-085 / L-495 — the same class fixed in lib/integrate.py:_str_loader).
#
# Fix: a resolver-stripped SafeLoader (`_str_safe_load`) on the fallback path in
# BOTH lib/bvp.sh (PYEOF block) and agents/termlink/bvp-estimator/estimator.py
# (4 frontmatter sites). These tests force ruamel ABSENT (a fake `ruamel`
# package that raises ImportError on import) and assert ISO-Z survives.

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d -t fw-t2477-XXXXXX)"
    export TEST_TEMP_DIR
    # Fake ruamel package: importing it raises ImportError, flipping the
    # _HAS_RUAMEL guard to False so the PyYAML fallback path is exercised.
    mkdir -p "$TEST_TEMP_DIR/fakemod/ruamel"
    echo 'raise ImportError("ruamel hidden for T-2477 fallback test")' \
        > "$TEST_TEMP_DIR/fakemod/ruamel/__init__.py"
    FAKEMOD="$TEST_TEMP_DIR/fakemod"
    EST="$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/estimator.py"
}

teardown() {
    [ -n "${TEST_TEMP_DIR:-}" ] && rm -rf "$TEST_TEMP_DIR"
}

@test "t2477:t1 estimator _str_safe_load keeps unquoted ISO-Z as a string (ruamel absent)" {
    PYTHONPATH="$FAKEMOD" run python3 - "$EST" <<'PY'
import importlib.util, os, sys
# guard: ruamel must be hidden for this test to be meaningful
try:
    import ruamel.yaml  # noqa
    print("RUAMEL-VISIBLE"); sys.exit(3)
except ImportError:
    pass
spec = importlib.util.spec_from_file_location("estimator", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
assert m._HAS_RUAMEL is False, "guard: _HAS_RUAMEL should be False"
fm = m._str_safe_load("created: 2026-06-02T00:00:00Z\nfoo: bar\n")
v = fm["created"]
assert isinstance(v, str), f"corrupted to {type(v).__name__}: {v!r}"
assert v == "2026-06-02T00:00:00Z", f"Z text changed: {v!r}"
print("OK")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "t2477:t2 control — plain PyYAML safe_load WOULD corrupt ISO-Z (proves the test detects the bug)" {
    run python3 - <<'PY'
import yaml
v = yaml.safe_load("created: 2026-06-02T00:00:00Z\n")["created"]
# plain safe_load parses to datetime → str(v) is the reformatted form
print(type(v).__name__, str(v))
PY
    [ "$status" -eq 0 ]
    # The bug we are fixing: plain safe_load yields a datetime, NOT a str.
    [[ "$output" == datetime* ]]
    [[ "$output" == *"2026-06-02 00:00:00+00:00"* ]]
}

@test "t2477:t3 fw bvp confirm preserves ISO-Z in rewritten frontmatter (ruamel absent, end-to-end)" {
    local proj="$TEST_TEMP_DIR/proj"
    mkdir -p "$proj/.tasks/active"
    cat > "$proj/.tasks/active/T-9999-fixture.md" <<'EOF'
---
id: T-9999
name: "fixture"
status: started-work
created: 2026-06-02T00:00:00Z
last_update: 2026-06-02T00:00:00Z
---

# T-9999 fixture
EOF
    PROJECT_ROOT="$proj" PYTHONPATH="$FAKEMOD" run "$FRAMEWORK_ROOT/bin/fw" \
        bvp confirm T-9999 --override D1=3 --i-am-human
    [ "$status" -eq 0 ]
    # Z text must survive (quoting is fine; reformat to a space-separated
    # datetime is the corruption we are preventing).
    run grep -E '^created:' "$proj/.tasks/active/T-9999-fixture.md"
    [[ "$output" == *"2026-06-02T00:00:00Z"* ]]
    [[ "$output" != *"2026-06-02 00:00:00+00:00"* ]]
}
