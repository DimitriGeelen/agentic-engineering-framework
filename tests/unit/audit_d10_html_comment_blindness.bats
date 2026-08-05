#!/usr/bin/env bats
# T-1889: D10 audit must ignore HTML-comment-only Human AC sections.
#
# D10 (Decision-without-Dialogue) flags inception/spec tasks where Human ACs
# exist but none are checked. Until T-1889 the counter ran naked .count("[ ]")
# against the section body, also counting checkboxes inside <!-- ... --> template
# stubs. Result: every task whose `### Human` section was only the template
# example fired D10 falsely. Origin: T-1455.
#
# Pattern matches the canonical strip in lib/inception.sh:517 (sed /<!--/,/-->/d).

load ../test_helper

# Helper: build a minimal completed-task file with a parameterised Human section.
# Args: $1=task_id, $2=human_section_body, $3=date_finished
mk_task() {
    local task_id="$1" body="$2" finished="$3"
    local file="$TEST_TEMP_DIR/${task_id}.md"
    cat > "$file" <<EOF
---
id: ${task_id}
name: "test"
description: "test"
status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: []
related_tasks: []
created: 2026-05-01T00:00:00Z
last_update: ${finished}
date_finished: ${finished}
---

# ${task_id}: test

## Context

test.

## Acceptance Criteria

### Agent
- [x] done

### Human
${body}

## Verification
EOF
    echo "$file"
}

run_d10_python() {
    # Run the D10 Python block stand-alone against a single task file.
    local task_file="$1"
    PROJECT_ROOT="$(dirname "$task_file")"
    guard_project_root
    mkdir -p "$PROJECT_ROOT/.tasks/completed"
    mv "$task_file" "$PROJECT_ROOT/.tasks/completed/"
    PROJECT_ROOT="$PROJECT_ROOT" python3 <<'PY'
import yaml, glob, os, re
from datetime import datetime, timedelta, timezone

PROJECT_ROOT = os.environ.get("PROJECT_ROOT", ".")
TASKS_DIR = os.path.join(PROJECT_ROOT, ".tasks", "completed")
cutoff = datetime.now(timezone.utc) - timedelta(days=30)

def parse_frontmatter(path):
    try:
        content = open(path).read()
        m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if m:
            return yaml.safe_load(m.group(1)) or {}
    except Exception:
        pass
    return {}

def parse_ts(s):
    if not s or s == "null":
        return None
    try:
        ts = datetime.fromisoformat(str(s).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts
    except (ValueError, TypeError):
        return None

flagged = []
for f in glob.glob(os.path.join(TASKS_DIR, "T-*.md")):
    fm = parse_frontmatter(f)
    finished = parse_ts(fm.get("date_finished"))
    if not finished or finished < cutoff:
        continue
    owner = fm.get("owner", "")
    wtype = fm.get("workflow_type", "")
    if owner != "human" or wtype not in ("inception", "specification"):
        continue
    content = open(f).read()
    human_section = re.search(r'### Human\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
    if not human_section:
        continue
    human_text = human_section.group(1)
    # T-1889: strip HTML comment blocks before counting
    human_text = re.sub(r'<!--.*?-->', '', human_text, flags=re.DOTALL)
    checked = human_text.count("[x]")
    unchecked = human_text.count("[ ]")
    if unchecked > 0 and checked == 0:
        tid = fm.get("id", "?")
        flagged.append(tid)

print("FLAGGED:" + ",".join(flagged) if flagged else "CLEAN")
PY
}

@test "T-1889: template-stub Human section (comments only) does not fire D10" {
    body='<!-- example block:
       - [ ] [REVIEW] Dashboard renders correctly
         Steps: do things
    -->'
    file=$(mk_task "T-9001" "$body" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    result=$(run_d10_python "$file")
    [ "$result" = "CLEAN" ]
}

@test "T-1889: real unchecked Human AC outside comments fires D10" {
    body='- [ ] [REVIEW] Approve the decision
  Steps: read findings'
    file=$(mk_task "T-9002" "$body" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    result=$(run_d10_python "$file")
    [[ "$result" == *"T-9002"* ]]
}

@test "T-1889: checked Human AC does not fire D10" {
    body='- [x] [REVIEW] Approved'
    file=$(mk_task "T-9003" "$body" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    result=$(run_d10_python "$file")
    [ "$result" = "CLEAN" ]
}

@test "T-1889: real AC outside + comment-stub above does not double-count" {
    body='<!-- example:
       - [ ] [REVIEW] sample
    -->
- [x] [REVIEW] Real and ticked'
    file=$(mk_task "T-9004" "$body" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    result=$(run_d10_python "$file")
    [ "$result" = "CLEAN" ]
}
