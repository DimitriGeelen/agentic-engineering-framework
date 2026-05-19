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


def usage():
    print("""fw bvp — Business Value Points (read-only)

USAGE:
  fw bvp                          rank all scored tasks by BVP (desc)
  fw bvp T-<id>                   per-driver detail for one task
  fw bvp arcs                     rank arcs by global-driver BVP
  fw bvp --quadrant {hv-lc|hv-hc|lv-lc|lv-hc}
                                  filter ranking by quadrant (BVP median × cost median)
  fw bvp --help                   this message

NOTES:
  - Read-only. Mutating verbs (weight/driver/confirm) ship later.
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
