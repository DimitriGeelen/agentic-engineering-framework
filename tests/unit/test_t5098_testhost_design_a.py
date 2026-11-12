"""T-5098: design A for fw testhost (T-5009 section 8b) — read-only ISO in, framed serial out.

Covers the framed result block (guest side and controller side), the stub backend on the serial
channel, and the Proxmox backend against a fake API, including one full run in which a fake serial
console runs the REAL guest-run.sh over the ISO's staged contents. No hypervisor is contacted."""
import base64
import gzip
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_testhost_controller import change, env, guest, testhost  # noqa: E402,F401

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))
import testhost_proxmox  # noqa: E402

NONCE = "ab" * 16


def block(doc, nonce=NONCE, raw=None):
    blob = base64.b64encode(raw if raw is not None else
                            gzip.compress(json.dumps(doc).encode(), mtime=0)).decode()
    sha = hashlib.sha256(blob.encode()).hexdigest()
    lines = [f"==TESTHOST-RESULT-BEGIN v1 nonce={nonce} sha256={sha} bytes={len(blob)}=="]
    lines += [blob[i:i + 76] for i in range(0, len(blob), 76)]
    lines.append(f"==TESTHOST-RESULT-END nonce={nonce}==")
    return lines


GOOD = {"result": json.dumps({"version": 1, "status": "passed",
                              "phases": [{"name": "lint", "rc": 0, "seconds": 1}],
                              "started": "2026-11-12T10:00:00Z",
                              "finished": "2026-11-12T10:00:01Z"}),
        "checks_log": "ok 1 lint\n"}


def collect(lines, nonce=NONCE, tmp=None):
    r, w = os.pipe()
    os.write(w, ("\n".join(lines) + "\n").encode())
    os.close(w)
    log = Path(tempfile.mkdtemp()) / "serial.log"
    c = testhost.Collector(os.fdopen(r, "rb", buffering=0), log, 1 << 20, nonce=nonce)
    c.start()
    assert c.join(5)
    return c, log.read_text()


# ── the framed block: controller side ────────────────────────────────────────

def test_block_is_taken_out_of_the_log_and_decodes():
    c, log = collect(["boot", *block(GOOD), "== done =="])
    assert c.frame is not None and c.frame_error == ""
    assert "TESTHOST-RESULT" not in log and "[testhost: result block received]" in log
    reader = testhost.decode_frame(c.frame)
    state, _reason, res = testhost.validate_result(reader)
    assert state == "passed" and res["phases"][0]["name"] == "lint"
    assert (reader / "checks.log").read_text() == "ok 1 lint\n"


def test_wrong_nonce_is_ignored_and_the_last_good_block_wins():
    forged = block({"result": "x", "checks_log": ""}, nonce="cd" * 16)
    c, log = collect([*block(GOOD), *forged])
    assert c.frame is not None
    assert "TESTHOST-RESULT-BEGIN" in log            # a forged block is plain (logged) text
    c2, _ = collect(forged)
    assert c2.frame is None and "nonce" in c2.frame_error


def test_truncated_block_is_detected():
    lines = block(GOOD)[:-1]
    c, _ = collect(lines)
    assert c.frame is None and "truncated" in c.frame_error


def test_interrupted_block_is_detected():
    lines = block(GOOD)
    c, _ = collect([lines[0], lines[1], "PASS all good", *lines[2:]])
    assert c.frame is None


def test_bad_checksum_and_length_are_refused():
    c, _ = collect(block(GOOD))
    sha, n, text = c.frame
    with pytest.raises(testhost.TesthostError, match="sha256"):
        testhost.decode_frame(("0" * 64, n, text))
    with pytest.raises(testhost.TesthostError, match="header says"):
        testhost.decode_frame((sha, n + 1, text))


def test_compression_bomb_is_refused():
    bomb = gzip.compress(b"0" * (testhost.FRAME_MAX_JSON * 4), mtime=0)
    c, _ = collect(block(None, raw=bomb))
    with pytest.raises(testhost.TesthostError, match="expands beyond"):
        testhost.decode_frame(c.frame)


def test_schema_of_the_envelope_is_checked():
    c, _ = collect(block({"result": "{}", "checks_log": "", "extra": 1}))
    with pytest.raises(testhost.TesthostError, match="schema"):
        testhost.decode_frame(c.frame)


# ── guest side and the stub on the serial channel ────────────────────────────

def test_guest_run_emits_a_block_only_with_a_nonce(env, tmp_path):
    sha = change(env, "good", "true")
    inp, out = tmp_path / "in", tmp_path / "out"
    out.mkdir()
    testhost.make_input(sha, "main", inp)
    run = lambda: subprocess.run(["bash", str(ROOT / "agents/testhost/guest-run.sh"), str(inp),
                                  str(out)], cwd=env["repo"], capture_output=True, text=True,
                                 timeout=300)
    assert "TESTHOST-RESULT-BEGIN" not in run().stdout
    (inp / "nonce").write_text(NONCE + "\n")
    p = run()
    assert f"==TESTHOST-RESULT-END nonce={NONCE}==" in p.stdout
    c, _ = collect(p.stdout.splitlines())
    state, _r, _res = testhost.validate_result(testhost.decode_frame(c.frame))
    assert state == "passed"


