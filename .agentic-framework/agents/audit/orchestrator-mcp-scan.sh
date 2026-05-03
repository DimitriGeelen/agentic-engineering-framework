#!/bin/bash
# orchestrator-mcp-scan.sh — drift defense for MCP-tool task_id enforcement
# T-1646 (Arc C drift defense, parented under T-1644, originating in T-1641)
#
# Detects: new MCP tools added without check_task_governance() gate; gated tools
# losing their gate; mutators_ungated growing instead of shrinking.
#
# Strategy: probe /opt/termlink via TermLink (cross-repo policy per T-559) or
# direct read when running on the host that owns the repo. Inventory tools.rs
# `name = "termlink_*"` entries, classify against the baseline, emit YAML summary.
#
# Exit codes:
#   0  baseline match
#   1  drift: new unclassified tools (manual classification needed) or ratchet candidates
#   2  regression: gated count dropped (a tool lost its check_task_governance call)

set -euo pipefail

FRAMEWORK_ROOT="${PROJECT_ROOT:-${FW_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
BASELINE="$FRAMEWORK_ROOT/.context/audits/orchestrator-mcp-baseline.yaml"
LATEST="$FRAMEWORK_ROOT/.context/audits/orchestrator-LATEST.yaml"
TERMLINK_REPO="${FW_TERMLINK_REPO:-/opt/termlink}"
TERMLINK_AGENT="${FW_TERMLINK_AGENT:-framework-agent}"

if [ ! -f "$BASELINE" ]; then
  echo "ERROR: baseline not found at $BASELINE" >&2
  echo "Run T-1646 setup: file should ship with the framework." >&2
  exit 2
fi

# Probe /opt/termlink — prefer direct read (no TermLink stale-buffer issues), fall
# back to TermLink interact when the repo isn't directly readable from this host.
probe_via_direct_read() {
  if [ -d "$TERMLINK_REPO/crates/termlink-mcp/src" ] && [ -r "$TERMLINK_REPO/crates/termlink-mcp/src/tools.rs" ]; then
    return 0
  fi
  return 1
}

probe_tools() {
  if probe_via_direct_read; then
    grep -rEh 'name\s*=\s*"termlink_[a-z_]+"' "$TERMLINK_REPO/crates/termlink-mcp/src/" \
      | grep -oE 'termlink_[a-z_]+' | sort -u
  else
    local cmd
    cmd='grep -rEh "name\s*=\s*\"termlink_[a-z_]+\"" '"$TERMLINK_REPO"'/crates/termlink-mcp/src/ | grep -oE "termlink_[a-z_]+" | sort -u'
    termlink interact "$TERMLINK_AGENT" "$cmd" --json --timeout 30 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('output',''),end='')" \
      | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' \
      | grep -E '^termlink_' || true
  fi
}

probe_gate_calls() {
  if probe_via_direct_read; then
    grep -rE 'check_task_governance\(.+"termlink_[a-z_]+"' "$TERMLINK_REPO/crates/termlink-mcp/src/tools.rs" \
      | grep -oE '"termlink_[a-z_]+"' | tr -d '"' | sort -u
  else
    local cmd
    cmd='grep -rE "check_task_governance\(.+\"termlink_[a-z_]+\"" '"$TERMLINK_REPO"'/crates/termlink-mcp/src/tools.rs | grep -oE "\"termlink_[a-z_]+\"" | tr -d "\"" | sort -u'
    termlink interact "$TERMLINK_AGENT" "$cmd" --json --timeout 30 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('output',''),end='')" \
      | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' \
      | grep -E '^termlink_' || true
  fi
}

CURRENT_TOOLS=$(probe_tools)
if [ -z "$CURRENT_TOOLS" ]; then
  echo "ERROR: probe returned empty tool list — TERMLINK_REPO=$TERMLINK_REPO unreachable" >&2
  exit 2
fi

CURRENT_GATED=$(probe_gate_calls)

# T-1649: also pull live TermLink sessions for tag-format lint. Bounded; degrades silently.
probe_sessions_json() {
  if ! command -v termlink >/dev/null 2>&1; then
    echo ""
    return 0
  fi
  timeout 4 termlink list --json 2>/dev/null || echo ""
}
SESSIONS_JSON=$(probe_sessions_json)

# Run classification in Python (yaml + set ops are easier than bash)
export CURRENT_TOOLS CURRENT_GATED BASELINE LATEST SESSIONS_JSON
python3 - <<'PYEOF'
import yaml, sys, datetime, os, json

baseline_path = os.environ['BASELINE']
latest_path = os.environ['LATEST']
current_tools = {t for t in os.environ['CURRENT_TOOLS'].splitlines() if t}
current_gated = {t for t in os.environ['CURRENT_GATED'].splitlines() if t}
sessions_json = os.environ.get('SESSIONS_JSON', '') or ''

# T-1649: tag-format lint.
# Canonical orchestrator routing prefixes (mirrors web/blueprints/orchestrator.py
# _TAG_PREFIXES). When live sessions carry near-misses (wrong separator, typo),
# orchestrator routing silently falls through to defaults — the W08 / T-1641 symptom.
CANONICAL_PREFIXES = (
    "task-type:", "role:", "task:", "model:",  # colon-separated (routing-relevant)
    "host=", "project=",                        # equals-separated (host metadata)
)
# Hard-coded common drifts (cheap heuristic; avoids Levenshtein dependency).
KNOWN_DRIFT_MAP = {
    "task=": "task:",
    "role=": "role:",
    "model=": "model:",
    "task-type=": "task-type:",
    "host:": "host=",
    "project:": "project=",
    "tasktype:": "task-type:",
    "task_type:": "task-type:",
    "tasktype=": "task-type:",
    "task_type=": "task-type:",
}

