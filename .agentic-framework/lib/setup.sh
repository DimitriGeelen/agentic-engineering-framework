#!/bin/bash
# fw setup - Guided onboarding wizard for new projects
#
# A 6-step breadcrumb flow that wraps fw init with guided configuration.
# Each step is idempotent (sentinel-checked) and safe to re-run.
#
# Steps:
#   1. Project Identity    — name, description, owner
#   2. Provider Selection  — claude, cursor, generic
#   3. Tech Stack          — languages, test framework, conventions
#   4. Enforcement Level   — strict, standard, advisory
#   5. First Task          — optional initial task creation
#   6. Verification        — fw doctor + cheat sheet

do_setup() {
    local target_dir=""
    local non_interactive=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive) non_interactive=true; shift ;;
            -h|--help)
                echo -e "${BOLD}fw setup${NC} - Guided project onboarding"
                echo ""
                echo "Usage: fw setup [target-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  target-dir          Directory to set up (default: current directory)"
                echo ""
                echo "Options:"
                echo "  --non-interactive   Apply defaults without prompting"
                echo "  -h, --help          Show this help"
                echo ""
                echo "Steps:"
                echo "  1/6  Project Identity     — name, description, owner"
                echo "  2/6  Provider Selection   — claude, cursor, generic"
                echo "  3/6  Tech Stack           — languages, conventions"
                echo "  4/6  Enforcement Level    — strict, standard, advisory"
                echo "  5/6  First Task           — optional task creation"
                echo "  6/6  Verification         — fw doctor + cheat sheet"
                echo ""
                echo "Re-running on an existing project skips completed steps."
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

    # Create directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi

    # Resolve to absolute path
    target_dir="$(cd "$target_dir" 2>/dev/null && pwd)" || {
        echo -e "${RED}ERROR: Cannot access directory: $target_dir${NC}" >&2
        return 1
    }

    # Auto-detect non-interactive mode (no TTY)
    if [ ! -t 0 ] && [ "$non_interactive" != true ]; then
        non_interactive=true
    fi

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║       fw setup — Project Onboarding      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Directory: $target_dir"
    if [ "$non_interactive" = true ]; then
        echo -e "  Mode:      ${YELLOW}non-interactive (defaults applied)${NC}"
    fi
    echo ""

    # --- Step 1: Project Identity ---
    setup_step_identity "$target_dir"

    # --- Step 2: Provider Selection ---
    setup_step_provider "$target_dir"

    # --- Step 3: Tech Stack ---
    setup_step_techstack "$target_dir"

    # --- Step 4: Enforcement Level ---
    setup_step_enforcement "$target_dir"

    # --- Step 5: First Task ---
    setup_step_first_task "$target_dir"

    # --- Step 6: Verification ---
    setup_step_verify "$target_dir"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Setup Complete!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

# ─────────────────────────────────────────────
# Step 1: Project Identity
# Sentinel: .framework.yaml has project_name key
# ─────────────────────────────────────────────
setup_step_identity() {
    local dir="$1"
    local fw_yaml="$dir/.framework.yaml"

    echo -e "${BOLD}━━━ Step 1 of 6: Project Identity ━━━${NC}"
    echo ""

    # Sentinel check
    if [ -f "$fw_yaml" ] && grep -q "^project_name:" "$fw_yaml" 2>/dev/null; then
        local existing_name
        existing_name=$(grep "^project_name:" "$fw_yaml" | sed 's/project_name:[[:space:]]*//')
        echo -e "  ${CYAN}DONE${NC}  Project identity already set: $existing_name"
        echo ""
        return
    fi

    local project_name description owner
    project_name=$(basename "$dir")

    if [ "$non_interactive" = true ]; then
        description=""
        owner="$(whoami)"
    else
        echo "  Project name [$project_name]: "
        read -r input_name
        [ -n "$input_name" ] && project_name="$input_name"

        echo "  One-line description (optional): "
        read -r description

        echo "  Primary owner [$(whoami)]: "
        read -r owner
        [ -z "$owner" ] && owner="$(whoami)"
    fi

    # Initialize basic structure with fw init (generic first)
    if [ ! -d "$dir/.tasks" ]; then
        source "$FW_LIB_DIR/init.sh"
        # Run init in generic mode — provider config comes in step 2
        local force_flag=""
        [ -f "$fw_yaml" ] && force_flag="--force"
        do_init "$dir" --provider generic $force_flag 2>&1 | while IFS= read -r line; do
            echo "    $line"
        done
    fi

    # Update .framework.yaml with identity
    if [ -f "$fw_yaml" ]; then
        # Add/update fields
        local tmp_yaml
        tmp_yaml=$(mktemp)
        {
            grep -v "^project_name:\|^description:\|^owner:" "$fw_yaml"
            echo "project_name: $project_name"
            [ -n "$description" ] && echo "description: \"$description\""
            echo "owner: $owner"
        } > "$tmp_yaml"
        mv "$tmp_yaml" "$fw_yaml"
    fi

    echo -e "  ${GREEN}OK${NC}  Project identity: $project_name (owner: $owner)"
    echo ""
}

