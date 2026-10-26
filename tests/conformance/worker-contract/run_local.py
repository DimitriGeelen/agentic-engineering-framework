#!/usr/bin/env python3
"""Run the shared worker-contract vectors against AEF's local backend (T-4520).

The local backend is the §6.2 dispatch-records store. It is looked for at
lib/dispatch_records.py, which must expose `conformance_adapter()` returning an
adapter object:

    adapter.capabilities        set of vocabulary capability names it offers
    adapter.reset(given)        seed the store from a vector's `given`
    adapter.apply(step)         perform one step; return a result mapping shaped like
                                an expect ({"accepted": "T3", "notices": 1, "values": {…},
                                "bind": {…}}; for `concurrent`, {"results": [ … ]});
                                raise NotImplementedError("<what>") for an op it lacks
    adapter.snapshot()          {"attempts": {"A1": {"state", "outcome", "history": [states], …}},
                                 plus any then-level facts it reports (operator_notices, …)}
    adapter.equivalent_routes   optional set of "<case id>/<variant name>" the backend cannot run
                                directly and runs by the variant's `equivalent:` instead (§6.6 N2)

Equivalent route (T-4793). A variant may carry `equivalent:` (what a backend without the
phrased path runs instead). A backend that runs the real path returns no "equivalent" and is
judged on the steps as usual. A backend that names the variant in `equivalent_routes` must
return a non-empty "equivalent": "<what ran>" in every step result; its expect is accepted only
then, and that string is named in the case result. A declared route whose result lacks it
fails ("equivalent route taken silently"), as does an "equivalent" on a variant offering none.

Until that module exists every vector is reported `not-implemented` with what is
missing. A vector is reported `pass` only after its steps ran and every expect and
`then` assertion matched: nothing is assumed.

Usage: run_local.py [--vectors PATH] [--backend MODULE:FUNC] [--json] [--require-implemented]
Exit: 0 no failures · 1 a vector failed · 2 vectors file invalid · 3 --require-implemented and
something is not implemented.
"""

from __future__ import annotations

import argparse
import copy
import importlib
import importlib.util
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
LOCAL_BACKEND = REPO / "lib" / "dispatch_records.py"
sys.path.insert(0, str(HERE))

import yaml  # noqa: E402

from check_vectors import Checker  # noqa: E402

NA_CAPABILITIES = {"answer_channel", "registry_epoch", "caller_chosen_ids"}


class Mismatch(Exception):
    pass


# ── backend discovery ──────────────────────────────────────────────────────
def load_backend(spec: str | None):
    """Return (adapter or None, reason)."""
    if spec:
        mod_name, _, func = spec.partition(":")
        module = importlib.import_module(mod_name)
        return getattr(module, func or "conformance_adapter")(), f"adapter {spec}"
    if not LOCAL_BACKEND.exists():
        return None, "no local backend: lib/dispatch_records.py (§6.2 dispatch records) does not exist"
    s = importlib.util.spec_from_file_location("dispatch_records", LOCAL_BACKEND)
    assert s is not None and s.loader is not None
    module = importlib.util.module_from_spec(s)
    s.loader.exec_module(module)
    factory = getattr(module, "conformance_adapter", None)
    if factory is None:
        return None, "lib/dispatch_records.py exists but exposes no conformance_adapter()"
    return factory(), "lib/dispatch_records.py"


# ── helpers ────────────────────────────────────────────────────────────────
def ops_used(vec: dict) -> list[str]:
    ops: list[str] = []

    def walk(steps):
        for st in steps or []:
            if st.get("op") not in ops:
                ops.append(st["op"])
            inner = (st.get("args") or {}).get("step")
            if isinstance(inner, dict):
                walk([inner])

    walk(vec.get("steps"))
    for var in vec.get("variants") or []:
        walk(var.get("steps"))
    return ops


def runs_of(vec: dict) -> list[dict]:
    if not vec.get("variants"):
        return [{"name": None, "requires": [], "equivalent": None, "given": vec["given"],
                 "steps": list(vec["steps"]), "then": vec["then"]}]
    out = []
    for var in vec["variants"]:
        given = copy.deepcopy(vec["given"])
        given.update(var.get("given") or {})
        out.append({"name": var["name"], "requires": var.get("requires") or [],
                    "equivalent": var.get("equivalent"), "given": given,
                    "steps": list(vec["steps"]) + list(var["steps"]), "then": var["then"]})
    return out


