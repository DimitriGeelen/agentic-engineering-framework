"""CLI entry point for the Watchtower scan engine.

Usage:
    python3 -m web.watchtower [--project-root PATH] [--quiet]
    fw scan [--quiet]
"""

import argparse
import os
import sys
import yaml

from .scanner import scan


def main():
    parser = argparse.ArgumentParser(
        description="Watchtower scan — detect opportunities, challenges, and work direction"
    )
    parser.add_argument(
        "--project-root",
        default=os.environ.get("PROJECT_ROOT"),
        help="Project root directory (default: PROJECT_ROOT env var)",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress output — only write scan YAML",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output scan result as YAML to stdout",
    )
    args = parser.parse_args()

    try:
        result = scan(project_root=args.project_root)
    except Exception as exc:
        print(f"Scan failed: {exc}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        yaml.dump(result, sys.stdout, default_flow_style=False,
                  sort_keys=False)
    elif not args.quiet:
        print(result["summary"])
        print()
        n_dec = len(result.get("needs_decision", []))
        n_rec = len(result.get("framework_recommends", []))
        n_opp = len(result.get("opportunities", []))
        n_risk = len(result.get("risks", []))
        parts = []
        if n_dec:
            parts.append(f"{n_dec} decisions")
        if n_rec:
            parts.append(f"{n_rec} recommendations")
        if n_opp:
            parts.append(f"{n_opp} opportunities")
        if n_risk:
            parts.append(f"{n_risk} risks")
        if parts:
            print("  " + " | ".join(parts))
        print(f"\nScan written to .context/scans/{result['scan_id']}.yaml")


if __name__ == "__main__":
    main()
