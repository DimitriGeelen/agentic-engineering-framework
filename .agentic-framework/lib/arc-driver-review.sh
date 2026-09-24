#!/usr/bin/env bash
# lib/arc-driver-review.sh — T-3429 (arc-006), D-586.
#
# The external value-driver reviewer. Operator ruling 2026-09-22: arc-scoped
# value drivers are created and added by DEFAULT; the §ACD operator-approval
# step (T-1926, M6/D8) stops being the default path and becomes the override.
# Quality is held here instead — by a check that can be re-run, diffed and
# audited, rather than by a click nobody can reproduce six weeks later.
#
# DELIBERATELY NOT MODEL-BACKED. The verdict has to be identical on every run
# of the same YAML, or the audit rail below it (check_arc_driver_reviewer_record)
# is auditing noise. Three static checks:
#
#   (a) SCORABLE  — the estimator can actually score this driver: a hand-written
#                   handler exists for its id/name, or it carries a `scoring:`
#                   block (inline, or via `scoring_file:` relative to the project
#                   root) that passes the T-3428 validator. Same predicate
#                   lib/bvp-scorability.sh uses, so the reviewer and the audit
#                   rail can never disagree about what "scorable" means.
#   (b) DISTINCT  — the name/id does not duplicate D1-D4, a free_drivers[] entry
#                   in policy/value-drivers.yaml, or an existing scoped_drivers[]
#                   entry on this arc. Case-insensitive, whitespace/punctuation
#                   normalised to hyphens, so "Loop Closure" collides with
#                   "loop-closure".
#   (c) DISTINGUISHES — the rationale is >= 60 chars AND names at least one of
#                   D1-D4 (by id or by name) that it distinguishes itself from.
#                   This is D6 from the T-1925 workflow made mechanical: "this
#                   arc is about reliability" is already D2 and must not pass.
#
# The verdict is written back onto the matching proposed_scoped_drivers[] entry
# as `reviewer: {verdict, checks, ts, reviewer_id}` so it survives the session
# and the audit rail can find it. `--dry-run` writes nothing.
#
#   fw arc review-driver <arc> "<name>" [--dry-run] [--json]
#   fw arc review-driver <arc> --all [--dry-run] [--json]
#
#   rc 0 : every reviewed driver passed all three checks
#   rc 1 : at least one FAIL (or the named driver was not found)
#   rc 2 : usage error / arc not found

FW_ARC_REVIEWER_ID="${FW_ARC_REVIEWER_ID:-static-v1}"

