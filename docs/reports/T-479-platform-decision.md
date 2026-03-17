# T-479: Primary Development Platform — GitHub vs OneDev

## Problem

The framework uses OneDev as source of truth and GitHub as public mirror. Launch is imminent (T-334). Community interaction will happen on GitHub. The question: should GitHub become primary?

## Options

| Option | Description | Effort |
|--------|-------------|--------|
| A | Keep OneDev primary, GitHub mirror | None (status quo) |
| B | Flip to GitHub primary, OneDev backup | Low-medium |
| C | Split: OneDev for dev, GitHub for community | Medium-high (sync complexity) |

## Spike 1: OneDev Usage Audit

### What OneDev provides

**Git remotes:**
- OneDev: `https://onedev.docker.ring20.geelenandcompany.com/agentic-engineering-framework.git` (primary)
- GitHub: `https://github.com/DimitriGeelen/agentic-engineering-framework.git` (mirror)

**OneDev-specific config:**
1. `.onedev-buildspec.yml` — Two CI jobs:
   - **Production deployment:** Triggers on `v*` tags, SSHs to LXC 170, deploys to `/opt/watchtower-prod`, health check, auto-rollback on failure
   - **GitHub mirror:** Pushes all branches + tags to GitHub using PAT secret
2. `deploy/onedev-pr-sync.sh` — Cron script (in .gitignore) that polls OneDev API for PRs and creates framework tasks (T-442/T-443)

**What's actively used:**
- Production deployment pipeline (essential — deploys Watchtower to LXC 170)
- GitHub mirroring (runs on every branch update / tag)
- PR-to-task sync cron (bridges OneDev PRs to `.tasks/`)

**What's NOT used:**
- No OneDev-specific access control, code review, or issue tracking
- No OneDev UI for day-to-day work (development happens in terminal + Claude Code)

### What would be lost if OneDev became mirror-only

1. **Production deployment automation** — Tag triggers must move to GitHub Actions
2. **PR-to-task sync** — Built for OneDev API; GitHub PRs need separate tooling
3. **Mirror push job** — Direction reverses (GitHub pushes to OneDev, not vice versa)

## Spike 2: GitHub Community Readiness

### What already exists (70% ready)

- **Issue templates:** Bug report + feature request with framework-specific fields
- **CI workflow:** GitHub Actions for bats-core tests + Python validation (T-476)
- **Documentation:** README, CONTRIBUTING.md, Apache 2.0 LICENSE
- **Reusable action:** action.yml with branding
- **Install script:** References GitHub raw content

### What's missing

| Item | Impact | Effort |
|------|--------|--------|
| PR template | Medium | Trivial |
| SECURITY.md | High | Small |
| CODE_OF_CONDUCT.md | Medium | Trivial |
| CODEOWNERS | Low | Trivial |
| Branch protection rules | Medium | Small (admin UI) |
| Status badges in README | Low | Trivial |
| Release automation workflow | Low | Small |
| Dependabot config | Low | Trivial |

### Risk areas
- No release automation (installs from `master` branch, no version tags on GitHub)
- No branch protection (main/master unprotected)
- PR template doesn't enforce task ID format

## Spike 3: Sync Strategy Evaluation

### Current sync model
OneDev → GitHub (one-way push via `.onedev-buildspec.yml` mirror job). No sync from GitHub back. This means GitHub PRs, issues, and discussions are siloed — they don't feed back to the framework's task system.

### Sync options if both platforms remain active

| Strategy | Direction | Complexity | Operational cost |
|----------|-----------|-----------|-----------------|
| Current (OneDev → GitHub push) | One-way | Low | Near-zero (CI handles it) |
| Add GitHub → tasks cron | One-way inbound | Medium | New cron script + GitHub API |
| Bi-directional sync | Two-way | High | Conflict resolution, state tracking |
| GitHub primary, OneDev mirror | Reversed one-way | Low | Swap push direction |

### Key insight: the task system is platform-agnostic

`.tasks/` lives in git. It syncs to both platforms automatically. The real question isn't "where does truth live" — it's "where do external contributors interact, and how do we capture that interaction into tasks?"

### Operational cost assessment

- **Option A (status quo):** Zero cost today. Cost grows linearly with community interaction — every GitHub issue/PR requires manual task creation.
- **Option B (GitHub primary):** One-time migration (~2-3 days: CI pipeline to GitHub Actions, reverse mirror direction). Then zero ongoing cost — community interacts where code lives.
- **Option C (split):** Ongoing cost — two sync scripts, two sets of CI, two places to check. Complexity compounds over time.

## Directive Scoring

| Option | D1 Antifragility | D2 Reliability | D3 Usability | D4 Portability |
|--------|------------------|----------------|--------------|----------------|
| A (OneDev primary) | Neutral — private infra is a single point of failure | Good — current model works, no moving parts | Poor for contributors — truth on private server | Good — no vendor dependency |
| B (GitHub primary) | Better — GitHub has redundancy, community can report issues directly | Good after migration — simpler model, one source | Best — contributors interact where code lives | Moderate — GitHub dependency, but git remains portable |
| C (Split) | Worst — two failure modes, sync bugs, unclear ownership | Poor — sync complexity, stale mirrors, race conditions | Confusing — which platform for what? | Neutral — complexity without portability benefit |

## Analysis

### The decisive factor

OneDev provides exactly two things that GitHub doesn't: (1) production deployment automation, and (2) private network access to LXC 170. Both are **deployment infrastructure**, not development platform features. The development itself (editing, committing, task management) already happens in the terminal — neither platform's UI is used for daily work.

The question reduces to: can production deployment be triggered from GitHub? Yes — GitHub Actions can SSH to LXC 170 (with a self-hosted runner or SSH action + secrets). The `.onedev-buildspec.yml` logic is ~50 lines of shell. Migration is mechanical, not architectural.

### Option C is ruled out

Two sources of truth with sync is a well-known antipattern. The operational cost compounds, the failure modes multiply, and the mental model ("which platform do I check?") degrades usability. The only question is A vs B.

### A vs B tradeoff

**A wins if:** The project remains primarily single-developer with minimal external contribution. OneDev provides infrastructure independence (D4). Community interaction stays low.

**B wins if:** External adoption materializes (T-334 launch). Contributors file issues and PRs on GitHub. The project wants to be discoverable and contributor-friendly. The one-time migration cost is paid once; the ongoing benefit is permanent.

## Recommendation

**Option B: Flip to GitHub primary, OneDev as backup/deployment slave.**

Rationale:
1. Development doesn't use OneDev's UI — it happens in terminal/Claude Code
2. Community will interact on GitHub regardless — making it the source removes friction
3. OneDev's only non-replaceable value is LXC deployment — keep it as a deployment trigger or migrate to GitHub Actions
4. The task system (`.tasks/`) is already platform-agnostic — no migration needed
5. D4 (portability) concern is addressed: git itself is portable. GitHub is the distribution channel, not a lock-in. The framework can be cloned from any remote.

### Migration steps (if GO)

1. **GitHub Actions deployment workflow** — Port `.onedev-buildspec.yml` prod deploy job (~2h)
2. **Reverse mirror** — GitHub becomes push source; OneDev pulls or is updated manually (~30min)
3. **GitHub community polish** — PR template, SECURITY.md, CODE_OF_CONDUCT.md, badges (~1h)
4. **Branch protection** — Require passing tests before merge to main (~15min, admin UI)
5. **Update documentation** — CONTRIBUTING.md clone URLs, install.sh references (~30min)

Total: ~1 day of focused work, decomposable into 3-4 build tasks.

## Dialogue Log

_No human dialogue yet — awaiting review of recommendation._
