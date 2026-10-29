#!/usr/bin/env bats
# T-4906: the Verification guidance must not render as huge bold headings.
#   GitHub: the template's guidance is an HTML comment (hidden), not `# …` lines (H1s).
#   Watchtower: the raw Task Body block is not auto-highlighted (`nohighlight`).
# The completion gate strips HTML comments, so a fresh template still has no command.

setup() {
    REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TPL="$REPO/.tasks/templates/default.md"
    source "$REPO/lib/verification-port.sh"
    T="$(mktemp -d)"
}

teardown() { rm -rf "$T"; }

_verif() { awk '/^## Verification/{f=1;next} f&&/^## /{exit} f{print}' "$1"; }

@test "template: no Verification line starts a Markdown heading outside the comment" {
    run python3 -I -c 'import re,sys; t=re.sub(r"<!--.*?-->","",sys.stdin.read(),flags=re.S); sys.exit(1 if re.search(r"(?m)^#{1,6} ", t) else 0)' < <(_verif "$TPL")
    [ "$status" -eq 0 ]
}

@test "template: the gate extracts no command from an untouched template" {
    run extract_verification_block "$TPL"
    [ "$status" -eq 0 ]
    [ -z "$(printf '%s' "$output" | tr -d '[:space:]')" ]
}

@test "template: a command written below the comment is extracted" {
    awk '{print} /^## Verification/ {v=1} v && /^-->$/ && !done {print "bash -n lib/x.sh"; done=1}' "$TPL" > "$T/task.md"
    run extract_verification_block "$T/task.md"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]
    [[ "$output" == "bash -n lib/x.sh" ]]
}

@test "Watchtower: the raw Task Body block is excluded from highlight.js" {
    grep -q '<pre><code class="nohighlight">{{ task_body_html | safe }}</code></pre>' \
        "$REPO/web/templates/task_detail.html"
}