def test_stub_serial_channel_run_passes_without_reading_the_disk(env):
    env["mp"].setenv("TESTHOST_STUB_CHANNEL", "serial")
    sha = change(env, "good", "true")
    row = testhost.run(commit=sha, base="main", backend_name="stub", timeout=300)
    assert row["state"] == "passed", row["reason"]


def test_stub_serial_channel_with_no_block_is_infra_error(env):
    env["mp"].setenv("TESTHOST_STUB_CHANNEL", "serial")
    guest(env, "silent", "echo hello; exit 0\n")
    sha = change(env, "good", "true")
    row = testhost.run(commit=sha, base="main", backend_name="stub", timeout=60)
    assert row["state"] == "infra-error" and "no result block" in row["reason"]


def test_a_guest_forging_a_block_without_the_nonce_gets_infra_error(env):
    env["mp"].setenv("TESTHOST_STUB_CHANNEL", "serial")
    forged = "\n".join(block(GOOD, nonce="cd" * 16))
    guest(env, "forger", f"cat <<'X'\n{forged}\nX\n")
    sha = change(env, "good", "true")
    row = testhost.run(commit=sha, base="main", backend_name="stub", timeout=60)
    assert row["state"] == "infra-error"


# ── the Proxmox backend against a fake API ───────────────────────────────────

class FakeApi:
    """Just enough Proxmox: nextid, clone, config, start/stop/status, upload, delete, pools."""

    def __init__(self, template=9000, nets=False):
        self.template, self.nets = template, nets
        self.vms, self.isos, self.calls, self.next = {}, {}, [], 200
        self.uploaded = {}

    def _rec(self, *c):
        self.calls.append(c)

    def get(self, path, **p):
        self._rec("GET", path)
        if path == "/cluster/nextid":
            return str(self.next)
        if path.endswith("/status"):
            return {"status": "stopped", "exitstatus": "OK"}
        m = re.search(r"/qemu/(\d+)/(config|status/current)$", path)
        if m:
            vm = self.vms.get(int(m.group(1)))
            if vm is None:
                raise testhost.TesthostError(f"HTTP 500 VM {m.group(1)} does not exist")
            return dict(vm["cfg"]) if m.group(2) == "config" else {"status": vm["status"]}
        if path.startswith("/pools/"):
            return {"members": [{"type": "qemu", "vmid": v} for v in [self.template, *self.vms]]}
        if path.endswith("/content"):
            return [{"volid": v} for v in self.isos]
        raise AssertionError(path)

    def post(self, path, **p):
        self._rec("POST", path, p)
        if path.endswith("/clone"):
            cfg = {"serial0": "socket", "scsi0": "x"}
            if self.nets:
                cfg["net0"] = "virtio,bridge=vmbr0"
            self.vms[int(p["newid"])] = {"cfg": cfg, "status": "stopped", "pool": p["pool"]}
            self.next += 1
            return "UPID:clone"
        m = re.search(r"/qemu/(\d+)/status/(start|stop)$", path)
        if m:
            self.vms[int(m.group(1))]["status"] = "running" if m.group(2) == "start" else "stopped"
            return "UPID:" + m.group(2)
        raise AssertionError(path)

    def put(self, path, **p):
        self._rec("PUT", path, p)
        vmid = int(re.search(r"/qemu/(\d+)/config$", path).group(1))
        self.vms[vmid]["cfg"].update(p)

    def delete(self, path, **p):
        self._rec("DELETE", path, p)
        m = re.search(r"/qemu/(\d+)$", path)
        if m:
            self.vms.pop(int(m.group(1)), None)
            return "UPID:destroy"
        m = re.search(r"/content/(.+)$", path)
        if m:
            from urllib.parse import unquote
            self.isos.pop(unquote(m.group(1)), None)
            return None
        raise AssertionError(path)

    def upload(self, path, name, fh, **p):
        self._rec("UPLOAD", path, name, p)
        volid = f"isos:iso/{name}"
        self.isos[volid] = True
        self.uploaded[name] = fh.read()
        return "UPID:upload"


def cfg(tmp_path, **over):
    ca = tmp_path / "ca.pem"
    ca.write_text("x")
    values = {"TESTHOST_PVE_URL": "https://pve.invalid:8006", "TESTHOST_PVE_NODE": "pve",
              "TESTHOST_PVE_POOL": "aef-pr-test", "TESTHOST_PVE_TEMPLATE": "9000",
              "TESTHOST_PVE_ISO_STORAGE": "isos", "TESTHOST_PVE_CA": str(ca),
              "TESTHOST_PVE_TOKEN_FILE": ""}
    values.update(over)
    return lambda k: values.get(k, "")


