#!/bin/bash
# Git Agent - Hook installation subcommand

do_install_hooks() {
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force=true
                shift
                ;;
            -h|--help)
                show_hooks_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done

    check_git_repo

    local hooks_dir="$PROJECT_ROOT/.git/hooks"
    local commit_msg_hook="$hooks_dir/commit-msg"
    local pre_commit_hook="$hooks_dir/pre-commit"
    local post_commit_hook="$hooks_dir/post-commit"
    local pre_push_hook="$hooks_dir/pre-push"

    # Check if hooks exist
    if [ -f "$commit_msg_hook" ] && [ "$force" = false ]; then
        local existing_version
        existing_version=$(grep "^# VERSION=" "$commit_msg_hook" 2>/dev/null | cut -d= -f2)
        if [ "$existing_version" = "$VERSION" ]; then
            echo -e "${GREEN}Hooks already installed (version $VERSION)${NC}"
            echo "Use --force to reinstall"
            exit 0
        else
            echo -e "${YELLOW}Updating hooks from version $existing_version to $VERSION${NC}"
        fi
    fi

    # Create commit-msg hook
    # PL-078: install-hooks short-circuits on the commit-msg `# VERSION=`
    # marker alone (see line ~32-42). When you change content of ANY hook
    # (commit-msg, post-commit, pre-push), bump the commit-msg marker too
    # so consumers' next install-hooks call redeploys all three. Without
    # the bump, your fix sits in the template indefinitely and deployed
    # hooks stay stale (T-1252 sat dormant on /opt/termlink and
    # /opt/999-AEF for unknown days, surfacing only as fw doctor warnings).
    cat > "$commit_msg_hook" << 'HOOK_EOF'
#!/bin/bash
# commit-msg hook - Task Reference Enforcement
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.9

COMMIT_MSG_FILE="$1"
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Allow merge commits (no task ref required)
if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    exit 0
fi

# Allow rebase commits
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    exit 0
fi

# Check for task reference
if ! echo "$COMMIT_MSG" | grep -qE "T-[0-9]+"; then
    echo ""
    echo "ERROR: No task reference found in commit message"
    echo ""
    echo "Your message: $COMMIT_MSG"
    echo ""
    echo "To fix:"
    echo "  1. Add task reference: git commit -m \"T-XXX: your message\""
    echo "  2. Create a task: ./agents/task-create/create-task.sh"
    echo ""
    echo "Bypass: git commit --no-verify"
    echo "  (In agent context, Tier 0 will prompt for approval on --no-verify.)"
    echo ""
    echo "Bypasses are logged."
    exit 1
fi

# Extract task reference and project root
TASK_REF=$(echo "$COMMIT_MSG" | grep -oE "T-[0-9]+" | head -1)
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Resolve FRAMEWORK_ROOT and source task helpers (T-456, T-520)
FRAMEWORK_ROOT="$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    _fw_path=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    [ -n "$_fw_path" ] && [ -d "$_fw_path" ] && FRAMEWORK_ROOT="$_fw_path"
fi
# Check vendored framework path (T-520: framework_path removed in T-498)
if [ ! -f "$FRAMEWORK_ROOT/lib/tasks.sh" ] && [ -f "$PROJECT_ROOT/.agentic-framework/lib/tasks.sh" ]; then
    FRAMEWORK_ROOT="$PROJECT_ROOT/.agentic-framework"
