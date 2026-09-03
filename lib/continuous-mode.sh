#!/bin/bash
# Continuous-run counters (T-3169, arc-012 S3).
#
# `.continuous-mode.yaml` carries TWO ceilings, counted in different units:
#
#   current_iteration / max_iterations  — SESSIONS. Advanced by SessionStart
#       (agents/context/inject-next-directive.py). Bounds how many context
#       windows one run may consume.
#   tasks_completed   / max_tasks       — TASKS. Advanced here, on the
#       work-completed transition. Bounds how much WORK one run may do.
#
# They are not interchangeable and neither substitutes for the other. Before
# T-3164 the two were the same number by accident, because a session could only
# take one turn and the run advanced a window per unit of work; `max_iterations: 5`
# therefore meant "five units of work" AND "five 285K windows" at once. With a Stop
# hook driving turns inside one window, many tasks now fit in a single session, and
# the session counter can no longer see any of them. The operator reasons in tasks;
# the budget is spent in sessions. Both get a ceiling.
#
# Part of: Agentic Engineering Framework — arc-012 (continuous-run)

# fw_continuous_note_task_completed <task_id> [project_root]
#
# Increment tasks_completed when the loop is ARMED, once per task id. No-op — and
# silent — when continuous mode is off, when the state file is missing or
# unreadable, or when python3/pyyaml are unavailable. This runs on the completion
# path of every task in the project, so it must never fail a close.
fw_continuous_note_task_completed() {
    local task_id="$1"
    local root="${2:-${PROJECT_ROOT:-$(pwd)}}"
    local state="${root}/.context/working/.continuous-mode.yaml"

    [ -n "$task_id" ] || return 0
    [ -f "$state" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    python3 - "$state" "$task_id" <<'PY' 2>/dev/null || true
import sys

try:
    import yaml
except ImportError:
    raise SystemExit(0)

state_path, task_id = sys.argv[1], sys.argv[2]

try:
    with open(state_path) as f:
        state = yaml.safe_load(f)
except Exception:
    raise SystemExit(0)

if not isinstance(state, dict):
    raise SystemExit(0)

# Disarmed means disarmed: an ordinary session's completions are not loop progress,
# and counting them would make every close look like the loop doing work.
if state.get("enabled") is not True:
    raise SystemExit(0)

seen = state.get("completed_task_ids")
if not isinstance(seen, list):
    seen = []

# Idempotent per task id. `fw task update --status work-completed` is re-runnable
# (partial-complete tasks come back through it after the human ticks their ACs),
# and a ceiling that double-counts one task would end a run early for no reason.
if task_id in seen:
    raise SystemExit(0)

seen.append(task_id)
state["completed_task_ids"] = seen

try:
    count = int(state.get("tasks_completed") or 0)
except (TypeError, ValueError):
    count = 0
state["tasks_completed"] = count + 1

tmp = state_path + ".tmp"
with open(tmp, "w") as f:
    yaml.safe_dump(state, f, default_flow_style=False, sort_keys=False)

import os
os.replace(tmp, state_path)
PY
}

# fw_continuous_note_human_gate <task_id> <gate_class> [project_root]
#
# STOP AND NOTIFY, DO NOT PARK AND TAKE THE NEXT TASK (T-3212, arc-012 IW-5).
#
# The stop-driver already asks the agent, in prose, to stop when it reaches a
# human-owned decision. Nothing enforced it — which is the same shape the driver's
# own header attributes to T-2404: a repair that presumes the very turn it is
# trying to cause. This is that stop, made structural.
#
# Why stop rather than park-and-next: 280+ tasks already sit awaiting operator
# review. A loop that treats a human gate as a routing hint keeps spending budget
# growing a queue nobody is draining, and then ends later on an unrelated cap with
# the real blocker nowhere in the record.
#
# Why record a REASON and not just disarm: `enabled: false` names the flag, not
# what set it. `.stop-driver.log` is 25 consecutive
# `continuous-mode-disabled(enabled=False)` lines, in which "the operator never
# armed it" and "the loop disarmed itself on a gate" are indistinguishable — the
# false-green shape this project keeps finding, one layer up. `last_terminated_reason`
# is what makes the two legible apart; stop-driver.sh reads it back.
#
# Same fail-safe posture as fw_continuous_note_task_completed, for the same reason:
# this runs on the completion path of every task in the project, so every ambiguous
# case is a silent no-op and it must never fail a close.
fw_continuous_note_human_gate() {
    local task_id="$1"
    local gate_class="${2:-human-ac}"
    local root="${3:-${PROJECT_ROOT:-$(pwd)}}"
    local state="${root}/.context/working/.continuous-mode.yaml"

    [ -n "$task_id" ] || return 0
    [ -f "$state" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0

    python3 - "$state" "$task_id" "$gate_class" <<'PY' 2>/dev/null || true
import sys

try:
    import yaml
except ImportError:
    raise SystemExit(0)

state_path, task_id, gate_class = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(state_path) as f:
        state = yaml.safe_load(f)
except Exception:
    raise SystemExit(0)

if not isinstance(state, dict):
    raise SystemExit(0)

# Disarmed means disarmed. An ordinary session hitting a human gate is not a loop
# termination, and recording one would put a termination reason on a run that was
# never running — the inverse of the ambiguity this field exists to remove.
if state.get("enabled") is not True:
    raise SystemExit(0)

import datetime

state["enabled"] = False
state["last_terminated_reason"] = f"human-gate:{gate_class}:{task_id}"
state["terminated_at"] = datetime.datetime.now(
    datetime.timezone.utc
).strftime("%Y-%m-%dT%H:%M:%SZ")

tmp = state_path + ".tmp"
with open(tmp, "w") as f:
    yaml.safe_dump(state, f, default_flow_style=False, sort_keys=False)

import os
os.replace(tmp, state_path)
PY
}

# ---------------------------------------------------------------------------
# fw_continuous_cli <arm|disarm|status> [opts]   — T-3225
#
# The loop shipped disarmed (T-3164, for cause: the flag used to claim armed
# while structurally terminated) and no verb was ever built to arm it again.
# Arming meant hand-editing five fields across TWO files, and the second file
# is the one nobody remembered:
#
#   .continuous-mode.yaml   enabled, current_iteration, last_terminated_reason
#   .next-directive.yaml    filed_at, expires_at   <-- the expiry the driver READS
#
# stop-driver.sh takes expires_at from the DIRECTIVE first (stop-driver.sh:188),
# falling back to state.expires_after_seconds + directive.filed_at. So a run can
# be `enabled: true` and still stop dead on a directive expiry from months ago.
# Both legs are set together here, or not at all.
#
# `status` re-evaluates the predicate chain LIVE. It prints
# last_terminated_reason only as an explicitly-labelled stored string, because
# that is what the driver replays: for 74 days the log read "expires_at
# 2026-06-17 passed (now 2026-08-26)" — a frozen `now`, recited rather than
# computed, which reads as current and is not.
# ---------------------------------------------------------------------------
# T-3254 follow-up. The injector is FRAMEWORK-owned code, not project data, so it is
# resolved from FRAMEWORK_ROOT and only falls back to the project tree.
#
# It used to be "${root}/agents/context/inject-next-directive.py", with root =
# PROJECT_ROOT. That path exists in THIS repo (where the two roots coincide) and
# nowhere else. On any consumer project the import raised FileNotFoundError, which
# `_emit_json` correctly refuses to treat as a green light -- so `may_inject` was
# false forever and the driver could never fire. Fail-safe, and completely inert:
# exactly the shape that passes every test written inside the framework repo.
_cm_injector_path() {
    local proj="${1:-}" c
    for c in "${FRAMEWORK_ROOT:-}" "$proj" "$proj/.agentic-framework"; do
        [ -n "$c" ] || continue
        [ -f "$c/agents/context/inject-next-directive.py" ] || continue
        printf '%s\n' "$c/agents/context/inject-next-directive.py"; return 0
    done
    printf '%s\n' "${FRAMEWORK_ROOT:-$proj}/agents/context/inject-next-directive.py"
}

fw_continuous_cli() {
    local action="${1:-status}"; shift || true
    local root="${PROJECT_ROOT:-$(pwd)}"
    local wdir="$root/.context/working"
    local state="$wdir/.continuous-mode.yaml"
    local directive="$wdir/.next-directive.yaml"
    local halt="${FW_CONTINUOUS_HALT:-$wdir/.continuous-halt}"
    local hours="" iters="" ceiling="" reason="" text="" maxtasks="" json=0

    while [ $# -gt 0 ]; do
        case "$1" in
            --hours) hours="$2"; shift 2 ;;
            --iterations) iters="$2"; shift 2 ;;
            --tier-ceiling) ceiling="$2"; shift 2 ;;
            --max-tasks) maxtasks="$2"; shift 2 ;;
            --reason) reason="$2"; shift 2 ;;
            --directive) text="$2"; shift 2 ;;
            --json) json=1; shift ;;
            *) echo "fw continuous: unknown option '$1'" >&2; return 2 ;;
        esac
    done

    case "$action" in
        arm|disarm|status) ;;
        *) echo "usage: fw continuous <arm|disarm|status> [--hours N] [--iterations N] [--tier-ceiling N] [--max-tasks N] [--directive TEXT] [--reason TEXT]" >&2; return 2 ;;
    esac

    if [ "$action" = "arm" ] && [ -f "$halt" ]; then
        echo "REFUSED: halt file present at $halt" >&2
        echo "  The halt file is Brake 1 and outranks every other vote (stop-driver.sh:81)." >&2
        echo "  Remove it deliberately before arming:  rm $halt" >&2
        return 3
    fi

    FW_CM_ACTION="$action" FW_CM_STATE="$state" FW_CM_DIRECTIVE="$directive" \
    FW_CM_HALT="$halt" FW_CM_HOURS="$hours" FW_CM_ITERS="$iters" \
    FW_CM_CEILING="$ceiling" FW_CM_REASON="$reason" FW_CM_TEXT="$text" \
    FW_CM_MAXTASKS="$maxtasks" FW_CM_JSON="$json" FW_CM_ROOT="$root" \
    FW_CM_INJECTOR="$(_cm_injector_path "$root")" \
    python3 - <<'PYCM'
