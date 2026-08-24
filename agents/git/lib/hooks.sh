#!/bin/bash
# Git Agent - Hook installation subcommand

# T-2852: the version of the commit-msg hook TEMPLATE in this file — i.e. the
# value written as `# VERSION=` into the heredoc below, and therefore the value
# that will be read back out of an installed hook on the next run.
#
# This is deliberately NOT `$VERSION` (agents/git/git.sh:19), which is the git
# agent's own version. Those were compared against each other for an unknown
# span: the template said 1.11, the agent said 1.6, so the equality at the
# "already installed" check could never hold, the fast path was unreachable, and
# every install-hooks call rewrote all four hooks while announcing a move from
# the installed marker to the agent's number — phrasing that reads as a
# downgrade and produced a confident, wrong bug report from a live onboarding
# run (/opt/001-test-install, 2026-08-07). The old wording is deliberately not
# reproduced here: a regression test greps this file for it, and quoting the
# string one claims to have removed is its own recurring mistake (T-2847).
#
# git.sh already carried a comment instructing whoever edits a template to keep
# the two in sync. It was correct and it was ignored across five marker bumps,
# which is why the guard is now a test (tests/unit/hook_version_marker_parity.bats)
# rather than a sixth sentence of prose.
#
# PL-078 still applies: when you change the CONTENT of any hook template below,
# bump this constant AND the `# VERSION=` literal in the commit-msg heredoc
# together, so consumers' next install-hooks redeploys all four.
COMMIT_MSG_HOOK_VERSION="1.14"

# T-2813: verify a hook actually landed by reading state back from disk,
# rather than trusting that the `cat`/`chmod` calls that wrote it didn't
# print an error. `cat > "$hook" << 'EOF'` fails silently at the redirect
# (e.g. hooks directory missing) *before* any command in the heredoc body
# runs, so neither a captured exit status nor the heredoc content itself
# is a reliable signal — only the resulting file is.
_verify_hook_written() {
    [ -f "$1" ] && [ -x "$1" ]
}

