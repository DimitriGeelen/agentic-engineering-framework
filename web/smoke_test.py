"""Watchtower smoke test — runtime route discovery + content validation.

Auto-discovers all routes via Flask's url_map, tests each for HTTP 200,
and validates content markers on critical pages. Can run standalone or
be called from fw doctor / fw audit.

T-486: Built from T-485 inception (69 endpoints, hybrid approach).

Usage:
    python3 web/smoke_test.py                    # test against running server
    python3 web/smoke_test.py --port 5050        # custom port
    python3 web/smoke_test.py --test-client       # use Flask test client (no server needed)
    python3 -c "from web.smoke_test import run_smoke_tests; print(run_smoke_tests())"
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
import urllib.error

# Content markers for critical routes — if the page loads but these are missing,
# something is broken (wrong template, missing data, import error).
CRITICAL_ROUTES: dict[str, list[str]] = {
    "/": ["Watchtower"],
    "/tasks": ["Tasks"],
    "/search": ["Search"],
    "/fabric": ["Component Fabric"],
    "/quality": ["Quality"],
    "/settings/": ["Settings"],
    "/directives": ["Directives"],
    "/enforcement": ["Enforcement"],
    "/metrics": ["Metrics"],
    "/health": ['"app"'],
}

# Routes to skip (require path params, POST-only, or streaming)
SKIP_PREFIXES = ("/api/", "/static/", "/search/ask", "/api/v1/ask/stream")


def _discover_routes_from_app():
    """Discover all GET routes from Flask url_map (no running server needed)."""
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from web.app import app

    routes = []
    for rule in app.url_map.iter_rules():
        if "GET" not in rule.methods:
            continue
        path = rule.rule
        # Skip static, parameterized, and excluded routes
        if "<" in path:
            continue
        if any(path.startswith(p) for p in SKIP_PREFIXES):
            continue
        if path == "/static":
            continue
        routes.append(path)
    return sorted(set(routes)), app


def run_smoke_tests(port: int = 3000, use_test_client: bool = False) -> dict:
    """Run smoke tests against Watchtower.

    Args:
        port: Port number for HTTP tests against running server.
        use_test_client: If True, use Flask test client (no server needed).

    Returns:
        dict with keys: passed, failed, skipped, total, errors, results
    """
    routes, app = _discover_routes_from_app()

    results = []
    passed = 0
    failed = 0
    skipped = 0

    if use_test_client:
        app.config["TESTING"] = True
        app.config["SECRET_KEY"] = "smoke-test-key"
        client = app.test_client()

        for path in routes:
            try:
                resp = client.get(path)
                status = resp.status_code
                body = resp.data.decode("utf-8", errors="replace")
            except Exception as e:
                results.append({"path": path, "status": "error", "error": str(e)})
                failed += 1
                continue

            # Check status
            if status >= 500:
                results.append({"path": path, "status": status, "error": f"HTTP {status}"})
                failed += 1
                continue

            # Check content markers for critical routes
            markers = CRITICAL_ROUTES.get(path, [])
            missing = [m for m in markers if m not in body]
            if missing:
                results.append({
                    "path": path, "status": status,
                    "error": f"Missing content: {missing}"
                })
                failed += 1
            else:
                results.append({"path": path, "status": status, "ok": True})
                passed += 1

    else:
        # HTTP mode — test against running server
        base = f"http://localhost:{port}"

        for path in routes:
            url = f"{base}{path}"
            try:
                req = urllib.request.Request(url, method="GET")
                with urllib.request.urlopen(req, timeout=5) as resp:
                    status = resp.status
                    body = resp.read().decode("utf-8", errors="replace")
            except urllib.error.HTTPError as e:
                status = e.code
                body = ""
            except Exception as e:
                results.append({"path": path, "status": "error", "error": str(e)})
                failed += 1
                continue

            if status >= 500:
                results.append({"path": path, "status": status, "error": f"HTTP {status}"})
                failed += 1
                continue

            markers = CRITICAL_ROUTES.get(path, [])
            missing = [m for m in markers if m not in body]
            if missing:
                results.append({
                    "path": path, "status": status,
                    "error": f"Missing content: {missing}"
                })
                failed += 1
            else:
                results.append({"path": path, "status": status, "ok": True})
                passed += 1

    return {
        "passed": passed,
        "failed": failed,
        "total": len(routes),
        "errors": [r for r in results if "error" in r],
        "results": results,
    }


def print_report(report: dict) -> int:
    """Print human-readable smoke test report. Returns exit code."""
    total = report["total"]
    passed = report["passed"]
    failed = report["failed"]

    print(f"\nWatchtower Smoke Test: {passed}/{total} passed", end="")
    if failed:
        print(f", {failed} FAILED")
    else:
        print(" — all OK")

    if report["errors"]:
        print("\nFailures:")
        for err in report["errors"]:
            print(f"  {err['path']}: {err.get('error', err.get('status', '?'))}")

    print()
    return 1 if failed else 0


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Watchtower smoke test")
    parser.add_argument("--port", type=int, default=int(os.environ.get("FW_PORT", 3000)))
    parser.add_argument("--test-client", action="store_true",
                        help="Use Flask test client (no running server needed)")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    args = parser.parse_args()

    report = run_smoke_tests(port=args.port, use_test_client=args.test_client)

    if args.json:
        print(json.dumps(report, indent=2))
        sys.exit(1 if report["failed"] else 0)
    else:
        sys.exit(print_report(report))
