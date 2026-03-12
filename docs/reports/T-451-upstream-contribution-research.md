# T-451: Upstream Contribution Pipeline — Research Findings

**Task:** T-451 (Inception)
**Researcher:** Agent
**Date:** 2026-03-12

---

## Research Task 1: Current Framework Distribution Model

**Source:** `/opt/999-Agentic-Engineering-Framework/docs/reports/T-306-framework-distribution-model.md`

### How It Works

The framework uses a **shared tooling model**:

1. **Framework repo** lives at a fixed path (e.g., `/opt/999-Agentic-Engineering-Framework`)
2. **Consumer projects** run `fw init /path/to/project` which:
   - Creates `.framework.yaml` containing `framework_path: /opt/999-Agentic-Engineering-Framework` (line 165 of `lib/init.sh`)
   - Copies frozen artifacts (CLAUDE.md, settings.json, task templates, seed YAML files, git hooks)
   - Runtime components (agents, lib, fw CLI) are executed live from the framework path

3. **Path resolution** (`lib/paths.sh:27-35`):
   ```
   FRAMEWORK_ROOT = this file's parent directory (repo root)
   PROJECT_ROOT = git toplevel of FRAMEWORK_ROOT, else FRAMEWORK_ROOT
   ```
   When sourced from a consumer project's hooks/config, `PROJECT_ROOT` is set via environment variable, while `FRAMEWORK_ROOT` comes from `.framework.yaml`.

### Key Finding: No Upstream URL Exists

The `.framework.yaml` file stores:
- `project_name` — basename of project directory
- `framework_path` — local filesystem path to framework repo
- `version` — framework version at init time
- `provider` — claude/cursor/generic
- `initialized_at` — timestamp

**There is no field for the framework's remote repository URL.** The framework only knows where it lives on disk, not where its canonical upstream is. This is the core gap for T-451.

### How Hooks Find the Framework

The pre-push hook (`agents/git/lib/hooks.sh:281-336`) demonstrates the resolution:
1. Read `framework_path` from `.framework.yaml`
2. Use that path to find `agents/audit/audit.sh`
3. Fall back to `$PROJECT_ROOT/agents/audit/audit.sh` for self-hosting

This pattern works for execution but provides no remote URL information.

---

## Research Task 2: Existing Remote/Git Safety

### Tier 0 Enforcement (`agents/context/check-tier0.sh`)

The Tier 0 system is a **PreToolUse hook on the Bash tool** that:
1. Reads the bash command from Claude Code's stdin JSON (line 33)
2. Fast-path keyword filter (line 50) — skips Python for 95%+ of commands
3. Pattern-matches against 16 destructive patterns (lines 85-136):
   - `git push --force` / `--force-with-lease`
   - `git reset --hard`
   - `git clean -f`
   - `git checkout .` / `git restore .`
   - `git branch -D`
   - `rm -rf /`, `rm -rf ~`, `rm -rf .`, `rm -rf *`
   - `DROP TABLE`, `TRUNCATE TABLE`
   - `git --no-verify`
   - `find -delete`, `dd if=`, `chmod 000`, `mkfs`, `pkill -9`
   - `docker system prune`, `kubectl delete namespace`
4. If matched: writes a pending approval file, blocks with exit code 2
5. Human runs `fw tier0 approve` to create one-time token (5-minute TTL, hash-matched)
6. Token consumed on next execution, logged to `bypass-log.yaml`

### What Tier 0 Covers for Pushes

**`git push --force`** is blocked. But **`git push` to the wrong remote** is NOT blocked. The Tier 0 patterns check for force flags, not remote targets. A normal `git push origin main` where `origin` points to the wrong repo would sail through unchallenged.

### Pre-Push Hook (`hooks/pre-push`)

Runs `audit.sh` before every push. Blocks on audit failures (exit 2). Does NOT check:
- Which remote is being pushed to
- Whether the remote is appropriate for the content
- Whether the branch exists on the remote

### Current Safety Gaps for T-451

| Risk | Current Protection | Gap |
|------|-------------------|-----|
| Force push | Tier 0 blocks it | None |
| Push to wrong remote | **None** | Full gap |
| Project code in framework PR | **None** | Full gap |
| Framework code in project PR | **None** | Full gap |
| Agent forgets remote topology after compaction | **None** | Full gap |

---

## Research Task 3: `gh` CLI Capabilities

### Cross-Repo Issue Creation

```bash
gh issue create --repo DimitriGeelen/agentic-engineering-framework \
  --title "Bug: audit fails on empty task" \
  --body "Description here"
```

