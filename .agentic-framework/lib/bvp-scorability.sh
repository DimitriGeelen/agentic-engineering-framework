#!/usr/bin/env bash
# lib/bvp-scorability.sh — T-3428 (OBS-463 leg 3), arc-006.
#
# One fact function for the audit and doctor rails. It answers a single
# question about every ACTIVE value driver — free (policy/value-drivers.yaml)
# and arc-scoped (.context/arcs/*.yaml `scoped_drivers[]`):
#
#     can the estimator score this driver at all?
#
# A driver is SCORABLE when a hand-written handler exists for its id or name
# (agents/termlink/bvp-estimator/estimator.py::_handler_table) or when it
# carries a declarative `scoring:` block that validates (T-3428). Anything
# else is a driver that is only a NAME: T-3427 keeps it out of the ranking
# denominator, so it does not distort the ranking any more — but it also
# contributes nothing, and nobody is told. Its weight, its rubric prose and
# its rationale all read as a live scoring axis. That silence is what this
# file exists to break.
#
# An INVALID `scoring:` block is reported as its own class, not lumped in with
# "no spec". A broken spec looks like a mechanism in the policy file and is
# treated as no mechanism by the estimator — exactly the divergence T-3428 was
# filed to remove, so it gets named separately and its errors printed.
#
#   fw_bvp_unscorable_drivers <project_root>
#
#     stdout : zero or more lines, tab-separated
#              ID<TAB>NAME<TAB>SOURCE<TAB>REASON
#              REASON is `no-mechanism` or `invalid-spec: <first error>`
#     rc 0   : scan ran (zero lines = every active driver is scorable)
#     rc 1   : nothing to scan here — no policy/value-drivers.yaml under
#              <project_root> (a project that never bootstrapped BVP). The
#              caller stays SILENT rather than reporting a clean bill of
#              health it never measured.
#     rc 2   : the scan could not run (estimator unimportable, YAML broken).
#              The caller should say so rather than report zeros.
#
# WARN-only by design at both call sites. The remedy — draft a `scoring:` spec
# or write a handler — is a policy/authoring decision, never something a gate
# should force mid-push. Arc-scoped drivers are read from arcs whose status is
# neither `closed` nor `abandoned`: a retired arc's driver is not active and
# nagging about it would be noise that trains the rail out.

fw_bvp_unscorable_drivers() {
    local root="${1:?fw_bvp_unscorable_drivers: project root required}"
    [ -f "$root/policy/value-drivers.yaml" ] || return 1

    local fw_root="${FRAMEWORK_ROOT:-$root}"
    local est="$fw_root/agents/termlink/bvp-estimator/estimator.py"
    [ -f "$est" ] || est="$root/agents/termlink/bvp-estimator/estimator.py"
    [ -f "$est" ] || return 2

    PROJECT_ROOT="$root" python3 - "$est" "$root" <<'PY'
import importlib.util
import sys
from pathlib import Path

est_path, root = sys.argv[1], Path(sys.argv[2])

try:
    import yaml
    spec = importlib.util.spec_from_file_location("bvp_estimator_scorability", est_path)
    est = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(est)
except Exception:
    sys.exit(2)


def classify(entry):
    """(ok, reason) for one driver entry."""
    d_id = entry.get("id") or entry.get("name")
    d_name = entry.get("name") or d_id
    table = est._handler_table()
    if d_id in table or d_name in table:
        return True, ""
    try:
        alias = est._load_driver_aliases().get(d_id)
    except Exception:
        alias = None
    if alias and alias in table:
        return True, ""
    block = est.load_scoring_spec(entry)
    if block is None:
        return False, "no-mechanism"
    errors = est.validate_scoring_spec(block)
    if errors:
        return False, f"invalid-spec: {errors[0]}"
    return True, ""


rows = []
try:
    policy = yaml.safe_load((root / "policy" / "value-drivers.yaml").read_text()) or {}
except Exception:
    sys.exit(2)

# Only free drivers: D1-D4 are the chassis and always have handlers; a
# protected driver without one would be a framework bug, not a policy state
# this rail can advise on.
for d in (policy.get("free_drivers") or []):
    if not isinstance(d, dict):
        continue
    ok, reason = classify(d)
    if not ok:
        rows.append((d.get("id") or "?", d.get("name") or "?",
                     "policy/value-drivers.yaml", reason))

arcs_dir = root / ".context" / "arcs"
if arcs_dir.is_dir():
    for arc_yaml in sorted(arcs_dir.glob("*.yaml")):
        try:
            arc = yaml.safe_load(arc_yaml.read_text()) or {}
        except Exception:
            continue
        if str(arc.get("status") or "").lower() in ("closed", "abandoned"):
            continue
        for sd in (arc.get("scoped_drivers") or []):
            if not isinstance(sd, dict):
                continue
            ok, reason = classify(sd)
            if not ok:
                rows.append((sd.get("id") or sd.get("name") or "?",
                             sd.get("name") or "?",
                             f".context/arcs/{arc_yaml.name}", reason))

for r in rows:
    print("\t".join(str(x).replace("\t", " ") for x in r))
PY
    local rc=$?
    [ "$rc" -ne 0 ] && return 2
    return 0
}
