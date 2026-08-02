#!/usr/bin/env bats
# T-2731 — frontmatter extraction must be scoped to the frontmatter and must not
# truncate multi-line scalars.
#
# Origin OBS-129: .context/episodic/T-100202.yaml was unparseable. Its task file
# has a body line beginning `name:` at line 248, and the generator extracted
# fields with `grep "^name:" "$task_file"` — which matches the WHOLE FILE. Two
# lines came back, so the emitted `task_name: "…"` scalar spanned lines.
#
# The same bespoke grep also kept only the first physical line, so every
# multi-line name was silently truncated mid-sentence and every folded
# description collapsed to a bare `>`. That half never raised — it just quietly
# wrote the wrong value.
#
# Fix: episodic.sh uses the shared lib/yaml.sh:get_yaml_field, and that helper is
# frontmatter-scoped and folds continuation lines with a single space (which is
# what YAML means by a line break inside a folded or double-quoted scalar).

load ../test_helper

_yaml() { source "$FRAMEWORK_ROOT/lib/yaml.sh"; get_yaml_field "$1" "$2"; }

_fixture() {
    local f="$TEST_TEMP_DIR/task.md"
    cat > "$f" <<'TASK'
---
id: T-9997
name: "a name that is long enough to wrap and therefore spans
  two physical lines"
description: >
  folded description content
status: work-completed
workflow_type: build
owner: agent
tags: [alpha, beta]
---

# T-9997

## Context

The body quotes a frontmatter block from another task:

name: "a decoy that must not be extracted"
status: captured
TASK
    echo "$f"
}

@test "T-2731: a multi-line name folds to one line with a single space" {
    local f; f="$(_fixture)"
    run _yaml "$f" name
    [ "$status" -eq 0 ]
    [ "$output" = "a name that is long enough to wrap and therefore spans two physical lines" ]
}

@test "T-2731: a body line beginning name: is not extracted" {
    local f; f="$(_fixture)"
    run _yaml "$f" name
    [[ "$output" != *"decoy"* ]]
}

@test "T-2731: a body key absent from frontmatter yields nothing, not the body's" {
    # `status` IS in frontmatter, so head -1 would have masked the bug. This
    # checks the case the old implementation actually got wrong: a field the
    # frontmatter does not define must not be answered from the body.
    local f; f="$TEST_TEMP_DIR/nostatus.md"
    cat > "$f" <<'TASK'
---
id: T-9996
name: "no status here"
---

horizon: later
TASK
    run _yaml "$f" horizon
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2731: a folded block scalar returns its content, not the > indicator" {
    local f; f="$(_fixture)"
    run _yaml "$f" description
    [ "$output" = "folded description content" ]
}

@test "T-2731: single-line fields are unchanged" {
    local f; f="$(_fixture)"
    [ "$(_yaml "$f" id)" = "T-9997" ]
    [ "$(_yaml "$f" status)" = "work-completed" ]
    [ "$(_yaml "$f" workflow_type)" = "build" ]
    [ "$(_yaml "$f" owner)" = "agent" ]
    [ "$(_yaml "$f" tags)" = "[alpha, beta]" ]
}

@test "T-2731: a missing field returns empty and exit 0 (pipefail-safe, L-302)" {
    local f; f="$(_fixture)"
    run _yaml "$f" no_such_field
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "T-2731 guard: episodic.sh extracts no frontmatter field by bare grep" {
    # Source-derived, no allowlist (L-533). The defect was six hand-rolled
    # `grep "^field:"` extractions living beside a shared helper written to
    # replace exactly them. A seventh must not be addable in silence.
    run grep -nE 'grep "\^[a-z_]+:" "\$task_file"' \
        "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh"
    [ "$status" -ne 0 ] || {
        echo "bespoke frontmatter grep(s) still present:" >&2
        echo "$output" >&2
        false
    }
}

@test "T-2731 guard control: the guard detects a reintroduced bare grep" {
    local copy="$TEST_TEMP_DIR/regressed.sh"
    cp "$FRAMEWORK_ROOT/agents/context/lib/episodic.sh" "$copy"
    printf '    local x=$(grep "^owner:" "$task_file" | sed "s/owner: //")\n' >> "$copy"
    run grep -nE 'grep "\^[a-z_]+:" "\$task_file"' "$copy"
    [ "$status" -eq 0 ]
}

@test "T-2731: episodic.sh works when sourced without lib/paths.sh" {
    # It used to rely on its caller having sourced the helper chain.
    # context.sh does; tests/unit/context_episodic.bats sources this file
    # directly and did not — so every field came back empty and only a
    # downstream grep assertion noticed.
    run bash -c "
        set -e
        export FRAMEWORK_ROOT='$FRAMEWORK_ROOT'
        source '$FRAMEWORK_ROOT/agents/context/lib/episodic.sh'
        declare -F get_yaml_field >/dev/null
        echo available
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"available"* ]]
}

@test "T-2731: the whole episodic corpus parses, with no exclusions" {
    # T-2729's version of this test excluded T-100202 by name. That exclusion is
    # gone: if it needs to come back, something regressed.
    run python3 - "$FRAMEWORK_ROOT" <<'PY'
import glob, os, sys, yaml
bad = []
for f in sorted(glob.glob(os.path.join(sys.argv[1], ".context/episodic/*.yaml"))):
    try:
        yaml.safe_load(open(f))
    except Exception as e:
        bad.append((os.path.basename(f), str(e).splitlines()[0][:70]))
if bad:
    sys.exit("unparseable episodics: %r" % bad)
print("corpus clean")
PY
    [ "$status" -eq 0 ]
}
