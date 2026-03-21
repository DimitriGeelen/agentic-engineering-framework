#!/usr/bin/env bash
# Agentic Engineering Framework — Install Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
#   bash install.sh --local /path/to/repo    # install/update from local clone
#
# Configuration (environment variables):
#   INSTALL_DIR   — Where to install (default: ~/.agentic-framework)
#   REPO_URL      — Git clone URL (default: GitHub)
#   BRANCH        — Branch to clone (default: master)

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="${INSTALL_DIR:-$HOME/.agentic-framework}"
REPO_URL="${REPO_URL:-https://github.com/DimitriGeelen/agentic-engineering-framework.git}"
BRANCH="${BRANCH:-master}"
MODIFY_PATH="${MODIFY_PATH:-false}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[x]${NC} $*" >&2; }
fatal() { error "$@"; exit 1; }

# --- Argument Parsing ---
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                if [[ -z "${2:-}" ]]; then
                    fatal "--local requires a path argument"
                fi
                LOCAL_REPO="$2"
                if [[ ! -d "$LOCAL_REPO/.git" ]]; then
                    fatal "--local path is not a git repository: $LOCAL_REPO"
                fi
                shift 2
                ;;
            --branch)
                if [[ -z "${2:-}" ]]; then
                    fatal "--branch requires a value"
                fi
                BRANCH="$2"
                shift 2
                ;;
            --install-dir)
                if [[ -z "${2:-}" ]]; then
                    fatal "--install-dir requires a path"
                fi
                INSTALL_DIR="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: install.sh [options]"
                echo ""
                echo "Options:"
                echo "  --local <path>       Install/update from a local git repo"
                echo "  --branch <name>      Branch to use (default: master)"
                echo "  --install-dir <path> Install location (default: ~/.agentic-framework)"
                echo "  -h, --help           Show this help"
                exit 0
                ;;
            *)
                fatal "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done
}

# --- Prerequisite Checks ---
check_prereqs() {
    local ok=true

    # bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] || { [[ "${BASH_VERSINFO[0]}" -eq 4 ]] && [[ "${BASH_VERSINFO[1]}" -lt 4 ]]; }; then
        error "bash 4.4+ required (found ${BASH_VERSION})"
        ok=false
    else
        info "bash ${BASH_VERSION}"
    fi

    # git
    if ! command -v git &>/dev/null; then
        error "git not found — install git 2.20+"
        ok=false
    else
        local git_ver
        git_ver=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        info "git ${git_ver}"
    fi

    # python3
    if ! command -v python3 &>/dev/null; then
        error "python3 not found — install Python 3.8+"
        ok=false
    else
        local py_ver
        py_ver=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        info "python3 ${py_ver}"
    fi

    if [[ "$ok" != "true" ]]; then
        fatal "Prerequisites not met. Fix the issues above and re-run."
    fi
}

# --- Install ---
do_install() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "Existing installation found — updating..."

        # Ensure fileMode is off (macOS HFS+/APFS reports permission diffs as changes)
        git -C "$INSTALL_DIR" config core.fileMode false

        local old_hash
        old_hash=$(git -C "$INSTALL_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

        if [[ -n "$LOCAL_REPO" ]]; then
            # Update from local repo — add as temporary remote
            local remote_name="local-install"
            git -C "$INSTALL_DIR" remote remove "$remote_name" 2>/dev/null || true
            git -C "$INSTALL_DIR" remote add "$remote_name" "$LOCAL_REPO"
            git -C "$INSTALL_DIR" fetch "$remote_name" "$BRANCH" --quiet
            git -C "$INSTALL_DIR" checkout "$BRANCH" --quiet 2>/dev/null || true
            if ! git -C "$INSTALL_DIR" diff --quiet 2>/dev/null; then
                warn "Local modifications in $INSTALL_DIR will be overwritten"
            fi
            git -C "$INSTALL_DIR" reset --hard "${remote_name}/$BRANCH" --quiet
            git -C "$INSTALL_DIR" remote remove "$remote_name" 2>/dev/null || true
        else
            # Update from origin
            git -C "$INSTALL_DIR" fetch origin "$BRANCH" --quiet
            git -C "$INSTALL_DIR" checkout "$BRANCH" --quiet 2>/dev/null || true
            if ! git -C "$INSTALL_DIR" diff --quiet 2>/dev/null; then
                warn "Local modifications in $INSTALL_DIR will be overwritten"
            fi
            git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH" --quiet
        fi

        local new_hash
        new_hash=$(git -C "$INSTALL_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")

        if [[ "$old_hash" == "$new_hash" ]]; then
            info "Already up to date (${new_hash})"
        else
            info "Updated ${old_hash} → ${new_hash}"
        fi
    else
        if [[ -n "$LOCAL_REPO" ]]; then
            info "Cloning framework from local repo to ${INSTALL_DIR}..."
            git clone --branch "$BRANCH" --single-branch --quiet "$LOCAL_REPO" "$INSTALL_DIR"
        else
            info "Cloning framework to ${INSTALL_DIR}..."
            git clone --branch "$BRANCH" --single-branch --quiet "$REPO_URL" "$INSTALL_DIR"
        fi
        # Disable fileMode for macOS compatibility (HFS+/APFS permission diffs)
        git -C "$INSTALL_DIR" config core.fileMode false
        info "Cloned successfully"
    fi
}

