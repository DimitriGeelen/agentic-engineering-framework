#!/bin/bash
# fw preflight — Validate OS dependencies before init
#
# Sovereignty principle: detect silently, inform clearly, act only with consent.
# Same pattern as Tier 0: detect → inform → ask → execute with approval.
#
# Usage:
#   fw preflight              # Interactive: check + offer to install
#   fw preflight --check-only # Non-interactive: check only, exit code 0/1
#
# Exit codes:
#   0 = all required deps present
#   1 = required dep(s) missing

# Colors (inherited from bin/fw, but define fallbacks)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
CYAN="${CYAN:-\033[0;36m}"
BOLD="${BOLD:-\033[1m}"
NC="${NC:-\033[0m}"

CHECK_ONLY=false
QUIET=false
for arg in "$@"; do
    case "$arg" in
        --check-only|--ci) CHECK_ONLY=true ;;
        --quiet) QUIET=true; CHECK_ONLY=true ;;
    esac
done

# Detect if running non-interactive (piped, CI)
if [ ! -t 0 ] || [ ! -t 1 ]; then
    CHECK_ONLY=true
fi

# --- Detect package manager ---
detect_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

PKG_MGR=$(detect_pkg_manager)

# --- Results tracking ---
REQUIRED_MISSING=()
RECOMMENDED_MISSING=()
REQUIRED_INSTALL_CMDS=()
RECOMMENDED_INSTALL_CMDS=()

# --- Check functions ---

check_bash() {
    # Check the bash available in PATH, not the running shell
    # (macOS ships /bin/bash 3.2 but Homebrew installs bash 5+ elsewhere)
    local bash_path ver major
    bash_path=$(command -v bash 2>/dev/null || echo "/bin/bash")
    ver=$("$bash_path" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    major="${ver%%.*}"
    if [ -n "$major" ] && [ "$major" -ge 4 ] 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC}  bash $ver (>= 4.0 required)"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}  bash ${ver:-unknown} (>= 4.0 required)"
        echo -e "       ${CYAN}Why:${NC} Framework uses associative arrays and other bash 4+ features"
        REQUIRED_MISSING+=("bash >= 4.0")
        case "$PKG_MGR" in
            apt) REQUIRED_INSTALL_CMDS+=("sudo apt-get install -y bash") ;;
            brew) REQUIRED_INSTALL_CMDS+=("brew install bash") ;;
            *) REQUIRED_INSTALL_CMDS+=("# Install bash >= 4.0 via your package manager") ;;
        esac
        return 1
    fi
}

check_git() {
    if ! command -v git >/dev/null 2>&1; then
        echo -e "  ${RED}FAIL${NC}  git not found (>= 2.0 required)"
        echo -e "       ${CYAN}Why:${NC} Task traceability, hooks, and version control"
        REQUIRED_MISSING+=("git")
        case "$PKG_MGR" in
            apt) REQUIRED_INSTALL_CMDS+=("sudo apt-get install -y git") ;;
            brew) REQUIRED_INSTALL_CMDS+=("brew install git") ;;
            *) REQUIRED_INSTALL_CMDS+=("# Install git >= 2.0 via your package manager") ;;
        esac
        return 1
    fi
    local ver
    ver=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major="${ver%%.*}"
    if [ "$major" -ge 2 ]; then
        echo -e "  ${GREEN}OK${NC}  git $ver (>= 2.0 required)"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}  git $ver (>= 2.0 required)"
        echo -e "       ${CYAN}Why:${NC} Modern hook support and worktree features"
        REQUIRED_MISSING+=("git >= 2.0")
        return 1
    fi
}

check_python3() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "  ${RED}FAIL${NC}  python3 not found (>= 3.8 required)"
        echo -e "       ${CYAN}Why:${NC} Audit agent, metrics, watchtower, YAML processing"
        REQUIRED_MISSING+=("python3")
        case "$PKG_MGR" in
            apt) REQUIRED_INSTALL_CMDS+=("sudo apt-get install -y python3") ;;
            brew) REQUIRED_INSTALL_CMDS+=("brew install python3") ;;
            *) REQUIRED_INSTALL_CMDS+=("# Install python3 >= 3.8 via your package manager") ;;
        esac
        return 1
    fi
    local ver
    ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    local minor="${ver#*.}"
    if [ "$minor" -ge 8 ] 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC}  python3 $ver (>= 3.8 required)"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}  python3 $ver (>= 3.8 required)"
        echo -e "       ${CYAN}Why:${NC} Uses f-strings, walrus operator, and typing features"
        REQUIRED_MISSING+=("python3 >= 3.8")
        return 1
    fi
}

