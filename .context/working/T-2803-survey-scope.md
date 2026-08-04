# T-2803 — survey scope (written at budget-critical; pick up here)

**Why:** T-2800 got operator GO (2026-08-04). IW-4 was deliberately deferred and
**gates the first build slice**: nobody has enumerated what depends on
`$HOME/.agentic-framework`. That survey bounds migration cost. Do it before
touching `install.sh`.

## The searches to run

```
grep -rnE '(\$HOME|~|\$\{HOME[^}]*\})/\.agentic-framework' \
  --include="*.sh" --include="fw" --include="fw-router" --include="fw-shim" \
  --include="*.py" bin/ lib/ agents/ web/ install.sh
grep -rn 'FW_GLOBAL_ROOT' bin/ lib/ agents/ install.sh
grep -rni 'global install' bin/ lib/ agents/ web/ docs/ prompts/
```

Exclude `.agentic-framework/` itself from results — it is the vendored mirror and
will double every hit.

## Known touch points (from dialogue, unverified counts)

| Site | What it does with the global |
|---|---|
| `bin/fw-router` | falls back to `${FW_GLOBAL_ROOT:-$HOME/.agentic-framework}` |
| `lib/upgrade.sh` | syncs `bin/fw` to it (L-172); step 4c installs the router |
| `bin/fw doctor` | probes it; global-install `du` scan in the non-`--quick` path |
| `fw consumer-recover` | references it for legacy consumer recovery |
| `install.sh` | creates it (`INSTALL_DIR="${INSTALL_DIR:-$HOME/.agentic-framework}"`, line 16) |
| every consumer on this host | was installed under the current model |

## What the survey must produce

1. A complete list of call sites, each classed **must-migrate / can-delete /
   compat-shim-needed**.
2. An explicit answer to: *does an existing install keep working untouched?*
   The GO was given on the understanding that this changes how **new** projects
   are created, not that every current project must be re-created.

## Already proven (do not re-litigate) — `docs/reports/T-2800-home-install-architecture.md`

- A 28 MB vendored copy inits a project with **zero framework in `$HOME`**: rc=0,
  5 onboarding tasks seeded, router afterwards resolves `Mode: vendored`.
- The router's no-framework refusal already exists and reads correctly; it needs
  the install one-liner in the message (T-2794's lesson), not a rewrite.
- The router is **not** fooled by `/.context` + `/.tasks` at the filesystem root
  (OBS-152's trap) — it keys on `FRAMEWORK.md` + `bin/fw`.

## Design decisions already locked by the operator

- `$HOME` keeps the router **only**. 352 MB → 5.5 KB.
- `fw init` fetches into the project; channels `stable` (default) / `edge`.
- **`stable` is cut by the operator** via `fw release`. No automated gate yet —
  gating on the current suite would bless whatever the runner skips (OBS-145).
- Exact pinning `--ref <tag|sha>`; resolved SHA recorded (`version_sha:` exists).
- Alternate source `--from <url|path|tarball>`; `upstream_repo:` already exists.
- Install + init become **one command per project** — forced by the bootstrap
  constraint, not chosen.

## Two constraints for the build slice

- **Fetch a tarball, not a clone.** A clone brings `.git` back. Even the repo
  tarball is ~183 MB; today's vendored copy is a subset (`agents bin docs lib web`
  = 28 MB). So `fw release` should publish a vendor-subset asset.
- **Atomicity is a requirement.** T-2801 (was OBS-157) is an interrupted init
  leaving `.agentic-framework/` without `.framework.yaml` — every `fw` verb then
  fails, so the tool cannot repair what it created. Fetch to a temp path, move
  into place: an interruption must leave either nothing or a working project.
- **"Seed project two from the nearest project" stays opt-in.** Automatic, it is
  the stale-global bug in a new costume (T-2762 foreign-source class).

## Session note

A **concurrent session** was working this repo tonight — it closed T-2799 (second
clean run, live Watchtower `/api/_identity`) and filed T-2801/T-2802 from OBS-157
and OBS-158. Its regression test `tests/unit/install_verify_no_cwd_init.bats` was
independently re-run here and is green. Expect `.tasks/` write collisions (the
operator hit a G-052 duplicate-ID block on the GO commit because of this).