def match_value(actual, expected) -> bool:
    if isinstance(expected, dict) and set(expected) == {"present"}:
        return (actual is not None) == bool(expected["present"])
    if isinstance(expected, dict) and set(expected) == {"any_of"}:
        return any(match_value(actual, e) for e in expected["any_of"])
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            return False
        return all(match_value(actual.get(k), v) for k, v in expected.items())
    return actual == expected


def match_expect(result: dict, exp: dict) -> bool:
    if "any_of" in exp:
        return any(match_expect(result, e) for e in exp["any_of"])
    for key in ("accepted", "fence_reject", "error", "refused", "response", "no_transition", "ok"):
        if key in exp and result.get(key) != exp[key]:
            return False
    if "notices" in exp and result.get("notices", 0) != exp["notices"]:
        return False
    for k, v in (exp.get("values") or {}).items():
        actual = (result.get("values") or {}).get(k.removesuffix("_matches"))
        if k.endswith("_matches"):
            if not isinstance(actual, str) or not re.fullmatch(v, actual):
                return False
        elif not match_value(actual, v):
            return False
    return True


def check_route(result: dict, step: dict, route: str | None, offered: str | None) -> str | None:
    """Return what ran by the equivalent route, or None for the real path (T-4793)."""
    ran = result.get("equivalent")
    if ran is not None and not (isinstance(ran, str) and ran.strip()):
        raise Mismatch(f"step {step['op']}: 'equivalent' must be a non-empty string, got {ran!r}")
    if ran and offered is None:
        raise Mismatch(f"step {step['op']}: equivalent '{ran}' reported on a run that offers no equivalent")
    if route and not ran:
        raise Mismatch(f"step {step['op']}: equivalent route taken silently ({route} declared, "
                       "result carries no 'equivalent')")
    return ran or None


def check_step(adapter, step: dict, route: str | None = None, offered: str | None = None) -> str | None:
    result = adapter.apply(step)
    ran = check_route(result, step, route, offered)
    exp = step["expect"]
    if step["op"] == "concurrent":
        results = result.get("results") or []
        if len(results) != step["args"]["count"]:
            raise Mismatch(f"concurrent: {len(results)} results for {step['args']['count']} writers")
        winners = [r for r in results if match_expect(r, exp["exactly_one"])]
        losers = [r for r in results if not match_expect(r, exp["exactly_one"])]
        if len(winners) != 1:
            raise Mismatch(f"concurrent: {len(winners)} writers matched exactly_one")
        bad = [r for r in losers if not any(match_expect(r, e) for e in exp["rest_any_of"])]
        if bad:
            raise Mismatch(f"concurrent: loser result {bad[0]} not admissible")
        return ran
    if not match_expect(result, exp):
        raise Mismatch(f"step {step['op']}: expected {exp}, got {result}")
    return ran


def check_then(before: dict, after: dict, then: dict) -> None:
    attempts = after.get("attempts") or {}
    for key, want in (then.get("final") or {}).items():
        got = attempts.get(key)
        if got is None:
            raise Mismatch(f"final: attempt {key} missing")
        for field, value in want.items():
            if not match_value(got.get(field), value):
                raise Mismatch(f"final {key}.{field}: expected {value}, got {got.get(field)}")
    for key, seqs in (then.get("admissible_histories") or {}).items():
        hist = (attempts.get(key) or {}).get("history")
        if hist not in seqs:
            raise Mismatch(f"history {key}: {hist} not in admissible {seqs}")
    for key in then.get("history_unchanged") or []:
        if (before.get("attempts") or {}).get(key, {}).get("history") != attempts.get(key, {}).get("history"):
            raise Mismatch(f"history of {key} changed")
    for key in then.get("fields_unchanged") or []:
        if (before.get("attempts") or {}).get(key) != attempts.get(key):
            raise Mismatch(f"fields of {key} changed")
    if then.get("record_unchanged") and before.get("attempts") != attempts:
        raise Mismatch("record changed")
    handled = {"final", "admissible_histories", "history_unchanged", "fields_unchanged", "record_unchanged"}
    for key, value in then.items():
        if key in handled:
            continue
        if key not in after:
            raise Mismatch(f"then.{key}: the adapter does not report '{key}'")
        if not match_value(after[key], value):
            raise Mismatch(f"then.{key}: expected {value}, got {after[key]}")


