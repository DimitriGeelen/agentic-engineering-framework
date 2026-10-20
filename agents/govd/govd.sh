#!/usr/bin/env bash
# govd — privileged state-holder agent (arc-013 / T-2430).
#
# AGENT-SAFE subcommands only emit specs and evaluate decisions. The INSTALL of the
# cage/daemon (create the aef-gov uid, RO bind-mount the envelope+state, enable the
# systemd unit) is Lock-1 Part 1 — human/root, NEVER run by the agent. `emit-install`
# prints the artifacts; it does not execute them.
#
# Usage:
#   govd.sh evaluate '<decision-json>'     # who-commits verdict (no side effects)
#   govd.sh propose  '<request-json>'      # one-shot propose as current uid
#   govd.sh emit-install [--out DIR]       # emit systemd unit + root setup (NOT run)
set -euo pipefail

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ENVELOPE="${AEF_ENVELOPE:-$FRAMEWORK_ROOT/policy/authority-envelope.yaml}"

PROXY_POLICY="${AEF_PROXY_POLICY:-$FRAMEWORK_ROOT/policy/proxy-policy.yaml}"

evaluate() { PYTHONPATH="$FRAMEWORK_ROOT" python3 "$FRAMEWORK_ROOT/lib/govd_envelope.py" "$ENVELOPE" "$1"; }
propose()  { PYTHONPATH="$FRAMEWORK_ROOT" python3 "$FRAMEWORK_ROOT/lib/govd_holder.py" --envelope "$ENVELOPE" --request "$1"; }

relay_serve() {
  # Run the mediation relay locally (test / non-cage use). In deployment this runs
  # OUTSIDE the cage under a non-agent uid — that install is Lock-1 Part 1 (human/root).
  local port="${1:-4000}"
  PYTHONPATH="$FRAMEWORK_ROOT" python3 "$FRAMEWORK_ROOT/lib/govd_relay.py" \
    --serve --port "$port" --policy "$PROXY_POLICY"
}

relay_emit() {
  # EMIT ONLY — the relay deployment unit. Install (point the agent's
  # ANTHROPIC_BASE_URL at the relay, run it under a non-agent uid) is Lock-1 Part 1.
  local port="${1:-4000}"
  cat <<EOF
# ── aef-relay systemd unit (EMIT ONLY — install yourself; the agent must NOT) ──
# /etc/systemd/system/aef-relay.service
[Unit]
Description=AEF governance mediation relay (payload proxy)
After=network.target

[Service]
Type=simple
User=aef-relay
ExecStart=/usr/bin/python3 ${FRAMEWORK_ROOT}/lib/govd_relay.py --serve \\
  --port ${port} --policy ${PROXY_POLICY} \\
  --audit /var/lib/aef-relay/relay-audit.jsonl
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/var/lib/aef-relay

[Install]
WantedBy=multi-user.target

# ── agent wiring (Lock-1 Part 1 — run yourself) ──
#   the harness must launch with: ANTHROPIC_BASE_URL=http://127.0.0.1:${port}
#   policy RO to the agent uid:  sudo chmod 0640 ${PROXY_POLICY}
#   sudo useradd --system --no-create-home aef-relay
#   sudo mkdir -p /var/lib/aef-relay && sudo chown aef-relay: /var/lib/aef-relay
#   sudo systemctl daemon-reload && sudo systemctl enable --now aef-relay
EOF
}

emit_install() {
  local out="" service_user="aef-gov"
  while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift 2;; *) shift;; esac; done

  emit() {
    cat <<EOF
# ── aef-govd systemd unit (EMIT ONLY — install with: sudo install, then systemctl) ──
# /etc/systemd/system/aef-govd.service
[Unit]
Description=AEF privileged state-holder (authority broker)
After=network.target

[Service]
Type=simple
User=${service_user}
# envelope + state live OUTSIDE the agent's reach; this unit's user owns them.
ExecStart=/usr/bin/python3 ${FRAMEWORK_ROOT}/lib/govd_holder.py --serve \\
  --envelope ${ENVELOPE} \\
  --audit /var/lib/aef-govd/audit.jsonl \\
  --state /var/lib/aef-govd/state.json \\
  --socket /run/aef-govd/aef-govd.sock \\
  --sovereign-uid 0
# hardening (defense in depth — the real boundary is the uid + RO mounts below)
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/aef-govd /run/aef-govd
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target

# ── root setup (Lock-1 Part 1 — run yourself; the agent must NOT) ──
#   sudo useradd --system --no-create-home ${service_user}
#   sudo mkdir -p /var/lib/aef-govd /run/aef-govd
#   sudo chown ${service_user}: /var/lib/aef-govd /run/aef-govd
#   # envelope + state become RO projections to the agent uid:
#   sudo chattr +a /var/lib/aef-govd/audit.jsonl   # append-only audit
#   sudo chmod 0640 ${ENVELOPE}                     # agent reads, cannot write
#   sudo systemctl daemon-reload && sudo systemctl enable --now aef-govd
EOF
  }

  if [ -n "$out" ]; then
    mkdir -p "$out"; emit > "$out/aef-govd.service.spec"
    echo "Emitted: $out/aef-govd.service.spec"
    echo "NOTE: emit only. Install is Lock-1 Part 1 (human/root). The agent does not run it."
  else
    emit
  fi
}

cmd="${1:-}"; shift || true
case "$cmd" in
  evaluate)     evaluate "${1:?decision json required}";;
  propose)      propose "${1:?request json required}";;
  emit-install) emit_install "$@";;
  relay-serve)  relay_serve "${1:-4000}";;
  relay-emit)   relay_emit "${1:-4000}";;
  *) echo "usage: govd.sh {evaluate|propose|emit-install|relay-serve|relay-emit}" >&2; exit 2;;
esac