def backend(tmp_path, api, **kw):
    staged = {}

    def iso_builder(stage, iso):
        staged["dir"] = tmp_path / f"staged-{len(staged)}"
        import shutil
        shutil.copytree(stage, staged["dir"])
        iso.write_bytes(b"ISO")

    b = testhost_proxmox.ProxmoxBackend(config=cfg(tmp_path, **kw), error=testhost.TesthostError,
                                        api=api, iso_builder=iso_builder,
                                        serial_opener=kw.get("_opener") or (lambda v, s: iter(())),
                                        framework_root=ROOT, project_root=tmp_path)
    return b, staged


def test_unconfigured_and_bad_config_refuse(tmp_path):
    with pytest.raises(testhost.TesthostError, match="missing TESTHOST_PVE_URL"):
        testhost_proxmox.ProxmoxBackend(config=lambda k: "", error=testhost.TesthostError)
    with pytest.raises(testhost.TesthostError, match="https"):
        testhost_proxmox.ProxmoxBackend(config=cfg(tmp_path, TESTHOST_PVE_URL="http://x:8006"),
                                        error=testhost.TesthostError)
    with pytest.raises(testhost.TesthostError, match="token file .* missing"):
        testhost_proxmox.ProxmoxBackend(config=cfg(tmp_path), error=testhost.TesthostError,
                                        project_root=tmp_path)
    tok = tmp_path / ".context/secrets/testhost-pve-token"
    tok.parent.mkdir(parents=True)
    tok.write_text("aef@pve!prtest=0123456789abcdef\n")
    tok.chmod(0o644)
    with pytest.raises(testhost.TesthostError, match="readable by others"):
        testhost_proxmox.ProxmoxBackend(config=cfg(tmp_path), error=testhost.TesthostError,
                                        project_root=tmp_path)


def test_lifecycle_against_the_fake_api(tmp_path):
    api = FakeApi()
    b, staged = backend(tmp_path, api)
    vm = b.clone()
    assert api.vms[int(vm)]["pool"] == "aef-pr-test"
    src = tmp_path / "in"
    src.mkdir()
    (src / "pr.bundle").write_bytes(b"bundle")
    (src / "nonce").write_text(NONCE)
    b.attach_input(vm, src)
    assert sorted(p.name for p in staged["dir"].iterdir()) == \
        ["guest-run.sh", "nonce", "pr-checks.sh", "pr.bundle"]
    assert (staged["dir"] / "guest-run.sh").read_bytes() == \
        (ROOT / "agents/testhost/guest-run.sh").read_bytes()       # our copy, not the PR's
    assert api.vms[int(vm)]["cfg"]["ide2"] == f"isos:iso/aef-pr-{vm}.iso,media=cdrom"
    b.attach_output(vm)
    b.start(vm)
    assert b.state(vm) == "running"
    assert b.list_pool() == [f"iso isos:iso/aef-pr-{vm}.iso", f"vm {vm}"]
    b.destroy(vm)
    assert b.state(vm) == "absent" and b.list_pool() == [] and not api.isos


def test_a_clone_with_a_network_device_is_destroyed_and_refused(tmp_path):
    api = FakeApi(nets=True)
    b, _ = backend(tmp_path, api)
    with pytest.raises(testhost.TesthostError, match="network device"):
        b.clone()
    assert api.vms == {}


def test_the_template_itself_is_never_a_vm_id(tmp_path):
    b, _ = backend(tmp_path, FakeApi())
    with pytest.raises(testhost.TesthostError, match="bad vm id"):
        b.destroy("9000")


def test_full_run_design_a_with_the_real_guest_script(env, tmp_path):
    """controller -> ProxmoxBackend(fake API) -> 'serial console' that runs the real
    guest-run.sh over the ISO's staged contents; result only through the framed block."""
    api = FakeApi()
    holder = {}

    def opener(vmid, stop):
        out = tmp_path / f"scratch-{vmid}"
        out.mkdir()
        p = subprocess.Popen(["bash", str(holder["staged"]["dir"] / "guest-run.sh"),
                              str(holder["staged"]["dir"]), str(out)], cwd=str(tmp_path),
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for chunk in iter(lambda: p.stdout.read(4096), b""):
            yield chunk
        p.wait()
        api.vms[vmid]["status"] = "stopped"            # the guest powers off

    b, staged = backend(tmp_path, api, _opener=opener)
    holder["staged"] = staged
    sha = change(env, "good", "true")
    row = testhost.run(commit=sha, base="main", backend=b, timeout=300)
    assert row["state"] == "passed", row["reason"]
    assert row["backend"] == "proxmox" and api.vms == {} and not api.isos
    sha2 = change(env, "bad", "false")
    row2 = testhost.run(commit=sha2, base="main", backend=b, timeout=300)
    assert row2["state"] == "failed", row2["reason"]