# ── one vector ─────────────────────────────────────────────────────────────
def run_vector(vec: dict, adapter, backend_reason: str) -> dict:
    app = vec["applicability"]
    base = {"id": vec["id"], "title": vec["title"]}
    if adapter is None:
        missing = [backend_reason] + [f"op:{o}" for o in ops_used(vec)] + \
                  [f"capability:{c}" for c in app.get("requires") or []]
        return {**base, "status": "not-implemented", "missing": missing}
    caps = set(getattr(adapter, "capabilities", set()) or set())
    lacking = [c for c in app.get("requires") or [] if c not in caps]
    if lacking:
        if app.get("n_a_allowed") and set(lacking) <= NA_CAPABILITIES | {"real_worker"}:
            return {**base, "status": "n/a", "reason": f"capability not offered: {', '.join(lacking)}"}
        return {**base, "status": "fail",
                "reason": f"N2: lacks {', '.join(lacking)} on a case that may not be n/a"}
    declared = set(getattr(adapter, "equivalent_routes", set()) or set())
    variant_results = []
    for run in runs_of(vec):
        label = run["name"] or "main"
        if any(c not in caps for c in run["requires"]):
            variant_results.append({"variant": label, "status": "n/a"})
            continue
        key = f"{vec['id']}/{label}"
        route = key if key in declared else None
        try:
            if route and not run["equivalent"]:
                raise Mismatch(f"{key} declared as an equivalent route, but the variant offers no equivalent")
            adapter.reset(copy.deepcopy(run["given"]))
            before = copy.deepcopy(adapter.snapshot())
            ran = [r for r in (check_step(adapter, step, route, run["equivalent"])
                               for step in run["steps"]) if r]
            check_then(before, adapter.snapshot(), run["then"])
            passed = {"variant": label, "status": "pass"}
            if ran:
                passed["equivalent"] = "; ".join(dict.fromkeys(ran))
            variant_results.append(passed)
        except NotImplementedError as exc:
            variant_results.append({"variant": label, "status": "not-implemented", "missing": [str(exc)]})
        except Mismatch as exc:
            variant_results.append({"variant": label, "status": "fail", "reason": str(exc)})
    statuses = {v["status"] for v in variant_results}
    if "fail" in statuses:
        status = "fail"
    elif "not-implemented" in statuses:
        status = "not-implemented"
    elif statuses == {"n/a"}:
        status = "n/a" if app.get("n_a_allowed") else "fail"
    else:
        status = "pass"
    out = {**base, "status": status, "variants": variant_results}
    if status == "fail" and statuses == {"n/a"}:
        out["reason"] = "N2: no variant applies to a transition-subject case"
    if status == "not-implemented":
        out["missing"] = sorted({m for v in variant_results for m in v.get("missing", [])})
    return out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--vectors", default=str(HERE / "vectors.yaml"))
    ap.add_argument("--backend", help="MODULE:FUNC returning an adapter (default: lib/dispatch_records.py)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--require-implemented", action="store_true")
    args = ap.parse_args(argv)

    doc = yaml.safe_load(Path(args.vectors).read_text())
    errors = Checker().check(doc)
    if errors:
        for e in errors:
            print(f"INVALID {e}", file=sys.stderr)
        return 2
    adapter, reason = load_backend(args.backend)
    results = [run_vector(v, adapter, reason) for v in doc["vectors"]]
    counts: dict = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1

    if args.json:
        print(json.dumps({"backend_found": adapter is not None, "backend": reason,
                          "counts": counts, "results": results}, indent=2))
    else:
        print(f"backend: {reason}")
        for r in results:
            detail = r.get("reason") or "; ".join(r.get("missing", [])[:1]) or "; ".join(
                f"{v['variant']} by equivalent: {v['equivalent']}" for v in r.get("variants", []) if "equivalent" in v)
            print(f"  {r['id']:6} {r['status']:16} {r['title']}" + (f" — {detail}" if detail else ""))
        print("summary: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    if counts.get("fail"):
        return 1
    if args.require_implemented and counts.get("not-implemented"):
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
