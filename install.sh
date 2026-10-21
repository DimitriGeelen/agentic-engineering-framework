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
FETCH_OWNED=0
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

# T-4248: every [x] step is counted; any count fails the install (see main).
INSTALL_ERRORS=0
# T-4251: 1 when the target must end up as its own git top-level (set by
# do_project_init; verify() checks the own-top-level only then).
TARGET_OWN_REPO=0

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { INSTALL_ERRORS=$((INSTALL_ERRORS + 1)); echo -e "${RED}[x]${NC} $*" >&2; }
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
                # T-3129: `-e`, not `-d`. In a linked git worktree `.git` is a
                # regular FILE holding a `gitdir:` pointer, so a `-d` test
                # rejects a perfectly clonable checkout.
                if [[ ! -e "$LOCAL_REPO/.git" ]]; then
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
# T-4238: this script runs before the framework is fetched, so it cannot source
# lib/python-deps.sh — the lists below are a copy, pinned equal to it (and to
# bin/watchtower.sh) by tests/unit/t4238_python_deps_hint.bats.
# Format: import-name|pip-name|apt-name
PYYAML_MODULE="yaml|pyyaml|python3-yaml"
WATCHTOWER_MODULES=(
    "flask|flask|python3-flask"
    "flask_socketio|flask-socketio|python3-flask-socketio"
    "yaml|pyyaml|python3-yaml"
    "markdown2|markdown2|python3-markdown2"
)

# The install command for this machine. Never a bare `pip install`: PEP 668
# interpreters (Debian 12, Ubuntu 24.04, Mint 22, Homebrew) refuse it.
python_install_hint() {
    local entry mod pip_name apt_name pips="" apts=""
    for entry in "$@"; do
        IFS='|' read -r mod pip_name apt_name <<< "$entry"
        pips="${pips:+$pips }$pip_name"
        apts="${apts:+$apts }$apt_name"
    done
    if command -v apt-get &>/dev/null && grep -qiE '^ID(_LIKE)?=.*(debian|ubuntu)' "${FW_OS_RELEASE:-/etc/os-release}" 2>/dev/null; then
        echo "sudo apt-get install -y $apts"
    else
        echo "python3 -m venv ~/.venvs/aef-watchtower && ~/.venvs/aef-watchtower/bin/pip install $pips && . ~/.venvs/aef-watchtower/bin/activate  (then re-run fw in that shell)"
    fi
}

