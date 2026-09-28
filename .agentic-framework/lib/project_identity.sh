#!/bin/bash
# lib/project_identity.sh — who this project is, and which instance of it you are (T-3534)
#
# ── WHY ───────────────────────────────────────────────────────────────────────
#
# Operator, 2026-09-28: "Here again I got another project asking me if it's you.
# So we should also have mechanics to register project name and the project root
# directory so it always knows who it is and where to find that."
#
# Identity was IMPLIED in four places — .framework.yaml, PROJECT_ROOT/
# FRAMEWORK_ROOT, TermLink session tags, the T-559 boundary gate — and ANSWERABLE
# in none. There was no verb an agent could call to say who it is.
#
# ── THE TWO IDENTITIES, WHICH ARE NOT THE SAME THING ──────────────────────────
#
#   PROJECT identity   = project_id + project_name.  Lives in .framework.yaml,
#                        which is COMMITTED, so every clone/checkout/deployment
#                        of a project shares it. That is the DESIGN, not a
#                        compromise — operator: "sometimes we also want to have
#                        different instances of a project and we definitely want
#                        the same id. Only if you fork it, then it should be a
#                        separate process."
#
#   INSTANCE identity  = project_id + host + root.  Runtime, never stored. This
#                        is what distinguishes two checkouts of one project, and
#                        it is the shape TermLink session tags already use
#                        (host=107,project=<name>).
#
# Asking "who are you" must answer BOTH, because the messaging case that
# prompted this needs the instance and the governance case needs the project.
#
# ── WHY NOT REUSE WHAT ALREADY EXISTS (checked, then rejected, with evidence) ──
#
#   .context/rail-identity.key — a project-owned SIGNING key with a stable
#   fingerprint, and the closest existing thing. Rejected: it is GITIGNORED
#   (.gitignore:55, untracked), so a clone mints a different key and a different
#   fingerprint. Instances would NOT share it, which is precisely the property
#   the operator ruled on. Correct for a private key; wrong for identity. It also
#   has a rotation lifecycle, and rotating a signing key must not change who the
#   project IS.
#
#   project_name — committed and shared, but it is a NAME. Renames change it and
#   names collide across hosts. Kept as the display name; it is not the id.
#
#   The five-part address (host/hub/project/session/agent, lib/aef_address.py) —
#   NOT a competitor: slot 3 currently holds a PATH, and this module supplies the
#   stable token that slot was always reaching for. Swapping it is the next slice
#   and is deliberately not done here.
#
# ── THE INVARIANT ─────────────────────────────────────────────────────────────
#
#   A project's id is minted ONCE and never changes. Not on rename, not on move,
#   not on re-init, not on vendor, not on clone. A project that can change its
#   identity has none. Forking to a NEW project is a different intent and gets
#   its own verb, sovereignty-gated — an agent that can re-identify a project can
#   walk out of the T-559 boundary gate.

if [ -z "${_FW_PROJECT_IDENTITY_LOADED:-}" ]; then
_FW_PROJECT_IDENTITY_LOADED=1
# Guard written as `if`, not `[ … ] && return 0`: a `return` in a file sourced
# inside a function returns from the ENCLOSING function. That exact form cost a
# silent `fw context focus` failure earlier today (T-3537).

FW_PROJECT_ID_KEY="project_id"
FW_PROJECT_NAME_KEY="project_name"

# Read a bare key from .framework.yaml. Deliberately not fw_config: that helper
# uppercases and layers env/flag precedence, and identity must come from the
# FILE alone — an env var that could override the id would mean a project's
# identity depends on how you invoked it.
_fw_pi_read() {
    local key="$1" root="${2:-${PROJECT_ROOT:-.}}"
    local f="$root/.framework.yaml"
    [ -f "$f" ] || return 0
    sed -n "s/^${key}:[[:space:]]*//p" "$f" | head -1 | tr -d '"'"'" | tr -d '\r'
}

# fw_project_id [root] — the immutable id, or empty if this project has none yet.
fw_project_id() { _fw_pi_read "$FW_PROJECT_ID_KEY" "${1:-}"; }

# fw_project_name [root] — display name, falling back to the directory basename
# so an un-named project still says something useful rather than nothing.
fw_project_name() {
    local root="${1:-${PROJECT_ROOT:-.}}" n
    n=$(_fw_pi_read "$FW_PROJECT_NAME_KEY" "$root")
    [ -n "$n" ] && { echo "$n"; return 0; }
    basename "$(cd "$root" 2>/dev/null && pwd)" 2>/dev/null
}

# fw_project_id_new — a fresh id. Format: pid-<16 lowercase hex>.
# Prefixed because a bare hex string in a log or an address is unidentifiable,
# and 64 bits because collision across a fleet must be a non-event, not a policy.
fw_project_id_new() {
    local raw
    raw=$( { head -c 8 /dev/urandom 2>/dev/null || true; } | od -An -tx1 2>/dev/null | tr -d ' \n')
    if [ -z "$raw" ] || [ ${#raw} -lt 16 ]; then
        # No /dev/urandom (some containers, some CI). Fall back to a source that
        # still varies per project+host+time rather than inventing a constant —
        # a DUPLICATE id is worse than an ugly one.
        raw=$(printf '%s' "$(hostname 2>/dev/null)$(pwd)$(date +%s%N 2>/dev/null)$$" \
              | cksum | tr -d ' ' | head -c 16)
        raw=$(printf '%016x' "${raw:-0}" 2>/dev/null | tail -c 16)
    fi
    printf 'pid-%s\n' "${raw:0:16}"
}

# fw_project_instance [root] — the runtime triple, as one addressable string:
#   <project_id>@<host>:<root>
# Not stored anywhere. Two checkouts of one project agree on the id and differ
# here, which is the whole point.
fw_project_instance() {
    local root="${1:-${PROJECT_ROOT:-.}}"
    local id host abs
    id=$(fw_project_id "$root"); [ -n "$id" ] || id="(unregistered)"
    host=$(hostname 2>/dev/null || echo unknown)
    abs=$(cd "$root" 2>/dev/null && pwd || echo "$root")
    printf '%s@%s:%s\n' "$id" "$host" "$abs"
}

# fw_project_identity_ensure [root] — mint an id if and only if there is none.
#
# PRESERVES an existing id unconditionally. No flag, no env var, no override.
# Re-running `fw init` on a project must never mint a new identity over an old
# one: nothing downstream would report the change, so the corruption would be
# silent. Starting a NEW project from a fork is a different intent and belongs to
# its own verb.
#
# Prints the id. Returns 0 whether it minted or preserved — "already had one" is
# not an error, and a non-zero here would be a finding-signal meeting `set -e`,
# which is the defect class that cost three incidents today (OBS-566).
fw_project_identity_ensure() {
    local root="${1:-${PROJECT_ROOT:-.}}"
    local f="$root/.framework.yaml" existing
    existing=$(fw_project_id "$root")
    if [ -n "$existing" ]; then
        echo "$existing"
        return 0
    fi
    local new
    new=$(fw_project_id_new)
    if [ -f "$f" ]; then
        printf '%s: %s\n' "$FW_PROJECT_ID_KEY" "$new" >> "$f"
    else
        printf '# Project identity (T-3534) — minted once, never changes.\n%s: %s\n' \
            "$FW_PROJECT_ID_KEY" "$new" > "$f"
    fi
    echo "$new"
}

fi  # end double-source guard
