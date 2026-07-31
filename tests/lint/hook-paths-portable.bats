#!/usr/bin/env bats
# Invariant: hook `command` strings in .claude/settings.json must reference fw via the
# ${CLAUDE_PROJECT_DIR} placeholder — never via a literal absolute filesystem path.
#
# Origin: T-2704. All 25 hook commands in this repo read
# `/opt/999-Agentic-Engineering-Framework/bin/fw hook <name>` — the checkout path of
# whichever host last ran init/upgrade. Clone onto any other host and every hook fails
# to resolve, so governance is silently OFF everywhere but here. It fails toward
# no-enforcement, quietly.
#
# Why the existing surfaces miss it (see docs/reports/T-2704-hook-path-portability.md):
#   - fw doctor's `broken` counter asks "does the file exist?" — on the generating host
#     it always does, by construction, forever.
#   - fw doctor's `stale_paths` predicate looks for '/agents/context/' or 'PROJECT_ROOT=',
#     which is the PRE-T-496 defect shape, not this one.
#   - the T-1629 /tmp hook exercise varies CWD, not HOST — absolute paths pass trivially.
# So the class is cheaply detectable on the generating host and nothing looks for it.
# That is what this guard is.
#
# NOT a re-regression to relative paths: T-1364/T-1504 correctly established that hook
# commands must resolve independently of CWD (relative paths cost 680 silent failures
# downstream at 003-NTB-ATC-Plugin). ${CLAUDE_PROJECT_DIR} expands to an ABSOLUTE path,
# so it keeps that property while adding host-portability. The rule below is therefore
# "portable AND absolute-after-expansion", not "relative".
#
# Scope discipline (false-positive surface): this asserts only over FRAMEWORK hook
# entries — commands invoking `fw hook <name>`. A project registering its own script via
# `fw hook-enable --script <abs-path>` (bin/hook-enable.sh:29) is legitimately absolute
# and is counted separately, never failed on. A framework invariant must not block a
# consumer from wiring its own hooks.

setup() {
    FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}"
    SETTINGS="$FRAMEWORK_ROOT/.claude/settings.json"
}

# _scan <settings.json> -> "<fw_total>|<offenders>|<foreign>|<detail>"
#   fw_total  = framework `fw hook` command entries seen
#   offenders = those whose fw path is a literal absolute path (the defect)
#   foreign   = non-framework entries (informational only — never fails)
_scan() {
    python3 - "$1" <<'PY'
import json, re, sys

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except FileNotFoundError:
    print("MISSING|0|0|settings.json not found"); raise SystemExit(0)
except json.JSONDecodeError as e:
    print(f"BADJSON|0|0|{e}"); raise SystemExit(0)

fw_total = 0
foreign = 0
offenders = []

for event, entries in (data.get("hooks") or {}).items():
    for entry in entries or []:
        for hook in entry.get("hooks") or []:
            cmd = (hook.get("command") or "").strip()
            if not cmd:
                continue
            # Framework hook = dispatches through `fw hook <name>`. Anything else is a
            # project-local registration and is out of scope for this invariant.
            if not re.search(r"(^|/)fw\s+hook\s", cmd):
                foreign += 1
                continue
            fw_total += 1
            # The fw path is the first token that is not an ENV=value prefix.
            exe = ""
            for tok in cmd.split():
                if "=" not in tok.split("/")[0]:
                    exe = tok
                    break
            # Portable iff the path is anchored on the CLAUDE_PROJECT_DIR placeholder.
            # Accept both spellings and an optional leading quote, since shell form may
            # legitimately be written "$CLAUDE_PROJECT_DIR"/bin/fw.
            if re.match(r'^"?\$\{?CLAUDE_PROJECT_DIR\}?', exe):
                continue
            if exe.startswith("/"):
                offenders.append(f"{event}: {cmd}")

detail = " ;; ".join(offenders) if offenders else ""
print(f"{fw_total}|{len(offenders)}|{foreign}|{detail}")
PY
}

@test "hook paths: every framework hook command uses \${CLAUDE_PROJECT_DIR}, not a hardcoded absolute path" {
    result="$(_scan "$SETTINGS")"
    fw_total="${result%%|*}"
    rest="${result#*|}"
    offenders="${rest%%|*}"
    rest="${rest#*|}"
    detail="${rest#*|}"

    [ "$fw_total" != "MISSING" ] || { echo "settings.json not found: $SETTINGS"; false; }
    [ "$fw_total" != "BADJSON" ] || { echo "settings.json is not valid JSON"; false; }

    if [ "$offenders" -ne 0 ]; then
        echo "FAIL: $offenders of $fw_total framework hook command(s) hardcode an absolute path."
        echo ""
        echo "Hook commands must resolve on ANY host. Use the placeholder, which expands"
        echo "to an absolute path (so CWD-drift protection from T-1364/T-1504 is kept):"
        echo "  framework repo:  \${CLAUDE_PROJECT_DIR}/bin/fw hook <name>"
        echo "  consumer:        \${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <name>"
        echo ""
        echo "Do NOT hand-edit settings.json — fix the generators (lib/init.sh:617,"
        echo "bin/hook-enable.sh:116) and regenerate, then refresh the enforcement"
        echo "baseline (bin/fw enforcement baseline). See T-2704."
        echo ""
        echo "Offending entries:"
        printf '%s\n' "$detail" | tr ';' '\n' | sed '/^ *$/d;s/^ */  - /'
        false
    fi
}

@test "hook paths: settings.json declares a plausible number of framework hooks" {
    # Guards the degenerate pass — an empty or hook-less settings.json would otherwise
    # satisfy the portability assertion vacuously (0 offenders of 0 commands).
    result="$(_scan "$SETTINGS")"
    fw_total="${result%%|*}"
    [ "$fw_total" != "MISSING" ] || { echo "settings.json not found"; false; }
    [ "$fw_total" -ge 10 ] || {
        echo "Only $fw_total framework hook commands found (expected >= 10)."
        echo "Either settings.json lost hooks, or the detector stopped recognising them."
        false
    }
}

@test "hook paths: project-local --script registrations are not flagged (no false positive)" {
    # A consumer may register its own hook by absolute path via
    # `fw hook-enable --script /abs/path.sh`. That is legitimately absolute and must not
    # trip a FRAMEWORK invariant. Proven on a fixture, not asserted in prose.
    fixture="$BATS_TEST_TMPDIR/fp/.claude"
    mkdir -p "$fixture"
    cat > "$fixture/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/bin/fw hook check-active-task" },
          { "type": "command", "command": "/opt/some-project/.claude/hooks/my-own-hook.sh" }
        ]
      }
    ]
  }
}
JSON
    result="$(_scan "$fixture/settings.json")"
    fw_total="${result%%|*}"
    rest="${result#*|}"
    offenders="${rest%%|*}"
    rest="${rest#*|}"
    foreign="${rest%%|*}"

    [ "$fw_total" -eq 1 ]  || { echo "expected 1 framework hook, got $fw_total"; false; }
    [ "$offenders" -eq 0 ] || { echo "false positive: flagged $offenders (expected 0)"; false; }
    [ "$foreign" -eq 1 ]   || { echo "expected 1 foreign entry counted, got $foreign"; false; }
}
