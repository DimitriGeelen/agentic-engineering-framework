#!/bin/bash
# T-4406: refuse to use an empty root, or one that is the filesystem root, as the
# base a writer joins paths onto. "$X/policy" with X empty or "/" is /policy —
# debris at / (policy/, episodic/, working/) came from exactly that join.
#
# Sourceable and side-effect-free (unlike lib/paths.sh, which resolves and exports
# paths on source), so bin/fw's own libs (init.sh, upgrade.sh) can load it too.
#
# Usage: fw_refuse_fs_root <label> <path> || return 1
# rc 0 = usable; rc 1 = refused (message on stderr names the label and the value).

[ -n "${_FW_FS_ROOT_GUARD_LOADED:-}" ] && return 0
_FW_FS_ROOT_GUARD_LOADED=1

fw_refuse_fs_root() {
    local _rfr_label="$1" _rfr_path="${2:-}" _rfr_trim _rfr_real=""
    _rfr_trim="${_rfr_path%"${_rfr_path##*[!/]}"}"   # strip trailing slashes
    if [ -d "$_rfr_path" ]; then
        _rfr_real="$(cd -P "$_rfr_path" 2>/dev/null && pwd -P)" || _rfr_real=""
    fi
    if [ -z "$_rfr_trim" ] || [ "$_rfr_real" = "/" ]; then
        echo "ERROR: $_rfr_label='$_rfr_path' is empty or the filesystem root — refusing to write under it (T-4406)." >&2
        echo "       Set $_rfr_label to the project directory (the one holding .framework.yaml)." >&2
        return 1
    fi
    return 0
}
