#!/usr/bin/env bash
# fw-path-check.sh — which `fw` is on PATH? (T-5303, rule T-5302)
#
# Printed commands no longer depend on the answer: since T-5303 every printed
# command spells this project's own fw (`bin/fw` or `.agentic-framework/bin/fw`,
# lib/paths.sh _fw_cmd). People and agents still TYPE bare `fw`, and that only
# runs the project's copy when the PATH fw is the T-2793 router. ring20's host
# .122 still had the pre-router fw-shim (T-5302 consultation), so doctor says
# which kind is installed and how to refresh it.
#
# fw_path_kind [path]   → router | shim | other | absent   (path = `command -v fw`)
# fw_installed_path     → first fw on PATH that is not a project's own copy
# fw_doctor_path_fw     → prints one doctor line (+ remedy); returns 1 on WARN

fw_path_kind() {
    local p="${1-}"
    if [ $# -eq 0 ]; then
        p=$(command -v fw 2>/dev/null || true)
    fi
    if [ -z "$p" ] || [ ! -f "$p" ]; then
        echo absent
        return 0
    fi
    # Builtins only (read, pattern match): doctor may run with a minimal PATH.
    local line i=0 kind=other
    while [ "$i" -lt 5 ] && IFS= read -r line; do
        i=$((i + 1))
        case "$line" in
            "# fw-router"|"# fw-router "*) kind=router; break ;;
            "# fw-shim"|"# fw-shim "*) kind=shim; break ;;
        esac
    done < "$p" 2>/dev/null
    echo "$kind"
}

# A project's own copy on PATH (bin/fw beside FRAMEWORK.md, or a vendored
# .agentic-framework/bin/fw) is not the host's entry point: a session started from
# inside the repo often has its bin/ first. Skip those to find the installed one.
_fw_is_project_copy() {
    local d
    d="${1%/*}/.."
    [ -f "$d/FRAMEWORK.md" ] && [ -f "$d/lib/paths.sh" ]
}

# The first fw on PATH that is not a project copy (empty when none).
fw_installed_path() {
    local dir old_ifs="$IFS"
    IFS=':'
    for dir in $PATH; do
        IFS="$old_ifs"
        [ -n "$dir" ] && [ -f "$dir/fw" ] && [ -x "$dir/fw" ] || continue
        _fw_is_project_copy "$dir/fw" && continue
        printf '%s\n' "$dir/fw"
        return 0
    done
    IFS="$old_ifs"
    return 0
}

fw_doctor_path_fw() {
    local p kind router="${FRAMEWORK_ROOT:-}/bin/fw-router"
    local y="${YELLOW:-}" g="${GREEN:-}" c="${CYAN:-}" n="${NC:-}"
    p=$(fw_installed_path)
    kind=$(fw_path_kind "$p")
    local install="curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash"
    case "$kind" in
        router)
            echo -e "  ${g}OK${n}  fw on PATH is the router (T-2793): $p"
            return 0 ;;
        other)
            echo -e "  ${c}INFO${n}  fw on PATH is neither the router nor the old shim: $p"
            echo -e "         Bare \`fw\` runs that file; printed commands use this project's own fw path (T-5303)"
            return 0 ;;
        shim)
            # T-5382: which fw a shell finds is a fact about this HOST's PATH, not about
            # the project, so it carries doctor's [host] tag (T-1707) and counts as a
            # host warning. On a clean CI runner it read as a project-scope WARN.
            echo -e "  ${y}WARN${n}  [host] fw on PATH is the old fw-shim, not the router (T-2793): $p"
            echo -e "         Bare \`fw\` may not reach this project's copy; printed commands do not rely on it (T-5303)"
            if [ -f "$router" ]; then
                echo -e "         Refresh: rm -f \"$p\" && cp \"$router\" \"$p\" && chmod +x \"$p\""
            fi
            echo -e "         Or:      $install"
            return 1 ;;
        *)
            local dest="$HOME/.local/bin/fw"
            echo -e "  ${y}WARN${n}  [host] No fw on PATH: bare \`fw\` does not run here; use this project's own fw path"
            if [ -f "$router" ]; then
                echo -e "         Install the router: mkdir -p \"$HOME/.local/bin\" && cp \"$router\" \"$dest\" && chmod +x \"$dest\"   (and put ~/.local/bin on PATH)"
            fi
            echo -e "         Or:      $install"
            return 1 ;;
    esac
}
