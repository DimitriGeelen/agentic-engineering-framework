#!/usr/bin/env bash
# Agentic Engineering Framework — Install Script
#
# T-2800/T-2809 (D-377 total isolation): this installer does NOT write a
# framework into $HOME. It fetches framework bytes to a TEMPORARY path,
# vendors them into a named target project, installs the ~100-line router
# (bin/fw-router) plus claude-fw onto PATH, then deletes the temporary
# fetch — the only things that persist outside the project are those two
# small files. "Install" and "init" are one command per project (T-2800
# IW-3): omit the target and you get PATH tooling only (no project is
# created, nothing is written outside $HOME/.local/bin — this is also the
# "refresh the router" path bin/fw's doctor check points at).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash -s -- /path/to/project
#   bash install.sh /path/to/project             # create/init a project (fetch+vendor+init, one step)
#   bash install.sh                              # PATH tooling only — no project created
#   bash install.sh --local /path/to/repo /path/to/project   # fetch from a local clone instead of GitHub
#
# Configuration (environment variables):
#   REPO_URL      — Git clone URL (default: GitHub)
#   BRANCH        — Branch to clone (default: master)
#   INSTALL_DIR   — Advanced: override the temporary fetch location (default: mktemp -d).
#                   Not a persistent install path — it is deleted at the end of the run.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="${INSTALL_DIR:-}"
TARGET_DIR=""
PROVIDER="${PROVIDER:-generic}"
REPO_URL="${REPO_URL:-https://github.com/DimitriGeelen/agentic-engineering-framework.git}"
BRANCH="${BRANCH:-master}"
MODIFY_PATH="${MODIFY_PATH:-false}"
LOCAL_REPO=""
NO_SCAN="${NO_SCAN:-false}"
FW_CONSUMER_SCAN_DIRS="${FW_CONSUMER_SCAN_DIRS:-/opt}"

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
            --provider)
                if [[ -z "${2:-}" ]]; then
                    fatal "--provider requires a value (claude, cursor, generic)"
                fi
                PROVIDER="$2"
                shift 2
                ;;
            --install-dir)
                if [[ -z "${2:-}" ]]; then
                    fatal "--install-dir requires a path"
                fi
                INSTALL_DIR="$2"
                shift 2
                ;;
            --no-scan)
                NO_SCAN=true
                shift
                ;;
            -h|--help)
                echo "Usage: install.sh [target-dir] [options]"
                echo ""
                echo "Arguments:"
                echo "  target-dir            Project directory to create/initialise (fetch+vendor+init,"
                echo "                        one step). Omit to install/refresh PATH tooling only — no"
                echo "                        project is created and nothing is written to \$HOME beyond"
                echo "                        \$HOME/.local/bin/{fw,claude-fw}."
                echo ""
                echo "Options:"
                echo "  --local <path>        Fetch from a local git repo instead of GitHub"
                echo "  --branch <name>       Branch to use (default: master)"
                echo "  --provider <name>     fw init provider: claude, cursor, generic (default: generic)"
                echo "  --install-dir <path>  Advanced: override the temporary fetch location"
                echo "  --no-scan             Skip vendored-consumer scan (CI/automation)"
                echo "  -h, --help            Show this help"
                exit 0
                ;;
            -*)
                fatal "Unknown option: $1 (use --help for usage)"
                ;;
            *)
                if [[ -n "$TARGET_DIR" ]]; then
                    fatal "Unexpected extra argument: '$1' (target directory already set to '$TARGET_DIR')"
                fi
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done

    if [[ -n "$TARGET_DIR" ]]; then
        case "$TARGET_DIR" in
            /*) : ;;
            *) TARGET_DIR="$PWD/$TARGET_DIR" ;;
        esac
    fi
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
        git_ver=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)
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

    # Node.js (optional — recommended for TypeScript hooks, Python fallback otherwise)
    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version 2>&1 | sed 's/^v//')
        info "node ${node_ver} (recommended for TS hooks)"
    else
        warn "Node.js not found (optional — Python fallback for TS hooks)"
    fi

    if [[ "$ok" != "true" ]]; then
        fatal "Prerequisites not met. Fix the issues above and re-run."
    fi
}

# --- Fetch (T-2800/T-2809: bytes go to a TEMPORARY path, never $HOME) ---
#
# Previously this cloned into a permanent $HOME/.agentic-framework and, on a
# second run, updated it in place (fetch/checkout/reset --hard). Under D-377
# total isolation there is nothing to update in place: INSTALL_DIR is a fresh
# mktemp every run, deleted by cleanup_fetch() once the router/claude-fw are
# on PATH and (if requested) the target project is vendored. A shallow,
# single-branch clone is enough — do_vendor only needs a working tree, and
# this fetch dir does not outlive the run.
do_install() {
    if [[ -z "$INSTALL_DIR" ]]; then
        INSTALL_DIR="$(mktemp -d -t agentic-fw-fetch-XXXXXX)"
    fi

    if [[ -n "$LOCAL_REPO" ]]; then
        info "Fetching framework from local repo (temporary path, not \$HOME)..."
        git clone --branch "$BRANCH" --single-branch --depth 1 --quiet "$LOCAL_REPO" "$INSTALL_DIR"
    else
        info "Fetching framework from ${REPO_URL} (temporary path, not \$HOME)..."
        git clone --branch "$BRANCH" --single-branch --depth 1 --quiet "$REPO_URL" "$INSTALL_DIR"
    fi
    # Disable fileMode for macOS compatibility (HFS+/APFS permission diffs)
    git -C "$INSTALL_DIR" config core.fileMode false

    local hash
    hash=$(git -C "$INSTALL_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    info "Fetched ${hash} → ${INSTALL_DIR} (temporary)"
}

# --- Cleanup (T-2809) — the fetch dir never persists past this run ---
cleanup_fetch() {
    if [[ -n "${INSTALL_DIR:-}" ]] && [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi
}

# --- T-1346-B3: Vendored Consumer Scan ---
# Enumerate vendored consumer projects so the user can see which existing
# installs may interact with this install. T-1356 (B1) flipped resolve_framework
# rule order so vendored beats global, but visibility still matters: a user
# installing the global shim should know which projects already have their
# own copy. Suppress with --no-scan for CI.
scan_vendored_consumers() {
    if [[ "$NO_SCAN" == "true" ]]; then
        info "Vendored-consumer scan: skipped (--no-scan)"
        return 0
    fi

    echo ""
    echo -e "${BOLD}Vendored framework copies detected:${NC}"

    local found=0
    local IFS=':'
    for dir in $FW_CONSUMER_SCAN_DIRS; do
        unset IFS
        [ -d "$dir" ] || continue
        # Look one level deep for .agentic-framework/FRAMEWORK.md
        for proj in "$dir"/*/; do
            [ -d "$proj" ] || continue
            if [ -f "$proj/.agentic-framework/FRAMEWORK.md" ]; then
                local pin="?"
                if [ -f "$proj/.agentic-framework/VERSION" ]; then
                    pin="$(cat "$proj/.agentic-framework/VERSION" 2>/dev/null || echo "?")"
                fi
                echo "  - ${proj%/} (v$pin)"
                found=$((found + 1))
            fi
        done
        IFS=':'
    done
    unset IFS

    if [ "$found" -eq 0 ]; then
        echo "  (none)"
    else
        echo ""
        info "$found vendored consumer project(s) found — they use their own framework copy (not affected by this install)"
    fi
    echo ""
}