# _arc_driver_review_run <arc_file> <project_root> <selector> <dry_run> <emit>
#   selector : driver name, or the literal "--all"
#   dry_run  : true|false
#   emit     : "human" | "json"
# Prints the report (or JSON) on stdout. rc as above.
_arc_driver_review_run() {
    local arc_file="$1" root="$2" selector="$3" dry_run="$4" emit="$5"
    local fw_root="${FRAMEWORK_ROOT:-$root}"
    local est="$fw_root/agents/termlink/bvp-estimator/estimator.py"
    [ -f "$est" ] || est="$root/agents/termlink/bvp-estimator/estimator.py"

    FW_ARC_REVIEWER_ID="$FW_ARC_REVIEWER_ID" python3 - \
        "$arc_file" "$root" "$est" "$selector" "$dry_run" "$emit" <<'PY'
import datetime, importlib.util, json, os, re, sys
from pathlib import Path

import yaml

arc_file, root, est_path, selector, dry_run, emit = sys.argv[1:7]
root = Path(root)
dry_run = (dry_run == "true")
REVIEWER_ID = os.environ.get("FW_ARC_REVIEWER_ID") or "static-v1"

DIRECTIVE_TOKENS = ["D1", "D2", "D3", "D4",
                    "Antifragility", "Reliability", "Usability", "Portability"]
MIN_RATIONALE = 60


def norm(s):
    """Fold to a comparable key: case, whitespace and punctuation all become
    hyphens, so 'Loop closure (conditional)' == 'loop-closure-conditional'."""
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", str(s or "").lower())).strip("-")


# ── estimator (for check a). Unimportable estimator is reported, not swallowed:
#    a reviewer that silently passes everything is the failure shape this closes.
est = None
est_err = ""
try:
    spec = importlib.util.spec_from_file_location("bvp_estimator_review", est_path)
    est = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(est)
except Exception as e:  # noqa: BLE001 - reported below, never fatal-silent
    est_err = f"{type(e).__name__}: {e}"

# ruamel round-trips comments and key order; arc YAMLs are hand-edited and a
# safe_dump rewrite of one would be a diff nobody asked for. safe_load is the
# fallback, same ladder as lib/arc.sh's approve path.
try:
    from ruamel.yaml import YAML
    _ry = YAML()
    _ry.preserve_quotes = True
    _ry.indent(mapping=2, sequence=4, offset=2)
except ImportError:
    _ry = None

try:
    if _ry is not None:
        with open(arc_file) as _fh:
            arc = _ry.load(_fh) or {}
    else:
        arc = yaml.safe_load(Path(arc_file).read_text()) or {}
except Exception as e:  # noqa: BLE001
    print(f"Error: cannot parse {arc_file}: {e}", file=sys.stderr)
    sys.exit(2)

proposed = [p for p in (arc.get("proposed_scoped_drivers") or []) if isinstance(p, dict)]
scoped = [s for s in (arc.get("scoped_drivers") or []) if isinstance(s, dict)]

try:
    policy = yaml.safe_load((root / "policy" / "value-drivers.yaml").read_text()) or {}
except Exception:
    policy = {}


def check_a(entry):
    """Scorable: handler, inline scoring: spec, or scoring_file: that validates."""
    if est is None:
        return False, f"estimator unimportable, cannot validate a scoring spec ({est_err})"
    d_id = entry.get("id") or entry.get("name")
    d_name = entry.get("name") or d_id
    try:
        table = est._handler_table()
    except Exception as e:  # noqa: BLE001
        return False, f"handler table unreadable ({type(e).__name__}: {e})"
    if d_id in table or d_name in table:
        return True, f"handler exists for '{d_id if d_id in table else d_name}'"
    try:
        alias = est._load_driver_aliases().get(d_id)
    except Exception:
        alias = None
    if alias and alias in table:
        return True, f"alias '{d_id}' -> handler '{alias}'"

    block = est.load_scoring_spec(entry)
    src = "inline scoring:"
    if block is None and entry.get("scoring_file"):
        sf = root / str(entry["scoring_file"])
        src = f"scoring_file: {entry['scoring_file']}"
        if not sf.is_file():
            return False, f"scoring_file: {entry['scoring_file']} does not exist"
        try:
            loaded = yaml.safe_load(sf.read_text()) or {}
        except Exception as e:  # noqa: BLE001
            return False, f"scoring_file: unparseable ({type(e).__name__}: {e})"
        if isinstance(loaded, dict) and isinstance(loaded.get("scoring"), dict):
            block = loaded["scoring"]
        elif isinstance(loaded, dict) and loaded:
            block = loaded
    if block is None:
        return False, "no handler, no inline scoring: block, no scoring_file: (T-3428)"
    errors = est.validate_scoring_spec(block)
    if errors:
        return False, f"{src} does not validate: {errors[0]}"
    return True, f"{src} validates ({len(est._spec_levels(block))} level(s))"


def check_b(entry):
    """Distinct from D1-D4, free drivers, and this arc's existing scoped drivers."""
    keys = {norm(entry.get("name")), norm(entry.get("id"))} - {""}
    if not keys:
        return False, "entry has neither name: nor id:"
    collisions = []
    for d in (policy.get("protected_drivers") or []):
        if not isinstance(d, dict):
            continue
        if keys & {norm(d.get("id")), norm(d.get("name"))}:
            collisions.append(f"constitutional directive {d.get('id')} ({d.get('name')})")
    for d in (policy.get("free_drivers") or []):
        if not isinstance(d, dict):
            continue
        if keys & {norm(d.get("id")), norm(d.get("name"))}:
            collisions.append(f"free driver {d.get('id')} ({d.get('name')})")
    for s in scoped:
        # `is` and not `==`: reviewing an ALREADY-APPROVED driver (the read-only
        # path) must not report it as a duplicate of itself. Identity is the
        # only test that distinguishes "this very entry" from "a second entry
        # that happens to carry the same name", which IS a collision.
        if s is entry:
            continue
        if keys & {norm(s.get("id")), norm(s.get("name"))}:
            collisions.append(f"existing scoped driver '{s.get('name')}' on this arc")
    if collisions:
        return False, "duplicates " + "; ".join(collisions)
    return True, "no collision with D1-D4, free_drivers[] or this arc's scoped_drivers[]"


def check_c(entry):
    """D6: >= 60 chars AND names a directive it distinguishes itself from."""
    r = str(entry.get("rationale") or "").strip()
    if len(r) < MIN_RATIONALE:
        return False, f"rationale is {len(r)} chars, needs >= {MIN_RATIONALE} (D6)"
    low = r.lower()
    named = [t for t in DIRECTIVE_TOKENS if t.lower() in low]
    if not named:
        return False, ("rationale names no directive it distinguishes from "
                       f"(expected one of: {', '.join(DIRECTIVE_TOKENS)})")
    return True, f"{len(r)} chars, distinguishes from {', '.join(named[:3])}"


CHECKS = (("a", "scorable", check_a),
          ("b", "distinct", check_b),
          ("c", "distinguishes", check_c))


def review(entry):
    checks = {}
    ok = True
    for key, label, fn in CHECKS:
        passed, reason = fn(entry)
        checks[key] = {"check": label, "verdict": "pass" if passed else "fail",
                       "reason": reason}
        ok = ok and passed
    ts = datetime.datetime.now(datetime.timezone.utc).isoformat(
        timespec="seconds").replace("+00:00", "Z")
    return {"verdict": "pass" if ok else "fail", "checks": checks,
            "ts": ts, "reviewer_id": REVIEWER_ID}


# ── selection ──
if selector == "--all":
    targets = list(proposed)
    where = "proposed_scoped_drivers"
    if not targets:
        if emit == "json":
            print(json.dumps({"arc": arc.get("id"), "reviewed": [], "verdict": "pass"}))
        else:
            print(f"No proposed scoped drivers on arc '{arc.get('id')}' — nothing to review.")
        sys.exit(0)
else:
    key = norm(selector)
    targets = [p for p in proposed if key in {norm(p.get("name")), norm(p.get("id"))}]
    where = "proposed_scoped_drivers"
    if not targets:
        # An already-approved driver is reviewable too: that is how the six
        # drivers the T-3428 audit names as unscorable get a verdict at all.
        targets = [s for s in scoped if key in {norm(s.get("name")), norm(s.get("id"))}]
        where = "scoped_drivers"
    if not targets:
        # An ad-hoc driver named on the command line has no proposed entry yet
        # (`fw arc approve-driver <arc> "<new name>" --rationale ...`). The
        # reviewer still has to be able to judge it, or the default path would
        # only ever work for estimator proposals. Reviewed in memory; nothing
        # is written, because there is nothing on disk to write onto.
        inline = os.environ.get("FW_ARC_REVIEW_INLINE_ENTRY") or ""
        if inline:
            try:
                entry = json.loads(inline)
            except Exception:
                entry = None
            if isinstance(entry, dict):
                targets = [entry]
                where = "inline"
    if not targets:
        msg = (f"Error: no driver matching '{selector}' in proposed_scoped_drivers[] "
               f"or scoped_drivers[] on arc '{arc.get('id')}'.")
        if emit == "json":
            print(json.dumps({"arc": arc.get("id"), "error": msg, "verdict": "fail",
                              "reviewed": []}))
        else:
            print(msg, file=sys.stderr)
        sys.exit(1)

results = []
for entry in targets:
    v = review(entry)
    results.append({"name": entry.get("name"), "id": entry.get("id"),
                    "where": where, **v})
    if not dry_run and where == "proposed_scoped_drivers":
        entry["reviewer"] = v

overall = "pass" if all(r["verdict"] == "pass" for r in results) else "fail"

if not dry_run and where == "proposed_scoped_drivers":
    arc["proposed_scoped_drivers"] = proposed
    tmp = arc_file + ".tmp"          # T-100191: same-dir temp + os.replace
    with open(tmp, "w") as fh:
        if _ry is not None:
            _ry.dump(arc, fh)
        else:
            yaml.safe_dump(arc, fh, sort_keys=False, default_flow_style=False,
                           allow_unicode=True)
    os.replace(tmp, arc_file)

if emit == "json":
    print(json.dumps({"arc": arc.get("id"), "verdict": overall,
                      "reviewer_id": REVIEWER_ID, "dry_run": dry_run,
                      "reviewed": results}))
else:
    for r in results:
        head = "PASS" if r["verdict"] == "pass" else "FAIL"
        print(f"{head}  {r['name']}  [{r['where']}]")
        for k, _label, _fn in CHECKS:
            c = r["checks"][k]
            mark = "PASS" if c["verdict"] == "pass" else "FAIL"
            print(f"  ({k}) {c['check']:<14} {mark}  {c['reason']}")
    if dry_run:
        print("\n(--dry-run: no reviewer: block written)")
    elif where == "scoped_drivers":
        print("\n(driver is already approved — reviewed read-only, nothing written)")
    elif where == "inline":
        print("\n(driver is not yet proposed — reviewed from arguments, nothing written)")
    else:
        print(f"\nWrote reviewer: block to {len(results)} proposed entr"
              f"{'y' if len(results) == 1 else 'ies'} in {arc_file}")

sys.exit(0 if overall == "pass" else 1)
PY
}

