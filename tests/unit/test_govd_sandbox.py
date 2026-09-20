"""T-2433 (arc-013): sandbox profile emit / status / install — the static floor.

Pins: the source→artefact render is deterministic; the RO/RW partition is validated
structurally; the two drift classes (stale = source edited but not re-emitted,
drift = emitted but not installed) are told apart by content; install is a plain
copy the agent never runs (the CLAUDECODE refusal lives in bin/fw and is pinned by
the bats sibling). Host checkers (`systemd-analyze verify`, `nft -c`) run when present.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import govd_sandbox as gs  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def _source(tmp_path, **over):
    data = {
        "version": 1,
        "agent_user": "aef-agent",
        "agent_uid": 1999,
        "read_write": ["."],
        "read_only": ["bin", "lib", "policy", ".git", "/etc/aef-relay"],
        "inaccessible": ["/run/aef-govd"],
        "egress": {"proxy_host": "127.0.0.1", "proxy_port": 4000, "extra_allow": []},
        "deployed_dir": str(tmp_path / "deployed"),
    }
    data.update(over)
    src = tmp_path / "sandbox-profile.yaml"
    src.write_text(yaml.safe_dump(data))
    return src


def _project(tmp_path):
    root = tmp_path / "proj"
    for d in ("bin", "lib", "policy", ".git"):
        (root / d).mkdir(parents=True)
    return root


# ------------------------------------------------------------------ resolve

def test_resolve_absolutises_and_partitions(tmp_path):
    root = _project(tmp_path)
    r = gs.resolve(gs.load_source(_source(tmp_path)), root)
    assert r["read_write"] == [str(root.resolve())]
    assert str(root.resolve() / "bin") in r["read_only"]
    assert "/etc/aef-relay" in r["read_only"]
    assert r["inaccessible"] == ["/run/aef-govd"]
    assert r["agent_uid"] == 1999


def test_resolve_refuses_ro_rw_overlap(tmp_path):
    root = _project(tmp_path)
    src = _source(tmp_path, read_only=["bin", "."])
    with pytest.raises(ValueError, match="both read_only and read_write"):
        gs.resolve(gs.load_source(src), root)


def test_resolve_refuses_inaccessible_that_is_readable(tmp_path):
    root = _project(tmp_path)
    src = _source(tmp_path, inaccessible=["bin"])
    with pytest.raises(ValueError, match="inaccessible paths also listed as readable"):
        gs.resolve(gs.load_source(src), root)


def test_resolve_refuses_uid_zero(tmp_path):
    root = _project(tmp_path)
    with pytest.raises(ValueError, match="uid 0 is the hole"):
        gs.resolve(gs.load_source(_source(tmp_path, agent_uid=0)), root)


def test_load_source_rejects_unknown_version(tmp_path):
    src = _source(tmp_path, version=7)
    with pytest.raises(ValueError, match="unsupported version"):
        gs.load_source(src)


# ------------------------------------------------------------------ renders

def test_unit_render_carries_the_partition(tmp_path):
    root = _project(tmp_path)
    r = gs.resolve(gs.load_source(_source(tmp_path)), root)
    unit = gs.render_unit(r)
    assert "User=aef-agent" in unit
    assert "ProtectSystem=strict" in unit
    assert f"ReadWritePaths={root.resolve()}" in unit
    # substrate inside the working tree is listed RO (inner entry wins — pinned live)
    assert f"{root.resolve()}/bin" in unit.split("ReadOnlyPaths=")[1].split("\n")[0]
    # absolute trusted-state paths outside the tree are `-` prefixed (skip if absent)
    assert "-/etc/aef-relay" in unit
    assert "InaccessiblePaths=-/run/aef-govd" in unit
    assert "IPAddressDeny=any" in unit
    # the class we must not re-create: no namespace restriction at the floor (T-1660)
    assert "RestrictNamespaces" not in unit


def test_nft_render_is_uid_keyed_default_drop(tmp_path):
    root = _project(tmp_path)
    r = gs.resolve(gs.load_source(_source(tmp_path)), root)
    nft = gs.render_nft(r)
    assert "define aef_agent_uid = 1999" in nft
    assert "meta skuid $aef_agent_uid jump aef_agent_egress" in nft
    assert "ip daddr $proxy_addr tcp dport $proxy_port accept" in nft
    assert nft.rstrip().endswith("}")
    # the last rule of the egress chain is the drop
    body = nft.split("chain aef_agent_egress {")[1].split("}")[0]
    rules = [ln.strip() for ln in body.strip().split("\n") if ln.strip()]
    assert rules[-1].endswith("drop"), rules


def test_nft_render_extra_allow_rows_and_ipv6(tmp_path):
    root = _project(tmp_path)
    src = _source(tmp_path, egress={"proxy_host": "::1", "proxy_port": 4000,
                                   "extra_allow": [{"host": "192.168.10.107", "port": 3002, "why": "watchtower"}]})
    nft = gs.render_nft(gs.resolve(gs.load_source(src), root))
    assert "ip6 daddr $proxy_addr" in nft
    assert "ip daddr 192.168.10.107 tcp dport 3002 accept  # watchtower" in nft


def test_render_is_deterministic(tmp_path):
    root = _project(tmp_path)
    r = gs.resolve(gs.load_source(_source(tmp_path)), root)
    assert gs.render_all(r) == gs.render_all(r)
    m = yaml.safe_load(gs.render_manifest(r))
    assert m["agent_uid"] == 1999 and m["egress"]["proxy_port"] == 4000


# ------------------------------------------------------------------ emit / status / install

def test_emit_then_status_walks_both_drift_legs(tmp_path):
    root = _project(tmp_path)
    src = _source(tmp_path)
    out = root / "policy" / "sandbox-profile.d"
    dep = tmp_path / "deployed"

    # nothing emitted yet
    assert gs.status(src, root, out, dep)["state"] == "absent_emitted"

    written = gs.emit_profile(src, root, out)
    assert set(written) == set(gs.ARTEFACTS)
    for n in gs.ARTEFACTS:
        assert (out / n).is_file()
    # emitted, not installed → SKIP (exit 0), leg = install
    s = gs.status(src, root, out, dep)
    assert s["state"] == "not_installed" and gs.STATUS_EXIT[s["state"]] == 0

    r = gs.install_profile(out, dep)
    assert set(r["installed"]) == set(gs.ARTEFACTS)
    assert gs.status(src, root, out, dep)["state"] == "ok"

    # STALE leg: sovereign edits the source, forgets to re-emit
    data = yaml.safe_load(src.read_text())
    data["egress"]["proxy_port"] = 4001
    src.write_text(yaml.safe_dump(data))
    s = gs.status(src, root, out, dep)
    assert s["state"] == "stale" and s["leg"] == "emit"
    assert gs.NFT_NAME in s["differs"] and gs.MANIFEST_NAME in s["differs"]
    assert gs.STATUS_EXIT["stale"] == 1

    # re-emit clears stale, exposes DRIFT (deployed copy is now behind)
    gs.emit_profile(src, root, out)
    s = gs.status(src, root, out, dep)
    assert s["state"] == "drift" and s["leg"] == "install"
    assert gs.STATUS_EXIT["drift"] == 1

    # re-install → ok
    gs.install_profile(out, dep)
    assert gs.status(src, root, out, dep)["state"] == "ok"


def test_status_is_content_not_mtime(tmp_path):
    root = _project(tmp_path)
    src = _source(tmp_path)
    out = root / "policy" / "sandbox-profile.d"
    dep = tmp_path / "deployed"
    gs.emit_profile(src, root, out)
    gs.install_profile(out, dep)
    os.utime(out / gs.UNIT_NAME, None)  # touch: T-2290 lesson — must not read as drift
    assert gs.status(src, root, out, dep)["state"] == "ok"


def test_install_refuses_without_emit(tmp_path):
    with pytest.raises(FileNotFoundError, match="emitted artefacts missing"):
        gs.install_profile(tmp_path / "nothing", tmp_path / "deployed")


def test_install_spec_names_every_human_step(tmp_path):
    root = _project(tmp_path)
    r = gs.resolve(gs.load_source(_source(tmp_path)), root)
    spec = gs.emit_install_spec(r, root / "policy" / "sandbox-profile.d", "/etc/aef-sandbox")
    for needle in ("systemd-analyze verify", "nft -c -f", "useradd --system --uid 1999",
                   "sudo fw sandbox install", "sudo nft -f", "systemctl daemon-reload", "fw sandbox status"):
        assert needle in spec, needle


# ------------------------------------------------------------------ host checkers (when present)

@pytest.mark.skipif(shutil.which("systemd-analyze") is None, reason="no systemd-analyze on host")
def test_emitted_unit_passes_systemd_analyze_verify(tmp_path):
    root = _project(tmp_path)
    out = root / "policy" / "sandbox-profile.d"
    gs.emit_profile(_source(tmp_path), root, out)
    p = subprocess.run(["systemd-analyze", "verify", str(out / gs.UNIT_NAME)], capture_output=True, text=True)
    assert p.returncode == 0, p.stderr


@pytest.mark.skipif(shutil.which("nft") is None or os.geteuid() != 0, reason="nft -c needs nft + root")
def test_emitted_nft_passes_syntax_check(tmp_path):
    root = _project(tmp_path)
    out = root / "policy" / "sandbox-profile.d"
    gs.emit_profile(_source(tmp_path), root, out)
    p = subprocess.run(["nft", "-c", "-f", str(out / gs.NFT_NAME)], capture_output=True, text=True)
    assert p.returncode == 0, p.stderr


# ------------------------------------------------------------------ Lock-1 boundary at the verb

def test_fw_sandbox_install_refuses_under_agent(tmp_path):
    """The agent must not install its own cage: bin/fw refuses with exit 3 under
    CLAUDECODE=1 before it even looks at uid or files (Lock-1 Part 1)."""
    env = dict(os.environ, CLAUDECODE="1", AEF_SANDBOX_DEPLOYED=str(tmp_path / "deployed"))
    p = subprocess.run([str(REPO / "bin" / "fw"), "sandbox", "install"], capture_output=True, text=True,
                       env=env, cwd=REPO)
    assert p.returncode == 3, (p.stdout, p.stderr)
    assert "Lock-1 Part 1" in p.stderr
    assert "sudo fw sandbox install" in p.stderr
    assert not (tmp_path / "deployed").exists()


def test_fw_sandbox_status_exit_codes_reach_the_shell(tmp_path):
    """`fw sandbox status` is what audit routes on — the exit code must survive bin/fw."""
    env = dict(os.environ, AEF_SANDBOX_DEPLOYED=str(tmp_path / "nowhere"))
    p = subprocess.run([str(REPO / "bin" / "fw"), "sandbox", "status"], capture_output=True, text=True,
                       env=env, cwd=REPO)
    assert p.returncode == 0, (p.stdout, p.stderr)
    assert "not installed" in p.stdout


# ------------------------------------------------------------------ the repo's own profile

def test_repo_source_resolves_and_matches_emitted():
    """The committed artefacts must be a fresh render of the committed source —
    the stale class caught at test time, not only at doctor time."""
    src = REPO / "policy" / "sandbox-profile.yaml"
    out = REPO / "policy" / "sandbox-profile.d"
    assert src.is_file()
    s = gs.stale_status(src, REPO, out)
    assert s["state"] == "ok", s