# ─────────────────────────────────────────────
# Step 2: Provider Selection
# Sentinel: CLAUDE.md or .cursorrules exists with non-placeholder content
# ─────────────────────────────────────────────
setup_step_provider() {
    local dir="$1"

    echo -e "${BOLD}━━━ Step 2 of 6: Provider Selection ━━━${NC}"
    echo ""

    # Sentinel check — provider was explicitly selected by setup (not just init default)
    if [ -f "$dir/.framework.yaml" ] && grep -q "^setup_provider_done: true" "$dir/.framework.yaml" 2>/dev/null; then
        local existing_provider
        existing_provider=$(grep "^provider:" "$dir/.framework.yaml" | sed 's/provider:[[:space:]]*//')
        echo -e "  ${CYAN}DONE${NC}  Provider already selected: $existing_provider"
        echo ""
        return
    fi

    local provider="claude"

    if [ "$non_interactive" != true ]; then
        echo "  Available providers:"
        echo "    1) claude    — CLAUDE.md + settings.json hooks"
        echo "    2) cursor    — .cursorrules"
        echo "    3) generic   — CLAUDE.md only (no hooks)"
        echo ""
        echo "  Select provider [1]: "
        read -r choice
        case "$choice" in
            2) provider="cursor" ;;
            3) provider="generic" ;;
            *) provider="claude" ;;
        esac
    fi

    # Generate provider config (force=true to overwrite generic CLAUDE.md from Step 1)
    source "$FW_LIB_DIR/init.sh"
    local force=true
    case "$provider" in
        claude)
            generate_claude_md "$dir"
            generate_claude_code_config "$dir"
            ;;
        cursor)
            generate_cursorrules "$dir"
            ;;
        generic)
            generate_claude_md "$dir"
            ;;
    esac

    # Update .framework.yaml with provider + mark step done
    if [ -f "$dir/.framework.yaml" ]; then
        if grep -q "^provider:" "$dir/.framework.yaml"; then
            _sed_i "s|^provider:.*|provider: $provider|" "$dir/.framework.yaml"
        else
            echo "provider: $provider" >> "$dir/.framework.yaml"
        fi
        # Sentinel: mark provider as explicitly selected by setup
        if ! grep -q "^setup_provider_done:" "$dir/.framework.yaml"; then
            echo "setup_provider_done: true" >> "$dir/.framework.yaml"
        fi
    fi

    echo -e "  ${GREEN}OK${NC}  Provider: $provider"
    echo ""
}