**`--repo` / `-R` flag** (`[HOST/]OWNER/REPO`): Creates the issue on the specified repo regardless of the current working directory's git remote. This is the safest approach — no push needed, no branch needed, no risk of cross-contamination.

### Cross-Repo PR Creation

```bash
gh pr create --repo DimitriGeelen/agentic-engineering-framework \
  --head user:branch-name \
  --base main \
  --title "Fix: audit check" \
  --body "Description"
```

**`--head` flag** supports `<user>:<branch>` syntax. This allows creating a PR from a fork's branch to the upstream repo. However, organization-owned heads are not supported (see `gh` issue #10093).

**`--dry-run` flag**: Prints details without creating the PR. May still push git changes though (important caveat).

### Authentication Status

Currently authenticated as `DimitriGeelen` with scopes: `gist`, `read:org`, `repo`. This is sufficient for both issue creation and PR creation.

### Key Finding

**`gh issue create --repo` is the zero-risk path.** It requires no push, no branch, no fork. It just creates an issue on the target repo. This should be the default/primary mode for upstream contributions.

---

## Research Task 4: OneDev PR Sync Pattern

**Source:** `/opt/999-Agentic-Engineering-Framework/deploy/onedev-pr-sync.sh`

### Architecture (Inbound: External -> Framework Tasks)

1. **Polling**: Cron every 15 min, fetches open PRs via OneDev REST API
2. **Seen file**: `.context/working/.onedev-pr-seen` tracks PR# -> Task ID mapping
3. **Idempotent**: Skips already-seen PRs
4. **Task creation**: Uses `fw task create` with `--horizon next --owner human --tags "onedev,pr"`
5. **Dry-run mode**: `--dry-run` shows what would happen without creating tasks
6. **Error handling**: Fails loudly on API errors, silently when nothing to do (cron-friendly)

### Applicable Patterns for Outbound Design

| OneDev Pattern | Outbound Equivalent |
|----------------|-------------------|
| Seen file (`.onedev-pr-seen`) | Sent file (`.upstream-issues-sent`) to prevent duplicates |
| `--dry-run` default | `--dry-run` default for safety |
| Tags on created tasks | Labels on created issues |
| Cron-friendly (silent when nothing) | Not needed (on-demand, not cron) |
| API URL from env/config | Repo URL from `.framework.yaml` |

### Key Difference

OneDev sync is **inbound** (pull external data, create local tasks) — low risk, only writes to local filesystem. The outbound pipeline is **outbound** (push local data to external repo) — higher risk, writes to remote systems. This asymmetry means the outbound pipeline needs MORE safety gates, not fewer.

---

## Research Task 5: `.framework.yaml` Structure

**Source:** `lib/init.sh:155-169`

### Current Fields

```yaml
# Agentic Engineering Framework - Project Configuration
project_name: my-project
framework_path: /opt/999-Agentic-Engineering-Framework
version: 1.2.6
provider: claude
initialized_at: 2026-03-12T09:00:00Z
```

### Could It Store Upstream URL?

Yes. Adding a field is trivial:

```yaml
upstream_repo: DimitriGeelen/agentic-engineering-framework
```

**Advantages:**
- Persistent — survives compaction, session changes, agent restarts
- Single source of truth — all `fw upstream` commands read from here
- Set once at `fw init` time — computed from the framework repo's git remote
- Explicit — no discovery needed at runtime

**Implementation in init.sh** would add:
```bash
# Detect upstream repo from framework's git remote
UPSTREAM_REPO=$(cd "$FRAMEWORK_ROOT" && git remote get-url origin 2>/dev/null | sed 's|.*github.com[:/]||;s|\.git$||')
```

**NOTE:** `.framework.yaml` does NOT exist in the framework repo itself (only in consumer projects). The framework repo has no `.framework.yaml` at root. This file is only generated by `fw init` in target projects. For the framework self-hosting case, the upstream URL must come from somewhere else (git remote, or a dedicated config).

---

## Research Task 6: `fw harvest` — Extension Potential

**Source:** `/opt/999-Agentic-Engineering-Framework/lib/harvest.sh`

### What It Does

`fw harvest` is the **inbound knowledge pipeline**: it reads a project's `.context/` directory and promotes learnings, patterns, decisions, episodic memories, and practices back to the framework.

### How It Works

1. Reads from `$project_dir/.context/project/{patterns,learnings,decisions,practices}.yaml`
2. Compares against `$FRAMEWORK_ROOT/.context/project/` equivalents
3. Deduplicates by content string matching
4. Appends new items with `harvested_from` and `harvest_date` provenance
5. Also detects new sections in project's CLAUDE.md vs template

