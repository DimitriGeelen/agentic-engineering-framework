# /deploy-check - Pre-Deployment Validation

Run this before triggering a deployment to verify all prerequisites are met.

## Step 1: Task Gate

Verify an active task exists:
1. Read `.context/working/focus.yaml` — check `current_task` is set
2. If no task is set, STOP and say: "No active task. Run `/start-work` first."

## Step 2: Run Pre-Deploy Audit

```bash
fw audit --section deployment
```

Capture the exit code:
- **Exit 0:** All gates passed
- **Exit 1:** Warnings (deployment can proceed with caution)
- **Exit 2:** Failures (deployment blocked — must fix first)

## Step 3: Check Registry Reachability

```bash
curl -sf http://192.168.10.201:5000/v2/_catalog | head -5
```

If unreachable, report: "Docker registry at 192.168.10.201:5000 is unreachable."

## Step 4: Check Ollama Reachability from App Host

```bash
curl -sf http://192.168.10.107:11434/api/tags | head -5
```

If unreachable, report: "Ollama GPU host at 192.168.10.107:11434 is unreachable — containers won't be able to run Q&A."

## Step 5: Verify Deployment Files Exist

Check these files exist in the project root:
1. `Dockerfile`
2. `deploy/docker-compose.swarm.yml`
3. `deploy/traefik-routes.yml`
4. `.onedev-buildspec.yml`

## Step 6: Check Local Health Endpoint

If the app is running locally:
```bash
curl -sf http://localhost:3000/health
```

Report the health status (app, ollama, embeddings).

## Step 7: Present Results

Present a numbered checklist:

```
## Deploy Readiness Check

1. [PASS/FAIL] Active task: T-XXX
2. [PASS/FAIL] Pre-deploy audit (fw audit --section deployment)
3. [PASS/FAIL] Docker registry reachable (192.168.10.201:5000)
4. [PASS/FAIL] Ollama GPU host reachable (192.168.10.107:11434)
5. [PASS/FAIL] Deployment files present
6. [PASS/FAIL] Local health endpoint

Result: READY / NOT READY (N issues to fix)
```

If NOT READY, list remediation steps for each failure.

If READY, suggest next steps:
1. Push to trigger CI/CD: `git push`
2. Tag for production: `git tag vX.Y.Z && git push --tags`
3. Manual scaffold: `fw deploy scaffold --app watchtower`

## Rules

- This is a read-only check — it does NOT trigger deployment
- Run `fw audit --section deployment` (not a full audit)
- All checks run sequentially (registry/Ollama checks may timeout)
- Present results as numbered list per Agent Behavioral Rules
