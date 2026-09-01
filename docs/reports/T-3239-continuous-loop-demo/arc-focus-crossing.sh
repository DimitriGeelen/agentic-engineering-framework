#!/usr/bin/env bash
# T-3239 E6 — does the ARC FOCUS actually cross a restart boundary?
#
# THE QUESTION. The arc's headline mechanic ends "...operator observes multi-cycle
# continuous session whose iteration counter, directive, and bounded tier-ceiling
# are visible". E4 proved the counter advances and the directive is re-emitted.
# Neither E4 nor E5 touched the ARC. A loop that cycles forever while forgetting
# which arc it is working on is not the mechanism — it is a restart loop with
# amnesia, and from the outside the two look identical.
#
# WHY THIS SHAPE. The restarted session is FRESH by construction (T-3166 —
# CLAUDE_ARGS is emptied so the session cannot inherit the context it restarted
# to escape). So it knows nothing it was not handed. Everything the next
# iteration will ever know about the arc has to be inside the SessionStart
# payload. That payload is therefore the whole boundary, and it is capturable:
# run the real hook, read its stdout.
#
# This runs the REAL agents/context/post-compact-resume.sh through the REAL
# `fw hook` dispatcher, against a sandbox with the real state files. Nothing is
# reimplemented — a reimplementation would be testing my model of the hook.
#
# CONTROL LEG. A disarmed sandbox, identical in every other respect. Without it,
# "the arc crossed" cannot be distinguished from "the arc was in the payload for
# some unrelated reason".
#
# Usage: bash docs/reports/T-3239-continuous-loop-demo/arc-focus-crossing.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EVID="${REPO}/docs/reports/T-3239-continuous-loop-demo/evidence"
OUT="${EVID}/E6-arc-focus-crossing.txt"
mkdir -p "$EVID"

SANDBOX="$(mktemp -d)"; trap 'rm -rf "$SANDBOX"' EXIT
pass=0; fail=0; report=""

ARC="continuous-run"
TASK="T-3239"
BEACON="ARCBEACON-7731"

# build_case <name> <enabled> <sentinel:yes|no> <source>
build_case() {
    local name="$1" enabled="$2" sentinel="$3" source="$4"
    local root="${SANDBOX}/${name}"
    mkdir -p "${root}/.context/working" "${root}/.context/handovers" "${root}/.tasks/active"
    git -C "$root" init -q
    git -C "$root" config user.email t@t.t; git -C "$root" config user.name t

    # Real state files, the same ones a live project carries.
    printf 'current_task: %s\n' "$TASK"          > "${root}/.context/working/focus.yaml"
    printf 'current_arc: %s\n' "$ARC"            > "${root}/.context/working/arc-focus.yaml"
    cat > "${root}/.context/working/.continuous-mode.yaml" <<YAML
enabled: ${enabled}
current_iteration: 4
max_iterations: 10
tier_ceiling: 1
tasks_completed: 0
YAML
    cat > "${root}/.context/working/.next-directive.yaml" <<YAML
expires_at: "$(python3 -c "
import datetime;print((datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
directive: |
  Continue arc ${ARC}. Emit ${BEACON} once, then take the next action.
YAML
    printf '# Handover\n\n## Where We Are\n\nMid-run on arc %s under %s.\n' "$ARC" "$TASK" \
        > "${root}/.context/handovers/LATEST.md"
    [ "$sentinel" = "yes" ] && : > "${root}/.context/working/.auto-restart-pending"
    echo "$root"
}

# run_case <name> <enabled> <sentinel> <source> <want_arc:yes|no> <want_directive:yes|no>
run_case() {
    local name="$1" enabled="$2" sentinel="$3" source="$4" want_arc="$5" want_dir="$6"
    local root out iter_before iter_after
    root=$(build_case "$name" "$enabled" "$sentinel" "$source")

    iter_before=$(grep '^current_iteration:' "${root}/.context/working/.continuous-mode.yaml" | tr -dc '0-9')
    # The REAL hook, through the REAL dispatcher, exactly as settings.json calls it.
    out=$(printf '{"source":"%s"}' "$source" \
          | CLAUDE_PROJECT_DIR="$root" PROJECT_ROOT="$root" \
            timeout 60 bash "${REPO}/bin/fw" hook post-compact-resume 2>&1)
    iter_after=$(grep '^current_iteration:' "${root}/.context/working/.continuous-mode.yaml" | tr -dc '0-9')

    local has_arc=no has_dir=no has_task=no has_iter=no
    case "$out" in *"$ARC"*)     has_arc=yes ;; esac
    case "$out" in *"$BEACON"*)  has_dir=yes ;; esac
    case "$out" in *"$TASK"*)    has_task=yes ;; esac
    case "$out" in *"teration"*) has_iter=yes ;; esac

    local verdict=PASS
    [ "$has_arc" = "$want_arc" ] || verdict=FAIL
    [ "$has_dir" = "$want_dir" ] || verdict=FAIL
    [ "$verdict" = PASS ] && pass=$((pass+1)) || fail=$((fail+1))

    report+="  ${name}   (source=${source} enabled=${enabled} sentinel=${sentinel})
      arc '${ARC}' in payload        : ${has_arc}   (want ${want_arc})
      directive beacon in payload    : ${has_dir}   (want ${want_dir})
      focus task ${TASK} in payload  : ${has_task}
      iteration wording in payload   : ${has_iter}
      current_iteration              : ${iter_before} -> ${iter_after}
      payload bytes                  : $(printf '%s' "$out" | wc -c)
      verdict                        : ${verdict}