### Could It Be Extended for Upstream Reporting?

**Partially.** `fw harvest` moves knowledge artifacts (YAML entries) into the framework. Upstream reporting needs to move **issues** (bugs, features) and optionally **code patches** to a remote repo.

The overlap is:
- Both move information from a project to the framework
- Both need deduplication (seen/sent tracking)
- Both need provenance (where did this come from?)

The divergence is:
- `harvest` writes to local files; upstream writes to GitHub API
- `harvest` deals with YAML entries; upstream deals with issues/PRs
- `harvest` is safe (local-only); upstream has remote side effects

**Recommendation:** `fw harvest` and `fw upstream` should be **sibling commands**, not merged. They share the "project -> framework" direction but differ in everything else. However, `fw harvest` could be enhanced to automatically create an upstream issue for patterns that appear in 3+ projects (graduation trigger).

---

## Research Task 7: CONTRIBUTING.md Friction Points

**Source:** `/opt/999-Agentic-Engineering-Framework/CONTRIBUTING.md`

### Current Manual Workflow

1. Fork and branch from `main`
2. Create a task: `fw work-on "Description" --type build`
3. Reference task in commits: `T-XXX: description`
4. Run `fw doctor` and `fw audit`
5. Open a PR against `main`
6. Respond to review

### Friction Points for Field Reporting

| Step | Friction | Why |
|------|----------|-----|
| Fork | Requires manual GitHub UI action or `gh repo fork` | Not part of `fw` workflow |
| Branch | Must be on the framework repo, not the project | Risk: branching in wrong repo |
| Task reference | Framework task IDs don't exist in consumer projects | Namespace collision risk |
| Running checks | `fw doctor` and `fw audit` run against current project, not framework | May report project-specific issues |
| Opening PR | Manual `gh pr create` with correct `--repo` | Risk: targeting wrong repo |

### The Core Problem

CONTRIBUTING.md assumes you're working **inside** the framework repo. There's no workflow for contributing **from** a consumer project. The T-451 pipeline needs to bridge this gap.

---

## Design Question 1: Remote Identification

### Option A: Stored in `.framework.yaml` (Recommended)

```yaml
upstream_repo: DimitriGeelen/agentic-engineering-framework
upstream_host: github.com  # optional, defaults to github.com
```

