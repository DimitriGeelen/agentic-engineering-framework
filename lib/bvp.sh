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
# T-2230 (T-2229 Slice 1): FRAMEWORK_ROOT exposed so `fw bvp driver --init` can
# locate the canonical template `<FRAMEWORK_ROOT>/policy/value-drivers.yaml`
# when bootstrapping the consumer's own copy at PROJECT_ROOT.
FRAMEWORK_ROOT = Path(os.environ.get('FRAMEWORK_ROOT', os.environ.get('PROJECT_ROOT', '.')))

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


def _atomic_write_text(path, text):
    """T-100191: same-dir temp + os.replace — a kill mid-write must not truncate
    durable state (L-493 non-atomic-YAML-write class)."""
    tmp = Path(str(path) + '.tmp')
    tmp.write_text(text)
    os.replace(tmp, path)


def _str_safe_load(text):
    """PyYAML safe_load with the implicit timestamp resolver removed, so unquoted
    ISO `2026-06-02T00:00:00Z` datetimes round-trip as strings instead of being
    parsed to a datetime and re-emitted as `2026-06-02 00:00:00+00:00` (which
    churns task frontmatter and breaks `...Z`-expecting readers). Used ONLY on the
    no-ruamel fallback path — ruamel round-trip already preserves them.
    Origin: OBS-085 / L-495 (the integrate.py:_str_loader fix, shared here)."""
    class _L(yaml.SafeLoader):
        pass
    _L.yaml_implicit_resolvers = {
        ch: [(t, rx) for t, rx in res if t != 'tag:yaml.org,2002:timestamp']
        for ch, res in yaml.SafeLoader.yaml_implicit_resolvers.items()
    }
    return yaml.load(text, Loader=_L)


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
PROPOSALS_PATH = PROJECT_ROOT / '.context' / 'bvp-driver-proposals.jsonl'


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
    _atomic_write_text(HISTORY_PATH, yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


# ---------------------------------------------------------------- policy load
def load_policy():
    policy_path = PROJECT_ROOT / 'policy' / 'value-drivers.yaml'
    if not policy_path.is_file():
        print(f"ERROR: policy file not found: {policy_path}", file=sys.stderr)
        print("       Bootstrap with: fw bvp driver --init", file=sys.stderr)
        print("       (idempotent; copies the framework template into this project)", file=sys.stderr)
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


# T-3485: value-axis equality defect. `bvp_norm >= bvp_median` is true AT
# equality, which is harmless while the median sits mid-distribution but
# manufactures a verdict when it doesn't: if the median itself has collapsed
# onto the corpus floor (median == min(bvp_vals)), then by definition at
# least half the corpus is tied at that floor value, and `>=` promotes every
# one of those tied, floor-scoring tasks into `hv`. Measured live: 13/25
# zero-scored tasks, median 0.00, all 13 in hv-lc. Swapping to `>` does not
# repair this — it just moves the same tied mass to `lv`, which is equally
# manufactured (nothing in the corpus becomes newly distinguishable; the
# verdict for the tied mass is still invented, just on the other side).
#
# The repair withholds a verdict for the tied-at-floor mass instead of
# guessing which side it belongs on — same shape as `quadrant()` already
# returning '-' for missing cost/value: absence of a real signal renders "I
# cannot judge this", not a spelled-out bucket. `QUAD_VALUE_WITHHELD` is
# scoped narrowly: it only fires when a task's own value score equals a
# degenerate median (median == corpus floor), so a task genuinely above that
# median is untouched and still classifies normally. On any corpus where the
# median does NOT sit on the floor (the common case), `value_axis_degenerate`
# is False and this function's behaviour is byte-identical to before.
QUAD_VALUE_WITHHELD = 'v-thin'


def value_axis_degenerate(bvp_vals):
    """True when the value-axis median cannot separate the corpus — it sits
    at the distribution's floor, which forces >=50% of the corpus to be tied
    there (T-3485). Median-of-n floor-equality implies at least ceil(n/2)
    values equal that floor: the smallest values determining the median can
    be no smaller than the true minimum, so if they equal it, they ARE it."""
    if not bvp_vals:
        return False
    return statistics.median(bvp_vals) == min(bvp_vals)


def quadrant(bvp_norm, cost, bvp_median, cost_median, degenerate=False):
    """Return one of hv-lc / hv-hc / lv-lc / lv-hc, QUAD_VALUE_WITHHELD for a
    degenerate-median tie, or '-' if either axis is missing."""
    if bvp_norm is None or cost is None:
        return '-'
    if degenerate and bvp_norm == bvp_median:
        return QUAD_VALUE_WITHHELD
    hv = bvp_norm >= bvp_median
    lc = cost <= cost_median
    return ('hv' if hv else 'lv') + '-' + ('lc' if lc else 'hc')


# --------------------------------------------------------------------- verbs
def cmd_rank(filter_quadrant=None, include_proposed=False, include_completed=False):
    """T-1938: --include-proposed opt-in falls back to bvp_scores_proposed:
    for tasks lacking confirmed scores. Sovereignty default is confirmed-only;
    explicit consent is required to fold in advisory inputs.

    T-2223: --include-completed opt-in folds work-completed tasks back into the
    rank. Actionable-only is the default — the surface answers "what should I
    work on next" by default, not "rank everything we have data for". Set the
    flag when running an archival/historical sweep.

    T-2224: the --include-completed gate covers both legs — status-field
    work-completed AND directory-drift (path under .tasks/completed/ with
    stale frontmatter). L-390 cases (tasks moved via `git mv` without status
    update) bypass the status check; the path check catches them. T-2196 was
    the canonical evidence: in completed/, status:started-work, sitting at
    HV-LC #2 one session after T-2223 shipped."""
    policy = load_policy()
    weights = driver_weights(policy)
    rows = []
    for path, fm in collect_tasks():
        # T-2223 + T-2224: skip work-completed rows by default so the rank lists
        # actionable tasks only. Two legs:
        #   - status field == 'work-completed' (T-2223): canonical case
        #   - path under .tasks/completed/ (T-2224): L-390 drift case where
        #     status field was not updated when the file was moved
        # Either condition triggers the skip when --include-completed is unset.
        if not include_completed and (
            fm.get('status') == 'work-completed'
            or path.parent.name == 'completed'
        ):
            continue
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
    # Medians are taken over KNOWN costs only — an unknown-cost task must not shift
    # the threshold that decides everyone else's quadrant (T-3068).
    cost_vals = [r['cost'] for r in rows if r['cost'] is not None]
    bvp_median = statistics.median(bvp_vals) if bvp_vals else 0.5
    cost_median = statistics.median(cost_vals) if cost_vals else 4.0
    # T-3485: degeneracy is a property of the whole distribution, computed once
    # per rank rather than per-row — see value_axis_degenerate() docstring.
    _value_degenerate = value_axis_degenerate(bvp_vals)
    for r in rows:
        r['quadrant'] = quadrant(r['bvp_norm'], r['cost'], bvp_median, cost_median,
                                  degenerate=_value_degenerate)

    # T-3068: say what the ranking could not place, and say it before the table
    # rather than after — a quadrant filter that silently drops most of the corpus
    # reads as complete coverage (CLAUDE.md §no silent caps). The cost axis leans
    # 0.6 on blast_radius, and blast_radius is only derivable once `components:` is
    # resolved, which happens at the work-completed transition — the very status
    # this ranking excludes by default. So a large unknown count here is the
    # expected state, not an anomaly, and the operator needs to see its size to
    # know how much weight the quadrant split can carry.
    _n_total = len(rows)
    _n_unknown = sum(1 for r in rows if r['cost'] is None)
    if _n_unknown:
        _pct = 100.0 * _n_unknown / _n_total if _n_total else 0.0
        print(f"NOTE: {_n_unknown}/{_n_total} task(s) ({_pct:.0f}%) have no known cost "
              f"— blast_radius unmeasured, so no quadrant (COST/QUAD show '-').")
        print(f"      Quadrant thresholds are computed over the {_n_total - _n_unknown} "
              f"task(s) that do have one.")
        print("      Cost becomes measurable once `components:` is resolved; see T-3068.")
        print()

    # T-3485: same disclosure discipline as the cost-unknown NOTE above — a
    # quadrant that silently reclassifies a large tied mass as unplaceable
    # must say so, or the count shift reads as missing tasks rather than a
    # withheld verdict.
    _n_withheld = sum(1 for r in rows if r['quadrant'] == QUAD_VALUE_WITHHELD)
    if _n_withheld:
        print(f"NOTE: {_n_withheld}/{_n_total} task(s) have a value score tied at a "
              f"degenerate median (median sits at the corpus floor, bvp_norm={bvp_median:.2f}) "
              f"— quadrant withheld ('{QUAD_VALUE_WITHHELD}') rather than guessed. See T-3485.")
        print()

    if filter_quadrant:
        rows = [r for r in rows if r['quadrant'] == filter_quadrant]
        if not rows:
            print(f"No tasks match quadrant {filter_quadrant}.")
            if _n_unknown:
                print(f"  ({_n_unknown} of {_n_total} task(s) were unplaceable for want "
                      f"of a cost — that is the likely reason, not an empty quadrant.)")
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


# T-3503: membership is resolved by the CANONICAL helper, not re-derived here.
#
# This function matched `arc_id:` only, so an arc whose members bind via the legacy
# `arc:<slug>` tag yielded zero members — and cmd_arcs() then `continue`d, dropping
# the arc from the ranking entirely. Reported by cashweb-integration-agent
# (agent-chat-arc @1247). The identical copy in web/blueprints/bvp.py carries the
# same fix, so `fw bvp arcs` and Watchtower /bvp cannot disagree.
#
# Delegating rather than adding a fifth regex is the framework's own instruction:
# audit's T-1881 check exists to stop inline membership scans ("Any NEW occurrence
# is silent-corpus #3 in waiting") and its mitigation reads "Migrate to
# lib/arc_membership.{sh,py}". That rail could not have caught THIS site — its
# pattern requires the literal token `grep`, so a Python reinvention is invisible
# to it, which is why it passed while both copies were wrong (OBS-546).
#
# The caches also remove an O(arcs x tasks) blow-up: membership was re-derived per
# arc over the whole corpus, so `fw bvp arcs` did ~20 x 3,484 frontmatter parses
# and exceeded a 300s timeout on this repo. Both indices are now built once.
_ARC_MEMBERSHIP_INDEX = None
_ARC_FM_INDEX = None


def _arc_membership_index():
    """(by_arc_id, by_tag, degraded_reason) from lib/arc_membership.py, cached.

    `degraded_reason` is None on success, else a string: the canonical helper could
    not be loaded and membership has fallen back to `arc_id:`-only. The caller MUST
    surface it. `fw bvp` is a core verb and must not crash, but silently falling
    back to the exact defect being fixed would be worse than crashing.
    """
    global _ARC_MEMBERSHIP_INDEX
    if _ARC_MEMBERSHIP_INDEX is None:
        try:
            lib_dir = str(FRAMEWORK_ROOT / 'lib')
            if lib_dir not in sys.path:
                sys.path.insert(0, lib_dir)
            from arc_membership import scan_tasks_by_arc_membership
            by_id, by_tag = scan_tasks_by_arc_membership(PROJECT_ROOT)
            _ARC_MEMBERSHIP_INDEX = (by_id, by_tag, None)
        except Exception as exc:  # noqa: BLE001 - never break a core verb
            _ARC_MEMBERSHIP_INDEX = ({}, {}, f'{type(exc).__name__}: {exc}')
    return _ARC_MEMBERSHIP_INDEX


def _task_frontmatter_index():
    """{task_id: frontmatter} over the corpus, built once."""
    global _ARC_FM_INDEX
    if _ARC_FM_INDEX is None:
        idx = {}
        for sub in ('active', 'completed'):
            for p in sorted(glob.glob(str(PROJECT_ROOT / '.tasks' / sub / 'T-*.md'))):
                fm = parse_frontmatter(Path(p))
                if fm and fm.get('id'):
                    idx[str(fm['id']).strip()] = fm
        _ARC_FM_INDEX = idx
    return _ARC_FM_INDEX


def arc_membership_degraded():
    """Reason string when membership could not use the canonical union, else None."""
    return _arc_membership_index()[2]


def _arc_member_tasks(arc_slug, arc_id_str):
    """Frontmatter of every task in the arc, by the canonical union.

    T-1849 dual-form (`arc_id: <slug>` or `arc_id: arc-NNN`) UNION the legacy
    `arc:<slug>` tag form (T-3503). Returns [] for an arc that genuinely has no
    members — which the caller renders as zero, never drops.
    """
    targets = {x for x in (arc_slug, arc_id_str) if x}
    if not targets:
        return []
    by_id, by_tag, degraded = _arc_membership_index()
    fm_index = _task_frontmatter_index()

    if degraded:
        # Canonical helper unavailable: arc_id:-only, the pre-T-3503 behaviour,
        # surfaced by the caller via arc_membership_degraded() and never silent.
        return [fm for fm in fm_index.values()
                if fm.get('arc_id') and str(fm['arc_id']).strip() in targets]

    ids = set()
    for key in (arc_slug, arc_id_str):
        if key:
            ids.update(by_id.get(key, []))
    if arc_slug:
        ids.update(by_tag.get(f'arc:{arc_slug}', []))
    return [fm_index[t] for t in sorted(ids) if t in fm_index]


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
                    # T-3503: was `continue`, which DELETED the arc from the table.
                    # That collapsed two different states into one invisible one —
                    # "no members found" and "members found but none scored" — so an
                    # arc missing from the ranking was indistinguishable from an arc
                    # that does not exist, in the table used to choose arcs. Report
                    # which of the two it is; never omit the row.
                    rows.append({
                        'slug': data.get('slug', path.stem),
                        'arc_id': data.get('id', '-'),
                        'name': (data.get('name') or '')[:40],
                        'bvp_raw': None,
                        'bvp_norm': None,
                        'status': data.get('status', '-'),
                        'source': 'no-members' if not members else 'members-unscored',
                    })
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
    # T-3503: unscorable arcs sort LAST and render '-', rather than being dropped or
    # claiming a score of zero. An arc we cannot score is not an arc worth nothing.
    rows.sort(key=lambda r: (r['bvp_norm'] is None, -(r['bvp_norm'] or 0.0)))
    degraded = arc_membership_degraded()
    if degraded:
        print(f"WARNING: arc membership DEGRADED to arc_id:-only — {degraded}")
        print("         Tag-only arcs are under-counted in this table (T-3503).")
    print(f"{'ARC':<8} {'SLUG':<24} {'STATUS':<12} {'BVP':>5} {'NORM':>6}  {'SOURCE':<18} NAME")
    print('-' * 96)
    for r in rows:
        raw = '-' if r['bvp_raw'] is None else f"{r['bvp_raw']:>5}"
        norm = '     -' if r['bvp_norm'] is None else f"{r['bvp_norm']:>6.2f}"
        print(f"{r['arc_id']:<8} {r['slug']:<24} {r['status']:<12} {raw:>5} {norm}  {r['source']:<18} {r['name']}")
    return 0


# ----------------------------------------------------- mutating verbs (T-1920)
def _save_policy_preserving(policy_path, data):
    """Write policy YAML back to disk, preserving comments if ruamel available."""
    if _HAS_RUAMEL:
        from io import StringIO
        buf = StringIO()
        _ruamel_yaml.dump(data, buf)
        _atomic_write_text(policy_path, buf.getvalue())
    else:
        _atomic_write_text(policy_path, yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


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
    # T-2230 (T-2229 Slice 1): --init is the bootstrap path. It does not
    # change policy meaning (just first-writes the template), so it is NOT
    # §ACD-gated — agents bootstrapping a consumer is sovereignty-neutral.
    # Subsequent customisation (weight, --add, --remove) IS sovereignty-bearing
    # and gates appropriately.
    if '--init' in args:
        return _driver_init(args)
    # T-2331 (T-2330 S1): --propose is the NON-Sovereign sibling of --add.
    # Writes a pending row to .context/bvp-driver-proposals.jsonl; the
    # Watchtower /bvp/proposed queue (T-2330 S2) approves via --from-watchtower.
    # Must route before --add — propose has no acd_gate; add does.
    if '--propose' in args:
        return _driver_propose(args)
    # T-3428: the two read-only scoring-spec surfaces. Routed before --add so
    # `--validate-scoring` is never mistaken for an add that forgot a name.
    if '--validate-scoring' in args:
        return _driver_validate_scoring(args)
    if '--explain' in args:
        return _driver_explain(args)
    if '--add' in args:
        return _driver_add(args)
    if '--remove' in args:
        return _driver_remove(args)
    print("Usage: fw bvp driver --init [--force]", file=sys.stderr)
    print("       fw bvp driver --add \"name\" --weight N --rationale \"...\" [--drop Fn --drop-name NAME] [--scoring-file FILE]", file=sys.stderr)
    print("       fw bvp driver --validate-scoring FILE", file=sys.stderr)
    print("       fw bvp driver --explain <driver-id-or-name> T-XXXX [--scoring-file FILE]", file=sys.stderr)
    # `--remove` takes no --drop; the old usage line said it did (same
    # docs↔CLI divergence class as T-3069, fixed here incidentally).
    print("       fw bvp driver --remove Fn --rationale \"...\"", file=sys.stderr)
    print("       fw bvp driver --propose \"name\" --weight N --rationale \"...\" [--drop Fn] [--task T-XXX]", file=sys.stderr)
    return 2


def _driver_init(args):
    """Bootstrap consumer's BVP policy files from the framework templates.

    Copies BOTH `policy/value-drivers.yaml` (driver definitions, T-2229) and
    `policy/bvp-scoring-rubric.md` (estimator's scoring source of truth,
    T-1921). The BVP driver-session bundle (policy/prompts/bvp-driver-session.md
    line 146) refuses to run without BOTH files; T-2259 closes the asymmetric
    leg from T-2252's GO decision.

    Idempotent per-file: each existing target survives unless `--force` is
    given (in which case BOTH are overwritten). NOT §ACD-gated — first-write
    of starter files is not a policy decision; subsequent weight/driver
    mutations are gated separately.

    T-2229 Slice 1 (value-drivers.yaml leg) + T-2259 (rubric.md leg, this
    function). Slice 2 (separate task) wires this into fw init/upgrade/vendor.
    """
    force = '--force' in args
    files = [
        ('policy/value-drivers.yaml',
         FRAMEWORK_ROOT / 'policy' / 'value-drivers.yaml',
         PROJECT_ROOT / 'policy' / 'value-drivers.yaml'),
        ('policy/bvp-scoring-rubric.md',
         FRAMEWORK_ROOT / 'policy' / 'bvp-scoring-rubric.md',
         PROJECT_ROOT / 'policy' / 'bvp-scoring-rubric.md'),
    ]

    # Both templates must exist or the install is broken.
    for label, template, _ in files:
        if not template.is_file():
            print(f"ERROR: framework template not found at {template}", file=sys.stderr)
            print(f"       This indicates a broken framework install (vendored copy", file=sys.stderr)
            print(f"       is missing {label}). Run `fw vendor` or", file=sys.stderr)
            print(f"       reinstall the framework.", file=sys.stderr)
            return 2

    actions = []  # list of (label, "created"|"overwritten"|"already-exists", target)
    for label, template, target in files:
        if target.exists() and not force:
            actions.append((label, 'already-exists', target))
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        action = 'overwritten' if (force and target.exists()) else 'created'
        target.write_bytes(template.read_bytes())
        actions.append((label, action, target))

    for label, action, target in actions:
        if action == 'already-exists':
            print(f"OK: {label} already exists at {target}")
        else:
            print(f"OK: {label} {action} from framework template")
            print(f"  Source: {FRAMEWORK_ROOT / label}")
            print(f"  Target: {target}")

    if any(a == 'already-exists' for _, a, _ in actions):
        print("    (idempotent — use `fw bvp driver --init --force` to overwrite from framework template)")

    print("")
    print("  These are the framework's default BVP drivers (D1-D4 + free drivers)")
    print("  and the scoring rubric. Customise via sovereignty-gated verbs:")
    print("    fw bvp                                    # see current ranking")
    print("    fw bvp weight --set Dn=N --rationale ...  # tune driver weights")
    print("    fw bvp driver --add ... | --remove ...    # add/drop free drivers")
    return 0


# ---------------------------------------------------------- confirm (T-1924)
def cmd_confirm(args):
    """Move bvp_scores_proposed: → bvp_scores: with confirmed_by/at/via; clear proposed.

    Sovereignty boundary (F7, D8) — WAIVED for the identity check by T-3487
    (operator directive, 2026-09-26): the §ACD gate below is opt-in via
    FW_REQUIRE_BVP_CONFIRM_APPROVAL=1, not a hard refusal. After confirm, the
    estimator's M3 v2-delta logic must skip this task (T-1922 reads bvp_scores
    presence as the "sticky" signal). --override D=N lets the caller alter
    individual driver scores at confirm time.

    Form validation precedes §ACD (consistent with T-1920/T-1926).
    """
    if '--help' in args or '-h' in args or not args:
        print("""Usage: fw bvp confirm T-<id> [--override Dn=N]... [--i-am-human|--from-watchtower]

  Moves bvp_scores_proposed: → bvp_scores: on the named task.
  Records confirmed_by (=$USER), confirmed_at (UTC ISO-8601), and
  confirmed_via (agent|human|watchtower — T-3487 provenance).
  Clears bvp_scores_proposed: so the estimator's next sweep can re-populate
  per M3 v2-delta semantics.

  Overrides:
    --override Dn=N    set/replace Dn score at confirm time (after proposed
                        baseline). May be repeated for multiple drivers.
    --i-am-human       sovereignty override for §ACD gate (T-1671 shape)
    --from-watchtower  Flask backend POST

  T-3487 (2026-09-26, operator-authorised sovereignty waiver): the §ACD
  human-approval gate on this verb is now OPT-IN. By default confirm proceeds
  under $CLAUDECODE=1 with no --i-am-human/--from-watchtower (confirmed_via
  records 'agent'). Set FW_REQUIRE_BVP_CONFIRM_APPROVAL=1 to restore the
  original hard refusal.

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
    #
    # T-3487: sovereignty waiver (operator directive, 2026-09-26) — the human-
    # approval gate on THIS verb only is now opt-in via FW_REQUIRE_BVP_CONFIRM_APPROVAL=1
    # (restores the exact acd_gate() refusal below). Default (unset) skips the
    # gate — confirm proceeds under $CLAUDECODE=1 with no --i-am-human/--from-watchtower.
    # acd_gate() itself is untouched; its other 4 call sites (weight, driver --add,
    # driver --remove, auto-promote --enable) are unaffected by this switch.
    if os.environ.get('FW_REQUIRE_BVP_CONFIRM_APPROVAL') == '1':
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
        fm = _str_safe_load(fm_text)

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

    # T-3487: WHO/BY-WHAT-AUTHORITY provenance. confirmed_by/at alone no longer
    # distinguish "a human ran this" from "an agent ran this" now that the §ACD
    # gate is opt-in (FW_REQUIRE_BVP_CONFIRM_APPROVAL) rather than a hard refusal
    # — $USER is the OS user either way. confirmed_via records which of the three
    # legal paths this confirm took.
    if '--from-watchtower' in args:
        confirmed_via = 'watchtower'
    elif '--i-am-human' in args:
        confirmed_via = 'human'
    elif os.environ.get('CLAUDECODE') == '1':
        confirmed_via = 'agent'
    else:
        confirmed_via = 'human'

    fm['bvp_scores'] = confirmed
    fm['bvp_scores_proposed'] = []  # M3 — cleared; estimator may re-populate next sweep.
    fm['confirmed_by'] = os.environ.get('USER', 'unknown')
    fm['confirmed_at'] = _utc_now()
    fm['confirmed_via'] = confirmed_via

    # Re-serialise frontmatter + write back.
    if _HAS_RUAMEL:
        buf = StringIO()
        _ruamel_yaml.dump(fm, buf)
        new_fm_text = buf.getvalue().rstrip()
    else:
        new_fm_text = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).rstrip()

    new_body = raw[:m.start(1)] + new_fm_text + raw[m.end(1):]
    _atomic_write_text(task_path, new_body)

    print(f"OK: confirmed bvp_scores for {task_id}")
    print(f"  Scores: {confirmed}")
    if overrides:
        print(f"  Overrides applied: {overrides}")
    print(f"  Confirmed by: {fm['confirmed_by']}  at: {fm['confirmed_at']}  via: {fm['confirmed_via']}")
    print(f"  bvp_scores_proposed: cleared (M3 — estimator may re-propose if next pass diverges by ≥2)")
    return 0


def _load_estimator():
    """Import agents/termlink/bvp-estimator/estimator.py by path.

    It is a script, not a package, so there is no import statement that
    reaches it. Raises on failure — callers decide whether a tooling fault is
    a refusal (it is not, for _has_scorer) or an error (it is, for the
    scoring-spec verbs, which have nothing to say without it).
    """
    import importlib.util
    est_path = FRAMEWORK_ROOT / 'agents' / 'termlink' / 'bvp-estimator' / 'estimator.py'
    spec = importlib.util.spec_from_file_location('bvp_estimator_for_cli', est_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _has_scorer(driver_id, name, entry=None):
    """T-3427: ask the estimator whether a driver can be scored at all.

    Calls has_scorer(). T-3428 added the `entry` argument: when the caller
    supplied `--scoring-file`, the candidate entry carries a declarative
    `scoring:` block that is not in the policy file yet, and the spec IS the
    answer. If the estimator cannot be imported the answer is unknown, not
    "no": say so on stderr and let the add proceed, because refusing on our
    own tooling fault would be a false block.
    """
    try:
        return bool(_load_estimator().has_scorer(driver_id, name, entry))
    except Exception as exc:  # pragma: no cover - tooling fault, not a verdict
        print(f"WARN: could not consult the estimator for a scorer ({exc}); "
              f"proceeding without the T-3427 check", file=sys.stderr)
        return True


def _read_scoring_file(path_str):
    """Load a `scoring:` spec from a YAML file. Returns (spec, errors).

    Accepts both shapes, because both are what an author writes: a bare spec
    (`kind: signals` at the top level) or a file wrapping it under `scoring:`.
    Guessing between them is safe — `scoring:` is not a valid spec key, so the
    two cannot be confused.
    """
    path = Path(path_str)
    if not path.is_file():
        return None, [f"{path_str}: no such file"]
    try:
        data = yaml.safe_load(path.read_text()) or {}
    except yaml.YAMLError as exc:
        return None, [f"{path_str}: YAML parse error: {exc}"]
    if not isinstance(data, dict):
        return None, [f"{path_str}: top level must be a mapping"]
    spec = data.get('scoring') if isinstance(data.get('scoring'), dict) else data
    try:
        errors = _load_estimator().validate_scoring_spec(spec)
    except Exception as exc:
        return None, [f"could not load the estimator to validate: {exc}"]
    return spec, errors


def _driver_validate_scoring(args):
    """T-3428: `fw bvp driver --validate-scoring <yaml>` — check a spec offline.

    Read-only, so NOT §ACD-gated: validating a file the operator is drafting
    carries no policy authority. Exists so an author finds out a spec is wrong
    BEFORE spending the one free driver slot on it.
    """
    idx = args.index('--validate-scoring')
    if idx + 1 >= len(args):
        print("Error: --validate-scoring needs a YAML file path", file=sys.stderr)
        return 2
    path_str = args[idx + 1]
    spec, errors = _read_scoring_file(path_str)
    if errors:
        print(f"INVALID: {path_str} — {len(errors)} error(s)", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 2
    levels = sorted(int(k) for k in (spec.get('levels') or {}))
    print(f"OK: {path_str} is a valid scoring spec")
    print(f"  kind:           {spec.get('kind')}")
    print(f"  strip_template: {spec.get('strip_template', True)}")
    print(f"  levels:         {', '.join('L' + str(l) for l in levels)}")
    for lvl in levels:
        sigs = spec['levels'][lvl] if lvl in spec['levels'] else spec['levels'][str(lvl)]
        kinds = ', '.join(f"{k}({len(v) if isinstance(v, (list, dict)) else 1})"
                          for k, v in sigs.items())
        print(f"    L{lvl}: {kinds}")
    print("")
    print("  Attach it to a driver with:")
    print(f"    fw bvp driver --add \"<name>\" --weight N --rationale \"...\" --scoring-file {path_str}")
    return 0


def _find_driver_entry(driver_key, task_fm=None):
    """Locate a driver entry by id or name: policy first, then the task's arc.

    Returns (entry, source) or (None, None). Policy wins on collision, the
    same precedence estimate_task() applies when it merges arc-scoped drivers.
    """
    policy = load_policy()
    for section in ('protected_drivers', 'free_drivers'):
        for d in (policy.get(section) or []):
            if not isinstance(d, dict):
                continue
            if driver_key in (d.get('id'), d.get('name')):
                return d, f"policy/value-drivers.yaml ({section})"
    if task_fm:
        try:
            arc_data = _load_estimator()._resolve_arc_data(task_fm) or {}
        except Exception:
            arc_data = {}
        for sd in (arc_data.get('scoped_drivers') or []):
            if not isinstance(sd, dict):
                continue
            if driver_key in (sd.get('id'), sd.get('name')):
                return sd, f".context/arcs/{task_fm.get('arc_id')}.yaml (scoped_drivers)"
    return None, None


def _driver_explain(args):
    """T-3428: `fw bvp driver --explain <driver> <T-XXXX>` — the level ladder.

    Prints, per declared level, which signals matched and which did not, then
    the winning score. Read-only; NOT §ACD-gated. This is the surface that
    makes a declarative driver debuggable — without it an author can see the
    score but not why, which is the same opacity the hardcoded handler table
    had (OBS-463).
    """
    idx = args.index('--explain')
    if idx + 2 >= len(args):
        print("Error: --explain needs <driver-id-or-name> <T-XXXX>", file=sys.stderr)
        return 2
    driver_key, task_id = args[idx + 1], args[idx + 2]
    if not re.fullmatch(r'T-\d+', task_id):
        print(f"Error: {task_id!r} is not a task id (expected T-NNNN)", file=sys.stderr)
        return 2

    matches = list((PROJECT_ROOT / '.tasks' / 'active').glob(f'{task_id}-*.md')) + \
              list((PROJECT_ROOT / '.tasks' / 'completed').glob(f'{task_id}-*.md'))
    if not matches:
        print(f"Error: task {task_id} not found under .tasks/{{active,completed}}/", file=sys.stderr)
        return 2
    task_path = matches[0]

    try:
        est = _load_estimator()
    except Exception as exc:
        print(f"Error: could not load the estimator: {exc}", file=sys.stderr)
        return 1
    fm, body = est.parse_task(task_path)
    tags = list(fm.get('tags') or [])

    entry, source = _find_driver_entry(driver_key, fm)
    if entry is None:
        print(f"Error: driver {driver_key!r} not found in policy or in "
              f"{task_id}'s arc scoped_drivers", file=sys.stderr)
        return 2

    d_id = entry.get('id') or entry.get('name')
    d_name = entry.get('name') or d_id
    print(f"Driver: {d_id} '{d_name}'   weight={entry.get('weight')}")
    print(f"Source: {source}")
    print(f"Task:   {task_id}  ({task_path.name})")
    print("")

    # T-3428: `--scoring-file` lets an author try a DRAFT spec against a real
    # task before spending the one free slot on it — the companion to
    # `--validate-scoring`, which only checks shape. Without it the only way
    # to see what a spec scores is to attach it to live policy first.
    draft = None
    if '--scoring-file' in args:
        sfidx = args.index('--scoring-file')
        if sfidx + 1 >= len(args):
            print("Error: --scoring-file needs a YAML file path", file=sys.stderr)
            return 2
        draft, draft_errors = _read_scoring_file(args[sfidx + 1])
        if draft_errors:
            print(f"Error: --scoring-file {args[sfidx + 1]} is not a valid scoring spec:", file=sys.stderr)
            for e in draft_errors:
                print(f"  - {e}", file=sys.stderr)
            return 2

    spec = draft if draft is not None else est.load_scoring_spec(entry)
    if draft is not None:
        print(f"Spec source: DRAFT {args[args.index('--scoring-file') + 1]} "
              f"(not attached to {d_id}; nothing is written)")
    if spec is None:
        # Not an error: the driver may be scored by a hand-written handler,
        # which is the RICHER mechanism. Say which, so the absence of a spec
        # does not read as a fault.
        if est.has_scorer(d_id, d_name):
            print("No declarative `scoring:` block — this driver is scored by a")
            print("hand-written handler in agents/termlink/bvp-estimator/estimator.py.")
            print(f"Score it with: fw bvp estimate {task_id} --dry-run --json")
            return 0
        print("No declarative `scoring:` block and no handler — this driver is UNSCORED")
        print("(T-3427: omitted from `scores` and left out of the ranking denominator).")
        print("Give it a mechanism: fw bvp driver --validate-scoring <yaml>, then")
        print("re-add with --scoring-file. See policy/value-drivers.yaml header.")
        return 1

    errors = est.validate_scoring_spec(spec)
    if errors:
        print(f"INVALID spec — {len(errors)} error(s); this driver scores as UNSCORED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 2

    strip = spec.get('strip_template', True) is not False
    print(f"Spec: kind={spec.get('kind')}  strip_template={strip}")
    # Dispatch order is handler → alias → spec, so an attached spec on a
    # handler-backed driver is INERT. Say so here rather than let the ladder
    # below read as what the estimator actually did.
    if draft is None and (d_id in est._handler_table() or d_name in est._handler_table()):
        print(f"NOTE: {d_id} also has a hand-written handler, which WINS "
              f"(handler → alias → spec).")
        print("      The ladder below is what the spec would score, not what the "
              "estimator used.")
    ladder = est.declarative_matches(spec, fm, body, tags)
    for lvl in sorted(ladder):
        if ladder[lvl]:
            print(f"  L{lvl}  MATCH   " + "; ".join(ladder[lvl]))
        else:
            print(f"  L{lvl}  -")
    score, evidence = est.score_declarative(spec, fm, body, tags)
    print("")
    print(f"Score: {score}   (highest matching level; 0 = measured no-signal, not unscored)")
    print(f"Evidence: {'; '.join(evidence)}")
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

    # T-3066: --drop names a SLOT; --drop-name names the thing in it. Both are
    # required together, and the pairing is checked against the live register
    # before anything is written (see the drop block below).
    drop_name = None
    if '--drop-name' in args:
        nidx = args.index('--drop-name')
        if nidx + 1 >= len(args):
            print("Error: --drop-name needs a driver name", file=sys.stderr)
            return 2
        drop_name = args[nidx + 1]

    # T-3066: the pairing is REQUIRED, not optional-if-you-remember. A caller
    # that passes only --drop is refused loudly rather than silently skipping
    # the identity check — an optional guard is indistinguishable from an
    # absent one at the call site, which is the L-399 / T-2278 shape this
    # session has already paid for twice (T-3065, T-3069).
    if drop_id and drop_name is None:
        _cur = next((d.get('name') for d in free if d.get('id') == drop_id), None)
        print(f"Error: --drop {drop_id} requires --drop-name <name> (T-3066).", file=sys.stderr)
        print("", file=sys.stderr)
        print("  Driver ids are slots, not names: the allocator reuses the lowest free", file=sys.stderr)
        print("  number, so an id recorded now can denote a different driver later.", file=sys.stderr)
        print("  Naming the driver makes the deletion refuse instead of hitting whatever", file=sys.stderr)
        print("  happens to occupy the slot at apply time.", file=sys.stderr)
        print("", file=sys.stderr)
        if _cur:
            print(f"  {drop_id} currently denotes '{_cur}'. If that is what you mean:", file=sys.stderr)
            print(f"    --drop {drop_id} --drop-name {_cur}", file=sys.stderr)
        else:
            print(f"  {drop_id} denotes nothing in free_drivers right now.", file=sys.stderr)
        return 2

    # T-3066: and the reverse — `--drop-name` alone is a caller who believes they
    # are displacing a driver while nothing is displaced. Found by probing the
    # fix: the stray flag was accepted and the add went through silently.
    if drop_name is not None and not drop_id:
        print(f"Error: --drop-name {drop_name!r} given without --drop <id> (T-3066).", file=sys.stderr)
        print("  Nothing would have been dropped. Both flags travel together.", file=sys.stderr)
        _slot = next((d.get('id') for d in free if d.get('name') == drop_name), None)
        if _slot:
            print(f"    --drop {_slot} --drop-name {drop_name}", file=sys.stderr)
        else:
            print(f"  No free driver is named '{drop_name}'.", file=sys.stderr)
        return 2

    # M1: total cap = 9. If at cap, require --drop.
    if total >= 9 and not drop_id:
        print(f"Error: total drivers = {total} (cap = 9). Add-one-drop-one (M1):", file=sys.stderr)
        print("  Provide --drop <existing-free-driver-id> --drop-name <its-name> to displace one.", file=sys.stderr)
        return 1

    # Allocate next id like F1, F2, … unless name matches existing slug pattern.
    free_ids = {d['id'] for d in free}
    next_n = 1
    while f'F{next_n}' in free_ids:
        next_n += 1
    new_id = f'F{next_n}'

    # T-3428 (OBS-463 leg 2): `--scoring-file` attaches a declarative scoring
    # spec to the new entry. An invalid spec is refused with every error named
    # — writing a broken block would produce a driver that LOOKS scorable in
    # the policy file and is treated as UNSCORED by the estimator, which is the
    # silent-divergence shape this task exists to remove. A valid spec IS a
    # scorer, so it also lifts the T-3427 refusal below without --allow-unscored.
    scoring_spec = None
    if '--scoring-file' in args:
        sfidx = args.index('--scoring-file')
        if sfidx + 1 >= len(args):
            print("Error: --scoring-file needs a YAML file path", file=sys.stderr)
            return 2
        scoring_spec, spec_errors = _read_scoring_file(args[sfidx + 1])
        if spec_errors:
            print(f"Error: --scoring-file {args[sfidx + 1]} is not a valid scoring spec "
                  f"({len(spec_errors)} error(s)) — nothing was written.", file=sys.stderr)
            for e in spec_errors:
                print(f"  - {e}", file=sys.stderr)
            print("", file=sys.stderr)
            print("  Check it in isolation first:", file=sys.stderr)
            print(f"    fw bvp driver --validate-scoring {args[sfidx + 1]}", file=sys.stderr)
            print("  Schema: policy/value-drivers.yaml header, §Declarative scoring specs.", file=sys.stderr)
            return 2

    # T-3427 (OBS-463): a free driver is only a name unless the estimator has a
    # scorer for it — without one it scores 0 on every non-inception task and
    # STILL enters the ranking denominator, so adding it ranks every real task
    # lower. Measured on a consumer (1409-sprind): weight 8, 46/50 tasks at 0,
    # the flagship "rising to #1" was 2×58 vs 2×54 arithmetic. A gated, capped,
    # deliberate verb must not produce that silently. Refuse, name the
    # consequence, and offer the bypass for an operator reserving the slot.
    candidate_entry = {'scoring': scoring_spec} if scoring_spec else None
    unscored = not _has_scorer(new_id, name, candidate_entry)
    if unscored and '--allow-unscored' not in args:
        print(f"Error: '{name}' has no scorer in the estimator (would be {new_id}) — refused (T-3427).", file=sys.stderr)
        print("", file=sys.stderr)
        print("  Scoring is dispatched from a handler table in agents/termlink/bvp-estimator/estimator.py;", file=sys.stderr)
        print("  a driver with no handler scores 0 on every non-inception task, and its weight still", file=sys.stderr)
        print("  enters the normalisation denominator — every real task ranks LOWER for adding it.", file=sys.stderr)
        print("  Prose `rubric:` text alone changes nothing — the estimator does not read it.", file=sys.stderr)
        print("", file=sys.stderr)
        print("  GIVE IT A MECHANISM (T-3428) — a declarative `scoring:` spec needs no framework", file=sys.stderr)
        print("  code change. Draft it, check it, then attach it:", file=sys.stderr)
        print("    fw bvp driver --validate-scoring my-driver-scoring.yaml", file=sys.stderr)
        print(f"    fw bvp driver --add \"{name}\" --weight {weight} --scoring-file my-driver-scoring.yaml ...", file=sys.stderr)
        print("  Schema: policy/value-drivers.yaml header, §Declarative scoring specs.", file=sys.stderr)
        print("", file=sys.stderr)
        print("  To reserve the slot anyway (it will be listed UNSCORED and left out of ranking sums):", file=sys.stderr)
        print(f"    fw bvp driver --add \"{name}\" --weight {weight} --allow-unscored ...", file=sys.stderr)
        return 2

    if drop_id:
        if drop_id.startswith('D'):
            print(f"Error: cannot drop protected driver {drop_id}", file=sys.stderr)
            return 1
        target = next((d for d in free if d.get('id') == drop_id), None)
        if target is None:
            print(f"Error: --drop target {drop_id} not found in free_drivers", file=sys.stderr)
            return 1
        # T-3066 fail-safe: refuse BEFORE any write when the slot's occupant is
        # not the driver the caller named. Fail-safe rather than best-effort
        # because a partial apply here is a silently corrupted Sovereignty
        # boundary: the operator consented to "add X, drop Y" and the register
        # would perform "add X, drop Z".
        current_name = target.get('name')
        if current_name != drop_name:
            # BOTH names on the first line, deliberately. Every consumer that
            # surfaces this refusal shows `err.splitlines()[0]` and nothing else
            # (web/blueprints/bvp.py, both legs), so a first line that named only
            # the proposed driver would tell the operator their approval failed
            # without telling them what the slot now holds — which is the single
            # fact the decision turns on. Widening those renders is open work
            # (T-2219/T-2221); a message that survives truncation does not wait
            # on it.
            print(f"Error: --drop {drop_id} no longer denotes '{drop_name}' — it now denotes "
                  f"'{current_name}'; nothing was changed (T-3066).", file=sys.stderr)
            print("", file=sys.stderr)
            # Padded so the two names line up under each other — the whole point
            # of this message is that the operator can see they differ.
            _label = f"{drop_id} now denotes:"
            print(f"  {'asked to drop:'.ljust(len(_label))} {drop_name}", file=sys.stderr)
            print(f"  {_label} {current_name}", file=sys.stderr)
            print("", file=sys.stderr)
            print("  Nothing was changed. Driver ids are recycled slots — the allocator", file=sys.stderr)
            print("  reuses the lowest free number — so an id captured earlier can point", file=sys.stderr)
            print(f"  at a driver nobody proposed dropping. Deleting '{current_name}' here", file=sys.stderr)
            print("  would apply the operator's consent to the wrong object.", file=sys.stderr)
            print("", file=sys.stderr)
            moved = next((d.get('id') for d in free if d.get('name') == drop_name), None)
            if moved:
                print(f"  '{drop_name}' still exists, now at {moved}. To proceed against it:", file=sys.stderr)
                print(f"    --drop {moved} --drop-name {drop_name}", file=sys.stderr)
            else:
                print(f"  No free driver named '{drop_name}' remains — it is already gone, so", file=sys.stderr)
                print("  the drop is unnecessary. Re-file without --drop (or name a real target).", file=sys.stderr)
            return 1
        free = [d for d in free if d.get('id') != drop_id]
        policy['free_drivers'] = free

    new_entry = {'id': new_id, 'name': name, 'weight': weight, 'protected': False, 'rationale': rationale}
    if scoring_spec:
        new_entry['scoring'] = scoring_spec
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
        'scoring': 'declarative' if scoring_spec else None,
        'dropped': drop_id,
        # T-3066: the slot id alone made the audit log unreadable after any
        # reallocation — "dropped F1" is true of two different deletions.
        'dropped_name': drop_name,
        'who': os.environ.get('USER', 'unknown'),
        'agent_session': bool(os.environ.get('CLAUDECODE')),
        'ts': _utc_now(),
    })
    _flag = ' UNSCORED' if unscored else (' +scoring-spec' if scoring_spec else '')
    if drop_id:
        print(f"OK: added {new_id} '{name}' weight={weight}{_flag}; dropped {drop_id} '{drop_name}' (M1 add-one-drop-one)")
    else:
        print(f"OK: added {new_id} '{name}' weight={weight}{_flag}")
    if scoring_spec:
        print(f"    scoring: declarative spec, levels "
              f"{', '.join('L' + str(l) for l in sorted(int(k) for k in scoring_spec.get('levels') or {}))}")
        print(f"    Explain it on a task: fw bvp driver --explain {new_id} T-XXXX")
    return 0


def _driver_propose(args):
    """T-2331 (T-2330 S1): non-Sovereign propose-queue write.

    Appends a `state: pending` row to .context/bvp-driver-proposals.jsonl.
    NOT §ACD-gated — proposing is the agent's job; the Sovereign click stays
    on the operator's Approve action (T-2330 S2 wires Watchtower /bvp/proposed
    → `fw bvp driver --add --from-watchtower`). Storage is JSONL for
    race-free append (IW-3 dissolved): two agents proposing the same name
    produce two rows, both surface in the queue, operator picks one.

    Storage location (.context/, not policy/) chosen because proposals are
    working state, not live policy — mirrors .context/bvp-weight-history.yaml,
    .context/dispatches.jsonl convention.
    """
    if '--propose' not in args:
        return 2
    idx = args.index('--propose')
    if idx + 1 >= len(args):
        print("Error: --propose needs a driver name", file=sys.stderr)
        return 2
    name = args[idx + 1]

    # Slug shape mirrors the form validator (web/templates/bvp.html: pattern
    # [A-Za-z][A-Za-z0-9_-]*) so propose↔add round-trip is identical.
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]*', name):
        print(f"Error: invalid name {name!r}; must start with letter, then letters/digits/_/-", file=sys.stderr)
        return 2

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

    drop_id = None
    if '--drop' in args:
        didx = args.index('--drop')
        if didx + 1 < len(args):
            drop_id = args[didx + 1]

    # T-3066: resolve the drop target's IDENTITY here, at propose time, and store
    # it next to the slot id. This is the whole fix — the proposal is a sentence
    # the operator will agree to later ("add X, drop Y"), and until now its second
    # clause was resolved after they agreed, against a register that may have moved.
    # A name cannot be reallocated; a slot number can, and ours are (F1/F2/F3 all
    # hold named drivers today).
    drop_name = None
    if drop_id:
        if drop_id.startswith('D'):
            print(f"Error: cannot propose dropping protected driver {drop_id} (D1-D4 are immutable)", file=sys.stderr)
            return 2
        _, _policy = _load_policy_preserving()
        _target = next((d for d in (_policy.get('free_drivers') or [])
                        if d.get('id') == drop_id), None)
        if _target is None:
            print(f"Error: --drop target {drop_id} not found in free_drivers", file=sys.stderr)
            print("  A proposal cannot record an intent that is already unresolvable;", file=sys.stderr)
            print("  `fw bvp` lists the current free drivers and their ids.", file=sys.stderr)
            return 2
        drop_name = _target.get('name')

    task_id = None
    if '--task' in args:
        tidx = args.index('--task')
        if tidx + 1 < len(args):
            task_id = args[tidx + 1]

    import json, uuid
    actor_prefix = 'agent' if os.environ.get('CLAUDECODE') == '1' else 'human'
    entry = {
        'id': f'P-{uuid.uuid4().hex[:8]}',
        'ts': _utc_now(),
        'state': 'pending',
        'name': name,
        'weight': weight,
        'rationale': rationale,
        'drop': drop_id,
        # T-3066: `drop` stays for readability and for the 100 append-only rows
        # that predate this field; `drop_name` is the referent the approval is
        # checked against. Rows with a `drop` but no `drop_name` are legacy and
        # the approve route refuses them rather than guessing.
        'drop_name': drop_name,
        'task': task_id,
        'author': f"{actor_prefix}:{os.environ.get('USER', 'unknown')}",
    }

    PROPOSALS_PATH.parent.mkdir(exist_ok=True)
    with open(PROPOSALS_PATH, 'a') as f:
        f.write(json.dumps(entry) + '\n')

    print(f"OK: proposal {entry['id']} filed — name='{name}' weight={weight} (state: pending)")
    print(f"  Storage: {PROPOSALS_PATH.relative_to(PROJECT_ROOT)}")
    print(f"  Operator approves via Watchtower /approvals (BVP Driver Proposals section, T-2335) or /bvp (T-2332).")
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
    _atomic_write_text(AUTO_PROMOTE_LOG, yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


def _auto_promote_set_enabled(value, rationale, mechanism_args):
    """Flip auto_promote.enabled in policy. Preserves comments via ruamel."""
    policy_path = PROJECT_ROOT / 'policy' / 'value-drivers.yaml'
    if _HAS_RUAMEL:
        data = _ruamel_yaml.load(policy_path.read_text())
        data['auto_promote']['enabled'] = value
        from io import StringIO
        buf = StringIO()
        _ruamel_yaml.dump(data, buf)
        _atomic_write_text(policy_path, buf.getvalue())
    else:
        data = yaml.safe_load(policy_path.read_text())
        data['auto_promote']['enabled'] = value
        _atomic_write_text(policy_path, yaml.safe_dump(data, sort_keys=False, default_flow_style=False))


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
        if fm.get('owner') == 'human':
            continue  # PL-037 (T-2544): owner:human never auto-starts — the human
                      # decides when. Belt-and-suspenders for G2 (T-2541 IW-3): confirming
                      # bvp_scores for ranking must not imply consent to auto-start a
                      # human-owned task (e.g. a BPMN-promoted task, T-2542/T-2543).
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
  fw bvp                          rank actionable confirmed-scored tasks by BVP (desc)
                                  (T-2223: work-completed tasks excluded by default —
                                  the rank answers "what should I work on next")
  fw bvp --include-proposed       also rank tasks with estimator-proposed scores
                                  (T-1938; SOURCE column distinguishes confirmed/proposed;
                                  cost falls back to cost_estimate_proposed: too)
  fw bvp --include-completed      also rank work-completed tasks (T-2223; archival
                                  sweep semantic — opt-in for historical analysis)
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
  fw bvp driver --init [--force]
                                  bootstrap policy/value-drivers.yaml from the framework
                                  template (T-2230, T-2229 Slice 1). Idempotent; --force
                                  overwrites. NOT §ACD-gated (first-write, not policy edit).
  fw bvp driver --add "name" --weight N --rationale "..." [--drop Fn --drop-name NAME]
                                  add free driver; a drop is required at cap=9 (M1), and
                                  --drop-name is required with --drop: ids are recycled
                                  slots, so the deletion is checked against the NAME and
                                  refuses if the slot changed hands (T-3066)
  fw bvp driver --remove Fn --rationale "..."
                                  remove free driver (D1-D4 protected)
  fw bvp driver --add ... --scoring-file FILE
                                  attach a declarative `scoring:` spec to the new driver
                                  (T-3428). A valid spec IS a scorer, so it lifts the
                                  T-3427 no-scorer refusal — no framework code change
                                  needed to make a project or arc driver actually score.
  fw bvp driver --validate-scoring FILE
                                  check a scoring spec offline before spending a slot on
                                  it; prints the level ladder or every validation error
  fw bvp driver --explain <driver-id-or-name> T-XXXX [--scoring-file FILE]
                                  per-level evidence for one driver on one task: which
                                  signals matched at which level, and the winning score.
                                  --scoring-file tries a DRAFT spec against a real task
                                  without attaching it to policy (nothing is written)
  fw bvp estimate-cost T-<id> [--dry-run] [--json]
  fw bvp estimate-cost all|sweep|determinism ...
                                  propose cost_estimate per task (advisory, T-1935).
                                  Populates the COST column this ranking sorts by —
                                  without it every quadrant filter is blind. Was
                                  omitted from this help for its whole existence
                                  (T-3069), which is why the cost half of BVP read
                                  as unbuilt. See `fw bvp estimate-cost --help`.
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

SEE ALSO (driver-session workflow, T-2245/T-2246/T-2250):
  policy/prompts/bvp-driver-session.md
    Keystone prompt for proposing or sharpening a value driver. Three
    workflows: A (batch-propose at arc-draft), B (discover+sharpen),
    C (sharpen named topic). Loaded manually today; CLI loader verbs
    (`fw bvp driver suggest|create|recompute|edit|retire`) are deferred
    per T-2245 IW-3 (operator-only territory until v2 handoff lands).
  policy/prompts/artefact-template.md
    Output shape for the research artefact written to
    docs/reports/T-XXXX-bvp-driver-<slug>.md.
  policy/prompts/bvp-references/
    Sharpening subroutine (R1/R2/O1-O4), tactical conversation moves,
    worked examples (global + arc-scoped), and anti-patterns to avoid.
  CLAUDE.md §Driver Session Prompt Bundle and 040-ValueDrivers.md
    Routing context — when to enter a session and how to navigate
    the bundle.
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
    # T-2223: --include-completed is a positional flag valid for rank surfaces.
    # Default (False) skips work-completed tasks — actionable-only rank.
    include_completed = False
    if '--include-completed' in args:
        include_completed = True
        args = [a for a in args if a != '--include-completed']
    if not args:
        return cmd_rank(include_proposed=include_proposed,
                        include_completed=include_completed)
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
        return cmd_rank(filter_quadrant=q, include_proposed=include_proposed,
                        include_completed=include_completed)
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
    # T-2335: `driver --propose` fires a push notification on success so the
    # operator's channel surfaces the pending Sovereign decision. Bash-layer
    # wrap (not in the Python engine) because fw_notify lives in lib/notify.sh;
    # notify stays fire-and-forget and never affects the propose exit code.
    if [ "${1:-}" = "driver" ]; then
        local _has_propose=0 _a
        for _a in "$@"; do [ "$_a" = "--propose" ] && _has_propose=1; done
        if [ "$_has_propose" -eq 1 ]; then
            local _out _rc
            _out=$(_bvp_python_engine "$@")
            _rc=$?
            [ -n "$_out" ] && printf '%s\n' "$_out"
            if [ "$_rc" -eq 0 ]; then
                if ! type fw_notify >/dev/null 2>&1 && [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
                    # shellcheck disable=SC1091
                    source "$FRAMEWORK_ROOT/lib/notify.sh"
                fi
                if type fw_notify >/dev/null 2>&1; then
                    # Parse the OK line: OK: proposal P-xxx filed — name='X' weight=N (state: pending)
                    local _pid _pname _pweight _ptask="" _wturl
                    _pid=$(printf '%s\n' "$_out" | sed -n "s/^OK: proposal \(P-[a-f0-9]*\) filed.*/\1/p" | head -1)
                    _pname=$(printf '%s\n' "$_out" | sed -n "s/^OK: proposal .*name='\([^']*\)'.*/\1/p" | head -1)
                    _pweight=$(printf '%s\n' "$_out" | sed -n "s/^OK: proposal .*weight=\([0-9]*\).*/\1/p" | head -1)
                    local _seen_task=0
                    for _a in "$@"; do
                        if [ "$_seen_task" -eq 1 ]; then _ptask="$_a"; _seen_task=0; fi
                        [ "$_a" = "--task" ] && _seen_task=1
                    done
                    _wturl=$(type _watchtower_url >/dev/null 2>&1 && _watchtower_url 2>/dev/null || echo "")
                    fw_notify \
                        "BVP driver proposal pending: ${_pname:-?}" \
                        "{type: bvp_proposal_pending, id: ${_pid:-?}, name: ${_pname:-?}, weight: ${_pweight:-?}, task: ${_ptask:-none}}" \
                        "manual" "framework" \
                        "${_wturl:+${_wturl}/approvals#section-bvp-proposals}" \
                        2>/dev/null || true
                fi
            fi
            return $_rc
        fi
    fi
    _bvp_python_engine "$@"
}
