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
