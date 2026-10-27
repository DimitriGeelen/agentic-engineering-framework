#!/usr/bin/env bats
# T-4826 — fw doctor's Watchtower smoke check judged too early right after a restart.
#
# Field report (055 be.37, test H): `fw doctor` run right after `fw watchtower restart`
# reported 1/54 endpoints failed; a minute later 54/54 OK. The /api/_identity warm-up
# wait (T-4363) had passed, but one route still failed its first probe. The smoke test
# now re-probes each failed route once after a short bounded pause and reports only
# routes that fail both times.
#
# The probes go to a real stub HTTP server on a free loopback port; route discovery
# and the warm-up wait are stubbed so web.app is never imported.

setup() {
    FRAMEWORK_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

# $1 = how many times /flaky answers 500 before answering 200.
_run_smoke() {
    run timeout 120 python3 - "$FRAMEWORK_ROOT" "$1" <<'PY'
import json, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, sys.argv[1])
fail_first = int(sys.argv[2])
hits = {}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        hits[self.path] = hits.get(self.path, 0) + 1
        if self.path == "/broken" or (self.path == "/flaky" and hits[self.path] <= fail_first):
            self.send_response(500); self.end_headers(); self.wfile.write(b"boom"); return
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")

srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()

import web.smoke_test as smoke
routes = ["/", "/flaky"] + (["/broken"] if fail_first < 0 else [])
smoke._discover_routes_from_app = lambda: (routes, None)
smoke.wait_for_warmup = lambda base, **kw: {"state": "unknown", "waited": 0}
smoke.CRITICAL_ROUTES = {}
smoke.RETRY_PAUSE_SECONDS = 0.2
r = smoke.run_smoke_tests(base_url="http://127.0.0.1:%d" % srv.server_address[1])
srv.shutdown()
print(json.dumps({"passed": r["passed"], "failed": r["failed"], "total": r["total"],
                  "errors": [e["path"] for e in r["errors"]], "hits": hits}))
PY
}

@test "T-4826: an endpoint that fails only its first probe is not reported" {
    _run_smoke 1
    [ "$status" -eq 0 ]
    [[ "$output" == *'"passed": 2'* ]]
    [[ "$output" == *'"failed": 0'* ]]
    [[ "$output" == *'"/flaky": 2'* ]]
}

@test "T-4826: an endpoint that keeps failing is still reported, after one retry" {
    _run_smoke -1
    [ "$status" -eq 0 ]
    [[ "$output" == *'"failed": 1'* ]]
    [[ "$output" == *'"errors": ["/broken"]'* ]]
    # probed exactly twice: one retry, not a loop
    [[ "$output" == *'"/broken": 2'* ]]
    # a route that passed first time is not re-probed
    [[ "$output" == *'"/": 1'* ]]
}

@test "T-4826: the retry pass is bounded and the bound is stated" {
    src="$FRAMEWORK_ROOT/web/smoke_test.py"
    grep -q '^RETRY_PAUSE_SECONDS = ' "$src"
    grep -q '^RETRY_BUDGET_SECONDS = ' "$src"
}
