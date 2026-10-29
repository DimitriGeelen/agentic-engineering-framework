#!/usr/bin/env bats
# T-4903: fw release publishes the notes with task ids linked to the task files at the
# release tag (a bare "T-NNNN" on GitHub is confusing for readers).

load ../test_helper

setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    ORIGIN="$TEST_TEMP_DIR/origin.git"
    REPO="$TEST_TEMP_DIR/repo"
    git init -q --bare -b master "$ORIGIN"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b master
    git -C "$REPO" config user.email t@t.t
    git -C "$REPO" config user.name t
    git -C "$REPO" config commit.gpgsign false
    echo 1.0.0 > "$REPO/VERSION"
    mkdir -p "$REPO/docs/releases" "$REPO/.tasks/completed"
    echo "# v1.0.0" > "$REPO/docs/releases/v1.0.0-notes.md"
    echo base > "$REPO/f"; git -C "$REPO" add f VERSION docs; git -C "$REPO" commit -qm c1
    git -C "$REPO" tag v1.0.0
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin master v1.0.0
    git -C "$REPO" checkout -q -b bleeding-edge
    echo "task" > "$REPO/.tasks/completed/T-7-fix-the-thing.md"
    {
        echo "# v1.0.1"; echo
        echo "Fixes the thing (**T-7**). Run \`fw task show T-7\` for detail."
        for i in $(seq 1 20); do echo "A readable line about change number $i for consumers."; done
    } > "$REPO/docs/releases/v1.0.1-notes.md"
    git -C "$REPO" add .tasks docs; git -C "$REPO" commit -qm "T-7: fix and notes"
    STUB_BIN="$TEST_TEMP_DIR/bin"; mkdir -p "$STUB_BIN"
    NOTES_SEEN="$TEST_TEMP_DIR/notes.seen"
    cat > "$STUB_BIN/gh" <<EOF
#!/bin/sh
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--notes-file" ]; then cat "\$2" > "$NOTES_SEEN"; fi
  shift
done
exit 0
EOF
    chmod +x "$STUB_BIN/gh"
    LIB="$FRAMEWORK_ROOT/lib/release.sh"
    env PROJECT_ROOT="$REPO" bash -c "source '$LIB'; release_decide v1.0.1 --by operator --ref 'test decision'" >/dev/null 2>&1
}

teardown() { rm -rf "$TEST_TEMP_DIR"; }

@test "the published notes link task ids to the task file at the release tag" {
    run env PATH="$STUB_BIN:$PATH" PROJECT_ROOT="$REPO" RELEASE_TAG_RETRY_SLEEP=0 \
        bash -c "source '$LIB'; release_main tag-and-release --repo owner/proj" 2>&1 </dev/null
    [ "$status" -eq 0 ]
    grep -qF "**[T-7](https://github.com/owner/proj/blob/v1.0.1/.tasks/completed/T-7-fix-the-thing.md)**" "$NOTES_SEEN"
    # inside a code span the id stays as typed
    grep -qF '`fw task show T-7`' "$NOTES_SEEN"
    # the committed notes file itself is unchanged
    ! grep -q "github.com" "$REPO/docs/releases/v1.0.1-notes.md"
}