# --- Install claude-fw onto PATH by COPY (T-2807) ---
#
# It used to be `ln -sf "$INSTALL_DIR/bin/claude-fw"`, with the comment "claude-fw
# still symlinks (it's a wrapper, not project-specific)". That was true while
# $INSTALL_DIR was permanent, and it stops being true under T-2800, which makes the
# fetched framework a temporary directory. A symlink into it dangles the moment it
# is cleaned up — and what dangles is the T-179 auto-restart wrapper, so the failure
# is a session that silently never recovers at budget-critical rather than an error
# anyone sees. Copy now, before the thing it points at becomes temporary.
#
# The rm -f is the T-1278/T-2793 guard, not defensive noise: if $local_bin/claude-fw
# is TODAY a symlink into the global install, a plain `cp` follows it and overwrites
# the global's own bin/claude-fw. That is exactly how the router bug happened — the
# install path is the one that most often meets the symlink it exists to replace.
#
# Trade-off accepted: a copy goes stale where a symlink self-updated. That is what
# the T-2501 drift check in `fw doctor` is for, and this change is what makes it
# load-bearing rather than cosmetic.
install_claude_fw() {
    local src="$1" local_bin="$2"
    [[ -f "$src" ]] || return 0
    rm -f "$local_bin/claude-fw"
    cp "$src" "$local_bin/claude-fw"
    chmod +x "$local_bin/claude-fw"
    info "Installed claude-fw → ${local_bin}/claude-fw (copy — survives removal of ${INSTALL_DIR})"
}

