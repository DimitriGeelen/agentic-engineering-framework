# T-2803 — What depends on `$HOME/.agentic-framework`?

**Task:** T-2803 · **Gates:** the first T-2800 build slice · **Date:** 2026-08-04

T-2800 (operator GO) removes the framework from `$HOME`, leaving only the 5.5 KB
router. IW-4 — *what actually depends on the global install?* — was deliberately
deferred. This is that survey. It enumerates and classifies; it changes nothing.

## Method

Three greps over shipped code (the vendored mirror `.agentic-framework/` is
excluded — it doubles every hit):

```
grep -rnE '(\$HOME|~|\$\{HOME[^}]*\})/\.agentic-framework' \
  --include="*.sh" --include="fw" --include="fw-router" --include="fw-shim" \
  --include="*.py" bin/ lib/ agents/ web/ install.sh     → 12 lines
grep -rn 'FW_GLOBAL_ROOT' bin/ lib/ agents/ install.sh   → 1 line (subset of the above)
grep -rni 'global install' bin/ lib/ agents/ web/ docs/ prompts/
```

**12 references, 6 files**: `bin/fw`, `bin/fw-router`, `bin/fw-shim`,
`install.sh`, `lib/update.sh`, `lib/upgrade.sh`. Nothing in `agents/`, `web/`, or
any Python. The blast radius is smaller than the dialogue assumed.

## Classification

| # | Site | What it does with the global | Class |
|---|---|---|---|
| 1 | `bin/fw-router:64` (+`:23`) | `_global="${FW_GLOBAL_ROOT:-$HOME/.agentic-framework}"` — the announced fallback when no project is found above cwd | **must-migrate** — ordering-critical, see below |
| 2 | `install.sh:16` (+`:9`, `:74`) | `INSTALL_DIR="${INSTALL_DIR:-$HOME/.agentic-framework}"` | **must-migrate** — becomes the project target |
| 3 | `install.sh:134-190` (`do_install`) | clones/resets a **git checkout** into `INSTALL_DIR` | **must-migrate** — becomes a tarball fetch to a temp path |
| 4 | `install.sh:238-282` (`link_fw`) | reads the router from `$INSTALL_DIR/bin/fw-router` to copy onto PATH | **compat-shim-needed** — router source moves to the fetched temp dir |
| 5 | `install.sh:259`, `:280` | **`ln -sf "$INSTALL_DIR/bin/claude-fw"`** — a *symlink*, not a copy | **must-migrate** — see finding below |
| 6 | `install.sh:334` (`verify`) | runs `$INSTALL_DIR/bin/fw doctor` as the self-test | **must-migrate** — verify against the project's vendored copy |
| 7 | `lib/upgrade.sh:1432-1509` | step 4c syncs `bin/fw`, `lib/*.sh`, `agents/context/` into the global | **can-delete** — explicitly "fallback for users who still use global install" (T-660); already prints `SKIP` when absent |
| 8 | `bin/fw:1532-1552` | doctor: global-install deprecation check | **compat-shim-needed** — keep as a *migration detector*, invert the wording |
| 9 | `bin/fw:2270-2280` | doctor: WARN when global > 100 MB, "consider `rm -rf`" | **compat-shim-needed** — the cleanup nudge for existing hosts; delete once migration is done |
| 10 | `bin/fw:1768` | advises `bash ~/.agentic-framework/install.sh` to refresh a drifted `claude-fw` | **must-migrate** — the instruction becomes false (no global checkout to reset) |
| 11 | `lib/update.sh:7`, `:39`, `_do_update_git` | the `git reset --hard` update path, keyed on `$FRAMEWORK_ROOT/.git` | **can-delete** — legacy pre-T-499 path; vendored projects take `_do_update_vendored` |
| 12 | `bin/fw-shim:4-13` | comments; superseded by `fw-router` (kept only as the `! -x` fallback) | **can-delete** — dead under the new model |

Summary: **6 must-migrate, 3 compat-shim-needed, 3 can-delete.** Every
must-migrate except #10 is inside `install.sh` — which matches the T-2800
conclusion that the gap is almost entirely there.

## Finding the design doc missed: `claude-fw` is a symlink, not a copy

`install.sh` installs two things on PATH, and it treats them differently:

```bash
cp  "$shim_src"                  "$local_bin/fw"        # router — COPIED
ln -sf "$INSTALL_DIR/bin/claude-fw" "$local_bin/claude-fw"  # wrapper — SYMLINKED
```