def _tag_prefix(tag: str) -> str | None:
    """Extract the prefix (incl. separator) of a tag if it has one; else None."""
    for sep in (':', '='):
        if sep in tag:
            return tag.split(sep, 1)[0] + sep
    return None

tag_format_warnings = []
sessions_total = 0
sessions_err = None
if sessions_json:
    try:
        sessions = json.loads(sessions_json).get('sessions', []) or []
        sessions_total = len(sessions)
        from collections import Counter
        bad_counter: Counter[str] = Counter()
        sample_sessions: dict[str, list[str]] = {}  # bad_prefix -> [session names]
        for s in sessions:
            sname = s.get('display_name') or s.get('name') or s.get('id', '?')
            for tag in s.get('tags', []) or []:
                prefix = _tag_prefix(tag)
                if not prefix:
                    continue
                if prefix in CANONICAL_PREFIXES:
                    continue
                bad_counter[prefix] += 1
                sample_sessions.setdefault(prefix, [])
                if len(sample_sessions[prefix]) < 3 and sname not in sample_sessions[prefix]:
                    sample_sessions[prefix].append(sname)
        for bad_prefix, count in sorted(bad_counter.items(), key=lambda x: (-x[1], x[0])):
            suggestion = KNOWN_DRIFT_MAP.get(bad_prefix)
            tag_format_warnings.append({
                'bad': bad_prefix,
                'count': count,
                'suggested': suggestion,
                'sample_sessions': sample_sessions.get(bad_prefix, []),
            })
    except (json.JSONDecodeError, ValueError) as exc:
        sessions_err = f"sessions json parse: {exc}"
elif not sessions_json:
    sessions_err = "termlink list unavailable"

with open(baseline_path) as f:
    baseline = yaml.safe_load(f)

bl_gated = set(baseline['gated']['tools'])
bl_mutators_ungated = set(baseline['mutators_ungated']['tools'])
bl_readonly = set(baseline['readonly_exempt']['tools'])
bl_known = bl_gated | bl_mutators_ungated | bl_readonly

new_tools = sorted(current_tools - bl_known)
removed_tools = sorted(bl_known - current_tools)
gate_drop_outs = sorted(bl_gated - current_gated)
gate_added = sorted(current_gated - bl_gated)
ratchet_candidates = sorted(set(gate_added) & bl_mutators_ungated)

status = "pass"
exit_code = 0
warnings = []
errors = []

if gate_drop_outs:
    errors.append(f"REGRESSION: {len(gate_drop_outs)} tool(s) lost their check_task_governance call: {', '.join(gate_drop_outs)}")
    status = "fail"
    exit_code = 2

if new_tools:
    warnings.append(f"NEW: {len(new_tools)} unclassified tool(s) (manual review needed): {', '.join(new_tools)}")
    if exit_code == 0:
        status = "warn"; exit_code = 1

if ratchet_candidates:
    warnings.append(f"RATCHET: {len(ratchet_candidates)} mutator(s) gained a governance gate — move from mutators_ungated to gated in baseline: {', '.join(ratchet_candidates)}")
    if exit_code == 0:
        status = "warn"; exit_code = 1

if removed_tools:
    warnings.append(f"REMOVED: {len(removed_tools)} tool(s) gone from /opt/termlink (likely renamed or T-1166 deprecation completed): {', '.join(removed_tools)}")

if tag_format_warnings:
    drift_summary = ", ".join(f"{w['bad']}({w['count']})" for w in tag_format_warnings)
    warnings.append(f"TAG-FORMAT-DRIFT: {len(tag_format_warnings)} non-canonical tag prefix(es) in live sessions: {drift_summary}")
    if exit_code == 0:
        status = "warn"; exit_code = 1

result = {
    'audit': 'orchestrator-mcp-scan',
    'task': 'T-1646',
    'parent_arc': 'T-1644',
    'origin': 'T-1641',
    'last_run': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
    'baseline_count': baseline['baseline_count'],
    'current_count': len(current_tools),
    'gated_baseline': len(bl_gated),
    'gated_current': len(current_gated),
    'mutators_ungated_baseline': len(bl_mutators_ungated),
    'readonly_exempt_baseline': len(bl_readonly),
    'status': status,
    'exit_code': exit_code,
    'findings': {
        'new_unclassified_tools': new_tools,
        'gate_drop_outs': gate_drop_outs,
        'gate_added_ratchet_candidates': ratchet_candidates,
        'removed_tools': removed_tools,
        'tag_format_warnings': tag_format_warnings,
    },
    'sessions_scanned': sessions_total,
    'sessions_probe_error': sessions_err,
    'warnings': warnings,
    'errors': errors,
}

with open(latest_path, 'w') as f:
    yaml.safe_dump(result, f, default_flow_style=False, sort_keys=False)

print(f"=== orchestrator-mcp-scan ({status}) ===")
print(f"Tools: {len(current_tools)} (baseline {baseline['baseline_count']})")
print(f"Gated: {len(current_gated)} (baseline {len(bl_gated)})")
print(f"Mutators ungated (baseline): {len(bl_mutators_ungated)}")
print(f"Readonly exempt (baseline): {len(bl_readonly)}")
if sessions_total:
    print(f"Sessions scanned (tag-lint): {sessions_total}")
elif sessions_err:
    print(f"Sessions scanned (tag-lint): SKIPPED ({sessions_err})")
print()
for w in warnings:
    print(f"  WARN: {w}")
for e in errors:
    print(f"  FAIL: {e}", file=sys.stderr)
print()
print(f"Report: {latest_path}")
sys.exit(exit_code)
PYEOF
