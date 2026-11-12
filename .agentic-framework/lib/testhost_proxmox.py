#!/usr/bin/env python3
"""Proxmox API backend for `fw testhost` (T-5098; design: docs/reports/T-5009-isolated-test-host-
design.md, section 8b, "design A").

One run = a linked clone of the template into the test pool, a read-only ISO (the PR's git bundle,
the run's nonce, and guest-run.sh / pr-checks.sh from THIS framework copy, never from the PR),
start, the serial console read through the API (termproxy + vncwebsocket), stop, destroy the VM
and delete the ISO. The result comes back as the framed block on the serial line
(result_channel = "serial"); there is no output disk and nothing the guest wrote is mounted.

Configuration (env FW_<KEY> > .framework.yaml), every key required, nothing guessed:
  TESTHOST_PVE_URL          https://<node>:8006
  TESTHOST_PVE_NODE         node name as Proxmox knows it
  TESTHOST_PVE_POOL         the pool the token is limited to
  TESTHOST_PVE_TEMPLATE     VMID of the template (no network device, serial0 present)
  TESTHOST_PVE_ISO_STORAGE  storage that holds ISO images
  TESTHOST_PVE_CA           CA file the node's TLS certificate is checked against
  TESTHOST_PVE_VMID_RANGE   e.g. 9501-9509: the only VMIDs a clone may get, and the only ones any
                            operation accepts (ring20 review 2026-11-12; T-5099)
  TESTHOST_PVE_TOKEN_FILE   default .context/secrets/testhost-pve-token, one line
                            "user@realm!tokenid=secret", mode 0600 (refused when group/world
                            readable). The token never goes into .framework.yaml or a VM.
"""
import os
import re
import shutil
import subprocess
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import quote, urlparse

KEYS = ("TESTHOST_PVE_URL", "TESTHOST_PVE_NODE", "TESTHOST_PVE_POOL", "TESTHOST_PVE_TEMPLATE",
        "TESTHOST_PVE_ISO_STORAGE", "TESTHOST_PVE_CA", "TESTHOST_PVE_VMID_RANGE")
DEFAULT_TOKEN_FILE = ".context/secrets/testhost-pve-token"
TASK_TIMEOUT = 300
_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,62}")
_TOKEN = re.compile(r"[A-Za-z0-9._@-]+![A-Za-z0-9._-]+=[0-9a-fA-F-]{8,64}")


class _Api:
    """Minimal Proxmox REST client: token auth, TLS checked against the configured CA."""

    def __init__(self, url, token, ca, error):
        import requests
        self.url, self.error = url.rstrip("/"), error
        self.s = requests.Session()
        self.s.headers["Authorization"] = f"PVEAPIToken={token}"
        self.s.verify = ca

    def _call(self, method, path, files=None, **params):
        r = self.s.request(method, self.url + "/api2/json" + path, timeout=60,
                           data=params if method in ("POST", "PUT") else None,
                           params=None if method in ("POST", "PUT") else params, files=files)
        if r.status_code >= 400:
            raise self.error(f"proxmox {method} {path}: HTTP {r.status_code} {r.text[:200]}")
        return (r.json() or {}).get("data")

    def get(self, path, **p): return self._call("GET", path, **p)
    def post(self, path, **p): return self._call("POST", path, **p)
    def put(self, path, **p): return self._call("PUT", path, **p)
    def delete(self, path, **p): return self._call("DELETE", path, **p)

    def upload(self, path, name, fileobj, **p):
        return self._call("POST", path, files={"filename": (name, fileobj)}, **p)


def build_iso(src_dir: Path, iso_path: Path):
    tool = shutil.which("genisoimage") or shutil.which("mkisofs")
    if tool:
        cmd = [tool, "-quiet", "-r", "-J", "-V", "AEFRUN", "-o", str(iso_path), str(src_dir)]
    elif shutil.which("xorriso"):
        cmd = ["xorriso", "-as", "mkisofs", "-quiet", "-r", "-J", "-V", "AEFRUN", "-o",
               str(iso_path), str(src_dir)]
    else:
        raise RuntimeError("no ISO tool (genisoimage, mkisofs or xorriso) on the controller")
    subprocess.run(cmd, check=True, capture_output=True, timeout=120)