fi
TASKS_DIR="$PROJECT_ROOT/.tasks"
if [ -f "$FRAMEWORK_ROOT/lib/tasks.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/tasks.sh"
fi

# Source config for configurable inception limit (T-1176, R-032)
if [ -f "$FRAMEWORK_ROOT/lib/config.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/config.sh"
fi
# Source paths for _emit_user_command (T-1204, T-1146 GO)
if [ -f "$FRAMEWORK_ROOT/lib/paths.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/paths.sh"
fi
INCEPTION_COMMIT_LIMIT=$(fw_config "INCEPTION_COMMIT_LIMIT" 2 2>/dev/null || echo 2)

# --- Inception commit classifier (T-2195) ---
# An inception commit is "exploration" (counts toward budget) if its diff touches
# anything OUTSIDE the inception's own task file in .tasks/{active,completed}/.
# A "storage" commit (filing-only, status flip, demote, frontmatter edit) is
# exempt — these are bookkeeping, not exploration. Origin: T-2186 hit the
# budget at its 3rd commit (Step 0 findings) because filing + demote consumed
# 2/2 with zero exploration. Same scoring-shaped rigidity the inception was
# trying to recalibrate.
#
# Returns the count on stdout. Assumes TASK_REF is set.
_count_inception_exploration_commits() {
    local task_ref="$1"
    local total=0
    local sha files
    # Subject-anchored match (T-1328) avoids counting body-mentions.
    while IFS= read -r sha; do
        [ -z "$sha" ] && continue
        files=$(git show --name-only --format= "$sha" 2>/dev/null || echo "")
        # If ANY file is outside .tasks/{active,completed}/T-XXX-*, this is exploration.
        # grep -v matches storage-pattern lines; if anything remains, we count.
        if echo "$files" | grep -vE "^\.tasks/(active|completed)/${task_ref}-" | grep -q '[^[:space:]]'; then
            total=$((total + 1))
        fi
    done < <(git log --oneline 2>/dev/null | grep -E "^[0-9a-f]+ ${task_ref}:" | awk '{print $1}')
    echo "$total"
}

# --- Inception Gate (T-126, T-1176) ---
# Block commits on inception tasks after exploration threshold unless decision recorded
# Threshold configurable via FW_INCEPTION_COMMIT_LIMIT (default: 2)
if [ -n "$TASK_REF" ]; then
    TASK_FILE=$(find_task_file "$TASK_REF" active)
    if [ -n "$TASK_FILE" ] && grep -q "^workflow_type: inception" "$TASK_FILE"; then
        # Check if a decision has been recorded by fw inception decide
        HAS_DECISION=false
        if grep -q '^\*\*Decision\*\*: \(GO\|NO-GO\|DEFER\)' "$TASK_FILE" 2>/dev/null; then
            HAS_DECISION=true
        fi

        if [ "$HAS_DECISION" = false ]; then
            # Count existing exploration commits for this inception task (T-2195).
            # Storage commits (task-file-only edits: filing, demote, status flips,
            # frontmatter changes) are exempt. The classifier looks at each commit's
            # diff and counts only those touching files outside the task's own .md.
            # Origin: T-2186 hit the limit at commit 3 (Step 0 findings) because
            # filing + demote consumed 2/2 with zero exploration — a scoring-shaped
            # rigidity in the very system the inception was recalibrating.
            INCEPTION_COMMITS=$(_count_inception_exploration_commits "$TASK_REF")

            if [ "$INCEPTION_COMMITS" -ge "$INCEPTION_COMMIT_LIMIT" ]; then
                echo ""
                echo "BLOCKED: Inception gate — $TASK_REF has no go/no-go decision"
                echo ""
                echo "This inception task has $INCEPTION_COMMITS commits but no decision."
                echo "Inception tasks allow $INCEPTION_COMMIT_LIMIT exploration commits, then require a decision."
                echo ""
                echo "Record a decision:"
                echo "  1. Review: $(_emit_user_command "task review $TASK_REF")"
                echo "  2. Decide: $(_emit_user_command "inception decide $TASK_REF go --rationale 'reason'")"
                echo "          or: $(_emit_user_command "inception decide $TASK_REF no-go --rationale 'reason'")"
                echo ""
                echo "Bypass: git commit --no-verify"
                echo "  (In agent context, Tier 0 will prompt for approval on --no-verify.)"
                echo "  Configure: $(_emit_user_command "config set inception_commit_limit N")"
                exit 1
            else
                echo ""
                echo "NOTE: Inception task $TASK_REF — no decision yet (commit $((INCEPTION_COMMITS + 1))/$INCEPTION_COMMIT_LIMIT before gate)"
                echo "  After exploration:"
                echo "    $(_emit_user_command "inception decide $TASK_REF go --rationale '...'")"
                echo ""
            fi
        fi
    fi
fi

# --- Research Artifact Enforcement (C-001, C-002, G-009, T-226) ---
# Block inception commits after the first if no docs/reports/T-XXX artifact exists.
# inception-research-warnings: audit marker (C-002 OE check)
# First commit is allowed (task creation). Subsequent commits must have the artifact
# either on disk already or in the staged changes.
if [ -n "$TASK_REF" ] && [ -n "$TASK_FILE" ] && grep -q "^workflow_type: inception" "$TASK_FILE" 2>/dev/null; then
    # T-2195: exploration-only counter; storage commits exempt.
    INCEPTION_COMMITS=$(_count_inception_exploration_commits "$TASK_REF")
    if [ "$INCEPTION_COMMITS" -gt 0 ]; then
        # Check if docs/reports/ changes are in this commit
        HAS_STAGED_RESEARCH=$(git diff --cached --name-only | grep -c "^docs/reports/" || true)
        # Check if docs/reports/T-XXX-* already exists on disk
        HAS_EXISTING_ARTIFACT=false
        if ls "$PROJECT_ROOT/docs/reports/${TASK_REF}-"* >/dev/null 2>&1; then
            HAS_EXISTING_ARTIFACT=true
        fi

        if [ "$HAS_STAGED_RESEARCH" -eq 0 ] && [ "$HAS_EXISTING_ARTIFACT" = false ]; then
            echo ""
            echo "BLOCKED: inception commit for $TASK_REF — no research artifact (C-001/G-009)"
            echo ""
            echo "Inception tasks require a research artifact in docs/reports/"
            echo "Create the artifact BEFORE conducting research:"
            echo "  docs/reports/${TASK_REF}-<topic>.md"
            echo ""
            echo "The thinking trail IS the artifact — conversations are ephemeral, files are permanent."
            echo ""
            echo "Emergency bypass: git commit --no-verify"
            exit 1
        fi
    fi
fi

# Check if referenced task is closed (Tier 1 warning — does not block)
if [ -n "$TASK_REF" ] && ls "$PROJECT_ROOT/.tasks/completed/${TASK_REF}-"* >/dev/null 2>&1; then
    echo ""
    echo "WARNING: Task $TASK_REF is closed (in .tasks/completed/)"
    echo "  Consider: create a new task, or reopen this one."
    echo "  Commit allowed (Tier 1 warning)."
    echo ""
fi

# --- Critical YAML Shrinkage Guard (T-1243) ---
# Warn when learnings.yaml, patterns.yaml, or practices.yaml lose >50% of entries.
# Advisory only (WARN, not BLOCK) — legitimate cleanup is rare but possible.
for _yaml_file in .context/project/learnings.yaml .context/project/patterns.yaml .context/project/practices.yaml; do
    if git diff --cached --name-only | grep -q "^${_yaml_file}$"; then
        _old_lines=$(git show HEAD:"${_yaml_file}" 2>/dev/null | grep -c "^- " || true)
        _new_lines=$(git diff --cached -- "${_yaml_file}" | grep -c "^+- " || true)
        _del_lines=$(git diff --cached -- "${_yaml_file}" | grep -c "^-- " || true)
        if [ "$_old_lines" -gt 10 ] && [ "$_del_lines" -gt 0 ]; then
            _remaining=$((_old_lines - _del_lines + _new_lines))
            if [ "$_remaining" -lt $((_old_lines / 2)) ]; then
                echo ""
                echo "WARNING: ${_yaml_file} shrunk from ${_old_lines} to ~${_remaining} entries (>50% loss)"
                echo "  If intentional, proceed. If accidental: git checkout HEAD -- ${_yaml_file}"
                echo "  Use 'fw context add-learning' instead of direct file edits."
                echo ""
            fi
        fi
    fi
done

exit 0
HOOK_EOF

    chmod +x "$commit_msg_hook"

    # T-1844: Create pre-commit hook for secret-scan
    # Origin: T-1828/T-1834 — Azure DevOps PAT committed at 79e3361d (T-1736
    # Spike B). GitHub mirror blocked by GH013 push protection. Framework had
    # no structural gate against secrets reaching commits. This hook delegates
    # scanning to agents/git/lib/secret-scan.sh and fails the commit on hit.
    cat > "$pre_commit_hook" << 'HOOK_EOF'
#!/bin/bash
# pre-commit hook - Secret Scan (T-1844)
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.0

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Resolve FRAMEWORK_ROOT — framework / consumer / vendored layouts.
FRAMEWORK_ROOT="$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    _fw_path=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    [ -n "$_fw_path" ] && [ -d "$_fw_path" ] && FRAMEWORK_ROOT="$_fw_path"
fi
[ ! -f "$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh" ] \
    && [ -f "$PROJECT_ROOT/.agentic-framework/agents/git/lib/secret-scan.sh" ] \
    && FRAMEWORK_ROOT="$PROJECT_ROOT/.agentic-framework"

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
if [ ! -x "$SCANNER" ]; then
    # Scanner missing — fail open with a clear message, don't block legitimate work.
    echo "secret-scan: scanner not found at $SCANNER (skipping)" >&2
    exit 0
fi

# Run the scanner against the staged diff.
_hits=$(PROJECT_ROOT="$PROJECT_ROOT" "$SCANNER" scan-staged 2>&1)
_rc=$?

if [ "$_rc" -ne 0 ]; then
    echo ""
    echo "ERROR: Commit blocked — secret-scan detected matches:" >&2
    echo "" >&2
    echo "$_hits" >&2
    echo "" >&2
    echo "If this is a real secret: remove it from the staged content and re-commit." >&2
    echo "If this is a false positive: add a regex to .secret-scan-allowlist." >&2
    echo "" >&2
    echo "Bypass: git commit --no-verify" >&2
    echo "  (Tier 0 will prompt for approval on --no-verify. Bypasses are logged.)" >&2
    echo "" >&2
    echo "Origin: T-1844 — root-cause prevention for the T-1828/T-1834 leak class." >&2
    exit 1
fi

# T-1863: Duplicate-task-ID gate — G-052 prevention at the commit boundary.
# Catches active/T-NNNN + completed/T-NNNN orphans before they land in git
# (was previously only caught at audit time, often days after the leak).
DUP_TASK_SCANNER="$FRAMEWORK_ROOT/agents/git/lib/dup-task-scan.sh"
if [ -x "$DUP_TASK_SCANNER" ]; then
    _dt_hits=$(PROJECT_ROOT="$PROJECT_ROOT" "$DUP_TASK_SCANNER" scan-staged 2>&1)
    _dt_rc=$?
    if [ "$_dt_rc" -ne 0 ]; then
        echo "" >&2
        echo "ERROR: Commit blocked — duplicate task IDs in staged tree:" >&2
        echo "" >&2
        echo "$_dt_hits" >&2
        echo "" >&2
        echo "Resolve: keep the canonical version (usually .tasks/completed/),"  >&2
        echo "         git rm the orphan, and re-commit. Cross-check status:"   >&2
        echo "           grep '^status:' .tasks/{active,completed}/T-NNNN-*.md" >&2
        echo "" >&2
        echo "Bypass: git commit --no-verify   (Tier 0, logged)"                >&2
        echo "" >&2
        echo "Origin: T-1863 — T-1859 active+completed orphan caught 3 days late." >&2
        exit 1
    fi
fi

# T-1845: Large-file gate — sibling prevention to secret-scan. Blocks staged
# files >10MiB by default; allowlist exempts deliberate vendored cases.
LARGE_FILE_SCANNER="$FRAMEWORK_ROOT/agents/git/lib/large-file-scan.sh"
if [ -x "$LARGE_FILE_SCANNER" ]; then
    _lf_hits=$(PROJECT_ROOT="$PROJECT_ROOT" "$LARGE_FILE_SCANNER" scan-staged 2>&1)
    _lf_rc=$?
    if [ "$_lf_rc" -ne 0 ]; then
        echo ""
        echo "ERROR: Commit blocked — large-file gate flagged staged content:" >&2
        echo "" >&2
        echo "$_lf_hits" >&2
        echo "" >&2
        echo "If this file should not be in git: unstage it (git restore --staged <path>)" >&2
        echo "                                   and add it to .gitignore." >&2
        echo "If it's a deliberate vendored artefact: add the path-prefix regex to" >&2
        echo "                                       .large-file-allowlist." >&2
        echo "If you need a one-off larger threshold:" >&2
        echo "  FW_LARGE_FILE_BLOCK_BYTES=104857600 git commit ..." >&2
        echo "" >&2
        echo "Bypass: git commit --no-verify   (Tier 0, logged)" >&2
        echo "" >&2
        echo "Origin: T-1845 — sibling prevention to T-1844 (T-1834 force-push surfaced 36MB+78MB tracked binaries)." >&2
        exit 1
    fi
fi

exit 0
HOOK_EOF

    chmod +x "$pre_commit_hook"

    # Create post-commit hook for bypass detection + context checkpoint
    cat > "$post_commit_hook" << 'HOOK_EOF'
#!/bin/bash
# post-commit hook - Bypass Detection + Context Checkpoint
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.6

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Resolve FRAMEWORK_ROOT for _emit_user_command (T-1204)
FRAMEWORK_ROOT="$PROJECT_ROOT"
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    _fw_path=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    [ -n "$_fw_path" ] && [ -d "$_fw_path" ] && FRAMEWORK_ROOT="$_fw_path"
fi
[ ! -f "$FRAMEWORK_ROOT/lib/paths.sh" ] && [ -f "$PROJECT_ROOT/.agentic-framework/lib/paths.sh" ] && FRAMEWORK_ROOT="$PROJECT_ROOT/.agentic-framework"
[ -f "$FRAMEWORK_ROOT/lib/paths.sh" ] && source "$FRAMEWORK_ROOT/lib/paths.sh"

# Get the commit message
COMMIT_MSG=$(git log -1 --format=%B HEAD)

# --- Task reference check ---
if ! echo "$COMMIT_MSG" | grep -qE "T-[0-9]+"; then
    echo ""
    echo "WARNING: Commit made without task reference (bypass detected)"
    echo ""
    echo "Please log this bypass:"
    echo "  ./agents/git/git.sh log-bypass --commit $(git rev-parse --short HEAD) --reason \"your reason\""
    echo ""
fi

# --- Context checkpoint: reset tool counter on commit ---
COUNTER_FILE="$PROJECT_ROOT/.context/working/.tool-counter"
if [ -f "$COUNTER_FILE" ]; then
    echo "0" > "$COUNTER_FILE"
fi

# --- T-591: Reset edit counter on commit (commit cadence warning) ---
EDIT_COUNTER="$PROJECT_ROOT/.context/working/.edit-counter"
if [ -f "$EDIT_COUNTER" ]; then
    echo "0" > "$EDIT_COUNTER"
fi

# --- Fabric blast-radius note (T-236) ---
FABRIC_DIR="$PROJECT_ROOT/.fabric/components"
if [ -d "$FABRIC_DIR" ]; then
    CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)
    COMP_COUNT=0
    DEP_COUNT=0
    COMP_NAMES=""
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        case "$file" in .context/*|.fabric/*|.tasks/*|docs/*) continue ;; esac
        for card in "$FABRIC_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            if grep -q "^location: $file" "$card" 2>/dev/null; then
                COMP_COUNT=$((COMP_COUNT + 1))
                name=$({ grep "^name:" "$card" 2>/dev/null || true; } | head -1 | sed 's/^name: //')
                COMP_NAMES="${COMP_NAMES:+$COMP_NAMES, }$name"
                # Count dependents (depended_by entries)
                deps=$(grep -c "target:" "$card" 2>/dev/null || true)
                DEP_COUNT=$((DEP_COUNT + deps))
                break
            fi
        done
    done <<< "$CHANGED_FILES"
    if [ "$COMP_COUNT" -gt 0 ]; then
        echo ""
        echo "FABRIC: $COMP_COUNT component(s) modified: $COMP_NAMES"
        if [ "$DEP_COUNT" -gt 5 ]; then
            echo "  High connectivity ($DEP_COUNT edges) — consider: $(_fw_cmd 2>/dev/null || echo fw) fabric blast-radius HEAD"
        fi
    fi
fi

# --- New file auto-registration advisory (T-247) ---
if [ -d "$FABRIC_DIR" ]; then
    NEW_FILES=$(git diff-tree --no-commit-id --name-only --diff-filter=A -r HEAD 2>/dev/null)
    UNREG=""
    UNREG_COUNT=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        case "$file" in
            .context/*|.fabric/*|.tasks/*|.claude/*|.git/*|docs/*|*.md|*.yaml|*.yml|*.json) continue ;;
        esac
        FOUND=0
        for card in "$FABRIC_DIR"/*.yaml; do
            [ -f "$card" ] || continue
            if grep -q "^location: $file" "$card" 2>/dev/null; then
                FOUND=1
                break
            fi
        done
        if [ "$FOUND" -eq 0 ]; then
            UNREG_COUNT=$((UNREG_COUNT + 1))
            UNREG="${UNREG:+$UNREG, }$file"
        fi
    done <<< "$NEW_FILES"
    if [ "$UNREG_COUNT" -gt 0 ]; then
        echo ""
        echo "FABRIC: $UNREG_COUNT new file(s) without component cards: $UNREG"
        echo "  Register: $(_fw_cmd 2>/dev/null || echo fw) fabric register <path>"
    fi
fi

# --- Handover staleness check ---
LATEST="$PROJECT_ROOT/.context/handovers/LATEST.md"
if [ -f "$LATEST" ]; then
    TODO_COUNT=$(grep -c '\[TODO' "$LATEST" 2>/dev/null || true)
    if [ "${TODO_COUNT:-0}" -gt 3 ]; then
        HANDOVER_TIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        ELAPSED=$(( (NOW - HANDOVER_TIME) / 60 ))
        if [ "$ELAPSED" -gt 60 ]; then
            echo ""
            echo "HANDOVER STALE: Last handover has $TODO_COUNT unfilled [TODO] sections (${ELAPSED}min old)"
            echo "  Run: $(_emit_user_command "handover --commit" 2>/dev/null || echo "fw handover --commit")"
            echo ""
        fi
    fi
fi
HOOK_EOF

    chmod +x "$post_commit_hook"

    # Create pre-push hook for audit enforcement
    cat > "$pre_push_hook" << 'HOOK_EOF'
#!/bin/bash
# pre-push hook - Audit Enforcement + lightweight-tag rejection + VERSION monotonicity (T-1593, T-1603, T-1829)
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.4

# T-1603: VERSION monotonicity check.
# Origin: T-1602 surfaced silent VERSION rollback in cc38e98f5 (1.5.463 → 1.5.19,
# ~440 patch versions dropped) as a side-effect of `git checkout` against a stale
# ref. 12 consumers paid the cost (pins ahead of HEAD for 4 days). Block any push
# whose local commit is NOT forward-in-time of the remote commit (compare via
# git merge-base --is-ancestor). T-1829 added the ancestor refinement: a pure
# sort -V comparison conflated "new commit lowers VERSION via tag-counter reset"
# (forward in time, allowed) with "HEAD reset to older commit" (the cc38e98f5
# class — local is ancestor of remote, blocked). Read git's stdin format:
# "<local-ref> <local-sha> <remote-ref> <remote-sha>"
_zero="0000000000000000000000000000000000000000"
_block_lines=""
# Need to capture stdin once; tee to FD 9 so the lightweight-tag loop below
# can re-read it via /dev/fd/9 (mkfifo not portable enough across hosts).
_stdin_buf=$(cat)
while IFS=' ' read -r _local_ref _local_sha _remote_ref _remote_sha; do
    [ -z "$_local_ref" ] && continue
    # Skip deletions (local_sha is all zeros)
    [ "$_local_sha" = "$_zero" ] && continue
    # Only check branch refs — tags carry their own version meaning
    case "$_local_ref" in refs/heads/*) ;; *) continue ;; esac
    # Read VERSION from local commit being pushed
    _local_ver=$(git show "$_local_sha:VERSION" 2>/dev/null | tr -d '[:space:]')
    [ -z "$_local_ver" ] && continue
    # Read VERSION from remote tip if known; if remote_sha is zero, this is a
    # new branch — fall back to comparing against $_local_sha~1's VERSION.
    if [ "$_remote_sha" = "$_zero" ]; then
        _remote_ver=$(git show "$_local_sha~1:VERSION" 2>/dev/null | tr -d '[:space:]')
    else
        _remote_ver=$(git show "$_remote_sha:VERSION" 2>/dev/null | tr -d '[:space:]')
    fi
    [ -z "$_remote_ver" ] && continue
    # Equal is OK — no change. Higher is OK — bump.
    [ "$_local_ver" = "$_remote_ver" ] && continue
    # Lower fails: sort -V says first is lower-or-equal; if remote sorts BEFORE
    # local, local is higher → ok. If local sorts before remote, local is lower
    # → check forward-in-time via ancestor relation (T-1829).
    _first=$(printf '%s\n%s\n' "$_local_ver" "$_remote_ver" | sort -V | head -1)
    if [ "$_first" = "$_local_ver" ] && [ "$_local_ver" != "$_remote_ver" ]; then
        # T-1829: tag-counter reset (e.g. v1.6.2 created after v1.5.X stamping)
        # drops <commits-since-tag> back to 0, making local-VERSION numerically
        # less than remote-VERSION despite local being forward in commit time.
        # If the remote sha is locally known AND is an ancestor of local sha,
        # the push is genuinely forward — allow. Otherwise fall back to the
        # strict-block behaviour that T-1602 motivated (HEAD-reset rollback,
        # local-is-ancestor-of-remote shape).
        if [ "$_remote_sha" != "$_zero" ] \
           && git cat-file -e "$_remote_sha" 2>/dev/null \
           && git merge-base --is-ancestor "$_remote_sha" "$_local_sha" 2>/dev/null; then
            :   # forward in commit time despite VERSION decrease — allow
        else
            _block_lines="${_block_lines}${_block_lines:+
}  ${_local_ref#refs/heads/}: VERSION ${_local_ver} < remote ${_remote_ver}"
        fi
    fi
done <<EOF
${_stdin_buf}
EOF
if [ -n "$_block_lines" ]; then
    echo "" >&2
    echo "ERROR: Push blocked — VERSION monotonicity violation:" >&2
    printf '%s\n' "$_block_lines" >&2
    echo "" >&2
    echo "VERSION rolled back without authorization (T-1603)." >&2
    echo "Origin: T-1602 surfaced cc38e98f5 silent rollback (1.5.463 → 1.5.19)." >&2
    echo "" >&2
    echo "If this is intentional (rare — major-version reset, etc.):" >&2
    echo "  Bypass: git push --no-verify (Tier 0 protected, logged)" >&2
    echo "" >&2
    exit 1
fi

# T-1593 (T-1591/T-1592 RCA Prevention #2): Reject lightweight tag pushes.
# Annotated-vs-lightweight tag SHA mismatch caused 22h+ of broken AEF→GitHub
# mirror builds (T-1591 RCA). Lightweight tags are commits; annotated tags are
# tag objects with their own SHA. Mixing them across remotes guarantees mirror
# failure on force=false, and silent SHA-drift even on force=true.
# Read git's stdin format: "<local-ref> <local-sha> <remote-ref> <remote-sha>"
# stdin already consumed into $_stdin_buf above (T-1603); re-feed via heredoc.
_lw_tags=""
while IFS=' ' read -r _local_ref _local_sha _remote_ref _remote_sha; do
    [ -z "$_local_ref" ] && continue
    case "$_local_ref" in
        refs/tags/*)
            # Skip deletions (local_sha is all zeros)
            case "$_local_sha" in 0000000000000000000000000000000000000000) continue ;; esac
            _tag_type=$(git cat-file -t "$_local_sha" 2>/dev/null || echo "")
            if [ "$_tag_type" = "commit" ]; then
                _lw_tags="${_lw_tags} ${_local_ref#refs/tags/}"
            fi
            ;;
    esac
done <<EOF
${_stdin_buf}
EOF

if [ -n "$_lw_tags" ]; then
    echo "" >&2
    echo "ERROR: Push blocked — lightweight tag(s) detected:" >&2
    for _t in $_lw_tags; do
        echo "  - $_t" >&2
    done
    echo "" >&2
    echo "Lightweight tags break OneDev→GitHub mirror (T-1591/T-1592)." >&2
    echo "Recreate as annotated:" >&2
    for _t in $_lw_tags; do
        echo "  git tag -d $_t && git tag -a $_t -m \"Release $_t\"" >&2
    done
    echo "" >&2
    echo "Bypass: git push --no-verify (Tier 0 protected)" >&2
    exit 1
fi

# Find project root (where .git is) and export for audit script
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
export PROJECT_ROOT

# T-1610: YAML well-formedness gate for tracked .context/project/*.yaml.
# Origin: T-1599 surfaced concerns.yaml corruption (consumer-local writer landed
# `- id: G-XXX` outside parent mapping) — survived all gates until downstream
# loaders failed silently. Block at push so corruption can't cross-fan-out to
# consumers. yaml.safe_load with sys.argv path (not f-string interpolation) so
# odd characters in paths don't break the check.
_yaml_failures=""
for _y in "$PROJECT_ROOT"/.context/project/*.yaml; do
    [ -f "$_y" ] || continue
    if ! python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$_y" 2>/dev/null; then
        _err=$(python3 -c "
import yaml, sys
try:
    yaml.safe_load(open(sys.argv[1]))
except yaml.YAMLError as e:
    msg = str(e).splitlines()[0] if str(e) else 'unknown YAML error'
    print(msg)
" "$_y" 2>&1 | head -1)
        _yaml_failures="${_yaml_failures}
  - ${_y##*/}: ${_err}"
    fi
done
if [ -n "$_yaml_failures" ]; then
    echo "" >&2
    echo "ERROR: Push blocked — YAML parse failure in tracked project file(s):" >&2
    printf '%s\n' "$_yaml_failures" >&2
    echo "" >&2
    echo "Origin: T-1599/T-1610 — silent .context/project/*.yaml corruption" >&2
    echo "must not cross-fan-out to consumer projects." >&2
    echo "" >&2
    echo "Fix the YAML, then push again." >&2
    echo "Bypass: git push --no-verify (Tier 0 protected, logged)" >&2
    exit 1
fi

# Resolve audit script. Priority (T-1396):
#   1. .framework.yaml -> framework_path (explicit consumer config)
#   2. $PROJECT_ROOT/agents/audit/audit.sh (framework repo: source-of-truth)
#   3. $PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh (vendored bootstrap fallback)
# Root-level agents/ only exists in the framework repo itself; preferring it when
# present ensures the framework-repo pre-push hook runs HEAD's audit, not the
# stale vendored bootstrap copy.
AUDIT_SCRIPT=""
if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
    FW_PATH=$(grep "^framework_path:" "$PROJECT_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
    if [ -n "$FW_PATH" ] && [ -f "$FW_PATH/agents/audit/audit.sh" ]; then
        AUDIT_SCRIPT="$FW_PATH/agents/audit/audit.sh"
    fi
fi
if [ -z "$AUDIT_SCRIPT" ] && [ -f "$PROJECT_ROOT/agents/audit/audit.sh" ]; then
    AUDIT_SCRIPT="$PROJECT_ROOT/agents/audit/audit.sh"
fi
if [ -z "$AUDIT_SCRIPT" ] && [ -f "$PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh" ]; then
    AUDIT_SCRIPT="$PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh"
fi

# Skip if audit script not found anywhere
if [ -z "$AUDIT_SCRIPT" ]; then
    echo "ERROR: Audit script not found"
    echo "  Checked: .framework.yaml -> framework_path"
    echo "  Checked: $PROJECT_ROOT/agents/audit/audit.sh"
    echo "  Checked: $PROJECT_ROOT/.agentic-framework/agents/audit/audit.sh"
    echo "  Push blocked — fix framework path or install audit agent"
    exit 1
fi

# Stamp VERSION file from git describe (T-648: git-derived versioning)
_version=$(git describe --tags --match 'v[0-9]*' 2>/dev/null) || true
if [ -n "$_version" ]; then
    _version="${_version#v}"
    if [[ "$_version" == *-*-* ]]; then
        _base="${_version%%-*}"
        _rest="${_version#*-}"
        _commits="${_rest%%-*}"
        _major_minor="${_base%.*}"
        _stamped="${_major_minor}.${_commits}"
    else
        _stamped="$_version"
    fi
    echo "$_stamped" > "$PROJECT_ROOT/VERSION"
    # T-1252 (G-006): do NOT stamp .agentic-framework/VERSION — the vendored
    # framework's VERSION must reflect the framework release that was vendored,
    # not the consumer project's version.
    echo "VERSION stamped: $_stamped"
fi

echo ""
echo "=== Pre-Push Audit Check ==="
echo ""

# T-862: Run fast audit subset for pre-push (full audit takes >90s with 100+ tasks)
# Structure checks: dirs exist, YAML parses, fabric valid — fast and catches real breaks
"$AUDIT_SCRIPT" --section structure
audit_exit=$?

if [ $audit_exit -eq 2 ]; then
    echo ""
    echo "ERROR: Push blocked - audit has FAILURES"
    echo ""
    echo "Fix the issues above before pushing."
    echo ""
    echo "Bypass: git push --no-verify"
    echo "  (In agent context, Tier 0 will prompt for approval on --no-verify.)"
    echo ""
    exit 1
elif [ $audit_exit -eq 1 ]; then
    echo ""
    echo "WARNING: Audit has warnings (push allowed)"
    echo "Consider addressing the issues above."
    echo ""
fi

exit 0
HOOK_EOF

    chmod +x "$pre_push_hook"

    echo -e "${GREEN}=== Hooks Installed ===${NC}"
    echo ""
    echo "Installed:"
    echo "  - $commit_msg_hook (task reference validation)"
    echo "  - $pre_commit_hook (secret-scan — T-1844)"
    echo "  - $post_commit_hook (bypass detection)"
    echo "  - $pre_push_hook (audit before push)"
    echo ""
    echo "Hook behavior:"
    echo "  - Blocks commits without task references (T-XXX)"
    echo "  - Blocks commits introducing secrets (T-1844 — Azure PAT, AWS keys, SSH keys, etc.)"
    echo "  - Allows merge commits and rebases"
    echo "  - Runs audit before push (blocks on FAIL, warns on WARN)"
    echo "  - Bypass: $(_emit_user_command "tier0 approve") (Tier 0 protected)"
    echo "           then: git commit/push --no-verify"
}

show_hooks_help() {
    cat << EOF
Git Agent - Install Hooks Command

Usage: git.sh install-hooks [options]

Options:
  -f, --force   Force reinstall even if same version
  -h, --help    Show this help

Installs:
  - commit-msg hook: Validates task reference in commit message
  - post-commit hook: Detects bypasses and reminds to log them
  - pre-push hook: Runs audit before push (blocks on FAIL)

The hooks enforce task traceability (P-002: Structural Enforcement).

Pre-push behavior:
  - Audit FAIL (exit 2): Push blocked
  - Audit WARN (exit 1): Push allowed with warning
  - Audit PASS (exit 0): Push allowed
  - Bypass: fw tier0 approve && git push --no-verify (Tier 0 protected)
EOF
}
