#!/usr/bin/env bash
# lib/doctor-upstream.sh — T-2843
#
# Predicate for `fw doctor` check 2: is there a genuine ambiguity between the
# framework a project is PINNED to (`upstream_repo:` in .framework.yaml) and the
# framework it is actually RUNNING (`FRAMEWORK_ROOT`)?
#
# The two fields answer different questions. `upstream_repo` names where updates
# are pulled FROM; `FRAMEWORK_ROOT` names the copy currently executing. They
# coincide only in shared-tooling mode, where a project is served by a framework
# checkout living elsewhere on disk. Under D-377 (total isolation) the default is
# vendored mode, where the running fw is the project's own `.agentic-framework/`
# — so the two CANNOT be equal, and inequality carries no information.
#
# Before T-2843 the check compared them unconditionally. The result was a WARN on
# every vendored consumer from the moment `fw init` finished. A warning that is
# always on is indistinguishable from one that is correctly on, which is why it
# survived: it never looked like a bug, only like a project that needed tidying.

# doctor_upstream_ambiguous <upstream_repo> <framework_root> <mode>
#
# Exit 0  → genuine ambiguity, caller should WARN
# Exit 1  → nothing to report
doctor_upstream_ambiguous() {
    local upstream="$1" fw_root="$2" mode="$3"

    # Nothing pinned — nothing to reconcile.
    [ -n "$upstream" ] || return 1

    # Vendored mode: the running fw IS this project's own copy, by design.
    # Comparing it to the pull source is a category error, not a finding.
    [ "$mode" = "vendored" ] && return 1

    # A remote URL is a pull source with no filesystem location to compare
    # against. Note this test must precede any realpath call: `realpath -m` on
    # "https://host/x" happily returns "$PWD/https:/host/x", which would then be
    # compared against a real directory and always differ.
    case "$upstream" in
        *://*|git@*) return 1 ;;
    esac

    # Path-shaped upstream, non-vendored mode: the comparison is meaningful.
    local resolved_upstream resolved_fw
    resolved_upstream=$(realpath -m "$upstream" 2>/dev/null || echo "$upstream")
    resolved_fw=$(realpath -m "$fw_root" 2>/dev/null || echo "$fw_root")

    [ "$resolved_upstream" != "$resolved_fw" ]
}
