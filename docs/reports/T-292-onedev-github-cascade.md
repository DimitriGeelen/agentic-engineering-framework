# T-292: OneDev to GitHub Cascade — Research

## Problem Statement

The Agentic Engineering Framework repo lives on a self-hosted OneDev instance. We want automatic cascading (push mirror) to GitHub so the repo is publicly accessible without manual syncing.

## Current State

- **Primary remote:** `onedev` → `https://onedev.docker.ring20.geelenandcompany.com/agentic-engineering-framework.git`
- **No GitHub remote configured** — `git remote -v` shows only `onedev`
- **Existing CI/CD:** `.onedev-buildspec.yml` has one job (Deploy Production to LXC on `v*` tags)
- **OneDev version:** 7.1+ (supports native Repository Sync steps)

## Approaches Researched

### Approach A: OneDev Built-in "Push to Remote" Step

OneDev 7.1 introduced native repository sync steps. This is the officially supported method.

**How it works:**
1. Create a GitHub Personal Access Token (PAT) with repo push permissions
2. Store the PAT as a OneDev "Job Secret" in the project
3. Add a buildspec job with a `!PushRepository` step pointing to GitHub
4. Add triggers: `BranchUpdateTrigger` (all branches) + `TagCreateTrigger` (all tags)

**Pros:**
- Native OneDev feature, maintained by OneDev team
- Declarative (in buildspec YAML), version-controlled
- Triggers on every push — near-real-time sync
- Handles branches AND tags automatically
- Coexists with existing deploy job in same buildspec

**Cons:**
- Requires GitHub PAT stored as job secret (rotation management)
- Adds a second job to the buildspec
- If OneDev CI runner is down, sync stops

### Approach B: Server-side Git Hook (post-receive)

Add a `post-receive` hook on the OneDev server that does `git push --mirror github`.

**How it works:**
1. Add GitHub as a remote in the bare repo on OneDev server
2. Store credentials via git credential helper or SSH key
3. Create `hooks/post-receive` script

**Pros:**
- Simple, no CI dependency
- Fires on every push (real-time)

**Cons:**
- Requires SSH access to OneDev server internals (bare repo)
- Not version-controlled (hook lives on server, not in repo)
- OneDev may overwrite hooks on upgrade
- Credential management outside OneDev's secret management

### Approach C: Cron/Systemd Timer Push

A timer that periodically pushes to GitHub (like T-283's dev auto-update, but in reverse).

**How it works:**
1. Add `github` remote to the repo
2. Systemd timer runs `git push github --mirror` every N minutes

**Pros:**
- Independent of OneDev CI
- Familiar pattern (already use this for dev auto-update)

**Cons:**
- Not real-time (delay up to N minutes)
- Requires a machine with both remotes configured
- Another systemd unit to manage
- Mirror push can be destructive (force-pushes)

### Approach D: GitHub Actions Pull

A GitHub Actions workflow that pulls from OneDev on a schedule.

**Pros:**
- Runs on GitHub's infrastructure
- No OneDev server changes needed

**Cons:**
- OneDev not publicly accessible — would need tunnel/VPN
- GitHub Actions has no access to internal network
- **Non-starter** given current network topology

## Recommendation

**Approach A (OneDev built-in Push to Remote)** is the clear winner:
- It's the officially supported method
- Declarative and version-controlled in buildspec
- Near-real-time on every branch update and tag
- Coexists naturally with the existing LXC deploy job
- Credential management via OneDev job secrets

## Implementation Steps (if GO)

1. Create GitHub repo (`agentic-engineering-framework`, public)
2. Generate GitHub PAT with `repo` scope (or fine-grained with push access)
3. Add PAT as OneDev job secret (e.g., `github-push-token`)
4. Add "Push to GitHub" job to `.onedev-buildspec.yml`
5. Test: push a branch, verify it appears on GitHub
6. Test: create a tag, verify it appears on GitHub
7. Document in deployment runbook

## Open Questions

1. GitHub repo visibility: public or private?
2. GitHub org/account: personal or organization?
3. Should we sync issues/PRs too, or code only? (OneDev supports code sync only natively)
4. PAT rotation strategy: manual or automated?
