# T-279: Watchtower Deployment Model Research

## Problem Statement

Production Watchtower at `watchtower.docker.ring20.geelenandcompany.com` shows an empty "new project" page — 0 tasks, 0/5 setup checklist, "No focus", "Session: unknown". The Docker container has no access to the framework's `.tasks/`, `.context/`, `.fabric/` directories.

User observation: "This should be the main framework page, not a new project page."

## Research Conducted

7 parallel research agents investigated the architecture:

| Agent | Scope | Key Finding |
|-------|-------|-------------|
| RQ-1 | Framework purpose & philosophy | Dual-mode self-hosting; multi-project by design via `.framework.yaml` |
| RQ-2 | Watchtower architecture & data | 11 blueprints reading from single PROJECT_ROOT; not multi-tenant |
| RQ-3 | Deployment model & infra | Container missing .tasks/.context/.fabric; .dockerignore blocks them |
| RQ-4 | Multi-project evidence | Confirmed: T-091/T-095/T-101/T-103 validated external projects |
| RQ-5 | Design history & vision | T-058 vision: "governance consciousness reflecting what project knows" |
| RQ-6 | Proxmox VM/LXC feasibility | LXC sufficient; IPs .140-.145 free; Proxmox HA available |
| RQ-7 | Ring20 services mapping | 4 Proxmox nodes; Traefik routes to any IP; no existing non-Docker app pattern |

Two additional review agents validated the Docker approach before pivoting:

| Agent | Scope | Key Finding |
|-------|-------|-------------|
| Review-1 | Workflow gaps/risks | 9 gaps: 2 CRITICAL (write data loss, vector DB timeout), 2 HIGH |
| Review-2 | Technical feasibility | Feasible but 4 warnings: ephemeral writes, embedding rebuild, git degradation |

## Key Deductions

### D1: Docker's isolation model fights Watchtower's design
Watchtower is a filesystem-dependent project dashboard with 18+ write endpoints and git integration. Docker's ephemeral, stateless, replicated model creates:
- **Data loss**: Writes to container filesystem lost on restart
- **Replica divergence**: Task created on replica A invisible on replica B
- **Stale data**: Framework data baked at build time, not live
- **Git degradation**: No .git directory, all git operations show "unknown"

### D2: The framework IS its own primary project
278 tasks, 74 learnings, full fabric graph — this is the data Watchtower should display. The empty production page is architecturally incomplete, not a new project.

### D3: LXC on Proxmox eliminates all Docker critical issues
All 9 gaps from Docker review disappear with LXC:
- Persistent filesystem → writes survive restarts
- Single instance → no replica divergence
- Git repo present → all operations work
- Ollama reachable → search/embeddings work natively
- Live data via git pull → no staleness

### D4: LXC is a new deployment pattern for Ring20
Ring20 currently uses Docker Swarm for all web apps. This would be the first LXC-based app service. But infrastructure supports it: Proxmox client tools exist, Traefik routes to any IP, IPs available.

## Considerations

### Docker approach (rejected)
- **Pro**: Existing CI/CD pipeline, Swarm HA (2 replicas), consistent with Ring20 pattern
- **Con**: 2 CRITICAL issues (write data loss, vector DB timeout), stale data, git degradation
- **Mitigation attempted**: Read-only mode + disable search — but this reduces Watchtower to a static viewer, losing its "command center" vision (T-058)

### LXC approach (chosen)
- **Pro**: All writes work, search works, live data, git works, simpler deployment, lower resource cost
- **Con**: New pattern for Ring20, no Swarm HA (mitigated by Proxmox HA), single instance
- **Risk**: LXC kernel crash affects both dev and prod (mitigated by Proxmox HA failover)

### VM approach (considered, rejected)
- **Pro**: Full isolation, own kernel
- **Con**: Higher resource cost (512MB+ baseline), slower boot, overkill for a Flask app
- Watchtower needs only Python 3.12, git, gunicorn, sqlite — LXC is sufficient

## Decision

**GO: Deploy Watchtower as LXC container on Proxmox (Option B: single LXC, two systemd services)**

### Architecture

```
LXC Container (CT on proxmox2, IP 192.168.10.141)
├── /opt/watchtower-dev/     ← git checkout (master/develop)
│   └── systemd: watchtower-dev on :5051
│
├── /opt/watchtower-prod/    ← git checkout (tagged release)
│   └── systemd: watchtower on :5050
│
├── Shared: Python 3.12, git, gunicorn, sqlite-vec
└── Shared: Ollama access via http://192.168.10.107:11434

Traefik (.51/.53):
  watchtower.docker.ring20...     → http://192.168.10.141:5050
  watchtower-dev.docker.ring20... → http://192.168.10.141:5051
```

### Update Workflow

```
Dev:  Work on master → push to onedev → webhook/cron triggers
      → LXC pulls latest → systemctl restart watchtower-dev
      Automatic, shows latest committed state

Prod: Human explicit trigger → LXC checks out tagged version
      → systemctl restart watchtower
      Never automatic, only on human "go"
```

### Rationale
1. Watchtower's design (filesystem reads/writes, git integration, fw CLI) requires a real filesystem — not Docker's ephemeral overlay
2. Single-user dashboard doesn't need Swarm HA — Proxmox HA provides equivalent failover
3. Resource cost is lower (1 LXC vs 2 Swarm replicas)
4. Deployment is simpler (git pull + restart vs image build + push + deploy)
5. The "command center" vision (T-058) requires write operations to work — read-only mode would reduce Watchtower to a static viewer

### Alternatives Rejected
- **Docker with read-only mode**: Loses write functionality, reduces to static viewer
- **Docker with NFS mounts**: Adds complexity, latency, NFS dependency
- **Docker with git clone at startup**: Fragile (clone failures), credential management
- **Two separate LXCs**: Overkill for current needs, double resource cost
- **Full VM**: Overkill, LXC sufficient for Python + git workload
