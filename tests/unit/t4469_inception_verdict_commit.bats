#!/usr/bin/env bats
# T-4469 — a reviewer's verdict-only commit (.context/reviews/ only) on an undecided
# inception must pass the commit-msg inception gates (commit limit + research
# artifact), and a refused verdict commit must not leave its row staged.
#
# Origin: 832 (v1.8.12) — `fw reviewer verdict record --commit` on inception T-1215
# was refused at the research-artifact gate; the row stayed staged, the next
# unrelated commit carried it, and the append-only ledger blocked every push.
#
# Hermetic: hooks are installed into a temp repo whose .framework.yaml points at
# this checkout; the commit-msg hook is run directly against the staged index.

load ../git_fence

setup() {
    FW_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    FX="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$FX/.tasks/active" "$FX/.context/reviews" "$FX/.context/costs"
    git -C "$FX" init -q
    git -C "$FX" config user.email "t4469@localhost"
    git -C "$FX" config user.name "T-4469 fixture"
    printf 'framework_path: %s\n' "$FW_ROOT" > "$FX/.framework.yaml"
    printf -- '---\nid: T-9100\nworkflow_type: inception\nstatus: started-work\n---\n# T-9100\n' \
        > "$FX/.tasks/active/T-9100-probe.md"
    git -C "$FX" add .tasks .framework.yaml
    git -C "$FX" commit -q -m "T-9100: file inception" --no-verify
    # Spend the whole exploration budget (default limit 2), no research artifact.
    for n in 1 2; do
        printf 'note %s\n' "$n" > "$FX/notes$n.txt"
        git -C "$FX" add "notes$n.txt"
        git -C "$FX" commit -q -m "T-9100: exploration $n" --no-verify
    done
    export PROJECT_ROOT="$FX"
    run bash "$FW_ROOT/agents/git/git.sh" install-hooks
    [ "$status" -eq 0 ]
    [ -f "$FX/.git/hooks/commit-msg" ]
}

_commit_msg() {
    printf '%s\n' "$1" > "$FX/.git/T4469_MSG"
    run bash -c "cd '$FX' && PROJECT_ROOT='$FX' .git/hooks/commit-msg .git/T4469_MSG"
}

_load_classifier() {
    awk '
        /^_count_inception_exploration_commits\(\)/ { in_fn=1; brace=0 }
        in_fn { print; for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="{") brace++; if (c=="}") { brace--; if (brace==0 && in_fn) { in_fn=0 } } } }
    ' "$FW_ROOT/agents/git/lib/hooks.sh" > "$BATS_TEST_TMPDIR/_classifier.sh"
    source "$BATS_TEST_TMPDIR/_classifier.sh"
}

@test "control: an ordinary commit on the exhausted inception is refused" {
    printf 'more\n' > "$FX/notes3.txt"
    git -C "$FX" add notes3.txt
    _commit_msg "T-9100: more exploration"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
}

@test "a verdict-only commit passes both inception gates" {
    printf '{"id": "V-1"}\n' > "$FX/.context/reviews/verdicts.jsonl"
    printf '{"id": "C-1"}\n' > "$FX/.context/costs/reviews.jsonl"
    git -C "$FX" add .context/reviews/verdicts.jsonl .context/costs/reviews.jsonl
    _commit_msg "T-9100: reviewer verdict"
    [ "$status" -eq 0 ]
    [[ "$output" != *"BLOCKED"* ]]
    [[ "$output" == *"T-4469"* ]]
}

@test "the exemption is exact: a verdict row plus one other file is refused" {
    printf '{"id": "V-1"}\n' > "$FX/.context/reviews/verdicts.jsonl"
    printf 'other\n' > "$FX/other.txt"
    git -C "$FX" add .context/reviews/verdicts.jsonl other.txt
    _commit_msg "T-9100: reviewer verdict"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BLOCKED"* ]]
}

@test "research-artifact gate alone (budget not spent) also skips a verdict-only commit" {
    echo "INCEPTION_COMMIT_LIMIT: 10" >> "$FX/.framework.yaml"
    printf '{"id": "V-1"}\n' > "$FX/.context/reviews/verdicts.jsonl"
    git -C "$FX" add .context/reviews/verdicts.jsonl
    _commit_msg "T-9100: reviewer verdict"
    [ "$status" -eq 0 ]
    [[ "$output" != *"no research artifact"* ]]
}

@test "the classifier does not count a verdict-only commit toward the limit" {
    _load_classifier
    cd "$FX"
    run _count_inception_exploration_commits "T-9100"
    before="$output"
    [ "$before" -ge 2 ]
    printf '{"id": "V-1"}\n' > .context/reviews/verdicts.jsonl
    git add .context/reviews/verdicts.jsonl
    git commit -q -m "T-9100: reviewer verdict" --no-verify
    run _count_inception_exploration_commits "T-9100"
    [ "$output" -eq "$before" ]
    # control: a non-ledger commit does count
    printf 'x\n' > notes9.txt
    git add notes9.txt
    git commit -q -m "T-9100: exploration 9" --no-verify
    run _count_inception_exploration_commits "T-9100"
    [ "$output" -eq $((before + 1)) ]
}

@test "_commit_rows unstages its paths when the commit is refused" {
    printf '#!/bin/sh\necho refused-by-test >&2\nexit 1\n' > "$FX/.git/hooks/commit-msg"
    chmod +x "$FX/.git/hooks/commit-msg"
    printf '{"id": "V-1"}\n' > "$FX/.context/reviews/verdicts.jsonl"
    run python3 -c "
import sys; from pathlib import Path
sys.path.insert(0, '$FW_ROOT')
from lib import verdict_ledger as vl
root = Path('$FX')
sha, err = vl._commit_rows(root, vl._ledger_paths(root, []), 'w', 'T-9100: reviewer verdict')
print('SHA=' + sha); print('ERR=' + err)
"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "SHA=" ]]
    [[ "$output" == *"refused-by-test"* ]]
    [[ "$output" == *"unstaged"* ]]
    staged=$(git -C "$FX" diff --cached --name-only)
    [ -z "$staged" ]
    [ -f "$FX/.context/reviews/verdicts.jsonl" ]
}
