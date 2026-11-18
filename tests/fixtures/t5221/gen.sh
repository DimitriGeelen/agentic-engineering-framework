#!/bin/bash
# How golden/ was made: run against create-task.sh as of 7ef993ddc (before T-5221 moved its
# rendering into lib/render_task.py): bash gen.sh OUTDIR. Kept as the record of the inputs.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FW="${FW:-$(cd "$HERE/../../.." && pwd)}"
OUT="$1"; mkdir -p "$OUT"
unset CLAUDECODE FW_ALLOW_EMPTY_RECOMMENDATION FW_INCEPTION_PRE_GATED FW_SESSION_SCOPED_FOCUS FW_FOCUS_SESSION_KEY
DESC=$'First paragraph: status: captured here.\n\nSecond horizon: now line\nowner: human inside\n\nThird with "quotes" and \\backslash.'
NAME='Fix: the "owner: x" case'"'"'s {braces} & ünïcode — dash'
run() { # case scriptroot templates(yes/no) args...
  local c="$1" root="$2" tpl="$3"; shift 3
  local T; T=$(mktemp -d "${TMPDIR:-/tmp}"/t5221gen.case.XXXX)
  mkdir -p "$T/.tasks/active" "$T/.tasks/completed" "$T/.tasks/templates" "$T/.context/working" "$T/.context/locks"
  [ "$tpl" = yes ] && cp "$FW/tests/fixtures/t5221/templates/"*.md "$T/.tasks/templates/"
  git -C "$T" init -q
  ( cd "$T" && TASKS_DIR="$T/.tasks" PROJECT_ROOT="$T" CONTEXT_DIR="$T/.context" FW_ID_CHECK=1 \
     bash "$root/agents/task-create/create-task.sh" "$@" </dev/null >/dev/null 2>"$T/err" ) || { echo "FAIL $c"; cat "$T/err"; }
  f=$(ls "$T/.tasks/active/"T-*.md)
  id=$(basename "$f" | grep -oE '^T-[0-9]+')
  TS=$(grep -m1 "^created:" "$f" | sed "s/created: //")
  python3 "$HERE/norm.py" "$f" "$id" "$TS" "$T" > "$OUT/$c.md"
  basename "$f" | sed -E 's/^T-[0-9]+/T-ID/' > "$OUT/$c.name"
  rm -rf "$T"
}
run build "$FW" yes --name "$NAME" --description "$DESC" --type build --owner agent --tags "a, b ,c" --related "T-900,T-901" --horizon next
run refactor "$FW" yes --name "Plain refactor name" --description "one line" --type refactor --owner human --start
run inception "$FW" yes --name "$NAME" --description "$DESC" --type inception --owner agent --tags "x"
# inline fallback: a framework root with no .tasks/templates
FAKE=$(mktemp -d "${TMPDIR:-/tmp}"/t5221gen.fake.XXXX); mkdir -p "$FAKE/agents"
cp -r "$FW/agents/task-create" "$FW/agents/context" "$FAKE/agents/"; cp -r "$FW/lib" "$FAKE/lib"
run fallback "$FAKE" no --name "$NAME" --description "$DESC" --type test --owner agent --tags "q"
rm -rf "$FAKE"
