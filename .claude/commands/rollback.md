# /rollback - Revert Production to Previous Version

Recovery skill for failed or problematic deployments. Reads deployment history, confirms with user, executes rollback, verifies health.

## Step 1: Task Gate

Verify an active task exists:
1. Read `.context/working/focus.yaml` — check `current_task` is set
2. If no task is set, STOP and say: "No active task. Run `/start-work` first."

## Step 2: Read Deployment History

```bash
ls -t .context/deployments/*.yaml 2>/dev/null | head -5
```

If no deployment records exist, STOP and say: "No deployment records found in `.context/deployments/`. Nothing to roll back."

Read the most recent deployment record:
```bash
cat .context/deployments/$(ls -t .context/deployments/*.yaml | head -1 | xargs basename)
```

Present the deployment info:
```
## Last Deployment

- Timestamp: {timestamp}
- App: {app}
- Task: {task}
- Commit: {commit}
- Result: {result}
```

## Step 3: Check Current Service State

```bash
export DOCKER_HOST=tcp://192.168.10.201:2375
docker service ls --filter name=watchtower
docker service ps watchtower_app --format '{{.ID}} {{.Image}} {{.CurrentState}}' | head -5
```

Present the current state: running image version, replica count, health.

## Step 4: Confirm with User

**This is a Tier 0 action.** Present options and WAIT for explicit user confirmation:

```
## Rollback Options

1. Rollback watchtower_app to previous version (docker service rollback)
2. Cancel — do not rollback
```

Do NOT proceed without the user selecting option 1. If user selects 2 or anything else, abort.

## Step 5: Execute Rollback

Only after user confirms option 1:

```bash
export DOCKER_HOST=tcp://192.168.10.201:2375
docker service rollback watchtower_app
```

Wait for convergence (up to 60 seconds):
```bash
for i in $(seq 1 30); do
  RUNNING=$(docker service ps watchtower_app --filter desired-state=running --format '{{.CurrentState}}' | grep -c 'Running')
  if [ "$RUNNING" -ge 2 ]; then
    echo "Rollback converged: $RUNNING replicas running"
    break
  fi
  sleep 2
done
```

## Step 6: Verify Health

After rollback converges:
```bash
curl -sf http://192.168.10.201:5050/health
```

Report health status.

## Step 7: Log Rollback Record

Write a deployment record:
```bash
DEPLOY_DIR=".context/deployments"
DEPLOY_FILE="$DEPLOY_DIR/$(date +%Y-%m-%d-%H%M)-rollback.yaml"
```

Record should include: timestamp, app, command (rollback), task, commit, result (success/failed).

## Step 8: Present Summary

```
## Rollback Summary

- App: {app}
- Action: Rolled back to previous version
- Health: {healthy/unhealthy}
- Record: {deploy_file}

Next steps:
1. Investigate root cause of the failed deployment
2. Fix and redeploy when ready
3. Run `/deploy-check` before next deployment
```

## Rules

- ALWAYS require explicit user confirmation before executing rollback (Step 4)
- ALWAYS read deployment history first — never rollback blind
- ALWAYS verify health after rollback
- ALWAYS log the rollback as a deployment record
- If no DOCKER_HOST is reachable, report and abort — do not guess
- Present all options as numbered lists per Agent Behavioral Rules