do_install_hooks() {
    local force=false
    local install_failed=false
    local -a failed_hooks=()

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

    local hooks_dir
    hooks_dir=$(resolve_git_hooks_dir) || {
        echo -e "${RED}ERROR: Could not resolve git hooks directory${NC}"
        exit 1
    }
    mkdir -p "$hooks_dir"
    local commit_msg_hook="$hooks_dir/commit-msg"
    local pre_commit_hook="$hooks_dir/pre-commit"
    local post_commit_hook="$hooks_dir/post-commit"
    local pre_push_hook="$hooks_dir/pre-push"

    # Check if hooks exist
    if [ -f "$commit_msg_hook" ] && [ "$force" = false ]; then
        local existing_version
        existing_version=$(grep "^# VERSION=" "$commit_msg_hook" 2>/dev/null | cut -d= -f2)
        if [ "$existing_version" = "$COMMIT_MSG_HOOK_VERSION" ]; then
            echo -e "${GREEN}Hooks already installed (version $COMMIT_MSG_HOOK_VERSION)${NC}"
            echo "Use --force to reinstall"
            exit 0
        else
            # State the difference, not a direction. Nothing here compares
            # ordering, so "updating X to Y" was claiming knowledge the code
            # does not have — and when the installed marker happened to sort
            # above the template's, it read as a downgrade and was reported as
            # a version-comparison bug (T-2852).
            echo -e "${YELLOW}Hook version differs (installed: ${existing_version:-none}, template: $COMMIT_MSG_HOOK_VERSION) — reinstalling${NC}"
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
# VERSION=1.14

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

# Resolve the fw entry point for THIS project shape (T-2816, T-1257 class).
# The framework repo carries bin/fw at its root; a consumer carries only
# .agentic-framework/bin/fw unless the PATH shim is installed. This hook is the
# ONLY framework gate a by-hand operator ever trips — the PreToolUse task gate
# is a Claude Code hook and never fires for a human at a terminal — so a remedy
# that does not exist here is the first and possibly only enforcement message
# that operator ever reads. Resolved at hook runtime, not at install time: the
# heredoc that writes this file is quoted, and the project may be re-shaped
# (shim installed, framework vendored) long after the hook was written.
_fw_entry() {
    if [ -x "./bin/fw" ] && [ -f "./FRAMEWORK.md" ]; then
        echo "bin/fw"
    elif command -v fw >/dev/null 2>&1; then
        echo "fw"
    elif [ -x "./.agentic-framework/bin/fw" ]; then
        echo ".agentic-framework/bin/fw"
    else
        echo "fw"
    fi
}

# Check for task reference
if ! echo "$COMMIT_MSG" | grep -qE "T-[0-9]+"; then
    echo ""
    echo "ERROR: No task reference found in commit message"
    echo ""
    echo "Your message: $COMMIT_MSG"
    echo ""
    echo "To fix:"
    echo "  1. Add task reference: git commit -m \"T-XXX: your message\""
    echo "  2. Create a task: $(_fw_entry) work-on \"your task name\" --type build"
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
    _verify_hook_written "$commit_msg_hook" || { install_failed=true; failed_hooks+=("$commit_msg_hook"); }

    # T-1844: Create pre-commit hook for secret-scan
    # Origin: T-1828/T-1834 — Azure DevOps PAT committed at 79e3361d (T-1736
    # Spike B). GitHub mirror blocked by GH013 push protection. Framework had
    # no structural gate against secrets reaching commits. This hook delegates
    # scanning to agents/git/lib/secret-scan.sh and fails the commit on hit.
    cat > "$pre_commit_hook" << 'HOOK_EOF'
#!/bin/bash
# pre-commit hook - Master-merge-only guard (T-2396) + task-corpus guard (T-3110)
#                   + Secret Scan (T-1844)
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.3

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

# T-2396 (inception T-2394 G1): Master-as-merge-only guard. Runs FIRST so a
# direct authored commit on a protected branch is refused before any scan work.
# Default-off (config PROTECT_MASTER) → consumer-safe; opt-in per project.
# Allows merges/rebases/fast-forwards/feature-branches. Bypass: FW_ALLOW_MASTER_COMMIT=1
# (Tier-2) or git commit --no-verify (Tier-0). See agents/git/lib/master-guard.sh.
# T-2061: bash-invoke + gate on -f (exec bit irrelevant for vendored copies).
MASTER_GUARD="$FRAMEWORK_ROOT/agents/git/lib/master-guard.sh"
if [ -f "$MASTER_GUARD" ]; then
    PROJECT_ROOT="$PROJECT_ROOT" bash "$MASTER_GUARD" check || exit 1
fi

# FW-HOOK-BLOCK: t3110-corpus-guard
# T-3110 (R7 leg L1, docs/design/task-corpus-concurrency-model.md): task-corpus
# commit guard. Refuses a commit that stages any path under `.tasks/` when the
# commit is made from a LINKED WORKTREE. Silent otherwise; source-only commits
# from a worktree are the normal supported flow and are untouched.
#
# RESOLVED FROM THE AUTHORITY, DELIBERATELY NOT FROM $FRAMEWORK_ROOT.
# Every other scanner in this hook resolves off `git rev-parse --show-toplevel`,
# which in a linked worktree IS the worktree — i.e. the replica's own tracked,
# possibly months-stale copy. That is precisely the circularity R7 describes: the
# replica supplying the code meant to constrain the replica. `.git/hooks` is the
# one anchor that does not fork, so this block walks back to the main checkout
# via --git-common-dir and loads the guard from there. Do not "simplify" it to
# match its siblings; that silently deletes the only version-independent leg.
_fw_gcd=$(git rev-parse --git-common-dir 2>/dev/null)
case "$_fw_gcd" in
    "") ;;
    /*) ;;
    *)  _fw_gcd="$PROJECT_ROOT/$_fw_gcd" ;;
esac
AUTHORITY_ROOT=""
[ -n "$_fw_gcd" ] && AUTHORITY_ROOT=$(cd "$(dirname "$_fw_gcd")" 2>/dev/null && pwd)

CORPUS_GUARD=""
if [ -n "$AUTHORITY_ROOT" ]; then
    for _cand in "$AUTHORITY_ROOT/agents/git/lib/worktree-corpus-guard.sh" \
                 "$AUTHORITY_ROOT/.agentic-framework/agents/git/lib/worktree-corpus-guard.sh"; do
        if [ -f "$_cand" ]; then CORPUS_GUARD="$_cand"; break; fi
    done
    if [ -z "$CORPUS_GUARD" ] && [ -f "$AUTHORITY_ROOT/.framework.yaml" ]; then
        _afp=$(grep "^framework_path:" "$AUTHORITY_ROOT/.framework.yaml" 2>/dev/null | sed 's/framework_path:[[:space:]]*//')
        if [ -n "$_afp" ] && [ -f "$_afp/agents/git/lib/worktree-corpus-guard.sh" ]; then
            CORPUS_GUARD="$_afp/agents/git/lib/worktree-corpus-guard.sh"
        fi
    fi
