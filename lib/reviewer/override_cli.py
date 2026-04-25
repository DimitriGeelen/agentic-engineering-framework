"""CLI for reviewer overrides (T-1443 v1.4).

Subcommands: add | list | prune | remove
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone

from lib.reviewer.overrides import (
    DEFAULT_TTL_DAYS,
    add_override,
    load_overrides,
    prune_expired,
    remove_override,
    save_overrides,
)


def _cmd_add(args: argparse.Namespace) -> int:
    o = add_override(
        task_id=args.task,
        pattern_id=args.pattern,
        reason=args.reason,
        ac_index=args.ac,
        ttl_days=args.ttl,
        added_by=args.by,
    )
    print(f"Override added: {o.id}")
    print(f"  task: {o.task_id}  pattern: {o.pattern_id}  ac: {o.ac_index}")
    print(f"  expires_at: {o.expires_at}  reason: {o.reason}")
    return 0


def _cmd_list(args: argparse.Namespace) -> int:
    now = datetime.now(timezone.utc)
    overrides = load_overrides()
    if not overrides:
        print("No active overrides.")
        return 0
    print(f"{'ID':<14} {'TASK':<10} {'PATTERN':<24} {'AC':<4} {'DAYS':<5} EXPIRES                REASON")
    print("─" * 110)
    for o in overrides:
        days = o.days_remaining(now)
        ac = str(o.ac_index) if o.ac_index is not None else "*"
        flag = " (EXPIRED)" if o.is_expired(now) else ""
        print(f"{o.id:<14} {o.task_id:<10} {o.pattern_id:<24} {ac:<4} {days:<5} {o.expires_at:<22} {o.reason[:40]}{flag}")
    return 0


def _cmd_prune(args: argparse.Namespace) -> int:
    overrides = load_overrides()
    kept, dropped = prune_expired(overrides)
    if not dropped:
        print("No expired overrides to prune.")
        return 0
    save_overrides(kept)
    print(f"Pruned {len(dropped)} expired override(s):")
    for o in dropped:
        print(f"  {o.id}  task={o.task_id}  pattern={o.pattern_id}  expired_at={o.expires_at}")
    return 0


def _cmd_remove(args: argparse.Namespace) -> int:
    if remove_override(args.id):
        print(f"Removed override: {args.id}")
        return 0
    print(f"No override with id {args.id}", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="fw reviewer override")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_add = sub.add_parser("add", help="add a new override")
    p_add.add_argument("task", help="T-XXX task id")
    p_add.add_argument("--pattern", required=True, help="pattern id (e.g. AC-verify-mismatch)")
    p_add.add_argument("--ac", type=int, default=None, help="AC index (omit = wildcard)")
    p_add.add_argument("--reason", required=True, help="why this is being suppressed")
    p_add.add_argument("--ttl", type=int, default=DEFAULT_TTL_DAYS, help="TTL in days (default 90)")
    p_add.add_argument("--by", default=None, help="who added (default: $USER)")
    p_add.set_defaults(func=_cmd_add)

    p_list = sub.add_parser("list", help="list active overrides")
    p_list.set_defaults(func=_cmd_list)

    p_prune = sub.add_parser("prune", help="drop expired overrides")
    p_prune.set_defaults(func=_cmd_prune)

    p_rm = sub.add_parser("remove", help="remove a specific override by id")
    p_rm.add_argument("id", help="override id (OV-XXXX)")
    p_rm.set_defaults(func=_cmd_remove)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
