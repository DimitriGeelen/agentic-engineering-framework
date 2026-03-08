#!/usr/bin/env bash
# Agentic Engineering Framework — Install Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash
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
SYMLINK_DIR="/usr/local/bin"

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
        git_ver=$(git --version | grep -oP '\d+\.\d+' | head -1)
        info "git ${git_ver}"
    fi

    # python3
    if ! command -v python3 &>/dev/null; then
        error "python3 not found — install Python 3.8+"
        ok=false
    else
        local py_ver
        py_ver=$(python3 --version 2>&1 | grep -oP '\d+\.\d+\.\d+')
        info "python3 ${py_ver}"
    fi

    # PyYAML
    if ! python3 -c "import yaml" 2>/dev/null; then
        warn "PyYAML not found — install with: pip install pyyaml"
        ok=false
    else
        info "PyYAML installed"
    fi

    if [[ "$ok" != "true" ]]; then
        fatal "Prerequisites not met. Fix the issues above and re-run."
    fi
}

# --- Install ---
do_install() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "Existing installation found — updating..."
        git -C "$INSTALL_DIR" fetch origin "$BRANCH" --quiet
        git -C "$INSTALL_DIR" checkout "$BRANCH" --quiet 2>/dev/null || true
        git -C "$INSTALL_DIR" pull --quiet
        info "Updated to latest"
    else
        info "Cloning framework to ${INSTALL_DIR}..."
        git clone --branch "$BRANCH" --single-branch --quiet "$REPO_URL" "$INSTALL_DIR"
        info "Cloned successfully"
    fi
}

# --- Symlink ---
link_fw() {
    local fw_path="$INSTALL_DIR/bin/fw"

    if [[ ! -x "$fw_path" ]]; then
        fatal "bin/fw not found in ${INSTALL_DIR} — clone may be corrupted"
    fi

    # Try /usr/local/bin first (needs sudo), fall back to ~/.local/bin
    if [[ -w "$SYMLINK_DIR" ]]; then
        ln -sf "$fw_path" "$SYMLINK_DIR/fw"
        info "Linked fw → ${SYMLINK_DIR}/fw"
    elif command -v sudo &>/dev/null; then
        info "Creating symlink in ${SYMLINK_DIR} (requires sudo)..."
        sudo ln -sf "$fw_path" "$SYMLINK_DIR/fw"
        info "Linked fw → ${SYMLINK_DIR}/fw"
    else
        # Fallback: ~/.local/bin
        local local_bin="$HOME/.local/bin"
        mkdir -p "$local_bin"
        ln -sf "$fw_path" "$local_bin/fw"
        info "Linked fw → ${local_bin}/fw"
        if [[ ":$PATH:" != *":${local_bin}:"* ]]; then
            warn "Add ${local_bin} to your PATH:"
            echo "  export PATH=\"${local_bin}:\$PATH\""
        fi
    fi
}

# --- Verify ---
verify() {
    if command -v fw &>/dev/null; then
        info "Running fw doctor..."
        fw doctor || true
    else
        warn "fw not in PATH yet — run: source ~/.bashrc (or open a new terminal)"
        info "Manual verify: ${INSTALL_DIR}/bin/fw doctor"
    fi
}

# --- Main ---
main() {
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
    echo "  Get started:"
    echo "    cd /path/to/your-project"
    echo "    git init"
    echo "    fw init"
    echo ""
    echo "  Then choose your path:"
    echo ""
    echo "    1. Think first — explore before building:"
    echo "       fw inception start \"Define goals and architecture\""
    echo ""
    echo "    2. Build now — fire off tasks immediately:"
    echo "       fw work-on \"Set up project\" --type build"
    echo ""
    echo "    3. Dashboard — see your project at a glance:"
    echo "       fw serve"
    echo ""
    echo "  Documentation: ${INSTALL_DIR}/FRAMEWORK.md"
    echo ""
}

main "$@"