fi
if [ -n "$CORPUS_GUARD" ]; then
    # T-2061 bash-invoke pattern: gate on -f, run via `bash`, so a vendored copy
    # that landed without +x still runs.
    PROJECT_ROOT="$PROJECT_ROOT" FW_AUTHORITY_ROOT="$AUTHORITY_ROOT" \
        bash "$CORPUS_GUARD" scan-staged || exit 1
elif [ -n "$AUTHORITY_ROOT" ] && [ "$AUTHORITY_ROOT" != "$PROJECT_ROOT" ] && [ -d "$AUTHORITY_ROOT/.tasks" ]; then
    # Degrade to ALLOW — a guard that failed closed on its own missing dependency
    # would block every commit in the repo. But not SILENTLY (T-2647: a control
    # that no-ops is indistinguishable from one that passed), and only where it
    # could have mattered: a linked worktree of a repo that has a task corpus.
    # The main checkout and every worktree-free consumer print nothing, ever.
    echo "WARNING: task-corpus commit guard is NOT running (T-3110) — not found at:" >&2
    echo "  $AUTHORITY_ROOT/agents/git/lib/worktree-corpus-guard.sh" >&2
    echo "Commits touching .tasks/ from this worktree are unguarded." >&2
    echo "Fix at the authority: cd $AUTHORITY_ROOT && bin/fw upgrade" >&2
    echo "  (framework repo: bin/fw vendor self)" >&2
fi

SCANNER="$FRAMEWORK_ROOT/agents/git/lib/secret-scan.sh"
# T-2061: gate on -f not -x. We invoke via `bash "$SCANNER"` below, so the
# exec bit is irrelevant — gating on -x silently disabled the scanner when
# vendor copies landed without the exec bit (T-2052 found this hot, 2026-06-08).
# -f catches the only failure that actually matters here: file missing.
if [ ! -f "$SCANNER" ]; then
    # T-2647 (832 G-001/F4): a security control that silently no-ops is worse
    # than one that is absent — the old one-line "(skipping)" note was ignorable
    # and consumers committed for weeks with no secret scanning. Default stays
    # fail-open (a missing scanner usually means a stale vendored payload, and
    # blocking every commit on it would be hostile), but the warning is now
    # unmissable and names the fix. FW_SECRET_SCAN_STRICT=1 opts into blocking.
    echo "" >&2
    echo "WARNING: SECRET SCAN IS NOT RUNNING — scanner missing:" >&2
    echo "  $SCANNER" >&2
    echo "Every commit is going through WITHOUT secret scanning." >&2
    echo "Fix: refresh the vendored framework payload:" >&2
    echo "  cd $PROJECT_ROOT && .agentic-framework/bin/fw upgrade" >&2
    echo "  (framework repo: bin/fw vendor self)" >&2
    echo "Strict mode: set FW_SECRET_SCAN_STRICT=1 to make this block commits." >&2
    echo "" >&2
    if [ "${FW_SECRET_SCAN_STRICT:-0}" = "1" ]; then
        echo "ERROR: Commit blocked — FW_SECRET_SCAN_STRICT=1 and scanner missing." >&2
        exit 1
    fi
    exit 0
fi

