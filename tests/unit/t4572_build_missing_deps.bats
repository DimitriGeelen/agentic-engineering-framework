#!/usr/bin/env bats
# T-4572: fw build on a clean machine — lib/ts/node_modules is gitignored, so
# lib/build.sh must install the declared dependencies (js-yaml) before esbuild
# bundles, and must name a dependency it cannot get.
#
# Synthetic framework root with the real lib/build.sh and the real
# lib/ts/package.json, NO node_modules, and stub npm/npx on PATH (real node).

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    T="$(mktemp -d)"
    FR="$T/fw"
    mkdir -p "$FR/lib/ts/src" "$T/bin"
    cp "$REPO/lib/build.sh" "$FR/lib/build.sh"
    cp "$REPO/lib/ts/package.json" "$REPO/lib/ts/package-lock.json" "$FR/lib/ts/"
    printf 'import * as yaml from "js-yaml";\nconsole.log(yaml.dump({a: 1}));\n' > "$FR/lib/ts/src/u.ts"
    NODE_DIR="$(dirname "$(command -v node)")"
    # npx stub: records the call and writes the outfile
    cat > "$T/bin/npx" <<'EOF'
#!/bin/bash
echo "npx $*" >> "$STUB_LOG"
for a in "$@"; do case "$a" in --outfile=*) echo "// built" > "${a#--outfile=}" ;; esac; done
exit "${NPX_RC:-0}"
EOF
    chmod +x "$T/bin/npx"
    ln -s "$NODE_DIR/node" "$T/bin/node"
    # PATH is $T/bin ONLY, so a host npm (/usr/bin/npm) cannot leak in
    for u in dirname basename mkdir; do ln -s "$(command -v "$u")" "$T/bin/$u"; done
    BASH_BIN="$(command -v bash)"
    ln -s "$BASH_BIN" "$T/bin/bash"
    export STUB_LOG="$T/stub.log"
    : > "$STUB_LOG"
}

teardown() { rm -rf "$T"; }

_npm_stub() {
    # $1 = "install" (populate node_modules) or "fail"
    cat > "$T/bin/npm" <<EOF
#!$BASH_BIN
echo "npm \$*" >> "\$STUB_LOG"
[ "$1" = fail ] && exit 1
node -e 'const p=require("./package.json");const d=Object.assign({},p.dependencies,p.devDependencies);const fs=require("fs");for(const n of Object.keys(d)){fs.mkdirSync("node_modules/"+n,{recursive:true});fs.writeFileSync("node_modules/"+n+"/package.json","{}")}'
EOF
    chmod +x "$T/bin/npm"
}

@test "clean tree: build installs declared deps (npm ci) before esbuild" {
    _npm_stub install
    run env PATH="$T/bin" "$BASH_BIN" "$FR/lib/build.sh" -v
    [ "$status" -eq 0 ]
    [[ "$output" == *"compiled 1 file"* ]]
    grep -q '^npm ci' "$STUB_LOG"
    [ -f "$FR/lib/ts/node_modules/js-yaml/package.json" ]
    # install happened before the compile
    [ "$(grep -n '^npm ci' "$STUB_LOG" | cut -d: -f1)" -lt "$(grep -n '^npx' "$STUB_LOG" | cut -d: -f1)" ]
}

@test "clean tree, no npm: exits non-zero naming js-yaml, never calls esbuild" {
    run env PATH="$T/bin" "$BASH_BIN" "$FR/lib/build.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing TypeScript build dependencies"* ]]
    [[ "$output" == *"js-yaml"* ]]
    [[ "$output" == *"npm not found"* ]]
    ! grep -q '^npx' "$STUB_LOG" || false
}

@test "clean tree, npm install fails: exits non-zero naming js-yaml" {
    _npm_stub fail
    run env PATH="$T/bin" "$BASH_BIN" "$FR/lib/build.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"js-yaml"* ]]
    [[ "$output" == *"npm install failed"* ]]
}

@test "esbuild failure is reported with the source, not swallowed" {
    _npm_stub install
    cat > "$T/bin/npx" <<'EOF'
#!/bin/bash
echo 'X [ERROR] Could not resolve "js-yaml"' >&2
exit 1
EOF
    run env PATH="$T/bin" "$BASH_BIN" "$FR/lib/build.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"esbuild failed on lib/ts/src/u.ts"* ]]
    [[ "$output" == *'Could not resolve "js-yaml"'* ]]
}

@test "deps present: no install is attempted" {
    _npm_stub install
    (cd "$FR/lib/ts" && PATH="$T/bin:$PATH" npm ci)
    : > "$STUB_LOG"
    run env PATH="$T/bin" "$BASH_BIN" "$FR/lib/build.sh"
    [ "$status" -eq 0 ]
    ! grep -q '^npm' "$STUB_LOG" || false
}

@test "real lib/ts/package.json declares js-yaml (the import in fw-util.ts)" {
    grep -q 'from "js-yaml"' "$REPO/lib/ts/src/fw-util.ts"
    node -e 'const p=require(process.argv[1]);const d=Object.assign({},p.dependencies,p.devDependencies);process.exit(d["js-yaml"]?0:1)' "$REPO/lib/ts/package.json"
}
