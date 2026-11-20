# T-5302 — How the framework names its own commands in vendored projects

**Status:** EXPLORING. Inception opened 2026-11-20.

## Trigger

GitHub #68 (outside contributor's second PR): `fw doctor` prints `bin/watchtower.sh restart` and `bin/watchtower.sh stop && bin/watchtower.sh start`; in a vendored project that file is `.agentic-framework/bin/watchtower.sh`. The contributor's fix (`bin/fw watchtower restart`) is also not runnable at a vendored project's root (no `bin/` there).

Operator, 2026-11-20 (verbatim): "I'm not sure that the bin slash f watchtower invented projects is just really a crappy crappy buggy artifact we still have because it's path rewriting and isolation we should have in the project and is referenced to bin watchtowers bin slash fw is screwing a lot of things up often time but I want you to reflect on this and also get consultation on this and that means you need to We do some research on how we program and stuff and how vendor projects are done and also how the isolation should take place and how we also do rewriting in webpages and things in the Watchtower."

## Findings (agent research, 2026-11-20)

### F1. Layout

- Framework repo: `bin/fw`, `bin/watchtower.sh` at the root (and a self-vendored copy under `.agentic-framework/`).
- Vendored project: no `bin/` at the root; the framework lives in `.agentic-framework/` (`.agentic-framework/bin/fw`, `.agentic-framework/bin/watchtower.sh`).

### F2. The `fw` on PATH is already an isolating router (T-2793, D-377)

`~/.local/bin/fw` holds no framework logic. It walks up from the current directory and runs the first of: `<dir>/bin/fw` beside `FRAMEWORK.md` (the framework repo), or `<dir>/.agentic-framework/bin/fw` (a vendored project). Only when no project is found does it fall back to a global install, announced on stderr. Its own header records why: before T-2793 the global CLI ran with the project's libs, a "split brain" that changed whenever the global install drifted. So **bare `fw`, run inside a project, already runs that project's own copy**, when the router is the thing on PATH.

### F3. One resolver exists for printed commands, and most printers ignore it

- Shell: `_fw_cmd` in `lib/paths.sh` (T-1102/T-1143) returns `bin/fw` in the framework repo, `fw` when a `fw` is on PATH, else `.agentic-framework/bin/fw`; `_emit_user_command` adds the `cd <project> &&` prefix (T-609). About 105 uses in 15 files.
- About 99 user-facing `echo` lines in bin/fw, lib/ and agents/ hard-code `bin/fw` instead. `fw doctor`'s own "Run:" remedies: 21 bare `fw`, 10 `bin/fw`, 2 `bin/watchtower.sh` (#68).
- Python keeps its own copies of the rule: `lib/delegation_cli.py _fw()` (T-4250: `bin/fw` or `.agentic-framework/bin/fw`, never bare `fw`), `web/designer_registry.py`, others. They disagree with `_fw_cmd` about bare `fw`.

### F4. Watchtower does two different things

- **Running fw:** fixed by T-3952: blueprints call `FRAMEWORK_ROOT/bin/fw` by absolute path (a vendored project has no `bin/fw` at its root, so the old cwd-relative call broke).
- **Showing commands to copy:** five templates and some blueprint strings print literal `bin/fw …` (e.g. `bin/fw arc …`, `web/blueprints/inception.py:815` `bin/fw task review`). No Jinja global or filter supplies the right spelling; `fw_version` is the only fw global. In a vendored project these copy-paste commands do not run.

### F5. No path rewriting during vendoring

`fw vendor` / `fw upgrade` copy framework files into `.agentic-framework/` as they are; nothing rewrites `bin/fw` in printed text for the consumer. So every hard-coded `bin/fw` in a message is wrong in every vendored project, and has been since vendoring began. Earlier fixes went one printer at a time (T-609, T-1257, T-1633, T-3952, T-4250).

### F6. Known caveat on bare `fw`

CLAUDE.md §Copy-Pasteable Commands still says bare `fw` "may resolve to a stale global install". That was true before the T-2793 router; after it, bare `fw` is only wrong on a host whose PATH `fw` is not the router (an old install), or outside any project. Whether every host now has the router is an open fact (IW-4).

## Reflection (agent)

- The operator's instinct holds: the bug class is not one wrong line but *each printer spelling the command itself*. The isolation already exists at run time (the router, T-3952); what is missing is one rule for what we *print*, used everywhere (shell, Python, Watchtower pages).
- Candidate shapes to test in consultation:
  - **A. Print bare `fw` everywhere** (with `cd <project> &&`), relying on the router; doctor checks the PATH `fw` is the router and says how to install it when not.
  - **B. Print the resolved project path** (`bin/fw` in the framework repo, `.agentic-framework/bin/fw` in a vendored project) through one shared resolver in shell, Python and a Watchtower template global.
  - **C. A project-root shim** (`bin/fw` or `./fw` created in every vendored project), so `bin/fw` is always right. Changes the consumer's tree; conflicts with "nothing outside .agentic-framework/".
- Whatever the shape, a lint that fails on a new hard-coded `bin/fw` or `bin/watchtower.sh` in printed text is what stops the drift.

## Consultation

(pending — see Dialogue Log)

## Dialogue Log

- 2026-11-20, operator: questioned the `bin/fw` path in vendored projects as a buggy artifact of path rewriting and missing isolation; asked for reflection, research and consultation before answering the contributor on #68.
- 2026-11-20, agent: consultation sent to proxmox-ring20-management (b0e5a55b), 1409-sprind (bc92f5c9), 055-agentic-fleet-cockpit (504306b4), 832-Workflow-designer (6aec9304): how they run fw, whether PATH fw is the router, which printed commands failed, what they want printed. Revisit 2026-11-24. The outside contributor on #68 has not been consulted (a GitHub comment needs the operator's OK).
