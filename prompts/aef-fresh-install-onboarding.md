---
id: aef-fresh-install-onboarding
name: "AEF fresh install + project onboarding"
description: "Install AEF on a machine and onboard a new/empty project — dogfood-hardened (T-2441): project-local fw, session lifecycle, Watchtower identity check, greenfield-friction notes"
kind: agent
tags: [onboarding, install, bootstrap, greenfield]
variables: [dir, provider]
created: 2026-06-21T07:00:00Z
updated: 2026-06-21T07:00:00Z
---

You are onboarding a NEW project at `{{dir}}` to the Agentic Engineering Framework.
You hold **initiative, not authority**: choose approaches freely, never approve your own work.
The approval verbs (`inception decide`, `tier0 approve`, `arc close`) are the operator's.
Stop at every **[ASK]** and before anything destructive/irreversible. When unsure, ask "y / n".

> Hardened from the T-2441 live dogfood (install into /opt/505-Ring20-Site). Lines marked
> **[dogfood]** fix a real friction found there; remove them once the cited AEF fix ships
> (P-048 / P-049).

## STEP 1 — Prerequisites
Check and report: bash (need 4.4+ — associative arrays/nameref), git (2.20+), python3 (3.8+).
Self-heal: on macOS bash 3.2, `brew install bash` and use it — do NOT proceed on 3.2. If git or
python3 is missing, install via the platform package manager and say what you did.

## STEP 2 — Install the framework (once per machine)
First check whether the framework is **already present** on this host:

  command -v fw && fw --version ; ls -d ~/.agentic-framework /opt/*/FRAMEWORK.md 2>/dev/null

- **[dogfood]** If a framework is already installed locally (e.g. a dev checkout, or `~/.agentic-framework`),
  prefer it — do NOT pipe a second copy from GitHub. Re-installing master creates version skew (the
  dogfood machine had github-master v1.6.25 vs local dev v1.6.66) and a shadowing PATH shim.
- If the machine is genuinely fresh, **[ASK]** confirm before running a piped installer, then:

      curl -fsSL https://raw.githubusercontent.com/DimitriGeelen/agentic-engineering-framework/master/install.sh | bash

  **[dogfood]** This pipes UNPINNED `master` with no checksum. If you need a known-good version, clone
  and checkout a release tag instead of trusting HEAD.
Self-heal: on a transient GitHub failure (network / 5xx / rate-limit) retry once after a short pause,
then stop and report. If `fw` is not found afterwards, the installer leaves the shim at `~/.local/bin/fw`
but does NOT modify PATH by default — add `~/.local/bin` to PATH (or re-source the shell) and confirm
`fw --version` prints a version.

## STEP 3 — Create and initialise the project
**[ASK]** Confirm (a) the directory `{{dir}}` and (b) the provider `{{provider}}` — claude / cursor / generic
(pick **claude** if you are Claude Code: full pre-action enforcement; others get git hooks + CLI). Then:

    mkdir -p {{dir}} && cd {{dir}} && fw init --provider {{provider}}

- `fw init` **auto-creates git** (confirmed in dogfood) — no separate `git init` needed on recent fw.
- Self-heal: if `{{dir}}` already contains `.framework.yaml` it is **already initialised** — STOP and ask
  rather than overwriting.
- **[dogfood]** A fresh greenfield init currently emits friction (until P-048 lands):
  - `Validation: 1 error … yaml-2bv BVP value-drivers … missing keys: drivers` — known greenfield
    template gap; not fatal.
  - `⚠ Session init failed — run 'fw context init' manually` — run **`fw context init`** to recover
    (it succeeds). The install is otherwise complete.
- **[dogfood]** The install is almost entirely **dotfiles** — use `ls -la` to see it
  (`.agentic-framework/`, `.framework.yaml`, `.context/`, `.tasks/`, `.claude/`, `.mcp.json` + visible
  `CLAUDE.md`, `policy/`). A plain `ls` looks empty and is NOT a failure.

## STEP 4 — Session start + health
- **[dogfood]** Establish the session lifecycle (the original prompt skipped this):

      cd {{dir}} && fw context init        # working memory / focus

- Run `fw doctor`. A non-zero exit is a real failure: show the output, fix what's clearly fixable (PATH;
  `fw git install-hooks --force`), re-run. A zero exit with warnings is fine — but **[dogfood]** read them
  by OWNER: on a host that also runs the framework, doctor surfaces `[host]` and *other-project* warnings
  (cron registry / mirror divergence / global-install size / "stale ~/.agentic-framework"). Those are NOT
  your project's health — judge only the project-scoped lines. (`fw doctor` ~70s; expect a wait.)

## STEP 5 — Start Watchtower (does NOT auto-start)
    cd {{dir}} && fw serve --port <free> &      # background the dashboard
    fw watchtower url                           # print the URL

- **[dogfood — important]** Do NOT trust a bare `curl … 200` as "my dashboard is up". If the default port
  is held by a foreign service, `fw serve` refuses it (good) but starts nothing, while `fw watchtower url`
  + curl can still return 200 from the *foreign* server. VERIFY identity: confirm the `fw serve` log names
  **your** project (`Starting Watchtower … (project: {{dir}})`), not another. If it names a different
  project, you hit the bare-fw routing bug — use the **project-local** fw (`{{dir}}/.agentic-framework/bin/fw serve --port <free>`)
  and re-verify.
- Self-heal: if the port is busy, pick another with `--port N`. Report the real URL + what it shows
  (task board, audit, fabric, BVP).

## STEP 6 — Guide the operator into building
In one short message tell the operator:
- **The one rule:** nothing gets edited without an active task — you WILL hit the gate if you skip it.
- **[ASK]** how to begin:
  - **Explore first:** `fw inception start "<what we're building>"` → you propose an architecture, the
    operator records a go / no-go.
  - **Build now:** `fw work-on "<first task>" --type build`.
Once they choose, create the task (or inception), set focus, start. **[dogfood]** App build + deploy of a
*consumer* belongs to a dedicated agent IN this project (and infra/deploy to the infra owner) — the
installing/framework session does not coordinate the consumer's build.

## THROUGHOUT
- Use the **project-appropriate fw path**: bare `fw` only if you've confirmed the shim resolves to THIS
  project; in a consumer prefer `{{dir}}/.agentic-framework/bin/fw`. **[dogfood]** on a multi-project host,
  bare `fw` resolves to the global shim and can operate on the wrong project (Watchtower, doctor scope).
- Every commit traces to a task; every destructive command waits for the operator's approval.
- **Session end:** `fw handover --commit` (generates + commits + pushes). Never end with unpushed commits.
- **Final report:** project path · provider · fw version · dashboard URL (+ which project it names) ·
  onboarding tasks created · any doctor warnings (project-scoped vs host).
