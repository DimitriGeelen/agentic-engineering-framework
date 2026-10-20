#!/usr/bin/env bash
# runme-new.sh — scaffold the next operator job for the runme launcher (832 T-1055).
#
#   bash tools/runme-new.sh <name>      -> .context/runme/<NNN>-<name>/job.sh (prints its path)
#
# Edit the job.sh it writes, then rehearse it: bash runme.sh --dry-run <NNN>-<name>
# The operator then runs: bash /opt/832-Workflow-designer/runme.sh
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
JOBS="${RUNME_JOBS_DIR:-$ROOT/.context/runme}"
name=${1:-}
[[ "$name" =~ ^[a-z0-9][a-z0-9.-]*$ ]] || { echo "usage: runme-new.sh <name>  (lowercase, digits, . and -)"; exit 2; }
mkdir -p "$JOBS"
last=$( { ls -d "$JOBS"/[0-9][0-9][0-9]-*/ 2>/dev/null || true; } | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -n | tail -1)
next=$(printf '%03d' $((10#${last:-0} + 1)))
d="$JOBS/$next-$name"
mkdir "$d"
cat > "$d/job.sh" <<'EOF'
# Operator job for tools/runme-launcher.sh. DEFINITIONS ONLY: the launcher refuses a job that runs
# anything when loaded. Steps run from the project root, each after the operator's y/N.
JOB_TITLE="TODO one line: what this does"
JOB_TASK="T-XXXX"
JOB_WHY="TODO: why now, and what the operator should know before saying y."

preflight() {
    check "on bleeding-edge" '[ "$(git rev-parse --abbrev-ref HEAD)" = bleeding-edge ]'
}

steps() {
    step "TODO first step" 'echo replace me'
}
EOF
echo "$d/job.sh"
