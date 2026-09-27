#!/usr/bin/env bash
# lib/cron-registry.sh — T-2844
#
# How many jobs does a cron registry actually declare?
#
# The registry → generated → deployed drift checks in `fw doctor` and `fw audit`
# were gated on the registry FILE EXISTING, never on it declaring any work. But
# `fw init` seeds `.context/cron-registry.yaml` with `jobs: []`, and an empty
# registry has no generated form — `fw cron generate` correctly produces nothing.
# So both surfaces reported "registry present but not generated" on a project
# seconds old, which is the framework complaining about a state it created and
# which is in fact correct.
#
# The distinction that was missing: "nothing to generate" and "something to
# generate that was not generated" are different states. Only the second is drift.

# cron_registry_job_count <registry_path>
#
# Echoes the number of declared jobs.
#   0   → registry declares no work; nothing to generate
#   N>0 → registry declares work
#   -1  → missing, unreadable, or malformed
#
# -1 is deliberately NOT folded into 0. Callers skip drift checks on 0 only; an
# unparseable registry must keep warning, because "we could not tell" must not
# read the same as "we checked and it was fine".
cron_registry_job_count() {
    local path="$1"
    [ -f "$path" ] || { echo "-1"; return 0; }

    python3 -c '
import sys
try:
    import yaml
    with open(sys.argv[1]) as fh:
        data = yaml.safe_load(fh) or {}
    if not isinstance(data, dict):
        print(-1); sys.exit(0)
    jobs = data.get("jobs")
    if jobs is None:
        print(0); sys.exit(0)
    if not isinstance(jobs, list):
        print(-1); sys.exit(0)
    print(len(jobs))
except Exception:
    print(-1)
' "$path" 2>/dev/null || echo "-1"
}

# cron_target_has_registry_marker <target_path>
#
# T-3161: a deployed crontab this framework generated always carries the
# header line `fw cron generate` writes ("managed by cron-registry.yaml").
# A target that exists but lacks it was not produced by the registry-driven
# lane — most commonly the legacy heredoc lane `fw cron install` used to
# share the target with (T-3070) — and is not safe for `fw cron install` to
# overwrite unconditionally: with `jobs: []` that overwrite replaces a live,
# populated crontab with a header-only file.
#
# Exit 0  → marker present (target is ours; safe to overwrite)
# Exit 1  → target missing OR present without the marker (unmigrated / foreign)
#
# Single source of truth for the predicate `fw cron install`, `fw doctor`, and
# `agents/audit/audit.sh` all need — same discipline as cron_registry_job_count
# above and lib/cron_dry_run.py (L-332/L-408: shared logic lives in one file).
cron_target_has_registry_marker() {
    local path="$1"
    [ -f "$path" ] || return 1
    grep -q "managed by cron-registry.yaml" "$path" 2>/dev/null
}