check_pyyaml() {
    if python3 -c "import yaml" 2>/dev/null; then
        echo -e "  ${GREEN}OK${NC}  PyYAML installed"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}  PyYAML not installed"
        echo -e "       ${CYAN}Why:${NC} All context, task, and audit files use YAML format"
        REQUIRED_MISSING+=("PyYAML")
        REQUIRED_INSTALL_CMDS+=("pip3 install pyyaml")
        return 1
    fi
}

check_git_identity() {
    local name email
    name=$(git config user.name 2>/dev/null || true)
    email=$(git config user.email 2>/dev/null || true)
    if [ -n "$name" ] && [ -n "$email" ]; then
        echo -e "  ${GREEN}OK${NC}  git identity: $name <$email>"
        return 0
    else
        echo -e "  ${YELLOW}WARN${NC}  git identity not configured"
        echo -e "       ${CYAN}Why:${NC} Commits require author identity"
        RECOMMENDED_MISSING+=("git identity")
        RECOMMENDED_INSTALL_CMDS+=("git config --global user.name 'Your Name' && git config --global user.email 'you@example.com'")
        return 1
    fi
}

check_shellcheck() {
    if command -v shellcheck >/dev/null 2>&1; then
        echo -e "  ${GREEN}OK${NC}  shellcheck installed (linting)"
        return 0
    else
        echo -e "  ${YELLOW}WARN${NC}  shellcheck not installed"
        echo -e "       ${CYAN}Why:${NC} Used by fw doctor for shell script linting"
        RECOMMENDED_MISSING+=("shellcheck")
        case "$PKG_MGR" in
            apt) RECOMMENDED_INSTALL_CMDS+=("sudo apt-get install -y shellcheck") ;;
            brew) RECOMMENDED_INSTALL_CMDS+=("brew install shellcheck") ;;
            *) RECOMMENDED_INSTALL_CMDS+=("# Install shellcheck via your package manager") ;;
        esac
        return 1
    fi
}

check_write_perms() {
    local target="${PROJECT_ROOT:-.}"
    if [ -w "$target" ]; then
        echo -e "  ${GREEN}OK${NC}  write permissions on $target"
        return 0
    else
        echo -e "  ${RED}FAIL${NC}  no write permissions on $target"
        echo -e "       ${CYAN}Why:${NC} Framework creates .tasks/, .context/, .claude/ directories"
        REQUIRED_MISSING+=("write permissions")
        return 1
    fi
}

# --- Main ---

