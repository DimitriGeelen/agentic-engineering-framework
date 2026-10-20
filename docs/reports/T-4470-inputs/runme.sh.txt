#!/usr/bin/env bash
# =============================================================================
#  The operator's one command:   bash /opt/832-Workflow-designer/runme.sh
#  (832 T-1054 option 3, built in T-1055.) This file does not change per job.
# =============================================================================
#  It runs the pending job under .context/runme/<NNN>-<name>/, after showing its name and
#  fingerprint, refusing anything not rehearsed or changed since rehearsal, and asking y/N before
#  every step. All of that lives in tools/runme-launcher.sh (tested: tests/test_t1055_runme_launcher.py).
#
#    bash runme.sh                 run the pending job (asks which, when there are several)
#    bash runme.sh --list          show pending jobs and whether each is ready
#    bash runme.sh --dry-run [n]   the agent's rehearsal (never runs a step)
# =============================================================================
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tools/runme-launcher.sh" "$@"
