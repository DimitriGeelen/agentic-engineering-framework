# Watchtower Deployment Runbook

## Overview

| Item | Value |
|------|-------|
| App | Watchtower (Agentic Engineering Framework dashboard) |
| Production FQDN | `https://watchtower.docker.ring20.geelenandcompany.com` |
| Dev FQDN | `https://watchtower-dev.docker.ring20.geelenandcompany.com` |
| Port | 5050 (prod), 5051 (dev) |
| Deployment model | LXC container on Proxmox (D-039, see T-279) |
| LXC host | 192.168.10.170 (CT on proxmox2) |
| Ollama host | `192.168.10.107:11434` |
| Traefik nodes | .51 and .53 (sync both — L-TRF-02) |
| Git remote | OneDev (`onedev`) |

## Architecture

```
Browser → Traefik HA (.51/.53, VIP .52)
              ↓
    LXC Container (192.168.10.170)
    ├── watchtower-dev  :5051  ← git checkout (master)
    └── watchtower      :5050  ← git checkout (tagged release)
              ↓
         Ollama GPU (.107:11434)
```

- Single LXC with two systemd services (dev + prod)
- Each service runs gunicorn against its own git checkout
- Framework data (.tasks/, .context/, .fabric/) is live on disk — not baked into an image
- All write operations work natively (task creation, decisions, fw CLI, git)
- Search/embeddings build locally with Ollama access

## Three-Tier Access

| Tier | URL | Data Freshness | Purpose |
|------|-----|----------------|---------|
| **Local** | `localhost:3000` (`fw serve`) | Real-time (filesystem) | Active development |
| **Dev** | `watchtower-dev.docker.ring20...` | Last push (auto-update) | Remote verification |
| **Prod** | `watchtower.docker.ring20...` | Last promoted tag | Stable reference |

## Development Workflow

### Daily Work

```
1. Work on master (agent + human on dev machine)
   ├── fw serve on :3000 for real-time view
   ├── Agent commits every 15-20 min
   └── git push onedev master

2. Dev auto-updates (automatic)
   ├── OneDev webhook or cron triggers on push
   ├── LXC pulls latest master into /opt/watchtower-dev/
   ├── systemctl restart watchtower-dev
   └── Visible at watchtower-dev.docker.ring20...

3. Verify on dev (from any device)
   ├── Open dev FQDN in browser
   ├── Check dashboard, tasks, fabric, Q&A, write operations
   └── If issues → fix on master, repeat

4. Promote to prod (explicit human trigger only)
   ├── Tag: git tag v1.X.X && git push onedev --tags
   ├── SSH to LXC: cd /opt/watchtower-prod && git fetch && git checkout v1.X.X
   ├── systemctl restart watchtower
   └── Verify at watchtower.docker.ring20...
```

### Key Rules

- **Never work on prod directly** — all changes flow through dev first
- **Dev updates automatically** — latest master state, refreshes on push
- **Prod updates only on explicit tag** — human decides when to promote
- **Local `fw serve` is always available** for real-time view during active work

## Pre-Deploy Checklist

Run `/deploy-check` or manually verify:

```bash
# Framework audit clean
fw audit --section deployment

# Ollama reachable
curl -sf http://192.168.10.107:11434/api/tags | head -5

# LXC reachable
ssh root@192.168.10.170 'systemctl is-active watchtower-dev watchtower'
```

## Manual Operations

### Update Dev

```bash
ssh root@192.168.10.170 'cd /opt/watchtower-dev && git pull && systemctl restart watchtower-dev'
```

### Promote to Prod

```bash
# Tag locally
git tag v1.X.X
git push onedev --tags

# Deploy on LXC
ssh root@192.168.10.170 'cd /opt/watchtower-prod && git fetch --tags && git checkout v1.X.X && pip install -q -r web/requirements.txt && systemctl restart watchtower'
```

### Rollback Prod

```bash
# Check previous tag
ssh root@192.168.10.170 'cd /opt/watchtower-prod && git tag --sort=-v:refname | head -5'

# Rollback to previous version
ssh root@192.168.10.170 'cd /opt/watchtower-prod && git checkout v1.X.Y && systemctl restart watchtower'
```

## Verification

```bash
# Health checks (direct)
curl -sf http://192.168.10.170:5050/health   # prod
curl -sf http://192.168.10.170:5051/health   # dev

# Health checks (via Traefik FQDN)
curl -sf https://watchtower.docker.ring20.geelenandcompany.com/health
curl -sf https://watchtower-dev.docker.ring20.geelenandcompany.com/health

# Dashboard loads
curl -sf https://watchtower.docker.ring20.geelenandcompany.com/ -o /dev/null -w "%{http_code}"

# Service status on LXC
ssh root@192.168.10.170 'systemctl status watchtower watchtower-dev'
```

## Traefik Routes

Routes file: `deploy/traefik-routes.yml`

Sync to both Traefik nodes (L-TRF-02):
```bash
scp deploy/traefik-routes.yml root@192.168.10.51:/opt/traefik/config/watchtower.yml
scp deploy/traefik-routes.yml root@192.168.10.53:/opt/traefik/config/watchtower.yml
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Health returns 503 | Ollama unreachable | `curl http://192.168.10.107:11434/api/tags` |
| Search slow on first query | Vector DB rebuilding | Wait 2-3 min; Ollama embedding all files |
| FQDN 404 | Traefik routes not synced | Re-scp to both .51 and .53 |
| Service won't start | Python deps missing | `cd /opt/watchtower-* && pip install -r web/requirements.txt` |
| Git pull fails | OneDev credentials | Check SSH key on LXC, verify OneDev access |
| LXC unreachable | Node failure | Proxmox HA should auto-restart; check `ha-manager status` |
| Stale dev data | Auto-update not running | Check webhook/cron: `systemctl status watchtower-dev-update` |

## Resilience

- **Machine death**: Git repo on OneDev — `git clone` recovers everything
- **LXC crash**: Proxmox HA auto-restarts on another node
- **Traefik failover**: VIP .52 switches to surviving Traefik node
- **Ollama down**: Health endpoint reports `ollama: error`; dashboard works but search fails

## History

- **v1 (2026-02-25)**: Docker Swarm deployment (T-277). 2 replicas on .201/.202.
- **v2 (2026-02-25)**: Pivoted to LXC on Proxmox (T-279/D-039). Docker model conflicted with Watchtower's filesystem-dependent design.
