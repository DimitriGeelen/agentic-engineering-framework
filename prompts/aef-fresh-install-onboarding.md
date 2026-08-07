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
- **[dogfood — T-2795]** If THIS session has already run `fw` for a different, existing
  project (e.g. any session that ran the Session Start Protocol elsewhere), that project's
  `FRAMEWORK_ROOT`/`PROJECT_ROOT` are exported into this shell and **`fw` will keep
  reporting that project's identity even after `cd {{dir}}`** — by design, not a bug
  (T-2391/T-2446: "env wins" over an inherited-but-valid root). Symptom: `fw --version` /
  `fw doctor` name the WRONG project after you've `cd`'d into `{{dir}}`. Fix: scope every
  command below with `env -u FRAMEWORK_ROOT -u PROJECT_ROOT`, or run this onboarding in a
  genuinely fresh shell/session.

First check whether the framework is already present on this host:

  command -v fw && fw --version

`fw --version` answers this itself — it prints `Framework:` (the root it resolved),
`Mode:` (framework-repo / vendored / global) and `Project:`. That is the discovery.

**[dogfood — T-2847]** Do NOT glob the filesystem for other installs (this step used to say
`ls -d ~/.agentic-framework /opt/*/FRAMEWORK.md`). If you are running this onboarding from
inside an existing AEF project — the normal case, when an operator asks a live session to
onboard a new directory — the T-559 project-boundary hook **refuses** that command, and the
refusal is correct: one project's session must not read another project's tree. A prompt
step that cannot execute in its own most common context is a defect in the prompt, not a
reason to reach for a bypass. If you genuinely need a host-wide inventory, that is the
operator's call to make outside this session.

**Presence is not the question — freshness is, and the version NUMBER cannot answer it.**
`fw v1.6.432` is `major.minor.<commits-since-the-newest-tag-that-clone-knows>` — a distance,
not a version. It resets at every release tag, and a clone that has not fetched the recent
tags measures from an older anchor and so reports a **larger** number while being **older**.
Measured 2026-08-04: a global install three commits behind master reported `1.6.432` against
master's `1.6.132`, and two separate agents read that pair in opposite directions, both wrong
(OBS-150 / OBS-156, fixed in T-2796). Do not compare these numbers. Do not read a big one as
reassuring or a small one as stale.

Ask the commit instead — `fw --version` prints it (T-2796):

  fw --version | sed -n 's/^Commit: *//p' | cut -d' ' -f1
  git ls-remote https://github.com/DimitriGeelen/agentic-engineering-framework.git master | cut -c1-9

(the `cut -d' '` drops the branch name `fw --version` appends, so the two lines are
directly comparable — without it a strict `=` fails on two identical commits)

- **Same SHA** → the install is current. Skip the installer.
- **Different SHA** → the install is not upstream master. It may be newer (a dev checkout),
  older, or on another branch, and the SHA alone does not say which — so **[ASK]** rather
  than guessing a direction. `fw update` refreshes a git-based global install in place, which
  is usually the right move and avoids piping a second copy.
- **`Commit: (none — vendored copy…)`** → no git history, so nothing can be compared; the
  `VERSION` file is the only identity that install has.
- **No `Commit:` line at all** → the install predates T-2796, and is therefore old enough
  that refreshing it is the safe default.

- **[dogfood]** If a framework is already installed locally (e.g. a dev checkout, or
  `~/.agentic-framework`), do NOT pipe a second copy from GitHub — that leaves two frameworks
  and a shadowing PATH shim, and whichever one PATH happens to pick is the one every later
  step silently runs. (The original note here justified this with "the dogfood machine had
  github-master v1.6.25 vs local dev v1.6.66". Those two counters were never comparable, so
  ignore the arithmetic — the conclusion stands on the shadowing, not on the skew.)
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
- **What a healthy init looks like** (measured on greenfield 2026-08-07, T-2846): exit 0 and a
  `Validation passed: 44/45 checks OK (1 skipped)` line — the skip is the provider's unused rules
  file. Anything less than "Validation passed", or a non-zero exit, is a real failure: report it
  rather than working around it.
  Two failures this step used to warn about — a `yaml-2bv` BVP value-drivers validation error, and
  `⚠ Session init failed — run 'fw context init' manually` — **no longer occur** and the workaround
  text for them has been removed (T-2848). If you see either one, you are running an install old
  enough that STEP 2's freshness check should have caught it; go back and re-check.
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
