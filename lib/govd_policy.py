"""govd_policy — proxy-policy emit / install / drift (arc-013 / T-2432, design §4c).

The sovereign mediation policy (`policy/proxy-policy.yaml`) is authored in-repo but
ENFORCED from a deployed copy that is read-only to the agent uid (Lock-1 Part 1). This
module is the emit/install split:

  - emit  (agent-safe) — print the install spec; runs nothing.
  - install (human/root) — copy the policy to the deployed location RO; the agent must
            NOT run it (gated in bin/fw `do_policy`).
  - drift (audit)       — compare the in-repo SOURCE against the DEPLOYED copy. This is
            the emitted-but-not-installed class, the exact sibling of the cron
            registry→generated and tool-set→manifest drift checks (CLAUDE.md §Verification
            Gate). Source edited but deploy not refreshed → drift.

Pure + network-free; the only side effect is `install_policy` (file copy), which bin/fw
refuses to call under the agent. Drift uses CONTENT (sha256), never mtime — `touch` /
`git checkout` / vendor-sync must not produce a false WARN (T-2290 lesson).
"""
from __future__ import annotations

import hashlib
import os
import shutil
from pathlib import Path

# Default deployed location — RO to the agent uid in a real cage (Lock-1 Part 1).
# Overridable so the check works in dev / test without a real install.
DEPLOYED_DEFAULT = os.environ.get("AEF_POLICY_DEPLOYED", "/etc/aef-relay/proxy-policy.yaml")


def sha256_file(path) -> str | None:
    p = Path(path)
    if not p.is_file():
        return None
    return hashlib.sha256(p.read_bytes()).hexdigest()


def drift_status(source, deployed=DEPLOYED_DEFAULT) -> dict:
    """Compare in-repo SOURCE policy against the DEPLOYED copy.

    Returns {state, source_sha, deployed_sha, source, deployed} where state is:
      - "absent_source"  — the in-repo policy is missing (shouldn't happen; misconfig)
      - "not_installed"  — no deployed copy yet (install is human-gated → SKIP, not a fail)
      - "ok"             — deployed copy matches source
      - "drift"          — source edited but deployed copy not refreshed (the WARN class)
    """
    src_sha = sha256_file(source)
    dep_sha = sha256_file(deployed)
    if src_sha is None:
        state = "absent_source"
    elif dep_sha is None:
        state = "not_installed"
    elif src_sha == dep_sha:
        state = "ok"
    else:
        state = "drift"
    return {"state": state, "source_sha": src_sha, "deployed_sha": dep_sha,
            "source": str(source), "deployed": str(deployed)}


def emit_install_spec(source, deployed=DEPLOYED_DEFAULT, relay_port: int = 4000) -> str:
    """The install spec — EMIT ONLY. Tells the human/root how to deploy the policy RO and
    point the relay at it. The agent prints this; it never executes it (Lock-1 Part 1)."""
    dep_dir = str(Path(deployed).parent)
    return f"""\
# ── proxy-policy install spec (EMIT ONLY — run yourself; the agent must NOT) ──
# Source (in-repo, agent-authored, reviewable): {source}
# Deployed (RO to the agent uid — the relay reads THIS, not the source):  {deployed}
#
# 1. place the policy where the relay user can read it but the agent cannot write it:
sudo install -D -m 0644 -o root -g root {source} {deployed}
# 2. (or, idempotent re-deploy after a sovereign edit:)
sudo fw policy install            # refuses under the agent; root-only
# 3. point the relay at the deployed copy (Lock-1 Part 1 relay unit, see `fw` relay-emit):
#    ExecStart=... lib/govd_relay.py --serve --port {relay_port} --policy {deployed}
# 4. confirm no drift afterwards:
fw policy status                  # expect: OK (deployed matches source)
#
# Drift contract (audit + doctor): after ANY sovereign edit to {source}, re-run step 1/2.
# Until then `fw policy status` and `fw doctor` report WARN 'edited but not installed'
# in {dep_dir} — the emitted-but-not-installed class.
"""


def install_policy(source, deployed=DEPLOYED_DEFAULT) -> dict:
    """Copy SOURCE → DEPLOYED (root-only; bin/fw refuses this under the agent).

    First reviewable cut: a straight RO copy. The real cage hardening (non-agent owner,
    RO bind-mount, chattr) is Lock-1 Part 1 and lives in the emit spec above.
    """
    src = Path(source)
    if not src.is_file():
        raise FileNotFoundError(f"source policy not found: {source}")
    dst = Path(deployed)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)  # preserve mode/mtime
    os.chmod(dst, 0o644)
    return {"installed": str(dst), "sha256": sha256_file(dst)}


def _main(argv) -> int:
    import argparse
    ap = argparse.ArgumentParser(prog="govd_policy")
    ap.add_argument("action", choices=["emit", "status", "install"])
    ap.add_argument("--source", default=os.environ.get("AEF_PROXY_POLICY", "policy/proxy-policy.yaml"))
    ap.add_argument("--deployed", default=DEPLOYED_DEFAULT)
    ap.add_argument("--port", type=int, default=int(os.environ.get("AEF_RELAY_PORT", "4000")))
    args = ap.parse_args(argv[1:])

    if args.action == "emit":
        print(emit_install_spec(args.source, args.deployed, args.port))
        return 0
    if args.action == "status":
        d = drift_status(args.source, args.deployed)
        labels = {"ok": "OK  deployed policy matches source",
                  "drift": "WARN  proxy-policy.yaml edited but not installed",
                  "not_installed": "SKIP  proxy-policy not installed (run: sudo fw policy install)",
                  "absent_source": "ERROR  in-repo proxy-policy.yaml missing"}
        print(f"{labels[d['state']]}  ({args.deployed})")
        return 0 if d["state"] in ("ok", "not_installed") else 1
    if args.action == "install":
        r = install_policy(args.source, args.deployed)
        print(f"installed {r['installed']} (sha256 {r['sha256'][:12]}…)")
        return 0
    return 2


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv))