# --- Symlink ---
link_fw() {
    local fw_path="$INSTALL_DIR/bin/fw"
    local local_bin="$HOME/.local/bin"

    if [[ ! -x "$fw_path" ]]; then
        fatal "bin/fw not found in ${INSTALL_DIR} — clone may be corrupted"
    fi

    # Always use ~/.local/bin (no sudo required)
    mkdir -p "$local_bin"
    ln -sf "$fw_path" "$local_bin/fw"
    ln -sf "$INSTALL_DIR/bin/claude-fw" "$local_bin/claude-fw"
    info "Linked fw → ${local_bin}/fw"
    info "Linked claude-fw → ${local_bin}/claude-fw"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":${local_bin}:"* ]]; then
        echo ""
        warn "~/.local/bin is not in your PATH"
        echo ""

        if [[ "$MODIFY_PATH" == "true" ]]; then
            # CI/automation mode: modify shell config idempotently
            local shell_rc=""
            if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
                shell_rc="$HOME/.zshrc"
            else
                shell_rc="$HOME/.bashrc"
            fi

            local path_line='export PATH="$HOME/.local/bin:$PATH"'
            if ! grep -qF "$path_line" "$shell_rc" 2>/dev/null; then
                echo "" >> "$shell_rc"
                echo "# Added by Agentic Engineering Framework installer" >> "$shell_rc"
                echo "$path_line" >> "$shell_rc"
                info "Added PATH to $shell_rc"
            else
                info "PATH already configured in $shell_rc"
            fi
        else
            # Interactive mode: print instructions
            echo "  Add to your shell config (~/.bashrc or ~/.zshrc):"
            echo ""
            echo '    export PATH="$HOME/.local/bin:$PATH"'
            echo ""
            echo "  Or run with --modify-path to auto-configure:"
            echo ""
            echo "    curl -fsSL ... | MODIFY_PATH=true bash"
            echo ""
        fi
    fi
}

# --- Verify ---
verify() {
    local fw_path="$INSTALL_DIR/bin/fw"
    local ok=true

    echo ""
    info "Post-install verification..."
    echo ""

    # Step 1: Check fw binary exists
    if [[ -x "$fw_path" ]]; then
        info "Step 1/3: fw binary exists ✓"
    else
        error "Step 1/3: fw binary not found"
        echo "  Fix: git clone $REPO_URL $INSTALL_DIR"
        ok=false
    fi

    # Step 2: Check fw version works
    if "$fw_path" version &>/dev/null; then
        local ver
        ver=$("$fw_path" version 2>&1 | head -1)
        info "Step 2/3: fw version works ✓ ($ver)"
    else
        error "Step 2/3: fw version failed"
        echo "  Fix: Check $fw_path is not corrupted"
        ok=false
    fi

    # Step 3: Check fw doctor passes
    if "$fw_path" doctor &>/dev/null; then
        info "Step 3/3: fw doctor passes ✓"
    else
        warn "Step 3/3: fw doctor has warnings (non-fatal)"
        echo "  Run: $fw_path doctor"
    fi

    echo ""
    if [[ "$ok" == "true" ]]; then
        info "All verification steps passed"
    else
        error "Some verification steps failed — see above"
    fi
}

# --- Main ---
main() {
    parse_args "$@"

    echo ""
    echo -e "${BOLD}Agentic Engineering Framework — Installer${NC}"
    echo ""

    info "Checking prerequisites..."
    check_prereqs
    echo ""

    do_install
    echo ""

    link_fw
    echo ""

    verify
    echo ""

    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo "  Get started (in current dir, or specify a path):"
    echo "    fw init                  # current directory"
    echo "    fw init /path/to/project # specific directory"
    echo ""
    echo "  Then choose your path:"
    echo ""
    echo "    1. Think first — explore before building:"
    echo "       fw inception start \"Define goals and architecture\""
    echo ""
    echo "    2. Build now — fire off tasks immediately:"
    echo "       fw work-on \"Set up project\" --type build"
    echo ""
    echo "    3. Existing project — map your files so the framework knows what depends on what:"
    echo "       fw fabric register src/main.ts   # register key files"
    echo "       fw fabric drift                   # find unregistered files"
    echo ""
    echo "    4. Dashboard — live view of tasks, audit, and metrics:"
    echo "       fw serve                          # http://localhost:3000"
    echo "       fw serve --port 5000              # custom port"
    echo ""
    echo "  Documentation: ${INSTALL_DIR}/FRAMEWORK.md"
    echo ""
}

main "$@"
