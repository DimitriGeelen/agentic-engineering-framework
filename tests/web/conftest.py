"""Make the framework root importable so `from web.app import ...` works."""

import importlib
import os
import sys
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
if str(FRAMEWORK_ROOT) not in sys.path:
    sys.path.insert(0, str(FRAMEWORK_ROOT))
sys.path.insert(0, str(FRAMEWORK_ROOT / "tests" / "lib"))
import module_identity  # noqa: E402  (T-4616)


@pytest.fixture(autouse=True)
def _restore_web_shared_root():
    """OBS-094 / T-2580: several files (test_build_ambient, test_fabric_loader,
    test_load_latest_audit, test_secret_key, test_project_root_discovery)
    reload or pop web.shared under a tmp PROJECT_ROOT to exercise the
    module-level resolution. monkeypatch restores the env var at teardown but
    NOT the module constant — web.shared.PROJECT_ROOT then points at a deleted
    tmp dir for every later file, and any test that builds paths from it
    (the inception render tests build template_folder from it) fails with
    TemplateNotFound. Repair here: after each test, if the constant drifted
    from what the restored env resolves to, reload web.shared in place.
    In-place reload keeps module identity, so fixtures elsewhere that bound
    the module object (monkeypatch.setattr targets) stay coherent.
    """
    env_before = os.environ.get("PROJECT_ROOT")
    modules_before = module_identity.snapshot(("web",))
    yield
    # T-4616: a test that popped web.shared / web.app / web.blueprints.fabric and
    # reimported leaves NEW module objects behind; later tests patch those while
    # the blueprints still read the originals. Put the originals back first, so
    # the PROJECT_ROOT check below inspects the module the app actually uses.
    module_identity.restore(modules_before, ("web",))
    if env_before is None:
        os.environ.pop("PROJECT_ROOT", None)
    else:
        os.environ["PROJECT_ROOT"] = env_before
    shared = sys.modules.get("web.shared")
    if shared is None:
        return
    expected = Path(env_before) if env_before else FRAMEWORK_ROOT
    if getattr(shared, "PROJECT_ROOT", None) == expected:
        return
    config = sys.modules.get("web.config")
    if config is not None:
        importlib.reload(config)
    importlib.reload(shared)
