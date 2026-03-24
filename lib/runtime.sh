#!/usr/bin/env bash
# Runtime detection: TypeScript (Node.js) with Python fallback
# Source this file to use fw_run_ts()
#
# Usage:
#   source "$FRAMEWORK_ROOT/lib/runtime.sh"
#   fw_run_ts "fw-util" yaml-get "$file" "$key"

fw_run_ts() {
    local script="$1"; shift
    local js_path="${FRAMEWORK_ROOT}/lib/ts/dist/${script}.js"

    if [ -f "$js_path" ] && command -v node >/dev/null 2>&1; then
        node "$js_path" "$@"
    elif [ -f "${FRAMEWORK_ROOT}/lib/py/${script}.py" ]; then
        python3 "${FRAMEWORK_ROOT}/lib/py/${script}.py" "$@"
    else
        echo "ERROR: No runtime available for ${script}" >&2
        echo "  Need: node (preferred) or python3 with lib/py/${script}.py" >&2
        return 1
    fi
}