do_preflight() {
    if [ "$QUIET" = true ]; then
        # Silent mode: only check required deps, return 0/1
        check_bash >/dev/null 2>&1 || true
        check_git >/dev/null 2>&1 || true
        check_python3 >/dev/null 2>&1 || true
        check_pyyaml >/dev/null 2>&1 || true
        check_write_perms >/dev/null 2>&1 || true
        [ ${#REQUIRED_MISSING[@]} -eq 0 ] && return 0
        # On failure, show what's missing
        echo -e "  ${RED}✗${NC}  Missing: ${REQUIRED_MISSING[*]}"
        return 1
    fi

    echo -e "${BOLD}fw preflight${NC} — Dependency Check"
    echo ""

    # Required checks
    echo -e "${BOLD}Required:${NC}"
    check_bash || true
    check_git || true
    check_python3 || true
    check_pyyaml || true
    check_write_perms || true
    echo ""

    # Recommended checks
    echo -e "${BOLD}Recommended:${NC}"
    check_git_identity || true
    check_shellcheck || true
    echo ""

    # Summary
    local req_count=${#REQUIRED_MISSING[@]}
    local rec_count=${#RECOMMENDED_MISSING[@]}

    if [ "$req_count" -eq 0 ] && [ "$rec_count" -eq 0 ]; then
        echo -e "${GREEN}All checks passed.${NC} Ready for fw init."
        return 0
    fi

    if [ "$req_count" -gt 0 ]; then
        echo -e "${RED}$req_count required dependency(s) missing.${NC}"
    fi
    if [ "$rec_count" -gt 0 ]; then
        echo -e "${YELLOW}$rec_count recommended dependency(s) missing.${NC}"
    fi
    echo ""

    # Non-interactive: print commands and exit
    if [ "$CHECK_ONLY" = true ]; then
        if [ ${#REQUIRED_INSTALL_CMDS[@]} -gt 0 ]; then
            echo -e "${BOLD}Install required:${NC}"
            for cmd in "${REQUIRED_INSTALL_CMDS[@]}"; do
                echo "  $cmd"
            done
        fi
        if [ ${#RECOMMENDED_INSTALL_CMDS[@]} -gt 0 ]; then
            echo -e "${BOLD}Install recommended:${NC}"
            for cmd in "${RECOMMENDED_INSTALL_CMDS[@]}"; do
                echo "  $cmd"
            done
        fi
        [ "$req_count" -gt 0 ] && return 1
        return 0
    fi

    # Interactive: offer to install with consent
    if [ ${#REQUIRED_INSTALL_CMDS[@]} -gt 0 ]; then
        echo -e "${BOLD}Required dependencies can be installed:${NC}"
        for cmd in "${REQUIRED_INSTALL_CMDS[@]}"; do
            echo -e "  ${CYAN}$cmd${NC}"
        done
        echo ""
        read -rp "Install required dependencies? [Y/n] " reply
        reply="${reply:-Y}"
        if [[ "$reply" =~ ^[Yy] ]]; then
            for cmd in "${REQUIRED_INSTALL_CMDS[@]}"; do
                echo -e "Running: ${CYAN}$cmd${NC}"
                eval "$cmd"
            done
            echo ""
        else
            echo "Skipped. You can install manually with the commands above."
            echo ""
        fi
    fi

    if [ ${#RECOMMENDED_INSTALL_CMDS[@]} -gt 0 ]; then
        echo -e "${BOLD}Recommended dependencies:${NC}"
        for cmd in "${RECOMMENDED_INSTALL_CMDS[@]}"; do
            echo -e "  ${CYAN}$cmd${NC}"
        done
        echo ""
        read -rp "Install recommended dependencies? [y/N] " reply
        reply="${reply:-N}"
        if [[ "$reply" =~ ^[Yy] ]]; then
            for cmd in "${RECOMMENDED_INSTALL_CMDS[@]}"; do
                echo -e "Running: ${CYAN}$cmd${NC}"
                eval "$cmd"
            done
            echo ""
        else
            echo "Skipped."
            echo ""
        fi
    fi

    # Re-check required after install attempt
    if [ "$req_count" -eq 0 ]; then
        echo -e "${GREEN}Required dependencies satisfied.${NC}"
        return 0
    fi

    local still_missing=0
    for dep in "${REQUIRED_MISSING[@]}"; do
        case "$dep" in
            "python3"*) python3 --version >/dev/null 2>&1 || still_missing=$((still_missing + 1)) ;;
            "PyYAML") python3 -c "import yaml" 2>/dev/null || still_missing=$((still_missing + 1)) ;;
            "git"*) git --version >/dev/null 2>&1 || still_missing=$((still_missing + 1)) ;;
            "bash"*) local bm; bm=$(bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1); [ "${bm:-0}" -ge 4 ] 2>/dev/null || still_missing=$((still_missing + 1)) ;;
            "write permissions") [ -w "${PROJECT_ROOT:-.}" ] || still_missing=$((still_missing + 1)) ;;
        esac
    done

    if [ "$still_missing" -gt 0 ]; then
        echo -e "${RED}$still_missing required dependency(s) still missing. Cannot proceed with fw init.${NC}"
        return 1
    fi

    echo -e "${GREEN}Required dependencies satisfied.${NC}"
    return 0
}

# Allow sourcing or direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    do_preflight "$@"
fi
