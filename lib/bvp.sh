#!/usr/bin/env bash
# lib/bvp.sh — Business Value Points (BVP) read-only CLI
#
# T-1919 (arc-006, value-prioritisation). T-NEW-4. Read-only verbs:
#   fw bvp                       — rank all tasks by BVP desc
#   fw bvp T-<id>                — per-driver detail for one task
#   fw bvp arcs                  — rank arcs by global-driver BVP
#   fw bvp --quadrant {hv-lc,hv-hc,lv-lc,lv-hc}
#                                — filter ranking by quadrant
#   fw bvp --help                — usage
#
# Source-of-truth files:
#   policy/value-drivers.yaml     — driver weights (T-1917)
#   .tasks/{active,completed}/T-*.md frontmatter `bvp_scores:` / `cost_estimate:`
#   .context/arcs/*.yaml          — arc `scoped_drivers:` / `bvp_scores:`
#
# Cost composite (F8-mechanic): 0.6×blast_radius + 0.3×tier + 0.1×effort.
# Q2 T-shirt fallback when 3-component values absent: S/M/L/XL → 2/4/6/8.
#
# Read-only: NEVER writes to disk. Mutating verbs land in T-1920 (weight/driver).
# Confirmation of proposed scores lands in T-1924 (`fw bvp confirm`).

set -eo pipefail

# Resolved by bin/fw before sourcing.
: "${FRAMEWORK_ROOT:?FRAMEWORK_ROOT must be set by bin/fw}"
: "${PROJECT_ROOT:?PROJECT_ROOT must be set by bin/fw}"

