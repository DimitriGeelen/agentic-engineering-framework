# T-885: Configurable Watchtower Port + Project Service Registry

## Research Artifact (C-001)

**Task:** T-885
**Created:** 2026-04-05
**Status:** Complete

---

## Spike 1 — Port Persistence Mechanism

### How FW_PORT is resolved today

**3 tiers, no persistent file tier:**

1. `lib/config.sh` — `fw_config "PORT" 3000` → checks CLI arg > `FW_PORT` env var > default 3000
2. `web/config.py` — `int(os.environ.get("FW_PORT", "3000"))` → env var > default
3. `bin/watchtower.sh` — `DEFAULT_PORT=$(fw_config "PORT" 3000)`, then `--port` CLI flag overrides

**Gap:** No persistent tier. If you don't set `FW_PORT` in your shell or systemd, it's always 3000. The 3-tier model is CLI > env > default — there's no "config file" tier between env and default.

### What tools generate Watchtower URLs?

| File | How it gets port |
|------|------------------|
| `lib/review.sh` | `WATCHTOWER_URL` env > PID-based `ss` lookup > `fw_config "PORT" 3000` |
| `lib/verify-acs.sh` | `fw_config "PORT" 3000` then passes to Python |
| `agents/audit/audit.sh` | `fw_config "PORT" 3000` |
| `agents/context/check-tier0.sh` | `WATCHTOWER_URL` env var |
| `bin/fw` (doctor) | `${FW_PORT:-3000}` |
| `web/config.py` (Flask) | `os.environ.get("FW_PORT", "3000")` |
| `bin/watchtower.sh` | `fw_config "PORT" 3000` + `--port` flag |
| `.claude/commands/resume.md` | Hardcoded `localhost:3000` |
| Walkthrough docs | Hardcoded `localhost:3000` |

**7 code paths** read the port dynamically (via `fw_config` or env var).
**3 places** have it hardcoded to 3000 (resume command, walkthrough docs, CLAUDE.md example).

### How Watchtower starts

`bin/watchtower.sh start [--port N]`:
1. Reads `DEFAULT_PORT` from `fw_config "PORT" 3000`
2. `--port` flag overrides
3. Checks port availability, kills holder if busy (⚠️ this is the collision behavior!)
4. Starts `python3 -m web.app --port $port`
5. Writes PID to `.context/working/watchtower.pid`

**Key finding:** Line 159-178 of `watchtower.sh` actively **kills** whatever is on the port. This is exactly the collision problem — project B's Watchtower kills project A's.

### .framework.yaml in consumer projects — current schema

```yaml
project_name: 001-sprechloop
version: 1.4.566
provider: claude
initialized_at: 2026-02-17T20:26:57Z
upstream_repo: DimitriGeelen/agentic-engineering-framework
upgraded_from: 1.4.560
last_upgrade: 2026-04-05T07:31:39Z
```

No `watchtower` or `services` section exists. The file is simple key-value YAML.

### Spike 1 Findings

**Adding a persistent config file tier is straightforward:**
- `fw_config` gets a Tier 2.5: read from `.framework.yaml` (between env var and default)
- `fw_config` already receives `PROJECT_ROOT` context via sourcing
- `.framework.yaml` already exists in all 11 consumer projects
- Python side (`web/config.py`) needs to also read `.framework.yaml` — currently env-only

**Resolution order becomes:** CLI flag > `FW_PORT` env var > `.framework.yaml` `watchtower.port` > default 3000

**Port collision fix:** Instead of killing the port holder, warn and suggest the next available port. Or better: if a configured port is in use by a different project, refuse to start.

---

## Spike 2 — Service Registry + Port Conflict Detection

### Proposed .framework.yaml extension

```yaml
# Agentic Engineering Framework - Project Configuration
project_name: 001-sprechloop
version: 1.4.566
provider: claude
initialized_at: 2026-02-17T20:26:57Z

# Port configuration (T-885)
watchtower:
  port: 3001

services:
  - name: api
    port: 8080
    protocol: http
    health: /health
  - name: frontend
    port: 3010
    protocol: http
  - name: worker
    port: 9090
    protocol: http
    health: /status
```

**Schema rules:**
- `watchtower.port` — integer, persisted, read by all URL generators
- `services` — list of {name, port, protocol, health?}
- `health` is optional — when present, enables status checking
- Each service is ~3-4 lines — typical project with 2-3 services = ~12 lines

### Port Conflict Detection

**At Watchtower startup (`watchtower.sh`):**
```bash
# Instead of killing port holder:
if port_in_use "$port"; then
    holder=$(ss -tlnp | grep ":${port} " | grep -oP 'pid=\K[0-9]+')
    log_error "Port $port already in use (PID $holder)"
    log_info "Configure a different port: fw config set watchtower.port <N>"
    # Suggest next available
    for try_port in $(seq $((port+1)) $((port+20))); do
        if ! port_in_use "$try_port"; then
            log_info "Suggested available port: $try_port"
            break
        fi
    done
    exit 1
fi
```

**For registered services (fw doctor extension):**
```bash
# Read services from .framework.yaml, check each port
for service in $(parse_services); do
    if port_in_use "${service_port}"; then
        echo "OK  ${service_name} on :${service_port}"
    else
        echo "DOWN  ${service_name} on :${service_port}"
    fi
done
```

### Firewall Integration

`watchtower.sh` already has `ensure_firewall_open` (opens UFW port for LAN access). This pattern should extend to registered services:

```bash
# After service starts successfully on configured port:
ensure_firewall_open "$service_port"
```

Without this, services start but are unreachable from other devices on the LAN. This is already a known pain point (memory: `feedback_check_firewall_lan.md` — "ALWAYS check UFW and open port when starting web services").

