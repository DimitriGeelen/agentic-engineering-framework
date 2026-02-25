# Watchtower Deployment Runbook

## Overview

| Item | Value |
|------|-------|
| App | Watchtower (Agentic Engineering Framework dashboard) |
| Production FQDN | `https://watchtower.docker.ring20.geelenandcompany.com` |
| Dev FQDN | `https://watchtower-dev.docker.ring20.geelenandcompany.com` |
| Port | 5050 (prod), 5051 (dev) |
| Stack name | `watchtower` |
| Service name | `watchtower_app` |
| Registry | `192.168.10.201:5000/watchtower` |
| Ollama host | `192.168.10.107:11434` |
| Swarm nodes | docker-manager (.201), docker-worker-1 (.202) |
| Traefik nodes | .51 and .53 |
| CI/CD | OneDev (tag `v*` triggers production build+deploy) |

## Pre-Deploy Checklist

Run `/deploy-check` or manually:

```bash
fw audit --section deployment
curl -sf http://192.168.10.201:5000/v2/_catalog          # Registry
curl -sf http://192.168.10.107:11434/api/tags             # Ollama
test -f Dockerfile && test -f deploy/docker-compose.swarm.yml  # Files
```

## Automated Deployment (CI/CD)

For subsequent deployments after the initial stack creation:

```bash
# Tag and push to trigger OneDev CI/CD
git tag v1.X.X
git push onedev v1.X.X
```

OneDev will:
1. Build Docker image on docker-builder (CT 400)
2. Push to registry with version tag + latest
3. `docker service update --image` on watchtower_app
4. Wait for convergence (2 replicas, 60s timeout)
5. Auto-rollback on convergence failure

## Manual Deployment

### First-Time Stack Creation

```bash
# Generate secret key
python3 -c "import secrets; print(secrets.token_hex(32))"

# Build image
DOCKER_HOST=tcp://docker-builder.ring20.geelenandcompany.com:2375 \
  docker build -t 192.168.10.201:5000/watchtower:$(date +%Y%m%d-%H%M%S) \
               -t 192.168.10.201:5000/watchtower:latest -f Dockerfile .

# Push to registry
DOCKER_HOST=tcp://docker-builder.ring20.geelenandcompany.com:2375 \
  docker push 192.168.10.201:5000/watchtower:latest

# Deploy stack
FW_SECRET_KEY=<generated-key> \
  DOCKER_HOST=tcp://192.168.10.201:2375 \
  docker stack deploy -c deploy/docker-compose.swarm.yml watchtower

# Sync Traefik routes
scp deploy/traefik-routes.yml root@192.168.10.51:/opt/traefik/config/watchtower.yml
scp deploy/traefik-routes.yml root@192.168.10.53:/opt/traefik/config/watchtower.yml
```

### Manual Service Update

```bash
# Build and push new image
VERSION=$(date +%Y%m%d-%H%M%S)
DOCKER_HOST=tcp://docker-builder.ring20.geelenandcompany.com:2375 \
  docker build -t 192.168.10.201:5000/watchtower:${VERSION} \
               -t 192.168.10.201:5000/watchtower:latest -f Dockerfile .
DOCKER_HOST=tcp://docker-builder.ring20.geelenandcompany.com:2375 \
  docker push 192.168.10.201:5000/watchtower:${VERSION}
DOCKER_HOST=tcp://docker-builder.ring20.geelenandcompany.com:2375 \
  docker push 192.168.10.201:5000/watchtower:latest

# Update service
DOCKER_HOST=tcp://192.168.10.201:2375 \
  docker service update --image 192.168.10.201:5000/watchtower:${VERSION} watchtower_app
```

## Verification

```bash
# Service status
DOCKER_HOST=tcp://192.168.10.201:2375 docker service ps watchtower_app

# Health checks (direct)
curl -sf http://192.168.10.201:5050/health
curl -sf http://192.168.10.202:5050/health

# Health check (via Traefik FQDN)
curl -sf https://watchtower.docker.ring20.geelenandcompany.com/health

# Dashboard loads
curl -sf https://watchtower.docker.ring20.geelenandcompany.com/ -o /dev/null -w "%{http_code}"
```

## Rollback

Use `/rollback` skill or manually:

```bash
DOCKER_HOST=tcp://192.168.10.201:2375 docker service rollback watchtower_app
```

Wait for convergence, then verify health.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Health returns 503 | Ollama unreachable | Check `curl http://192.168.10.107:11434/api/tags` |
| Health hangs | Index rebuild triggered | Restart container (should not happen with fixed health endpoint) |
| Convergence failure | Image pull failed | Check registry, check node connectivity |
| Port conflict | Another service on 5050 | Check `ss -tlnp \| grep 5050` on Swarm nodes |
| Traefik 404 | Routes not synced | Re-scp `traefik-routes.yml` to .51 and .53 |

## Architecture

```
Browser → Traefik (.51/.53) → Swarm LB → watchtower_app (2 replicas)
                                              ↓
                                         Ollama GPU (.107)
```

- App containers are CPU-only (Python + Flask + gunicorn)
- Ollama runs on dedicated GPU host (192.168.10.107) as system service
- Containers connect via OLLAMA_HOST env var
- Embeddings index is built in-container on first search (ephemeral, stored in volume)