_bvp_python_engine() {
    # Single python entry point — keeps shell glue minimal and the math
    # auditable in one place. Reads stdin args (verb + flags) via env vars
    # and writes table output to stdout.
    python3 - "$@" <<'PYEOF'
import os
import sys
import re
import glob
import statistics
from pathlib import Path

PROJECT_ROOT = Path(os.environ['PROJECT_ROOT'])

try:
    import yaml
except ImportError:
    print("ERROR: python3 yaml module required (pip install pyyaml)", file=sys.stderr)
    sys.exit(2)

# Comment-preserving YAML for mutating writes (T-1920). Falls back to PyYAML
# if ruamel is unavailable — comments are lost but functionality preserved.
try:
    from ruamel.yaml import YAML
    _ruamel_yaml = YAML()
    _ruamel_yaml.preserve_quotes = True
    _ruamel_yaml.indent(mapping=2, sequence=4, offset=2)
    _HAS_RUAMEL = True
except ImportError:
    _HAS_RUAMEL = False


# ----------------------------------------------------------- §ACD agent gate
def acd_gate(verb, args, refusal_hint=""):
    """T-1671 §ACD shape: refuse under $CLAUDECODE=1 unless --i-am-human or
    --from-watchtower. Returns True if allowed, False if refused (and prints
    error). Used by all mutating verbs."""
    if os.environ.get('CLAUDECODE') != '1':
        return True
    if '--i-am-human' in args or '--from-watchtower' in args:
        return True
    print(f"Error: agents must not invoke 'fw bvp {verb}' directly (§ACD, M6).", file=sys.stderr)
    print("", file=sys.stderr)
    print("  You appear to be running inside Claude Code ($CLAUDECODE=1).", file=sys.stderr)
    print("  Weight/driver changes carry policy-edit authority (D8 — sovereignty", file=sys.stderr)
    print("  at policy-edit time) and belong to the human, recorded via Watchtower.", file=sys.stderr)
    print("", file=sys.stderr)
    if refusal_hint:
        print(f"  {refusal_hint}", file=sys.stderr)
        print("", file=sys.stderr)
    print("  Overrides (mirror T-1259 inception-decide / T-1671 arc-close):", file=sys.stderr)
    print("    --i-am-human       human typing into an agent session (rare)", file=sys.stderr)
    print("    --from-watchtower  Flask backend POST", file=sys.stderr)
    return False


def require_rationale(args, min_chars=30):
    """Pulls --rationale value out of args, validates min length. Returns
    (rationale_text, ok). Prints error on failure."""
    if '--rationale' not in args:
        print("Error: --rationale is required.", file=sys.stderr)
        print(f"  Provide ≥{min_chars} chars explaining why (R6 mitigation — thin", file=sys.stderr)
        print("  rationales make weight-history audit useless).", file=sys.stderr)
        return None, False
    idx = args.index('--rationale')
    if idx + 1 >= len(args):
        print("Error: --rationale needs a value.", file=sys.stderr)
        return None, False
    rationale = args[idx + 1]
    if len(rationale) < min_chars:
        print(f"Error: --rationale must be ≥{min_chars} characters (got {len(rationale)}).", file=sys.stderr)
        print(f"  Provided: {rationale!r}", file=sys.stderr)
        return None, False
    return rationale, True


# ------------------------------------------------------ append-only history
HISTORY_PATH = PROJECT_ROOT / '.context' / 'bvp-weight-history.yaml'
AUTO_PROMOTE_LOG = PROJECT_ROOT / '.context' / 'bvp-auto-promote-log.yaml'


def _utc_now():
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')


def history_append(entry):
    """Append-only YAML log of all policy mutations."""
    HISTORY_PATH.parent.mkdir(exist_ok=True)
    if HISTORY_PATH.is_file():
        data = yaml.safe_load(HISTORY_PATH.read_text()) or {'entries': []}
    else:
        data = {'entries': []}
    if 'entries' not in data:
        data['entries'] = []
    data['entries'].append(entry)
    HISTORY_PATH.write_text(yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


# ---------------------------------------------------------------- policy load
def load_policy():
    policy_path = PROJECT_ROOT / 'policy' / 'value-drivers.yaml'
    if not policy_path.is_file():
        print(f"ERROR: policy file not found: {policy_path}", file=sys.stderr)
        print("       Run T-1917 first (or `fw bvp driver --init` once T-1920 ships).", file=sys.stderr)
        sys.exit(2)
    return yaml.safe_load(policy_path.read_text()) or {}


def driver_weights(policy):
    """Returns dict {driver_id: weight}. Protected + free drivers merged."""
    out = {}
    for d in (policy.get('protected_drivers') or []):
        out[d['id']] = int(d['weight'])
    for d in (policy.get('free_drivers') or []):
        out[d['id']] = int(d['weight'])
    return out


# ----------------------------------------------------------- frontmatter scan
_FM_RE = re.compile(r'^---\n(.*?)\n---', re.S)


def parse_frontmatter(path):
    text = path.read_text()
    m = _FM_RE.match(text)
    if not m:
        return None
    try:
        return yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None


def collect_tasks():
    """Yield (path, frontmatter) for all active+completed task files."""
    patterns = [
        PROJECT_ROOT / '.tasks' / 'active' / 'T-*.md',
        PROJECT_ROOT / '.tasks' / 'completed' / 'T-*.md',
    ]
    for pattern in patterns:
        for p in sorted(glob.glob(str(pattern))):
            p = Path(p)
            fm = parse_frontmatter(p)
            if fm is None:
                continue
            yield p, fm


def collect_arcs():
    for p in sorted(glob.glob(str(PROJECT_ROOT / '.context' / 'arcs' / '*.yaml'))):
        try:
            data = yaml.safe_load(Path(p).read_text()) or {}
            yield Path(p), data
        except yaml.YAMLError:
            continue


# -------------------------------------------------------------------- scoring
def compute_bvp(scores, weights):
    """Sum score×weight across drivers present in BOTH scores and weights.

    Returns (raw_bvp, bvp_norm, drivers_used) where bvp_norm is in [0,1]
    against max-possible (5 × sum_of_weights_in_use).
    """
    raw = 0
    weight_sum = 0
    used = []
    for driver_id, weight in weights.items():
        if driver_id in scores:
            score = int(scores[driver_id])
            raw += score * weight
            weight_sum += weight
            used.append(driver_id)
    if weight_sum == 0:
        return 0, 0.0, used
    max_possible = 5 * weight_sum
    norm = raw / max_possible
    return raw, norm, used


# T-shirt fallback per Q2 (handoff §11.5 / artefact §7 M7).
_TSHIRT = {'S': 2, 'M': 4, 'L': 6, 'XL': 8}


def compute_cost(cost_estimate):
    """Return (composite, blast_radius, tier, effort, source).

    source ∈ {'three-component', 'tshirt', 'absent'}.
    composite per F8: 0.6×br + 0.3×tier + 0.1×effort.
    """
    if not cost_estimate or not isinstance(cost_estimate, dict):
        return None, None, None, None, 'absent'
    br = cost_estimate.get('blast_radius')
    tier = cost_estimate.get('tier')
    effort = cost_estimate.get('effort')
    if br is not None and tier is not None and effort is not None:
        composite = 0.6 * float(br) + 0.3 * float(tier) + 0.1 * float(effort)
        return composite, float(br), float(tier), float(effort), 'three-component'
    size = cost_estimate.get('size')
    if size and str(size).upper() in _TSHIRT:
        v = _TSHIRT[str(size).upper()]
        return float(v), None, None, None, 'tshirt'
    return None, None, None, None, 'absent'


def quadrant(bvp_norm, cost, bvp_median, cost_median):
    """Return one of hv-lc / hv-hc / lv-lc / lv-hc or '-' if either missing."""
    if bvp_norm is None or cost is None:
        return '-'
    hv = bvp_norm >= bvp_median
    lc = cost <= cost_median
    return ('hv' if hv else 'lv') + '-' + ('lc' if lc else 'hc')


# --------------------------------------------------------------------- verbs
def cmd_rank(filter_quadrant=None, include_proposed=False):
    """T-1938: --include-proposed opt-in falls back to bvp_scores_proposed:
    for tasks lacking confirmed scores. Sovereignty default is confirmed-only;
    explicit consent is required to fold in advisory inputs."""
    policy = load_policy()
    weights = driver_weights(policy)
    rows = []
    for path, fm in collect_tasks():
        scores = fm.get('bvp_scores') or {}
        source = 'confirmed'
        if not scores:
            if not include_proposed:
                continue  # default: confirmed-only
            proposed = _latest_proposed_scores(fm)
            if not proposed:
                continue
            scores, source = proposed, 'proposed'
        raw, norm, _ = compute_bvp(scores, weights)
        ce = fm.get('cost_estimate')
        # Cost: confirmed first; under --include-proposed, fall back to proposed.
        cost, _, _, _, src = compute_cost(ce)
        if cost is None and include_proposed:
            ce_proposed = _latest_proposed_cost_estimate(fm)
            if ce_proposed:
                cost, _, _, _, src = compute_cost(ce_proposed)
                if src == 'three-component':
                    src = 'three-component-proposed'
        rows.append({
            'id': fm.get('id', path.stem),
            'name': (fm.get('name') or '')[:50],
            'bvp_raw': raw,
            'bvp_norm': norm,
            'cost': cost,
            'cost_src': src,
            'source': source,
        })

    if not rows:
        if include_proposed:
            print("No tasks have `bvp_scores:` or `bvp_scores_proposed:` set yet.")
        else:
            print("No tasks have `bvp_scores:` set yet.")
            print("Score tasks via `fw bvp confirm T-<id> --i-am-human` (Sovereignty boundary, T-1924).")
            print("Or pass `--include-proposed` to see estimator-proposed scores (advisory).")
        return 0

    bvp_vals = [r['bvp_norm'] for r in rows]
    cost_vals = [r['cost'] for r in rows if r['cost'] is not None]
    bvp_median = statistics.median(bvp_vals) if bvp_vals else 0.5
    cost_median = statistics.median(cost_vals) if cost_vals else 4.0
    for r in rows:
        r['quadrant'] = quadrant(r['bvp_norm'], r['cost'], bvp_median, cost_median)

    if filter_quadrant:
        rows = [r for r in rows if r['quadrant'] == filter_quadrant]
        if not rows:
            print(f"No tasks match quadrant {filter_quadrant}.")
            return 0

    rows.sort(key=lambda r: r['bvp_norm'], reverse=True)
    if include_proposed:
        print(f"{'TASK':<10} {'BVP':>5} {'NORM':>6} {'COST':>5} {'QUAD':>6}  {'SOURCE':<10} NAME")
        print('-' * 96)
        for r in rows:
            cost_str = f"{r['cost']:.1f}" if r['cost'] is not None else '-'
            print(f"{r['id']:<10} {r['bvp_raw']:>5} {r['bvp_norm']:>6.2f} {cost_str:>5} {r['quadrant']:>6}  {r['source']:<10} {r['name']}")
    else:
        print(f"{'TASK':<10} {'BVP':>6} {'NORM':>6} {'COST':>6} {'QUAD':>6}  NAME")
        print('-' * 80)
        for r in rows:
            cost_str = f"{r['cost']:.1f}" if r['cost'] is not None else '-'
            print(f"{r['id']:<10} {r['bvp_raw']:>6} {r['bvp_norm']:>6.2f} {cost_str:>6} {r['quadrant']:>6}  {r['name']}")
    return 0


def _latest_proposed_cost_estimate(fm):
    """T-1938 / mirrors web blueprint: pull newest cost_estimate_proposed: entry."""
    proposed = fm.get('cost_estimate_proposed')
    if not proposed or not isinstance(proposed, list):
        return None
    latest = proposed[-1] if isinstance(proposed[-1], dict) else None
    if not latest:
        return None
    ce = latest.get('cost_estimate')
    if not ce or not isinstance(ce, dict):
        return None
    return ce


def cmd_detail(task_id):
    policy = load_policy()
    weights = driver_weights(policy)
    driver_names = {d['id']: d['name'] for d in (policy.get('protected_drivers') or [])}
    for d in (policy.get('free_drivers') or []):
        driver_names[d['id']] = d.get('name', d['id'])

    for path, fm in collect_tasks():
        if fm.get('id') != task_id:
            continue
        print(f"Task:  {task_id}")
        print(f"Name:  {fm.get('name','')}")
        print(f"File:  {path.relative_to(PROJECT_ROOT)}")
        print()
        scores = fm.get('bvp_scores') or {}
        proposed_list = fm.get('bvp_scores_proposed') or []
        proposed_latest = proposed_list[-1] if proposed_list and isinstance(proposed_list[-1], dict) else None
        proposed_scores = (proposed_latest.get('scores') or {}) if proposed_latest else {}

        if not scores and not proposed_scores:
            print("No bvp_scores: set. Run `fw bvp estimate` (T-1922) to propose, then `fw bvp confirm` (T-1924) to score.")
        else:
            label = "CONFIRMED" if scores else "PROPOSED (advisory)"
            display = scores or proposed_scores
            print(f"{label}")
            print(f"{'DRIVER':<6} {'NAME':<14} {'WEIGHT':>6} {'SCORE':>5} {'CONTRIB':>7}")
            print('-' * 50)
            raw, norm, used = compute_bvp(display, weights)
            for d_id, w in weights.items():
                s = display.get(d_id)
                contrib = (s * w) if s is not None else '-'
                s_str = str(s) if s is not None else '-'
                contrib_str = str(contrib) if contrib != '-' else '-'
                print(f"{d_id:<6} {driver_names.get(d_id,'')[:14]:<14} {w:>6} {s_str:>5} {contrib_str:>7}")
            print('-' * 50)
            print(f"{'TOTAL':<27} {raw:>5}   (norm: {norm:.2f})")
            if scores and proposed_scores and proposed_scores != scores:
                # Show estimator's latest take alongside the confirmed scores —
                # surfaces M3 v2-delta candidates (re-confirm with --override).
                delta = max(
                    (abs(int(proposed_scores.get(k, 0)) - int(v)) for k, v in scores.items()),
                    default=0,
                )
                print()
                print(f"PROPOSED (estimator latest, max delta={delta}):  "
                      + " ".join(f"{k}={proposed_scores.get(k, '-')}"
                                 for k in weights))
                ts = proposed_latest.get('ts') if proposed_latest else None
                est = proposed_latest.get('estimator') if proposed_latest else None
                if ts or est:
                    print(f"  ts={ts or '-'}  estimator={est or '-'}")

        print()
        ce = fm.get('cost_estimate')
        cost, br, tier, effort, src = compute_cost(ce)
        cost_source_label = 'CONFIRMED'
        if cost is None:
            # T-1938: fall back to cost_estimate_proposed: when absent (mirrors
            # score block which already does this — fixes sibling drift).
            ce_proposed = _latest_proposed_cost_estimate(fm)
            if ce_proposed:
                cost, br, tier, effort, src = compute_cost(ce_proposed)
                cost_source_label = 'PROPOSED (estimator)'
                ce = ce_proposed
        print(f"Cost components ({cost_source_label}):")
        if src == 'three-component':
            print(f"  blast_radius: {br:.1f}  × 0.6 = {br*0.6:.2f}")
            print(f"  tier:         {tier:.1f}  × 0.3 = {tier*0.3:.2f}")
            print(f"  effort:       {effort:.1f}  × 0.1 = {effort*0.1:.2f}")
            print(f"  composite:    {cost:.2f}")
        elif src == 'tshirt':
            size = ce.get('size')
            print(f"  T-shirt fallback (Q2): size={size} → {cost:.0f}")
            print("  3-component disclosure: blast_radius/tier/effort not yet computable")
        else:
            print("  cost_estimate: absent. Set in task frontmatter to enable ranking.")
        return 0
    print(f"Task {task_id} not found.", file=sys.stderr)
    return 1


# ---------------- T-1937: CLI parity with web /bvp arc rollup ----------------
# Mirrors web/blueprints/bvp.py {_arc_member_tasks, _arc_rolled_up_scores,
# _arc_rolled_up_cost, _latest_proposed_scores}. Kept in sync structurally.
# Adding a column-only feature here — sovereignty boundary unchanged: estimator
# proposals never reach `bvp_scores:`; the rollup only READS those proposals.
def _latest_proposed_scores(fm):
    """Return the latest entry's scores dict from bvp_scores_proposed:, or None."""
    proposed = fm.get('bvp_scores_proposed')
    if not proposed or not isinstance(proposed, list):
        return None
    latest = proposed[-1] if isinstance(proposed[-1], dict) else None
    if not latest:
        return None
    scores = latest.get('scores')
    if not scores or not isinstance(scores, dict):
        return None
    return scores


def _arc_member_tasks(arc_slug, arc_id_str):
    """T-1849 dual-form: tasks bind via arc_id: <slug> OR arc_id: arc-NNN."""
    members = []
    patterns = [
        str(PROJECT_ROOT / '.tasks' / 'active' / 'T-*.md'),
        str(PROJECT_ROOT / '.tasks' / 'completed' / 'T-*.md'),
    ]
    targets = {x for x in (arc_slug, arc_id_str) if x}
    if not targets:
        return members
    for pattern in patterns:
        for p in sorted(glob.glob(pattern)):
            fm = parse_frontmatter(Path(p))
            if not fm:
                continue
            arc_id = fm.get('arc_id')
            if arc_id and str(arc_id) in targets:
                members.append(fm)
    return members


def _arc_rolled_up_scores(members):
    """Mean-aggregate per-driver scores. Sovereignty: any proposed input taints
    mode → derived-proposed (parallel to web blueprint)."""
    if not members:
        return None, ''
    per_driver = {}
    any_proposed = False
    for fm in members:
        confirmed = fm.get('bvp_scores') or {}
        if confirmed and isinstance(confirmed, dict):
            for k, v in confirmed.items():
                if isinstance(v, (int, float)):
                    per_driver.setdefault(k, []).append(int(v))
            continue
        proposed = _latest_proposed_scores(fm)
        if proposed:
            any_proposed = True
            for k, v in proposed.items():
                if isinstance(v, (int, float)):
                    per_driver.setdefault(k, []).append(int(v))
    if not per_driver:
        return None, ''
    scores = {k: round(sum(vs) / len(vs)) for k, vs in per_driver.items()}
    mode = 'derived-proposed' if any_proposed else 'derived-confirmed'
    return scores, mode


def cmd_arcs():
    policy = load_policy()
    global_weights = driver_weights(policy)
    rows = []
    for path, data in collect_arcs():
        scores = data.get('bvp_scores') or {}
        source = ''
        if scores:
            source = 'direct'
        else:
            proposed = _latest_proposed_scores(data)
            if proposed:
                scores, source = proposed, 'direct-proposed'
            else:
                arc_slug = data.get('slug') or path.stem
                arc_id_str = str(data.get('id') or '')
                members = _arc_member_tasks(arc_slug, arc_id_str)
                scores, source = _arc_rolled_up_scores(members)
                if not scores:
                    continue
        raw, norm, _ = compute_bvp(scores, global_weights)
        rows.append({
            'slug': data.get('slug', path.stem),
            'arc_id': data.get('id', '-'),
            'name': (data.get('name') or '')[:40],
            'bvp_raw': raw,
            'bvp_norm': norm,
            'status': data.get('status', '-'),
            'source': source,
        })
    if not rows:
        print("No arcs have `bvp_scores:` set yet (and no constituent-task rollup available).")
        print("Per D2: arcs compared across arcs use only global drivers (D1-D4 + free).")
        return 0
    rows.sort(key=lambda r: r['bvp_norm'], reverse=True)
    print(f"{'ARC':<8} {'SLUG':<24} {'STATUS':<12} {'BVP':>5} {'NORM':>6}  {'SOURCE':<18} NAME")
    print('-' * 96)
    for r in rows:
        print(f"{r['arc_id']:<8} {r['slug']:<24} {r['status']:<12} {r['bvp_raw']:>5} {r['bvp_norm']:>6.2f}  {r['source']:<18} {r['name']}")
    return 0


# ----------------------------------------------------- mutating verbs (T-1920)
def _save_policy_preserving(policy_path, data):
    """Write policy YAML back to disk, preserving comments if ruamel available."""
    if _HAS_RUAMEL:
        with open(policy_path, 'w') as f:
            _ruamel_yaml.dump(data, f)
    else:
        policy_path.write_text(yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


def _load_policy_preserving():
    """Load policy with comment preservation when ruamel available."""
    policy_path = PROJECT_ROOT / 'policy' / 'value-drivers.yaml'
    if not policy_path.is_file():
        print(f"ERROR: policy file not found: {policy_path}", file=sys.stderr)
        sys.exit(2)
    if _HAS_RUAMEL:
        with open(policy_path) as f:
            return policy_path, _ruamel_yaml.load(f)
    return policy_path, yaml.safe_load(policy_path.read_text()) or {}


def cmd_weight(args):
    # Form validation first (rationale + shape), authority gate (§ACD) after.
    # This lets `grep -q "rationale"` and `grep -q "30"` tests pass from an
    # agent session (Verification block in T-1920 — runs under CLAUDECODE=1).
    if '--set' not in args:
        print("Usage: fw bvp weight --set Dn=N --rationale \"...\"", file=sys.stderr)
        return 2
    idx = args.index('--set')
    if idx + 1 >= len(args):
        print("Error: --set needs Dn=N", file=sys.stderr)
        return 2
    spec = args[idx + 1]
    m = re.fullmatch(r'(D\d+|[A-Za-z][A-Za-z0-9_-]*)=(\d+)', spec)
    if not m:
        print(f"Error: invalid --set value {spec!r}; expected Dn=N", file=sys.stderr)
        return 2
    driver_id, new_weight = m.group(1), int(m.group(2))
    if not 0 <= new_weight <= 9:
        print(f"Error: weight {new_weight} out of range (0-9)", file=sys.stderr)
        return 2

    rationale, ok = require_rationale(args)
    if not ok:
        return 2

    if not acd_gate('weight', args,
                    refusal_hint="Correct flow: human runs `bin/fw bvp weight --set Dn=N --rationale \"...\" --i-am-human`"):
        return 1

    policy_path, policy = _load_policy_preserving()
    found = None
    section = None
    for sec_key in ('protected_drivers', 'free_drivers'):
        for d in (policy.get(sec_key) or []):
            if d.get('id') == driver_id:
                found = d
                section = sec_key
                break
        if found:
            break
    if not found:
        print(f"Error: driver '{driver_id}' not found in policy", file=sys.stderr)
        return 1

    old_weight = int(found['weight'])
    if old_weight == new_weight:
        print(f"No change: {driver_id} weight is already {new_weight}.")
        return 0

    found['weight'] = new_weight
    _save_policy_preserving(policy_path, policy)

    history_append({
        'verb': 'weight',
        'driver': driver_id,
        'section': section,
        'from_weight': old_weight,
        'to_weight': new_weight,
        'rationale': rationale,
        'who': os.environ.get('USER', 'unknown'),
        'agent_session': bool(os.environ.get('CLAUDECODE')),
        'ts': _utc_now(),
    })
    print(f"OK: {driver_id} weight {old_weight} → {new_weight}")
    print(f"  Rationale: {rationale}")
    print(f"  History:   .context/bvp-weight-history.yaml")
    return 0


def cmd_driver(args):
    if '--add' in args:
        return _driver_add(args)
    if '--remove' in args:
        return _driver_remove(args)
    print("Usage: fw bvp driver --add \"name\" --weight N --rationale \"...\"", file=sys.stderr)
    print("       fw bvp driver --remove Dn --rationale \"...\" [--drop Dn]", file=sys.stderr)
    return 2


# ---------------------------------------------------------- confirm (T-1924)
def cmd_confirm(args):
    """Move bvp_scores_proposed: → bvp_scores: with confirmed_by/at; clear proposed.

    Sovereignty boundary (F7, D8): only the human confirms. After confirm, the
    estimator's M3 v2-delta logic must skip this task (T-1922 reads bvp_scores
    presence as the "sticky" signal). --override D=N lets the human alter
    individual driver scores at confirm time.

    Form validation precedes §ACD (consistent with T-1920/T-1926).
    """
    if '--help' in args or '-h' in args or not args:
        print("""Usage: fw bvp confirm T-<id> [--override Dn=N]... [--i-am-human|--from-watchtower]

  Moves bvp_scores_proposed: → bvp_scores: on the named task.
  Records confirmed_by (=$USER) and confirmed_at (UTC ISO-8601).
  Clears bvp_scores_proposed: so the estimator's next sweep can re-populate
  per M3 v2-delta semantics.

  Overrides:
    --override Dn=N    set/replace Dn score at confirm time (after proposed
                        baseline). May be repeated for multiple drivers.
    --i-am-human       sovereignty override for §ACD gate (T-1671 shape)
    --from-watchtower  Flask backend POST

  Refuses under $CLAUDECODE=1 unless --i-am-human or --from-watchtower.

  Note: confirm has NO effect if the task has no bvp_scores_proposed: AND no
  --override flags — there's nothing to write. In that case, propose first
  (T-1922 estimator) or supply --override values directly.
""")
        return 0

    # Pull target task id.
    task_id = None
    for a in args:
        if re.fullmatch(r'T-\d+', a):
            task_id = a
            break
    if not task_id:
        print("Error: fw bvp confirm requires a task id (T-NNN).", file=sys.stderr)
        return 2

    # Pull --override Dn=N pairs (may repeat).
    overrides = {}
    i = 0
    while i < len(args):
        if args[i] == '--override':
            if i + 1 >= len(args):
                print("Error: --override needs Dn=N", file=sys.stderr)
                return 2
            spec = args[i + 1]
            m = re.fullmatch(r'(D\d+|F\d+|[A-Za-z][A-Za-z0-9_-]*)=(\d+)', spec)
            if not m:
                print(f"Error: invalid --override value {spec!r}; expected Dn=N", file=sys.stderr)
                return 2
            score = int(m.group(2))
            if not 0 <= score <= 5:
                print(f"Error: score {score} out of range (0-5)", file=sys.stderr)
                return 2
            overrides[m.group(1)] = score
            i += 2
            continue
        i += 1

    # §ACD gate fires AFTER form parse (task id + overrides shape) but BEFORE
    # filesystem lookup. Reason: sovereignty check should not depend on whether
    # the target exists (typo'd task id under CLAUDECODE=1 must still surface
    # the §ACD refusal). Different ordering from cmd_weight (where rationale
    # validation precedes §ACD) — confirm has no comparable "form" check that
    # benefits from running first.
    if not acd_gate('confirm', args,
                    refusal_hint="Correct flow: human reviews proposed scores in Watchtower or runs `fw bvp confirm T-<id> --i-am-human`"):
        return 1

    # Locate task file.
    matches = []
    for sub in ('active', 'completed'):
        for p in (PROJECT_ROOT / '.tasks' / sub).glob(f'{task_id}-*.md'):
            matches.append(p)
    if not matches:
        print(f"Error: task {task_id} not found.", file=sys.stderr)
        return 1
    task_path = matches[0]

    # Read frontmatter via ruamel for preservation, fall back to PyYAML.
    if _HAS_RUAMEL:
        with open(task_path) as fh:
            raw = fh.read()
    else:
        raw = task_path.read_text()
    m = _FM_RE.match(raw)
    if not m:
        print(f"Error: task file {task_path} has no frontmatter.", file=sys.stderr)
        return 1
    fm_text = m.group(1)

    if _HAS_RUAMEL:
        from io import StringIO
        fm = _ruamel_yaml.load(fm_text)
    else:
        fm = yaml.safe_load(fm_text)

    proposed = fm.get('bvp_scores_proposed') if fm else None
    if not proposed and not overrides:
        print(f"Nothing to confirm for {task_id}: bvp_scores_proposed: is empty and no --override values supplied.", file=sys.stderr)
        print("Either run the estimator first (T-1922) or supply --override Dn=N flags.", file=sys.stderr)
        return 1

    # Build the confirmed map. Proposed is a list of timestamped entries
    # (per T-1918 schema); take the newest entry's scores dict.
    confirmed = {}
    if proposed:
        latest = proposed[-1] if isinstance(proposed, list) else proposed
        # latest is expected to have a 'scores' key per M3, or be the scores dict directly.
        if isinstance(latest, dict):
            if 'scores' in latest:
                confirmed.update({k: int(v) for k, v in (latest.get('scores') or {}).items()})
            else:
                confirmed.update({k: int(v) for k, v in latest.items() if isinstance(v, (int, float)) and not isinstance(v, bool)})
    confirmed.update(overrides)

    if not confirmed:
        print(f"Error: no scores to write — proposed was non-empty but didn't contain a score map.", file=sys.stderr)
        return 1

    fm['bvp_scores'] = confirmed
    fm['bvp_scores_proposed'] = []  # M3 — cleared; estimator may re-populate next sweep.
    fm['confirmed_by'] = os.environ.get('USER', 'unknown')
    fm['confirmed_at'] = _utc_now()

    # Re-serialise frontmatter + write back.
    if _HAS_RUAMEL:
        buf = StringIO()
        _ruamel_yaml.dump(fm, buf)
        new_fm_text = buf.getvalue().rstrip()
    else:
        new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip()

    new_body = raw[:m.start(1)] + new_fm_text + raw[m.end(1):]
    task_path.write_text(new_body)

    print(f"OK: confirmed bvp_scores for {task_id}")
    print(f"  Scores: {confirmed}")
    if overrides:
        print(f"  Overrides applied: {overrides}")
    print(f"  Confirmed by: {fm['confirmed_by']}  at: {fm['confirmed_at']}")
    print(f"  bvp_scores_proposed: cleared (M3 — estimator may re-propose if next pass diverges by ≥2)")
    return 0


def _driver_add(args):
    if not acd_gate('driver --add', args,
                    refusal_hint="Adding a driver is a policy-edit; the human approves the framing."):
        return 1
    idx = args.index('--add')
    if idx + 1 >= len(args):
        print("Error: --add needs a name", file=sys.stderr)
        return 2
    name = args[idx + 1]
    if '--weight' not in args:
        print("Error: --weight is required", file=sys.stderr)
        return 2
    widx = args.index('--weight')
    try:
        weight = int(args[widx + 1])
    except (IndexError, ValueError):
        print("Error: --weight needs an integer", file=sys.stderr)
        return 2
    if not 0 <= weight <= 9:
        print(f"Error: weight {weight} out of range (0-9)", file=sys.stderr)
        return 2
    rationale, ok = require_rationale(args)
    if not ok:
        return 2

    policy_path, policy = _load_policy_preserving()
    protected = policy.get('protected_drivers') or []
    free = policy.get('free_drivers') or []
    total = len(protected) + len(free)

    drop_id = None
    if '--drop' in args:
        didx = args.index('--drop')
        if didx + 1 >= len(args):
            print("Error: --drop needs a driver id", file=sys.stderr)
            return 2
        drop_id = args[didx + 1]

    # M1: total cap = 9. If at cap, require --drop.
    if total >= 9 and not drop_id:
        print(f"Error: total drivers = {total} (cap = 9). Add-one-drop-one (M1):", file=sys.stderr)
        print("  Provide --drop <existing-free-driver-id> to displace one.", file=sys.stderr)
        return 1

    # Allocate next id like F1, F2, … unless name matches existing slug pattern.
    free_ids = {d['id'] for d in free}
    next_n = 1
    while f'F{next_n}' in free_ids:
        next_n += 1
    new_id = f'F{next_n}'

    if drop_id:
        if drop_id.startswith('D'):
            print(f"Error: cannot drop protected driver {drop_id}", file=sys.stderr)
            return 1
        free = [d for d in free if d.get('id') != drop_id]
        if len(free) == len(policy.get('free_drivers') or []):
            print(f"Error: --drop target {drop_id} not found in free_drivers", file=sys.stderr)
            return 1
        policy['free_drivers'] = free

    new_entry = {'id': new_id, 'name': name, 'weight': weight, 'protected': False, 'rationale': rationale}
    if not policy.get('free_drivers'):
        policy['free_drivers'] = []
    policy['free_drivers'].append(new_entry)

    _save_policy_preserving(policy_path, policy)
    history_append({
        'verb': 'driver_add',
        'driver': new_id,
        'name': name,
        'weight': weight,
        'rationale': rationale,
        'dropped': drop_id,
        'who': os.environ.get('USER', 'unknown'),
        'agent_session': bool(os.environ.get('CLAUDECODE')),
        'ts': _utc_now(),
    })
    if drop_id:
        print(f"OK: added {new_id} '{name}' weight={weight}; dropped {drop_id} (M1 add-one-drop-one)")
    else:
        print(f"OK: added {new_id} '{name}' weight={weight}")
    return 0


def _driver_remove(args):
    # Form validation (protected check + rationale) before §ACD authority gate
    # so verification tests can prove the protected refusal from agent session.
    idx = args.index('--remove')
    if idx + 1 >= len(args):
        print("Error: --remove needs a driver id", file=sys.stderr)
        return 2
    driver_id = args[idx + 1]
    if driver_id in ('D1', 'D2', 'D3', 'D4'):
        print(f"Error: cannot remove protected driver {driver_id}.", file=sys.stderr)
        print("  The Four Constitutional Directives (CLAUDE.md) are immutable in identity.", file=sys.stderr)
        print(f"  To adjust impact, use `fw bvp weight --set {driver_id}=N` instead.", file=sys.stderr)
        return 1
    rationale, ok = require_rationale(args)
    if not ok:
        return 2

    if not acd_gate('driver --remove', args,
                    refusal_hint="Removing a driver is a policy-edit; the human approves the framing."):
        return 1

    policy_path, policy = _load_policy_preserving()
    free = policy.get('free_drivers') or []
    new_free = [d for d in free if d.get('id') != driver_id]
    if len(new_free) == len(free):
        print(f"Error: driver '{driver_id}' not found in free_drivers.", file=sys.stderr)
        return 1
    policy['free_drivers'] = new_free
    _save_policy_preserving(policy_path, policy)
    history_append({
        'verb': 'driver_remove',
        'driver': driver_id,
        'rationale': rationale,
        'who': os.environ.get('USER', 'unknown'),
        'agent_session': bool(os.environ.get('CLAUDECODE')),
        'ts': _utc_now(),
    })
    print(f"OK: removed driver {driver_id}")
    return 0


def _auto_promote_log_event(event):
    """Append a typed event (enable/disable/promotion) to the auto-promote log."""
    AUTO_PROMOTE_LOG.parent.mkdir(exist_ok=True)
    if AUTO_PROMOTE_LOG.is_file():
        data = yaml.safe_load(AUTO_PROMOTE_LOG.read_text()) or {'entries': []}
    else:
        data = {'entries': []}
    if 'entries' not in data:
        data['entries'] = []
    data['entries'].append(event)
    AUTO_PROMOTE_LOG.write_text(yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


def _auto_promote_set_enabled(value, rationale, mechanism_args):
    """Flip auto_promote.enabled in policy. Preserves comments via ruamel."""
    policy_path = PROJECT_ROOT / 'policy' / 'value-drivers.yaml'
    if _HAS_RUAMEL:
        data = _ruamel_yaml.load(policy_path.read_text())
        data['auto_promote']['enabled'] = value
        from io import StringIO
        buf = StringIO()
        _ruamel_yaml.dump(data, buf)
        policy_path.write_text(buf.getvalue())
    else:
        data = yaml.safe_load(policy_path.read_text())
        data['auto_promote']['enabled'] = value
        policy_path.write_text(yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


def _auto_promote_file_review_reminder():
    """File a captured task with revisit_at 30d ahead (R7 mitigation).

    Best-effort — uses bin/fw task create. Returns (task_id, err) tuple.
    """
    from datetime import datetime, timezone, timedelta
    revisit = (datetime.now(timezone.utc) + timedelta(days=30)).date().isoformat()
    import subprocess
    name = f"BVP auto-promote 30-day review (revisit {revisit}, R7 mitigation)"
    desc = (f"R7 (escalation drift) requires the human to revisit auto-promote "
            f"after 30 days of operation. Check the auto-promote log for false "
            f"positives, surprise promotions, and whether the thresholds need "
            f"calibration. Filed automatically by `fw bvp auto-promote --enable`.")
    proc = subprocess.run(
        ['bin/fw', 'task', 'create',
         '--name', name,
         '--description', desc,
         '--type', 'specification',
         '--horizon', 'later',
         '--owner', 'human',
         '--tags', 'bvp,auto-promote,review,r7-mitigation'],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return None, proc.stderr[:300]
    # Try to extract task ID from output
    m = re.search(r'T-\d+', proc.stdout)
    return (m.group(0) if m else None), None


def cmd_auto_promote(args):
    """Promote captured → started-work for tasks meeting bvp_norm and cost thresholds.

    Reads auto_promote.{enabled,bvp_norm_min,cost_max,max_concurrent} from
    policy/value-drivers.yaml. When enabled=false (the SHIP DEFAULT, T-1917),
    this verb is a no-op and prints why.

    Sovereignty boundary (D8): the act of flipping auto_promote.enabled to true
    is §ACD-gated (T-1932 ships the enable verb). This verb itself runs whatever
    policy says — no §ACD here.

    Promotion rules:
      - Status must be `captured` (not started-work / issues / work-completed).
      - bvp_scores: must be CONFIRMED (set by `fw bvp confirm`, T-1924).
        Tasks with only bvp_scores_proposed: do NOT auto-promote — the
        confirmation step is the sovereignty boundary.
      - bvp_norm ≥ bvp_norm_min AND cost ≤ cost_max (both threshold gates).
      - Respects max_concurrent: counts currently-started tasks; promotes only
        up to (max_concurrent − already_started).
      - Candidates sorted by bvp_norm desc, then cost asc.

    R4 detection: every promotion writes a full-disclosure entry to
    .context/bvp-auto-promote-log.yaml with bvp_norm, cost, the three cost
    components (blast_radius, tier, effort), the live thresholds, and the
    decision timestamp. Post-hoc forensics must be able to reconstruct WHY
    each promotion fired without re-running the math.
    """
    # ---- enable/disable verbs (§ACD-gated, T-1932) ---------------------
    if '--enable' in args:
        if not acd_gate('auto-promote --enable', args,
                        refusal_hint="Enabling auto-promote is a policy-edit (D8). Run from Watchtower or pass --i-am-human."):
            return 1
        rationale, ok = require_rationale(args)
        if not ok:
            return 2
        _auto_promote_set_enabled(True, rationale, args)
        _auto_promote_log_event({
            'event': 'enable',
            'ts': _utc_now(),
            'rationale': rationale,
            'actor': os.environ.get('USER', 'unknown'),
            'mechanism': 'fw-bvp-auto-promote-enable',
        })
        # R7 mitigation: file a 30-day review reminder.
        review_id, err = _auto_promote_file_review_reminder()
        if err:
            print(f"WARN: failed to file 30-day review task: {err}", file=sys.stderr)
        else:
            print(f"OK: auto_promote.enabled flipped → true")
            if review_id:
                print(f"  30-day review reminder filed: {review_id} (R7 mitigation)")
            else:
                print(f"  30-day review reminder filed (task ID not parsed from output)")
        return 0

    if '--disable' in args:
        # Disabling is always safe — no rationale, no §ACD (the safety direction).
        _auto_promote_set_enabled(False, None, args)
        _auto_promote_log_event({
            'event': 'disable',
            'ts': _utc_now(),
            'actor': os.environ.get('USER', 'unknown'),
            'mechanism': 'fw-bvp-auto-promote-disable',
        })
        print("OK: auto_promote.enabled flipped → false")
        return 0

    # ---- normal "run a promotion pass" path -----------------------------
    dry_run = '--dry-run' in args

    policy = load_policy()
    ap = policy.get('auto_promote') or {}
    enabled = bool(ap.get('enabled', False))
    bvp_norm_min = float(ap.get('bvp_norm_min', 0.85))
    cost_max = float(ap.get('cost_max', 1))
    max_concurrent = int(ap.get('max_concurrent', 1))

    if not enabled:
        print("Auto-promote disabled (policy/value-drivers.yaml: auto_promote.enabled=false). No-op.")
        print("To enable, run: fw bvp auto-promote --enable (T-1932; §ACD-gated).")
        return 0

    weights = driver_weights(policy)
    if not weights:
        print("ERROR: no drivers in policy — cannot compute bvp_norm.", file=sys.stderr)
        return 2
    max_possible = 5 * sum(weights.values())

    # Count currently started-work tasks (concurrency ceiling).
    started_count = 0
    for path in sorted((PROJECT_ROOT / '.tasks' / 'active').glob('T-*.md')):
        fm = parse_frontmatter(path)
        if fm and fm.get('status') == 'started-work':
            started_count += 1

    headroom = max(0, max_concurrent - started_count)
    if headroom == 0:
        print(f"At max_concurrent ({max_concurrent}): {started_count} task(s) already started-work. No headroom.")
        return 0

    # Build candidate list.
    candidates = []
    for path in sorted((PROJECT_ROOT / '.tasks' / 'active').glob('T-*.md')):
        fm = parse_frontmatter(path)
        if not fm or fm.get('status') != 'captured':
            continue
        scores = fm.get('bvp_scores') or {}
        if not scores:
            continue  # M3 sovereignty boundary: only confirmed scores promote.
        raw_bvp, bvp_norm, _ = compute_bvp(scores, weights)
        cost_estimate = fm.get('cost_estimate') or {}
        composite, br, tier, effort, source = compute_cost(cost_estimate)
        if composite is None:
            continue  # No cost ⇒ can't compare to cost_max safely.
        if bvp_norm < bvp_norm_min or composite > cost_max:
            continue
        candidates.append({
            'task_id': fm.get('id'),
            'path': path,
            'bvp_norm': bvp_norm,
            'cost': composite,
            'blast_radius': br,
            'tier': tier,
            'effort': effort,
            'cost_source': source,
        })

    candidates.sort(key=lambda c: (-c['bvp_norm'], c['cost']))
    to_promote = candidates[:headroom]

    if not to_promote:
        print(f"No HV/LC candidates eligible (thresholds: bvp_norm≥{bvp_norm_min}, cost≤{cost_max}).")
        return 0

    print(f"Auto-promote: {len(to_promote)} candidate(s) (headroom={headroom}, dry_run={dry_run}).")
    for c in to_promote:
        print(f"  {c['task_id']}  bvp_norm={c['bvp_norm']:.3f}  cost={c['cost']:.3f}  (source={c['cost_source']})")

    if dry_run:
        print("--dry-run: no promotion performed, no log entry written.")
        return 0

    import subprocess
    log_entries = []
    for c in to_promote:
        proc = subprocess.run(
            ['bin/fw', 'task', 'update', c['task_id'], '--status', 'started-work'],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            print(f"WARN: failed to promote {c['task_id']}: {proc.stderr[:200]}", file=sys.stderr)
            continue
        log_entries.append({
            'event': 'promotion',
            'task_id': c['task_id'],
            'ts': _utc_now(),
            'bvp_norm': round(c['bvp_norm'], 4),
            'cost': round(c['cost'], 4),
            'cost_components': {
                'blast_radius': c['blast_radius'],
                'tier': c['tier'],
                'effort': c['effort'],
                'source': c['cost_source'],
            },
            'thresholds_at_decision': {
                'bvp_norm_min': bvp_norm_min,
                'cost_max': cost_max,
                'max_concurrent': max_concurrent,
            },
            'mechanism': 'fw-bvp-auto-promote',
        })
        print(f"OK: promoted {c['task_id']} captured → started-work")

    if log_entries:
        AUTO_PROMOTE_LOG.parent.mkdir(exist_ok=True)
        if AUTO_PROMOTE_LOG.is_file():
            data = yaml.safe_load(AUTO_PROMOTE_LOG.read_text()) or {'entries': []}
        else:
            data = {'entries': []}
        if 'entries' not in data:
            data['entries'] = []
        data['entries'].extend(log_entries)
        AUTO_PROMOTE_LOG.write_text(yaml.safe_dump(data, sort_keys=False, default_flow_style=False))
        rel = AUTO_PROMOTE_LOG.relative_to(PROJECT_ROOT)
        print(f"Logged {len(log_entries)} promotion(s) → {rel}")

    return 0


def usage():
    print("""fw bvp — Business Value Points (read-only)

USAGE:
  fw bvp                          rank all confirmed-scored tasks by BVP (desc)
  fw bvp --include-proposed       also rank tasks with estimator-proposed scores
                                  (T-1938; SOURCE column distinguishes confirmed/proposed;
                                  cost falls back to cost_estimate_proposed: too)
  fw bvp T-<id>                   per-driver detail for one task; cost section
                                  falls back to cost_estimate_proposed: when
                                  cost_estimate: is absent (T-1938)
  fw bvp arcs                     rank arcs by global-driver BVP; falls back to
                                  constituent-task rollup when arc lacks direct
                                  scores (T-1937; SOURCE column)
  fw bvp --quadrant {hv-lc|hv-hc|lv-lc|lv-hc}
                                  filter ranking by quadrant (BVP median × cost median);
                                  combine with --include-proposed
  fw bvp weight --set Dn=N --rationale "..." [--i-am-human|--from-watchtower]
                                  change driver weight (§ACD-gated, M6)
  fw bvp driver --add "name" --weight N --rationale "..." [--drop Dn]
                                  add free driver; --drop required when at cap=9 (M1)
  fw bvp driver --remove Dn --rationale "..."
                                  remove free driver (D1-D4 protected)
  fw bvp confirm T-<id> [--override Dn=N]... [--i-am-human|--from-watchtower]
                                  move bvp_scores_proposed → bvp_scores
                                  (sovereignty boundary, F7/D8, §ACD-gated)
  fw bvp estimate T-<id> [--dry-run] [--json]
                                  score a task and write bvp_scores_proposed:
                                  (heuristic v1, NOT sovereignty-bearing)
  fw bvp estimate all [--dry-run] [--limit N] [--statuses ...]
                                  score every task; M3 v2-delta skip applies
  fw bvp estimate determinism T-<id> [--runs N]
                                  R3 regression guard (max delta ≤1)
  fw bvp estimate measure-a3 [--n N] [--output PATH]
                                  A3 latency measurement (mean <5s SLA)
  fw bvp auto-promote [--dry-run]
                                  promote captured → started-work for HV/LC
                                  tasks (off by default; reads policy
                                  auto_promote.*; M5 thresholds; T-1931)
  fw bvp auto-promote --enable --rationale "..." [--i-am-human|--from-watchtower]
                                  flip auto_promote.enabled true (§ACD, D8)
                                  + file 30-day R7 review task (T-1932)
  fw bvp auto-promote --disable
                                  flip auto_promote.enabled false (always safe)
  fw bvp --help                   this message

NOTES:
  - Mutating verbs (weight/driver) refuse under $CLAUDECODE=1 unless
    --i-am-human or --from-watchtower (T-1671 §ACD shape). They also require
    --rationale ≥30 chars (R6 mitigation — thin entries make audit useless).
  - All mutations append to .context/bvp-weight-history.yaml (append-only).
  - BVP = Σ score×weight across drivers present in policy/value-drivers.yaml (T-1917).
  - Cost composite (F8): 0.6×blast_radius + 0.3×tier + 0.1×effort.
    T-shirt fallback (Q2): S/M/L/XL → 2/4/6/8 when 3-component values absent.
  - Source: docs/reports/T-1915-bvp-inception.md (arc-006).
""")
    return 0


# --------------------------------------------------------------------- entry
def main(argv):
    args = argv[1:]
    # T-1938: --include-proposed is a positional flag valid for rank surfaces.
    include_proposed = False
    if '--include-proposed' in args:
        include_proposed = True
        args = [a for a in args if a != '--include-proposed']
    if not args:
        return cmd_rank(include_proposed=include_proposed)
    if args[0] in ('--help', '-h', 'help'):
        return usage()
    if args[0] == '--quadrant':
        if len(args) < 2:
            print("ERROR: --quadrant requires a value (hv-lc|hv-hc|lv-lc|lv-hc)", file=sys.stderr)
            return 2
        q = args[1]
        if q not in ('hv-lc', 'hv-hc', 'lv-lc', 'lv-hc'):
            print(f"ERROR: invalid quadrant '{q}'", file=sys.stderr)
            return 2
        return cmd_rank(filter_quadrant=q, include_proposed=include_proposed)
    if args[0] == 'arcs':
        return cmd_arcs()
    if args[0] == 'weight':
        return cmd_weight(args[1:])
    if args[0] == 'driver':
        return cmd_driver(args[1:])
    if args[0] == 'confirm':
        return cmd_confirm(args[1:])
    if args[0] == 'auto-promote':
        return cmd_auto_promote(args[1:])
    if re.fullmatch(r'T-\d+', args[0]):
        return cmd_detail(args[0])
    print(f"ERROR: unknown verb '{args[0]}'. See `fw bvp --help`.", file=sys.stderr)
    return 2


sys.exit(main(sys.argv))
PYEOF
}

# ---------------------------------------------------------------- dispatcher
bvp_dispatch() {
    # T-1922: 'estimate' verb routes to the standalone heuristic worker
    # (agents/termlink/bvp-estimator/estimator.py). Kept out of the
    # in-process Python heredoc because the estimator is a separate
    # concern (writes bvp_scores_proposed:, not read-only math) and the
    # script must also be invokable directly via TermLink convention.
    if [ "${1:-}" = "estimate" ]; then
        shift
        local sub="${1:-}"
        if [ -z "$sub" ] || [ "$sub" = "--help" ] || [ "$sub" = "-h" ]; then
            cat <<'EOF'
fw bvp estimate — score tasks against BVP rubric (writes proposed only)

USAGE:
  fw bvp estimate T-<id> [--dry-run] [--json]
                            score one task; writes bvp_scores_proposed:
                            unless M3 v2-delta says skip
  fw bvp estimate all [--dry-run] [--limit N] [--statuses S1 S2]
                            score every task; --statuses filters by frontmatter
  fw bvp estimate determinism T-<id> [--runs 3]
                            run N times, verify max delta ≤1 (R3)
  fw bvp estimate measure-a3 [--n 20] [--output PATH]
                            A3 measurement: mean/p95 latency on N tasks

NOTES:
  - bvp_scores_proposed: is advisory; confirmed bvp_scores: is set by
    `fw bvp confirm` (§ACD-gated, human authority).
  - Heuristic engine (v1): bit-deterministic, zero token cost, ~10ms/task.
  - Estimator script: agents/termlink/bvp-estimator/estimator.py
EOF
            return 0
        fi
        # Single-task convenience: `fw bvp estimate T-XXX` → `... one T-XXX`
        if echo "$sub" | grep -qE '^T-[0-9]+$'; then
            PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
                python3 "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/estimator.py" one "$@"
            return $?
        fi
        PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
            python3 "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/estimator.py" "$@"
        return $?
    fi
    # T-1935: 'estimate-cost' verb — parallel routing for cost-estimator
    # (writes cost_estimate_proposed: only). Single-task convenience same
    # pattern as 'estimate' above.
    if [ "${1:-}" = "estimate-cost" ]; then
        shift
        local sub="${1:-}"
        if [ -z "$sub" ] || [ "$sub" = "--help" ] || [ "$sub" = "-h" ]; then
            cat <<'EOF'
fw bvp estimate-cost — propose cost_estimate per task (advisory)

USAGE:
  fw bvp estimate-cost T-<id> [--dry-run] [--json]
                            score one task; writes cost_estimate_proposed:
                            (blast_radius/tier/effort) unless v2-delta skip
  fw bvp estimate-cost all [--dry-run] [--limit N] [--statuses S1 S2]
                            score every task
  fw bvp estimate-cost sweep [--stale-hours 24] [--statuses S1 S2] [--cron]
                            periodic sweep — re-score stale or unscored
  fw bvp estimate-cost determinism T-<id> [--runs 10]
                            R3 contract check: 10 runs delta=0

NOTES:
  - cost_estimate_proposed: is advisory; confirmed cost_estimate: is set
    by the human via `fw bvp confirm-cost` (future work).
  - Heuristic v1: blast_radius from components: count; tier from tags
    (tier-N) or workflow_type; effort from body line count + AC count.
  - Estimator script: agents/termlink/bvp-estimator/estimator.py
EOF
            return 0
        fi
        # Single-task convenience: `fw bvp estimate-cost T-XXX` → `... cost-one T-XXX`
        if echo "$sub" | grep -qE '^T-[0-9]+$'; then
            PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
                python3 "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/estimator.py" cost-one "$@"
            return $?
        fi
        # Map fw-side verb (sweep / all / determinism) to estimator verbs (cost-sweep / cost-all / cost-determinism)
        case "$sub" in
            sweep|all|determinism)
                shift
                PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
                    python3 "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/estimator.py" "cost-$sub" "$@"
                return $?
                ;;
            cost-*)
                # Allow direct passthrough for power users
                PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
                    python3 "$FRAMEWORK_ROOT/agents/termlink/bvp-estimator/estimator.py" "$@"
                return $?
                ;;
        esac
        echo "ERROR: unknown estimate-cost subverb: $sub" >&2
        echo "Try: fw bvp estimate-cost --help" >&2
        return 2
    fi
    _bvp_python_engine "$@"
}