**Build task addition:** B-8: Firewall auto-open for registered service ports.

### CLI for port configuration

```bash
# Set Watchtower port
fw config set watchtower.port 3001

# Register a service
fw service register --name api --port 8080 --protocol http --health /health

# List services
fw service list

# Remove a service
fw service remove api
```

**Implementation:** These commands read/write `.framework.yaml` using `yq` or Python's `ruamel.yaml` (already a dependency).

### fw doctor Extension

Currently `fw doctor` checks:
- Git hooks installed
- Python available
- Watchtower running (health endpoint)
- Various framework state

**Addition:**
```
  OK  Watchtower configured on :3001
  OK  Service 'api' on :8080 (healthy)
  WARN  Service 'frontend' on :3010 (not responding)
  WARN  Port conflict: :8080 also used by project 052-KCP
```

Cross-project conflict detection: scan all `/opt/*/.framework.yaml` files for port overlap.

### Spike 2 Findings

- Schema is minimal and backward-compatible (new keys, no breaking changes)
- `ruamel.yaml` already available for YAML round-trip editing
- Port scanning with `ss -tlnp` works without privileges
- Cross-project conflict detection is possible by scanning sibling project configs
- `fw config set` is a new command but mechanically simple (YAML key update)

---

## Spike 3 — Watchtower Services Page

### UI Placement

**Option A: `/services` page (new route)**
- Dedicated page in sidebar navigation
- Shows: service table, port status, Watchtower config
- Pro: clean separation, room to grow
- Con: another nav item

**Option B: `/config` extension**
- Add "Services" section to existing config page
- Shows services below framework settings
- Pro: single page for all config
- Con: config page gets long

**Recommendation: Option A — `/services`** because:
- Config is read-only display of framework settings
- Services need interactive elements (register, edit port, remove)
- Aligns with Watchtower's pattern of one-purpose pages (/approvals, /costs, /fabric)

### Page Content

```
┌──────────────────────────────────────────────┐
│  Services — 001-sprechloop                   │
├──────────────────────────────────────────────┤
│                                              │
│  Watchtower                                  │
│  Port: 3001  Status: ● Running   [Edit]     │
│  URL: http://192.168.10.170:3001             │
│                                              │
│  ──────────────────────────────────────────  │
│                                              │
│  Registered Services                         │
│                                              │
│  Name       Port   Status    Health          │
│  api        8080   ● Up      /health ✓       │
│  frontend   3010   ○ Down    —               │
│  worker     9090   ● Up      /status ✓       │
│                                              │
│  [Register Service]                          │
│                                              │
│  ──────────────────────────────────────────  │
│                                              │
│  Port Conflicts                              │
│  ⚠ :8080 also configured in 052-KCP         │
│                                              │
└──────────────────────────────────────────────┘
```

### Consumer Project Integration

Consumer projects already have `.framework.yaml`. The services section is added:
- Manually (edit YAML)
- Via CLI (`fw service register`)
- Via Watchtower UI (form on `/services` page)

Watchtower reads `PROJECT_ROOT/.framework.yaml` at request time (not cached) so changes are immediate.

### Spike 3 Findings

- New `/services` route is cleanest — one blueprint file, one template
- Status checking via `ss -tlnp` at render time (fast, <50ms)
- Cross-project scan via glob of `/opt/*/.framework.yaml` (already done by `fw upgrade`)
- Port edit from UI writes back to `.framework.yaml` via `ruamel.yaml`
- No new dependencies needed

---

## Assumption Validation

| # | Assumption | Result |
|---|-----------|--------|
| A-1 | Static port registration, not dynamic discovery | ✅ Confirmed — YAML config in `.framework.yaml` is simple and reliable |
| A-2 | Per-project scope in `.framework.yaml` | ✅ Confirmed — file exists in all 11 projects, natural fit |
| A-3 | Health checking is Phase 2 | ⚠️ Partially — basic health is easy (just curl), could include in Phase 1 |
| A-4 | `lib/config.sh` handles persistent port | ✅ With modification — needs new tier reading `.framework.yaml` |
| A-5 | Display only, no orchestration | ✅ Confirmed — start/stop is out of scope |

---

## Recommendation

**GO** — All three spikes show this is bounded, achievable, and immediately useful.

### Rationale

1. **The problem is real and daily** — 11 projects, all defaulting to :3000, actively killing each other
2. **The fix is minimal** — add one YAML tier to `fw_config`, add `watchtower.port` to `.framework.yaml`
3. **No new dependencies** — `ruamel.yaml` already available, `ss` is standard
4. **Backward compatible** — no `watchtower` key = default 3000, same as today
5. **Natural fit** — `.framework.yaml` exists everywhere, Watchtower already has page-per-concern pattern

### Suggested Build Decomposition

| Task | Scope | Effort |
|------|-------|--------|
| B-1 | Add `.framework.yaml` tier to `fw_config` + Python config | Small |
| B-2 | `fw config set/get` CLI commands | Small |
| B-3 | `fw service register/list/remove` CLI | Medium |
| B-4 | Watchtower `/services` page | Medium |
| B-5 | `fw doctor` service health extension | Small |
| B-6 | Port conflict detection (startup + cross-project) | Small |
| B-7 | Fix `watchtower.sh` to warn instead of kill on port conflict | Small |

### Evidence

- 7 code paths already use `fw_config "PORT"` — adding a file tier catches them all
- `watchtower.sh:159-178` actively kills port holders — proven collision mechanism
- All 11 consumer projects have `.framework.yaml` — no setup needed
- `web/config.py:20-27` already reads `.context/settings.yaml` — same pattern for `.framework.yaml`