import os, sys, datetime, tempfile, json
try:
    import yaml
except ImportError:
    print("fw continuous: pyyaml unavailable", file=sys.stderr); sys.exit(4)

act = os.environ["FW_CM_ACTION"]
sp, dp, halt = os.environ["FW_CM_STATE"], os.environ["FW_CM_DIRECTIVE"], os.environ["FW_CM_HALT"]
now = datetime.datetime.now(datetime.timezone.utc)
Z = "%Y-%m-%dT%H:%M:%SZ"

def load(p):
    try:
        with open(p) as f:
            d = yaml.safe_load(f)
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}

def save(p, d):
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p) or ".")
    with os.fdopen(fd, "w") as f:
        yaml.safe_dump(d, f, default_flow_style=False, sort_keys=False)
    os.replace(tmp, p)

def parse_ts(v):
    if v is None: return None
    if isinstance(v, datetime.datetime):
        return v if v.tzinfo else v.replace(tzinfo=datetime.timezone.utc)
    s = str(v).strip()
    if not s: return None
    if s.endswith("Z"): s = s[:-1] + "+00:00"
    try:
        dt = datetime.datetime.fromisoformat(s)
        return dt if dt.tzinfo else dt.replace(tzinfo=datetime.timezone.utc)
    except Exception:
        return None

