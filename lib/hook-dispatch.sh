#!/bin/bash
# hook-dispatch.sh — `fw hook <name> [args...]` body (G-118, T-4303)
#
# Every Claude Code hook runs `bin/fw hook NAME`. bash parses bin/fw from the top,
# so a parse error anywhere above the `hook)` branch (today: line ~10553 of 11.5k)
# stops every hook. The body lives here so bin/fw can run it from a fast path placed
# above the bulk of the file (see the G-118 block after FW_BIN_DIR in bin/fw).
#
# Expects in the environment: FRAMEWORK_ROOT, PROJECT_ROOT, AGENTS_DIR, FW_LIB_DIR.
# Always exits (exit or exec) — callers must not expect a return.

fw_hook_run() {
        # fw hook <name> [args...] — runtime path resolution for Claude Code hooks
        # Resolves FRAMEWORK_ROOT from symlink, PROJECT_ROOT from cwd.
        # Replaces hardcoded absolute paths in .claude/settings.json (G-021/T-496).
        _hook_name="${1:-}"
        shift 2>/dev/null || true
        # T-1437: --help / -h print usage, not treated as a hook name
        # (would miss agents/context/--help.sh and log a spurious crash).
        if [ -z "$_hook_name" ] || [ "$_hook_name" = "--help" ] || [ "$_hook_name" = "-h" ]; then
            _hook_exit=1
            [ "${_hook_name:-}" = "--help" ] || [ "${_hook_name:-}" = "-h" ] && _hook_exit=0
            echo "Usage: fw hook <name> [args...]" >&2
            # T-1186/G-042: Generate hook list from filesystem (single source of truth)
            _hooks=$(ls "$AGENTS_DIR/context/"*.sh 2>/dev/null | xargs -I{} basename {} .sh | sort | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')
            echo "Available hooks: $_hooks" >&2
            exit $_hook_exit
        fi
        _hook_script="$AGENTS_DIR/context/${_hook_name}.sh"
        if [ ! -f "$_hook_script" ]; then
            # T-1360 / G-053-B: missing hook script = config drift, NOT a reason to
            # block the agent's tool surface. Exit 2 would hard-block PreToolUse and
            # cascade across every Bash/Write/Edit. Log once to hook-crashes.log so
            # `fw doctor` can surface the drift, then exit 0 (allow).
            echo "WARNING: Hook script not found: $_hook_script (degrading to allow — fix hook config)" >&2
            if [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT/.context/working" ]; then
                _crash_log="$PROJECT_ROOT/.context/working/.hook-crashes.log"
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) missing-hook $_hook_name script=$_hook_script" >> "$_crash_log" 2>/dev/null || true
            fi
            # T-1628 (B-2 of T-1626): record the missing-hook event as a failure
            # so .hook-failure-counter surfaces it. This is the exact witness
            # scenario from T-1626 (ring20-dashboard 2026-04-30): a path-broken
            # hook that "succeeds" with exit 0 was invisible to every health
            # surface. By marking it as a fire with synthetic exit 127 (sh
            # convention for command-not-found), B-3's threshold scan + doctor
            # check have a deterministic signal to alert on.
            if [ -f "$FW_LIB_DIR/hook-telemetry.sh" ]; then
                # shellcheck disable=SC1091
                source "$FW_LIB_DIR/hook-telemetry.sh"
                fw_record_hook_fire "$_hook_name" 127 2>/dev/null || true
            fi
            exit 0
        fi
        export FRAMEWORK_ROOT PROJECT_ROOT
        # T-863: Use bash explicitly — don't require -x (core.filemode=false drops execute bits)
        # T-1628 (B-2 of T-1626): record per-hook fire + non-zero-exit telemetry to
        # .context/working/.hook-counter / .hook-failure-counter. The original `exec`
        # replaced this process; we now run-and-capture so post-exit telemetry can
        # observe the exit code. Telemetry overhead is <0.2ms per fire (mapfile-based,
        # no subprocess); the extra fork from non-exec is negligible vs. hook payload.
        # Source is best-effort — if telemetry helper is missing, skip silently and
        # fall back to plain exec (preserves behaviour on degraded installs).
        # T-4908: a hook that cannot run because it (or a file it sources) has a bash
        # syntax error exits 2 — the same code a gate uses to refuse. On 2026-10-29 a
        # half-finished edit of check-active-task.sh therefore refused every write in
        # the repo, including `git checkout` of the broken file, and only the operator
        # could repair it from outside the hooks. So: keep the payload, keep stderr, and
        # when the failure is bash's own syntax error, open exactly the repair path.
        _hook_payload=""
        [ -t 0 ] || _hook_payload="$(cat)"
        _hook_err="$(mktemp "${TMPDIR:-/tmp}/fw-hook-err.XXXXXX" 2>/dev/null)" || _hook_err=""
        if [ -f "$FW_LIB_DIR/hook-telemetry.sh" ]; then
            # shellcheck disable=SC1091
            source "$FW_LIB_DIR/hook-telemetry.sh"
        fi
        # `|| _hook_rc=$?`, never `cmd; rc=$?`: bin/fw runs under `set -e`, so a hook
        # that refuses (exit 2) would end this function before its captured message
        # is replayed — a refusal with no reason (seen live on 2026-10-29).
        _hook_rc=0
        if [ -n "$_hook_err" ]; then
            bash "$_hook_script" "$@" <<<"$_hook_payload" 2>"$_hook_err" || _hook_rc=$?
            cat "$_hook_err" >&2
        else
            bash "$_hook_script" "$@" <<<"$_hook_payload" || _hook_rc=$?
        fi
        if [ "$_hook_rc" -ne 0 ] && [ -n "$_hook_err" ] && \
           _hook_broken="$(_fw_hook_really_broken "$_hook_err")"; then
            _hook_rc=0
            _fw_hook_broken_mode "$_hook_name" "$_hook_broken" "$_hook_payload" || _hook_rc=$?
        fi
        [ -n "$_hook_err" ] && rm -f "$_hook_err"
        type fw_record_hook_fire >/dev/null 2>&1 && fw_record_hook_fire "$_hook_name" "$_hook_rc" 2>/dev/null || true
        exit "$_hook_rc"
}

# T-4908: decide a tool call while a hook cannot run. $2 is bash's
# "<file>: line N: syntax error" for the file that does not parse. Allowed: the repair
# (restore that file from git, or Write/Edit it). Everything else: exit 2, loudly.
# T-4928 (ring20-dashboard forwarded review, finding 3): stderr TEXT used to decide
# broken mode — any "/x: line N: syntax error" line opened the repair path for /x. Now a
# line counts only when its file is a framework hook or library (agents/ or lib/ under
# FRAMEWORK_ROOT, or under the project's .agentic-framework/) AND `bash -n` really fails
# on it. Prints the first such "<file>: line N: syntax error"; returns 1 if none.
_fw_hook_really_broken() {
    local err="$1" line file real ok root
    while IFS= read -r line; do
        file="${line%%: line *}"
        real="$(realpath -e -- "$file" 2>/dev/null)" || continue
        ok=0
        for root in "${FRAMEWORK_ROOT:-}" "${PROJECT_ROOT:+$PROJECT_ROOT/.agentic-framework}"; do
            [ -n "$root" ] || continue
            root="$(realpath -e -- "$root" 2>/dev/null)" || continue
            case "$real" in "$root"/agents/*|"$root"/lib/*) ok=1 ;; esac
        done
        [ "$ok" -eq 1 ] || continue
        bash -n "$real" 2>/dev/null && continue
        printf '%s\n' "$line"
        return 0
    done < <(grep -oE '^/[^:]+: line [0-9]+: syntax error' "$err" 2>/dev/null)
    return 1
}

_fw_hook_broken_mode() {
    local name="$1" broken="$2" payload="$3"
    local file="${broken%%: line *}" line
    line="$(printf '%s' "$broken" | sed -E 's/.*: line ([0-9]+): syntax error/\1/')"
    if [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT/.context/working" ]; then
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) broken-hook $name file=$file line=$line" \
            >> "$PROJECT_ROOT/.context/working/.hook-crashes.log" 2>/dev/null || true
    fi
    local verdict
    verdict="$(printf '%s' "$payload" | python3 -I -c '
import json, os, re, shlex, sys
broken = os.path.realpath(sys.argv[1]); root = sys.argv[2] or os.getcwd()
try:
    d = json.loads(sys.stdin.read() or "{}")
except Exception:
    print("deny"); sys.exit()
tool = d.get("tool_name", ""); ti = d.get("tool_input") or {}
def same(p, base):
    return bool(p) and os.path.realpath(os.path.join(base, p)) == broken
if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    print("repair" if same(ti.get("file_path") or ti.get("notebook_path") or "", root) else "deny"); sys.exit()
if tool != "Bash":
    print("deny"); sys.exit()
cmd = (ti.get("command") or "").strip()
base = root
m = re.match(r"^cd\s+(\S+)\s*&&\s*(.*)$", cmd, re.S)
if m:
    base = os.path.join(root, m.group(1)); cmd = m.group(2).strip()
if re.search(r"[;&|<>`$(){}\n]", cmd):
    print("deny"); sys.exit()
try:
    w = shlex.split(cmd)
except ValueError:
    print("deny"); sys.exit()
if len(w) >= 2 and w[0] == "git" and w[1] == "-C" and len(w) >= 3:
    base = os.path.join(base, w[2]); w = ["git"] + w[3:]
if len(w) < 3 or w[0] != "git" or w[1] not in ("checkout", "restore"):
    print("deny"); sys.exit()
args = [a for a in w[2:] if a not in ("--", "--worktree") and not a.startswith("--source=")]
if w[1] == "checkout" and "--" not in w[2:]:
    print("deny"); sys.exit()
print("repair" if len(args) == 1 and same(args[0], base) else "deny")
' "$file" "${PROJECT_ROOT:-}" 2>/dev/null)" || verdict="deny"
    if [ "$verdict" = "repair" ]; then
        echo "fw hook: $name cannot run ($file line $line has a syntax error) — allowing this repair of that file (T-4908)." >&2
        return 0
    fi
    echo "" >&2
    echo "BLOCKED: the $name gate cannot run — $file has a bash syntax error at line $line." >&2
    echo "Every write is refused until it is repaired; only the repair itself is allowed (T-4908)." >&2
    echo "" >&2
    echo "Repair (allowed now): git checkout -- $file" >&2
    echo "   or fix the file with the Edit tool, then check it: bash -n $file" >&2
    return 2
}
