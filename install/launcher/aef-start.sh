#!/usr/bin/env bash
# aef-start.sh — the P-01 one-click launcher (T-3659), reference copy (T-4721).
#
# What the desktop icon runs: cd into the project, start Watchtower detached and
# open it, run Claude Code under claude-fw, then leave the user in a project shell.
#
#   aef-start.sh [--new] [PROJECT_DIR]
#
# Default: CONTINUE the project's last conversation (`claude-fw -c`). After a
# restart the icon must take the operator back into the running work (055,
# 'greenfield', 2026-10-23); `--new` opens a fresh conversation instead.
#
# How the fallback behaves (and why it is not `claude-fw -c || claude-fw`):
#   - claude-fw resolves -c to this project's interactive conversation, and with
#     none it already starts fresh (T-4497), so -c needs no fallback there.
#   - exit 3 is claude-fw REFUSING: the conversation is live in another process
#     (T-3890 / T-4714) or is a background job (T-4048). Opening a fresh one would
#     hide the live work behind a second conversation, so the launcher stops and
#     says so. `aef-start.sh --new` is the deliberate way to get a fresh one.
#   - any other failure within AEF_START_FALLBACK_SECS (default 15) means -c never
#     got going (an older claude-fw, or plain `claude -c` with nothing to
#     continue): start fresh. A session that ran and then exited non-zero is not
#     restarted.
#
# Environment: AEF_PROJECT (project dir when none is given), AEF_START_NO_WATCHTOWER=1,
# AEF_START_NO_BROWSER=1, AEF_START_NO_SHELL=1, AEF_START_FALLBACK_SECS.

new=0
project="${AEF_PROJECT:-}"
for a in "$@"; do
    case "$a" in
        --new) new=1 ;;
        -h|--help) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
        -*) echo "aef-start: unknown option $a (try --help)" >&2; exit 2 ;;
        *) project="$a" ;;
    esac
done
project="${project:-$PWD}"
cd "$project" || { echo "aef-start: cannot cd into $project" >&2; exit 1; }

# Watchtower, detached so it outlives this terminal (T-3660).
fw=""
for c in bin/fw .agentic-framework/bin/fw; do
    [ -x "$c" ] && { fw="$PWD/$c"; break; }
done
if [ -n "$fw" ] && [ "${AEF_START_NO_WATCHTOWER:-0}" != 1 ]; then
    if ! "$fw" watchtower status >/dev/null 2>&1; then
        (setsid "$fw" watchtower start >/dev/null 2>&1 < /dev/null &)
        sleep 2
    fi
    if [ "${AEF_START_NO_BROWSER:-0}" != 1 ]; then
        url=$("$fw" watchtower url 2>/dev/null)
        opener=$(command -v xdg-open || command -v open || command -v wslview || true)
        [ -n "$url" ] && [ -n "$opener" ] && ("$opener" "$url" >/dev/null 2>&1 &)
    fi
fi

# Claude Code: claude-fw (enforcement live) when present, else plain claude.
runner=$(command -v claude-fw >/dev/null 2>&1 && echo claude-fw || echo claude)
if [ "$new" = 1 ]; then
    "$runner"
else
    started=$(date +%s)
    "$runner" -c
    rc=$?
    elapsed=$(( $(date +%s) - started ))
    if [ "$rc" = 3 ] && [ "$runner" = claude-fw ]; then
        echo "aef-start: claude-fw refused to continue: that conversation is already live elsewhere (see the message above)." >&2
        echo "  Use the running session, or start a separate fresh one with: $0 --new" >&2
    elif [ "$rc" != 0 ] && [ "$elapsed" -lt "${AEF_START_FALLBACK_SECS:-15}" ]; then
        echo "aef-start: nothing to continue (exit $rc) — starting a fresh conversation" >&2
        "$runner"
    fi
fi

[ "${AEF_START_NO_SHELL:-0}" = 1 ] && exit 0
exec "${SHELL:-bash}" -i
