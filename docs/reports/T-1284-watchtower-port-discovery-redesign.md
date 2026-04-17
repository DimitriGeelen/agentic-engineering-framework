# T-1284: Watchtower Port Discovery Redesign — Research Artifact

## Problem Statement

`_watchtower_url` in `lib/watchtower.sh` returned `http://192.168.10.107:8080` 
when asked for T-1283's review URL. Port 8080 is NOT Watchtower — it is a 
different Python service that happens to respond to arbitrary paths. Port 3000 
(the real Watchtower, PID 3122424) was running but was skipped because its 
API didn't know T-1283 yet (needs restart to pick up new tasks).

## Evidence of Regression

Current running services on .107 (observed 2026-04-17 18:50):

```
LISTEN  :3000   python3  pid=3122424   (Watchtower — correct)
LISTEN  :8080   python3  pid=3892      (unknown service — returned a 200 for /inception/T-1283)
LISTEN  :4050   python3  pid=2730448
LISTEN  :8082   python3  pid=3646173
LISTEN  :8090   python3  pid=3887339
LISTEN  :8178   python3  pid=2636659
LISTEN  :5050   gunicorn pid=4151      (Watchtower-prod LXC mirror)
```

`_watchtower_url T-1283` fallback sequence:
1. No `WATCHTOWER_URL` env → skip
2. PID file → stale/missing → skip
3. cwd match → no process with `cwd=/opt/999-Agentic-Engineering-Framework` → skip
4. Task-specific probe iterates `3000 3001 3002 3003 8080` and hits the FIRST 
   service that returns 200 on any of `/api/tasks/T-1283`, `/inception/T-1283`, 
   `/review/T-1283`
5. Port :3000 (real Watchtower) doesn't yet know T-1283 because it wasn't 
   restarted after the task was created → returns 404
6. Probe proceeds to :8080, which returns 200 for arbitrary paths (likely a 
   catch-all Flask/FastAPI app or reverse proxy)
7. Function returns `:8080` → user lands on wrong service

## Root Cause

**Liveness and identity are conflated.** A service responding with HTTP 200 is 
treated as proof that it IS Watchtower AND owns this project. Neither is true:
- Liveness only means "something answered"
- Identity requires a service-specific handshake
- Ownership requires the service to be bound to THIS project root

## Four-Directive Analysis

### Antifragility (strengthens under stress)
Current: fragile under the stress of sibling services. Any Python app on the 
probed ports can masquerade. Adding more services = more failure surface.
Target: service identification must be **robust to the presence of unrelated 
services on the same host**, even on same ports the framework historically used.

### Reliability (predictable, observable, auditable, no silent failure)
Current: same env + same invocation returns different URLs depending on:
- Whether Watchtower was restarted after task creation
- What other Python services are running
- Which port each service happens to bind
Target: deterministic output given the environment. Same inputs → same URL. 
**Fail loudly** when no authoritative Watchtower is reachable — never 
silently return a URL to a random service.

### Usability (joy to use, sensible defaults, actionable errors)
Current: user clicks URL → lands on wrong service → blames Watchtower.
Target: errors are actionable. If no Watchtower is running, say "no watchtower 
running, try `fw serve`" — don't route the user to a ghost service.

### Portability (no provider/language/environment lock-in, prefer standards)
Current: hardcoded port list `3000 3001 3002 3003 8080`. Fine for our setup, 
breaks if consumer runs Watchtower on 8765. `fw_config "PORT"` is honored only 
as the default_port in the probe, then probed alongside hardcoded alternatives.
Target: no hardcoded port list. Discovery through a single source of truth 
(PID file, config, or identity registry).

## Proposal: Three-Layer Discovery

### Layer 1 — PID+Port+URL triple (authoritative)

When Watchtower starts, it writes ALL THREE of:
```
.context/working/watchtower.pid    # PID
.context/working/watchtower.port   # bound port
.context/working/watchtower.url    # full resolved URL (host:port)
```

On discovery:
1. Read all three files
2. Verify `kill -0 $pid` succeeds (process alive)
3. Verify `ss -tlnp` shows that PID listening on that port
4. Return `watchtower.url` — no probing, no guessing

If any check fails → go to Layer 2.

### Layer 2 — Identity handshake (verification)

