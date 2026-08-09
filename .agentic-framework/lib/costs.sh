#!/bin/bash
# costs.sh — Token usage tracking from JSONL transcripts (T-801)
#
# Parses Claude Code session JSONL transcripts to report token usage.
# Subscription model: cost measured in tokens consumed, not dollars.
# Data source: ~/.claude/projects/<project-dir>/*.jsonl
#
# Usage (via bin/fw):
#   fw costs              # Project summary
#   fw costs session      # Per-session breakdown
#   fw costs session ID   # Detailed session view
#   fw costs help         # Show usage
#
# Follows T-799 (GO) and T-800 (GO) inception decisions.
# Research: docs/reports/T-799-T-800-token-cost-analysis.md
#
# NOT routed through lib/context_tokens.py (T-2885). That module answers "how
# many tokens is THIS conversation holding right now" and deliberately drops
# usage entries from any model that isn't the dominant one since the last
# compact_boundary, so a foreign-model cache-priming call can't poison the
# budget gauges. Cost is the opposite question — every usage entry, whoever
# wrote it, was real spend and belongs in the total. Sharing the helper here
# would silently under-report cost for exactly the entries that make this
# script worth running.

set -euo pipefail

# Source colors if not already loaded
if [ -z "${GREEN:-}" ]; then
    source "${FRAMEWORK_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/lib/colors.sh"
fi

# Source paths helper (fw_claude_project_dir_name) if not already loaded (T-2380)
if ! declare -F fw_claude_project_dir_name >/dev/null 2>&1; then
    source "${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/paths.sh"
fi

costs_help() {
    echo -e "${BOLD}fw costs${NC} — Token usage tracking"
    echo ""
    echo "Usage:"
    echo "  fw costs                  Project-total token usage summary"
    echo "  fw costs session          Per-session token breakdown table"
    echo "  fw costs session <ID>     Detailed breakdown for one session"
    echo "  fw costs current          Current session token usage"
    echo "  fw costs help             Show this help"
    echo ""
    echo "Data source: ~/.claude/projects/ JSONL session transcripts"
    echo "Cost model: Subscription — tokens consumed (not dollars)"
}

# Find the JSONL directory/directories for this project.
#
# T-2380: use the canonical encoder (full non-alnum → '-'), matching Claude Code.
# The old slash-only sanitizer diverged in any worktree path (contains '.').
#
# T-2425: emit ALL candidate dirs via `fw_claude_project_dirs` (T-2392 union),
# one per line, existing dirs only. Claude Code keys the projects dir on launch
# cwd, not PROJECT_ROOT — so in a worktree session the JSONLs may live under the
# main-repo dir, not the worktree dir. The gauge sites (checkpoint.sh:86,
# budget-gate.sh:255, session-metrics.sh:44) already walk the union and pick
# the globally-newest *.jsonl; `fw costs` was the remaining single-dir consumer.
# Callers should iterate the lines and union the JSONL set.
_costs_jsonl_dir() {
    fw_claude_project_dirs
}

# Main token parsing — Python for streaming performance on large files.
#
# T-2425: first positional arg may be a newline-separated LIST of candidate
# projects dirs (from `fw_claude_project_dirs`), not a single dir. The Python
# loop globs *.jsonl across each existing dir and unions the result (dedup by
# basename — same session id appearing in two dirs is the same transcript).
_costs_parse_all() {
    local jsonl_dirs="$1"
    local mode="${2:-summary}"       # summary | sessions | session-detail
    local session_id="${3:-}"        # for session-detail mode

    python3 - "$jsonl_dirs" "$mode" "$session_id" << 'PYEOF'
import sys, json, os, glob
from datetime import datetime

jsonl_dirs_raw = sys.argv[1]
mode = sys.argv[2]
session_id = sys.argv[3] if len(sys.argv) > 3 else ""

# T-2425: split newline-separated dir list, keep existing dirs only
jsonl_dirs = [d for d in jsonl_dirs_raw.splitlines() if d and os.path.isdir(d)]

def fmt_tokens(n):
    """Format token count: 1234 → 1.2K, 1234567 → 1.2M, 1234567890 → 1.2B"""
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.1f}B"
    elif n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)

