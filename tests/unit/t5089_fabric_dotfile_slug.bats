#!/usr/bin/env bats
# T-5089 (GitHub #109) — `fw fabric register .gitignore` wrote `.fabric/components/.yaml`:
# the slug stripped the dotfile's whole name as if it were an extension. A second dotfile
# collided by registration order, and `.framework.yaml` got the slug of `framework.yaml`.
# A dotfile's leading dot now becomes a `dot-` prefix; every other path keeps its slug.

FRAMEWORK_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    TMP_PROJECT=$(mktemp -d)
    mkdir -p "$TMP_PROJECT/.fabric/components" "$TMP_PROJECT/sub" "$TMP_PROJECT/lib"
    for f in .gitignore .dockerignore .framework.yaml sub/.env framework.yaml lib/x.sh; do
        printf '# %s\n' "$f" > "$TMP_PROJECT/$f"
    done
    export PROJECT_ROOT="$TMP_PROJECT"
    export FABRIC_DIR="$TMP_PROJECT/.fabric"
    export COMPONENTS_DIR="$FABRIC_DIR/components"
    export RED="" GREEN="" YELLOW="" CYAN="" BOLD="" NC=""
    ensure_fabric_dirs() { :; }
    source "$FRAMEWORK_ROOT/agents/fabric/lib/register.sh"
}

teardown() { rm -rf "$TMP_PROJECT"; }

reg() { (cd "$TMP_PROJECT" && _do_register_file "$1") >/dev/null 2>&1; }

@test "T-5089: slugs for dotfiles get a dot- prefix" {
    [ "$(_fabric_slug .gitignore)" = "dot-gitignore" ]
    [ "$(_fabric_slug .framework.yaml)" = "dot-framework" ]
    [ "$(_fabric_slug sub/.env)" = "sub-dot-env" ]
}

@test "T-5089: other paths keep their old slug" {
    [ "$(_fabric_slug lib/x.sh)" = "lib-x" ]
    [ "$(_fabric_slug framework.yaml)" = "framework" ]
    [ "$(_fabric_slug .context/project/workflows/foo.yaml)" = "context-project-workflows-foo" ]
    [ "$(_fabric_slug bin/fw)" = "bin-fw" ]
}

@test "T-5089: registering two root dotfiles writes two named cards, never .yaml" {
    reg .dockerignore
    reg .gitignore
    [ -f "$COMPONENTS_DIR/dot-gitignore.yaml" ]
    [ -f "$COMPONENTS_DIR/dot-dockerignore.yaml" ]
    [ ! -f "$COMPONENTS_DIR/.yaml" ]
    [ ! -f "$COMPONENTS_DIR/-dockerignore.yaml" ]
}

@test "T-5089: .framework.yaml and framework.yaml get different cards" {
    reg framework.yaml
    reg .framework.yaml
    grep -q '^location: framework.yaml' "$COMPONENTS_DIR/framework.yaml"
    grep -q '^location: .framework.yaml' "$COMPONENTS_DIR/dot-framework.yaml"
}

@test "T-5089: a dotfile card under the old slug is recognised, not duplicated" {
    # The card name the old rule gave this file (sub/.env -> "sub-").
    legacy=$(printf '%s' sub/.env | sed 's|/|-|g; s|\.[^./-]*$||; s|^\.||')
    [ "$legacy" = "sub-" ]
    printf 'id: x\nlocation: sub/.env\n' > "$COMPONENTS_DIR/${legacy}.yaml"
    out=$(cd "$TMP_PROJECT" && _do_register_file sub/.env 2>&1)
    [[ "$out" == *"Card already exists"* ]]
    [ ! -f "$COMPONENTS_DIR/sub-dot-env.yaml" ]
}