def as_int(v, fb=None):
    try: return int(v)
    except (TypeError, ValueError): return fb

def verdict(state, directive):
    """Re-run stop-driver.sh's chain, in its real order, against the clock now."""
    if os.path.exists(halt):
        return "STOPPED", f"halt-file present at {halt}"
    if not state:
        return "STOPPED", "state-unreadable-or-empty"
    if state.get("enabled") is not True:
        return "STOPPED", f".continuous-mode.yaml: enabled={state.get('enabled')!r} (not armed)"
    cur = as_int(state.get("current_iteration"), 0) or 0
    mi = as_int(directive.get("max_iterations"), as_int(state.get("max_iterations")))
    if mi is not None and cur + 1 > mi:
        return "STOPPED", f"max_iterations reached ({cur + 1} > {mi})"
    dn = as_int(state.get("tasks_completed"), 0) or 0
    mt = as_int(directive.get("max_tasks"), as_int(state.get("max_tasks")))
    if mt is not None and dn >= mt:
        return "STOPPED", f"max_tasks reached ({dn} >= {mt})"
    exp = parse_ts(directive.get("expires_at"))
    if exp is None:
        secs, filed = as_int(state.get("expires_after_seconds")), parse_ts(directive.get("filed_at"))
        if secs is not None and filed is not None:
            exp = filed + datetime.timedelta(seconds=secs)
    if exp is not None and now > exp:
        age = int((now - exp).total_seconds() // 86400)
        return "STOPPED", f".next-directive.yaml: expires_at {exp.strftime(Z)} lapsed {age}d ago"
    return "ARMED", f"would continue as iteration-{cur + 1}" + (f", expires {exp.strftime(Z)}" if exp else "")

# T-3233 (arc-012 review W1-F2). The enforcer resolves the ceiling DIRECTIVE-FIRST
# at inject-next-directive.py:261 —
#     directive_data.get("tier_ceiling", new_state.get("tier_ceiling"))
# — where new_state starts as CONFIG_DEFAULTS, whose tier_ceiling is 1. `arm` and
# `status` used to print state.get("tier_ceiling", "-") instead, so three numbers
# could disagree with nothing anywhere showing it: the one the operator sets, the
# one the CLI confirms, and the one that actually binds.
#
# Two reachable directions, both measured on this repo:
#   - a directive carrying tier_ceiling: 1 silently TIGHTENS `--tier-ceiling 5`,
#     freezing the loop on the first task with blast-radius 2;
#   - a directive carrying 6 silently WIDENS `--tier-ceiling 1`.
# And with nothing set anywhere, the old code printed "-" — read as "no ceiling" —
# while the enforced value was 1, the strictest possible.
#
# This helper exists so the printed number is produced by the same chain that
# enforces it. It is deliberately NOT a re-typed copy of the enforcer's fallback
# order: keep the two in step, and if the enforcer's precedence ever changes, this
# is the one place to follow it.
CEILING_DEFAULT = 1  # inject-next-directive.py CONFIG_DEFAULTS["tier_ceiling"]

def effective_ceiling(st, dr):
    v = dr.get("tier_ceiling", st.get("tier_ceiling", CEILING_DEFAULT))
    n = as_int(v, None)
    return CEILING_DEFAULT if n is None else n

def effective_max_tasks(st, dr):
    """Same directive-first shape. Returns None when genuinely unset."""
    return as_int(dr.get("max_tasks", st.get("max_tasks")), None)

state, directive = load(sp), load(dp)

# T-3254: the machine-readable form of the SAME verdict the text form prints.
#
# The driver that injects a continuation turn from OUTSIDE the session must refuse
# on exactly the bounds the SessionStart path refuses on. The way to guarantee that
# is not to re-type them in the driver -- it is to have ONE evaluator and give it a
# second output shape. `verdict()` above is that evaluator; this adds the shape.
#
# It also carries the two conditions `verdict()` does not reach, so a caller sees
# all six in one place:
#   - `terminated`: a recorded death. T-3167 makes a terminating write also disarm,
#     so this is strictly narrower than `enabled` and never disagrees with it -- but
#     it is reported separately because "never armed" and "armed, then stopped" mean
#     opposite things to whoever reads the refusal.
#   - `ceiling_breached`: needs the planned next action AND its blast-radius, which
#     is the injector's join, so the injector's own functions are imported rather
#     than reimplemented. An unresolvable radius is NOT a breach (the enforcer's own
#     `is not None` semantics) and is reported as null, so it stays distinguishable
#     from a measured zero.
def _emit_json(state, directive):
    st, why = verdict(state, directive)
    blockers = []
    if os.path.exists(halt):
        blockers.append("halt-file present at %s" % halt)
    if state.get("enabled") is not True:
        blockers.append("enabled=%r (not armed)" % state.get("enabled"))
    stored = state.get("last_terminated_reason")
    stored = stored.strip() if isinstance(stored, str) and stored.strip() else None
    if stored:
        blockers.append("recorded termination: %s" % stored)
    cur = as_int(state.get("current_iteration"), 0) or 0
    mi = as_int(directive.get("max_iterations"), as_int(state.get("max_iterations")))
    if mi is not None and cur + 1 > mi:
        blockers.append("max_iterations reached (%d > %d)" % (cur + 1, mi))
    dn = as_int(state.get("tasks_completed"), 0) or 0
    mt = effective_max_tasks(state, directive)
    if mt is not None and dn >= mt:
        blockers.append("max_tasks reached (%d >= %d)" % (dn, mt))
    exp = parse_ts(directive.get("expires_at"))
    if exp is None:
        secs, filed = as_int(state.get("expires_after_seconds")), parse_ts(directive.get("filed_at"))
        if secs is not None and filed is not None:
            exp = filed + datetime.timedelta(seconds=secs)
    if exp is not None and now > exp:
        blockers.append("expires_at %s lapsed" % exp.strftime(Z))

    ceiling = effective_ceiling(state, directive)
    task_ref, blast, breached = None, None, None
    try:
        import importlib.util, pathlib
        spec = importlib.util.spec_from_file_location("_inj", os.environ.get("FW_CM_INJECTOR", ""))
        inj = importlib.util.module_from_spec(spec); spec.loader.exec_module(inj)
        d_text = directive.get("directive") or ""
        task_ref = directive.get("next_task") or inj.find_task_reference(d_text)
        if task_ref:
            blast = inj.resolve_task_blast_radius(pathlib.Path(os.environ.get("FW_CM_ROOT", ".")), task_ref)
            if blast is not None and blast > ceiling:
                breached = True
                blockers.append("tier ceiling exceeded: %s blast-radius %d > tier_ceiling %d" % (task_ref, blast, ceiling))
            elif blast is not None:
                breached = False
    except Exception as exc:
        # Reported, never swallowed. A caller must be able to tell "no breach" from
        # "the breach could not be evaluated" -- the second is not a green light,
        # and silently treating it as one is how a ceiling stops binding.
        blockers.append("ceiling check unavailable: %s" % exc.__class__.__name__)

    print(json.dumps({
        "status": st,
        "reason": why,
        "may_inject": st == "ARMED" and not blockers,
        "blockers": blockers,
        "enabled": state.get("enabled") is True,
        "terminated": stored,
        "halted": os.path.exists(halt),
        "iteration": cur,
        "max_iterations": mi,
        "tasks_completed": dn,
        "max_tasks": mt,
        "tier_ceiling": ceiling,
        "planned_task": task_ref,
        "planned_blast_radius": blast,
        "ceiling_breached": breached,
        "expires_at": exp.strftime(Z) if exp is not None else None,
        "now": now.strftime(Z),
        "directive": (directive.get("directive") or "").strip() or None,
    }, indent=2))
    sys.exit(0 if (st == "ARMED" and not blockers) else 1)

if act == "status":
    if os.environ.get("FW_CM_JSON") == "1":
        _emit_json(state, directive)
    st, why = verdict(state, directive)
    print(f"Continuous mode: {st}")
    print(f"  Reason (live): {why}")
    blockers = []
    if state.get("enabled") is not True:
        blockers.append(".continuous-mode.yaml: enabled is not true")
    e = parse_ts(directive.get("expires_at"))
    if e is not None and now > e:
        blockers.append(f".next-directive.yaml: expires_at {e.strftime(Z)} lapsed")
    if len(blockers) > 1:
        print("  ALSO blocking (each would stop the loop on its own):")
        for b in blockers:
            print(f"    - {b}")
    print(f"  Iteration: {as_int(state.get('current_iteration'), 0)} / {as_int(directive.get('max_iterations'), as_int(state.get('max_iterations'), '-'))}")
    print(f"  Tier ceiling: {effective_ceiling(state, directive)}")
    _mt = effective_max_tasks(state, directive)
    print(f"  Max tasks: {_mt if _mt is not None else '-'} (completed {as_int(state.get('tasks_completed'), 0)})")
    stored = state.get("last_terminated_reason")
    if isinstance(stored, str) and stored.strip():
        print(f"  (stored last_terminated_reason, NOT re-evaluated: {stored.strip()})")
    sys.exit(0 if st == "ARMED" else 1)

if act == "disarm":
    state["enabled"] = False
    state["last_terminated_reason"] = os.environ.get("FW_CM_REASON") or f"disarmed by operator at {now.strftime(Z)}"
    save(sp, state)
    print("Continuous mode: DISARMED")
    print(f"  Reason: {state['last_terminated_reason']}")
    sys.exit(0)

hours = as_int(os.environ.get("FW_CM_HOURS") or "", 4)
iters = as_int(os.environ.get("FW_CM_ITERS") or "", 3)
if hours is None or iters is None or hours <= 0 or iters <= 0:
    print("REFUSED: --hours and --iterations must be positive integers", file=sys.stderr)
    sys.exit(2)
if hours > 24:
    print(f"REFUSED: --hours {hours} exceeds the 24h ceiling.", file=sys.stderr)
    print("  An unbounded arm is refused, not defaulted.", file=sys.stderr)
    sys.exit(2)

ceiling = as_int(os.environ.get("FW_CM_CEILING") or "", None)
max_tasks = as_int(os.environ.get("FW_CM_MAXTASKS") or "", None)
if os.environ.get("FW_CM_MAXTASKS") and (max_tasks is None or max_tasks <= 0):
    print("REFUSED: --max-tasks must be a positive integer", file=sys.stderr)
    sys.exit(2)

# T-3233 (W1-F3). The injector is a NO-OP without a directive string:
# inject-next-directive.py:232-234 returns (state, "") when `directive` is not a
# non-empty str, and main() returns before write_state(). So arming a project
# whose .next-directive.yaml has no `directive:` key produces a run that restarts
# without advancing and without marching orders — while `arm` prints a confident
# "Bound: N iteration(s)". Refuse rather than arm into that, in the same spirit as
# the --hours ceiling above: an arm that cannot take effect is refused, not
# defaulted.
_existing = directive.get("directive")
_existing = _existing.strip() if isinstance(_existing, str) else ""
_new_text = (os.environ.get("FW_CM_TEXT") or "").strip()
if not (_new_text or _existing):
    print("REFUSED: this arm would carry no directive text.", file=sys.stderr)
    print("  inject-next-directive.py returns before write_state() when the", file=sys.stderr)
    print("  directive is empty, so the loop would restart without advancing", file=sys.stderr)
    print("  the iteration counter and without receiving marching orders.", file=sys.stderr)
    print("", file=sys.stderr)
    print("  Give it one:  fw continuous arm --hours N --iterations N \\", file=sys.stderr)
    print("                  --directive \"what the next session should do\"", file=sys.stderr)
    sys.exit(2)

exp = now + datetime.timedelta(hours=hours)

# ── ORDER IS LOAD-BEARING: directive first, state last (T-3233, W1-F8/W5-F4) ──
#
# save() is atomic per file (mkstemp + os.replace), which reads as transactional
# across the pair. It is not. If the process dies between the two writes — SIGINT,
# ENOSPC on the second mkstemp, EROFS, OOM — one file is committed and the other
# is not, and the ORDER decides which half-state is reachable.
#
#   state first (the old order):  enabled: true  +  the PREVIOUS expires_at.
#       That is the armed-but-instantly-expired state this file's own header
#       promises cannot happen. The loop stops dead on the next turn citing an
#       expiry from months ago, and no output is printed because both confirmation
#       prints come after both saves — the operator sees a killed command, an
#       armed flag, and no reason to suspect the directive.
#
#   directive first (this order): fresh expiry  +  still disarmed.
#       Harmless. Nothing reads the expiry while disarmed; the operator re-runs.
#
# Do not re-sort these two saves to group them with their neighbours.
directive["filed_at"] = now.strftime(Z)
directive["expires_at"] = exp.strftime(Z)
directive["max_iterations"] = iters
if _new_text:
    directive["directive"] = _new_text
directive["filed_by"] = "fw-continuous-arm"

# T-3233 (W1-F2/W1-F4): write the caps to BOTH files, and CLEAR them when the flag
# is absent. The enforcer reads the directive first, so a value left behind by a
# previous run outranks this arm — which is how a run ends on `max_tasks-reached`
# for a ceiling the operator never set and that appears in no output anywhere.
if ceiling is not None:
    directive["tier_ceiling"] = ceiling
else:
    directive.pop("tier_ceiling", None)
if max_tasks is not None:
    directive["max_tasks"] = max_tasks
else:
    directive.pop("max_tasks", None)
save(dp, directive)

state["enabled"] = True
state["current_iteration"] = 0
state["max_iterations"] = iters
state["last_terminated_reason"] = None
state["last_resumed_at"] = now.strftime(Z)
state["tasks_completed"] = 0
# T-3233 (W1-F4): clear the id list in the SAME write that zeroes the counter.
# fw_continuous_note_task_completed short-circuits on `task_id in seen`, so a
# surviving list makes a re-completed task uncountable — len(completed_task_ids)
# and tasks_completed then diverge permanently after the first re-arm, and the id
# list reads as this run's audit trail while containing prior runs' ids.
state["completed_task_ids"] = []
if ceiling is not None:
    state["tier_ceiling"] = ceiling
else:
    state.pop("tier_ceiling", None)
if max_tasks is not None:
    state["max_tasks"] = max_tasks
else:
    state.pop("max_tasks", None)
save(sp, state)

_st2, _dr2 = load(sp), load(dp)
st, why = verdict(_st2, _dr2)
_eff_ceiling = effective_ceiling(_st2, _dr2)
_eff_max_tasks = effective_max_tasks(_st2, _dr2)
print(f"Continuous mode: {st}")
print(f"  Expires: {exp.strftime(Z)} ({hours}h)")
print(f"  Max tasks: {_eff_max_tasks if _eff_max_tasks is not None else 'unset'}")
print(f"  Ceiling: tier {_eff_ceiling}")
print(f"  Sessions: {iters} (advances only across SessionStart)")
# T-3233 (W1-F3): current_iteration has exactly one writer — inject-next-directive
# .py, reached only from post-compact-resume.sh, wired only to SessionStart. The
# Stop hook drives turns INSIDE one session, where no SessionStart fires, so the
# session counter is frozen for the whole run and max_iterations never binds.
# Leading with it read as the operative bound; it is not, so it is listed last.
#
# T-3239 CORRECTION, MEASURED. This line used to name "expiry and max tasks" as the
# two bounds that DO bind a Stop-hook-driven run. Neither can. A live claude -p run
# against the real driver (docs/reports/T-3239-continuous-loop-demo/evidence/
# E2-armed-*) produced exactly ONE decision=continue and then:
#
#   decision=stop reason=stop_hook_active=true (platform runaway guard)
#
# Brake 3a is checked BEFORE the caps (stop-driver.sh:87-101), and Claude Code sets
# stop_hook_active on every stop that follows a hook-driven continuation. So the
# second stop of any run yields there, and expiry / max_tasks are never consulted.
# The driver's own header says "our counter is meant to stop the loop first, leaving
# the vendor's cap as the backstop we did not write" — that intent is not met, and
# stating unreachable bounds as the operative ones is the false-green class this arc
# exists to remove. Whether the cap SHOULD be one turn is a sovereignty decision for
# the operator, not something to quietly widen here; T-3240 carries it.
print("  Binding a Stop-hook-driven run: ONE continuation, then the platform's")
print("  stop_hook_active guard (measured, T-3239). Expiry and max tasks are")
print("  checked after it, so in practice they bound the SESSION count, not turns.")
print(f"  Check:   {why}")
print(f"  Halt at any time:  touch {halt}")
sys.exit(0 if st == "ARMED" else 1)
PYCM
}