"
    # Keep the first armed payload whole — it is the boundary itself.
    if [ "$name" = "1-armed-startup-restart" ]; then
        { echo "───── VERBATIM SessionStart payload handed to the restarted session ─────"
          printf '%s\n' "$out"
          echo "───── end payload ─────"; } > "${EVID}/E6-payload-verbatim.txt"
    fi
}

# 1. The real case: a fresh restart. T-2376 — an auto-restart emits source
#    "startup", and the .auto-restart-pending sentinel is what distinguishes it
#    from an unrelated cold start.
run_case "1-armed-startup-restart"  true  yes startup yes yes

# 2. Same, via an explicit resume.
run_case "2-armed-resume"           true  yes resume  yes yes

# 3. CONTROL — disarmed. The arc may still appear (it is ambient project state),
#    but the DIRECTIVE must not: an unarmed project has no run to continue.
run_case "3-disarmed-control"       false yes startup yes no

# 4. CONTROL — armed but NO sentinel: a cold operator start, not a loop
#    continuation. The directive must not fire, or every manual `claude` launch
#    would be hijacked by a stale run (the T-3168 failure).
#
#    AUTHORED want_arc=yes AND IT WAS WRONG. The reasoning was that the arc is
#    ambient project state and would appear in the payload regardless, since
#    case 3 emits 1276 bytes carrying it. Measured: the payload is ZERO bytes.
#    post-compact-resume.sh:48-57 exits early on source=startup when the sentinel
#    is absent — `exit 0  # cold start — preserve pre-T-2376 no-op`. Explicit,
#    commented, and correct: a cold start never received this injection before
#    T-2376, and T-2376 deliberately did not change that. Emitting the arc here
#    would be the first half of hijacking a cold start with a stale run.
#
#    Corrected to want_arc=no. Recorded rather than silently amended because
#    filing this as a defect is exactly how a demo manufactures findings out of
#    its own assumptions — the same correction E4 had to make about the expiry
#    counter, and the reason both are written down.
run_case "4-armed-no-sentinel"      true  no  startup no  no

{
    echo "T-3239 E6 — does the arc focus cross the restart boundary?"
    echo "generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "repo sha:  $(git -C "$REPO" rev-parse --short HEAD)"
    echo "hook:      bin/fw hook post-compact-resume  (the real dispatcher)"
    echo
    echo "$report"
    echo "----------------------------------------------------------------"
    echo "PASS: $pass   FAIL: $fail"
    echo
    echo "READING THIS: the restarted session is FRESH (T-3166 empties CLAUDE_ARGS),"
    echo "so it knows nothing it was not handed. This payload IS the boundary."
    echo "Verbatim payload: evidence/E6-payload-verbatim.txt"
} | tee "$OUT"

exit $(( fail > 0 ? 1 : 0 ))