**Pros:**
- Persistent across sessions and compactions
- Set once at `fw init` time (auto-detected from framework repo's git remote)
- Agent always knows where upstream is — no discovery needed
- Works even if framework repo's git remote changes later (pinned at init)

**Cons:**
- Only exists in consumer projects, not in framework self-hosting
- Requires `fw init` or `fw upgrade` to populate for existing projects

**Self-hosting fallback:** When no `.framework.yaml` exists (self-hosting), detect from `git remote get-url origin` of the framework repo itself.

### Option B: Git Submodule Remote

**Pros:** Standard git mechanism for tracking upstream
**Cons:** Framework is NOT distributed as a submodule. This would require changing the distribution model. Rejected.

### Option C: Hardcoded in Framework Source

```bash
# In bin/fw or lib/upstream.sh
UPSTREAM_REPO="DimitriGeelen/agentic-engineering-framework"
```

**Pros:** Always available, no configuration needed
**Cons:** Forks would need to change this. Not portable. Violates D4 (Portability).

### Option D: Discovered from Git Remote at Runtime

```bash
cd "$FRAMEWORK_ROOT" && git remote get-url origin
```

**Pros:** Always current, no configuration needed
**Cons:** Fragile after compaction (agent may not know FRAMEWORK_ROOT). Fails if framework repo has unusual remote names. Not available if framework is vendored.

### Recommendation: **Option A + D fallback**

1. Primary: Read `upstream_repo` from `.framework.yaml`
2. Fallback: Discover from `$FRAMEWORK_ROOT` git remote
3. Self-hosting: Discover from current repo's git remote
4. Confirm before first use: "Upstream is `DimitriGeelen/agentic-engineering-framework` — correct?"

---

## Design Question 2: Safety Model for Outbound Operations

### Issue-Only Mode (Low Risk) — Default

```bash
fw upstream report --title "Bug: audit fails" --body "Details..."
# Equivalent to: gh issue create --repo $UPSTREAM_REPO --title ... --body ...
```

- **No push required** — only GitHub API call
- **No branch required** — no code sent
- **No cross-contamination possible** — only text metadata
- **Dry-run by default**: `fw upstream report --title "..." --dry-run` (show what would be created)
- **Confirmation prompt**: "Create issue on DimitriGeelen/agentic-engineering-framework? [y/N]"

### PR Mode (High Risk) — Explicit Opt-in

```bash
fw upstream contribute --patch HEAD~3..HEAD --title "Fix: audit check"
# Creates a branch on upstream (or fork), applies patch, opens PR
```

- **Requires explicit `--push` flag** (no accidental pushes)
- **Tier 0 gate**: The `git push` to upstream repo should trigger Tier 0 approval
- **Isolation**: Use worktree or temporary clone to avoid contaminating project repo
- **Dry-run default**: Show diff, target repo, branch name without executing

### Structural Prevention of Wrong-Repo Pushes

The key insight: **never use `git push` from the project repo.** Instead:

1. **Issue mode**: `gh issue create --repo` — no push at all
2. **PR mode**: `gh pr create --repo` with `--head user:branch` — push goes to fork, not upstream
3. **Patch mode**: Generate `.patch` file, upload via API — no push at all

If a push IS needed (to fork), it should happen in an isolated worktree/clone:
```bash
# In /tmp/fw-upstream-XXXX/ (temporary clone of framework)
git clone --depth 1 https://github.com/USER/agentic-engineering-framework-fork.git /tmp/fw-upstream-XXXX
cd /tmp/fw-upstream-XXXX
git checkout -b fix/audit-check
# Apply changes
git push origin fix/audit-check
gh pr create --repo DimitriGeelen/agentic-engineering-framework --head USER:fix/audit-check
```

This makes it **structurally impossible** to push project code to the framework repo or vice versa.

### Safety Summary

| Mode | Risk Level | Safety Mechanism | Push? |
|------|-----------|-----------------|-------|
| `fw upstream report` (issue) | **Minimal** | `gh --repo`, confirmation prompt | No |
| `fw upstream patch` (file) | **Low** | Generates file only, no remote action | No |
| `fw upstream contribute` (PR) | **Medium** | Isolated clone/worktree, Tier 0, dry-run | To fork only |
| Direct push to upstream | **High** | **Blocked** — not offered as option | N/A |

---

## Design Question 3: Isolation for PR Contributions

### Option A: Fork Workflow (Recommended for PRs)

```bash
fw upstream contribute --title "Fix audit" --files agents/audit/audit.sh
# 1. Check if fork exists: gh repo view USER/agentic-engineering-framework
# 2. If not, fork: gh repo fork DimitriGeelen/agentic-engineering-framework
# 3. Clone fork to /tmp/fw-upstream-XXXX/
# 4. Create branch, apply changes
# 5. Push to fork
# 6. Create PR: gh pr create --repo UPSTREAM --head USER:branch
# 7. Clean up temp directory
```

**Pros:** Standard GitHub workflow. Safe (push goes to fork). No upstream write access needed.
**Cons:** Requires fork setup (one-time). More complex implementation.

### Option B: Branch on Upstream

**Pros:** Simpler (no fork management)
**Cons:** Requires write access to upstream. Branches accumulate on upstream. Not viable for external contributors.

### Option C: Patch File Generation (Recommended for Simple Fixes)

```bash
fw upstream patch HEAD~1 --output /tmp/fw-fix-audit.patch
# Generates a .patch file from framework-relevant changes
# User can upload to issue manually, or attach via gh
```

**Pros:** Zero remote side effects. Works offline. Can be reviewed before sending.
**Cons:** Manual step to apply. Not integrated with GitHub PR workflow.

### Option D: Worktree Isolation

```bash
# Use git worktree to isolate framework changes
git worktree add /tmp/fw-upstream-work -b upstream/fix-audit
```

**Pros:** Uses git's built-in isolation
**Cons:** Worktree shares object store with project repo — still risk of contamination

### Recommendation: **Tiered approach**

1. **Default (issue)**: `fw upstream report` — no isolation needed
2. **Simple (patch)**: `fw upstream patch` — generates patch file
3. **Full (PR)**: `fw upstream contribute` — fork workflow with temp clone

---

## Design Question 4: What Gets Sent Upstream

### Tier 1: Issue Report (Default)

```yaml
title: "Bug: audit fails on empty task list"
body: |
  ## Context
  - Framework version: 1.2.6
  - Project: my-project (shared-tooling mode)
  - fw doctor output: [attached]

  ## Problem
  audit.sh exits with error when .tasks/active/ is empty

  ## Reproduction
  1. fw init /tmp/test --provider claude
  2. fw audit

  ## Suggested Fix
  Check for empty directory before iterating
labels: [bug, field-report]
```

Auto-populated: framework version, `fw doctor` output, project mode (self-hosting vs shared).

### Tier 2: Issue + Patch

Same as Tier 1 plus a `.patch` attachment:
```bash
fw upstream report --title "..." --attach-patch HEAD~1
```

### Tier 3: Full PR

Same as Tier 1 plus a PR:
```bash
fw upstream contribute --title "..." --files agents/audit/audit.sh
```

### Tier 4: Learning/Pattern (fw harvest extension)

```bash
fw upstream share-learning L-042
# Creates an issue labeled "learning" with the learning content
# For patterns that graduated across 3+ projects
```

### Recommendation: **Start with Tier 1 and Tier 2 only.** Tier 3 (full PR) is complex and rare. Tier 4 is a future enhancement of `fw harvest`.

---

## Design Question 5: Agent Awareness After Compaction

### The Problem

After context compaction, the agent loses all session memory. If it needs to report upstream, it must rediscover:
1. What repo is upstream
2. What remote names mean
3. Whether it's in a consumer project or self-hosting

### Current State

After compaction:
- `.framework.yaml` persists (it's a file, not memory)
- Git remotes persist (they're in `.git/config`)
- Session state is lost (but rebuilt by `fw resume`)

### Solution: Persistent Configuration in `.framework.yaml`

If `upstream_repo` is in `.framework.yaml`, the agent doesn't need to discover it:

```yaml
upstream_repo: DimitriGeelen/agentic-engineering-framework
```

For self-hosting (no `.framework.yaml`), the `fw upstream` command can:
1. Read current repo's `origin` remote
2. Extract `OWNER/REPO` from the URL
3. Confirm with user on first use
4. Cache in `.context/working/.upstream-config` for the session

### Additional Safety: Remote Map

`fw upstream status` could show:
```
Upstream Configuration:
  Repo:   DimitriGeelen/agentic-engineering-framework
  Source:  .framework.yaml (persistent)
  Auth:   DimitriGeelen (gh auth status)

Remote Topology:
  origin  -> my-project (THIS PROJECT)
  github  -> agentic-engineering-framework (FRAMEWORK)

Safety: gh issue create --repo will target the framework repo, not this project's repo.
```

This gives the agent (and human) a clear view of what's what, surviving any compaction.

---

## Summary of Key Findings

1. **No upstream URL exists anywhere in the framework.** `.framework.yaml` stores `framework_path` (local filesystem) but not the remote repo URL. This is the #1 gap.

2. **`gh issue create --repo` is the zero-risk default.** It requires no push, no branch, no fork. It just creates an issue via API. This should be the primary mode.

3. **Tier 0 does NOT protect against wrong-repo pushes.** It only blocks force pushes and `--no-verify`. A normal `git push` to the wrong remote sails through. The safety model for T-451 must be **structural** (never use `git push` from project repo) not **pattern-based** (add more regex).

4. **OneDev PR sync is the architectural mirror.** Same deduplication pattern (seen file), same idempotency, same dry-run default. The outbound pipeline should follow this pattern.

5. **`fw harvest` and `fw upstream` should be siblings, not merged.** `harvest` moves YAML knowledge entries locally; `upstream` creates GitHub issues/PRs remotely. Different mechanisms, same direction.

6. **The fork-clone-push-PR pattern prevents cross-contamination structurally.** By using a temporary clone for PRs, it's impossible to accidentally push project code to the framework repo.

7. **`.framework.yaml` is the right place for persistent upstream config.** It already stores `framework_path` and `version`. Adding `upstream_repo` is natural and survives compaction.

---

## Proposed Command Surface

```bash
# Configure (auto-detected at fw init, or manual)
fw upstream config                     # Show current upstream config
fw upstream config --repo OWNER/REPO   # Set upstream repo explicitly

# Report (issue-only, zero risk)
fw upstream report --title "Bug: ..."  # Create issue on upstream
fw upstream report --title "..." --attach-doctor  # Include fw doctor output
fw upstream report --title "..." --attach-patch HEAD~1  # Include patch

# Contribute (PR, medium risk, isolated)
fw upstream contribute --title "Fix: ..." --files path/to/file  # Fork + PR workflow

# Status
fw upstream status                     # Show config, auth, recent reports
fw upstream list                       # Show issues/PRs you've created
```

All commands default to `--dry-run` on first use. All commands confirm the target repo before executing.
