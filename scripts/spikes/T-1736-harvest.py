#!/usr/bin/env python3
"""T-1736 Spike B harvest: extract real user prompts from Claude Code session JSONLs.

A "real user prompt" = a `type: user` message whose content is a plain string
typed by a human at the chat input. Filtered out:
  - sub-agent dispatch prompts (start with "You are worker", "You are sub-agent")
  - pings ("Reply with the single word", "Reply only with")
  - system reminders / tool results (start with "<" or wrapped objects, not strings)
  - caveats from local commands
  - very short pings (< 12 chars)
  - hook-emitted markers
Output: one JSON object per line: {id, source, ts, text}.
"""
import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


SUBAGENT_PREFIXES = (
    "You are worker",
    "You are sub-agent",
    "You are an automation",
    "You are an agent ",
    "You are part of ",
    "Reply with the single word",
    "Reply only with the literal",
    "Reply only with",
)

# Lowercase substrings that indicate the prompt is internal/sub-agent, not user
SUBAGENT_CONTAINS = (
    "do not change focus",
    "do not create new tasks",
    "follow framework governance",
)


def looks_human(text: str) -> bool:
    if not text or len(text) < 12:
        return False
    s = text.strip()
    if s.startswith("<"):
        return False
    if s.startswith("Caveat"):
        return False
    for p in SUBAGENT_PREFIXES:
        if s.startswith(p):
            return False
    low = s.lower()
    if any(c in low for c in SUBAGENT_CONTAINS):
        # only reject if also starts with worker-ish frame; otherwise let through
        if "worker" in low[:200] or "sub-agent" in low[:200]:
            return False
    # Reject pure command-result style fragments
    if s.startswith("Tool ") and "returned" in s[:80]:
        return False
    return True


def harvest(projects_root: Path, days: int) -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    seen_hashes = set()
    out = []
    files = sorted(projects_root.glob("*/*.jsonl"))
    for f in files:
        try:
            mtime = datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc)
        except OSError:
            continue
        if mtime < cutoff:
            continue
        try:
            with f.open() as fh:
                for line in fh:
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if obj.get("type") != "user":
                        continue
                    msg = obj.get("message")
                    if not isinstance(msg, dict):
                        continue
                    content = msg.get("content")
                    if not isinstance(content, str):
                        continue
                    text = content.strip()
                    if not looks_human(text):
                        continue
                    h = hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]
                    if h in seen_hashes:
                        continue
                    seen_hashes.add(h)
                    out.append(
                        {
                            "id": h,
                            "source": str(f.relative_to(projects_root.parent)),
                            "ts": obj.get("timestamp", ""),
                            "text": text,
                        }
                    )
        except OSError:
            continue
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--projects-root",
        default=str(Path.home() / ".claude" / "projects"),
    )
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument(
        "--out",
        default=".context/spikes/T-1736-prompts.jsonl",
    )
    ap.add_argument("--limit", type=int, default=0, help="cap output (0 = no cap)")
    args = ap.parse_args()

    root = Path(args.projects_root)
    if not root.exists():
        print(f"projects root not found: {root}", file=sys.stderr)
        return 1
    prompts = harvest(root, args.days)
    if args.limit and args.limit > 0:
        prompts = prompts[: args.limit]
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w") as f:
        for p in prompts:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")
    print(f"harvested {len(prompts)} prompts → {out_path}")
    # Print quick distribution
    if prompts:
        lens = sorted(len(p["text"]) for p in prompts)
        print(
            f"length stats: min={lens[0]} median={lens[len(lens)//2]} max={lens[-1]}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