# ─────────────────────────────────────────────
# Step 3: Tech Stack and Conventions
# Sentinel: .framework.yaml has tech_stack key
# ─────────────────────────────────────────────
setup_step_techstack() {
    local dir="$1"
    local fw_yaml="$dir/.framework.yaml"

    echo -e "${BOLD}━━━ Step 3 of 6: Tech Stack and Conventions ━━━${NC}"
    echo ""

    # Sentinel check
    if [ -f "$fw_yaml" ] && grep -q "^tech_stack:" "$fw_yaml" 2>/dev/null; then
        echo -e "  ${CYAN}DONE${NC}  Tech stack already configured"
        echo ""
        return
    fi

    local languages="" test_framework="" code_style=""

    if [ "$non_interactive" = true ]; then
        # Non-interactive: skip tech stack configuration
        echo -e "  ${CYAN}SKIP${NC}  Tech stack (configure later in .framework.yaml)"
        echo ""
        # Write empty sentinel
        echo "tech_stack: []" >> "$fw_yaml"
        return
    fi

    echo "  Primary language(s) (comma-separated, e.g., python,javascript): "
    read -r languages

    if [ -n "$languages" ]; then
        echo "  Test framework (e.g., pytest, jest, go test): "
        read -r test_framework

        echo "  Code style notes (e.g., 'black formatter, 4-space indent'): "
        read -r code_style
    fi

    # Write to .framework.yaml
    if [ -n "$languages" ]; then
        cat >> "$fw_yaml" << TECHYAML
tech_stack:
  languages: [$languages]
  test_framework: "$test_framework"
  code_style: "$code_style"
TECHYAML
    else
        echo "tech_stack: []" >> "$fw_yaml"
    fi

    # Append to CLAUDE.md if it exists
    if [ -f "$dir/CLAUDE.md" ] && [ -n "$languages" ]; then
        local tech_section=""
        tech_section="## Tech Stack and Conventions"
        if grep -q "$tech_section" "$dir/CLAUDE.md"; then
            # Replace the placeholder section
            local tmp_md
            tmp_md=$(mktemp)
            awk -v langs="$languages" -v test="$test_framework" -v style="$code_style" '
                /^## Tech Stack and Conventions/ {
                    print $0
                    print ""
                    print "**Languages:** " langs
                    if (test != "") print "**Test Framework:** " test
                    if (style != "") print "**Code Style:** " style
                    skip = 1
                    next
                }
                skip && /^## / { skip = 0 }
                !skip { print }
            ' "$dir/CLAUDE.md" > "$tmp_md"
            mv "$tmp_md" "$dir/CLAUDE.md"
        fi
    fi

    echo -e "  ${GREEN}OK${NC}  Tech stack: $languages"
    echo ""
}

# ─────────────────────────────────────────────
# Step 4: Enforcement Level
# Sentinel: .framework.yaml has enforcement_level key
# ─────────────────────────────────────────────
setup_step_enforcement() {
    local dir="$1"
    local fw_yaml="$dir/.framework.yaml"

    echo -e "${BOLD}━━━ Step 4 of 6: Enforcement Level ━━━${NC}"
    echo ""

    # Sentinel check
    if [ -f "$fw_yaml" ] && grep -q "^enforcement_level:" "$fw_yaml" 2>/dev/null; then
        local existing_level
        existing_level=$(grep "^enforcement_level:" "$fw_yaml" | sed 's/enforcement_level:[[:space:]]*//')
        echo -e "  ${CYAN}DONE${NC}  Enforcement level: $existing_level"
        echo ""
        return
    fi

    local level="standard"

    if [ "$non_interactive" != true ]; then
        echo "  Enforcement levels:"
        echo "    1) strict    — Tier 0 + Tier 1 hooks (blocks without task + blocks destructive commands)"
        echo "    2) standard  — Tier 1 hooks only (blocks without task)"
        echo "    3) advisory  — No blocking hooks (logging only)"
        echo ""
        echo "  Select level [2]: "
        read -r choice
        case "$choice" in
            1) level="strict" ;;
            3) level="advisory" ;;
            *) level="standard" ;;
        esac
    fi

    echo "enforcement_level: $level" >> "$fw_yaml"

    # Install git hooks based on level
    if [ -d "$dir/.git" ] && [ "$level" != "advisory" ]; then
        PROJECT_ROOT="$dir" "$FRAMEWORK_ROOT/agents/git/git.sh" install-hooks 2>/dev/null || true
    fi

    echo -e "  ${GREEN}OK${NC}  Enforcement: $level"
    echo ""
}