# PyYAML is required (returns 1); the Watchtower stack is a warning only.
check_python_modules() {
    local entry missing=() rc=0
    if python3 -c "import yaml" 2>/dev/null; then
        info "PyYAML installed"
    else
        error "PyYAML not installed (required by most fw commands) — install: $(python_install_hint "$PYYAML_MODULE")"
        rc=1
    fi
    for entry in "${WATCHTOWER_MODULES[@]}"; do
        python3 -c "import ${entry%%|*}" 2>/dev/null || missing+=("$entry")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        info "Watchtower Python stack installed"
    else
        local names="" e
        for e in "${missing[@]}"; do names="${names:+$names, }${e%%|*}"; done
        warn "Watchtower Python stack incomplete (missing: $names) — install: $(python_install_hint "${missing[@]}")"
    fi
    return $rc
}

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
        check_python_modules || ok=false
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
        # T-4438: this run created the dir, so this run removes it on every exit.
        # EXIT covers error paths and set -e aborts. INT/TERM clean up, then
        # re-raise the signal so the exit status stays the signal's, not 0.
        FETCH_OWNED=1
        trap cleanup_fetch EXIT
        trap 'cleanup_fetch; trap - TERM; kill -TERM $$' TERM
        trap 'cleanup_fetch; trap - INT; kill -INT $$' INT
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
# T-4438: a caller-supplied INSTALL_DIR (env or --install-dir) is never removed;
# FETCH_OWNED is set only where do_install's mktemp created the directory.
cleanup_fetch() {
    if [[ "$FETCH_OWNED" == "1" ]] && [[ -n "${INSTALL_DIR:-}" ]] && [[ -d "$INSTALL_DIR" ]]; then
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

# --- Back up an existing ~/.local/bin entry before it is replaced (T-4248) ---
# fw and claude-fw were overwritten with no backup and no notice (a 69,580 B
# framework CLI became a 3,707 B router). Keep the previous file beside it and
# say so. An identical file is not backed up again, so reruns stay quiet.
backup_local_bin_entry() {
    local path="$1" src="$2"
    [[ -e "$path" || -L "$path" ]] || return 0
    if [[ -f "$path" && ! -L "$path" && -f "$src" ]] && cmp -s "$path" "$src"; then
        return 0
    fi
    local bak="${path}.bak-$(date -u +%Y%m%dT%H%M%SZ)"
    cp -P "$path" "$bak"
    info "Backed up existing $(basename "$path") → ${bak}"
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
#
# T-2854/D-377: the function itself just copies whatever src it is handed — it
# does not know or care whether that src is the plain wrapper or claude-fw-router.
# `link_fw` below is what changed: it now hands this function claude-fw-router
# (which resolves the current project's own bin/claude-fw at invocation time),
# not a fixed copy of the wrapper's logic. A fixed copy that always runs the
# same bytes regardless of which project you are standing in is the same
# global-install problem `fw`'s own router (bin/fw-router) exists to avoid.
install_claude_fw() {
    local src="$1" local_bin="$2"
    [[ -f "$src" ]] || return 0
    backup_local_bin_entry "$local_bin/claude-fw" "$src"
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

    # T-2854/D-377: claude-fw on PATH must resolve per-project too, same as
    # fw. Prefer claude-fw-router (walks up from cwd to the current project's
    # own bin/claude-fw); fall back to the plain wrapper for a clone that
    # predates it.
    local claude_fw_src="$INSTALL_DIR/bin/claude-fw-router"
    [[ -x "$claude_fw_src" ]] || claude_fw_src="$INSTALL_DIR/bin/claude-fw"

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
        backup_local_bin_entry "$local_bin/fw" "$fw_path"
        ln -sf "$fw_path" "$local_bin/fw"
        install_claude_fw "$claude_fw_src" "$local_bin"
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
        backup_local_bin_entry "$local_bin/fw" "$shim_src"
        rm -f "$local_bin/fw"
        cp "$shim_src" "$local_bin/fw"
        chmod +x "$local_bin/fw"
        install_claude_fw "$claude_fw_src" "$local_bin"
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
    # T-4251: a directory this run creates is greenfield — it gets its own repo
    # even under an enclosing project repo (FW_INIT_OWN_REPO=1 to fw init).
    local own_repo_env=0
    [[ -d "$TARGET_DIR" ]] || own_repo_env=1
    mkdir -p "$TARGET_DIR"
    echo ""
    # T-4248: a re-run against an initialised target is a no-op, not a failure.
    # fw init refuses there (lib/init.sh: "already initialized", rc=1) without
    # --force, which is the wrong thing to count as a failed step.
    if [[ -f "$TARGET_DIR/.framework.yaml" ]]; then
        info "Project already initialised: ${TARGET_DIR} — left untouched (fw init is not --force)"
        return 0
    fi
    info "Initialising project at ${TARGET_DIR}..."
    # Same rule as lib/init.sh: own repo when in no work tree, when the enclosing
    # top-level is / or $HOME, or when greenfield; otherwise fw init attaches.
    local encl_top home_real=""
    encl_top=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null || true)
    [[ -n "$encl_top" ]] && encl_top=$(cd "$encl_top" && pwd -P)
    [[ -n "${HOME:-}" ]] && home_real=$(cd "$HOME" 2>/dev/null && pwd -P || true)
    if [[ -z "$encl_top" || "$encl_top" == "/" || "$encl_top" == "$home_real" \
          || "$encl_top" == "$(cd "$TARGET_DIR" && pwd -P)" || "$own_repo_env" == "1" ]]; then
        TARGET_OWN_REPO=1
    fi
    # T-4248: fw init runs under env -u of the inherited framework/project
    # variables. A leaked FRAMEWORK_ROOT or PROJECT_ROOT (from another install)
    # made it source <target>/lib/init.sh, so the run must not inherit them.
    # Its output is kept so a [x] step inside it counts against this install.
    # T-4298: say so once, naming what was ignored — the silent ignore is what
    # left the later fw calls warning with no explanation of where it came from.
    local _v ignored_vars=""
    for _v in FRAMEWORK_ROOT PROJECT_ROOT TASKS_DIR CONTEXT_DIR _FW_PATHS_DERIVED_BY FW_ROUTED_FROM; do
        if [[ -n "${!_v:-}" ]]; then
            ignored_vars+="${ignored_vars:+, }$_v"
        fi
    done
    if [[ -n "$ignored_vars" ]]; then
        info "Ignoring inherited environment for fw init (set in this shell): ${ignored_vars}"
    fi
    local init_log init_rc=0
    init_log=$(mktemp -t agentic-fw-init-XXXXXX)
    (cd "$INSTALL_DIR" && env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u TASKS_DIR -u CONTEXT_DIR \
        -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM FW_INIT_OWN_REPO="$own_repo_env" \
        "$INSTALL_DIR/bin/fw" init "$TARGET_DIR" --provider "$PROVIDER") > "$init_log" 2>&1 || init_rc=$?
    cat "$init_log"
    if [[ "$init_rc" -eq 0 ]] && ! grep -q '\[x\]' "$init_log"; then
        info "Project initialised: ${TARGET_DIR}"
    else
        warn "fw init reported an issue (see above)."
        warn "fw init leaves an already-initialised target untouched and is not --force by default; if ${TARGET_DIR} was initialised before, this is not a fresh install."
        INSTALL_ERRORS=$((INSTALL_ERRORS + 1))
    fi
    rm -f "$init_log"
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
        # T-4261: capture doctor's output instead of discarding it — exit 0
        # only means "no FAIL"; a fresh install carried 31 WARNs behind a
        # green checkmark. Report the WARN count and the first few lines.
        local doctor_out="" doctor_rc=0 warn_lines="" warn_count=0
        if [[ -x "$target_fw" ]]; then
            # T-4331: same env -u as do_project_init's fw init. An inherited
            # PROJECT_ROOT/FRAMEWORK_ROOT pointed doctor at another (or a gone)
            # project: exit 2 here, exit 0 from the operator's fresh shell.
            doctor_out=$(cd "$TARGET_DIR" && env -u FRAMEWORK_ROOT -u PROJECT_ROOT -u TASKS_DIR \
                -u CONTEXT_DIR -u _FW_PATHS_DERIVED_BY -u FW_ROUTED_FROM \
                "$target_fw" doctor 2>&1) || doctor_rc=$?
            warn_lines=$(printf '%s\n' "$doctor_out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '(^|[^A-Za-z])WARN' || true)
            [[ -n "$warn_lines" ]] && warn_count=$(printf '%s\n' "$warn_lines" | wc -l | tr -d ' ')
        else
            doctor_rc=127
        fi
        if [[ "$doctor_rc" -eq 0 && "$warn_count" -eq 0 ]]; then
            info "Step 3/3: fw doctor passes with no warnings ✓"
        elif [[ "$doctor_rc" -eq 0 ]]; then
            warn "Step 3/3: fw doctor passes with ${warn_count} warning(s) (non-fatal). First few:"
            printf '%s\n' "$warn_lines" | head -5 | sed 's/^/    /'
            echo "  To see all:"
            echo "    cd $TARGET_DIR && $target_fw doctor"
        else
            warn "Step 3/3: fw doctor reported failures (exit ${doctor_rc}; ${warn_count} warning(s), non-fatal to install). First few:"
            # T-4331: name what failed — an exit code alone left nothing to act on.
            local fail_lines
            fail_lines=$(printf '%s\n' "$doctor_out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '(^|[^A-Za-z])(FAIL|ERROR)|refusing' || true)
            [[ -z "$fail_lines" ]] && fail_lines=$(printf '%s\n' "$doctor_out" | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^[[:space:]]*$' | tail -5)
            printf '%s\n' "$fail_lines" | head -5 | sed 's/^/    /'
            echo "  To see details:"
            echo "    cd $TARGET_DIR && $target_fw doctor"
        fi

        # T-4261: a project without HEAD means the bootstrap commit did not
        # land; everything above can still look green. Fail the summary.
        # T-4251: `rev-parse HEAD` resolves through an enclosing repo too, so a
        # target that should have got its own repo passed here on the parent's
        # HEAD. Where it should (TARGET_OWN_REPO=1), it must be its own top-level
        # before its HEAD counts; a target attached to a project repo is not.
        local target_top own_top_ok=true
        target_top=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null || true)
        if [[ "$TARGET_OWN_REPO" == "1" ]] && \
            [[ -z "$target_top" || "$(cd "$target_top" && pwd -P)" != "$(cd "$TARGET_DIR" && pwd -P)" ]]; then
            own_top_ok=false
        fi
        if $own_top_ok && git -C "$TARGET_DIR" rev-parse --verify HEAD &>/dev/null; then
            info "Bootstrap commit present (HEAD resolves) ✓"
        else
            if ! $own_top_ok; then
                error "Target ${TARGET_DIR} is not its own git repository (git top-level: ${target_top:-none}) — git init did not run"
                error "  Check: cd $TARGET_DIR && git rev-parse --show-toplevel"
            else
                error "Project has no HEAD — the bootstrap commit did not land in ${TARGET_DIR}"
                error "  Check: cd $TARGET_DIR && git status && git log -1"
            fi
            ok=false
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
        return 1
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

    local verify_rc=0
    verify || verify_rc=$?
    echo ""

    cleanup_fetch

    # T-4248: a [x] anywhere (verify or fw init) is a failed install, never
    # "complete" with exit 0.
    if [[ "$verify_rc" -ne 0 || "$INSTALL_ERRORS" -ne 0 ]]; then
        error "Installation FAILED: ${INSTALL_ERRORS} step(s) reported [x] (verification exit ${verify_rc})"
        exit 1
    fi

    print_completion_banner
}

print_completion_banner() {
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
        # T-4263 (F-23): an agent that ran this installer from inside its own
        # session would otherwise carry on ungoverned — Claude Code reads
        # .claude/settings.json (the hooks just installed) at session start only.
        if [[ -n "${CLAUDECODE:-}" ]]; then
            echo ""
            warn "This installer ran inside a Claude Code session (CLAUDECODE is set)."
            echo "  The hooks just written to ${TARGET_DIR}/.claude/settings.json are read only"
            echo "  at session start, so THIS session runs without them. Restart the agent there:"
            echo ""
            echo "    exit this session, then: cd ${TARGET_DIR} && claude-fw"
        fi
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
