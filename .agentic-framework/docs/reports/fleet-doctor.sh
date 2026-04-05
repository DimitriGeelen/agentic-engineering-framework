#!/usr/bin/env bash
# Fleet health check — run fw doctor across all consumer projects
# T-867

PROJECTS=(
  /opt/001-sprechloop
  /opt/050-email-archive
  /opt/051-Vinix24
  /opt/052-KCP
  /opt/053-ntfy
  /opt/150-skills-manager
  /opt/3021-Bilderkarte-tool-llm
  /opt/995_2021-kosten
  /opt/openclaw-evaluation
  /opt/termlink
)

for proj in "${PROJECTS[@]}"; do
  name=$(basename "$proj")
  fw_bin="$proj/.agentic-framework/bin/fw"
  if [[ ! -x "$fw_bin" ]]; then
    echo "=== $name === NO_FW"
    continue
  fi
  echo "=== $name ==="
  (cd "$proj" && "$fw_bin" doctor 2>&1)
  echo "---"
done
