#!/usr/bin/env bats
# T-4683 — regression from T-4675. With two dispatch roots (project .context/dispatch + the
# legacy /tmp root), a codex/opencode/antigravity review seat is placed in the legacy root.
# The shadow guard compared that wdir with _wdir_of(name), which falls back to the PROJECT
# root for a name no root holds — so every FIRST dispatch of a harness seat "would shadow"
# a dir that did not exist and died. No multi-vendor review panel could complete.
#
# Sandbox: every external binary is a stub. termlink is stubbed on PATH AND via TERMLINK_BIN
# (T-4682: spawn runs the caller-resolved binary), the codex binary is a stub pinned in the
# sandbox project's own committed registry, tmux/termlink runtime dirs are private, and
# `od` is stubbed so the random review-name suffix is fixed (the shadow case needs to know
# the final name). The real termlink hub is only ever asked `list`, to prove nothing leaked.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="${T4683_SCRIPT:-$FRAMEWORK_ROOT/agents/termlink/termlink.sh}"
    REAL_TL="$(command -v termlink || true)"
    T="$(mktemp -d)"
    PROJ="$T/proj"
    LEGACY="$T/legacy"
    PD="$PROJ/.context/dispatch"
    MARK="$T/marks"
    mkdir -p "$PROJ/.context/working" "$PROJ/policy" "$LEGACY" "$T/bin" "$MARK" "$T/tmux" "$T/tlrt"
    echo "framework_root: $FRAMEWORK_ROOT" > "$PROJ/.framework.yaml"
    # The registry as committed in the sandbox project, with codex pinned to a stub binary.
    sed "s#^\(    binary: \).*codex\$#\1$T/bin/codex#" "$FRAMEWORK_ROOT/policy/review-backends.yaml" \
        > "$PROJ/policy/review-backends.yaml"
    grep -q "binary: $T/bin/codex" "$PROJ/policy/review-backends.yaml"
    git -C "$PROJ" init -q
    git -C "$PROJ" -c user.name=t -c user.email=t@t add policy/review-backends.yaml .framework.yaml
    git -C "$PROJ" -c user.name=t -c user.email=t@t commit -qm init

    cat > "$T/bin/termlink" <<SH
#!/bin/sh
echo "\$*" >> "$MARK/termlink"
case "\$1" in
    list) exit 0 ;;
    --version|version) echo "termlink 0.12.221"; exit 0 ;;
    event) exit 1 ;;
esac
exit 1
SH
    cat > "$T/bin/codex" <<SH
#!/bin/sh
echo "\$*" >> "$MARK/codex"
exit 0
SH
    cat > "$T/bin/od" <<SH
#!/bin/sh
echo od >> "$MARK/od"
echo " 4b 68 30 00 00 01"
SH
    for s in claude tmux systemd-run sudo; do
        printf '#!/bin/sh\necho "$*" >> "%s/%s"\nexit 1\n' "$MARK" "$s" > "$T/bin/$s"
    done
    chmod +x "$T/bin/"*
    unset FW_DISPATCH_DIR FW_TERMLINK_MAX_WORKERS FW_DISPATCH_LIMIT TMUX TMUX_PANE
    export FW_DISPATCH_LEGACY_DIR="$LEGACY"
    export PROJECT_ROOT="$PROJ"
    export TERMLINK_BIN="$T/bin/termlink"
    export TMUX_TMPDIR="$T/tmux" TERMLINK_RUNTIME_DIR="$T/tlrt"
    export PATH="$T/bin:$PATH"
    NAME="t4683-seat-$$-$RANDOM"
    FINAL="$NAME-4b6830000001"
}

teardown() {
    rm -rf "$T"
}

dispatch_codex() {
    run bash -c "cd '$PROJ' && timeout 120 bash '$SCRIPT' dispatch --task T-4683 --name '$NAME' \
        --task-type review --worker-kind codex --prompt 'review it' --project '$PROJ' </dev/null"
}

real_hub_clean() {
    [ -z "$REAL_TL" ] && return 0
    ! PATH=/usr/local/bin:/usr/bin:/bin "$REAL_TL" list 2>/dev/null | grep -q -- "$NAME"
}

@test "T-4683: first codex seat dispatch with two roots gets past the shadow guard" {
    dispatch_codex
    echo "$output"
    [[ "$output" != *"would shadow"* ]] || false
    # The guard let it through: the seat dir was created in the legacy root, nothing in the project.
    [ -d "$LEGACY/$FINAL" ]
    [ ! -e "$PD/$FINAL" ]
    # The stubs ran (the fixed suffix came from the od stub; termlink stub was consulted).
    [ -s "$MARK/od" ]
    [ -s "$MARK/termlink" ]
    # The real codex / claude never ran, and the real hub never saw the worker.
    [ ! -e "$MARK/claude" ] || ! grep -q "review it" "$MARK/claude" || false
    real_hub_clean
}

@test "T-4683: a same-named run already in the project root still dies with the shadow message" {
    mkdir -p "$PD/$FINAL"
    printf '{\n  "name": "%s",\n  "project": "%s"\n}\n' "$FINAL" "$PROJ" > "$PD/$FINAL/meta.json"
    echo 0 > "$PD/$FINAL/exit_code"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$PD/$FINAL/collected"
    dispatch_codex
    echo "$output"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already holds a run of that name and would shadow the new one"* ]]
    [ ! -e "$LEGACY/$FINAL" ]
    [ -s "$MARK/od" ]
    real_hub_clean
}