# Run the scanner against the staged diff.
# T-2061: invoke via `bash` so the exec bit is irrelevant (vendor copies
# historically landed without +x and silently fail-open under the older -x gate).
_hits=$(PROJECT_ROOT="$PROJECT_ROOT" bash "$SCANNER" scan-staged 2>&1)
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
# T-2061: see secret-scan note above — gate on -f, not -x.
if [ -f "$DUP_TASK_SCANNER" ]; then
    # T-2061: bash-invoke pattern — see secret-scan note above.
    _dt_hits=$(PROJECT_ROOT="$PROJECT_ROOT" bash "$DUP_TASK_SCANNER" scan-staged 2>&1)
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
# T-2061: see secret-scan note above — gate on -f, not -x.
if [ -f "$LARGE_FILE_SCANNER" ]; then
    # T-2061: bash-invoke pattern — see secret-scan note above.
    _lf_hits=$(PROJECT_ROOT="$PROJECT_ROOT" bash "$LARGE_FILE_SCANNER" scan-staged 2>&1)
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
    _verify_hook_written "$pre_commit_hook" || { install_failed=true; failed_hooks+=("$pre_commit_hook"); }

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
    _verify_hook_written "$post_commit_hook" || { install_failed=true; failed_hooks+=("$post_commit_hook"); }

    # Create pre-push hook for audit enforcement
    cat > "$pre_push_hook" << 'HOOK_EOF'
#!/bin/bash
# pre-push hook - Audit Enforcement + lightweight-tag rejection + VERSION monotonicity + self-vendor drift (T-1593, T-1603, T-1829, T-2240, T-3125, T-3126)
# Installed by: ./agents/git/git.sh install-hooks
# Part of: Agentic Engineering Framework
# VERSION=1.7

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