def parse_session(filepath):
    """Parse a single JSONL file, return session stats dict."""
    session = os.path.basename(filepath).replace('.jsonl', '')
    stats = {
        'id': session[:8],
        'id_full': session,
        'file': filepath,
        'turns': 0,
        'input_tokens': 0,
        'cache_read': 0,
        'cache_create': 0,
        'output_tokens': 0,
        'first_ts': None,
        'last_ts': None,
        'model': '',
        'file_size': os.path.getsize(filepath),
    }

    with open(filepath, 'r') as f:
        for line in f:
            try:
                e = json.loads(line)
            except:
                continue

            # Track timestamps
            ts = e.get('timestamp')
            if ts:
                if stats['first_ts'] is None:
                    stats['first_ts'] = ts
                stats['last_ts'] = ts

            msg = e.get('message', {})
            if not isinstance(msg, dict):
                continue

            usage = msg.get('usage')
            if not usage or not isinstance(usage, dict):
                continue

            # Skip synthetic entries
            model = msg.get('model', '')
            if model == '<synthetic>' or model.startswith('<'):
                continue

            if not stats['model'] and model:
                stats['model'] = model

            stats['turns'] += 1
            stats['input_tokens'] += usage.get('input_tokens', 0)
            stats['cache_read'] += usage.get('cache_read_input_tokens', 0)
            stats['cache_create'] += usage.get('cache_creation_input_tokens', 0)
            stats['output_tokens'] += usage.get('output_tokens', 0)

    stats['total'] = (stats['input_tokens'] + stats['cache_read']
                      + stats['cache_create'] + stats['output_tokens'])
    return stats

# T-2425: union JSONL discovery across all candidate dirs
if not jsonl_dirs:
    print(f"ERROR: No JSONL directory found (candidates: {jsonl_dirs_raw!r})", file=sys.stderr)
    sys.exit(1)

# Glob each dir, dedupe by basename (same session id in two dirs → one transcript;
# the newer mtime wins when sorted).
_files_by_basename = {}
for _d in jsonl_dirs:
    for _f in glob.glob(os.path.join(_d, '*.jsonl')):
        _bn = os.path.basename(_f)
        _existing = _files_by_basename.get(_bn)
        if _existing is None or os.path.getmtime(_f) > os.path.getmtime(_existing):
            _files_by_basename[_bn] = _f
files = sorted(_files_by_basename.values(), key=os.path.getmtime)

# Filter out agent transcripts
files = [f for f in files if not os.path.basename(f).startswith('agent-')]

if not files:
    print("No session transcripts found.", file=sys.stderr)
    sys.exit(1)

if mode == "session-detail" and session_id:
    # Find matching file
    match = [f for f in files if session_id in os.path.basename(f)]
    if not match:
        print(f"No session found matching '{session_id}'", file=sys.stderr)
        sys.exit(1)
    files = match[:1]

# Parse all sessions
sessions = []
for f in files:
    sessions.append(parse_session(f))

if mode == "summary":
    # Project totals
    total_turns = sum(s['turns'] for s in sessions)
    total_input = sum(s['input_tokens'] for s in sessions)
    total_cache_read = sum(s['cache_read'] for s in sessions)
    total_cache_create = sum(s['cache_create'] for s in sessions)
    total_output = sum(s['output_tokens'] for s in sessions)
    total_all = sum(s['total'] for s in sessions)

    print(f"\033[1m=== Token Usage Summary ===\033[0m")
    print(f"Sessions:         {len(sessions)}")
    print(f"Total turns:      {total_turns:,}")
    print()
    print(f"\033[1m{'Category':<25} {'Tokens':>15} {'%':>8}\033[0m")
    print(f"{'─' * 50}")
    if total_all > 0:
        print(f"{'Fresh input':<25} {fmt_tokens(total_input):>15} {total_input*100/total_all:>7.1f}%")
        print(f"{'Cache read':<25} {fmt_tokens(total_cache_read):>15} {total_cache_read*100/total_all:>7.1f}%")
        print(f"{'Cache create':<25} {fmt_tokens(total_cache_create):>15} {total_cache_create*100/total_all:>7.1f}%")
        print(f"{'Output':<25} {fmt_tokens(total_output):>15} {total_output*100/total_all:>7.1f}%")
        print(f"{'─' * 50}")
        print(f"\033[1m{'TOTAL':<25} {fmt_tokens(total_all):>15} {'100.0%':>8}\033[0m")
    print()
    print(f"Avg tokens/turn:  {fmt_tokens(total_all // max(total_turns, 1))}")
    print(f"Avg turns/session: {total_turns // max(len(sessions), 1):,}")

    # Date range
    first_dates = [s['first_ts'] for s in sessions if s['first_ts']]
    last_dates = [s['last_ts'] for s in sessions if s['last_ts']]
    if first_dates and last_dates:
        print(f"Date range:       {min(first_dates)[:10]} → {max(last_dates)[:10]}")

