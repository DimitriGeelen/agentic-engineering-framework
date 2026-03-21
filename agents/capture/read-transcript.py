#!/usr/bin/env python3
"""
JSONL transcript reader for conversation capture.
Extracts human/agent conversation turns from the current Claude Code session.

Usage:
  python3 read-transcript.py              # Extract current topic turns as JSON
  python3 read-transcript.py --dry-run    # Validate format only, no output
  python3 read-transcript.py --last-n 20  # Force last N human exchanges
  python3 read-transcript.py --all        # Entire session
"""

import json
import os
import re
import sys
import argparse
from datetime import datetime


# ── ANSI stripping ────────────────────────────────────────────────────────────

ANSI_RE = re.compile(r'\x1b\[[0-9;]*[mABCDEFGHJKSTfhilmnprsu]')

def strip_ansi(text):
    return ANSI_RE.sub('', text)


# ── Transcript location ───────────────────────────────────────────────────────

def find_transcript():
    project_root = os.environ.get('PROJECT_ROOT') or os.getcwd()
    # Matches Claude Code's encoding: /Users/x/y → -Users-x-y (leading slash → leading dash)
    dir_name = project_root.replace('/', '-')
    search_dir = os.path.expanduser(f'~/.claude/projects/{dir_name}')

    if not os.path.isdir(search_dir):
        print(f'Warning: transcript directory not found: {search_dir}', file=sys.stderr)
        return None

    candidates = [
        f for f in os.listdir(search_dir)
        if f.endswith('.jsonl') and not f.startswith('agent-')
    ]
    if not candidates:
        print('Warning: no session JSONL found', file=sys.stderr)
        return None

    candidates.sort(
        key=lambda f: os.path.getmtime(os.path.join(search_dir, f)),
        reverse=True
    )
    return os.path.join(search_dir, candidates[0])


# ── Format canary ─────────────────────────────────────────────────────────────

def validate_format(path):
    """Check expected event types exist in first 100 lines."""
    seen = set()
    with open(path, errors='ignore') as f:
        for i, line in enumerate(f):
            if i >= 100:
                break
            try:
                e = json.loads(line)
                seen.add(e.get('type'))
            except Exception:
                pass

    missing = {'user', 'assistant'} - seen
    if missing:
        print(
            f'Warning: JSONL format canary failed — expected event types not found: {missing}. '
            'Anthropic may have changed the transcript format.',
            file=sys.stderr
        )
        return False
    return True


# ── Turn extraction ───────────────────────────────────────────────────────────

def extract_turns(path):
    """Extract all (role, text, timestamp) turns from transcript."""
    turns = []
    with open(path, errors='ignore') as f:
        for line in f:
            try:
                e = json.loads(line)
                t = e.get('type')
                ts = e.get('timestamp', '')

                if t == 'user':
                    content = e.get('message', {}).get('content', '')
                    if isinstance(content, str) and content.strip():
                        turns.append({
                            'role': 'human',
                            'content': strip_ansi(content.strip()),
                            'timestamp': ts,
                        })
                    elif isinstance(content, list):
                        for c in content:
                            if isinstance(c, dict) and c.get('type') == 'text':
                                text = c.get('text', '').strip()
                                if text:
                                    turns.append({
                                        'role': 'human',
                                        'content': strip_ansi(text),
                                        'timestamp': ts,
                                    })
                                break

                elif t == 'assistant':
                    content = e.get('message', {}).get('content', [])
                    if isinstance(content, list):
                        for c in content:
                            if isinstance(c, dict) and c.get('type') == 'text':
                                text = c.get('text', '').strip()
                                if text:
                                    turns.append({
                                        'role': 'agent',
                                        'content': strip_ansi(text),
                                        'timestamp': ts,
                                    })
                                break

            except Exception:
                pass

    return turns


# ── Topic boundary detection ──────────────────────────────────────────────────

def find_topic_start(turns, fallback_n=20):
    """
    Find where the current conversation topic started (Interpretation A, T-101).

    Strategy:
    1. Scan backward for timestamp gap > 5 minutes between consecutive turns
    2. Gap signals user returned with a new topic
    3. Fallback: last fallback_n human exchanges if no gap found
    """
    if len(turns) <= fallback_n * 2:
        return 0

    def parse_ts(ts_str):
        if not ts_str:
            return None
        try:
            return datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        except Exception:
            return None

    GAP_MINUTES = 5

    for i in range(len(turns) - 1, 0, -1):
        ts_curr = parse_ts(turns[i]['timestamp'])
        ts_prev = parse_ts(turns[i - 1]['timestamp'])
        if ts_curr and ts_prev:
            gap = (ts_curr - ts_prev).total_seconds() / 60
            if gap > GAP_MINUTES:
                return i

    # Fallback: last fallback_n human turns
    human_count = 0
    for i in range(len(turns) - 1, -1, -1):
        if turns[i]['role'] == 'human':
            human_count += 1
            if human_count >= fallback_n:
                return i

    return 0


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='Extract conversation from Claude Code JSONL transcript'
    )
    parser.add_argument('--dry-run', action='store_true',
                        help='Validate format only, no output')
    parser.add_argument('--last-n', type=int, default=None,
                        help='Force last N human exchanges')
    parser.add_argument('--all', action='store_true',
                        help='Extract entire session')
    args = parser.parse_args()

    path = find_transcript()
    if not path:
        sys.exit(1)

    valid = validate_format(path)
    if args.dry_run:
        if valid:
            print('Format canary: OK')
            sys.exit(0)
        else:
            sys.exit(1)

    all_turns = extract_turns(path)
    if not all_turns:
        print('Warning: no conversation turns found in transcript', file=sys.stderr)
        sys.exit(1)

    if args.all:
        start_idx = 0
        mode = 'all'
    elif args.last_n:
        human_count = 0
        start_idx = 0
        for i in range(len(all_turns) - 1, -1, -1):
            if all_turns[i]['role'] == 'human':
                human_count += 1
                if human_count >= args.last_n:
                    start_idx = i
                    break
        mode = f'last-{args.last_n}'
    else:
        start_idx = find_topic_start(all_turns)
        mode = 'topic-boundary'

    captured = all_turns[start_idx:]

    result = {
        'session_file': os.path.basename(path),
        'total_turns': len(all_turns),
        'captured_turns': len(captured),
        'topic_start_index': start_idx,
        'capture_mode': mode,
        'turns': captured,
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