# fw arc review-driver <arc-id> "<name>"|--all [--dry-run] [--json]
arc_review_driver() {
    local id="" name="" dry_run=false emit="human" want_all=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --all) want_all=true; shift;;
            --dry-run) dry_run=true; shift;;
            --json) emit="json"; shift;;
            --help|-h) _arc_review_driver_help; return 0;;
            *)
                if [ -z "$id" ]; then id="$1"
                elif [ -z "$name" ]; then name="$1"
                else echo "Unexpected arg: $1" >&2; return 2; fi
                shift;;
        esac
    done

    if [ -z "$id" ]; then _arc_review_driver_help; return 2; fi
    id="$(_arc_normalize_input "$id")"
    _arc_validate_id "$id" || return 2
    _arc_exists "$id" || { echo "Error: arc '$id' not found" >&2; return 1; }

    if [ "$want_all" = "false" ] && [ -z "$name" ]; then
        echo "Error: driver name is required (or pass --all)." >&2
        _arc_review_driver_help
        return 2
    fi
    [ "$want_all" = "true" ] && name="--all"

    _arc_driver_review_run "$(_arc_path "$id")" "$PROJECT_ROOT" "$name" "$dry_run" "$emit"
}

_arc_review_driver_help() {
    echo "Usage:"
    echo "  fw arc review-driver <arc-id> \"<name>\" [--dry-run] [--json]"
    echo "  fw arc review-driver <arc-id> --all [--dry-run] [--json]"
    echo ""
    echo "  Static, re-runnable review of a proposed scoped driver (T-3429, D-586):"
    echo "    (a) scorable      — handler, or a scoring:/scoring_file: spec that validates (T-3428)"
    echo "    (b) distinct      — no collision with D1-D4, free_drivers[] or this arc's scoped_drivers[]"
    echo "    (c) distinguishes — rationale >= 60 chars and names a directive it differs from (D6)"
    echo ""
    echo "  Writes reviewer: {verdict, checks, ts, reviewer_id} onto the matching"
    echo "  proposed_scoped_drivers[] entry. --dry-run writes nothing."
    echo "  Exit 0 when every reviewed driver passes, 1 otherwise."
    echo ""
    echo "  An already-approved driver may be named too — it is reviewed read-only."
}
