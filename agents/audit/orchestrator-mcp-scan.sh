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

# T-2154 (T-1761 build): --apply opt-in to auto-classify new tools by convention.
# Without --apply: classifier runs in advisory mode (auto_classified populated in
# LATEST.yaml, but baseline.yaml not mutated).
# With --apply:    if any new tools match the convention (termlink_agent_*,
# termlink_channel_*), they are written into baseline.yaml in-place with a .bak
# backup; baseline_count is bumped.
APPLY_MODE=0
for arg in "$@"; do
    case "$arg" in
        --apply) APPLY_MODE=1 ;;
        --help|-h) echo "Usage: $0 [--apply]"; exit 0 ;;
        *) echo "ERROR: unknown arg: $arg (use --apply or --help)" >&2; exit 2 ;;
    esac
done

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
export CURRENT_TOOLS CURRENT_GATED BASELINE LATEST SESSIONS_JSON APPLY_MODE
python3 - <<'PYEOF'
import yaml, sys, datetime, os, json, shutil

baseline_path = os.environ['BASELINE']
latest_path = os.environ['LATEST']
current_tools = {t for t in os.environ['CURRENT_TOOLS'].splitlines() if t}
current_gated = {t for t in os.environ['CURRENT_GATED'].splitlines() if t}
sessions_json = os.environ.get('SESSIONS_JSON', '') or ''
apply_mode = os.environ.get('APPLY_MODE', '0') == '1'

# T-2154 (T-1761 build): convention-based auto-classification for the two
# namespaces (termlink_agent_*, termlink_channel_*) with a 7-batch zero-
# misclassification track record (T-1755, T-1755 f/u, T-1760, T-1867, T-2073,
# T-2073 f/u, T-2150 — 196 tools, zero corrections). Convention encoded by
# all 7 batches: action-verb suffix → mutator; read-shape suffix → readonly.
# Outside these two namespaces, returns 'unknown' (bounded blast radius).
CONVENTION_NAMESPACES = ('termlink_agent_', 'termlink_channel_')
# Verb whitelist sourced from baseline-header annotations across 7 batches.
# Multi-word verbs (poll_start, poll_end, poll_vote, typing_emit) match the
# full suffix; single-word verbs match the LAST underscore-segment.
CONVENTION_MUTATOR_VERBS_SINGLE = frozenset({
    'post', 'send', 'broadcast', 'edit', 'react', 'pin', 'quote',
    'redact', 'reply', 'star', 'ack', 'forward', 'reauth',
})
CONVENTION_MUTATOR_VERBS_MULTI = frozenset({
    'poll_start', 'poll_end', 'poll_vote', 'typing_emit',
})

def classify_by_convention(name: str) -> str:
    """Return one of {'mutators_ungated', 'readonly_exempt', 'unknown'}.

    'unknown' means the convention does not cover this tool — manual review
    still required (out of T-1761's GO scope). The two in-scope namespaces
    are the ones with the verified 7-batch track record; classifying tools
    in 'termlink_fleet_*' / 'termlink_hub_*' / 'termlink_tofu_*' / etc. by
    the same verb-list IS sound for the batches we've seen, but T-1761 chose
    the bounded-blast-radius shape — extending to other namespaces is a
    separate follow-up decision.
    """
    matched_ns = None
    for ns in CONVENTION_NAMESPACES:
        if name.startswith(ns):
            matched_ns = ns
            break
    if matched_ns is None:
        return 'unknown'
    suffix = name[len(matched_ns):]
    if not suffix:
        return 'unknown'
    # Multi-word verbs first (longest-match wins).
    for verb in CONVENTION_MUTATOR_VERBS_MULTI:
        if suffix == verb or suffix.endswith('_' + verb):
            return 'mutators_ungated'
    # Single-word verb: match the LAST underscore-delimited segment.
    last_seg = suffix.rsplit('_', 1)[-1]
    if last_seg in CONVENTION_MUTATOR_VERBS_SINGLE:
        return 'mutators_ungated'
    return 'readonly_exempt'

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

new_tools_raw = sorted(current_tools - bl_known)
removed_tools = sorted(bl_known - current_tools)
gate_drop_outs = sorted(bl_gated - current_gated)
gate_added = sorted(current_gated - bl_gated)
ratchet_candidates = sorted(set(gate_added) & bl_mutators_ungated)

# T-2154: partition new_tools via the convention classifier BEFORE the WARN.
# Only 'still_unclassified' (out-of-namespace or empty-suffix) drives the
# manual-review WARN; auto-classifiable tools are listed in a separate
# advisory field (and optionally applied to baseline when --apply is set).
auto_mutators = []
auto_readonly = []
still_unclassified = []
for t in new_tools_raw:
    verdict = classify_by_convention(t)
    if verdict == 'mutators_ungated':
        auto_mutators.append(t)
    elif verdict == 'readonly_exempt':
        auto_readonly.append(t)
    else:
        still_unclassified.append(t)

status = "pass"
exit_code = 0
warnings = []
errors = []
apply_result = None  # populated below if apply_mode and there's something to apply

