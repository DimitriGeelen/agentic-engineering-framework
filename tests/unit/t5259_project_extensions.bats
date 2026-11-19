#!/usr/bin/env bats
#
# T-5259 (T-4649 slice 0) — project extensions register.
#
# Every modification of the framework in a project is the project operator's
# recorded decision (.framework-extensions.yaml at the project root), listed by
# fw audit and kept by fw vendor / fw upgrade. vendored-override entries are
# mirrored into .fwvendor-preserve.yaml so the existing T-3850/T-4870 protection
# keeps them. FIXTURES ONLY: every test runs in a temporary project root.

setup() {
    FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    TMP="$(mktemp -d)"
    PROJ="$TMP/proj"
    AF="$PROJ/.agentic-framework"
    EXT="$FRAMEWORK_ROOT/lib/extensions.py"
    mkdir -p "$PROJ/.context/working" "$PROJ/.tasks/active"
    git -C "$PROJ" init -q
}

teardown() { rm -rf "$TMP"; }

# Operator form: no CLAUDECODE in the environment.
_ext() { env -u CLAUDECODE python3 "$EXT" --project "$PROJ" "$@"; }
_fw() { ( cd "$PROJ" && env -u CLAUDECODE FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" "$FRAMEWORK_ROOT/bin/fw" "$@" 2>&1 ); }
_audit() {
    PROJECT_ROOT="$PROJ" timeout 300 "$FRAMEWORK_ROOT/agents/audit/audit.sh" --section enforcement 2>&1 || true
}

# ------------------------------------------------------------ add / list / remove

@test "fw extension add/list/remove: register written with id, kind, paths, words, decided_by, date" {
    mkdir -p "$PROJ/web"
    run _fw extension add page approvals --path web/approvals.py --words "we own the approvals page"
    [ "$status" -eq 0 ]
    [ -f "$PROJ/.framework-extensions.yaml" ]
    python3 - "$PROJ/.framework-extensions.yaml" <<'PY'
import sys, yaml
e = yaml.safe_load(open(sys.argv[1]))["extensions"][0]
assert e["id"] == "approvals" and e["kind"] == "page", e
assert e["paths"] == ["web/approvals.py"] and e["words"] == "we own the approvals page", e
assert e["decided_by"] == "operator" and len(str(e["date"])) == 10, e
PY
    run _fw extension list
    [ "$status" -eq 0 ]
    [[ "$output" == *"approvals  [page]  web/approvals.py"* ]]
    [[ "$output" == *'"we own the approvals page"'* ]]
    run _fw extension list --json
    [ "$(printf '%s' "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')" = approvals ]
    run _fw extension remove approvals --words "not needed any more"
    [ "$status" -eq 0 ]
    run _fw extension list
    [[ "$output" == *"No project extensions registered"* ]]
    # Both decisions are in the history, in the operator's words.
    grep -q '"action": "add".*we own the approvals page' "$PROJ/.context/project/extension-decisions.jsonl"
    grep -q '"action": "remove".*not needed any more' "$PROJ/.context/project/extension-decisions.jsonl"
}

@test "validation: unknown kind, bad id, duplicate id, markers on a non-override kind are refused" {
    run _ext add nonsense x --path a --words w
    [ "$status" -ne 0 ]
    run _ext add page "Bad Id" --path a --words w
    [ "$status" -eq 2 ]
    [[ "$output" == *"id"* ]]
    run _ext add page ok --path a --words w
    [ "$status" -eq 0 ]
    run _ext add page ok --path b --words w
    [ "$status" -eq 2 ]
    [[ "$output" == *"already registered"* ]]
    run _ext add page m --path a --marker x --words w
    [ "$status" -eq 2 ]
    [[ "$output" == *"vendored-override only"* ]]
    run _ext add page abs --path /etc/passwd --words w
    [ "$status" -eq 2 ]
    # Every later-slice kind is accepted.
    for k in nav csrf-exemption event-hook reviewer-brief gate-check; do
        run _ext add "$k" "k-$k" --path p --words w
        [ "$status" -eq 0 ]
    done
}

# ------------------------------------------------------------ operator-only

@test "agent control: add and remove are refused under CLAUDECODE=1; list is open" {
    run env CLAUDECODE=1 python3 "$EXT" --project "$PROJ" add page p --path a --words w
    [ "$status" -eq 1 ]
    [[ "$output" == *"operator's decision"* ]]
    [[ "$output" == *"--i-am-human"* ]]
    [ ! -f "$PROJ/.framework-extensions.yaml" ]
    _ext add page p --path a --words w
    run env CLAUDECODE=1 python3 "$EXT" --project "$PROJ" remove p --words w
    [ "$status" -eq 1 ]
    grep -q 'id: "p"' "$PROJ/.framework-extensions.yaml"
    run env CLAUDECODE=1 python3 "$EXT" --project "$PROJ" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"p  [page]"* ]]
}

@test "agent control: --i-am-human is honoured, logged, and recorded on the entry" {
    run env CLAUDECODE=1 python3 "$EXT" --project "$PROJ" add page p --path a --words w --i-am-human
    [ "$status" -eq 0 ]
    grep -q "flag: '--i-am-human'" "$PROJ/.context/working/.gate-bypass-log.yaml"
    grep -q "caller: 'fw extension add'" "$PROJ/.context/working/.gate-bypass-log.yaml"
    grep -q 'decided_by: "operator (--i-am-human in an agent session)"' "$PROJ/.framework-extensions.yaml"
    run env CLAUDECODE=1 python3 "$EXT" --project "$PROJ" remove p --words w --i-am-human
    [ "$status" -eq 0 ]
    grep -q "caller: 'fw extension remove'" "$PROJ/.context/working/.gate-bypass-log.yaml"
}

# ------------------------------------------------------------ preserve mirror

@test "mirror: vendored-override goes into files:/in_file:, hand-written items untouched, remove takes only its own" {
    cat > "$PROJ/.fwvendor-preserve.yaml" <<'YAML'
# hand-written
files:
  - web/hand.py   # mine
in_file:
  - file: lib/notify.sh
    marker: "local: ntfy"
on_missing: warn
YAML
    cp "$PROJ/.fwvendor-preserve.yaml" "$TMP/orig.yaml"
    _ext add vendored-override ui --path .agentic-framework/web/app.py --words "keep"
    _ext add vendored-override blk --path web/core.py --marker 're:register\(x\)' --marker plain --words "block"
    python3 - "$FRAMEWORK_ROOT/lib" "$PROJ" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import vendor_preserve as v
m = v.load_manifest(sys.argv[2])
assert m["files"] == ["web/hand.py", "web/app.py"], m
assert m["in_file"] == {"lib/notify.sh": ["local: ntfy"], "web/core.py": ["re:register\\(x\\)", "plain"]}, m
assert m["on_missing"] == "warn", m
PY
    grep -q '# mine' "$PROJ/.fwvendor-preserve.yaml"
    _ext remove ui --words bye
    _ext remove blk --words bye
    diff <(grep -v '^\s*$' "$TMP/orig.yaml") <(grep -v '^\s*$' "$PROJ/.fwvendor-preserve.yaml")
}

@test "mirror: creates the preserve manifest when absent; non-override kinds are not mirrored" {
    _ext add page pg --path web/x.py --words w
    [ ! -f "$PROJ/.fwvendor-preserve.yaml" ]
    _ext add vendored-override o --path lib/a.sh --words w
    grep -q 'extension: "o"' "$PROJ/.fwvendor-preserve.yaml"
    _ext remove o --words w
    ! grep -q 'extension: "' "$PROJ/.fwvendor-preserve.yaml"
}

@test "mirror: fallback reader (no PyYAML) parses mirrored items the same way" {
    _ext add vendored-override o --path lib/a.sh --words w
    _ext add vendored-override b --path web/app.py --marker "ring20-local: x" --words w
    python3 - "$FRAMEWORK_ROOT/lib" "$PROJ/.fwvendor-preserve.yaml" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import vendor_preserve as v
d = v._mini_yaml(open(sys.argv[2]).read())
assert [i["path"] for i in d["files"]] == ["lib/a.sh"], d
assert d["in_file"][0]["file"] == "web/app.py" and d["in_file"][0]["markers"] == ["ring20-local: x"], d
PY
}

# ------------------------------------------------------------ survives fw vendor

_src_v1() {
    SRC="$TMP/src"
    mkdir -p "$SRC/bin" "$SRC/lib" "$SRC/web"
    printf '#!/bin/sh\necho stub\n' > "$SRC/bin/fw"; chmod +x "$SRC/bin/fw"
    echo "# framework" > "$SRC/FRAMEWORK.md"
    echo "a v1" > "$SRC/lib/a.sh"
    echo "app v1" > "$SRC/web/app.py"
    git -C "$SRC" init -q
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t add -A
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qm v1
}
_vendor() {
    ( cd "$PROJ" && env -u CLAUDECODE FRAMEWORK_ROOT="$FRAMEWORK_ROOT" PROJECT_ROOT="$PROJ" \
        "$FRAMEWORK_ROOT/bin/fw" vendor --target "$PROJ" --source "$SRC" "$@" 2>&1 )
}

@test "fw vendor: a registered override survives an upstream change, and the vendor names it" {
    _src_v1
    _vendor >/dev/null
    [ -f "$AF/.fw-vendor-stamp.json" ]
    echo "a v1 + project patch" > "$AF/lib/a.sh"
    _ext add vendored-override patch-a --path lib/a.sh --words "our lib/a.sh, keep it"
    echo "a v2" > "$SRC/lib/a.sh"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2
    run _vendor
    [ "$status" -eq 0 ]
    [ "$(cat "$AF/lib/a.sh")" = "a v1 + project patch" ]
    [[ "$output" == *"EXTENSIONS  1 registered"* ]]
    [[ "$output" == *"patch-a [vendored-override] lib/a.sh  — kept"* ]]
    # The register itself is project-owned: the vendor did not write it.
    grep -q 'words: "our lib/a.sh, keep it"' "$PROJ/.framework-extensions.yaml"
}

@test "fw vendor: an unregistered local edit is still refused (no second mechanism, T-3850 unchanged)" {
    _src_v1
    _vendor >/dev/null
    echo "edited" > "$AF/lib/a.sh"
    echo "a v2" > "$SRC/lib/a.sh"
    git -C "$SRC" -c user.email=t@example.invalid -c user.name=t commit -qam v2
    run _vendor
    [ "$status" -ne 0 ]
    [[ "$output" == *"LOCAL  lib/a.sh"* ]]
}

# ------------------------------------------------------------ audit

@test "audit: INFO lists the register" {
    mkdir -p "$PROJ/web"; touch "$PROJ/web/x.py"
    _ext add page pg --path web/x.py --words w
    run _audit
    [[ "$output" == *"[INFO] Project extensions (1): pg [page]"* ]]
    [[ "$output" != *"Extension pg: registered path"* ]]
}

@test "audit WARN: a registered path that does not exist" {
    _ext add page gone --path web/gone.py --words w
    _ext add vendored-override vgone --path lib/gone.sh --words w
    run _audit
    [[ "$output" == *"[WARN] Extension gone: registered path web/gone.py does not exist"* ]]
    [[ "$output" == *"[WARN] Extension vgone: registered path .agentic-framework/lib/gone.sh does not exist"* ]]
}

@test "audit WARN: a preserve entry with no register decision behind it" {
    mkdir -p "$AF/web" "$AF/lib"; touch "$AF/web/hand.py" "$AF/lib/a.sh"
    printf 'files:\n  - web/hand.py\n' > "$PROJ/.fwvendor-preserve.yaml"
    _ext add vendored-override ok --path lib/a.sh --words w
    run _audit
    [[ "$output" == *"[WARN] Preserve entry files: web/hand.py has no operator decision"* ]]
    # The mirrored item is backed by the register.
    [[ "$output" != *"Preserve entry files: lib/a.sh"* ]]
}

@test "audit WARN: a vendored file the stamp shows locally modified with no decision" {
    _src_v1
    _vendor >/dev/null
    echo "edited" > "$AF/web/app.py"
    echo "edited" > "$AF/lib/a.sh"
    _ext add vendored-override keep-a --path lib/a.sh --words w
    run _audit
    [[ "$output" == *"[WARN] Vendored file .agentic-framework/web/app.py is locally modified with no operator decision"* ]]
    [[ "$output" != *"Vendored file .agentic-framework/lib/a.sh"* ]]
}

@test "audit: silent on a project with no register, no preserve manifest and no local edits" {
    run _audit
    [[ "$output" != *"Project extensions"* ]]
    [[ "$output" != *"Preserve entry"* ]]
    [[ "$output" != *"locally modified with no operator decision"* ]]
}