Both branches of `link_fw` symlink `claude-fw` (`:259` and `:280`), with the
comment *"claude-fw still symlinks (it's a wrapper, not project-specific)"* —
true today, because `INSTALL_DIR` is permanent.

Under "$HOME keeps the router and nothing else", `INSTALL_DIR` stops existing,
and **`~/.local/bin/claude-fw` becomes a dangling symlink.** The auto-restart
wrapper (T-179) — the thing that recovers a session at budget-critical — silently
stops working, on every host that migrates.

`claude-fw` must be **copied** like the router is. It is a 2-file bootstrap layer
in `$HOME`, not one. This does not change the T-2800 decision (both files are
tiny; the 352 MB still goes), but it is a required line in the build slice, and
nobody had written it down.

Second-order: `bin/fw:1745-1772` detects `claude-fw` drift by comparing the file
on PATH against the repo's `bin/claude-fw`. Once it is a copy rather than a
symlink, that check becomes *more* necessary, not less — and its remediation
line (#10) must name the new refresh path.

## Does an existing install keep working untouched?

The GO was given on the understanding that this changes how **new** projects are
created. Splitting the question, because the answer differs by subject:

**Existing projects — yes, untouched.** Evidence:

- The router resolves `<dir>/.agentic-framework/bin/fw` by walking up from cwd
  and only consults the global when that walk fails (`bin/fw-router:64`,
  reached after the project branch). A project that exists is found first.
- Proven live in the T-2800 bootstrap spike: a vendored project ran with
  **zero framework bytes in `$HOME`** — `fw init` rc=0, 5 tasks seeded, and
  afterwards `fw` reported `Mode: vendored`.
- `fw upgrade` step 4c is a *fallback for* the global, not a dependency *on* it:
  guarded by `[ -d "$global_dir/agents/context" ]`, prints
  `SKIP  No global install at …` otherwise (`lib/upgrade.sh:1509`).
- `fw update` in a vendored project dispatches on
  `$project/.agentic-framework/VERSION` to `_do_update_vendored`
  (`lib/update.sh:60-62`). The global-only `_do_update_git` path is never
  reached.

**Host-level affordances — two break, and both are in-scope for the slice:**

1. **`claude-fw` dangles** (the finding above).
2. **`fw init` in a bare directory has nothing to run.** Today it works *because
   of* the global fallback: the router finds no project, announces the global,
   and executes framework code from it. Remove the global and that path refuses —
   correctly, but the user has no way to create project N+1 until the new
   installer ships.

## The ordering constraint this survey exists to surface

Sites #1 and #2 must change **in the same slice**, and #2 must land first.

> The router's global fallback is the only thing that makes `fw init` work in a
> bare directory. Deleting the global before `install.sh` can create a project is
> not a smaller first step — it is the step that removes the ability to make new
> projects.

Safe order:

1. `install.sh` learns to fetch a tarball into a target directory, init it, and
   copy **both** `fw-router` and `claude-fw` onto PATH. *(The global still exists
   at this point; nothing has broken.)*
2. Copy-not-symlink for `claude-fw` (#5), and fix the refresh advice (#10).
3. `fw upgrade` step 4c (#7) and `_do_update_git` (#11) deprecate — they are
   already no-ops when the global is absent, so this is cleanup, not a cutover.
4. Doctor checks (#8, #9) invert into migration detectors: *you still have a
   global install; here is how to remove it.*
5. Only then does the router's fallback (#1) become removable — and it may be
   better to keep it permanently, since it already announces itself on stderr
   and its absence is what T-2800's refuse-path message covers.

Step 1 alone delivers the operator-visible outcome (a new project with no 352 MB
in `$HOME`). Steps 3-5 are hygiene on hosts that already have one.

## What this survey did not cover

- **Other hosts.** This enumerates the *code*, not the fleet. How many machines
  currently have a global install, and what versions, is a separate question —
  `install.sh:193` (`scan_vendored_consumers`) already knows how to find
  vendored projects and could report it.
- **Documentation.** `grep -rni 'global install'` returns hits in
  `docs/reports/*` (T-1100, T-877, T-482, T-625). Those are historical RCAs and
  should stay as written — they are records, not instructions. No doc rewrite is
  implied by this survey beyond the install one-liner's own docs.
