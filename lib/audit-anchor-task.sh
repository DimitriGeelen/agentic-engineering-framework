#!/bin/bash
# T-1856 anchor_task existence detection — extracted from agents/audit/audit.sh
# by T-3356 so the check is reachable without running the whole `--section
# structure` block.
#
# Why the extraction exists (T-3356 RCA): the check itself is ~20 lines and
# runs in milliseconds, but it lived inline inside a 2400-line section that also
# invokes `timeout 300 bats tests/lint/` (audit.sh check_invariant_suite). Any
# test that wanted to exercise the anchor rule had to pay for a full nested
# suite run, which put the file over 180s even against an empty fixture corpus
# and made its four failure-path tests read as reds when they were timeouts.
# Detection now lives here; audit.sh remains the sole emitter of warn/pass_over.
#
# Contract (unchanged from the inline original):
#   - Each .context/arcs/*.yaml may declare `anchor_task: T-XXX`.
#   - Missing/empty/`null` anchors are skipped silently and are NOT counted.
#   - A declared anchor that resolves to no file in .tasks/{active,completed}/
#     is a finding. WARN-only — never affects audit exit status.
#
# Output (TSV on stdout, stable and parseable):
#   MISSING\t<arc_name>\t<anchor_id>\t<arc_yaml_path>   (one per finding)
#   SUMMARY\t<checked_count>\t<missing_count>           (always last)

anchor_task_scan() {
    local root="${1:-$PROJECT_ROOT}"
    local checked=0 missing=0
    local af anchor arc_name

    if [ -d "$root/.context/arcs" ]; then
        for af in "$root/.context/arcs"/*.yaml; do
            [ -f "$af" ] || continue
            # Extract anchor_task value (single-line scalar). Tolerate quotes + null.
            anchor=$(awk -F': ' '/^anchor_task:/ {sub(/^anchor_task:[[:space:]]*/, ""); print; exit}' "$af" \
                     | tr -d ' "' \
                     | head -c 32)
            [ -z "$anchor" ] && continue
            [ "$anchor" = "null" ] && continue
            checked=$((checked + 1))
            if ! ls "$root"/.tasks/active/"$anchor"-*.md "$root"/.tasks/completed/"$anchor"-*.md 2>/dev/null | grep -q .; then
                arc_name=$(basename "$af" .yaml)
                printf 'MISSING\t%s\t%s\t%s\n' "$arc_name" "$anchor" "$af"
                missing=$((missing + 1))
            fi
        done
    fi
    printf 'SUMMARY\t%d\t%d\n' "$checked" "$missing"
}
