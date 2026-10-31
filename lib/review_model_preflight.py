#!/usr/bin/env python3
"""Pinned-model preflight for review backends: `python3 lib/review_model_preflight.py [--json]`.

T-4506. policy/review-backends.yaml pinned the opencode seat to `zai-coding-plan/glm-5.2`
after Z.AI retired it. opencode launched the retired name and the provider answered with a
generic `UnknownError: Unexpected server error`, which T-4457 read as provider-side. Nothing
compared the pin with what the harness can actually serve.

For each registry backend run by opencode (worker_kind or binary basename `opencode`) whose
`model:` is `<provider>/<name>`, this lists `opencode models <provider>` and reports:

    ok         the pinned model is listed
    retired    the listing succeeded and the pin is not in it (names the listed models)
    unchecked  the listing failed or timed out (network, auth, unknown provider) — never
               reported as retired, so a flaky listing cannot take a seat down
    skipped    opencode is not installed here

Read by `fw doctor` (WARN on retired) and `fw reviewer judge` (a retired-pin kind is not
dispatched for that run). Exit: 0 when nothing is retired, 1 when something is, 2 when the
registry cannot be read.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable

#: opencode lists from a local cache plus a provider refresh: ~7 s measured (2026-10-22).
LIST_TIMEOUT = 60

#: (binary, provider) -> (returncode, stdout). Injectable for tests.
Lister = Callable[[str, str], tuple[int, str]]


def _list_models(binary: str, provider: str) -> tuple[int, str]:
    try:
        p = subprocess.run([binary, "models", provider], capture_output=True, text=True,
                           stdin=subprocess.DEVNULL, timeout=LIST_TIMEOUT)
    except subprocess.TimeoutExpired:
        return 124, ""
    except OSError as e:
        return 127, str(e)
    return p.returncode, p.stdout


def _is_opencode(b: dict) -> bool:
    return b.get("worker_kind") == "opencode" or os.path.basename(str(b.get("binary") or "")) == "opencode"


def _binary(b: dict) -> str:
    reg = str(b.get("binary") or "")
    if reg and os.path.isfile(reg) and os.access(reg, os.X_OK):
        return reg
    return shutil.which("opencode") or ""


def _loaded_registry() -> str:
    """T-4913: the absolute path of the registry actually loaded. A bare
    'policy/review-backends.yaml' read as the vendored file to a project whose own copy
    held the stale pin (dimitri-mint-dev, 2026-10-29)."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        import review_cost as rc_
        return str(rc_.policy_path().resolve())
    except Exception:  # noqa: BLE001 — a message helper must never fail the check
        return "policy/review-backends.yaml"


def check(backends: list[dict], lister: Lister | None = None,
          which: Callable[[dict], str] | None = None) -> list[dict]:
    """One result per opencode-backed registry entry that pins a `<provider>/<name>` model."""
    lister = lister or _list_models
    which = which or _binary
    cache: dict[tuple[str, str], tuple[int, str]] = {}
    out: list[dict] = []
    for b in backends:
        model = str(b.get("model") or "")
        if not _is_opencode(b) or "/" not in model:
            continue
        r = {"backend": b.get("id", ""), "kind": b.get("worker_kind", ""), "model": model}
        binary = which(b)
        if not binary:
            out.append({**r, "status": "skipped", "detail": "opencode not installed"})
            continue
        provider = model.split("/", 1)[0]
        key = (binary, provider)
        if key not in cache:
            cache[key] = lister(binary, provider)
        rc, text = cache[key]
        listed = [ln.strip() for ln in text.splitlines() if ln.strip().startswith(provider + "/")]
        if rc != 0 or not listed:
            out.append({**r, "status": "unchecked",
                        "detail": f"`opencode models {provider}` exited {rc} with no model list"})
        elif model in listed:
            out.append({**r, "status": "ok", "detail": ""})
        else:
            out.append({**r, "status": "retired", "listed": listed,
                        "detail": f"{model} is not in `opencode models {provider}` "
                                  f"(listed: {', '.join(listed)}) — re-pin it in "
                                  f"{_loaded_registry()}"})
    return out


def retired_kinds(results: list[dict]) -> dict[str, str]:
    """{worker kind: reason} for every retired pin."""
    return {r["kind"]: r["detail"] for r in results if r["status"] == "retired" and r["kind"]}


def main(argv: list[str]) -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import review_cost as rc_  # sibling module: the registry's only parser
    try:
        results = check(rc_.load_registry())
    except rc_.CostError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    if "--json" in argv:
        print(json.dumps(results, indent=2))
    else:
        for r in results:
            label = {"ok": "OK", "retired": "RETIRED", "unchecked": "UNCHECKED",
                     "skipped": "SKIPPED"}[r["status"]]
            print(f"{label} {r['backend']} {r['model']}" + (f" — {r['detail']}" if r["detail"] else ""))
    return 1 if any(r["status"] == "retired" for r in results) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
