#!/usr/bin/env bash
# lib/audit_emit.sh — T-2353 (T-2352 Slice 1)
#
# Convert audit WARN/FAIL findings into tracked bugfix tasks, deduplicated by
# sha1(normalized finding text). Sourced by agents/audit/audit.sh when the
# operator passes `--emit-tasks` (opt-in, default OFF until S3 digest calibration).
#
# Factored out as a sourceable lib (not inlined in audit.sh) so bats can drive it
# with fixtures — running the real `fw audit` takes >5 minutes, far too slow for a
# unit test. The function consumes a findings FILE (one `LEVEL|TEXT|MITIGATION|SECTION`
# per line) rather than audit.sh's in-memory FINDINGS array, which makes it testable
# in isolation.
#
# Design note (T-2353 §Evolution): the originating spec said `workflow_type=bugfix`,
# but `bugfix` is not a valid workflow_type (lib/enums.sh: specification design build
# test refactor decommission inception). We file `--type build` with a bug-class title
# ("audit warn/fail: …") + `audit-finding` tags, which is exactly what trips the
# T-1550 RCA gate at close — the behaviour the spec wanted ("reuses existing T-1550
# RCA gate at close").

# Normalize finding text for a stable hash across runs: lowercase, replace digit runs
# with N, collapse path-like tokens, squeeze whitespace. The finding CLASS is the
# dedupe unit — "14 stale tasks" and "12 stale tasks" must hash identically so a
# fluctuating count does not spawn a fresh task every audit run.
_audit_norm_finding() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's#/[^ |]+#PATH#g; s/[0-9]+/N/g; s/[[:space:]]+/ /g; s/^ //; s/ $//'
}

_audit_finding_hash() {
    _audit_norm_finding "$1" | sha1sum | cut -d' ' -f1
}

# Slugify a section name into a tag-safe token.
_audit_section_slug() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# Already filed? Scan active + completed task frontmatter for the dedupe key.
_audit_finding_already_filed() {
    local hash="$1" tasks_dir="$2"
    grep -rqlE "^audit_finding_hash: ${hash}\$" \
        "$tasks_dir/active" "$tasks_dir/completed" 2>/dev/null
}

# Insert dedupe key + severity + run timestamp into a freshly created task's
# frontmatter (create-task.sh has no flag for custom fields). Anchored after the
# unique `id:` line.
_audit_inject_frontmatter() {
    local file="$1" hash="$2" sev="$3" ts="$4"
    awk -v h="$hash" -v s="$sev" -v t="$ts" '
        /^id:/ && !injected {
            print
            print "audit_finding_hash: " h
            print "audit_severity: " s
            print "audit_run_ts: " t
            injected=1
            next
        }
        { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# audit_emit_findings_as_tasks <findings_file> <dry_run:true|false>
#
# Env (with fallbacks): FW_BIN (bin/fw), PROJECT_ROOT (pwd), TASKS_DIR
# ($PROJECT_ROOT/.tasks), AUDIT_TIMESTAMP (now). Prints a per-finding line and a
# trailing "audit-emit: created=N skipped=M" summary. Returns 0.
audit_emit_findings_as_tasks() {
    local findings_file="$1" dry_run="${2:-false}"
    local fw_bin="${FW_BIN:-bin/fw}"
    local proj="${PROJECT_ROOT:-$(pwd)}"
    local tasks_dir="${TASKS_DIR:-$proj/.tasks}"
    local ts="${AUDIT_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
    local created=0 skipped=0

    if [ ! -f "$findings_file" ]; then
        echo "audit-emit: no findings file ($findings_file) — nothing to emit"
        return 0
    fi

    local level text mitigation sectionname
    while IFS='|' read -r level text mitigation sectionname; do
        case "$level" in WARN|FAIL) ;; *) continue ;; esac
        [ -n "$text" ] || continue

        local hash sev secslug title
        hash=$(_audit_finding_hash "$text")
        sev=$(printf '%s' "$level" | tr '[:upper:]' '[:lower:]')
        secslug=$(_audit_section_slug "$sectionname")
        title="audit ${sev}: ${text}"

        if _audit_finding_already_filed "$hash" "$tasks_dir"; then
            skipped=$((skipped + 1))
            [ "$dry_run" = true ] && echo "would skip (already filed): [$level] $text  (hash ${hash:0:8})"
            continue
        fi

        if [ "$dry_run" = true ]; then
            echo "would create: [severity:${sev}] [section:${secslug:-none}] ${title}  (hash ${hash:0:8})"
            created=$((created + 1))
            continue
        fi

        local tags desc out tid tf
        tags="audit-finding,severity:${sev}"
        [ -n "$secslug" ] && tags="${tags},section:${secslug}"
        desc="Audit ${level} finding (auto-filed by 'fw audit --emit-tasks' at ${ts}). Section: ${sectionname:-n/a}. Mitigation hint: ${mitigation:-none}"

        out=$("$fw_bin" task create --name "$title" --description "$desc" \
            --type build --tags "$tags" --horizon now 2>&1)
        tid=$(printf '%s' "$out" | grep -oE 'T-[0-9]+' | head -1)
        if [ -z "$tid" ]; then
            echo "audit-emit: WARN could not create task for: $text" >&2
            printf '%s\n' "$out" | head -3 >&2
            continue
        fi
        tf=$(ls "$tasks_dir"/active/"${tid}"-*.md 2>/dev/null | head -1)
        [ -n "$tf" ] && _audit_inject_frontmatter "$tf" "$hash" "$sev" "$ts"
        echo "created ${tid}: ${title}  (hash ${hash:0:8})"
        created=$((created + 1))
    done < "$findings_file"

    echo "audit-emit: created=${created} skipped=${skipped} (dry_run=${dry_run})"
    return 0
}