if gate_drop_outs:
    errors.append(f"REGRESSION: {len(gate_drop_outs)} tool(s) lost their check_task_governance call: {', '.join(gate_drop_outs)}")
    status = "fail"
    exit_code = 2

# T-2154: --apply rewrites baseline.yaml if any auto-classifiable tools.
# Done BEFORE the still-unclassified WARN check so the post-apply state is
# what counts toward the scan exit code on subsequent passes.
if apply_mode and (auto_mutators or auto_readonly):
    backup_path = baseline_path + '.bak'
    shutil.copy2(baseline_path, backup_path)
    baseline['mutators_ungated']['tools'] = sorted(set(baseline['mutators_ungated']['tools']) | set(auto_mutators))
    baseline['readonly_exempt']['tools'] = sorted(set(baseline['readonly_exempt']['tools']) | set(auto_readonly))
    new_count = (
        len(baseline['gated']['tools'])
        + len(baseline['mutators_ungated']['tools'])
        + len(baseline['readonly_exempt']['tools'])
    )
    prev_count = baseline['baseline_count']
    baseline['baseline_count'] = new_count
    baseline['last_verified'] = datetime.date.today().isoformat()
    # Re-emit YAML preserving the leading comment header. We can't trivially
    # round-trip arbitrary YAML comments with yaml.safe_dump — read the header
    # comment block (everything before the first non-comment non-blank line)
    # and prepend it back.
    with open(baseline_path) as f:
        original = f.read()
    header_lines = []
    for line in original.splitlines(True):
        if line.startswith('#') or line.strip() == '':
            header_lines.append(line)
        else:
            break
    # Append a fresh T-2154 stamp at the end of the header block.
    stamp = (
        f"# Update {datetime.date.today().isoformat()} (T-2154): convention "
        f"auto-classification applied via --apply. "
        f"+{len(auto_mutators)} mutators, +{len(auto_readonly)} readonly. "
        f"Baseline {prev_count} → {new_count}. "
        f"T-1761 verb whitelist canonical (see orchestrator-mcp-scan.sh classify_by_convention).\n"
    )
    header_lines.append(stamp)
    body = yaml.safe_dump(baseline, default_flow_style=False, sort_keys=False)
    with open(baseline_path, 'w') as f:
        f.write(''.join(header_lines))
        f.write(body)
    apply_result = {
        'applied_mutators': auto_mutators,
        'applied_readonly': auto_readonly,
        'baseline_prev': prev_count,
        'baseline_new': new_count,
        'backup_path': backup_path,
    }
    # After applying, these tools are no longer "new" — the next scan will
    # see them in the baseline. Surface this in the current run's summary.
    auto_mutators_applied, auto_readonly_applied = auto_mutators, auto_readonly
    auto_mutators, auto_readonly = [], []

if still_unclassified:
    warnings.append(f"NEW: {len(still_unclassified)} unclassified tool(s) (manual review needed — outside T-1761 convention scope): {', '.join(still_unclassified)}")
    if exit_code == 0:
        status = "warn"; exit_code = 1

# Auto-classified-but-not-applied is advisory only (NOT a WARN — point of T-1761
# is to remove this noise). Surface in stdout so an operator running by hand
# can `--apply` next time if they like the classification.
if auto_mutators or auto_readonly:
    # status/exit_code intentionally NOT mutated — this is the "convention
    # handled it" path; no manual review needed.
    pass

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
        # T-2154: 'new_unclassified_tools' now means tools the convention does
        # NOT handle (out-of-namespace or empty suffix). Pre-T-2154 it meant
        # ALL new tools — the rename is intentional, kept under the original
        # key for downstream consumer compatibility.
        'new_unclassified_tools': still_unclassified,
        'gate_drop_outs': gate_drop_outs,
        'gate_added_ratchet_candidates': ratchet_candidates,
        'removed_tools': removed_tools,
        'tag_format_warnings': tag_format_warnings,
        # T-2154: advisory — auto-classified by convention this run. Empty
        # after a successful --apply (those tools have been written into the
        # baseline already; see apply_result for what landed).
        'auto_classified': {
            'mutators_ungated': auto_mutators,
            'readonly_exempt': auto_readonly,
        },
    },
    # T-2154: present only when --apply ran AND there was something to apply.
    'apply_result': apply_result,
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
# T-2154: surface auto-classification activity even when there are no WARNs.
if apply_result:
    am = len(apply_result['applied_mutators'])
    ar = len(apply_result['applied_readonly'])
    print(f"  APPLIED: +{am} mutator(s), +{ar} readonly via convention (baseline {apply_result['baseline_prev']} → {apply_result['baseline_new']}, backup: {apply_result['backup_path']})")
elif auto_mutators or auto_readonly:
    print(f"  AUTO-CLASSIFIABLE: {len(auto_mutators)} mutator(s), {len(auto_readonly)} readonly by convention (advisory — pass --apply to write into baseline)")
for w in warnings:
    print(f"  WARN: {w}")
for e in errors:
    print(f"  FAIL: {e}", file=sys.stderr)
print()
print(f"Report: {latest_path}")
sys.exit(exit_code)
PYEOF