# T-2240: Self-vendor drift gate (F2 N×M closure).
# Origin: T-2095 extracted _self_vendor_libs() into `fw vendor self`; T-2232 made
# the in-consumer upgrade path durable via .upstream sentinel; T-2239 split the
# dry-run wording ("would sync" vs "synced"). The gap T-2240 closes: editing
# lib/*.sh without running `fw vendor self` leaves the vendored copy at
# .agentic-framework/lib/ stale. `fw upgrade` is the only flow that catches it,
# and upgrade is not part of the push flow — so consumers that vendor from
# origin/master inherit the stale lib/ silently.
#
# Guard 1: only run in the framework repo (consumers have no root-level bin/fw —
# their fw lives at .agentic-framework/bin/fw and they don't have a vendored
# .agentic-framework/lib/ to drift). Consumer-safe by construction.
# Guard 2: FW_SKIP_SELF_VENDOR_CHECK=1 bypass for legitimate skip scenarios
# (e.g. release prep where vendor refresh is the next commit). Tier-2 visibility
# via stderr WARN — matches existing hook pattern (no separate log writes).
# T-3125: the detector above judges the WORKING TREE; the property this gate
# protects is about the PUSHED REF. `fw vendor self --dry-run` compares
# working-tree source against working-tree vendored copies, so ANY session with
# an uncommitted edit to a vendored-class file blocked EVERY other session's
# push, with no exit but a Tier-2 or Tier-0 bypass. Observed live 2026-08-23: 19
# commits held for hours by a concurrent session's uncommitted bin/fw and
# agents/audit/audit.sh — for both, `git show HEAD:<src>` was byte-identical to
# the vendored blob. The ref being pushed was clean; the block was false.
#
# So the dry-run stays as the cheap DETECTOR, and these two helpers decide
# whether the drift it found actually exists in the COMMITTED tree.
#
# _t3125_vendor_class mirrors the classes `fw vendor self --check` syncs
# (lib/bin/agents/web/policy/.tasks-templates/designer). It is a deliberate
# read-only MIRROR, not a shared list: bin/fw and agents/audit/audit.sh own the
# canonical filters and their mismatch is a separate open defect (T-2607) which
# this task does not touch. Getting the mirror wrong is safe in one direction
# only — a class listed here that vendor-self does not sync could hold a real
# push, so keep it conservative. VERSION is excluded on purpose: it is
# sync-only, outside --check, and is rewritten on every commit.
_t3125_vendor_class() {
    case "$1" in
        bin/*.pyc)                                  return 1 ;;
        bin/*)                                      return 0 ;;
        lib/*.sh|lib/*.py|lib/*.md)                 return 0 ;;
        agents/*.sh|agents/*.py|agents/*.md)        return 0 ;;
        web/*.sh|web/*.py|web/*.html|web/*.css|web/*.js|web/*.svg|web/*.j2|web/*.jinja2) return 0 ;;
        .tasks/templates/*.md)                      return 0 ;;
        policy/value-drivers.yaml|policy/bvp-scoring-rubric.md|policy/capability-overlay/tool-set.yaml|policy/anti-patterns.yaml|policy/escalation-patterns.yaml|policy/designer-pin.yaml) return 0 ;;
    esac
    # Designer class: only the build the ref's own pin names. The vendored tree
    # deliberately prunes superseded builds, so matching vendor/designer/*.html
    # would report 8 permanent phantoms and never let the gate downgrade.
    [ -n "$_t3125_pinned_designer" ] && [ "$1" = "$_t3125_pinned_designer" ] && return 0
    return 1
}

# Prints every class-matching source path whose vendored counterpart in $1 is
# missing or different. Walks SOURCE paths (not the vendored tree) because that
# is what vendor-self iterates: it syncs when the destination is absent OR
# differs, so a newly committed lib/foo.sh that was never vendored is drift and
# must still BLOCK. One `git ls-tree` fork, compared in-memory by blob sha.
_t3125_committed_drift() {
    local _ref="$1" _line _meta _path _sha
    declare -A _t3125_blob
    while IFS= read -r -d '' _line; do
        _meta="${_line%%$'\t'*}"
        _path="${_line#*$'\t'}"
        _sha="${_meta##* }"
        _t3125_blob["$_path"]="$_sha"
    done < <(git -C "$PROJECT_ROOT" ls-tree -r -z "$_ref" 2>/dev/null)
    _t3125_pinned_designer=$(git -C "$PROJECT_ROOT" show "$_ref:policy/designer-pin.yaml" 2>/dev/null \
        | grep -E '^vendored_path:' | head -1 \
        | sed -e 's/^vendored_path:[[:space:]]*//' -e 's/#.*//' -e 's/^"//' -e 's/"[[:space:]]*$//' -e 's/[[:space:]]*$//')
    for _path in "${!_t3125_blob[@]}"; do
        case "$_path" in .agentic-framework/*) continue ;; esac
        _t3125_vendor_class "$_path" || continue
        if [ "${_t3125_blob[.agentic-framework/$_path]:-}" != "${_t3125_blob[$_path]}" ]; then
            printf '%s\n' "$_path"
        fi
    done
}

if [ -x "$PROJECT_ROOT/bin/fw" ] && [ -d "$PROJECT_ROOT/.agentic-framework/lib" ]; then
    if [ "${FW_SKIP_SELF_VENDOR_CHECK:-0}" = "1" ]; then
        echo "" >&2
        echo "WARN: Self-vendor drift check skipped (FW_SKIP_SELF_VENDOR_CHECK=1)" >&2
        echo "  Class: T-2240/T-2241 — vendored .agentic-framework/ may diverge from source" >&2
        echo "" >&2
    else
        _sv_out=$("$PROJECT_ROOT/bin/fw" vendor self --dry-run 2>&1 || true)
        if echo "$_sv_out" | grep -q "would sync"; then
            # T-3125: which ref is actually being pushed? git feeds pre-push
            # "<local-ref> <local-sha> <remote-ref> <remote-sha>" on stdin, already
            # buffered into $_stdin_buf by the T-1603 block above. Take the first
            # non-deletion branch sha — that is the tree consumers will vendor.
            # Fall back to HEAD when stdin carried nothing usable (manual
            # invocation, tag-only push, deletion): HEAD is the closest committed
            # approximation, and it is still strictly better than the working
            # tree, which is what the false positive was made of.
            _t3125_ref=""
            while IFS=' ' read -r _t3125_lref _t3125_lsha _t3125_rref _t3125_rsha; do
                [ -z "$_t3125_lref" ] && continue
                [ "$_t3125_lsha" = "$_zero" ] && continue
                case "$_t3125_lref" in refs/heads/*) ;; *) continue ;; esac
                _t3125_ref="$_t3125_lsha"
                break
            done <<EOF
$_stdin_buf
EOF
            [ -n "$_t3125_ref" ] || _t3125_ref="HEAD"
            _sv_committed=$(_t3125_committed_drift "$_t3125_ref")

            if [ -n "$_sv_committed" ]; then
                echo "" >&2
                echo "ERROR: Push blocked — self-vendor drift detected (T-2240):" >&2
                echo "" >&2
                echo "$_sv_out" | grep "would sync" | head -3 >&2
                echo "" >&2
                echo "Vendored .agentic-framework/ is stale; see the 'would sync' line(s)" >&2
                echo "above for the affected class(es). Consumers that vendor from origin" >&2
                echo "would inherit the divergence silently." >&2
                echo "" >&2
                echo "Stale in the COMMITTED tree being pushed (T-3125), first 5:" >&2
                printf '%s\n' "$_sv_committed" | head -5 | sed 's/^/  /' >&2
                echo "" >&2
                echo "Fix:" >&2
                echo "  cd $PROJECT_ROOT && bin/fw vendor self && git add .agentic-framework/ && git commit -m 'T-XXX: refresh vendored copies'" >&2
                echo "" >&2
                echo "Bypass (logged Tier-2):" >&2
                echo "  FW_SKIP_SELF_VENDOR_CHECK=1 git push" >&2
                echo "Bypass (Tier 0):" >&2
                echo "  git push --no-verify" >&2
                echo "" >&2
                exit 1
            fi

            echo "" >&2
            echo "WARN: Self-vendor drift is working-tree-only — push allowed (T-3125)" >&2
            echo "  Affected class(es):" >&2
            echo "$_sv_out" | grep "would sync" | head -3 | sed 's/^ */    /' >&2
            echo "  The tree being pushed ($_t3125_ref) is IN SYNC: every vendored-class" >&2
            echo "  file matches its vendored copy in that commit, so consumers vendoring" >&2
            echo "  from origin inherit nothing stale. The drift above lives only in" >&2
            echo "  uncommitted edits — yours or a concurrent session's." >&2
            echo "  Run 'bin/fw vendor self' before COMMITTING those edits." >&2
            echo "" >&2
        fi
    fi
fi

# T-2294: MCP manifest drift gate (arc-010 sibling to T-2240).
# Origin: T-2293 commit 7e647bd1e leaked a bats artefact (fake_drift_tool_t2290)
# into agents/mcp/framework-mcp-manifest.json because the test's prior crash had
# polluted tool-set.yaml. The push went through clean — no manifest drift gate
# existed. This block runs `fw mcp check` (T-2293) and refuses push on non-zero
# exit. Catches both real edit-drift (developer forgot `fw mcp emit-manifest`)
# and test-artefact leaks.
#
# Guard: framework repo only (consumers have no agents/mcp/manifest.py source).
# Bypass: FW_SKIP_MCP_DRIFT_CHECK=1 (sibling to FW_SKIP_SELF_VENDOR_CHECK) and
# --no-verify per L-399 producer/consumer-parity discipline. Block message
# names both mechanisms (T-1890).
if [ -x "$PROJECT_ROOT/bin/fw" ] && [ -f "$PROJECT_ROOT/agents/mcp/manifest.py" ]; then
    if [ "${FW_SKIP_MCP_DRIFT_CHECK:-0}" = "1" ]; then
        echo "" >&2
        echo "WARN: MCP manifest drift check skipped (FW_SKIP_MCP_DRIFT_CHECK=1)" >&2
        echo "  Class: T-2294 — agents/mcp/framework-mcp-manifest.json may diverge from tool-set.yaml" >&2
        echo "" >&2
    else
        _mcp_out=$("$PROJECT_ROOT/bin/fw" mcp check 2>&1 || true)
        _mcp_exit=$("$PROJECT_ROOT/bin/fw" mcp check >/dev/null 2>&1; echo $?)
        if [ "$_mcp_exit" != "0" ]; then
            echo "" >&2
            echo "ERROR: Push blocked — MCP manifest drift detected (T-2294):" >&2
            echo "" >&2
            echo "$_mcp_out" | head -3 >&2
            echo "" >&2
            echo "agents/mcp/framework-mcp-manifest.json is out of sync with" >&2
            echo "policy/capability-overlay/tool-set.yaml. Consumers reading the" >&2
            echo "manifest as a capability gate would see the stale tool catalogue." >&2
            echo "" >&2
            echo "Fix:" >&2
            echo "  cd $PROJECT_ROOT && bin/fw mcp emit-manifest && git add agents/mcp/framework-mcp-manifest.json && git commit -m 'T-XXX: refresh MCP manifest'" >&2
            echo "" >&2
            echo "Bypass (logged Tier-2):" >&2
            echo "  FW_SKIP_MCP_DRIFT_CHECK=1 git push" >&2
            echo "Bypass (Tier 0):" >&2
            echo "  git push --no-verify" >&2
            echo "" >&2
            exit 1
        fi
    fi
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
#
# T-3126: the output is captured as well as shown, because the FAIL verdict alone
# does not say WHICH TREE the failure lives in. The audit reads the working tree;
# this gate decides a REF operation. `tee` keeps the run streaming to the operator
# (it takes tens of seconds) while PIPESTATUS preserves the audit's own exit code —
# the whole point of the exit-75 branch below is that the pipeline's exit code must
# not be substituted for the audit's.
_t3126_out=$(mktemp -t fw-prepush-audit-XXXXXX 2>/dev/null || echo "")
if [ -n "$_t3126_out" ]; then
    "$AUDIT_SCRIPT" --section structure 2>&1 | tee "$_t3126_out"
    audit_exit=${PIPESTATUS[0]}
else
    # mktemp unavailable: run exactly as before. No capture means no scope line,
    # and the gate below treats a missing scope line as "block" — degraded to the
    # pre-T-3126 behaviour, never to something weaker.
    "$AUDIT_SCRIPT" --section structure
    audit_exit=$?
fi

# Parse the T-3126 partition. Absent line, unparseable count, or no capture at all
# → _t3126_ref_fails stays empty → the FAILURES branch blocks, exactly as before.
_t3126_ref_fails=""
_t3126_wt_fails=""
if [ -n "$_t3126_out" ] && [ -f "$_t3126_out" ]; then
    _t3126_scope_line=$(grep -E '^AUDIT-SCOPE: ' "$_t3126_out" 2>/dev/null | tail -1)
    if [ -n "$_t3126_scope_line" ]; then
        _t3126_ref_fails=$(printf '%s\n' "$_t3126_scope_line" | sed -n 's/.*[[:space:]]ref=\([0-9][0-9]*\).*/\1/p')
        _t3126_wt_fails=$(printf '%s\n' "$_t3126_scope_line" | sed -n 's/.*[[:space:]]worktree=\([0-9][0-9]*\).*/\1/p')
    fi
fi

if [ $audit_exit -eq 75 ]; then
    # T-2930 / OBS-221: 75 = EX_TEMPFAIL = the audit DID NOT RUN (lock contention).
    # This is not a pass. Before this branch existed, contention exited 0 and landed
    # in the "no failures" path, so a push during the daily audit cron was waved
    # through with the gate never having evaluated anything — observed live
    # 2026-08-11 with an invariant RED at the time.
    #
    # BLOCK rather than warn. The asymmetry is what decides it: a push blocked on
    # contention costs seconds — wait for the other audit and push again — whereas a
    # push waved through on an unevaluated gate costs whatever the unaudited commit
    # does downstream, discovered later and attributed elsewhere.
    echo ""
    echo "ERROR: Push blocked - audit COULD NOT RUN (another audit holds the lock)"
    echo ""
    echo "This is not an audit failure. No verdict was produced, so the gate has"
    echo "nothing to pass you on."
    echo ""
    echo "What to do: wait for the running audit to finish, then push again."
    echo "  Usually the daily cron audit — it finishes within a minute or two."
    echo "  Check: ls -l $PROJECT_ROOT/.context/locks/audit.lock"
    echo ""
    echo "Bypass: git push --no-verify"
    echo "  (In agent context, Tier 0 will prompt for approval on --no-verify.)"
    echo ""
    [ -n "$_t3126_out" ] && rm -f "$_t3126_out"
    exit 1
elif [ $audit_exit -eq 2 ]; then
    # T-3126: block only on REF-scoped failures.
    #
    # A worktree-scoped FAIL is real — the audit is right to report it — but it is
    # a property of uncommitted edits, untracked files, or host state, none of
    # which any git ref contains. Refusing the push does not fix it, and it is
    # routinely somebody ELSE's in-flight work: on 2026-08-23 a concurrent
    # session's uncommitted bin/fw + agents/audit/audit.sh and two untracked
    # tests/lint/*.bats files held a push of a ref containing neither.
    #
    # The downgrade requires PROOF: a scope line saying ref=0 with at least one
    # worktree-scoped failure. Anything else — no line (audit predates T-3126, or
    # the capture failed), a non-numeric count, or ref>0 — blocks.
    if [ "$_t3126_ref_fails" = "0" ] && [ -n "$_t3126_wt_fails" ] && [ "$_t3126_wt_fails" != "0" ]; then
        echo ""
        echo "WARNING: Audit FAILED, but every failure is in the WORKING TREE (T-3126)"
        echo ""
        echo "  Worktree-scoped failure(s):"
        grep -E '^AUDIT-SCOPE-WORKTREE: ' "$_t3126_out" 2>/dev/null \
            | sed -e 's/^AUDIT-SCOPE-WORKTREE: /    - /'
        echo ""
        echo "  These findings are in the WORKING TREE: uncommitted edits, untracked"
        echo "  files, or host state such as /etc/cron.d."
        echo "  They are NOT in the ref being pushed — a clean checkout of that commit"
        echo "  does not contain them."
        echo "  They are therefore NOT BLOCKING THIS PUSH."
        echo ""
        echo "  They are still real. Fix them before COMMITTING the edits that caused"
        echo "  them — or, if they are a concurrent session's, leave them to that"
        echo "  session. Details: the [FAIL] blocks above, each with a 'Scope:' line."
        echo ""
    else
        echo ""
        echo "ERROR: Push blocked - audit has FAILURES"
        echo ""
        if [ -n "$_t3126_ref_fails" ]; then
            echo "  $_t3126_ref_fails failure(s) are REF-scoped — present in the commit being"
            echo "  pushed, not just in your working tree."
        else
            echo "  Failure scope could not be determined (no AUDIT-SCOPE line — the audit"
            echo "  predates T-3126, or its output could not be captured). Blocking:"
            echo "  an undetermined scope is not a determination that the ref is clean."
        fi
        echo ""
        echo "Fix the issues above before pushing."
        echo ""
        echo "Bypass: git push --no-verify"
        echo "  (In agent context, Tier 0 will prompt for approval on --no-verify.)"
        echo ""
        [ -n "$_t3126_out" ] && rm -f "$_t3126_out"
        exit 1
    fi
elif [ $audit_exit -eq 1 ]; then
    echo ""
    echo "WARNING: Audit has warnings (push allowed)"
    echo "Consider addressing the issues above."
    echo ""
fi

[ -n "$_t3126_out" ] && rm -f "$_t3126_out"
exit 0
HOOK_EOF

    chmod +x "$pre_push_hook"
    _verify_hook_written "$pre_push_hook" || { install_failed=true; failed_hooks+=("$pre_push_hook"); }

    # T-2813: report actual disk state, not the write that was attempted.
    # A hook is only listed as installed once _verify_hook_written confirmed
    # it exists and is executable — a hook whose write failed is reported as
    # a failure, never silently folded into a success banner.
    if [ "$install_failed" = true ]; then
        echo -e "${RED}ERROR: hook installation failed — ${#failed_hooks[@]} of 4 hook(s) were not written:${NC}" >&2
        echo "" >&2
        for _fh in "${failed_hooks[@]}"; do
            echo "  - $_fh" >&2
        done
        echo "" >&2
        echo "Cause: the target file does not exist (or is not executable) after the" >&2
        echo "write, which means the write to the hooks directory did not complete —" >&2
        echo "most commonly because the hooks directory itself does not exist or is" >&2
        echo "not writable." >&2
        echo "" >&2
        echo "Fix:" >&2
        echo "  1. Check the resolved hooks dir exists and is writable:" >&2
        echo "       git rev-parse --git-path hooks" >&2
        echo "  2. Re-run: $(_emit_user_command "git install-hooks" 2>/dev/null || echo "fw git install-hooks")" >&2
        echo "" >&2
        exit 1
    fi

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
    echo "  - Runs audit before push (blocks on FAIL, blocks if audit could not run, warns on WARN)"
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
  - pre-push hook: Runs audit before push (blocks on FAIL, and on could-not-run)

The hooks enforce task traceability (P-002: Structural Enforcement).

Pre-push behavior:
  - Audit FAIL (exit 2): Push blocked
  - Audit WARN (exit 1): Push allowed with warning
  - Audit PASS (exit 0): Push allowed
  - Bypass: fw tier0 approve && git push --no-verify (Tier 0 protected)
EOF
}