# ─────────────────────────────────────────────
# Step 5: First Task (optional)
# Sentinel: .context/working/session.yaml exists
# ─────────────────────────────────────────────
setup_step_first_task() {
    local dir="$1"

    echo -e "${BOLD}━━━ Step 5 of 6: First Task (optional) ━━━${NC}"
    echo ""

    # Sentinel check
    if [ -f "$dir/.context/working/session.yaml" ]; then
        echo -e "  ${CYAN}DONE${NC}  Session already initialized"
        echo ""
        return
    fi

    if [ "$non_interactive" = true ]; then
        echo -e "  ${CYAN}SKIP${NC}  First task (non-interactive mode)"
        echo ""
        return
    fi

    echo "  Create an initial task? (Enter task name, or press Enter to skip): "
    read -r task_name

    if [ -n "$task_name" ]; then
        echo "  Task type [build]: "
        read -r task_type
        [ -z "$task_type" ] && task_type="build"

        # Initialize context
        PROJECT_ROOT="$dir" "$FRAMEWORK_ROOT/agents/context/context.sh" init 2>&1 | while IFS= read -r line; do
            echo "    $line"
        done

        # Create task
        PROJECT_ROOT="$dir" "$FRAMEWORK_ROOT/agents/task-create/create-task.sh" \
            --name "$task_name" --type "$task_type" --owner human --start 2>&1 | while IFS= read -r line; do
            echo "    $line"
        done

        echo -e "  ${GREEN}OK${NC}  Task created: $task_name"
    else
        echo -e "  ${CYAN}SKIP${NC}  No initial task"
    fi
    echo ""
}

# ─────────────────────────────────────────────
# Step 6: Verification
# Sentinel: always runs (idempotent)
# ─────────────────────────────────────────────
setup_step_verify() {
    local dir="$1"

    echo -e "${BOLD}━━━ Step 6 of 6: Verification ━━━${NC}"
    echo ""

    # Check git identity (required for commits)
    local git_name git_email
    git_name=$(cd "$dir" && git config user.name 2>/dev/null || git config --global user.name 2>/dev/null || true)
    git_email=$(cd "$dir" && git config user.email 2>/dev/null || git config --global user.email 2>/dev/null || true)
    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        echo -e "  ${YELLOW}WARN${NC}  Git identity not configured (commits will fail)"
        echo "        Run: git config --global user.name \"Your Name\""
        echo "        Run: git config --global user.email \"you@example.com\""
        echo ""
    else
        echo -e "  ${GREEN}OK${NC}  Git identity: $git_name <$git_email>"
    fi

    # Run fw doctor
    echo -e "  ${YELLOW}Running fw doctor...${NC}"
    PROJECT_ROOT="$dir" "$FRAMEWORK_ROOT/bin/fw" doctor 2>&1 | while IFS= read -r line; do
        echo "    $line"
    done
    local doctor_exit=${PIPESTATUS[0]}

    echo ""

    if [ "$doctor_exit" -eq 0 ]; then
        echo -e "  ${GREEN}OK${NC}  Health check passed"
    else
        echo -e "  ${YELLOW}WARN${NC}  Some health checks failed (see above)"
    fi

    # Print cheat sheet
    echo ""
    echo -e "${BOLD}━━━ Quick Start Cheat Sheet ━━━${NC}"
    echo ""
    echo "  cd $dir"
    echo ""
    echo "  # Start a session"
    echo "  fw context init"
    echo "  fw context focus T-XXX"
    echo ""
    echo "  # Create a task"
    echo "  fw task create --name \"...\" --type build --owner human --start"
    echo ""
    echo "  # Work + commit"
    echo "  fw git commit -m \"T-XXX: description\""
    echo ""
    echo "  # End session"
    echo "  fw handover --commit"
    echo ""
    echo "  # Check health"
    echo "  fw doctor"
    echo "  fw audit"
    echo ""
    echo "  # Update framework"
    echo "  cd $FRAMEWORK_ROOT && git pull"
    echo ""
    echo -e "  Framework source: ${CYAN}https://onedev.docker.ring20.geelenandcompany.com/agentic-engineering-framework${NC}"
    echo ""
}