# --- Install the router (T-664 fw-shim → T-2793 fw-router: project-detecting fw,
# --- replaces the global symlink) ---
link_fw() {
    # T-2793: bin/fw-router supersedes bin/fw-shim. Same walk-up, plus an
    # ANNOUNCED global fallback so `fw init` still works in a bare directory —
    # the gap that made the old shim unsafe to install unconditionally.
    local shim_src="$INSTALL_DIR/bin/fw-router"
    [[ -x "$shim_src" ]] || shim_src="$INSTALL_DIR/bin/fw-shim"
    local local_bin="$HOME/.local/bin"

    if [[ ! -x "$shim_src" ]]; then
        # T-2793 — THIS BRANCH WAS THE BUG, not a benign legacy path.
        # bin/fw-shim was committed mode 100644, so `! -x` was ALWAYS true on a
        # fresh clone and every install silently symlinked ~/.local/bin/fw at the
        # global CLI. Projects then ran the global CLI against their own vendored
        # libs — the split brain T-2793 exists to end. The message below even
        # said so accurately ("legacy — upgrade for project-local routing") and
        # read as information rather than as the failure it was.
        # Guarded by tests/unit/bin_executable_bits.bats.
        #
        # Fallback for older installs that genuinely predate the router
        local fw_path="$INSTALL_DIR/bin/fw"
        if [[ ! -x "$fw_path" ]]; then
            fatal "bin/fw not found in ${INSTALL_DIR} — clone may be corrupted"
        fi
        mkdir -p "$local_bin"
        ln -sf "$fw_path" "$local_bin/fw"
        install_claude_fw "$INSTALL_DIR/bin/claude-fw" "$local_bin"
        info "Linked fw → ${local_bin}/fw (legacy — upgrade for project-local routing)"
    else
        # Install the shim: copies fw-shim as ~/.local/bin/fw
        # The shim walks up from CWD to find the project-local fw (bin/fw or .agentic-framework/bin/fw)
        # This means every project uses its own framework version — no global install dependency
        mkdir -p "$local_bin"
        # T-2793 / T-1278: rm BEFORE cp. If ~/.local/bin/fw is the old symlink
        # into the global install, a plain `cp` follows it and writes the router
        # THROUGH the link, overwriting the global framework's bin/fw — the real
        # CLI is replaced by a ~90-line router and every `fw` call then dies with
        # "routing loop". Hit live on 2026-08-04 by running this exact cp by hand.
        #
        # lib/upgrade.sh step 4c has carried this guard since T-1278; install.sh
        # never got it. The install path is the one that MOST often meets a
        # pre-existing symlink, because that symlink is what it exists to replace.
        rm -f "$local_bin/fw"
        cp "$shim_src" "$local_bin/fw"
        chmod +x "$local_bin/fw"
        install_claude_fw "$INSTALL_DIR/bin/claude-fw" "$local_bin"
        info "Installed fw router → ${local_bin}/fw (project-detecting — each project runs its own framework)"

        # Migrate notice if old symlink existed
        if [[ -L "$local_bin/fw.bak" ]] 2>/dev/null; then
            rm -f "$local_bin/fw.bak"
        fi
    fi

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":${local_bin}:"* ]]; then
        echo ""
        warn "$HOME/.local/bin is not in your PATH"
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

# --- Project init (T-2800/T-2809) — install and init become ONE command per
# --- project (T-2800 IW-3), forced: `fw init` is framework code, so nothing
# --- can run it in a bare directory until this installer has fetched some.
#
# `cd "$INSTALL_DIR"` before invoking its own bin/fw matters: bin/fw's
# resolve_framework() prefers an inherited PROJECT_ROOT's OWN vendored copy
# over FW_BIN_DIR-origin when one is found walking up from cwd. If the
# installer were invoked from inside an unrelated already-vendored project,
# an un-cd'd `"$INSTALL_DIR/bin/fw" init "$TARGET_DIR"` would vendor THAT
# project's (possibly stale) framework into the new target instead of the
# bytes this run just fetched — the T-2762 foreign-source class one layer up.
# Running from inside $INSTALL_DIR itself removes the ambiguity: candidate ==
# PROJECT_ROOT == FRAMEWORK_ROOT == the fetch.
do_project_init() {
    mkdir -p "$TARGET_DIR"
    echo ""
    info "Initialising project at ${TARGET_DIR}..."
    if (cd "$INSTALL_DIR" && "$INSTALL_DIR/bin/fw" init "$TARGET_DIR" --provider "$PROVIDER"); then
        info "Project initialised: ${TARGET_DIR}"
    else
        warn "fw init reported an issue (see above)."
        warn "If ${TARGET_DIR} was already initialised, it was left untouched — this is expected (fw init is not --force by default)."
    fi
}

