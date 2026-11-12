"""T-5099: the Proxmox token's reach is checked before any run, and the template's in-guest files
are in the repo. Fake API only; no hypervisor is contacted."""
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_t5098_testhost_design_a import FakeApi, backend  # noqa: E402
from test_testhost_controller import testhost  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TPL = ROOT / "agents" / "testhost" / "template"

GOOD = {
    "/pool/aef-pr-test": {p: 1 for p in ("VM.Allocate", "VM.Config.CDROM", "VM.Config.Disk",
                                          "VM.Config.Options", "VM.PowerMgmt", "VM.Console",
                                          "VM.Audit", "Pool.Audit")},
    "/vms/9000": {"VM.Clone": 1, "VM.Audit": 1},
    "/storage/isos": {"Datastore.AllocateTemplate": 1, "Datastore.Audit": 1},
    "/storage/vmdisks": {"Datastore.AllocateSpace": 1},
}


class PermApi(FakeApi):
    def __init__(self, perms):
        super().__init__()
        self.perms = perms

    def get(self, path, **p):
        if path == "/access/permissions":
            return self.perms
        return super().get(path, **p)


def check(tmp_path, perms):
    b, _ = backend(tmp_path, PermApi(perms))
    return b.check_token("vmdisks")


def test_exact_scope_passes(tmp_path):
    ok, lines = check(tmp_path, GOOD)
    assert ok, lines
    assert all(line.startswith("OK") for line in lines)


def test_a_privilege_anywhere_else_fails(tmp_path):
    for extra in ({"/": {"Sys.Audit": 1}}, {"/vms/101": {"VM.Audit": 1}},
                  {"/storage/local": {"Datastore.Audit": 1}}, {"/nodes/pve": {"Sys.Console": 1}}):
        ok, lines = check(tmp_path, {**GOOD, **extra})
        assert not ok and any("outside the test pool" in line for line in lines), extra


def test_a_pool_member_vm_is_inside_the_scope(tmp_path):
    api = PermApi({**GOOD, "/vms/200": {"VM.Audit": 1}})
    b, _ = backend(tmp_path, api)
    b.clone()                                   # 200 joins the pool
    ok, lines = b.check_token("vmdisks")
    assert ok, lines


def test_a_missing_privilege_fails(tmp_path):
    perms = {k: dict(v) for k, v in GOOD.items()}
    del perms["/pool/aef-pr-test"]["VM.Console"]
    ok, lines = check(tmp_path, perms)
    assert not ok and any("missing on /pool/aef-pr-test: VM.Console" in line for line in lines)


def test_disk_storage_must_be_named(tmp_path):
    b, _ = backend(tmp_path, PermApi(GOOD))
    with pytest.raises(testhost.TesthostError, match="DISK_STORAGE"):
        b.check_token("")


def test_cli_without_configuration_refuses(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    p = subprocess.run([sys.executable, str(ROOT / "lib/testhost.py"), "check-token"],
                       capture_output=True, text=True)
    assert p.returncode == 2 and "not configured" in p.stderr


def test_template_files_exist_and_parse():
    assert (TPL / "packages.txt").is_file()
    assert "bats-core:" in (TPL / "packages.txt").read_text()
    assert subprocess.run(["bash", "-n", str(TPL / "aef-testhost-boot.sh")]).returncode == 0
    svc = (TPL / "aef-testhost.service").read_text()
    assert "TTYPath=/dev/ttyS0" in svc and "ExecStart=/usr/local/sbin/aef-testhost-boot.sh" in svc


def test_boot_script_keeps_the_input_root_only_and_runs_our_copy():
    s = (TPL / "aef-testhost-boot.sh").read_text()
    assert "install -d -m 0700 /root/aefrun" in s
    assert "umount" in s and "mount -o ro,nosuid,nodev,noexec" in s
    assert "bash /root/aefrun/guest-run.sh /root/aefrun" in s
    assert "systemctl poweroff" in s