elif mode == "sessions":
    # Per-session table
    print(f"\033[1m{'Session':<10} {'Date':<12} {'Turns':>7} {'Input':>10} {'CacheRd':>10} {'CacheCr':>10} {'Output':>10} {'Total':>10} {'Size':>8}\033[0m")
    print(f"{'─' * 90}")
    for s in sessions:
        date = (s['first_ts'] or s['last_ts'] or '?')[:10]
        size_mb = s['file_size'] / (1024 * 1024)
        print(f"{s['id']:<10} {date:<12} {s['turns']:>7,} {fmt_tokens(s['input_tokens']):>10} {fmt_tokens(s['cache_read']):>10} {fmt_tokens(s['cache_create']):>10} {fmt_tokens(s['output_tokens']):>10} {fmt_tokens(s['total']):>10} {size_mb:>6.1f}MB")

    # Totals row
    print(f"{'─' * 90}")
    total_turns = sum(s['turns'] for s in sessions)
    print(f"\033[1m{'TOTAL':<10} {'':12} {total_turns:>7,} {fmt_tokens(sum(s['input_tokens'] for s in sessions)):>10} {fmt_tokens(sum(s['cache_read'] for s in sessions)):>10} {fmt_tokens(sum(s['cache_create'] for s in sessions)):>10} {fmt_tokens(sum(s['output_tokens'] for s in sessions)):>10} {fmt_tokens(sum(s['total'] for s in sessions)):>10}\033[0m")

elif mode == "session-detail":
    s = sessions[0]
    date = (s['first_ts'] or s['last_ts'] or '?')[:10]
    print(f"\033[1m=== Session {s['id_full'][:12]}... ===\033[0m")
    print(f"Date:       {s['first_ts'] or '?'} → {s['last_ts'] or '?'}")
    print(f"Model:      {s['model']}")
    print(f"File:       {s['file']}")
    print(f"File size:  {s['file_size'] / (1024*1024):.1f}MB")
    print(f"Turns:      {s['turns']:,}")
    print()
    print(f"\033[1m{'Category':<25} {'Tokens':>15} {'Raw':>15}\033[0m")
    print(f"{'─' * 55}")
    print(f"{'Fresh input':<25} {fmt_tokens(s['input_tokens']):>15} {s['input_tokens']:>15,}")
    print(f"{'Cache read':<25} {fmt_tokens(s['cache_read']):>15} {s['cache_read']:>15,}")
    print(f"{'Cache create':<25} {fmt_tokens(s['cache_create']):>15} {s['cache_create']:>15,}")
    print(f"{'Output':<25} {fmt_tokens(s['output_tokens']):>15} {s['output_tokens']:>15,}")
    print(f"{'─' * 55}")
    print(f"\033[1m{'TOTAL':<25} {fmt_tokens(s['total']):>15} {s['total']:>15,}\033[0m")
    print()
    if s['turns'] > 0:
        print(f"Avg input/turn:   {fmt_tokens((s['input_tokens'] + s['cache_read'] + s['cache_create']) // s['turns'])}")
        print(f"Avg output/turn:  {fmt_tokens(s['output_tokens'] // s['turns'])}")
        cache_pct = (s['cache_read'] * 100 / s['total']) if s['total'] > 0 else 0
        print(f"Cache hit rate:   {cache_pct:.1f}%")

elif mode == "current":
    # Current session = most recent JSONL by mtime
    s = sessions[-1]
    print(f"\033[1m=== Current Session ===\033[0m")
    print(f"Session:    {s['id']}")
    print(f"Turns:      {s['turns']:,}")
    print(f"Total:      {fmt_tokens(s['total'])} tokens")
    print(f"  Input:    {fmt_tokens(s['input_tokens'])}")
    print(f"  Cache Rd: {fmt_tokens(s['cache_read'])}")
    print(f"  Cache Cr: {fmt_tokens(s['cache_create'])}")
    print(f"  Output:   {fmt_tokens(s['output_tokens'])}")
    if s['turns'] > 0:
        print(f"Avg/turn:   {fmt_tokens(s['total'] // s['turns'])}")

PYEOF
}

# Entry point — called from bin/fw
costs_main() {
    local subcmd="${1:-summary}"
    shift 2>/dev/null || true

    local jsonl_dir
    jsonl_dir=$(_costs_jsonl_dir)

    case "$subcmd" in
        help|-h|--help)
            costs_help
            ;;
        summary|"")
            _costs_parse_all "$jsonl_dir" "summary"
            ;;
        session|sessions)
            local session_id="${1:-}"
            if [ -n "$session_id" ]; then
                _costs_parse_all "$jsonl_dir" "session-detail" "$session_id"
            else
                _costs_parse_all "$jsonl_dir" "sessions"
            fi
            ;;
        current)
            _costs_parse_all "$jsonl_dir" "current"
            ;;
        *)
            echo -e "${RED}Unknown costs subcommand: $subcmd${NC}" >&2
            costs_help >&2
            return 1
            ;;
    esac
}