Every Watchtower exposes `GET /api/_identity`:
```json
{
  "service": "watchtower",
  "version": "1.5.91",
  "project_root": "/opt/999-Agentic-Engineering-Framework",
  "started_at": "2026-04-17T14:20:00Z"
}
```

On discovery (when Layer 1 fails or is absent):
1. Probe configured ports (ONLY those from `.framework.yaml` + env, no defaults)
2. For each, call `/api/_identity`
3. Match if `service=="watchtower"` AND `project_root` matches current 
   `PROJECT_ROOT` or `FRAMEWORK_ROOT`
4. Returns first match; multiple matches = ambiguous, fail loudly

If no port is configured → go to Layer 3.

### Layer 3 — Fail loudly (no silent wrong answer)

If Layers 1 and 2 both fail: exit with error message:
```
No Watchtower reachable. Start one with: fw serve
Or set WATCHTOWER_URL explicitly.
```

Do NOT probe arbitrary ports. Do NOT return a URL to an unknown service.

## Out of Scope (for this inception)

- Auto-restarting Watchtower when a new task is created (separate problem)
- Multi-Watchtower coordination (one per project vs one for all)
- HTTPS/auth for /api/_identity (add when threat model requires it)

## Proposed Build Arc (post-GO)

- **B1** — Watchtower emits identity handshake at `/api/_identity`
- **B2** — Watchtower writes `.pid`, `.port`, `.url` triple atomically on startup
- **B3** — Rewrite `_watchtower_url` as 3-layer discovery (no port probe list)
- **B4** — `fw doctor` surfaces stale PID files and suggests `fw serve`
- **B5** — Decommission hardcoded port list `3000 3001 3002 3003 8080`
- **B6** — Add regression test: mock a second Python service on a common port, 
  assert `_watchtower_url` never returns it

## Assumptions

- A1: All Watchtower instances can write to `.context/working/` on startup 
  (consumer projects may vary — need to verify)
- A2: `/api/_identity` is cheap enough to call on every invocation (should be 
  trivial — static JSON response)
- A3: We can coordinate Watchtower-prod (LXC) to expose `/api/_identity` too, 
  so remote fleet discovery works consistently
- A4: Breaking the current "any responding port is Watchtower" behavior will 
  not orphan legacy scripts — all callers go through `_watchtower_url`

## Go/No-Go Criteria

**GO if:**
- 3-layer design scores ≥ current design on all four directives (analysis above)
- No breaking change to public `_watchtower_url` signature — still returns URL 
  on stdout or exits non-zero
- Build units B1-B6 fit one session each
- Identity handshake is cheap enough for every CLI invocation (< 50ms overhead)

**NO-GO if:**
- A3 is untestable (can't coordinate Watchtower-prod) → must reduce scope to 
  local-only discovery
- Writing a triple of files is racy across concurrent Watchtower starts → 
  must redesign Layer 1
- Identity handshake adds > 100ms to every `fw` command → must cache

## Recommendation

**Recommendation:** GO

**Rationale:** Current port discovery fails the Reliability directive 
outright (silent wrong answer on a wrong service) and fails Antifragility 
(masqueraders pass undetected). The 3-layer redesign restores all four 
directives: PID/port/URL triple = deterministic (reliability); identity 
handshake = robust to siblings (antifragility); fail-loud = actionable 
errors (usability); no hardcoded ports = config-driven (portability).

**Evidence:**
- :8080 service returned a URL the user clicked and it went nowhere — 
  a real user-visible regression, not hypothetical
- Current `_watchtower_url` has 3 fallback layers but all 3 can silently 
  converge on the wrong service
- Fix scope is bounded (6 build units, each <1 session) and reversible
- Pattern (identity handshake + PID triple + fail-loud) is reusable for 
  any future framework service (Watchtower, fabric viewer, log server)

## Dialogue Log

### 2026-04-17 — initial report
- User: "regression frickin port incompetent degenerate shit" after 
  T-1283 review URL pointed to :8080
- Agent: initially misidentified as "Watchtower should be :3000" — 
  user corrected: assumption vs dynamic check is the whole point
- User: "yeah just pick any port ::: that aint working fricking incept 
  how we can make this follow our framework 4 rules"
- Agent: created this inception (T-1284) covering the four-directive 
  redesign of port discovery