# --- Verify ---
verify() {
    local ok=true

    echo ""
    info "Post-install verification..."
    echo ""

    if [[ -n "$TARGET_DIR" ]]; then
        # T-2809: verify the PROJECT that was actually created, not the fetch
        # dir (which cleanup_fetch deletes right after this) — the project is
        # the end-to-end outcome the operator gets from running this script.
        if [[ -f "$TARGET_DIR/.framework.yaml" ]]; then
            info "Step 1/3: project initialised (${TARGET_DIR}/.framework.yaml) ✓"
        else
            error "Step 1/3: ${TARGET_DIR}/.framework.yaml not found"
            ok=false
        fi

        # T-2805's completeness sentinel — do_vendor writes this LAST, so its
        # presence is the strongest available evidence the vendor finished.
        if [[ -f "$TARGET_DIR/.agentic-framework/FRAMEWORK.md" ]]; then
            info "Step 2/3: vendored framework complete (FRAMEWORK.md present) ✓"
        else
            error "Step 2/3: ${TARGET_DIR}/.agentic-framework/FRAMEWORK.md missing — vendor incomplete"
            ok=false
        fi

        local target_fw="$TARGET_DIR/.agentic-framework/bin/fw"
        if [[ -x "$target_fw" ]] && (cd "$TARGET_DIR" && "$target_fw" doctor) &>/dev/null; then
            info "Step 3/3: fw doctor passes ✓"
        else
            warn "Step 3/3: fw doctor has warnings (non-fatal)"
            echo "  To see details:"
            echo "    cd $TARGET_DIR && $target_fw doctor"
        fi
    else
        # T-2799/T-2809: no target given — PATH tooling only. Nothing was
        # written to $HOME beyond the router and claude-fw (T-2807), so that
        # is the whole of what there is to verify. Running `fw doctor` here
        # would exercise the router's bootstrap fallback against whatever
        # directory the caller happens to be standing in — the exact
        # unannounced-cwd-init class T-2799 exists to prevent.
        local router_path="$HOME/.local/bin/fw"
        if [[ -x "$router_path" ]]; then
            info "Step 1/2: fw router installed → ${router_path} ✓"
        else
            error "Step 1/2: fw router not found on PATH (${router_path})"
            ok=false
        fi

        if [[ -x "$HOME/.local/bin/claude-fw" ]]; then
            info "Step 2/2: claude-fw installed → $HOME/.local/bin/claude-fw ✓"
        else
            warn "Step 2/2: claude-fw not installed (optional wrapper)"
        fi
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

    scan_vendored_consumers

    do_install
    echo ""

    link_fw
    echo ""

    if [[ -n "$TARGET_DIR" ]]; then
        do_project_init
        echo ""
    fi

    verify
    echo ""

    cleanup_fetch

    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    if [[ -n "$TARGET_DIR" ]]; then
        echo "  Project ready: ${TARGET_DIR}"
        echo ""
        echo "    cd ${TARGET_DIR}"
        echo "    fw doctor       # verify health"
        echo "    fw serve        # start the dashboard"
        echo ""
        echo "  Onboarding tasks were seeded to guide your first session — start your AI"
        echo "  agent (e.g. Claude Code) in the project directory."
    else
        echo "  fw router + claude-fw are installed onto PATH."
        echo ""
        echo "  Next — create/initialise a project (one command per project):"
        echo ""
        echo "    curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash -s -- /path/to/project"
        echo ""
        echo "  What happens:"
        echo "    - Fetches framework bytes into that project (not \$HOME)"
        echo "    - Creates governance structure (.tasks/, .context/)"
        echo "    - Installs git hooks for commit traceability"
        echo "    - Seeds onboarding tasks to guide your first session"
    fi
    echo ""
}

main "$@"
