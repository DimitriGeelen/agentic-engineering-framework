#!/usr/bin/env python3
"""T-3127: classify the persisted full-audit timing record against a warn fraction.

Reads the fixed-path timing record .context/audits/full-audit-timing.yaml,
written by agents/audit/audit.sh at the end of every full (unscoped) run (or by
its SIGTERM trap on a timeout kill), and classifies it for `fw doctor`.

Extracted to its own module rather than inlined in bin/fw so the classification
logic carries its own regression fixture, independent of the live corpus's
measured runtime (L-599 — pinning a test to the actual measured seconds breaks
the moment the corpus grows; a synthetic YAML fixture does not).
"""
import sys

import yaml


def evaluate(path, warn_fraction=0.70):
    """Classify the timing record at `path` against `warn_fraction`.

    Returns a dict with at least a "status" key, one of:
      "unmeasured"      — file missing, unparseable, or missing required fields
      "timed_out"       — the run exhausted its OWN ceiling (AUDIT_TIMEOUT)
      "killed_external" — the run was killed by something else, before its
                          ceiling was reached (T-3202)
      "warn"            — total_seconds / ceiling_seconds >= warn_fraction
      "ok"              — below the warn fraction

    T-3202: "timed_out" used to cover both kills, which made them serialise
    identically and pointed every reader at FW_AUDIT_FULL_TIMEOUT — a limit that
    an externally-killed run never reached. The two are separable with certainty,
    not by a threshold: the internal watchdog sleeps AUDIT_TIMEOUT before sending
    TERM and the trap runs after the in-flight command returns, so an internal
    kill can only record total >= ceiling. total < ceiling proves an external
    killer. Records written since T-3202 state it outright in `kill_source`;
    older ones are classified by that inference and flagged `kill_source_derived`.
    """
    try:
        with open(path) as f:
            data = yaml.safe_load(f) or {}
    except (OSError, yaml.YAMLError) as exc:
        return {"status": "unmeasured", "reason": str(exc)}

    run = data.get("last_run") or {}
    total = run.get("total_seconds")
    ceiling = run.get("ceiling_seconds")
    if (
        not isinstance(total, (int, float))
        or isinstance(total, bool)
        or not isinstance(ceiling, (int, float))
        or isinstance(ceiling, bool)
        or ceiling <= 0
    ):
        return {"status": "unmeasured", "reason": "missing/invalid total_seconds or ceiling_seconds"}

    fraction = total / ceiling
    result = {
        "total_seconds": total,
        "ceiling_seconds": ceiling,
        "fraction": fraction,
        "warn_fraction": warn_fraction,
    }
    if run.get("timed_out"):
        result["killed_in_section"] = run.get("killed_in_section", "")
        source = run.get("kill_source")
        if source in ("internal", "external"):
            result["kill_source_derived"] = False
        else:
            # Legacy record (pre-T-3202) carries no kill_source. Derive it — see
            # the module docstring for why total < ceiling is a proof and not a
            # heuristic. Flagged so a reader can tell a stated fact from an
            # inferred one.
            source = "external" if total < ceiling else "internal"
            result["kill_source_derived"] = True
        result["kill_source"] = source
        result["status"] = "killed_external" if source == "external" else "timed_out"
    elif fraction >= warn_fraction:
        result["status"] = "warn"
    else:
        result["status"] = "ok"
    return result


def main(argv):
    if len(argv) < 2:
        print("usage: audit_timing.py <timing-yaml-path> [warn_fraction]", file=sys.stderr)
        return 2
    path = argv[1]
    try:
        warn_fraction = float(argv[2]) if len(argv) > 2 else 0.70
    except ValueError:
        warn_fraction = 0.70

    result = evaluate(path, warn_fraction)
    status = result["status"]
    if status == "unmeasured":
        print(f"UNMEASURED|{result.get('reason', '')}")
    elif status == "timed_out":
        print(f"TIMED_OUT|{result['total_seconds']}|{result['ceiling_seconds']}|{result['killed_in_section']}")
    elif status == "killed_external":
        provenance = "derived" if result.get("kill_source_derived") else "recorded"
        print(
            f"KILLED_EXTERNAL|{result['total_seconds']}|{result['ceiling_seconds']}"
            f"|{result['killed_in_section']}|{provenance}"
        )
    elif status == "warn":
        print(f"WARN|{result['total_seconds']}|{result['ceiling_seconds']}|{result['fraction']:.4f}")
    else:
        print(f"OK|{result['total_seconds']}|{result['ceiling_seconds']}|{result['fraction']:.4f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
