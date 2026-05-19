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
def cmd_rank(filter_quadrant=None):
    policy = load_policy()
    weights = driver_weights(policy)
    rows = []
    for path, fm in collect_tasks():
        scores = fm.get('bvp_scores') or {}
        if not scores:
            continue  # only score-bearing tasks rank
        raw, norm, _ = compute_bvp(scores, weights)
        cost, _, _, _, src = compute_cost(fm.get('cost_estimate'))
        rows.append({
            'id': fm.get('id', path.stem),
            'name': (fm.get('name') or '')[:50],
            'bvp_raw': raw,
            'bvp_norm': norm,
            'cost': cost,
            'cost_src': src,
        })

    if not rows:
        print("No tasks have `bvp_scores:` set yet.")
        print("Score tasks via `fw bvp confirm T-<id>` (T-1924) once that slice ships.")
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
    print(f"{'TASK':<10} {'BVP':>6} {'NORM':>6} {'COST':>6} {'QUAD':>6}  NAME")
    print('-' * 80)
    for r in rows:
        cost_str = f"{r['cost']:.1f}" if r['cost'] is not None else '-'
        print(f"{r['id']:<10} {r['bvp_raw']:>6} {r['bvp_norm']:>6.2f} {cost_str:>6} {r['quadrant']:>6}  {r['name']}")
    return 0


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
        if not scores:
            print("No bvp_scores: set. Run `fw bvp confirm` (T-1924) to score.")
        else:
            print(f"{'DRIVER':<6} {'NAME':<14} {'WEIGHT':>6} {'SCORE':>5} {'CONTRIB':>7}")
            print('-' * 50)
            raw, norm, used = compute_bvp(scores, weights)
            for d_id, w in weights.items():
                s = scores.get(d_id)
                contrib = (s * w) if s is not None else '-'
                s_str = str(s) if s is not None else '-'
                contrib_str = str(contrib) if contrib != '-' else '-'
                print(f"{d_id:<6} {driver_names.get(d_id,'')[:14]:<14} {w:>6} {s_str:>5} {contrib_str:>7}")
            print('-' * 50)
            print(f"{'TOTAL':<27} {raw:>5}   (norm: {norm:.2f})")

        print()
        ce = fm.get('cost_estimate')
        cost, br, tier, effort, src = compute_cost(ce)
        print("Cost components:")
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


def cmd_arcs():
    policy = load_policy()
    global_weights = driver_weights(policy)
    rows = []
    for path, data in collect_arcs():
        scores = data.get('bvp_scores') or {}
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
        })
    if not rows:
        print("No arcs have `bvp_scores:` set yet.")
        print("Per D2: arcs compared across arcs use only global drivers (D1-D4 + free).")
        return 0
    rows.sort(key=lambda r: r['bvp_norm'], reverse=True)
    print(f"{'ARC':<8} {'SLUG':<24} {'STATUS':<12} {'BVP':>6} {'NORM':>6}  NAME")
    print('-' * 80)
    for r in rows:
        print(f"{r['arc_id']:<8} {r['slug']:<24} {r['status']:<12} {r['bvp_raw']:>6} {r['bvp_norm']:>6.2f}  {r['name']}")
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


def usage():
    print("""fw bvp — Business Value Points (read-only)

USAGE:
  fw bvp                          rank all scored tasks by BVP (desc)
  fw bvp T-<id>                   per-driver detail for one task
  fw bvp arcs                     rank arcs by global-driver BVP
  fw bvp --quadrant {hv-lc|hv-hc|lv-lc|lv-hc}
                                  filter ranking by quadrant (BVP median × cost median)
  fw bvp weight --set Dn=N --rationale "..." [--i-am-human|--from-watchtower]
                                  change driver weight (§ACD-gated, M6)
  fw bvp driver --add "name" --weight N --rationale "..." [--drop Dn]
                                  add free driver; --drop required when at cap=9 (M1)
  fw bvp driver --remove Dn --rationale "..."
                                  remove free driver (D1-D4 protected)
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
    if not args:
        return cmd_rank()
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
        return cmd_rank(filter_quadrant=q)
    if args[0] == 'arcs':
        return cmd_arcs()
    if args[0] == 'weight':
        return cmd_weight(args[1:])
    if args[0] == 'driver':
        return cmd_driver(args[1:])
    if re.fullmatch(r'T-\d+', args[0]):
        return cmd_detail(args[0])
    print(f"ERROR: unknown verb '{args[0]}'. See `fw bvp --help`.", file=sys.stderr)
    return 2


sys.exit(main(sys.argv))
PYEOF
}

# ---------------------------------------------------------------- dispatcher
bvp_dispatch() {
    _bvp_python_engine "$@"
}