class ProxmoxBackend:
    name = "proxmox"
    result_channel = "serial"

    def __init__(self, config, error, api=None, iso_builder=None, serial_opener=None,
                 framework_root=None, project_root=None):
        self.error = error
        cfg = {k: (config(k) or "").strip() for k in KEYS}
        missing = [k for k, v in cfg.items() if not v]
        root = Path(project_root or os.environ.get("PROJECT_ROOT") or os.getcwd())
        token_file = Path(config("TESTHOST_PVE_TOKEN_FILE") or DEFAULT_TOKEN_FILE)
        if not token_file.is_absolute():
            token_file = root / token_file
        if missing:
            raise error("backend 'proxmox' is not configured: missing " + ", ".join(missing)
                        + " (the operator's T-5099 runmes set them); use --backend stub meanwhile")
        if not cfg["TESTHOST_PVE_TEMPLATE"].isdigit():
            raise error("TESTHOST_PVE_TEMPLATE must be a VMID")
        m = re.fullmatch(r"(\d{3,9})-(\d{3,9})", cfg["TESTHOST_PVE_VMID_RANGE"])
        if not m or int(m.group(1)) > int(m.group(2)) or int(m.group(2)) - int(m.group(1)) > 99:
            raise error("TESTHOST_PVE_VMID_RANGE must be LOW-HIGH, at most 100 ids (e.g. 9501-9509)")
        lo, hi = int(m.group(1)), int(m.group(2))
        if lo <= int(cfg["TESTHOST_PVE_TEMPLATE"]) <= hi:
            raise error("the template's VMID must lie outside TESTHOST_PVE_VMID_RANGE")
        for k in ("TESTHOST_PVE_NODE", "TESTHOST_PVE_POOL", "TESTHOST_PVE_ISO_STORAGE"):
            if not _NAME.fullmatch(cfg[k]):
                raise error(f"{k} has characters a Proxmox name does not")
        if urlparse(cfg["TESTHOST_PVE_URL"]).scheme != "https":
            raise error("TESTHOST_PVE_URL must be https")
        if not Path(cfg["TESTHOST_PVE_CA"]).is_file():
            raise error(f"TESTHOST_PVE_CA {cfg['TESTHOST_PVE_CA']} is not a file")
        if api is None:
            try:
                st = token_file.stat()
            except OSError:
                raise error(f"token file {token_file} is missing (T-5099)")
            if st.st_mode & 0o077:
                raise error(f"token file {token_file} is readable by others; chmod 600 it")
            token = token_file.read_text().strip()
            if not _TOKEN.fullmatch(token):
                raise error(f"token file {token_file} does not hold user@realm!id=secret")
            api = _Api(cfg["TESTHOST_PVE_URL"], token, cfg["TESTHOST_PVE_CA"], error)
            self._token = token
        else:
            self._token = "fake!fake=00000000"
        self.api, self.cfg = api, cfg
        self.node, self.pool = cfg["TESTHOST_PVE_NODE"], cfg["TESTHOST_PVE_POOL"]
        self.template, self.iso_storage = int(cfg["TESTHOST_PVE_TEMPLATE"]), cfg["TESTHOST_PVE_ISO_STORAGE"]
        self.vmid_range = range(lo, hi + 1)
        self.iso_builder = iso_builder or build_iso
        self.serial_opener = serial_opener or self._termproxy_chunks
        self.fw_root = Path(framework_root or os.environ.get("FRAMEWORK_ROOT")
                            or Path(__file__).resolve().parent.parent)
        self.isos, self.readers, self.stops = {}, {}, {}

    # ── helpers ──────────────────────────────────────────────────────────────

    def _vm(self, vm_id) -> int:
        if (not re.fullmatch(r"\d{3,9}", str(vm_id)) or int(vm_id) == self.template
                or int(vm_id) not in self.vmid_range):
            raise self.error(f"bad vm id {vm_id!r} (outside {self.vmid_range.start}-"
                             f"{self.vmid_range.stop - 1})")
        return int(vm_id)

    def _q(self, vmid) -> str:
        return f"/nodes/{self.node}/qemu/{vmid}"

    def _wait(self, upid):
        if not upid:
            return
        deadline = time.monotonic() + TASK_TIMEOUT
        while time.monotonic() < deadline:
            st = self.api.get(f"/nodes/{self.node}/tasks/{quote(str(upid), safe='')}/status") or {}
            if st.get("status") == "stopped":
                if st.get("exitstatus") != "OK":
                    raise self.error(f"proxmox task failed: {str(st.get('exitstatus'))[:200]}")
                return
            time.sleep(1)
        raise self.error(f"proxmox task did not finish within {TASK_TIMEOUT}s")

    # ── backend interface ────────────────────────────────────────────────────

    def clone(self) -> str:
        """Clone into the first free VMID of the configured block (never /cluster/nextid)."""
        pool = self.api.get(f"/pools/{self.pool}") or {}
        taken = {m.get("vmid") for m in pool.get("members", [])}
        vmid = None
        for cand in self.vmid_range:
            if cand in taken:
                continue
            try:
                self._wait(self.api.post(f"{self._q(self.template)}/clone", newid=cand,
                                         name=f"aef-pr-{cand}", pool=self.pool, full=0))
            except Exception as e:  # noqa: BLE001
                if "already exists" in str(e):
                    continue
                raise
            vmid = cand
            break
        if vmid is None:
            raise self.error(f"no free VMID in {self.vmid_range.start}-{self.vmid_range.stop - 1}; "
                             "fw testhost list / clean the pool")
        cfg = self.api.get(f"{self._q(vmid)}/config") or {}
        nets = sorted(k for k in cfg if re.fullmatch(r"net\d+", k))
        if nets or "serial0" not in cfg:
            why = (f"has network device(s) {', '.join(nets)}" if nets else "has no serial0")
            self.destroy(str(vmid))
            raise self.error(f"clone of template {self.template} {why}; refused (fix the template)")
        return str(vmid)

    def attach_input(self, vm_id, src_dir):
        vmid = self._vm(vm_id)
        stage = Path(tempfile.mkdtemp(prefix="fw-testhost-iso-"))
        try:
            for f in Path(src_dir).iterdir():
                if f.is_file() and not f.is_symlink():
                    shutil.copy2(f, stage / f.name)
            for name in ("guest-run.sh", "pr-checks.sh"):     # this copy's, never the PR's
                shutil.copy2(self.fw_root / "agents" / "testhost" / name, stage / name)
            iso_name = f"aef-pr-{vmid}.iso"
            iso = stage.parent / f"{stage.name}.iso"
            self.iso_builder(stage, iso)
            with open(iso, "rb") as fh:
                self._wait(self.api.upload(f"/nodes/{self.node}/storage/{self.iso_storage}/upload",
                                           iso_name, fh, content="iso"))
            volid = f"{self.iso_storage}:iso/{iso_name}"
            self.isos[vm_id] = volid
            self.api.put(f"{self._q(vmid)}/config", ide2=f"{volid},media=cdrom")
        finally:
            shutil.rmtree(stage, ignore_errors=True)
            try:
                os.unlink(stage.parent / f"{stage.name}.iso")
            except OSError:
                pass

    def attach_output(self, vm_id):
        """Design A: no output disk; the guest uses its own scratch space."""

    def start(self, vm_id):
        self._wait(self.api.post(f"{self._q(self._vm(vm_id))}/status/start"))

    def state(self, vm_id) -> str:
        try:
            st = self.api.get(f"{self._q(self._vm(vm_id))}/status/current") or {}
        except Exception as e:  # noqa: BLE001
            if "does not exist" in str(e) or "HTTP 404" in str(e) or "HTTP 500" in str(e):
                return "absent"
            raise
        return "running" if st.get("status") == "running" else "stopped"

    def serial(self, vm_id):
        """A readable pipe fed by a thread from the serial console (the Collector reads its fd)."""
        vmid = self._vm(vm_id)
        r, w = os.pipe()
        stop = threading.Event()
        self.stops[vm_id] = stop

        def pump():
            try:
                for chunk in self.serial_opener(vmid, stop):
                    os.write(w, chunk)
            except Exception as e:  # noqa: BLE001 — a dropped console shows in the log
                try:
                    os.write(w, f"\n[testhost: serial console closed: {type(e).__name__}]\n".encode())
                except OSError:
                    pass
            finally:
                os.close(w)

        t = threading.Thread(target=pump, daemon=True)
        t.start()
        self.readers[vm_id] = t
        return os.fdopen(r, "rb", buffering=0)

    def _termproxy_chunks(self, vmid, stop):
        import ssl
        import websocket
        tp = self.api.post(f"{self._q(vmid)}/termproxy", serial="serial0") or {}
        port, ticket, user = tp.get("port"), tp.get("ticket"), tp.get("user")
        u = urlparse(self.cfg["TESTHOST_PVE_URL"])
        url = (f"wss://{u.netloc}/api2/json{self._q(vmid)}/vncwebsocket"
               f"?port={quote(str(port))}&vncticket={quote(str(ticket), safe='')}")
        ws = websocket.create_connection(
            url, header=[f"Authorization: PVEAPIToken={self._token}"], timeout=10,
            sslopt={"cert_reqs": ssl.CERT_REQUIRED, "ca_certs": self.cfg["TESTHOST_PVE_CA"]})
        try:
            ws.send(f"{user}:{ticket}\n")
            first = True
            last_ping = time.monotonic()
            while not stop.is_set():
                if time.monotonic() - last_ping > 25:
                    ws.send("2")                 # termproxy keepalive
                    last_ping = time.monotonic()
                try:
                    data = ws.recv()
                except websocket.WebSocketTimeoutException:
                    continue
                except websocket.WebSocketConnectionClosedException:
                    return
                if isinstance(data, str):
                    data = data.encode("utf-8", errors="replace")
                if first and data[:2] == b"OK":
                    data, first = data[2:], False
                if data:
                    yield data
        finally:
            ws.close()

    def stop(self, vm_id):
        vmid = self._vm(vm_id)
        if self.state(vm_id) == "running":
            self._wait(self.api.post(f"{self._q(vmid)}/status/stop"))

    def read_output(self, vm_id):
        raise self.error("proxmox backend has no output disk; the result comes over serial")

    def destroy(self, vm_id):
        errors = []
        ev = self.stops.pop(vm_id, None)
        if ev:
            ev.set()
        try:
            vmid = self._vm(vm_id)
            if self.state(vm_id) != "absent":
                if self.state(vm_id) == "running":
                    self._wait(self.api.post(f"{self._q(vmid)}/status/stop"))
                self._wait(self.api.delete(self._q(vmid), purge=1,
                                           **{"destroy-unreferenced-disks": 1}))
        except Exception as e:  # noqa: BLE001
            errors.append(f"vm: {e}")
        volid = self.isos.pop(vm_id, None)
        if volid:
            try:
                self._wait(self.api.delete(f"/nodes/{self.node}/storage/{self.iso_storage}"
                                           f"/content/{quote(volid, safe='')}"))
            except Exception as e:  # noqa: BLE001
                errors.append(f"iso: {e}")
        t = self.readers.pop(vm_id, None)
        if t:
            t.join(timeout=5)
        if errors:
            raise self.error("; ".join(errors)[:300])

    # ── T-5099: what the token may do, and nothing more ─────────────────────

    def required_privileges(self, disk_storage):
        return {
            f"/pool/{self.pool}": {"VM.Allocate", "VM.Config.CDROM", "VM.Config.Disk",
                                   "VM.Config.Options", "VM.PowerMgmt", "VM.Console",
                                   "VM.Audit", "Pool.Audit"},
            f"/vms/{self.template}": {"VM.Clone", "VM.Audit"},
            f"/storage/{self.iso_storage}": {"Datastore.AllocateTemplate", "Datastore.Audit"},
            f"/storage/{disk_storage}": {"Datastore.AllocateSpace"},
        }

    def check_token(self, disk_storage):
        """-> (ok, lines). Reads the token's effective permissions (GET /access/permissions) and
        fails on any privilege outside the pool, its member VMs, the template VM and the two
        storages, and on any required privilege that is missing."""
        if not disk_storage or not _NAME.fullmatch(disk_storage):
            raise self.error("TESTHOST_PVE_DISK_STORAGE is not set (the storage clones' disks use)")
        need = self.required_privileges(disk_storage)
        perms = self.api.get("/access/permissions") or {}
        pool = self.api.get(f"/pools/{self.pool}") or {}
        members = {f"/vms/{m.get('vmid')}" for m in pool.get("members", [])
                   if m.get("type") == "qemu"}
        ok, lines = True, []
        for path in sorted(perms):
            privs = sorted(k for k, v in (perms[path] or {}).items() if v)
            if not privs:
                continue
            if path in need or path in members:
                continue
            ok = False
            lines.append(f"FAIL  privileges outside the test pool: {path}: {', '.join(privs)}")
        for path, want in sorted(need.items()):
            have = {k for k, v in (perms.get(path) or {}).items() if v}
            missing = sorted(want - have)
            if missing:
                ok = False
                lines.append(f"FAIL  missing on {path}: {', '.join(missing)}")
            else:
                lines.append(f"OK    {path}: {', '.join(sorted(want))}")
        return ok, lines

    def list_pool(self):
        pool = self.api.get(f"/pools/{self.pool}") or {}
        out = [f"vm {m.get('vmid')}" for m in pool.get("members", [])
               if m.get("type") == "qemu" and m.get("vmid") != self.template]
        content = self.api.get(f"/nodes/{self.node}/storage/{self.iso_storage}/content",
                               content="iso") or []
        out += [f"iso {c.get('volid')}" for c in content
                if re.search(r"/aef-pr-\d+\.iso$", str(c.get("volid", "")))]
        return sorted(out)
