#!/bin/bash
# fw init - Bootstrap a new project with the Agentic Engineering Framework
#
# Creates the directory structure, config files, and git hooks needed
# for a project to use the framework.

do_init() {
    local target_dir=""
    local provider="generic"
    local force=false
    # shellcheck disable=SC2034  # reserved for future use
    local first_run=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        # shellcheck disable=SC2034
        case $1 in
            --provider) provider="$2"; shift 2 ;;
            --force) force=true; shift ;;
            --no-first-run) first_run=false; shift ;;
            -h|--help)
                echo -e "${BOLD}fw init${NC} - Bootstrap a new project"
                echo ""
                echo "Usage: fw init [target-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  target-dir        Directory to initialize (default: current directory)"
                echo ""
                echo "Options:"
                echo "  --provider NAME   Generate provider-specific config: claude, cursor, generic (default: generic)"
                echo "  --force           Overwrite existing files"
                echo "  --no-first-run    Skip guided walkthrough after init"
                echo "  -h, --help        Show this help"
                echo ""
                echo "Examples:"
                echo "  fw init                          # Initialize current directory"
                echo "  fw init /path/to/project         # Initialize specific directory"
                echo "  fw init --provider claude        # Generate CLAUDE.md"
                echo "  fw init --provider cursor        # Generate .cursorrules"
                return 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                return 1
                ;;
            *)
                target_dir="$1"; shift
                ;;
        esac
    done

    # Default to current directory
    if [ -z "$target_dir" ]; then
        target_dir="$PWD"
    fi

    # Resolve to absolute path
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Directory does not exist: $target_dir${NC}" >&2
        return 1
    }

    # Check if already initialized
    if [ -f "$target_dir/.framework.yaml" ] && [ "${force:-false}" != true ]; then
        echo -e "${YELLOW}Project already initialized at $target_dir${NC}"
        echo "Use --force to reinitialize"
        return 1
    fi

    # T-2722 (arc-015, F-10): snapshot what is in the directory BEFORE we write anything.
    # Project shape is then inferred from what the USER already had, not from a list of
    # names we hope covers every ecosystem. Taking the census here rather than at seed time
    # matters: `fw init` creates policy/, .tasks/, .context/ etc. before the seed step, so a
    # census taken later has to exclude framework artefacts by name — which is the same
    # allowlist mistake one level down, and would silently break again the next time init
    # learns to create a new directory.
    local -a preexisting_entries=()
    local _e _b
    for _e in "$target_dir"/* "$target_dir"/.[!.]*; do
        [ -e "$_e" ] || continue
        _b="$(basename "$_e")"
        case "$_b" in
            # VCS metadata, editor/OS noise and placeholders are not evidence of a project.
            .git|.gitignore|.gitattributes|.gitmodules|.svn|.hg|.keep|.gitkeep|.DS_Store) continue ;;
            # A prior/partial framework install is scaffolding, not user content.
            # .fw-init-incomplete (T-2801) is ours by definition — it only exists
            # because a previous run of THIS function put it there.
            .agentic-framework|.claude|.framework.yaml|CLAUDE.md|FRAMEWORK.md|.mcp.json|.fw-init-incomplete) continue ;;
        esac
        preexisting_entries+=("$_b")
    done

    # T-2801: mark the directory before touching it, clear the mark after the last
    # step. Between those two points an interruption is *recognisable* — which is
    # the whole fix. Previously the vendor ran at line ~129 and .framework.yaml was
    # written at ~251, so a kill anywhere between (the ~90MB copy is most of the
    # wall clock) left .agentic-framework/bin/fw present, .framework.yaml absent,
    # and no way to tell that state apart from a corrupt install.
    #
    # The sentinel lives at the project root, not inside .agentic-framework/: a
    # re-vendor is free to delete and recreate that directory, and a marker that
    # its own recovery path can erase is not a marker.
    local _init_incomplete_marker="$target_dir/.fw-init-incomplete"
    # Captured BEFORE we write it — this is what tells a re-run that it is a
    # recovery rather than a first init.
    local _resuming_partial_init=false
    [ -f "$_init_incomplete_marker" ] && _resuming_partial_init=true
    {
        echo "# fw init started here and has not finished."
        echo "#"
        echo "# While this file exists the .agentic-framework/ copy beside it may be"
        echo "# partial. fw refuses to route into it (bin/fw-router) rather than run a"
        echo "# CLI that cannot find its own framework."
        echo "#"
        echo "# Recover:  fw init $target_dir"
        echo "# Discard:  rm -rf $target_dir/.agentic-framework $target_dir/.fw-init-incomplete"
        echo "started_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "framework_version: ${FW_VERSION:-unknown}"
    } > "$_init_incomplete_marker"

    local project_display
    project_display=$(basename "$target_dir")
    echo -e "${BOLD}Setting up agentic governance for ${project_display}...${NC}"
    echo ""

    # --- Preflight check (T-303) — quiet mode, only fails on missing required deps ---
    source "$FW_LIB_DIR/preflight.sh" 2>/dev/null || source "$(dirname "${BASH_SOURCE[0]}")/preflight.sh" 2>/dev/null || true
    if type do_preflight >/dev/null 2>&1; then
        if ! do_preflight --quiet; then
            echo ""
            echo -e "${RED}Preflight failed. Run 'fw preflight' for details.${NC}"
            # T-2801: nothing has been written yet — a refusal is not an unfinished
            # init, and leaving the marker would report one.
            rm -f "$_init_incomplete_marker"

            return 1
        fi
    fi

    # --- Git init if needed (T-521: hooks and traceability require git) ---
    if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC}  Initializing git repository"
        git init -q "$target_dir"
    fi

    # --- Git identity inheritance (T-880/F4: inherit from global if not set) ---
    # T-2883: the guard asks whether a commit here would resolve an identity, not
    # whether config carries one. An env-supplied identity (CI, cron, dispatch
    # workers) needs no inheritance and no warning — copying global config over it
    # would also silently change who the commits are attributed to.
    source "$(dirname "${BASH_SOURCE[0]}")/git-identity.sh"
    if ! fw_git_identity_ok "$target_dir"; then
        local global_email
        global_email=$(git config --global user.email 2>/dev/null || true)
        if [ -n "$global_email" ]; then
            local global_name
            global_name=$(git config --global user.name 2>/dev/null || echo "Developer")
            git -C "$target_dir" config user.email "$global_email"
            git -C "$target_dir" config user.name "$global_name"
            echo -e "  ${GREEN}✓${NC}  Git identity inherited from global config ($global_email)"
        else
            echo -e "  ${YELLOW}⚠${NC}   Git identity not configured (commits will fail)"
            echo "       $(fw_git_identity_remedy "$target_dir")"
        fi
    fi

    # --- Vendor framework (T-498: full project isolation) ---
    # T-2801: `.agentic-framework/ already exists` is not evidence that it is
    # complete. When the marker says a previous init died mid-vendor, the existing
    # directory is exactly the thing that needs replacing — skipping it is what
    # made the debris permanent, because the SKIP branch is the one a recovery run
    # would always take.
    #
    # T-2805: the comment above was right and the test below was not wide enough.
    # `_resuming_partial_init` reads the .fw-init-incomplete MARKER — a declared
    # signal, absent from any vendor that predates T-2801 or that died before the
    # marker was written. For those, this branch still took SKIP, so a recovery run
    # printed "Validation passed: 42/43" over a directory with no FRAMEWORK.md and
    # no VERSION. Init reported success and left the project broken; the only
    # reason `fw` still ran there was the router falling back to the global install.
    #
    # Observed 2026-08-05 while verifying the router fix — the success message was
    # convincing enough that the artefact had to be checked to catch it.
    #
    # So also test the OBSERVED signal: FRAMEWORK.md is what bin/fw resolves
    # FRAMEWORK_ROOT by and what do_vendor now writes last, so its absence means
    # the copy did not finish, whatever the marker says.
    local _vendor_incomplete=false
    if [ -d "$target_dir/.agentic-framework" ] && [ ! -f "$target_dir/.agentic-framework/FRAMEWORK.md" ]; then
        _vendor_incomplete=true
    fi
    if [ ! -d "$target_dir/.agentic-framework" ] || [ "${force:-false}" = true ] || [ "$_resuming_partial_init" = true ] || [ "$_vendor_incomplete" = true ]; then
        if [ "$_resuming_partial_init" = true ] && [ -d "$target_dir/.agentic-framework" ]; then
            echo -e "  ${YELLOW}RECOVER${NC}  Previous init did not finish — re-vendoring over the partial copy"
        elif [ "$_vendor_incomplete" = true ]; then
            echo -e "  ${YELLOW}RECOVER${NC}  .agentic-framework/ exists but has no FRAMEWORK.md — re-vendoring over the partial copy"
        fi
        echo -e "${BOLD}Vendoring framework into project...${NC}"
        do_vendor --target "$target_dir"
        echo ""
    else
        echo -e "  ${YELLOW}SKIP${NC}  .agentic-framework/ already exists (use --force to re-vendor)"
    fi

    # --- Create directory structure ---
    #@init: dir-4mf .tasks/active
    # Active tasks directory
    mkdir -p "$target_dir/.tasks/active"
    #@init: dir-7hn .tasks/completed
    # Completed tasks archive
    mkdir -p "$target_dir/.tasks/completed"
    #@init: dir-2pw .tasks/templates
    # Task templates
    mkdir -p "$target_dir/.tasks/templates"
    #@init: dir-9kc .context/working
    # Working memory (session state)
    mkdir -p "$target_dir/.context/working"
    #@init: dir-3xe .context/project
    # Project memory (patterns, decisions, learnings)
    mkdir -p "$target_dir/.context/project"
    #@init: dir-6ja .context/episodic
    # Episodic memory (task histories)
    mkdir -p "$target_dir/.context/episodic"
    #@init: dir-1rv .context/handovers
    # Session handover documents
    mkdir -p "$target_dir/.context/handovers"
    #@init: dir-8qb .context/scans
    # Codebase scan results
    mkdir -p "$target_dir/.context/scans"
    #@init: dir-5wd .context/bus/results
    # Sub-agent result bus
    mkdir -p "$target_dir/.context/bus/results"
    #@init: dir-0tg .context/bus/blobs
    # Sub-agent blob storage
    mkdir -p "$target_dir/.context/bus/blobs"
    #@init: dir-3yn .context/audits/cron
    # Cron audit results
    mkdir -p "$target_dir/.context/audits/cron"
    #@init: dir-7cr .context/cron
    # Git-tracked cron definitions
    mkdir -p "$target_dir/.context/cron"

    #@init: yaml-8cr .context/cron-registry.yaml jobs
    # Cron registry — structured source of truth for scheduled jobs (T-448)
    if [ ! -f "$target_dir/.context/cron-registry.yaml" ]; then
        cat > "$target_dir/.context/cron-registry.yaml" << 'CRONREGEOF'
# Cron Registry — Structured source of truth for scheduled jobs (T-448)
# Read by web/blueprints/cron.py and fw cron generate.
# Editable by humans, controllable via Watchtower web UI.
jobs: []
CRONREGEOF
    fi

    #@init: yaml-5rc .context/bypass-log.yaml bypasses
    # Git hook bypass log
    if [ ! -f "$target_dir/.context/bypass-log.yaml" ]; then
        cat > "$target_dir/.context/bypass-log.yaml" << 'BYPASSEOF'
# Git hook bypass log
# Entries auto-added by post-commit hook when --no-verify is detected
bypasses: []
BYPASSEOF
    fi

    #@init: file-2nb .context/working/.gitignore
    # Volatile file exclusions
    cat > "$target_dir/.context/working/.gitignore" << 'WGIT'
# Volatile session files — regenerated each session
.tool-counter
.prev-token-reading
session.yaml
focus.yaml
tier0-approval

# T-2896: Watchtower's signing key. web/app.py:_resolve_secret_key generates this
# (secrets.token_hex(32), chmod 0600) on first start when FW_SECRET_KEY is unset;
# it signs fw_session_<port> and the CSRF token guarding the T-2277 sovereignty
# surface. chmod is a filesystem control and says nothing to git — a project that
# commits .context/working/ wholesale publishes the key without this line.
# Unanchored on purpose: also covers the copy under .agentic-framework/.
.fw-secret-key
WGIT

    echo -e "  ${GREEN}✓${NC}  Task system (.tasks/)"
    echo -e "  ${GREEN}✓${NC}  Context fabric (.context/)"

    # --- Copy task templates (all .md files from framework templates) ---
    #@init: file-8cz .tasks/templates/default.md
    # Default task template
    local template_count=0
    for tmpl in "$FRAMEWORK_ROOT/.tasks/templates/"*.md; do
        [ -f "$tmpl" ] || continue
        cp "$tmpl" "$target_dir/.tasks/templates/$(basename "$tmpl")"
        template_count=$((template_count + 1))
    done
    if [ "$template_count" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC}   No task templates found"
    fi

    #@init: yaml-8kj .framework.yaml project_name,version,provider
    # Project configuration
    local project_name
    project_name=$(basename "$target_dir")
    local init_timestamp
    init_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Auto-detect upstream repo from framework's git remotes
    # T-575: Accept any git remote, not just GitHub
    local upstream_repo=""
    if [ -d "$FRAMEWORK_ROOT/.git" ]; then
        local remote_url
        remote_url=$(git -C "$FRAMEWORK_ROOT" remote get-url origin 2>/dev/null) || true
        # If no origin, try first available push remote
        if [ -z "$remote_url" ]; then
            remote_url=$(git -C "$FRAMEWORK_ROOT" remote -v 2>/dev/null | grep "(push)" | head -1 | awk '{print $2}') || true
        fi
        if [ -n "$remote_url" ]; then
            # T-2817: strip any embedded credential BEFORE persisting. This value
            # lands in .framework.yaml, which is a TRACKED file of the new project,
            # so a framework cloned as https://TOKEN@host/... would write that token
            # into every project it creates. upstream_repo is a LOCATION, not an
            # authentication method — git resolves credentials from the credential
            # helper or netrc at fetch time, so dropping userinfo costs nothing.
            #
            # Requires "://" so scp-style SSH remotes (git@host:owner/repo) are left
            # alone; their "git@" is a username, not a secret, and mangling it would
            # break the remote. The github.com branch below already dropped userinfo
            # incidentally, by extracting owner/repo — this makes it deliberate and
            # extends it to every other host (OneDev, GitLab, Gitea).
            remote_url=$(printf '%s' "$remote_url" | sed -E 's|^([a-zA-Z][a-zA-Z0-9+.-]*://)[^/@]*@|\1|')

            # GitHub URLs: extract owner/repo for compact display
            if echo "$remote_url" | grep -q "github.com"; then
                upstream_repo=$(echo "$remote_url" | sed -E 's|.*github\.com[:/]||;s|\.git$||')
            else
                # Non-GitHub: store full URL (OneDev, GitLab, Gitea, etc.)
                upstream_repo="${remote_url%.git}"
            fi
        fi
    fi

    cat > "$target_dir/.framework.yaml" << FYAML
# Agentic Engineering Framework - Project Configuration
# framework_path removed (T-498) — fw resolves from .agentic-framework/bin/fw location
project_name: $project_name
version: $FW_VERSION
provider: $provider
initialized_at: $init_timestamp
${upstream_repo:+upstream_repo: $upstream_repo}
FYAML
    # .framework.yaml created

    # --- Seed governance files ---

    #@init: yaml-7dg .context/project/practices.yaml practices
    # Graduated practices
    if [ ! -f "$target_dir/.context/project/practices.yaml" ] || [ "${force:-false}" = true ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/seeds/practices.yaml" ]; then
            cp "$FRAMEWORK_ROOT/lib/seeds/practices.yaml" "$target_dir/.context/project/practices.yaml"
        else
            cat > "$target_dir/.context/project/practices.yaml" << 'PRAML'
# Project Practices - Graduated learnings (3+ applications)
# Promoted via: fw promote L-XXX --name "practice name" --directive D1
practices: []
PRAML
        fi
    fi

    #@init: yaml-4fs .context/project/decisions.yaml decisions
    # Architectural decisions
    if [ ! -f "$target_dir/.context/project/decisions.yaml" ] || [ "${force:-false}" = true ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/seeds/decisions.yaml" ]; then
            cp "$FRAMEWORK_ROOT/lib/seeds/decisions.yaml" "$target_dir/.context/project/decisions.yaml"
        else
            cat > "$target_dir/.context/project/decisions.yaml" << 'DYAML'
# Project Decisions - Architectural choices with rationale
# Added via: fw context add-decision "description" --task T-XXX --rationale "why"
decisions:
DYAML
        fi
    fi

    #@init: yaml-1qm .context/project/patterns.yaml failure_patterns
    # Failure/success/workflow patterns
    if [ ! -f "$target_dir/.context/project/patterns.yaml" ] || [ "${force:-false}" = true ]; then
        if [ -f "$FRAMEWORK_ROOT/lib/seeds/patterns.yaml" ]; then
            cp "$FRAMEWORK_ROOT/lib/seeds/patterns.yaml" "$target_dir/.context/project/patterns.yaml"
        else
            cat > "$target_dir/.context/project/patterns.yaml" << 'PYAML'
# Project Patterns - Learned from experience
# Categories: failure, success, workflow
# Added via: fw context add-pattern <type> "name" --task T-XXX
failure_patterns: []
success_patterns: []
workflow_patterns: []
PYAML
        fi
    fi

    #@init: yaml-6wt .context/project/learnings.yaml learnings
    # Project learnings
    if [ ! -f "$target_dir/.context/project/learnings.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/learnings.yaml" << 'LYAML'
# Project Learnings - Knowledge gained during development
# Added via: fw context add-learning "description" --task T-XXX
learnings:
LYAML
    fi

    # T-2261 / arc-006 (T-2229 Slice 2A): bootstrap BVP policy files from
    # framework templates. Mirror of the practices/decisions/patterns cp pattern
    # above. Per-file idempotent — pre-existing consumer customisation survives.
    # Skipped silently when --force re-runs: the destination existence check
    # handles re-init without trampling customisations.
    mkdir -p "$target_dir/policy"
    #@init: yaml-2bv policy/value-drivers.yaml protected_drivers
    # BVP value-drivers definitions (T-2229)
    if [ ! -f "$target_dir/policy/value-drivers.yaml" ]; then
        if [ -f "$FRAMEWORK_ROOT/policy/value-drivers.yaml" ]; then
            cp "$FRAMEWORK_ROOT/policy/value-drivers.yaml" "$target_dir/policy/value-drivers.yaml"
        fi
    fi
    #@init: md-3bv policy/bvp-scoring-rubric.md
    # BVP scoring rubric (T-1921/T-2259)
    if [ ! -f "$target_dir/policy/bvp-scoring-rubric.md" ]; then
        if [ -f "$FRAMEWORK_ROOT/policy/bvp-scoring-rubric.md" ]; then
            cp "$FRAMEWORK_ROOT/policy/bvp-scoring-rubric.md" "$target_dir/policy/bvp-scoring-rubric.md"
        fi
    fi

    #@init: yaml-9he .context/project/assumptions.yaml assumptions
    # Tracked assumptions
    if [ ! -f "$target_dir/.context/project/assumptions.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/assumptions.yaml" << 'AYAML'
# Project Assumptions - Tracked via inception workflow
# Added via: fw assumption add "description" --task T-XXX
# Validated via: fw assumption validate A-XXX --evidence "..."
assumptions: []
AYAML
    fi

    #@init: yaml-3bp .context/project/directives.yaml directives
    # Constitutional directives
    if [ ! -f "$target_dir/.context/project/directives.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/directives.yaml" << 'DRYAML'
# Project Directives - Constitutional principles (priority order)
# These are stable anchors — changes require human sovereignty approval

directives:
  - id: D1
    name: "Antifragility"
    statement: "The system must get stronger under stress, not merely survive it."
    priority: 1

  - id: D2
    name: "Reliability"
    statement: "The system must behave predictably and consistently under known conditions."
    priority: 2

  - id: D3
    name: "Usability"
    statement: "The framework must be a joy to use, extend, and debug."
    priority: 3

  - id: D4
    name: "Portability"
    statement: "The framework must not be captive to any single provider, language, or environment."
    priority: 4
DRYAML
    fi

    #@init: yaml-0vk .context/project/concerns.yaml concerns
    # Unified concerns register (T-397: gaps + risks)
    if [ ! -f "$target_dir/.context/project/concerns.yaml" ] || [ "${force:-false}" = true ]; then
        cat > "$target_dir/.context/project/concerns.yaml" << 'CYAML'
# Concerns Register — Unified gap and risk tracking (T-397)
# Type: gap (spec-reality) | risk (forward-looking)
# Status: watching | decided-build | decided-simplify | decided-defer | closed
concerns: []
CYAML
    fi

    echo -e "  ${GREEN}✓${NC}  Seeded: 10 practices, 18 decisions, 12 patterns"
    echo -e "  ${GREEN}✓${NC}  Initialized: learnings, assumptions, directives, gaps"

    # --- Generate provider config ---
    case "$provider" in
        claude)
            #@init: file-7xr CLAUDE.md ?claude,generic
            # Agent instruction file
            generate_claude_md "$target_dir" >/dev/null
            #@init: json-3fz .claude/settings.json hooks ?claude,generic
            # Claude Code hooks configuration
            #@init: hookpaths-6vc .claude/settings.json ?claude,generic
            # Hook script paths all resolve
            #@init: file-4ej .claude/commands/resume.md ?claude,generic
            # Resume slash command
            generate_claude_code_config "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  CLAUDE.md generated"
            echo -e "  ${GREEN}✓${NC}  Claude Code hooks (10 configured)"
            ;;
        cursor)
            #@init: file-6qs .cursorrules ?cursor
            # Cursor rules file
            generate_cursorrules "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  .cursorrules generated"
            ;;
        generic)
            # Tags declared in claude branch with ?claude,generic condition
            generate_claude_md "$target_dir" >/dev/null
            generate_claude_code_config "$target_dir" >/dev/null
            echo -e "  ${GREEN}✓${NC}  CLAUDE.md generated"
            echo -e "  ${GREEN}✓${NC}  Claude Code hooks (10 configured)"
            ;;
        *)
            echo -e "  ${YELLOW}⚠${NC}   Unknown provider '$provider', using generic"
            generate_claude_md "$target_dir" >/dev/null
            generate_claude_code_config "$target_dir" >/dev/null
            ;;
    esac

    # --- Git hooks (T-880/F3: auto-install for commit traceability) ---
    local git_sh="$target_dir/.agentic-framework/agents/git/git.sh"
    if [ -x "$git_sh" ]; then
        if PROJECT_ROOT="$target_dir" "$git_sh" install-hooks 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC}  Git hooks installed (commit traceability active)"
        else
            echo -e "  ${YELLOW}⚠${NC}   Git hooks install failed — run 'fw git install-hooks' manually"
        fi
    fi

    # --- Enforcement baseline (T-880/F5: auto-create for drift detection) ---
    if [ ! -f "$target_dir/.context/project/enforcement-baseline.sha256" ]; then
        local fw_bin="$target_dir/.agentic-framework/bin/fw"
        if [ -x "$fw_bin" ] && [ -f "$target_dir/.claude/settings.json" ]; then
            if PROJECT_ROOT="$target_dir" "$fw_bin" enforcement baseline >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC}  Enforcement baseline created"
            fi
        fi
    fi

    # --- Activate governance: initialize session context (T-002) ---
    # F5 (T-2444): route through the project's vendored fw — the SAME entry
    # point as the `fw context init` recovery — so context.sh runs with the
    # full env bin/fw exports. The earlier direct `context.sh init` call set
    # only PROJECT_ROOT, so context.sh's `set -euo pipefail` aborted on env
    # bin/fw would have provided, while the recovery (same script via bin/fw)
    # succeeded. The old `2>/dev/null` masked the real error (Directive-2) —
    # capture stderr and surface it on failure instead of discarding it.
    echo ""
    echo -e "Activating governance..."
    local si_fw="$target_dir/.agentic-framework/bin/fw"
    [ -x "$si_fw" ] || si_fw="$FRAMEWORK_ROOT/bin/fw"
    if [ -x "$si_fw" ]; then
        local si_err
        if si_err="$(PROJECT_ROOT="$target_dir" "$si_fw" context init 2>&1 >/dev/null)"; then
            echo -e "  ${GREEN}✓${NC}  Session initialized (governance active)"
        else
            echo -e "  ${YELLOW}⚠${NC}  Session init failed — run 'fw context init' manually"
            [ -n "$si_err" ] && echo "$si_err" | sed 's/^/      /' >&2
        fi
    fi

    # --- Copy onboarding task templates (T-460) ---
    local has_existing_tasks=false
    local has_code=false

    # Skip if tasks already exist (idempotent on --force re-init)
    #
    # T-2712: check completed/ TOO. Completing a task moves it out of active/, so a
    # project that finished its onboarding presented an empty active/, was judged
    # fresh, and had T-001..T-005 re-seeded over IDs it had already used and
    # committed against — a duplicate-ID generator aimed squarely at the projects
    # that made progress. The `check-active-completed-dup` hook defends this class
    # downstream; this guard was manufacturing it upstream.
    #
    # The question is "has this project ever had tasks", so it must consider every
    # directory an ID can live in, not just the one holding open work.
    local _seed_dir_probe
    for _seed_dir_probe in active completed; do
        if [ -d "$target_dir/.tasks/$_seed_dir_probe" ] \
           && ls "$target_dir/.tasks/$_seed_dir_probe/"T-*.md >/dev/null 2>&1; then
            has_existing_tasks=true
            break
        fi
    done

    if [ "$has_existing_tasks" = false ]; then
        # T-2722 (arc-015, F-10): infer project shape by ENUMERATION, not by an allowlist.
        #
        # The previous implementation asked "is one of these seven manifests present?" and
        # treated a miss as positive evidence of an empty directory. Every ecosystem off the
        # list (.NET, C/C++, PHP, flat Python, Ruby, Gradle, …) was therefore seeded greenfield,
        # which lands an owner:human inception task that the T-532 gate then uses to block all
        # other edits — a first-run deadlock the agent is structurally forbidden to clear.
        #
        # Lengthening the list was explicitly rejected (T-2718 Decisions): it reproduces the
        # identical property with a later failure date, because the defect is not WHICH names
        # are listed, it is that THE LIST IS THE ORACLE.
        #
        # Inverted: greenfield must be positively established — the directory contains nothing
        # but framework scaffolding, VCS metadata and placeholders. Anything else means we
        # found something we did not put here, so treat it as an existing project. The cost
        # asymmetry drives the direction: existing→greenfield is a wall the user cannot clear,
        # greenfield→existing is mild noise.
        # The census was taken at function entry, before we created anything (see above).
        local -a found_entries=("${preexisting_entries[@]}")
        [ ${#found_entries[@]} -gt 0 ] && has_code=true

        local seed_dir
        if [ "$has_code" = true ]; then
            seed_dir="$FRAMEWORK_ROOT/lib/seeds/tasks/existing-project"
        else
            seed_dir="$FRAMEWORK_ROOT/lib/seeds/tasks/greenfield"
        fi

        if [ -d "$seed_dir" ]; then
            local task_count=0
            local init_date
            init_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            for tmpl in "$seed_dir"/T-*.md; do
                [ -f "$tmpl" ] || continue
                local dest
                dest="$target_dir/.tasks/active/$(basename "$tmpl")"
                sed \
                    -e "s|__PROJECT_NAME__|$project_display|g" \
                    -e "s|__DATE__|$init_date|g" \
                    "$tmpl" > "$dest"
                task_count=$((task_count + 1))
            done
            if [ "$task_count" -gt 0 ]; then
                local mode_label="existing project"
                [ "$has_code" = false ] && mode_label="greenfield"
                # T-2722: state the EVIDENCE, not just the verdict. A wrong inference is then
                # legible here, at the moment it happens, instead of surfacing three commands
                # later as an unexplained gate refusal. Cap the list so a large repo does not
                # bury the line it is meant to clarify.
                if [ "$has_code" = true ]; then
                    local shown="${found_entries[*]:0:6}"
                    local more=""
                    [ ${#found_entries[@]} -gt 6 ] && more=" +$(( ${#found_entries[@]} - 6 )) more"
                    echo -e "  ${CYAN}·${NC}  found ${#found_entries[@]} existing item(s): ${shown// /, }${more}"
                else
                    echo -e "  ${CYAN}·${NC}  found nothing but framework scaffolding — treating as a new project"
                fi
                echo -e "  ${GREEN}✓${NC}  $task_count onboarding tasks ($mode_label mode)"
            fi
        fi
    fi

    # --- Post-init validation (T-461: Tier 1 structural + Tier 2 functional) ---
    #
    # T-2727: this block used to run BEFORE governance activation and before the
    # onboarding tasks were seeded, ~114 lines earlier. `func-tasks` — the check
    # that parses .tasks/active/ and verifies the onboarding tasks have valid
    # frontmatter — is guarded by `active_tasks > 0`, so on a fresh init it found
    # an empty directory, did not run, and (because the guard sits outside the
    # `total++`) was not counted either. It appeared in neither the numerator nor
    # the denominator and printed nothing: a check that never ran and a check that
    # does not exist were indistinguishable from the output.
    #
    # The artifact it protects is the onboarding task set — the thing a first-run
    # user is handed. Validation must run last so its verdict describes the tree
    # the user is actually left with, not an intermediate state that no longer
    # exists by the time init returns.
    echo ""
    echo -e "${BOLD}Validating...${NC}"
    source "$FW_LIB_DIR/validate-init.sh" 2>/dev/null || \
        source "$(dirname "${BASH_SOURCE[0]}")/validate-init.sh" 2>/dev/null || true
    if type do_validate_init >/dev/null 2>&1; then
        if ! do_validate_init "$target_dir" --provider "$provider"; then
            echo ""
            echo -e "${YELLOW}Init completed with validation errors — check output above${NC}"
        fi
    fi

    # --- Done ---
    # T-2801: last write of the function, deliberately. Everything above can be
    # interrupted; clearing the marker is the single act that says it wasn't.
    # Validation above is allowed to report errors without blocking this — a
    # project that validated badly is still a finished init, and leaving the
    # marker would send `fw` to the global install forever.
    rm -f "$_init_incomplete_marker"

    # --- Bootstrap commit: give the project a resolvable HEAD (T-2821) ---
    #
    # Placed LAST, after the marker clear, for the same reason T-2727 moved
    # post-init validation last: the commit's TREE must describe the tree the
    # user is actually left with, not an intermediate state that no longer
    # exists by the time init returns. T-2821 placed it right after hook install
    # (~150 lines earlier), which committed a partial scaffolding — measured:
    # it captured the `.fw-init-incomplete` sentinel that init then DELETES, and
    # missed the enforcement baseline and all five seeded onboarding tasks. A
    # worktree cut from that commit had `.tasks/` but no tasks in it, which is
    # the populated-looking-but-broken state this fix exists to prevent.
    #
    # Hooks are installed far earlier, so running here only strengthens the
    # "validated by the project's own hooks" guarantee below.
    #
    # `git init` alone leaves HEAD unborn (`git rev-parse HEAD` → exit 128).
    # Claude Code's background-session isolation (`EnterWorktree`) preflights
    # with exactly that check and refuses to isolate — and refuses to isolate
    # means refuses every Write/Edit — deadlocking the very first background
    # session before it can write anything, including its own task file.
    #
    # The commit stages what `fw init` just created (T-2827). An EMPTY commit
    # is NOT sufficient and was the original T-2821 defect: it gives a HEAD that
    # resolves but whose TREE has zero files, so `git worktree add` checks out
    # nothing and still yields an empty worktree — the same user-visible failure
    # as OBS-175 via a different mechanism (empty-tree checkout rather than
    # orphan inference). Measured live in T-2826 on published bytes: worktree
    # held 1 entry (`.git`), no CLAUDE.md. Resolvability was a PROXY for the
    # property the real use needs, which is "HEAD has content", and the proxy
    # diverged from the thing (OBS-178).
    #
    # Everything staged, not a curated subset: a background agent needs
    # CLAUDE.md, .claude/, .tasks/, .context/ AND .agentic-framework/ — without
    # the vendored CLI there is no `fw` in the worktree and no governance runs
    # at all, so a partial commit produces a worktree that LOOKS populated and
    # is still broken. All of it is framework-owned (9 top-level entries that
    # `fw init` itself just wrote), so this makes no decision about the
    # operator's project content, and onboarding task T-003 ("First governed
    # commit") still asks for exactly that. See T-2827 Decisions.
    #
    # Placed AFTER git hooks are installed (above) so this commit is validated
    # BY the project's own commit-msg + pre-commit hooks (task-ref check,
    # T-1844 secret-scan, T-1845 large-file, T-1863 dup-task-id) rather than
    # bypassing them with --no-verify — shipping every project with a bypass
    # in its first commit would be worse than the bug (T-2821 hard rule).
    # T-2821 noted an empty commit satisfies the scan/large-file/dup-id hooks
    # TRIVIALLY (no staged diff to inspect) — which is precisely why it was weak
    # evidence that the hooks work. A populated commit actually exercises them.
    # Verified live (T-2826 LEG6): staging all 2353 files and committing passes
    # every hook with no --no-verify. The commit-msg hook only requires a
    # `T-[0-9]+` pattern, so `T-000` — the framework's own established
    # placeholder for "no real task applies" (agents/handover/handover.sh:57) —
    # passes it.
    #
    # Author/committer identity is scoped to this one commit via env vars, not
    # written to git config, so it succeeds even when neither global nor local
    # git identity is configured (T-2818: the common case on a fresh machine,
    # not a corner case — the identity warning above is about the OPERATOR's
    # future commits, and is deliberately left unaffected by this bootstrap).
    #
    # Guarded on unborn HEAD so this is a no-op for existing-project inits
    # (already have a HEAD) and idempotent under --force re-init.
    if ! git -C "$target_dir" rev-parse -q --verify HEAD >/dev/null 2>&1; then
        local _bootstrap_err _bootstrap_n
        # Stage what init created. `add -A` honours any .gitignore init wrote
        # (currently none), so this stays the framework's own tracking surface.
        git -C "$target_dir" add -A >/dev/null 2>&1 || true
        _bootstrap_n=$(git -C "$target_dir" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
        if _bootstrap_err=$(GIT_AUTHOR_NAME="fw init" GIT_AUTHOR_EMAIL="fw-init@localhost" \
            GIT_COMMITTER_NAME="fw init" GIT_COMMITTER_EMAIL="fw-init@localhost" \
            git -C "$target_dir" commit --allow-empty -q \
                -m "T-000: fw init bootstrap commit (framework scaffolding — gives the project a resolvable HEAD with a non-empty tree)" 2>&1); then
            echo -e "  ${GREEN}✓${NC}  Bootstrap commit created — ${_bootstrap_n} file(s) tracked (worktree isolation)"
            # A resolvable HEAD over an EMPTY tree is the OBS-178 failure and is
            # indistinguishable from success unless the tree is checked (T-2827).
            if [ "${_bootstrap_n:-0}" -eq 0 ]; then
                echo -e "  ${YELLOW}⚠${NC}   Bootstrap tree is EMPTY — worktree isolation will yield an empty"
                echo "       worktree (OBS-178). Commit the project scaffolding before dispatching"
                echo "       a background agent: cd \"$target_dir\" && git add -A && git commit -m \"T-000: scaffolding\""
            fi
        else
            echo -e "  ${YELLOW}⚠${NC}   Bootstrap commit failed — HEAD remains unresolved:"
            echo "       run manually: cd \"$target_dir\" && git add -A && git commit -m \"T-000: bootstrap\""
            [ -n "$_bootstrap_err" ] && echo "$_bootstrap_err" | sed 's/^/      /' >&2
        fi
    fi

    # T-2818 / OBS-170: a fresh machine has no global git identity, so `git commit`
    # dies RC=128 "Author identity unknown" *before any framework hook runs* — which
    # makes onboarding task T-003 ("First governed commit") impossible to complete.
    #
    # This was not an unwarned condition. It was warned THREE times: here at ~line 4
    # of ~120 lines of init output, by `fw doctor`, and by the git-identity block
    # above. What made it invisible is that every line the operator reads AFTER the
    # warning contradicts it — 43/44 validation checks green, "Done! Governance is
    # active.", "Next step: start your AI agent". The last thing read wins, and the
    # last thing read said the project was ready.
    #
    # So the fix is not another warning; it is putting this one where the eye lands.
    # Re-check at the end rather than reusing a flag from the earlier block: init may
    # have SET the identity in between (inherited from global), and a stale flag
    # would report a blocker that no longer exists.
    local _identity_missing=false
    fw_git_identity_ok "$target_dir" || _identity_missing=true

    echo ""
    if [ "$_identity_missing" = true ]; then
        echo -e "${GREEN}Done!${NC} Governance is active — ${YELLOW}but this machine cannot commit yet.${NC}"
    else
        echo -e "${GREEN}Done!${NC} Governance is active."
    fi
    echo ""
    if [ "$_identity_missing" = true ]; then
        echo -e "  ${YELLOW}${BOLD}Do this first:${NC} set a git identity, or every commit fails with"
        echo -e "  \"Author identity unknown\" — including onboarding task T-003."
        echo ""
        echo -e "    $(fw_git_identity_remedy "$target_dir")"
        echo ""
        echo -e "  (Drop ${BOLD}--global${NC} in, or set it on this repo only as above.)"
        echo ""
    fi
    echo -e "  ${BOLD}Next step:${NC} Start your AI agent (e.g. Claude Code) in this directory."
    if [ "$has_existing_tasks" = false ] && [ -d "$target_dir/.tasks/active" ] && ls "$target_dir/.tasks/active/"T-*.md >/dev/null 2>&1; then
        local onboard_count
        onboard_count=$(ls "$target_dir/.tasks/active/"T-*.md 2>/dev/null | wc -l)
        echo -e "  Onboarding tasks are ready — ${BOLD}$onboard_count tasks${NC} will guide you through setup."
    fi
    echo ""
    echo -e "  ${BOLD}Dashboard${NC}: fw serve"
    echo -e "  ${BOLD}All commands${NC}: fw help"
}

# --- Provider Config Generators ---

generate_claude_md() {
    local dir="$1"
    local config_file="$dir/CLAUDE.md"

    if [ -f "$config_file" ] && [ "${force:-false}" != true ]; then
        echo -e "  ${YELLOW}SKIP${NC}  CLAUDE.md already exists (use --force to overwrite)"
        return
    fi

    local project_name
    project_name=$(basename "$dir")

    local template_file="$FRAMEWORK_ROOT/lib/templates/claude-project.md"

    if [ -f "$template_file" ]; then
        # Use comprehensive template with placeholder substitution
        # T-572: removed __FRAMEWORK_ROOT__ substitution (G-021 path isolation — no absolute paths in committed files)
        sed \
            -e "s|__PROJECT_NAME__|$project_name|g" \
            "$template_file" > "$config_file"
    else
        # Fallback: inline minimal CLAUDE.md if template missing
        cat > "$config_file" << CMDEOF
# CLAUDE.md

Project configuration for the Agentic Engineering Framework.

## Project Overview

**Project:** $project_name

## Core Principle

**Nothing gets done without a task.** This is enforced structurally by the framework.

## Framework Integration

This project uses the Agentic Engineering Framework as shared tooling.

\`\`\`bash
# All operations go through fw
fw help                              # See all commands
fw task create --name "..." --type build --owner human
fw git commit -m "T-XXX: description"
fw audit                             # Check compliance
fw context status                    # View context state
fw handover --commit                 # End-of-session handover
\`\`\`

## Quick Reference

| Action | Command |
|--------|---------|
| Create task | \`fw task create\` |
| Commit | \`fw git commit -m "T-XXX: ..."\` |
| Audit | \`fw audit\` |
| Initialize session | \`fw context init\` |
| Set focus | \`fw context focus T-XXX\` |
| Handover | \`fw handover --commit\` |
| Health check | \`fw doctor\` |
| Metrics | \`fw metrics\` |

## Session Protocol

**Start:** \`fw context init\` → read handover → \`fw context focus T-XXX\`
**End:** session capture → \`fw handover --commit\`
CMDEOF
    fi
}

generate_claude_code_config() {
    local dir="$1"

    # --- .claude/settings.json (PostToolUse hook for context protection) ---
    mkdir -p "$dir/.claude/commands"

    # T-663/T-662: Detect framework-mode vs consumer-mode for fw path.
    # T-1364 (G-053-A): hook commands must NOT be CWD-relative — Claude Code
    # resolves them against the session CWD, and CWD drift (test fixtures, subdir
    # navigation) cascades into hook-cannot-find-fw tool-blocks (680 silent
    # failures at 003-NTB-ATC-Plugin, see T-1504).
    # T-2709 (from T-2704 RCA): the fix for that was baking $dir — the GENERATING
    # host's checkout path — into the emitted string, which breaks on every other
    # host. ${CLAUDE_PROJECT_DIR} is expanded by Claude Code to the project root
    # before the hook runs, so it is absolute-after-expansion (T-1364's constraint
    # is fully kept) AND host-portable. Detection below still inspects the REAL
    # filesystem via $dir — only the emitted prefix is a placeholder.
    #
    # The literal must be SINGLE-quoted: the heredoc below is intentionally
    # unquoted so "$fw_prefix" expands, and heredoc expansion is a single pass —
    # so the placeholder survives verbatim into settings.json. Double-quoting here
    # would let the generating shell eat it. Pinned by
    # tests/unit/hook_absolute_paths.bats + tests/lint/hook-paths-portable.bats.
    local fw_prefix='${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw'
    if [ -x "$dir/bin/fw" ] && [ -f "$dir/FRAMEWORK.md" ]; then
        fw_prefix='${CLAUDE_PROJECT_DIR}/bin/fw'
    fi

    if [ ! -f "$dir/.claude/settings.json" ] || [ "${force:-false}" = true ]; then
        # T-2710: the heredoc below is a fixed template, but the on-disk file is the
        # real source of truth — `fw hook-enable` adds hooks the template never knew
        # about (6 of them in this repo). Overwriting unconditionally deletes them
        # and takes their gates down silently. Snapshot first, merge back after.
        local prev_settings=""
        if [ -f "$dir/.claude/settings.json" ]; then
            prev_settings=$(mktemp)
            cp "$dir/.claude/settings.json" "$prev_settings"
        fi

        # Use unquoted heredoc so $fw_prefix expands (T-663: framework-aware hook paths)
        cat > "$dir/.claude/settings.json" << SJSON
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook pre-compact"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook post-compact-resume"
          }
        ]
      },
      {
        "matcher": "resume",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook post-compact-resume"
          }
        ]
      },
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook post-compact-resume"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "EnterPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook block-plan-mode"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-active-task"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-human-ac-tick"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-active-completed-dup"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-arc-id"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-heredoc-cmd-sub"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-inception-decisions"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-inception-schema"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-onboarding-gate"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-tier0"
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-agent-dispatch"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-project-boundary"
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook budget-gate"
          }
        ]
      },
      {
        "matcher": "TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook block-task-tools"
          }
        ]
      },
      {
        "matcher": "mcp__termlink__termlink_channel_post",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-rail-mcp-label"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook checkpoint post-tool"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook error-watchdog"
          }
        ]
      },
      {
        "matcher": "Task|TaskOutput",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-dispatch"
          }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook loop-detect"
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook check-fabric-new-file"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook commit-cadence"
          },
          {
            "type": "command",
            "command": "$fw_prefix hook check-settings-edit"
          }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$fw_prefix hook audit-task-tools"
          }
        ]
      }
    ]
  }
}
SJSON
        # T-2710: fold the snapshot's non-template hooks back in. Template wins for
        # names it defines, so path fixes (T-2709) still propagate on upgrade; hooks
        # only the snapshot has are carried forward and REPORTED, not dropped mute.
        if [ -n "$prev_settings" ]; then
            local merge_py="${FW_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/settings_merge.py"
            if [ -f "$merge_py" ] && command -v python3 >/dev/null 2>&1; then
                if ! python3 "$merge_py" "$dir/.claude/settings.json" "$prev_settings"; then
                    echo -e "  ${YELLOW}WARN${NC}  settings.json merge failed — hooks added via 'fw hook-enable' may have been dropped; previous copy: $prev_settings"
                    prev_settings=""   # keep the snapshot for recovery
                fi
            else
                echo -e "  ${YELLOW}WARN${NC}  settings_merge.py or python3 unavailable — non-template hooks not preserved; previous copy: $prev_settings"
                prev_settings=""
            fi
            if [ -n "$prev_settings" ]; then
                rm -f "$prev_settings"
            fi
        fi
        # T-2912: this line used to be a hardcoded 14-name list that printed
        # unconditionally — true on the day it was written, false the moment
        # the template's hook set drifted from it (T-2911: 7 hooks the
        # template didn't know about). It claimed "all hooks" in the same
        # breath a caller (fw upgrade step 5) could report hooks still
        # missing. Report what was actually written instead of a fixed
        # claim — a caller that wants convergence detection compares against
        # the framework's canonical set itself (lib/upgrade.sh step 5).
        local _t2912_hook_count
        _t2912_hook_count=$(python3 -c "
import json
try:
    with open('$dir/.claude/settings.json') as f:
        data = json.load(f)
    n = sum(len(entry.get('hooks', [])) for entries in data.get('hooks', {}).values() for entry in entries)
except Exception:
    n = '?'
print(n)
" 2>/dev/null || echo "?")
        echo -e "  ${GREEN}OK${NC}  .claude/settings.json written ($_t2912_hook_count hook command(s) configured)"
    else
        # T-677: Pre-existing settings.json — back up and overwrite with framework hooks
        # The framework's governance hooks are authoritative; project-specific hooks from
        # other systems (vnx, etc.) are not compatible and reference non-local paths.
        cp "$dir/.claude/settings.json" "$dir/.claude/settings.json.pre-fw"
        local save_force="${force:-false}"
        force=true
        generate_claude_code_config "$dir"
        force="$save_force"
        echo -e "  ${GREEN}REPLACED${NC}  .claude/settings.json — framework hooks applied (original backed up to settings.json.pre-fw)"
    fi

    # --- .mcp.json (MCP server configuration for Claude Code) ---
    if [ ! -f "$dir/.mcp.json" ] || [ "${force:-false}" = true ]; then
        cat > "$dir/.mcp.json" << 'MCPJSON'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--no-sandbox"]
    },
    "termlink": {
      "command": "termlink",
      "args": ["mcp", "serve"]
    },
    "fw": {
      "command": "python3",
      "args": [".agentic-framework/agents/mcp/framework_mcp_server.py"]
    }
  }
}
MCPJSON
        echo -e "  ${GREEN}OK${NC}  .mcp.json (MCP servers: context7, playwright, termlink, fw)"
    else
        echo -e "  ${YELLOW}SKIP${NC}  .mcp.json already exists"
    fi

    # --- .claude/commands/resume.md (project-specific /resume) ---
    # T-1383 (closes G-056): prefer shared template at lib/templates/resume-md.md
    # so upgrade.sh can detect drift and refresh existing consumers.
    local resume_tmpl="$FRAMEWORK_ROOT/lib/templates/resume-md.md"
    if [ ! -f "$dir/.claude/commands/resume.md" ] || [ "${force:-false}" = true ]; then
        if [ -f "$resume_tmpl" ]; then
            cp "$resume_tmpl" "$dir/.claude/commands/resume.md"
            echo -e "  ${GREEN}OK${NC}  .claude/commands/resume.md"
        else
        cat > "$dir/.claude/commands/resume.md" << 'RESUME'
# /resume - Context Recovery for Agentic Engineering Framework

When the user says `/resume`, "pick up", or "continue", execute this workflow.

## Step 1: Gather State

Run these in parallel:

1. Read `.context/handovers/LATEST.md`
2. Run `git status --short` and `git log --oneline -5`
3. List `.tasks/active/` and extract task IDs, names, and statuses from frontmatter
4. Check tool counter: `cat .context/working/.tool-counter`
5. Check web server: `WURL=$(cat .context/working/watchtower.url 2>/dev/null || echo "http://localhost:$(bin/fw config get PORT 2>/dev/null || echo 3000)"); curl -sf "$WURL/" > /dev/null && echo "running at $WURL" || echo "stopped"`
   (Never hard-code `:3000` — the triple file `.context/working/watchtower.{pid,port,url}` is the single source of truth for Watchtower's current port. See `bin/fw doctor` for diagnostics.)

## Step 2: Summarize

Present this format (fill from gathered data):

```
## Context Restored

**Last Handover:** {session_id} ({timestamp})
**Last Commit:** {hash} - {message}
**Branch:** {branch}

### Where We Are
{paste the "Where We Are" section from LATEST.md}

### Active Tasks
- {T-XXX}: {name} ({status})

### Current State
- Git: {clean/N uncommitted files}
- Web UI: {running at {URL from .context/working/watchtower.url} / stopped}
- Tool counter: {N} (P-009)

### Suggested Action
{paste from LATEST.md "Suggested First Action" section}
```

## Step 3: Offer Next Steps

List the logical next actions as plain text (numbered). Derive from:
- The handover's "Suggested First Action"
- Any tasks with status `started-work`
- Uncommitted changes that need attention

Then ask: "What would you like to work on?"

## Rules

- Do NOT use AskUserQuestion (may be blocked in dontAsk mode) — use plain text
- Keep output concise — no commentary
- If LATEST.md has unfilled `[TODO]` sections, warn about stale handover
- If tool counter > 0 at session start, the PostToolUse hook is working
RESUME
        echo -e "  ${GREEN}OK${NC}  .claude/commands/resume.md"
        fi
    else
        echo -e "  ${YELLOW}SKIP${NC}  .claude/commands/resume.md already exists"
    fi
}

generate_cursorrules() {
    local dir="$1"
    local config_file="$dir/.cursorrules"

    if [ -f "$config_file" ] && [ "${force:-false}" != true ]; then
        echo -e "  ${YELLOW}SKIP${NC}  .cursorrules already exists (use --force to overwrite)"
        return
    fi

    local project_name
    project_name=$(basename "$dir")

    cat > "$config_file" << CREOF
# Cursor Rules - Agentic Engineering Framework

## Project: $project_name

## Core Rule
Nothing gets done without a task. Every commit must reference a task ID (T-XXX).

## Framework Commands
All operations go through the \`fw\` CLI:
- \`fw task create --name "..." --type build --owner human\`
- \`fw git commit -m "T-XXX: description"\`
- \`fw audit\` — Check compliance
- \`fw handover --commit\` — End-of-session handover

## Session Protocol
Start: \`fw context init\` → read handover → \`fw context focus T-XXX\`
End: session capture → \`fw handover --commit\`
CREOF
}
